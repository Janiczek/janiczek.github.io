# Defunctionalization in Elm

It was not so long ago that I opened HackerNews and saw the title [The Best Refactoring You've Never Heard Of](http://www.pathsensitive.com/2019/07/the-best-refactoring-youve-never-heard.html). The refactoring in question was "defunctionalization", which *really* was a term I never heard of, even though some of the given examples looked familiar. The talk gave some formless blob in my brain's idea space a name ("reified it", hello Rich Hickey!), and all around it was a very cool talk. (Go watch it!)

----

Fast forward a few days. I was fighting an ugly piece of code in our Elm codebase - one I wrote, again, not that long ago. Yeah, not my proudest moment.

[![Me reacting to my code.](/assets/images/2019-07-27-defunctionalization-in-elm/reaction.png)](/assets/images/2019-07-27-defunctionalization-in-elm/reaction.png)

As you can see, a lightbulb went off in my head. *This sounds like THAT thing!* There was nothing left to do than to try it.

----

The problem itself was simple to understand, but hairy in details.

We have a top-level `Store`.

```elm
type alias Store =
    { categories : WebData (Dict CategoryId Category)
    , questions : WebData (Dict QuestionId Question)
    , bookmarks : WebData (Dict BookmarkId Bookmark)
    , savedQueries : WebData (Dict SavedQueryId SavedQuery)
    -- ... you get the idea
    }
```

We also have our own `Msg` type in the Store module and `update`-like functions for fetching stuff.

```elm
fetchQuestions : Config msg -> Flags -> Store -> ( Store, Cmd msg )
fetchQuestions config flags store =
    fetch_
        { get = .questions
        , set = \val store_ -> { store_ | questions = val }
        , onSuccess = QuestionsFetched
        , request = API.getQuestions
        }
        config
        flags
        store

-- one such function for each field in the Store record
```

Now, many of our pages need multiple such entities fetched. So we do something similar to [elm-fetch](https://www.gizra.com/content/elm-fetch/), and define what route needs which entities.

```elm
fetchForRoute : Route -> Cmd msg
fetchForRoute route =
    case route of
        Router.CrosstabBuilder CrosstabBuilder.List ->
            Store.fetchXBProjects

        Router.CrosstabBuilder (CrosstabBuilder.Detail _) ->
            Store.fetchMany
                [ Store.fetchQuestions
                , Store.fetchCategories
                , Store.fetchAudiences
                , Store.fetchAudienceFolders
                , Store.fetchXBProjects
                ]

        -- ...
```

As you can see, we use a `fetchMany` function which allows us to compose these together. It's essentially a `List.foldl` over our `(Store, Cmd msg)` type, with the catch that the fetch functions need a bunch of other stuff in parameters.

```elm
fetchMany : List (Config msg -> Flags -> Store -> ( Store, Cmd msg ))
               -> Config msg -> Flags -> Store -> ( Store, Cmd msg )
fetchMany list config flags store =
    List.foldl
        (\fetchAction ( currentStore, currentCmd ) ->
            let
                ( newStore, newCmd ) =
                    fetchAction config flags currentStore
            in
            ( newStore
            , Cmd.batch [ currentCmd, newCmd ]
            )
        )
        ( store, Cmd.none )
        list
```

See that type signature? This is where we'll start encountering problems. Due to various constraints -- notably our app being both standalone (all those pages living in one Elm app) and embedded in a legacy JS shell -- we have to pass the pages a knowledge of how to do that `fetchMany` action.

```elm
type alias Config msg =
    { msg : Msg msg -> msg
    , ajaxError : Error -> msg
    , navigateTo : Route -> msg
    , openAlert : String -> String -> msg
    , refreshAudiences : msg
    , fetchMany : List (Store.Config Msg -> Flags -> Store.Store
                        -> ( Store.Store, Cmd Msg )
                       ) -> msg
    , disabledExportsAlert : msg
    }
```

To not get into too many details, we have to do this in one more level because of our Elm-in-JS-shell architecture, and that's where it starts getting really ugly. I don't want you to read and understand the following code, I just want you to agree that it's really ugly. Please?

```elm
type Msg
    = FetchMany (List (Store.Config Msg -> Flags -> Store.Store
                       -> ( Store.Store, Cmd Msg )
                      )
                )
    -- | ...

crosstabBuilderConfig : XB.Config Msg
crosstabBuilderConfig =
    { msg = CrosstabBuilderMsg
    , ajaxError = AjaxError
    , navigateTo = NavigateTo
    , openAlert = OpenAlert
    , refreshAudiences = RefreshAudiences
    , fetchMany = fetchMany
    , disabledExportsAlert = DisabledExportsAlert
    }

fetchMany list =
    let
        innerConfig : Store.Config (XB.Msg Msg)
        innerConfig =
            Store.configure
                { msg = XB.OuterMsg << StoreMsg
                , err = \store error ->
                            XB.OuterMsg
                                (AjaxError store error)
                }

        changeFn :
            (Store.Config (XB.Msg Msg) -> Flags
              -> Store.Store -> ( Store.Store, Cmd (XB.Msg Msg) )
            )
            -> (Store.Config Msg -> Flags -> Store.Store
                 -> ( Store.Store, Cmd Msg )
               )
        changeFn fn =
            \_ flags store ->
                fn innerConfig flags store
                    |> Glue.map CrosstabBuilderMsg
    in
    FetchMany (List.map changeFn list)
```

*Bleh.* All this was essentially `Msg` mapping to appease the type system, and it got very complicated very fast.

## Getting out of this mess

At the time of writing, I didn't see a way out of this. I knew it was ugly but it was the best I could do. But now, with the knowledge of defunctionalization, could I try to apply that here?

Let's see:

```elm
type FetchAction
    = FetchCategories
    | FetchQuestions
    | FetchBookmarks
    | FetchSavedQueries
    -- | ...


fetch : FetchAction -> Config msg -> Flags -> Store
        -> ( Store, Cmd msg )
fetch =
    -- exercise for the reader
    Debug.todo "Store.fetch"


fetchMany : List FetchAction -> Config msg -> Flags -> Store
            -> ( Store, Cmd msg )
fetchMany =
    -- exercise for the reader
    Debug.todo "Store.fetchMany"
```

What I've done above is replaced all those `fetchQuestions`-like functions with a single `fetch` one, which looks very much like `update` now. Also, `FetchAction` appeared! This is the crux of defunctionalization - **we have replaced functions with data and a way to interpret that data later.** In essence, nothing changed, but we'll be allowed to have nicer types and get rid of that horrible boilerplate!

And now, because the `fetchMany` type annotation no longer contains any parameterized `msg` types, it simplifies all types that touch it to the point where we don't need to `Cmd.map` the Msg at all! That horrible piece of code becomes:

```elm
type Msg
    = FetchMany (List Store.FetchAction)
    -- | ...


crosstabBuilderConfig : XB.Config Msg
crosstabBuilderConfig =
    { msg = CrosstabBuilderMsg
    , ajaxError = AjaxError
    , navigateTo = NavigateTo
    , openAlert = OpenAlert
    , refreshAudiences = RefreshAudiences
    , fetchMany = FetchMany
    , disabledExportsAlert = DisabledExportsAlert
    }
```

And so, we had a happy ending (click to enlarge):

[![Happy ending](/assets/images/2019-07-27-defunctionalization-in-elm/happy.png)](/assets/images/2019-07-27-defunctionalization-in-elm/happy.png)

## Conclusion

To recap, we were making our lives unnecessarily hard by

* using parameterized `msg` types
* sending functions that used them around in `Msg`s
* and then had to create Rube Goldberg machines to `Cmd.map` the Msg types around correctly.

![Rube Goldberg machine](/assets/images/2019-07-27-defunctionalization-in-elm/rube.jpg)

To get out of this mess, we defunctionalized by

* creating a datatype for all the various functions we needed to pass (`FetchAction`)
* creating a function that used them (`fetch : FetchAction -> ...`)
* passed the datatype around instead of the functions
* applied the new function with the datatype instead of running the old, now nonexistent functions directly

Defunctionalization has other benefits than just simplifying type signatures. For example it allows you to serialize the action and send it over the wire if you need to!

----

I encourage you to watch the [talk about defunctionalization](http://www.pathsensitive.com/2019/07/the-best-refactoring-youve-never-heard.html) if you haven't yet. It has more examples of defunctionalization in practice - which is always great for cementing a new concept in your head. Also sorry for probably a bit rushed blogpost - I was just excited by this simplification of our code and wanted to share it, without sharing too many unnecessary details. Hopefully I've managed to do that!
