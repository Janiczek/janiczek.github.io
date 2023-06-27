## Union types antipattern in Elm

So, lately I've been creating a microsite for my employer's conference. That seemed like a great place for sneaking some Elm in (no JS-only people to talk me out of it), and guess what - **it is!** I'm absolutely loving it so far.

During the development of a tab view, I dared make an union type:

```elm
type Town
    = Ostrava
    | Praha
```

Motivation: we have a tab for each town, and only one is visible at one time. So this would serve as an ID for whatever function is working with the towns.

So far, this has been a no-brainer. The problems started to crop up when I wanted to connect this to the model. My first try led me into a blind alley of runtime checks and unnecessary Maybe wrappers for things I *KNEW* were going to be found. The second try was much cleaner and, retrospectively, obvious, but... **this is the story of the first try.**

----

You see, I started with this:

```elm
type alias Model =
    { towns :
        { ostrava : TownInfo
        , praha : TownInfo
        }
    }


type alias TownInfo =
    { score : Int
    , selected : Bool
    }
```

(For the purposes of this post, I'll set the goal of getting a score for the currently selected town.)

It seemed okay. But it leads to:

```elm
score : Model -> Int
score model =
    if model.towns.ostrava.selected then
        model.towns.ostrava.score
    else if model.towns.praha.selected then
        model.towns.praha.score
    else
        {- pick one of the two above and use it as a default?
           ... or wrap everything here in Maybe and
           have THAT propagate above?
        -}
        ???
```

As you can imagine, this is quite error-prone. You can forget to add a new `if`, and the compiler won't tell you. It can't enumerate over a record!

You might not give up so easily though. Let's give this one more try.

```elm
score : Model -> Int
score model =
    let
        { ostrava, praha } =
            model.towns

        towns =
            [ ( Ostrava, ostrava.selected )
            , ( Praha, praha.selected )
            ]
    in
        towns
            |> List.filter (\( town, selected ) -> selected)
            |> List.head
            |> Maybe.map Tuple.first
            |> Maybe.withDefault Ostrava -- kinda arbitrary
```

This whole `Maybe` stuff seems absolutely unnecessary! And again, you're enumerating the cases of the union type by hand - this is error-prone, you can forget some, and by putting it into a list you have to jump through hoops just to make the compiler certain you didn't shoot yourself in a foot.

----

The right thing to do? **Have the selected ID be more top-level.**

```elm
type alias Model =
    { selectedTown : Town
    , towns :
        { ostrava : TownInfo
        , praha : TownInfo
        }
    }


type alias TownInfo =
    { score : Int }
```


You can then use functions which use compiler's exhaustiveness checking with the `case town of ...` pattern:

```elm
score : Model -> Int
score model =
    case model.selectedTown of
        Ostrava ->
            model.towns.ostrava.score

        Praha ->
            model.towns.praha.score
```

Suddenly all the hard stuff is gone. Writing this was so easy it's almost embarassing I didn't think of it the first time. But hey, experience comes with practice!

----

All in all, this ties back to Richard Feldman's talk ["Making Impossible States Impossible"](https://www.youtube.com/watch?v=IcgmSRJHu_8). With the final model, it's *guaranteed* you can only have *one town selected.* With the former model, you could have *any number of the towns selected!* A bug in your app could make none or all of them selected, and the compiler was right to give you trouble with all the Maybe stuff!

So, the conclusion is: **pay attention to how easy it is to write stuff!** If it doesn't want to come out nicely, there's probably a better pattern hiding.

And remember: if in doubts, ask on the [Elm Slack](https://elmlang.slack.com) ([registration](https://elm-lang.org/community/slack)) - we're a friendly bunch! :)
