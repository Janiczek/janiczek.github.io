# Improving Elm PRNG

_A bug is uncovered in the de facto PRNG library in the Elm language ecosystem
and alternative PRNG algorithms are suggested._

I'm not completely sure where I stumbled upon it, but I watched the [Noise-based
RNG](https://www.youtube.com/watch?v=LWFzPP8ZbdU) GDC talk this Saturday morning.

In it Squirrel Eiserloh makes a case for using stateless hash functions for
procedurally generated content.

There are some new capabilities this unlocks: the poster child example is
procedurally generated terrain in a game like Minecraft: each 2D coordinate can
have a stable terrain generated regardless of the player actions so far.

Later in the talk Squirrel asks the question, can we generate a PRNG out of a
hash function?

The answer is yes: you wrap the hash function (`hash(value: Int): Int`) into a
stateful wrapper `rng(): Int` which increments the hidden `value` everytime it's
called. Since hash functions possess the _avalanche effect_ (tiny change in
input causes a large change in the output), `hash(0)` should be wildly different
from and unrelated to `hash(1)`.

You end up with something like:

```c
// What you originally had
uint32_t hash(uint32_t value) {
  return do_something_to(value);
}

// PRNG wrapper
static uint32_t position = 0;
uint32_t rng_next() {
    return hash(position++);
}
```

where a classic PRNG like Mersenne Twister or XorShift would look more like:

```c
static state_t state = /* snip */;
uint32_t rng_next() {
    uint32_t value = read_value_from(state);
    advance(&state);
    return value;
}
```

Squirrel then claims the hash function based RNGs are more performant than the
LCG ones in his measurements, which elevated the talk from a neat idea to "let's
test it out!"

Specifically, I want to implement Squirrel's suggested hash function in
[Elm](https://elm-lang.org) and compare it to the "official" Elm PRNG in terms
of performance and randomness test batteries like
[Dieharder](https://webhome.phy.duke.edu/~rgb/General/dieharder.php) and
[TestU01](https://www.iro.umontreal.ca/~simardr/testu01/tu01.html).

All relevant code can be found in the repo [Janiczek/elm-prng-20260802](https://github.com/Janiczek/elm-prng-20260802).

## Squirrel's hash function

In the GDC talk Squirrel gives his hash function on a slide:

```cpp
unsigned int Squirrel3( int positionX, unsigned int seed )
{
    const unsigned int BIT_NOISE1 = 0x68E31DA4; // 0b0110'1000'1110'0011'0001'1101'1010'0100;
    const unsigned int BIT_NOISE2 = 0xB5297A4D; // 0b1011'0101'0010'1001'0111'1010'0100'1101;
    const unsigned int BIT_NOISE3 = 0x1B56C4E9; // 0b0001'1011'0101'0110'1100'0100'1110'1001;

    unsigned int mangledBits = (unsigned int) positionX;
    mangledBits *= BIT_NOISE1;
    mangledBits += seed;
    mangledBits ^= (mangledBits >> 8);
    mangledBits += BIT_NOISE2;
    mangledBits ^= (mangledBits << 8);
    mangledBits *= BIT_NOISE3;
    mangledBits ^= (mangledBits >> 8);
    return mangledBits;
}
```

Originally I wanted to port it directly, but then I [found
out](https://x.com/SquirrelTweets/status/1421251894274625536) he has published
[an updated version](http://eiserloh.net/noise/SquirrelNoise5.hpp) that should
behave better. So let's use that one.

Here is the relevant part:
```cpp
constexpr unsigned int SquirrelNoise5( int positionX, unsigned int seed )
{
    constexpr unsigned int SQ5_BIT_NOISE1 = 0xD2A80A3F; // 11010010101010000000101000111111
    constexpr unsigned int SQ5_BIT_NOISE2 = 0xA884F197; // 10101000100001001111000110010111
    constexpr unsigned int SQ5_BIT_NOISE3 = 0x6C736F4B; // 01101100011100110110111101001011
    constexpr unsigned int SQ5_BIT_NOISE4 = 0xB79F3ABB; // 10110111100111110011101010111011
    constexpr unsigned int SQ5_BIT_NOISE5 = 0x1B56C4F5; // 00011011010101101100010011110101

    unsigned int mangledBits = (unsigned int) positionX;
    mangledBits *= SQ5_BIT_NOISE1;
    mangledBits += seed;
    mangledBits ^= (mangledBits >> 9);
    mangledBits += SQ5_BIT_NOISE2;
    mangledBits ^= (mangledBits >> 11);
    mangledBits *= SQ5_BIT_NOISE3;
    mangledBits ^= (mangledBits >> 13);
    mangledBits += SQ5_BIT_NOISE4;
    mangledBits ^= (mangledBits >> 15);
    mangledBits *= SQ5_BIT_NOISE5;
    mangledBits ^= (mangledBits >> 17);
    return mangledBits;
}
```

Repeating Squirrel's point from the talk: to use this hash function as a PRNG,
you'd pick a `seed` at the beginning, set `position` to 0 and increment it
whenever the hash function was used. You can have multiple unrelated PRNGs by
picking different seeds (or eg. hashing a game entity ID to be the initial
seed).

I have ported it to Elm; the hash function converted to a PRNG can be found in
[`src/Random/Squirrel5.elm`](https://github.com/Janiczek/elm-prng-20260802/blob/main/src/Random/Squirrel5.elm).
It's of form `State -> (Int, State)` instead of `() -> Int` because Elm is pure
and can't hide side effects.

The numbers given by the Elm implementation agree with the C code's output; same
with all other implementations below.

## JKISS32

I can't recall which rabbit hole led me there, but somehow when reading about
Dieharder etc. I have opened the paper ["Good Practice in (Pseudo) Random Number
Generation for Bioinformatics
Applications"](http://www0.cs.ucl.ac.uk/staff/d.jones/GoodPracticeRNG.pdf).

In it the author gives a few examples of their recommended PRNGs. Most are
64bit, but there is one working on 32bit numbers and only uses additions and
shifts (no multiplications!), so let's try it - it might be a lot faster than
the multiplication-using ones? You never know.

> Note: Why 32bit numbers? Elm doesn't have access to (fast) 64bit integers, as
  it is compiled to JavaScript and JavaScript numbers are doubles (binary64 IEEE
  754 floats). The [maximum safe
  integer](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number/MAX_SAFE_INTEGER)
  is `2^53 - 1`, so we can't quite reach 64bit integers.
>
> Above that number, the doubles backing the JavaScript numbers get far enough
  from each other that `9007199254740991 + 1 === 9007199254740991 + 2`.

The paper gives the following C code for the 32bit addition-only PRNG: 

```c
static unsigned int x=123456789,y=234567891,z=345678912,w=456789123,c=0;
unsigned int JKISS32()
{
    int t;
    y ^= (y<<5); y ^= (y>>7); y ^= (y<<22);
    t = z+w+c; z = w; c = t < 0; w = t&2147483647;
    x += 1411392427;
    return x + y + w;
}
```

My Elm implementation can be found in
[`src/Random/JKISS32.elm`](https://github.com/Janiczek/elm-prng-20260802/blob/main/src/Random/JKISS32.elm).

## Elm PCG - the status quo

There is a single "blessed" Elm random number generator library:
[`elm/random`](https://package.elm-lang.org/packages/elm/random/latest/).

> There are multiple alternative PRNGs published on [package.elm-lang.org](https://package.elm-lang.org/) but we'll ignore them in this blogpost.

At least as of [version
`1.0.0`](https://github.com/elm/random/blob/1.0.0/src/Random.elm), `elm/random`
uses a variant of [PCG](https://www.pcg-random.org/) _(Permuted Congruential
Generator)_, specifically the [`RXS-M-XS`
version](https://github.com/imneme/pcg-c/blob/83252d9c23df9c82ecb42210afed61a7b42402d7/include/pcg_variants.h#L182-L186)
(check section 6.3.4 in the [PCG
paper](https://www.pcg-random.org/pdf/hmc-cs-2014-0905.pdf)) with some custom
decisions on how to initialize the RNG with just a single 32bit number instead
of two.

If code-golfed to a minimal C code, the Elm's algorithm could look like this:

```c
typedef struct { uint32_t state, incr; } elm_seed_t;

static inline void elm_next(elm_seed_t *s)
{
    double product = (double)s->state * 1664525.0; // Spoilers...
    uint64_t truncated = (uint64_t)product;
    uint32_t word = (uint32_t)(truncated & 0xFFFFFFFFu);
    s->state = word + s->incr;
}

static inline uint32_t elm_peel(uint32_t state)
{
    uint32_t xored = state ^ (state >> ((state >> 28u) + 4u));
    double product = (double)xored * 277803737.0; // Spoilers...
    uint64_t truncated = (uint64_t)product;
    uint32_t word = (uint32_t)(truncated & 0xFFFFFFFFu);
    return (word >> 22u) ^ word;
}

static void elm_initial_seed(elm_seed_t *s, uint32_t x)
{
    elm_seed_t tmp = { 0u, 1013904223u };
    elm_next(&tmp);
    tmp.state += x;
    elm_next(&tmp);
    *s = tmp;
}

static inline uint32_t elm_step_random_r(elm_seed_t *s)
{
    uint32_t out = elm_peel(s->state);
    elm_next(s);
    return out;
}
```

> There is a whole combinator library sitting on top of the `next` and `peel`
  primitives, doing some interesting bias-correcting math for returning random
  numbers in a certain range, but I'll consider these out of scope. `peel` gives
  the "raw" bits that everything else is made of, and that will be what we
  compare against the other algorithms.

You might have seen the comment and the surprisingly complex code in the `next`
and `peel` functions above. Doubles?! This is to emulate JavaScript behaviour:
the Elm code is slightly buggy because of multiplying two 32bit ints in a naive
way. 

Multiplying two 32bit integers can produce a 64bit integer, and as mentioned
above we don't have those in the JavaScript world. The numbers we get back don't
fall on the nearest integer to the true result but _get rounded_ to some
multiple of `2^n` depending on how large the result is.

The loss of precision means the current implementation of the PCG algorithm
follows a slightly different trajectory for its internal state and the generated
numbers than intended (than the canonical PCG algorithm would use for the given
seed). I don't know enough about these to _explain_ how bad it is, but as we'll
see from the Dieharder results later, it _does_ have an adverse effect on the
randomness of the generated numbers.

JavaScript has a workaround for the 32bit multiplication:
[`Math.imul()`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Math/imul).
We don't have access to it in the Elm userland, instead we need to emulate it
with bitwise operations like `&` and `>>>` (see `imul32` in
[`src/Bitwise/Extra.elm`](https://github.com/Janiczek/elm-prng-20260802/blob/main/src/Bitwise/Extra.elm)),
resulting in compiled JS code similar to this:

```typescript
function imul32(a,b) {
    var aLo = a & 0xFFFF;
    var bLo = b & 0xFFFF;
    var low = aLo * bLo;
    var aHi = a >>> 16;
    var bHi = b >>> 16;
    var high = ((aHi * bLo) + (aLo * bHi)) & 0xFFFF;
    return (low + (high * 0x10000)) >>> 0;
}
```

I only realized the bug is present when I ported the Elm PRNG to C and found it
doesn't give me the same numbers as the Elm version. Sure enough, it was that
multiplication! When stepping through both implementations and comparing the
numbers, I saw Elm give intermediate numbers like `5145799907274839000`: way too
big, and the `000` at the end was suspicious. _(I see this routinely at work
when webapps try to show big integers coming from Snowflake. Gotta love
JavaScript.)_

Changing the raw multiplications into an emulated `imul32` fixed the issue. I
have made a PR for `elm/random` (as we'll see later, the gradual loss of
precision does make a difference in the statistical tests) and continued with
the exploration; though I expect the correct fix will be to rather add a new
`Bitwise.imul` primitive to `elm/core` that will call `Math.imul()`, and use it
from `elm/random` instead of the emulated version.

Here is how you probably expected the PCG C code from above to look:

```diff
 static inline void elm_next(elm_seed_t *s)
 {
-    double product = (double)s->state * 1664525.0; // Spoilers...
-    uint64_t truncated = (uint64_t)product;
-    uint32_t word = (uint32_t)(truncated & 0xFFFFFFFFu);
-    s->state = word + s->incr;
+    s->state = s->state * 1664525u + s->incr;
 }
 
 static inline uint32_t elm_peel(uint32_t state)
 {
-    uint32_t xored = state ^ (state >> ((state >> 28u) + 4u));
-    double product = (double)xored * 277803737.0; // Spoilers...
-    uint64_t truncated = (uint64_t)product;
-    uint32_t word = (uint32_t)(truncated & 0xFFFFFFFFu);
+    uint32_t word = (state ^ (state >> ((state >> 28u) + 4u))) * 277803737u;
     return (word >> 22u) ^ word;
 }
```

That is, use integer multiplication instead of doubles.

We'll add two fixed PCG variants to the test suite and benchmarks:

1. One that uses the emulated `imul32` (expressible in "userspace" 3rd party Elm
   packages)
2. One that uses `Math.imul()`.

OK, enough talk about our contenders, let's whip out the test batteries and see
how random each implementation really is!

## Dieharder

My initial attempt was to let Elm print a large amount of random numbers into a
file, which I'd then pass to Dieharder with `-g 202`.

That's not such a good idea: the tests need you to generate _A LOT_ of
randomness. 2^30 numbers (roughly 11GB in filesize) is not enough and taints the
results. Dieharder automatically rewinds the file and sees the same numbers
repeated, which causes some tests to fail.

Another approach was necessary. Dieharder has a mode `-g 200` which consumes raw
binary data from `STDIN`. That plus the fact that I wasn't too impressed with
the speed at which Elm printed the numbers, led me to use the C versions of the
algorithms and port the Elm algorithm to C.

In the end I'm running Dieharder with the following flags:

```
$ ./jkiss32 | dieharder -k 2 -Y 1 -a -g 200
#                       ^         ^  ^^^^^^ load input from pipe
#                       ^         ^^ run all tests
#                       ^^^^^^^^^
#                       "Reduce Ambiguity" mode:
#           if WEAK, run more tests to end up at PASSED / FAILED
```

Full Dieharder reports are [in the
repository](https://github.com/Janiczek/elm-prng-20260802/tree/main/out/dieharder);
here is the summary:

| Algorithm | Passed | Weak | Failed |
|--|--:|--:|
| Elm PCG (current, buggy) | 91 | 7 | 16 |
| Elm PCG (fixed)          | 114 | 0 | 0 |
| SquirrelNoise5           | 114 | 0 | 0 |
| JKISS32                  | 114 | 0 | 0 |

I don't understand why Dieharder ignored some of the `WEAK` results, but the
picture is pretty clear anyways: the current `elm/random` PRNG is statistically
flawed due to the double multiplication bug. The other PRNGs don't seem to have
any apparent issues.

More testing is needed. Introducing: [TestU01](https://en.wikipedia.org/wiki/TestU01).

## TestU01

I ran the BigCrush test battery from TestU01 on all four algorithms [(see the
reports)](https://github.com/Janiczek/elm-prng-20260802/tree/main/out/testu01_bigcrush).

| Algorithm | Failed tests |
|--|--:|
| Elm PCG (current, buggy) |  12   |
| Elm PCG (fixed)          |   9   |
| SquirrelNoise5           |   8   |
| JKISS32                  | **0** |

A very surprising result!

First of all, given PCG's reputation I'd expect it to pass. Is it possible the
Elm implementation differs enough from the official one that it screws something
up? Another experiment using the official PCG algorithm and constants would be
needed.

Secondly, JKISS32 passes with flying colors. At least that gives us a clear
favorite when we'll next look at performance.

I don't really know what the failures mean in practice. The algorithms above
_aren't_ cryptographically secure, so I don't suppose any of them is safe from
predicting new values from previous ones etc., but maybe there could be some
bias that could realistically affect users in web app / game / simulation
scenarios?

Anyways, being naive, let's bias towards JKISS32 and go see the performance.

## Performance benchmark

I want to measure how long it takes to generate a random number and advance the
state _once_, and _1 million times_ in a typical Elm loop (that is, a tail
recursive function).

For benchmarking the Elm code I have compiled (with `elm make --optimize`) a
test program like this just to get the final JavaScript out:

```elm
import Random.CoreCurrent
import Random.CoreFixed
import Random.JKISS32
import Random.Squirrel5

coreCurrentState = Random.CoreCurrent.initialState 123456789
coreFixedState   = Random.CoreFixed.initialState   123456789
jkissState       = Random.JKISS32.initialState     123456789 234567891 345678912 456789123
squirrelState    = Random.Squirrel5.initialState   123456789

runTimes : Int -> (state -> ( Int, state )) -> state -> ()
runTimes n step state =
    if n <= 0 then
        ()

    else
        let
            ( generatedValue, newState ) =
                step state
        in
        runTimes (n - 1) step newState

runCoreCurrent_1 () = let _ = Random.CoreCurrent.step coreCurrentState in ()
runCoreFixed_1   () = let _ = Random.CoreFixed.step   coreFixedState   in ()
runJKISS32_1     () = let _ = Random.JKISS32.step     jkissState       in ()
runSquirrel5_1   () = let _ = Random.Squirrel5.step   squirrelState    in ()

runCoreCurrent_N n = runTimes n Random.CoreCurrent.step coreCurrentState
runCoreFixed_N   n = runTimes n Random.CoreFixed.step   coreFixedState
runJKISS32_N     n = runTimes n Random.JKISS32.step     jkissState
runSquirrel5_N   n = runTimes n Random.Squirrel5.step   squirrelState

main =
    let
        -- Just to prevent them from being dead-code-eliminated.
        _ = runCoreCurrent_1 ()
        _ = runCoreFixed_1   ()
        _ = runJKISS32_1     ()
        _ = runSquirrel5_1   ()
        _ = runCoreCurrent_N 1
        _ = runCoreFixed_N   1
        _ = runJKISS32_N     1
        _ = runSquirrel5_N   1
    in
    -- A necessary boilerplate to compile an Elm program
    Platform.worker
        { init = \() -> ( (), Cmd.none )
        , update = \_ _ -> ( (), Cmd.none )
        , subscriptions = \_ -> Sub.none
        }
```

Then I hand-picked the relevant parts into [a JavaScript
file](https://github.com/Janiczek/elm-prng-20260802/blob/main/mitata-benchmark.mjs)
and used [`mitata`](https://github.com/evanwashere/mitata) to benchmark it.

I kept the loops and function calls Elm-style instead of idiomatic JavaScript,
to measure the realistic Elm behaviour one can reach.

Here are the results. I'm striking through the current `elm/random` code because
while it's fastest, I'd prefer correctness over performance.

| Algorithm | 1x [ns] | 1 000 000x [ms] |
|--|--:|--:|
| `elm/random` PCG (current, buggy)     | ~~2.00~~ | ~~10.62~~ |
| `elm/random` PCG (fixed, userspace)   |   7.05   |   19.07   |
| `elm/random` PCG (fixed, `Math.imul`) | **1.94** |   16.45   |
| JKISS32                               |   3.42   |   21.88   |
| SquirrelNoise5                        |   5.54   | **12.22** |

Box plots reported by Mitata:

<span class="next-two-code-blocks-have-box-drawing" />

```plaintext
1x

                   ┌                                            ┐
                   ╷┬
       coreCurrent ├│
                   ╵┴
                                           ╷┌─┬                 ╷
coreFixedUserspace                         ├┤ │─────────────────┤
                                           ╵└─┴                 ╵
                   ┌┬
   coreFixedNative ││
                   └┴
                          ╷┬            ╷
           jkiss32        ├│────────────┤
                          ╵┴            ╵
                                     ┌┬             ╷
         squirrel5                   ││─────────────┤
                                     └┴             ╵
                   └                                            ┘
                   1.83 ns            6.21 ns            10.59 ns
```

```plaintext
1000000x

                   ┌                                            ┐
                   ╷┬╷
       coreCurrent ├│┤
                   ╵┴╵
                                                   ┌┬╷
coreFixedUserspace                                 ││┤
                                                   └┴╵
                                         ┌┬┐╷
   coreFixedNative                       ││├┤
                                         └┴┘╵
                                                              ┌┬╷
           jkiss32                                            ││┤
                                                              └┴╵
                         ╷┬╷
         squirrel5       ├│┤
                         ╵┴╵
                   └                                            ┘
                   10.43 ms           16.30 ms           22.18 ms
```

The current `elm/random` algorithm is really fast compared to all the others. I
think it also must have to do with lack of function calls (which in Elm-produced
JavaScript sometimes end up doing extra logic around arity due to partial
application) in its implementation.

If I had to pick from the rest and `JKISS32`'s BigCrush test results weren't
enough reason to pick it (or at least disqualify the rest and go search for
another function), `Squirrel5` seems to have great performance across multiple
runs although it's not the fastest one in the "1x" test.

> Note these numbers will surely be wildly different from their C counterparts:
  we're operating in a GC'd interpreted language with a JIT...

## Final results

We learned there's a bug in the `elm/random` PRNG implementation, causing it to
fail the Dieharder randomness test suite.

We learned that even fixing this bug doesn't make it pass the TestU01 randomness
test suite, something we'd expect from the PCG family of PRNGs. Further
exploration of how the Elm implementation differs from the official one is
needed.

We learned about using hash functions as PRNGs; it can be surprisingly fast
(likely because virtually all the work is hidden in the generation, incrementing
an integer to advance the state is negligible).

This whole journey is probably not enough to conclusively say there is a clear winner, a function that (in context of JavaScript) provides the best performance while passing all the randomness tests. Maybe there is one out there, but we didn't find it today.

## Addendum: JavaScript bitwise tricks

Here are JavaScript snippets for converting numbers to unsigned and signed 32bit
numbers with its bitwise operators, which you might be familiar with from
[asm.js](https://en.wikipedia.org/wiki/Asm.js):

```typescript
const toU32 = (n) => n >>> 0;
const toI32 = (n) => n | 0;

// 0xFFFFFFFF     == 4294967295
// 0xFFFFFFFF | 0 == -1
// -1 >>> 0       == 4294967295

// 0x100000000       == 4294967296
// 0x100000000 | 0   == 0
// 0x100000000 >>> 0 == 0
```
