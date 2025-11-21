# FAWK: LLVMs can write a language interpreter

After reading the book [The AWK Programming Language](https://www.awk.dev/)
_(recommended!)_, I was planning to try [AWK](https://en.wikipedia.org/wiki/AWK)
out on this year's Advent of Code. Having some time off from work this week, I
tried to implement [one of the problems](https://adventofcode.com/2016/day/22)
in it to get some practice, set up my tooling, see how hard AWK would be,
and... I found I'm FP-pilled.

I _knew_ I'm addicted to the combination of algebraic data types (tagged unions)
and exhaustive pattern matching, but what got me this time was immutability,
lexical scope and the basic human right of being allowed to return arrays from
functions.

Part 1 of the Advent of Code problem was easy enough, but for part 2 (basically
a shortest path search with a twist, to not spoil too much), I found myself
unable to switch from my usual [functional BFS
approach](/2023/06/27/fp-pattern-list-of-todos.html)
to something mutable, and ended up trying to implement my functional approach in
AWK.

It got hairy very fast: I needed to implement:
* hashing of strings and 2D arrays (by piping to `md5sum`)
* a global ~set~ array of seen states
* a way to serialize and deserialize a 2D array to/from a string
* and a few associative arrays for retrieving this serialized array by its
  hash.

I was very lost by the time I had all this; I spent hours just solving what felt
like _accidental complexity_; things that I'd take for granted in more modern
languages.

Now, I know nobody said AWK is modern, or functional, or that it promises any
convenience for anything other than one-liners and basic scripts that fit under
a handful of lines. I don't want to sound like I expect AWK to do any of this;
I knew I was stretching the tool when going in. But I couldn't shake the feeling
that there's a beautiful AWK-like language within reach, an iteration on the AWK
design (the pattern-action way of thinking is beautiful) that also gives us a
few of the things programming language designers have learnt over the 48 years
since AWK was born.

## Dreaming of functional AWK

Stopping my attempts to solve the AoC puzzle in pure AWK, I wondered: what am I
missing here?

What if AWK had **first-class arrays?**

```awk
BEGIN {
  # array literals
  normal   = [1, 2, 3]
  nested   = [[1,2], [3,4]]
  assoc    = ["foo" => "bar", "baz" => "quux"]
  multidim = [(1,"abc") => 999]

  five = range(1,5)
  analyze(five)
  print five  # --> still [1, 2, 3, 4, 5]! was passed by value
}

function range(a,b) {
  r = []
  for (i = a; i <= b; i++) {
    r[length(r)] = i
  }
  return r  # arrays can be returned!
}

function analyze(arr) {
  arr[0] = 100
  print arr[0]  # --> 100, only within this function
}
```

What if AWK had **first-class functions and lambdas?**

```awk
BEGIN {
  # construct anonymous functions
  double = (x) => { x * 2 }
  add = (a, b) => { c = a + b; return c }

  # functions can be passed as values
  apply = (func, value) => { func(value) }

  print apply(double,add(1,3))  # --> 8
  print apply(inc,5)  # --> 6
}

function inc(a) { return a + 1 }
```

What if AWK had **lexical scope** instead of dynamic scope?

```awk
# No need for this hack anymore ↓     ↓
#function foo(a, b         ,local1, local2) {
function foo(a, b) {
  local1 = a + b
  local2 = a - b
  return local1 + local2
}

BEGIN {
  c = foo(1,2)
  print(local1)  # --> 0, the local1 from foo() didn't leak!
}
```

What if AWK had **explicit globals**, and everything else was **local by default?**

```awk
BEGIN { global count }
END {
  foo()
  print count  # --> 1
  print mylocal # --> 0, didn't leak
}
function foo() { count++; mylocal++ }
```

(This one, admittedly, might make programs a bit more verbose. I'm willing to
pay that cost.)

What if AWK had **pipelines?** (OK, now I'm reaching for syntax sugar...)

```awk
BEGIN {
  result = [1, 2, 3, 4, 5] 
      |> filter((x) => { x % 2 == 0 })
      |> map((x) => { x * x })
      |> reduce((acc, x) => { acc + x }, 0)

  print "Result:", result
}
```

## Making it happen

> TL;DR: [`Janiczek/fawk` on GitHub](https://github.com/Janiczek/fawk)

Now for the crazy, LLM-related part of the post. I didn't want to spend days
implementing AWK from scratch or tweaking somebody else's implementation. So I
tried to use Cursor Agent for a larger task than I usually do (I tend to ask
for very small targeted edits), and asked Sonnet 4.5 for [a README with code
examples](https://github.com/Janiczek/fawk/pull/1/files), and then [a full
implementation in Python](https://github.com/Janiczek/fawk/pull/2/files).

And it did it.

> Note: I also asked for implementations in C, Haskell and Rust at the same
> time, not knowing if any of the four would succeed, and they all seem to have
> produced code that at least compiles/runs. I haven't tried to test them or
> even run them though. The PRs are
> [here](https://github.com/Janiczek/fawk/pulls?q=is%3Apr+is%3Aclosed).

I was very impressed---I still am! I expected the LLM to stumble and flail
around and ultimately get nothing done, but it did what I asked it for (gave me
an interpreter that could run _those specific examples_), and over the course
of a few chat sessions, I guided it towards implementing more and more of "the
rest of AWK", together with an excessive amount of end-to-end tests.

[Take a look at those tests!](https://github.com/Janiczek/fawk/tree/main/tests)

The only time I could see it struggle was when I asked it to implement arbitrary
precision floating point operations without using an external library like
`mpmath`. It attempted to use Taylor series, but couldn't get it right for at
least a few minutes. I chickened out and told it to `uv add mpmath` and simplify
the interpreter code. In a moment it was done.

Other things that I thought it would choke on, like `print` being both a
statement (with `>` and `>>` redirection support) and an expression, or
multi-dimensional arrays, or multi-line records, these were all implemented
correctly. Updating the test suite to also check for backwards compatibility
with [GAWK](https://www.gnu.org/software/gawk/) - not an issue. Lexical scoping
and tricky closure environment behaviour - handled that just fine.

## What now?

As the cool kids say, I have to _update my priors._ The frontier of what the
LLMs can do has moved since the last time I tried to vibe-code something. I
didn't expect to have a working interpreter _the same day_ I dreamt of a new
programming language. It now seems possible.

The downside of vibe coding the whole interpreter is that I have zero knowledge
of the code. I only interacted with the agent by telling it to implement a
thing and write tests for it, and I only _really_ reviewed the tests. I reckon
this would be an issue in the future when I want to manually make some change
in the actual code, because I have no familiarity with it.

> This also opened new questions for me wrt. my other projects where I've
previously run out of steam, eg. trying to implement a [Hindley-Milner type
system](https://en.wikipedia.org/wiki/Hindley%E2%80%93Milner_type_system) for my
dream forever-WIP programming language [Cara](https://cara-lang.com/). It seems
I can now just ask the LLM to do it, and it will? But then, I don't want to fall
into the trap where I am no longer able to work on the codebase myself. I want
to be familiar with and able to tinker on the code. I'd need to spend my time
reviewing and reading code instead of writing everything myself. Perhaps that's
OK.

Performance of FAWK might be an issue as well, though right now it's a non-goal,
given my intended use case is throwaway scripts for Advent of Code, nothing
user-facing.  And who knows, based on what I've seen, maybe I can instruct it to
_rewrite it in Rust_ and have a decent chance of success?

For now, I'll go dogfood my shiny new vibe-coded black box of a programming
language on the Advent of Code problem (and as many of the 2025 puzzles as I
can), and see what rough edges I can find. I expect them to be equal parts "not
implemented yet" and "unexpected interactions of new PL features with the old
ones".

If you're willing to jump through some Python project dependency hoops, you can
try to use FAWK too at your own risk, at [`Janiczek/fawk` on
GitHub](https://github.com/Janiczek/fawk).
