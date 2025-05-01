# Elm test distributions

...in which I'll tell you how you can make sure your property based tests _are_ testing the interesting cases.

Recently I was discussing [a TigerBeetle article on swarm testing](https://tigerbeetle.com/blog/2025-04-23-swarm-testing-data-structures/) with [Jeroen Engels](https://jfmengels.net/) on the Elm Slack, and at one point, reading the paragraph:

> For example, one weakness of our test above is that we chose to pop and push with equal probability. As a result, our queue is very short on average. We never exercise large queues!

He asked:

> How does one detect which situations are or aren't covered in practice by property-based tests? Like, when would you say "the distribution we have doesn't cover this case"?

How do you indeed! You could use [`Fuzz.examples`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Fuzz#examples) to visually check whether the generated values make sense to you:

```elm
-- inside Elm REPL
> import Fuzz
> Fuzz.examples 10 (Fuzz.intRange 0 10)
[4,6,3,6,9,9,9,3,3,6]
    : List Int
```

but did you just get unlucky and saw no 0 and 10, or do they never get generated?

----

To build the motivation a little bit, let's try and see the issue from the TigerBeetle blogpost. Assume we have a Queue implementation (the details don't matter):

```elm
type Queue a
empty  : Queue a
push   : a -> Queue a -> Queue a
pop    : Queue a -> (Maybe a, Queue a)
length : Queue a -> Int
```

Now let's try to test it!

```elm
type QueueOp
    = Push Int
    | Pop

queueOpFuzzer : Fuzzer QueueOp
queueOpFuzzer =
    Fuzz.oneOf
        [ Fuzz.map Push Fuzz.int
        , Fuzz.constant Pop
        ]

applyOp : QueueOp -> Queue Int -> Queue Int
applyOp op queue =
    case op of
        Push n ->
            Queue.push n queue

        Pop -> 
            Queue.pop queue
                |> Tuple.second

queueFuzzer : Fuzzer (Queue Int)
queueFuzzer =
    Fuzz.list queueOpFuzzer
        -- would generate [ Push 10, Pop, Pop, Push 5 ] etc.
        |> Fuzz.map (\ops -> List.foldl applyOp Queue.empty ops)
        -- instead generates a queue with the ops applied
```

The `queueFuzzer` makes a sort of random walk through the ops to arrive at a random Queue.

Now if we were worried we're not testing very interesting cases, we could debug-print their lengths and look at the logs real hard and make a gut decision about whether it's fine, but doesn't that feel a bit icky?

Well, you can instead get this lovely table:

```
Distribution report:
====================
  length 2-5:     37%  (370x)  ███████████░░░░░░░░░░░░░░░░░░░
  length 0:     29.6%  (296x)  █████████░░░░░░░░░░░░░░░░░░░░░
  length 1:     22.8%  (228x)  ███████░░░░░░░░░░░░░░░░░░░░░░░
  length 6-10:   9.7%   (97x)  ███░░░░░░░░░░░░░░░░░░░░░░░░░░░
  length 11+:    0.9%    (9x)  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
```

when you use [`Test.reportDistribution`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Test#reportDistribution) in your test:

```elm
Test.reportDistribution
    [ ( "length 0",    \q -> length q == 0 )
    , ( "length 1",    \q -> length q == 1 )
    , ( "length 2-5",  \q -> length q >= 2 && length q <= 5 )
    , ( "length 6-10", \q -> length q >= 6 && length q <= 10 )
    , ( "length 11+",  \q -> length q >= 11 )
    ]
```

What's more, you can also make the tests fail when something's not tested enough:

```
✗ Queue example 2
    Distribution of label "length 11+" was insufficient:
      expected:  10.000%
      got:       1.400%.

    (Generated 1000 values.)
```

using [`Test.expectDistribution`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Test#expectDistribution):

```elm
Test.expectDistribution
    [ ( Test.Distribution.atLeast 10, "length 0",    \q -> length q == 0 )
    , ( Test.Distribution.atLeast 10, "length 1",    \q -> length q == 1 )
    , ( Test.Distribution.atLeast 10, "length 2-5",  \q -> length q >= 2 && length q <= 5 )
    , ( Test.Distribution.atLeast 10, "length 6-10", \q -> length q >= 6 && length q <= 10 )
    , ( Test.Distribution.atLeast 10, "length 11+",  \q -> length q >= 11 )
    ]
```

----

With all of the secrets out, let me now properly introduce you to [`Test.Distribution`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Test-Distribution). It's a relatively new addition to the Elm test library API (added in [v2.0.0](https://github.com/elm-explorations/test/blob/master/CHANGELOG.md), has been 3 years already, wow) which lets you measure or alternatively _enforce_ how often each interesting case needs to happen.

This was ported over from Haskell QuickCheck (of course), where this is done with functions like [`label`](https://hackage.haskell.org/package/QuickCheck-2.15.0.1/docs/Test-QuickCheck.html#v:label) and [`checkCoverage`](https://hackage.haskell.org/package/QuickCheck-2.15.0.1/docs/Test-QuickCheck.html#v:checkCoverage), and there's an amazing talk ["Building on developers' intuitions to create effective property-based tests"](https://www.youtube.com/watch?v=NcJOiQlzlXQ) by John Hughes (of _course_) that explains the idea further.

----

Before I get to the actual [`Test.Distribution`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Test-Distribution) stuff, let me also say that in addition to the [`Fuzz.examples`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Fuzz#examples) mentioned earlier there's also [`Fuzz.labelExamples`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Fuzz#labelExamples) which you can use in the REPL to see an example of each labelled case (if it occurs):

```elm
Fuzz.labelExamples 100
    [ ( "Lower boundary (1)", \n -> n == 1 )
    , ( "Upper boundary (20)", \n -> n == 20 )
    , ( "In the middle (2..19)", \n -> n > 1 && n < 20 )
    , ( "Outside boundaries??", \n -> n < 1 || n > 20 )
    ]
    (Fuzz.intRange 1 20)
-->
[ ( [ "Lower boundary (1)" ], Just 1 )
, ( [ "Upper boundary (20)" ], Just 20 )
, ( [ "In the middle (2..19)" ], Just 3 )
, ( [ "Outside boundaries??" ], Nothing )
]
```

As you can see, each case consists of a label and a predicate. These can overlap:

```elm
Fuzz.labelExamples 100
    [ ( "fizz", \n -> (n |> modBy 3) == 0 )
    , ( "buzz", \n -> (n |> modBy 5) == 0 )
    ]
    (Fuzz.intRange 1 20)
-->
[ ( [ "fizz" ], Just 3 )
, ( [ "buzz" ], Just 10 )
, ( [ "fizz, buzz" ], Just 15 )
]
```

You can use these classifiers in your test suites: [`Test.fuzzWith`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Test#fuzzWith) has a `distribution` field where you can choose between:

* [`noDistribution`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Test#noDistribution): the default
* [`reportDistribution`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Test#reportDistribution): shows a histogram of which label happens how often
* [`expectDistribution`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Test#expectDistribution): fails the test if a labelled case doesn't happen as specified:
    * [`atLeast`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Test-Distribution#atLeast): N% of the time or more
    * [`zero`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Test-Distribution#zero): never
    * [`moreThanZero`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Test-Distribution#moreThanZero): at least once

----

Let's see some more examples. [`Test.reportDistribution`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Test#reportDistribution) used in the following way:

```elm
Test.fuzzWith
    { runs = 10000
    , distribution =
        Test.reportDistribution
            [ ( "fizz", \n -> (n |> modBy 3) == 0 )
            , ( "buzz", \n -> (n |> modBy 5) == 0 )
            , ( "even", \n -> (n |> modBy 2) == 0 )
            , ( "odd", \n -> (n |> modBy 2) == 1 )
            ]
    }
    (Fuzz.intRange 1 20)
    "Fizz buzz even odd"
    (\n -> Expect.pass)
```

will show the following histogram:

```
Distribution report:
====================
  even:             50.2%  (5017x)  ███████████████░░░░░░░░░░░░░░░
  odd:              49.8%  (4983x)  ███████████████░░░░░░░░░░░░░░░
  fizz:             30.1%  (3011x)  █████████░░░░░░░░░░░░░░░░░░░░░
  buzz:             19.2%  (1924x)  ██████░░░░░░░░░░░░░░░░░░░░░░░░

Combinations (included in the above base counts):
  fizz, even:       15.2%  (1524x)  █████░░░░░░░░░░░░░░░░░░░░░░░░░
  fizz, odd:        10.1%  (1013x)  ███░░░░░░░░░░░░░░░░░░░░░░░░░░░
  buzz, even:        9.5%   (949x)  ███░░░░░░░░░░░░░░░░░░░░░░░░░░░
  buzz, odd:           5%   (501x)  ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░
  fizz, buzz, odd:   4.7%   (474x)  █░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
```

As you would expect, of the 20 numbers in the range `1..20`,

* there are 10 even and 10 odd ones
  * the labels `even` and `odd` should happen with probability 10/20 (50% of the time), though the real counts will vary slightly due to randomness
* there are 6 multiples of 3
  * the label `fizz` should happen with probability 6/20 (30% of the time)
* there are 4 multiples of 5
  * the label `buzz` should happen with probability 4/20 (20% of the time)

> Note the combinations are disjoint in a sense: the hits for `fizz, buzz, odd` _aren't_ counted in `fizz, odd` and that's why `fizz, odd` only shows around 10% probability instead of the expected 15%: `fizz, buzz, odd` has stolen the missing 5% from it as a more specific combination of labels.

----

Distributions are more useful when you enforce them instead of just reporting them. Use [`Test.expectDistribution`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Test#expectDistribution):

```elm
Test.fuzzWith
    { runs = 100
    , distribution =
        Test.expectDistribution
            [ ( Test.Distribution.atLeast 4, "low", \n -> n == 1 )
            , ( Test.Distribution.atLeast 4, "high", \n -> n == 20 )
            , ( Test.Distribution.atLeast 80, "in between", \n -> n > 1 && n < 20 )
            , ( Test.Distribution.zero, "outside", \n -> n < 1 || n > 20 )
            , ( Test.Distribution.moreThanZero, "one", \n -> n == 1 )
            ]
    }
    (Fuzz.intRange 1 20)
    "Int range boundaries - mandatory"
    (\n -> Expect.pass)
```

In the test above, we expect the uniform fuzzer of numbers 1..20 to produce the number 1 at least 4% of the time. If the real probability was 2%, the test would fail on grounds of distribution, even though the actual test function always passes.

> In reality the number 1 will happen 5% of the time (1/20; [`Fuzz.intRange`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Fuzz#intRange) is uniform), but it's not the best idea to enforce the exact probability that will happen, because the library tries to run the fuzzer until it's statistically sure (1 false positive in 10<sup>9</sup> runs) that the distribution is reached.
> 
> This means that instead of the default 100 fuzzed values it might end up generating thousands or millions of values to make sure. So being a bit off the real probability helps keep the test suite fast.

[`Test.expectDistribution`](https://package.elm-lang.org/packages/elm-explorations/test/2.2.0/Test#expectDistribution) won't show the table and will generally be silent, but it will complain loudly and fail the test if the wanted distribution isn't reached (even if the actual test function passes), like in the following example where I've bumped the expected probability of generating the number 1 to 10%:

```
✗ Int range boundaries - mandatory
    Distribution of label "low" was insufficient:
      expected:  10.000%
      got:       5.405%.

    (Generated 2146 values.)
```

You can see it generated 2146 values to be sure of the result, instead of the specified 100.

----

That about covers it! This post mostly wants to show that this _can be done_ in the Elm PBT testing world; if you want to dive deeper I heartily recommend the mentioned [YouTube talk](https://www.youtube.com/watch?v=NcJOiQlzlXQ) by John Hughes.
