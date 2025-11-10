# Writing your own BEAM

This is my [Code BEAM Europe 2025](https://codebeameurope.com/) talk, converted to a blogpost.

I was always fascinated with BEAM, how it allowed easy spawning of processes that didn't share state, allowed for sending and selectively receiving messages, and linking to each other thus enabling creation of supervision trees.

It's an interesting set of primitives that interact in a nice way, and are in my view responsible for much of the appeal of BEAM languages. I wanted to see how much it takes to support these primitives, and I set out to write my own toy MVP implementation of BEAM.

As a disclaimer, I haven't read [The BEAM Book](https://blog.stenmans.org/theBeamBook/) yet, and how I do things might differ substantially from how the real BEAM does things. This is an exploration from first principles based on how I perceive BEAM from the outside, and doesn't aim for truthfulness to the reference implementation, real world usefulness nor performance.

The below examples are written in Elm, but if you can express it in Elm, you can express it in anything (it's purely functional so there's no mutation, it's single threaded and has no concurrency primitives, etc.).

## AST representation

I will only be making the scheduler and its main loop, not a full-blown language or VM. This allows me to only **keep a few hardcoded examples around** and skip writing a parser, CLI and a bunch more parts that a real compiler would have.

In the interest of skipping as much work as possible, I'll be using **continuation passing style (CPS)** for the example programs instead of the usual "list of statements" style:

```elm
-- ☑️ YES: continuations
type Program
    = End
    | Work Int K
    | Spawn Program KPid
    | Send Pid String K
    | Receive String K
    | Crash
    | Link Pid K

type alias K =
    () -> Program

type alias KPid =
    Pid -> Program

-- ❌ NO: list of statements
type Stmt
    = Let String Expr
    | Work Int
    | Spawn Program
    | Send Pid String
    | Receive String Program
    | Crash
    | Link Pid

type alias Program =
    List Stmt
```

This means I don't have to care about environments, bindings, scopes, return values, expressions and so on, as this will be handled by the continuation arguments in the host language:

```elm
ex5 : Program
ex5 =
    Spawn ex5Child       <| \childPid ->
    Send childPid "Ping" <| \() ->
    End

ex5Child =
    Work 10 <| \() ->
    End
```

In case you're having issues reading the `<|` operator, you can imagine a pair of parentheses instead:

```elm
ex5 : Program
ex5 =
    Spawn ex5Child       (\childPid ->
    Send childPid "Ping" (\() ->
    End
    ))

ex5Child =
    Work 10 (\() ->
    End
    )
```

## Instruction: `End`

The continuations in all the non-terminal instructions force us to provide at least one terminal, otherwise we couldn't write a valid `Program` value.

Let's then start by implement one of the terminals, `End`. It's a no-op, but it will allow me to show off the structure of the scheduler.

```elm
type Program =
    End

ex1 : Program
ex1 =
    End

type alias Scheduler =
    { program : Program }

init : Program -> Scheduler
init program =
    { program = program }

step : Scheduler -> Scheduler
step sch =
    case sch.program of
        End -> sch
```

[Try it online,](https://ellie-app.com/x4ykjfHJ5Sra1) or try the visualizer below:

<script>
let app = null;
</script>

<script src="/assets/js/WritingYourOwnBeamDemo1.elm.js"></script>
<div class="theme_fullscreen">
    <div id="demo1" style="color: red">Oh no, the visualizer didn't load!</div>
</div>
<script>
app = Elm.WritingYourOwnBeam.Demo1.init({
    node: document.getElementById('demo1'),
});
app.ports.jumpToBottomOfTraces.subscribe((traceId) => {
    document.getElementById(traceId).scrollTop = document.getElementById(traceId).scrollHeight;
});
</script>

Everything will revolve around this `Scheduler` type and its `step` function. Now let's expand our capabilities.

## Instruction: `Work`

Instead of wasting time implementing instructions for _actual_ work (mathematic operators, function calls, etc.), let's encompass this all with a dummy `Work` instruction, holding the amount of work (in units that will start making sense soon) and a continuation with what to do after the work:

```elm
type Program
    = End
    -- Added:
    | Work Int K

type alias K =
    () -> Program

ex2 : Program
ex2 =
    Work 5 <| \() ->
    End
```

The example holds a program that will "work" for 5 units of work then end.

We need to add this new instruction to our `step` function:

```elm
step : Scheduler -> Scheduler
step sch =
    case sch.program of
        End -> sch
        -- Added:
        Work n k -> { sch | program = k () }
```

For now we'll just ignore how much work it's supposed to be, and continue with the rest of the program (result of calling the continuation: `k ()`).

[Try it online,](https://ellie-app.com/x4LP34t3QhPa1) or try the visualizer below: 

<script src="/assets/js/WritingYourOwnBeamDemo2.elm.js"></script>
<div class="theme_fullscreen">
    <div id="demo2" style="color: red">Oh no, the visualizer didn't load!</div>
</div>
<script>
app = Elm.WritingYourOwnBeam.Demo2.init({
    node: document.getElementById('demo2'),
});
app.ports.jumpToBottomOfTraces.subscribe((traceId) => {
    document.getElementById(traceId).scrollTop = document.getElementById(traceId).scrollHeight;
});
</script>

## Instruction: `Spawn`

Let's do something _interesting_! We'll add a way to spawn other processes, thus making our programs concurrent.

```elm
type Program =
    -- ...
    | Spawn Program KPid

type alias KPid =
    Pid -> Program

type alias Pid =
    Int

ex3 : Program
ex3 =
    Work 5         <| \() ->
    Spawn ex3Child <| \childPid ->
    Work 5         <| \() ->
    End

ex3Child : Program
ex3Child =
    Work 10 <| \() ->
    Work 10 <| \() ->
    End
```

Whenever we spawn another process, we'll receive its PID in the continuation, which will be useful later for messaging and other tasks.

This marks a big change in our `Scheduler`: suddenly we have to track multiple processes instead of just one!

```elm
type alias Scheduler =
    { processes : Dict Pid Proc
    , nextUnusedPid : Pid
    , readyQueue : Queue Pid
    }

type alias Proc =
    { program : Program }

init : Program -> Scheduler
init program =
    { processes = Dict.empty
    , nextUnusedPid = 0
    , readyQueue = Queue.empty
    }
        |> spawn program
        |> Tuple.first -- discard the spawned PID

spawn : Program -> Scheduler -> ( Scheduler, Pid )
spawn program sch =
    let pid = sch.nextUnusedPid in
    ( { sch
        | processes =
            sch.processes
                |> Dict.insert pid (initProc program)
        , nextUnusedPid = pid + 1
      }
        |> enqueue pid
    , pid
    )

initProc : Program -> Proc
initProc program =
    { program = program }

enqueue : Pid -> Scheduler -> Scheduler
enqueue pid sch =
    { sch
        | readyQueue =
            if List.member pid (Queue.toList sch.readyQueue)
            then sch.readyQueue
            else sch.readyQueue |> Queue.enqueue pid
    }
```

We hold the processes in a `Dict` collection now, there's a bit of bookkeeping for incrementing PIDs, and a new concept: the "ready queue."

This queue will tell our scheduler which process to run next. This means our `step` function needs to change considerably: previously it was able to just pick the (only) program with `sch.program`, but now it needs to pick a PID from the queue, then find it in the dictionary, _then_ run it:

```elm
step : Scheduler -> Scheduler
step sch =
    case Queue.dequeue sch.readyQueue of
        Nothing -> sch
        Just ( pid, restOfQueue ) ->
            let newSch = { sch | readyQueue = restOfQueue } in
            case Dict.get pid newSch.processes of
                Nothing   -> newSch
                Just proc -> newSch |> stepInner pid proc

stepInner : Pid -> Proc -> Scheduler -> Scheduler
stepInner pid proc sch =
    case proc.program of
        End -> sch

        Work n k ->
            sch
                |> updateProc pid (setProgram (k ()))
                |> enqueue pid

updateProc : Pid -> (Proc -> Proc) -> Scheduler -> Scheduler
updateProc pid fn sch =
    { sch | processes =
        sch.processes
            |> Dict.update pid (Maybe.map fn)
    }

setProgram : Program -> Proc -> Proc
setProgram newProgram proc =
    { proc | program = newProgram }
```

The specifics of `stepInner` had to change as well: we can't set the single `sch.program` anymore, we need to update an entry for a PID in the processes dictionary.

Let's not forget about the new instruction:

```elm
stepInner pid proc sch =
    -- ...
    Spawn childProgram kpid ->
        let ( schWithChild, childPid ) =
                sch |> spawn childProgram
        in schWithChild
               |> updateProc pid (setProgram (kpid childPid))
               |> enqueue pid
```

We reuse the `spawn` function from before. It gives us the child's PID, which we can use to access the rest of the parent program via the continuation: `kpid childPid`.

We need to remember to enqueue the parent again (the program given by the continuation hasn't run yet); the child has already been enqueued in the `spawn` function.

[Try it online,](https://ellie-app.com/x4LQBXDbWb3a1) or try the visualizer below.

Our scheduler now takes 7 steps to finish the whole program, which corresponds to the 7 instructions in our initial program.

<script src="/assets/js/WritingYourOwnBeamDemo3.elm.js"></script>
<div class="theme_fullscreen">
    <div id="demo3" style="color: red">Oh no, the visualizer didn't load!</div>
</div>
<script>
app = Elm.WritingYourOwnBeam.Demo3.init({
    node: document.getElementById('demo3'),
});
app.ports.jumpToBottomOfTraces.subscribe((traceId) => {
    document.getElementById(traceId).scrollTop = document.getElementById(traceId).scrollHeight;
});
</script>

## Reduction budget

Can you see any potential issues with our current Scheduler?

The concurrency we have implemented is **cooperative**: a started process won't be stopped by the scheduler in the middle. Consider this program:

```elm
ex4 : Program
ex4 =
    Work 5         <| \() ->
    Spawn ex4Child <| \childPid ->
    Work 5         <| \() ->
    End

ex4Child : Program
ex4Child =
    Work 999 <| \() -> -- !!!
    Work 10  <| \() ->
    End
```

This only differs from example 3 by the amount of work the child is doing. The parent can't finish its tiny bit of work after the spawn until the child finishes its 999 units of work.

The way BEAM solves this is with a **reduction budget:** it creates an illusion of **preemptive** scheduling on top of the cooperative one by inserting yield points after every function call, decrementing its reduction budget in each, and once the budget reaches 0, the scheduler will pause the process and start another one from the queue.

This works surprisingly well: in BEAM languages, you iterate through lists via recursion →  there's a lot of function calls →  a lot of yield points.

We'll do something similar in our toy implementation: introduce a reduction budget, and make the `Work` instruction only do as much "work" as the budget allows.

```elm
reductionBudget : Int
reductionBudget =
    7 -- BEAM sets this to 4000.

step : Scheduler -> Scheduler
step sch =
    -- ...
    sch |> stepInner pid proc {- added: -} reductionBudget

stepInner : Pid -> Proc -> Int -> Scheduler -> Scheduler
stepInner pid proc budget sch =
    if budget <= 0
    then sch
         |> setProc pid proc
         |> (if shouldEnqueue proc
             then enqueue pid
             else identity)
    else -- ...

shouldEnqueue : Proc -> Bool
shouldEnqueue proc =
    case proc.program of
        -- Optimization: if we ended up on `End`,
        -- we don't need to run again.
        End -> False
        Work _ _ -> True
        Spawn _ _ -> True

setProc : Pid -> Proc -> Scheduler -> Scheduler
setProc pid newProc sch =
    sch
        |> updateProc pid (\_ -> newProc)
```

Above we're dealing with the case where the process ran out of the budget. The scheduler will remember where it ended, re-enqueue it if there's more work to do (if we're not at the `End` instruction), and stop the current step.

Let's flesh out the rest of `stepInner`:

```elm
stepInner pid proc budget sch =
    -- ...
    else
    let
        stop : Scheduler -> Scheduler
        stop sch_ =
            sch_ |> stepInner pid program 0

        continue : Program -> Int -> Scheduler -> Scheduler
        continue newProgram newBudget sch_ =
            sch_ |> stepInner pid newProgram newBudget
    in
    -- ...
```

Here I'm making helpers for working with the budget. `stop` sets the budget to 0 and recurses, so that we go straight to the `if budget <= 0 then ...` code path.

`continue` instead sets the budget to some arbitrary number we provided. Usually we'll decrement the current budget by 1, but in case of `Work` we'll jump in larger increments.

Let's use them:

```elm
stepInner pid proc budget sch =
    -- ...
    in
    case program of
        End -> sch |> stop

        Spawn childProgram kpid ->
            let ( schWithChild, childPid ) =
                    sch |> spawn childProgram
            in schWithChild
                   |> continue (kpid childPid) (budget - 1)

        Work n k ->
            if n <= 0
            then sch |> enqueue pid
                     |> continue (k ()) budget
            else let workDone = min n budget
                     workRemaining = n - workDone
                     budgetRemaining = budget - workDone
                 in sch |> continue (Work workRemaining k)
                                    budgetRemaining
```

The `Work` instruction now works completely differently: instead of doing all the work at once (going straight for `k ()`), it now finally cares about the amount of work present.

We will only continue with `k ()` if there's no more work to be done (`n <= 0`).

Otherwise we calculate how much work _can_ be done, and update the remaining work and budget accordingly.

| Budget | Work | Work done | Work remaining | Budget remaining |
|--|--|--|--|--|
| 7 | 5 | 5 | 0 | 2 |
| 7 | 7 | 7 | 0 | 0 |
| 7 | 9 | 7 | 2 | 0 |

[Try it online,](https://ellie-app.com/x4MFY5njY4Xa1) or try the visualizer below.

<script src="/assets/js/WritingYourOwnBeamDemo4.elm.js"></script>
<div class="theme_fullscreen">
    <div id="demo4" style="color: red">Oh no, the visualizer didn't load!</div>
</div>
<script>
app = Elm.WritingYourOwnBeam.Demo4.init({
    node: document.getElementById('demo4'),
});
app.ports.jumpToBottomOfTraces.subscribe((traceId) => {
    document.getElementById(traceId).scrollTop = document.getElementById(traceId).scrollHeight;
});
</script>

Take a look at the first few steps after the child spawns:


| PID 0 (parent) | PID 1 (child) | Ready queue | Action |
|--|--|--|--|
| Work 4 | Work 999 | 1,0 | PID 1 runs, 999 -> 992 |
| Work 4 | Work 992 | 0,1 | PID 0 runs, 4 -> 0 -> End |
| End    | Work 992 | 1   | PID 1 runs, 992 -> 985 |
| End    | Work 985 | 1   | ... |

Thus, even though the child has a lot of work to be done, the scheduler preempts and only lets it do the work in chunks of 7, and the parent process gets a chance to do some of its work as well.

## Instruction: `Send`

Spawning processes without letting them communicate is not very useful. It might help move computations off the main thread, but obviously we'll want some [inter-process communication](https://en.wikipedia.org/wiki/Inter-process_communication) eventually.

Let's add a way to send messages to processes. (Receiving them will come later.)

```elm
type Program
    = -- ...
    | Send Pid String K

shouldEnqueue : Proc -> Bool
shouldEnqueue proc =
    -- ...
    Send _ _ _ -> True

ex5 : Program
ex5 =
    Spawn ex5Child       <| \childPid ->
    Send childPid "Ping" <| \() ->
    End

ex5Child : Program
ex5Child =
    Work 10 <| \() ->
    End
```

To implement this `Send` instruction, we'll need to introduce the concept of **mailboxes:**

```elm
type alias Proc =
    { program : Program
    -- Added:
    , mailbox : Queue String
    }
```

Sending a message will be done by putting the message into this mailbox. We can do that because we have access to the whole scheduler, we are not limited to just the current process' resources:

```elm
stepInner pid proc budget sch =
    -- ...
    Send destinationPid message k ->
        sch
            |> send destinationPid message
            |> continue (k ()) (budget - 1)

send : Pid -> String -> Scheduler -> Scheduler
send destinationPid message sch =
    sch
        |> updateProc destinationPid (enqueueMessage message)
        |> enqueue destinationPid

enqueueMessage : String -> Proc -> Proc
enqueueMessage message proc =
    { proc | mailbox = proc.mailbox |> Queue.enqueue message }
```

When we send a message to a process, we also enqueue it to make sure it has a chance to process it. This will become important later, when processes go to sleep (ie. don't enqueue) after not finding any interesting message for their selective receive. We'll get there!

[Try it online,](https://ellie-app.com/x4Nmv37xMgwa1) or try the visualizer below.

<script src="/assets/js/WritingYourOwnBeamDemo5.elm.js"></script>
<div class="theme_fullscreen">
    <div id="demo5" style="color: red">Oh no, the visualizer didn't load!</div>
</div>
<script>
app = Elm.WritingYourOwnBeam.Demo5.init({
    node: document.getElementById('demo5'),
});
app.ports.jumpToBottomOfTraces.subscribe((traceId) => {
    document.getElementById(traceId).scrollTop = document.getElementById(traceId).scrollHeight;
});
</script>

The child has the message in its mailbox, but can't react to it. Let's fix that!

## Instruction: `Receive`

```elm
type Program
    = -- ...
    | Receive String K
```

This is a substantial simplification from what the real BEAM needs to support: Erlang receive statement allows for multiple branches, pattern matching inside the branches, timeouts when there's no interesting message present for a certain amount of time, and so on.

We will instead only support a single string message with no destructuring. The process won't continue until this specific string is found in the mailbox.

```elm
ex6 : Program
ex6 =
    Spawn ex6Child       <| \childPid ->
    Send childPid "Ping" <| \() ->
    End

ex6Child : Program
ex6Child =
    Receive "Ping" <| \() -> 
    Work 10        <| \() ->
    End
```

We can make an interesting optimization in the `shouldEnqueue` function:

```elm
shouldEnqueue proc =
    -- ...
    -- Optimization: we don't need to `Receive`
    -- if there's no interesting message.
    Receive wantedMsg _ ->
        Queue.toList proc.mailbox
            |> List.any (\msg -> msg == wantedMsg)
```

This means we won't reenqueue a process at the end of `stepInner` if it's waiting for a message that's not present in its mailbox. There's no reason for the process to try again until a new message is received, so the process will instead go to sleep and wait to be woken up later in the `send` function.

There's a wall of code coming up, brace yourselves! When interpreting the `Receive` instruction, we'll go through messages until we find the wanted one. If we find it, remove it from the mailbox and use the continuation, otherwise go to sleep with the mailbox intact.

```elm
stepInner pid proc budget sch =
    -- ...
    continue_ : Proc -> Int -> Scheduler -> Scheduler
    continue_ newProc newBudget sch_ =
        sch_ |> stepInner pid newProc newBudget
    -- ...
    Receive wantedMsg k ->
        let processMessages : List String -> Queue String -> Scheduler
            processMessages unmatchedStartRev restOfMailbox =
                case Queue.dequeue restOfMailbox of
                    -- NO MORE MSGS TO CHECK
                    Nothing ->
                        sch |> stop

                    Just ( msg, restOfMailboxWithoutThis ) ->
                        if msg == wantedMsg then
                            -- FOUND IT
                            let newMailbox =
                                  Queue.fromList
                                      (List.reverse unmatchedStartRev
                                          ++ Queue.toList restOfMailboxWithoutThis)
                            in
                                sch |> continue_
                                           (proc
                                               |> setMailbox newMailbox
                                               |> setProgram (k ())
                                           )
                                           (budget - 1)

                        else 
                            -- TRY NEXT
                            processMessages
                                 (msg :: unmatchedStartRev)
                                 restOfMailboxWithoutThis
        in
        processMessages [] proc.mailbox

setMailbox : Queue String -> Proc -> Proc
setMailbox newMailbox proc =
    { proc | mailbox = newMailbox }
```

This code is not very elegant due to plucking a message from the middle of a queue, but it does what I described in the previous paragraph.

[Try it online,](https://ellie-app.com/x4Th2jNCtFWa1) or try the visualizer below.

<script src="/assets/js/WritingYourOwnBeamDemo6.elm.js"></script>
<div class="theme_fullscreen">
    <div id="demo6" style="color: red">Oh no, the visualizer didn't load!</div>
</div>
<script>
app = Elm.WritingYourOwnBeam.Demo6.init({
    node: document.getElementById('demo6'),
});
app.ports.jumpToBottomOfTraces.subscribe((traceId) => {
    document.getElementById(traceId).scrollTop = document.getElementById(traceId).scrollHeight;
});
</script>

You can see things have lined up nicely: process 1 has `"Ping"` in its mailbox and also is about to try and `Receive "Ping"`. In the next step the message is gone and the process is doing `Work`. Success!

## Instruction: `Crash`, `Link`

For the last piece of the puzzle, let's look at the feature that gives rise to supervision trees: **linking** processes together.

Linking is bidirectional; the scheduler will send a system message to the other side of the link whenever a linked process exits (in our example, crashes). The receiving side can choose to react to this exit signal: respawn the other process? Crash ourselves? Log it somewhere and do cleanup?

> Note: BEAM also has **monitors.** These are one-directional, and I'll skip them in this blogpost.

```elm
type Program
    = -- ...
    | Crash
    | Link Pid K

type alias Proc =
    { -- ...
    , links : Set Pid
    }

initProc program =
    { -- ...
    , links = Set.empty
    }

ex7 : Program
ex7 =
    Spawn ex7Child <| \childPid ->
    Link childPid  <| \() ->
    Receive ("CRASH: " ++ String.fromInt childPid) <| \() ->
    End

ex7Child : Program
ex7Child =
    Crash

shouldEnqueue proc =
    -- ...
    Crash    -> True
    Link _ _ -> True
```

Why `Crash -> True`? The `Crash` instruction is a terminal, but it has work to do inside (sending the system messages), so we'll enqueue it if it hasn't run yet. (We'll replace `Crash` with `End` after doing that work.)

```elm
stepInner pid proc budget sch =
    -- ...
    Link linkedPid k ->
        sch
            |> link pid linkedPid
            |> continue (k ()) (budget - 1)

link : Pid -> Pid -> Scheduler -> Scheduler
link pid1 pid2 sch =
    sch
        |> updateProc pid1 (addLink pid2)
        |> updateProc pid2 (addLink pid1)

addLink : Pid -> Proc -> Proc
addLink pid proc =
    { proc | links = proc.links |> Set.insert pid }
```

And `Crash` is where we actually use `proc.links`:

```elm
stepInner pid proc budget sch =
    -- ...
    stop_ : Proc -> Scheduler -> Scheduler
    stop_ newProc sch_ =
        sch_ |> stepInner pid newProc 0
    -- ...
    Crash ->
        sch
            |> propagateCrashToLinks pid
            |> stop_ (proc |> setProgram End)

propagateCrashToLinks : Pid -> Scheduler -> Scheduler
propagateCrashToLinks pid sch =
    case Dict.get pid sch.processes of
        Nothing   -> sch
        Just proc ->
            proc.links
                |> Set.foldl
                    (\linkedPid accSch ->
                        accSch
                          |> send linkedPid
                                  ("CRASH: " ++ String.fromInt pid)
                    )
                    sch
```

In a real-world interpreter, we'd distinguish between user messages and system messages by using an ADT, but for this toy implementation, the above will be enough.

[Try it online,](https://ellie-app.com/x4RjvchvjQPa1) or try the visualizer below:

<script src="/assets/js/WritingYourOwnBeamDemo7.elm.js"></script>
<div class="theme_fullscreen">
    <div id="demo7" style="color: red">Oh no, the visualizer didn't load!</div>
</div>
<script>
app = Elm.WritingYourOwnBeam.Demo7.init({
    node: document.getElementById('demo7'),
});
app.ports.jumpToBottomOfTraces.subscribe((traceId) => {
    document.getElementById(traceId).scrollTop = document.getElementById(traceId).scrollHeight;
});
</script>

It works in the Ellie link above, but not in the visualizer. Why? Their reduction budget is different. The Ellie demo manages to run `Spawn` and `Link` without anything else running in between, but the visualizer has reduction budget of 1, and so the child `Crash`es before the parent manages to `Link` to it.

This can be fixed by making the instruction pair a single atomic instruction, and BEAM does this with the `spawn_link` function. You can [try it online](https://ellie-app.com/x4RjT3KBkxYa1) or click the `Fix the problem` button in the demo above.

## Conclusion

And that's all! We have implemented:
- spawning child processes
- sending and selectively receiving messages
- an illusion of preemptive scheduling on top of cooperative scheduling using a reduction budget
- linking between processes, essentially adding hooks for when a related process stops for some reason

These primitives combine together in nice ways, giving rise to BEAM's reputation. I think they're pretty neat, and I hope this toy implementation demystified them a little bit for you!
