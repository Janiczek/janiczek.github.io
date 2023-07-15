# "Being clever" antipattern in Elm

*Disclaimer: I write this article based on my experience and "feels" - and thus the points might not be right and are open to discussion! In the post I say things like "Elm values X and Y" - and might be wrong. I believe I'm not though :)*

----

I sometimes lurk on the [Elm Slack](https://elmlang.slack.com) ([obligatory registration link!](https://elm-lang.org/community/slack)) and talk with people hanging there. We have the `#beginners` and `#help` channels for questions of any kind, however trivial.

Today a person wanted to optimize this expression:

```elm
List.partition ((==) 2) [1,2,3]
```

with regards to parentheses count (ie. get rid of them). A few solutions appeared:

```elm
equals2 =
    (==) 2
List.partition equals2 [1,2,3]

flip List.partition [1,2,3] <| (==) 2
```

and some judgement was made:

*"personally, the parentheses before made it easier to read and like more normal elm code"*

I understand the poster's question - he wants to see if there's a better way to write his code. I often feel this way in Haskell. Given how there are many *(many many many)* operators, there often is a way to write more succint code.

In Elm, though, there is usually One Good Way™ to do a particular thing, and it's a simple way at that.

In this particular example, the original code is probably good enough. But I would even go as far as to not use the `((==) 2)` part, and go for maximum readability. For me, that means:

```elm
List.partition (\x -> x == 2) [1,2,3]
```

The thing is, `((==) 2)` might not be too bad, but `((<) 2)` would stop me for anywhere from 5 to 30 seconds before I was sure of what it does. (*"Do I have the condition reversed in my head?"*) 

Compare it to this version, where it's immediately obvious what the function does and that it's correct.

```elm
List.partition (\x -> x < 2) [1,2,3]
```

Some functions are commutative (`a == b` is the same as `b == a`) and some are not (`a < b` vs `b < a`), and I really **really** don't want to think about *"do I have it right?"* two weeks from now just because I used the partial function application a few minutes ago and feel clever about it.

----

The same goes for "point-free" style (ommiting arguments from function definitions):

```elm
sum : List number -> number
sum =
    List.foldl (+) 0
```

Again, this particular example isn't too bad but it makes me freeze for a few seconds: *"Wait a minute, the type definition says something else than the arguments of the function!"*

I guess going a bit more silly with this example would illustrate it better:

```elm
sumWithStartingValue : number -> List number -> number
sumWithStartingValue =
    List.foldl (+)
```

I'd much rather have:

```elm
sumWithStartingValue : number -> List number -> number
sumWithStartingValue startingValue numbers =
    List.foldl (+) startingValue numbers
```

because there is absolutely zero magic, zero cleverness, zero figuring out how the particular function works.

----

Haskell has this culture of "clever is better", and sure, it allows the programs be very, **very** terse. But I don't really see the value in that, and as far as I can tell, Elm doesn't either.

Elm doesn't value writing terse code, or clever code. **Elm values readability.** If you get thoughts like *"This is so painfully explicit"*, like I do when seeing and writing code like `(\x -> x == 2)`, don't let them make you refactor it into something more clever, but less readable.
