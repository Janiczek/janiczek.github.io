# How languages work #1: String interpolation

As I'm writing my own language [Cara](https://cara-lang.com), I am forced to revisit (or learn for the first time) how programming languages _pull off_ implementing their features.

This includes things like lexing, do-notation, type inference, pattern matching and destructuring, [operator precedence](/2023/07/03/demystifying-pratt-parsers.html) and so on.

Some ideas will be quite profound while other might feel quite simple. Let's start with the latter!

## String interpolation

Let's get our problem statement out first:

```typescript
`Hello ${name}! Your name is ${name.length} letters long.`
// assuming name == "Martin", will result in:
"Hello Martin! Your name is 6 letters long."
```

That is, whenever you see the string interpolation delimiters (`${...}`), evaluate the expression inside them, convert the result to string and concatenate it with the rest of the string.

We might even take inspiration from [Python](https://docs.python.org/3/whatsnew/3.8.html#f-strings-support-for-self-documenting-expressions-and-debugging) and add a debugging variant:

```typescript
`${name=} and ${name.length=}`
// assuming name == "Martin", will result in:
"name=Martin and name.length=6"
```

## Overview

How (and where) to implement this? It seems we'll need to parse the expression _inside_ the string at some point, so that we can run it.

In the debugging variant, we'll also need access to the verbatim source code (before parsing).

We could do this in the interpreter. That would be a lot of repeated work though---all this parsing would have to be repeated everytime you encountered a string.

Skipping the parser for the moment, we could do this in the lexer, but that would breach separation of concerns: the lexer would have to know about AST nodes, how appending strings works etc.

> ⚠️ **EDIT 2023-07-28:** Hayleigh Thompson made me aware of some lexer-only approaches:
> 
> Denis Defreyne solves this with [modal lexers](https://denisdefreyne.com/articles/2022-modal-lexer/#the-string-interpolation-lexer-mode): instead of a `StringToken "one plus two is ${1+2}."` you'd have these:
> ```elm
> [ StringStart
> , StringPartLit "one plus two is "
> , StringInterpStart
> , Number 1
> , Plus
> , Number 2
> , StringInterpEnd
> , StringPartLit "."
> , StringEnd
> ]
> ```
>
> More on modal lexers also on the [Oil Shell blog](https://www.oilshell.org/blog/2017/12/17.html).
> 
> So, solving this in a lexer _does_ make a lot of sense! (I'll keep the rest of the article focused on the parser approach though, having already written it 😅.)

It feels like the parser (or some compiler stage right after parsing) is the right place to do things in: we know about details of AST at this point, and it's a preprocessing job to be done once, before any runtime looping.

Assuming our lexer has already returned a token like:

```elm
StringToken "Hello ${name}! Length: ${name.length}"
```

Our parser can take this token and do some post-processing on it: if there are no `${...}` substrings, it will just return a string expression with the contents of the token (`"Hello..."`).

But if `${...}` _is_ found, the parser will return something equivalent to:

```elm
"Hello " 
 ++ toString name
 ++ "! Length: "
 ++ toString name.length
```

And in the debugging case, a string token like:

```elm
StringToken "The ${name=} and ${name.length=}"`
```

should be post-processed to something equivalent to:

```elm
"The name=" 
 ++ toString name
 ++ " and name.length="
 ++ toString name.length
```

## Disclaimers

The above is simple to understand, and as we'll see shortly, it's just a bit fiddly with recursion and nesting.

For simplicity I'm choosing a solution that will chomp things one character at a time. There are other variants (string-splitting the contents on the `${` delimiter, [<span class="zalgo">r̸̘̔e̴̩͊g̸̯̾ȇ̴̼͇̗̈́̽x̵̺͑̆͑̈́̑͂̔̊̚è̸̺s̴̘̃</span>](https://stackoverflow.com/a/1732454) etc.); in a production-ready compiler you'll likely want to splurge on a full-fledged parser!

There are also many edge cases to handle:
* unbalanced delimiters: `"Hello ${name"`
* empty expression: `"Hello ${}"` and `"Hello ${=}"`
* escaping: `"Hello \${name}"` and `"Hello $\{name}"`
* expressions containing the delimiters: `"Hello {% raw %}${{a:1}}{% endraw %}"`
* nested strings: `"Hello ${"World"}"`
  * ...with string interpolation: `"Hello ${"World ${num}"}"`

And I won't be dealing with _those_ in this post. High-level idea only, strictly on the happy path!

## Test suite

Let's first make [a quick test suite](https://ellie-app.com/ntSW63kbRH8a1) for all the interesting (happy path) cases.

It will be a bit less unit- and a bit more end-to-end-. In it, we'll match the string input to an expected interpolated string output, _after interpreting_ with a hardcoded environment.

[![Test suite](/assets/images/2023-07-27-how-languages-work-1-string-interpolation/test-suite.png)](/assets/images/2023-07-27-how-languages-work-1-string-interpolation/test-suite.png)

For this purpose I've made a little toy language that only has expressions (that's right, you can't even bind an expression to a name).

```elm
type Expr
    = Str String
    | Int Int
    | Append Expr Expr
    | ToString Expr
    | Var String
```

The interpreter will take these and the env and turn them into a `Value`:

```elm
type Value
    = VStr String
    | VInt Int
    | VError

interpret : Dict String Value -> Expr -> Value
```

> I'm cheating here, normally you'd return `Result Error Value` instead of having `VError` be one of the values. That would only slow us down though.

And finally, the star of the show, `postprocessString : String -> Expr`.

In the above link, as our starting point, it "does nothing": it wraps the string in the `Str` Expr constructor:

```elm
postprocessString : String -> Expr
postprocessString string =
    Str string
```

And the test suite rightfully complains:

[![Failures](/assets/images/2023-07-27-how-languages-work-1-string-interpolation/failures.png)](/assets/images/2023-07-27-how-languages-work-1-string-interpolation/failures.png)

## The algorithm

Let's start fleshing the `postprocessString` function out ([Ellie](https://ellie-app.com/ntVfwhfhfKta1)).

We'll create a loop, looking at the next character, keeping track of the expression we accumulated so far (see above for the expected shape of the final product!) and of the string we need to add to that expression.

* If we see `${`, we need to update the accumulated expression and start chomping the expression to be interpolated, until we see the final `}`.
* If we see any other character, we remember it and continue.
* If we run out of characters, we update and return the accumulated expression.

[![Chomp...](/assets/images/2023-07-27-how-languages-work-1-string-interpolation/chomp.png)](/assets/images/2023-07-27-how-languages-work-1-string-interpolation/chomp.png)

Now this will look differently in various languages; Elm has neither mutation nor loops, so we do things with recursion:

```elm
postprocessString : String -> Expr
postprocessString string =
    let
        append : Maybe Expr -> Expr -> Expr
        append soFar expr =
            case soFar of
                Nothing     -> expr
                Just soFar_ -> Append soFar_ expr

        go : Maybe Expr -> String -> List Char -> Expr
        go accExpr accString todos =
            case todos of
                -- base case
                [] ->
                    append accExpr (Str accString)

                '$' :: '{' :: rest ->
                    Debug.todo "handle ${"

                whatever :: rest ->
                    go
                        accExpr
                        (accString ++ String.fromChar whatever)
                        rest
    in
    go Nothing "" (String.toList string)
```

In the middle case, we'll need to switch modes and chomp the expression to interpolate. Let's move that out to its own function:

```elm
'$' :: '{' :: rest ->
    goInner
        (Just (append accExpr (Str accString)))
        ""
        rest
```

And flesh `goInner` out in a very similar manner ([Ellie](https://ellie-app.com/ntVpTN6MLDka1)):

```elm
goInner accExpr accSource todos =
    case todos of
        -- no } found!
        [] ->
            append accExpr (Str ("${" ++ accSource))

        '}' :: rest ->
            let
                parsed : Expr
                parsed = Debug.todo "parse accSource"
            in
            go
                (Just (append accExpr (ToString parsed)))
                ""
                rest

        whatever :: rest ->
            goInner
                accExpr
                (accSource ++ String.fromChar whatever)
                rest
```

You can see that in this inner loop we're looking for the `}` ending delimiter. If we don't find one, it's potentially an error state, or we could make the `${` inert, which is what I did.

If we do find one, we now have a source code to lex and parse! (We'll deal with that in a minute.) After parsing the inner expression we'll wrap it in a call to `toString()`.

Otherwise we just continue searching for the `}` and noting the characters found along the way.

## Parsing

We now need to take the string inside `accSource` and parse it into an expression.

To not make the blogpost longer than it already is, I'm cheating again: I'm skipping the lexing phase, my `parse` function only ever parses `Var`s, and it never fails:

```elm
parse : String -> Expr
parse source =
    Var source
```

In a real language this would not fly: you'd plug in the whole machinery, thus being able to have arbitrary expressions inside (`"hello ${1 + 3}"`), and there would inevitably be some error handling to do (ie. `String -> Result ParseError Expr`).

Nevertheless, this will do for now. ([Ellie](https://ellie-app.com/ntVRSPGw7CTa1))

![Some tests passing](/assets/images/2023-07-27-how-languages-work-1-string-interpolation/some-tests-passing.png)

## Debug mode

We still haven't touched the last part: ie. the `"${name=}"` equal-sign mode.

Let's quickly add that in. We'll add a new case to `goInner`:

```elm
[]                 -> ...
'=' :: '}' :: rest -> Debug.todo "debug mode"
'}' :: rest        -> ...
whatever :: rest   -> ...
```

I'm indicating the position in which to add this case, because the order matters. Some care needs to be taken to make sure the `=` doesn't get chomped prematurely (making this newly added case never fire). Anyways, the above should be fine.

What to do inside the new case? The same parsing we did in the `'}' :: rest` case, just with a different new appended expression.

Recall the difference between the debug and non-debug interpolation in our analysis above:

```elm
"Hello {name}"
-->
"Hello " ++ toString name

"Hello {name=}"
-->
"Hello name=" ++ toString name
```

You can think of the last expression as:

```elm
"Hello " ++ "name=" ++ toString name
```

which should illustrate how to implement this. We _do_ have the source string (`"name"`) in our `accSource` variable, so instead of

```elm
append accExpr (ToString parsed)
```

we'll return:

```elm
append accExpr
    (Append
        (Str (accSource ++ "="))
        (ToString parsed)
    )
```

And would you look at that, the whole test suite is passing now! ([Ellie](https://ellie-app.com/ntW4thTRVXCa1))

![All tests passing](/assets/images/2023-07-27-how-languages-work-1-string-interpolation/all-tests-passing.png)

## Conclusion

String interpolation is relatively simple: parse the string inside your string expression, distinguishing between inert string content and the interpolation delimiters (here, `"${...}"`).

Finding the delimiters, parse the source code inside them (presumably using your _expression parser_ instead of a top-level declaration one).

Build up the final expression by appending the inert strings around the delimiters with the `toString(parsedExpression)` function calls, one for each interpolation found.

In functional terms, this could be written as:

```elm
stringContent -- "Hello ${name}! ${age=}"
    |> parseDelimiters
       {- [ Inert "Hello "
          , Interpolation "name"
          , Inert "! "
          , DebugInterpolation "age"
          ]
       -}
    |> List.concatMap parseInterpolation
       {- [ Str "Hello "
          , ToString (Var "name")
          , Str "! "
          , Str "age="
          , ToString (Var "age")
          ]
       -}
    |> List.foldr Append (Str "")
       {- Append Str "Hello "
           (Append (ToString (Var "name"))
            (Append (Str "! ")
             (Append (Str "age=")
              (Append (ToString (Var "age"))
                      (Str "")))))
       -}
```

where `parseInterpolation` would look like

```elm
parseInterpolation : StringContent -> List Expr
parseInterpolation content =
    case content of
        Inert str ->
            [ Str str ]

        Interpolation source ->
            [ ToString (parse source) ]

        DebugInterpolation source ->
            [ Str (source ++ "=")
            , ToString (parse source)
            ]
```

Happy interpolating!
