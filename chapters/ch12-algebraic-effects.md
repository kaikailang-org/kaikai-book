# Chapter 12 · Algebraic effects

This is where kaikai earns its novelty. So far you've used
types, pattern matching, protocols, units of measure,
contracts — elegant pieces, but you'd find counterparts in
Haskell, Rust, F#. **Algebraic effects** set kaikai apart from
nearly every production-ready language today.

They are also the reason this project exists, as I recounted in
the prologue.

The idea is easy to state and strange at first: **a function
declares in its signature which effects it uses, but not how
they happen**. Printing to a screen, reading a file, failing
with an error, suspending execution, generating a random
number — these are all effects. The function says "I need
this capability"; code further up decides what it means in
the current context. The separation between **what** and
**how** is the heart of the system.

If that sounds like *dependency injection*, exceptions, or
generators, hold the thought. One mechanism resembles so many
things because, in the theory underneath, they're all the same.
Algebraic effects are the generalization.

Take it slowly. The first reading is for each idea to
register; solid intuition lands when you come back a month
later and it suddenly feels obvious.

## 12.1 The friction effects resolve

Before the syntax, consider the concrete problems effects
solve. If you recognize the pattern from your own work, you'll
know why a new tool is worth learning.

### Invisible exceptions

In Java or Python, any function call can throw an exception
and nothing in the signature tells you. You read the code and
you don't know what can fail. You find out in production.

```python
def load_user(id):
    return db.get(id)   # can this fail? with what exceptions?
```

Java's checked exceptions tried to fix it by forcing you to
declare `throws`. People wrote `throws Exception` to silence
the compiler, and we were back where we started. Modern
functional languages (Rust, OCaml, kaikai's chapter 5) push
you toward `Result` or `Option`: the cost of failure shows up
in the type, and the caller decides. Good for local failures,
heavy when many functions fail: signatures fill up with
wrapping and unwrapping.

### `async`/`await` infection

In JavaScript, Python, C#, Rust, marking a function `async`
forces every function that calls it to be `async` as well.
A seemingly local change spreads through the whole call tree.

```js
async function read(path) { ... }
async function process(path) {
  const data = await read(path);   // process had to become async too
  return transform(data);
}
```

Bob Nystrom named this in 2015 in a famous essay, **"What
Color is Your Function?"**. `async` splits functions into two
colors: red (`async`) and blue (non-async). A red function can
call a blue one, but not the other way around. If your blue
function needs a red one inside, you have to repaint it — and
the one that called it, all the way up. The infection won't
stay local.

The essay doesn't call `async` bad. Its point is that this kind
of signature marker, specific to one kind of effect, creates
parallel systems that don't compose. `async` doesn't compose
with generators: you need `async function*`. It doesn't compose
cleanly with exceptions either (inside async functions they
become rejected promises). Each new combination needs its own
syntax.

Algebraic effects go to the root: **there are no special
colors**, only one dimension — the effect row. `async` stops
being a syntactic property of the function and becomes one
effect among others. And the row extends without new syntax:
`/ Async + Fail` is no stranger than `/ Async`.

### Dependency injection

To make a function testable, you pass the "external things"
it uses as parameters: the clock, the logger, the database
client. Mocks in tests, the real things in production.

```java
class Processor {
  public Processor(Clock clock, Logger logger, DbClient db) { ... }
  public void run() { ... }
}
```

It works, but it pollutes signatures and forces manual
wiring. And every time a new function needs one of the
services, you have to thread it through the constructors up
the hierarchy.

### The common pattern

The three frustrations share the same shape:

- A function needs a **capability** (to fail, to suspend, to
  log).
- The capability must be **explicit** (visible in the type)
  so it doesn't surprise.
- The capability must be **provided by context** (caller,
  test, framework) without the function knowing.
- Multiple capabilities must **compose cleanly**.

Algebraic effects cover all four with **one construct**. What
exceptions, `async`/`await`, and dependency injection do
separately, and often poorly, effects do with a single
mechanism.

## 12.2 Declaring an `effect`

An effect is an **interface**: it declares what operations
exist and their signatures, but not how they're implemented.

```kai
effect Log {
  log(msg: String) : Unit
}
```

This introduces an effect `Log` with one operation, `log`,
that takes a string and returns nothing useful. Any function
that calls `Log.log(...)` uses the `Log` effect.

Notice what's missing: implementation. No body, no `if`, no
print; just the signature. That's the fundamental difference
from a protocol or a traditional interface: the effect decides
nothing, it only declares what can be requested.

Operations are declared without `fn` and without a body —
name, parameters, return type. An effect can have several:

```kai
effect Io {
  print(s: String)  : Unit
  read_line()       : String
}
```

Two dependencies may each declare an effect with the same name
without colliding — they're different effects that happen to
share a word. If you import both, you pick one with a
qualifier, and it goes everywhere the name does: in the row
(`/ tracing.Trace`), in the handler head
(`handle { ... } with tracing.Trace`), and on the operation
itself (`tracing.Trace.log(msg)`). Then `with ea.Emit` reaches
only `ea`'s, and `eb`'s stays untouched. §8.2 has the general
rule; a bare name is fine whenever nothing collides.

## 12.3 Calling an operation: the signature changes

To use an operation, call it on the effect:

```kai
fn greet(name: String) : Unit / Log {
  Log.log("hello, " ++ name)
}
```

Two new things:

- **`Log.log(...)`** is the invocation syntax. The effect is
  the namespace; the operation is the method.
- **`: Unit / Log`** in the signature. The slash introduces
  the **effect row**: the effects the function needs to run.
  Without `/ Log`, the function doesn't compile: it uses a
  capability it didn't declare.

The type system guarantees that **every function using an
effect declares it**. If you call `Log.log(...)` from a
function without `/ Log`, the compiler rejects it with a
clear message. Effects are visible in the signature, always.

And it's recursive. If `greet` uses `Log` and `main` calls
`greet`, `main` also needs `Log` in its signature, unless it
**handles** the effect first (that's §12.4).

```kai
fn main() : Unit / Log {       # propagates the effect
  greet("kaikai")
}
```

It's the contagion you know from `async`/`await`, minus the
colors: the call site carries no special syntax to "pay for
the effect". `Log.log(...)` is a call like any other. The
discipline lives in the signature, and a new effect doesn't
introduce an incompatible color: it only extends the row.

### Several effects: the row

If a function uses more than one effect, list them with `+`:

```kai
fn process() : Int / Log + Fail {
  Log.log("start")
  if bad_condition() {
    Fail.fail("can't")
  }
  42
}
```

`Log + Fail` is the **row** of effects. The row is a set:
order doesn't matter, and `Log + Fail` and `Fail + Log` are
the same row to the compiler. The `+` is just syntax for
building it.

(`Fail` doesn't come from the stdlib: you declare it in §12.5,
just like `Log` in §12.2. I use it here already because the
name explains itself.)

If this reminds you of chapter 10 — where `m * s` and `s * m`
were the same unit — that is no coincidence. Effects are
another of §2.6's families of labels: they inhabit their own
kind, with their own algebra (the row, where order doesn't
count and duplicates collapse), and the compiler applies it
when unifying signatures just as it applies the unit algebra.
In chapter 19 you'll find both as entries in the same catalog.

## 12.4 Handling an effect with `handle ... with`

The interesting part: **deciding what an effect means** at a
specific point in the program. That's what `handle ... with`
is for.

```kai
fn main() {
  handle {
    greet("kaikai")
    greet("Ada")
  } with Log {
    log(msg, resume) -> {
      println("[INFO] " ++ msg)
      resume(())
    }
  }
}
```

Read it as: "run this block, and whenever someone inside
invokes `Log.log`, do this". The handler intercepts each call
to `log`, decides what happens, and resumes with `resume(...)`.

Three details:

- **`handle { body } with Effect { clauses }`** is a control
  construct, in the same family as `if` and `match` — not a
  function call. `handle` and `with` are reserved keywords.
- **`body` is where `Effect` is handled.** Inside, calling
  `Log.log(...)` is legal even if the surrounding function
  doesn't have `Log` in its row, because the handler provides
  it. Outside the `with`, the type system demands the effect
  again.
- **`resume(())` continues the body** from the point where
  `log` was called, with the value you passed as argument.

The remarkable thing: **`main` doesn't declare `Log`**. The
`handle` "consumes" it: the inside uses it, the `with` provides
it, and `main`'s row comes out without `Log`. The type system
stays strict; the handler is the door through which an effect
leaves the scope.

The effect, its operation and its handler, in a complete
program:

```kai
# examples/ch12/01_log_basic.kai
effect Log {
  log(msg: String) : Unit
}

# `greet` uses `Log.log` and so its row carries `/ Log`.
# The function doesn't know whether messages go to the
# console, to a file, or nowhere: it only knows the effect
# is available.

fn greet(name: String) : Unit / Log {
  Log.log("hello, " ++ name)
}

fn main() {
  handle {
    greet("kaikai")
    greet("Ada")
  } with Log {
    log(msg, resume) -> {
      println("[INFO] " ++ msg)
      resume(())
    }
  }
}
```

```
$ kai run examples/ch12/01_log_basic.kai
[INFO] hello, kaikai
[INFO] hello, Ada
```

### The same body with two handlers

The power shows when you notice that `greet` doesn't change.
One handler gives you verbose logs; another, silence:

```kai
# Verbose handler
handle {
  greet("verbose mode")
} with Log {
  log(msg, resume) -> {
    println("[INFO] " ++ msg)
    resume(())
  }
}

# Silent handler
handle {
  greet("silent mode")
} with Log {
  log(msg, resume) -> resume(())   # drops the message
}
```

`greet` doesn't notice the difference, and wouldn't with a
handler that writes to a file, collects messages in a list, or
ships them over the network. It's **handler-agnostic**.

This replaces dependency injection. No constructor to
pass around, no service to mock; the handler is the
implementation.

The same body under two handlers, one that prints and one that
stays quiet:

```kai
# examples/ch12/02_two_handlers.kai
effect Log {
  log(msg: String) : Unit
}

fn greet(name: String) : Unit / Log {
  Log.log("hello, " ++ name)
}

fn main() {
  # Handler 1: prints with prefix.
  handle {
    greet("verbose mode")
  } with Log {
    log(msg, resume) -> {
      println("[INFO] " ++ msg)
      resume(())
    }
  }

  # Handler 2: drops the messages.
  handle {
    greet("silent mode")
  } with Log {
    log(msg, resume) -> {
      resume(())
    }
  }

  println("(end)")
}
```

```
$ kai run examples/ch12/02_two_handlers.kai
[INFO] hello, verbose mode
(end)
```

## 12.5 `resume`: the handler decides what happens next

`resume` is the piece that confuses most at first and pays off
most later. It's the **continuation** of the body from the
point of the operation.

When the body invokes `Log.log("hi")`, control jumps to the
handler, which receives two things:

1. The argument passed to the operation: `"hi"`.
2. A `resume` function that, when called, continues the body
   from where it left off.

```kai
log(msg, resume) -> {
  println("[INFO] " ++ msg)   # decide what to do with the effect
  resume(())                   # hand control back to the body
}
```

`resume(())` passes `()` as the return value of the operation
`log` (which returns `Unit`). The body continues after the
`Log.log(...)` call with that value.

### Operations that return values

`Log.log` returns nothing useful, but an effect can **supply**
a value:

```kai
effect Ask {
  name() : String
}

fn greeting() : String / Ask {
  "hello, " ++ Ask.name()
}

fn main() : Unit / Stdout {
  let message = handle {
    greeting()
  } with Ask {
    name(resume) -> resume("world")
  }
  println(message)   # prints "hello, world"
}
```

`Ask.name()` suspends the body. The handler receives `resume`
and decides what `String` to give the caller: here, `"world"`.
`resume("world")` continues the body with that value, and the
`++` concatenates it.

Another use of dependency injection gone: instead of threading
`name` as a parameter through the whole call tree, you "ask"
for it via an effect, and the handler in `main` decides the
answer. In tests, another handler answers something else.

The operation that returns a value, and the `resume` that
hands it back:

```kai
# examples/ch12/03_ask.kai
effect Ask {
  name() : String
}

fn greeting() : String / Ask {
  "hello, " ++ Ask.name()
}

fn main() : Unit / Stdout {
  let message = handle {
    greeting()
  } with Ask {
    name(resume) -> resume("world")
  }
  println(message)
}
```

```
$ kai run examples/ch12/03_ask.kai
hello, world
```

### Handlers that DON'T call `resume`

If the handler **doesn't** call `resume`, the body is
discarded and the handler's value becomes the value of the
whole `handle`. That's how exceptions are built:

```kai
effect Fail {
  fail(reason: String) : Nothing
}

fn divide(a: Int, b: Int) : Int / Fail {
  if b == 0 { Fail.fail("division by zero") }
  else      { a / b }
}

fn main() : Unit / Stdout {
  let r = handle {
    let x = divide(10, 2)
    let y = divide(20, 0)    # Fail.fail fires here
    x + y                     # never reached
  } with Fail {
    fail(reason, resume) -> {
      println("failed: " ++ reason)
      0                       # replacement value
    }
  }
  println("result: #{r}")    # prints: result: 0
}
```

The signature `fail(reason: String) : Nothing` says the
operation **never returns**. `Nothing` is kaikai's empty type
(chapter 3's bottom type): it has no inhabitants. There's
nothing to pass to `resume`, so the type system guarantees the
body can't continue after `Fail.fail`. If you try, the
compiler won't let you write the code.

kaikai's "exceptions" are a special case of the general
mechanism. There's no special syntax for
`try/catch`; there's `handle` and an effect whose operation
returns `Nothing`.

A handler that never calls `resume`: the operation cuts the
body short and the whole `handle` returns something else.

```kai
# examples/ch12/04_fail.kai
effect Fail {
  fail(reason: String) : Nothing
}

fn divide(a: Int, b: Int) : Int / Fail {
  if b == 0 {
    Fail.fail("division by zero")
  } else {
    a / b
  }
}

fn main() : Unit / Stdout {
  let r = handle {
    let x = divide(10, 2)
    let y = divide(20, 0)  # this is where `Fail.fail` fires
    x + y  # never evaluated
  } with Fail {
    fail(reason, resume) -> {
      println("failed: " ++ reason)
      0  # replacement value
    }
  }
  println("result: #{r}")
}
```

```
$ kai run examples/ch12/04_fail.kai
failed: division by zero
result: 0
```

### Code after `resume`

So far `resume` has always been the last thing in the clause.
That's **tail position**, and it's what you'll write
ninety-nine percent of the time: the handler decides
something, resumes, and gets out of the way.

But nothing forces you to stop there. Code **after** the
`resume` runs once the body is done, and `resume` hands you the
`handle`'s result:

```kai
# examples/ch12/14_non_tail_resume.kai (fragment)
log(msg, resume) -> {
  println("before: #{msg}")
  let v = resume(())
  println("after:  #{msg} (handle = #{v})")
  v
}
```

```
$ kai run examples/ch12/14_non_tail_resume.kai
before: start
before: finish
after:  finish (handle = 42)
after:  start (handle = 42)
result = 42
```

Read the order slowly, because it surprises. The two "before"
lines come out in the order the body performed `log`. The two
"after" lines come out **backwards**: `finish` first, because
it was the last to suspend. It's a stack unwinding — exactly
what you'd expect once you take `resume` for what it is: the
rest of the computation.

And look at what `resume` returned: `42`, the body's value, not
the `()` that `log` declares. Out of tail position, `resume`
hands you what came out of the whole `handle`; the operation's
return value goes to the body, down below. Mixing up the two is
the classic mistake.

One restriction comes along: on any one execution path
`resume` is called **once**. Two calls are a compile error:

```
error: `resume` may be called twice on one path
  = help: the continuation is one-shot
```

Resuming the same computation twice is *multi-shot*, it costs a
copy of the fiber's frames, and it lives separately under
`resume_multishot`.

What's it good for? Anything that has to happen *around* the
rest of the program: timing a stretch, closing a resource,
counting what happened inside. In §12.8 you'll meet `initially`
and `finally`, the sugar for the common case.

## 12.6 Handlers with state: the `State` pattern

So far the handlers have been stateless: they decide and
resume. But a handler can carry **its own state** without the
body noticing. This replaces global mutation.

```kai
effect State[T] {
  get() : T
  set(v: T) : Unit
}

fn sum(xs: [Int]) : Int {
  handle {
    list.foreach(xs, (x) => State.set(State.get() + x))
    State.get()
  } with State[Int](0) {
    get(resume)    -> resume(state)         # return state
    set(v, resume) -> resume((), v)         # update state
    return(x)      -> x                      # drop state at the end
  }
}
```

What's new:

- **`State[T]` is parametric.** `T` is what the state holds;
  here, `Int`.
- **`with State[Int](0)`** installs the handler with initial
  state `0`. The argument in parentheses is the initial
  value.
- **`state`** is a special identifier available inside the
  handler's clauses. It refers to the current value of the
  state.
- **`resume(value, new_state)`** has two arguments when the
  handler carries state: the operation's return value and the
  new state. Plain `resume(value)` leaves the state
  unchanged.
- **`return(x) -> x`** runs when the body completes normally,
  with `x` as its result. Here the final state is dropped and
  only `x` returned; if you wanted both, you'd write
  `return(x) -> (x, state)`.

From the body's view there's no mutation: only invocations of
pure-looking operations. Mutation lives entirely inside the
handler, and nothing shows outside the `handle`.

The same shape builds `Reader` (read-only environment),
`Writer` (output accumulation), counters, caches, sessions — no
global variables, no threaded parameters.

An accumulator that lives in the handler, not in the body:

```kai
# examples/ch12/05_state.kai
effect State[T] {
  get() : T
  set(v: T) : Unit
}

# Sum the elements of a list using a "mutable" accumulator
# encapsulated in the handler.

fn sum(xs: [Int]) : Int {
  handle {
    list.foreach(xs, x => State.set(State.get() + x))
    State.get()
  } with State[Int](0) {
    get(resume) -> resume(state)  # return the state, unchanged
    set(v, resume) -> resume((), v)  # return (), state becomes v
    return(x) -> x
  }
}  # drop the final state

fn main() : Unit / Stdout {
  println("sum([1,2,3,4,5]) = #{sum([1,2,3,4,5])}")
  println("sum([]) = #{sum([])}")
}
```

```
$ kai run examples/ch12/05_state.kai
sum([1,2,3,4,5]) = 15
sum([]) = 0
```

## 12.7 `var`, `Ref[T]` and `Array[T]`: two distinct mechanisms

`State[T]` is the general tool for carrying a changing value,
but writing `handle ... with State[Int](0)` for every local
counter would be tedious. So kaikai ships syntactic sugar and,
separately, a stdlib effect for memory that outlives a block.
Keep the two apart.

### `var`: sugar over `State[T]`

The short form for a local cell:

```kai
fn count_evens(xs: [Int]) : Int {
  var n := 0
  list.foreach(xs, (x) => {
    if x % 2 == 0 {
      n := n + 1
    }
  })
  n
}
```

`:=` is the single mark of mutability:

- **`var n := 0`** declares the cell with its initial value.
- **`n := v`** writes `v`.
- **`n`** reads the current value: a bare name, no marker.

How does it work? **`var` is syntactic sugar over `State[T]`.**
The compiler rewrites

```kai
var n := 0
... rest of the block ...
```

into

```kai
handle {
  ... rest of the block ...
} with State[Int](0) as n {
  get(resume)    -> resume(state)
  set(v, resume) -> resume((), v)
  return(x)      -> x
}
```

Because the inserted `handle` lives **inside the same block**
as the `var`, the `State[Int]` effect closes right there and
never escapes the signature. To the caller, `count_evens` is
just `: Int`, with no effects.

The effect isn't masked: the `handle` is literally next to the
`var`, and the row closes where the cell is declared.

Nor is it slow: the compiler detects the pattern "local cell
with one-shot resume" and specializes it down to a stack frame
slot, like a C mutable variable. Zero cost compared to the
equivalent imperative code.

A counter with `var` — the same `State[T]`, written as you would
in an imperative language:

```kai
# examples/ch12/10_local_var.kai
fn count_evens(xs: [Int]) : Int {
  var n := 0
  list.foreach(xs, x => {
    if x % 2 == 0 {
      n := n + 1
    }
  })
  n
}

fn main() : Unit / Stdout {
  println("evens in [1..10] = #{count_evens([1,2,3,4,5,6,7,8,9,10])}")
  println("evens in [] = #{count_evens([])}")
}
```

```
$ kai run examples/ch12/10_local_var.kai
evens in [1..10] = 5
evens in [] = 0
```

### `Mutable`: the effect behind `Ref[T]` and `Array[T]`

`var` covers local cells. Sometimes memory needs to **outlive
a block**: an array you'll return, a cell you'll pass between
functions, a structure shared by several routines. For that
kaikai ships two stdlib types, `Ref[T]` and `Array[T]`, both
under the **`Mutable`** effect.

```kai
fn fill(n: Int) : Array[Int] {
  let a = Mutable.array_make(n, 0)
  var i := 0
  list.foreach([0..n], (_) => {
    a[i] := i * 2
    i := i + 1
  })
  a
}
```

- **`Mutable.array_make(n, init)`** creates an array of size
  `n` with initial value `init`.
- **`a[i]`** reads index `i`. Sugar for
  `Mutable.array_get(a, i)`.
- **`a[i] := v`** writes index `i`. Sugar for
  `Mutable.array_set(a, i, v)`.

`Ref[T]` is the single-cell version: `Mutable.ref_make(v)`,
`Mutable.ref_get(r)`, `Mutable.ref_set(r, v)`. No indexing
sugar, but everything else is parallel to `Array[T]`.

Look at the signature of `fill`: `: Array[Int]`, **without
`Mutable`**, though the function obviously mutates.

`Mutable` follows the discipline of **observable effects**: it
shows up in the signature only when the mutation is **visible
to the caller**. Here it isn't. The array is created inside,
filled inside, and returned complete; whoever receives it gets
a settled value and observes no mutation.

### When `Mutable` becomes visible

If the mutation is **observable**, the effect appears:

```kai
fn fill_in_place(a: Array[Int]) : Unit / Mutable {
  let n = Mutable.array_length(a)
  var i := 0
  list.foreach([0..n], (_) => {
    a[i] := i * 2
    i := i + 1
  })
}
```

Here `a` comes from outside, and the caller holds a reference
to the same array the function modifies. The mutation is
visible to the caller, so the signature must declare it.

The rule from §12.3 applies as for any other effect: every
function producing an observable effect declares it. There are
no hidden assignments.

### `Mutable` versus `State[T]`

Both represent mutable state:

- **`var` (which is `State[T]`)**: the cell lives inside the
  block. It doesn't outlive the function or get passed to
  other routines — just a local accumulator or counter. The
  signature stays clean.
- **`Mutable` with `Ref[T]` or `Array[T]`**: memory outlives
  the block or is shared across functions. Appears in the
  signature whenever the mutation is observable to the
  caller.

If you pass a `Ref[T]` or `Array[T]` as argument, or return
one after mutating it, you're in `Mutable` territory. If you
just need a local counter, it's `var`.

## 12.8 Composing effects: nested handlers

Real functions use more than one effect. One that logs and
accumulates declares `/ Log + State[Int]`, and in `main` you
handle it with two nested `handle`s:

```kai
fn accumulate(xs: [Int]) : Int / Log + State[Int] {
  list.foreach(xs, (x) => {
    Log.log("adding #{x}")
    State.set(State.get() + x)
  })
  State.get()
}

fn main() : Unit / Stdout {
  let total = handle {
    handle {
      accumulate([10, 20, 30])
    } with State[Int](0) {
      get(resume)    -> resume(state)
      set(v, resume) -> resume((), v)
      return(x)      -> x
    }
  } with Log {
    log(msg, resume) -> {
      println("[LOG] " ++ msg)
      resume(())
    }
  }
  println("total = #{total}")
}
```

Nesting order matters **when the handlers interact**. Here
they don't: `State` only reads and writes its state, `Log`
only prints, and either order works. But with `Fail` inside
`State`, the order decides whether state survives a failure
(outer `Fail`) or is discarded (inner `Fail`). Each
combination has an explicit, checkable semantics.

With `try/catch` and global variables the order is implicit
and runtime-dependent. Here you decide it, in how you nest the
`handle`s.

Two effects in one body and two nested handlers serving them:

```kai
# examples/ch12/06_composition.kai
effect Log {
  log(msg: String) : Unit
}

effect State[T] {
  get() : T
  set(v: T) : Unit
}

# `accumulate` uses two effects: it reads and writes state,
# and it logs each step. The signature declares both with
# `Log + State[Int]`.

fn accumulate(xs: [Int]) : Int / Log + State[Int] {
  list.foreach(xs, x => {
    Log.log("adding #{x}")
    State.set(State.get() + x)
  })
  State.get()
}

fn main() : Unit / Stdout {
  let total = handle {
    handle {
      accumulate([10, 20, 30])
    } with State[Int](0) {
      get(resume) -> resume(state)
      set(v, resume) -> resume((), v)
      return(x) -> x
    }
  } with Log {
    log(msg, resume) -> {
      println("[LOG] " ++ msg)
      resume(())
    }
  }
  println("total = #{total}")
}
```

```
$ kai run examples/ch12/06_composition.kai
[LOG] adding 10
[LOG] adding 20
[LOG] adding 30
total = 60
```

### Guaranteed cleanup: `initially` and `finally`

Nesting brings a problem exceptions also have, and only half
solve. If an outer handler abandons `resume` — like the `Fail`
of §12.5 — the inner body never returns. The line you wrote
*after* the `handle` to close a file, drop a lock, or return a
connection to the pool never runs. The non-local jump ate it.

Two more clauses close that gap:

- `initially { }` runs once, when the handler is installed,
  before the body. Its value is the handler state, readable as
  `state` in the clauses. It fills the same slot as the
  `with Eff(init)` form: you write one or the other, never both.
- `finally { }` runs when the scope unwinds, **on every path**:
  normal return, a clause that abandons `resume` (including one
  installed further out, whose jump skips over this scope), and
  cooperative cancellation (chapter 13). It does not run on
  `panic`, which aborts the process rather than unwinding it.

Together they are the acquire/release bracket, by construction
rather than convention: the acquisition lives **inside** the
construct that guarantees the release, so there's no window
where the resource is open and unguarded.

```kai
# examples/ch12/12_cleanup.kai
effect Fail {
  fail(reason: String) : Nothing
}

effect Conn {
  query(sql: String) : String
}

fn report() : String / Conn + Fail {
  let _ = Conn.query("SELECT total FROM sales")
  Fail.fail("network dropped before the second query")
}

fn main() : Unit / Stdout {
  let r = handle {
    handle {
      report()
    } with Conn {
      initially { println("opening connection"); 42 }
      finally   { println("closing connection #{state}") }
      query(sql, resume) -> resume("1500")
      return(x)          -> x
    }
  } with Fail {
    fail(reason, resume) -> "aborted: #{reason}"
    return(x)            -> x
  }
  println(r)
}
```

```
$ kai run examples/ch12/12_cleanup.kai
opening connection
closing connection 42
aborted: network dropped before the second query
```

The outer `Fail` abandoned `resume` and the `Conn` body never
finished. The connection still closed — *before* the
replacement value reached `main`: the inner scope unwinds along
the jump's path, not after it.

Keep this rule in mind: **a cleanup runs in the evidence
context of its installation**. If the `finally` performs an
effect, it dispatches to the handlers live when the handler was
installed, not to those at the jump site, whose frames are
already gone. In practice, a `finally` cannot perform the effect
its own handler discharges. The compiler tells you ("effect not
handled"); it never becomes a runtime loop.

`finally` takes no parameters and its value is discarded: it
runs for its effect. To transform the `handle`'s result there
is `return(x)`.

Two details about living with them. `initially` and the
`with Eff(init)` form fill the same slot, so writing both is a
parse error. And neither word is reserved — they're contextual —
so an effect of yours can declare an operation named `finally`
without anything breaking.

## 12.9 Named instances: the handler as a value

So far, every operation finds its handler by the effect's name:
`Log.log(...)` climbs to the nearest `handle ... with Log`. What
if you need **two** handlers of the same effect, alive at the
same time, and want to choose which one you're talking to?

You give each instance a name:

```kai
handle {
  ...
} with Cell(10) as a {
  get(resume)    -> resume(state)
  set(v, resume) -> resume((), v)
  return(x)      -> x
}
```

The `as a` binds `a` as a **capability value**: a value whose
type is the effect itself (`Cell`, `State[Int]`). Inside the
body, `a.get()` performs against *that* instance — not against
"the nearest `Cell`", but against the handler named `a`.

The interesting part starts when the capability travels: a
named instance **can be passed as an argument**:

```kai
fn add(c1: Cell, c2: Cell, dst: Cell) : Unit =
  dst.set(c1.get() + c2.get())
```

Look at that signature carefully. `Cell` appears as a
**parameter type**, not in the effect row. They're two ways of
asking for the same thing:

- **In the row** (`fn f() : T / Cell`): the effect is
  *demanded* — satisfied by a `handle` wrapping the call, or by
  a default.
- **As a parameter** (`fn f(c: Cell) : T`): the capability is
  *provided* by the caller, passed explicitly. It doesn't go in
  the row, because the function asks nothing of its context: it
  already holds its evidence in hand.

With that, three instances of the same effect coexist without
stepping on each other (`examples/ch12/11_instances.kai`):

```kai
handle {
  handle {
    handle {
      add(a, b, target)
      println("target = #{target.get()}")
    } with Cell(0) as target { ... }
  } with Cell(20) as b { ... }
} with Cell(10) as a { ... }
```

```
$ kai run examples/ch12/11_instances.kai
target = 30
```

`add` sums whatever cells it is given, without knowing which is
which. Without named instances you'd have to declare three
identical effects — `CellA`, `CellB`, `CellDst` — and handle
each separately. Pure ceremony, and it doesn't scale.

One important restriction: the capability is **second-class**.
It can travel down the stack — as a call argument, as the
receiver of operations — but it cannot *escape*: you can't
store it in a record, return it, capture it in a closure that
outlives the `handle`, or carry it into a fiber with `spawn`. A
handler is a promise with lexical scope; what needs to outlive
its `handle` is a `Ref[T]` under `Mutable` (§12.7) or an actor
(chapter 14).

If you come from dependency injection, this rings a bell:
passing the capability as a parameter **is** injecting the
dependency, except the type tracks it and the compiler rejects
uses that would let it outlive its lifetime. And if the
explicit wiring gets in your way, the effect row is still
there: they're two ends of the same mechanism, and you choose
per call.

## 12.10 Effect row aliases

When a combination appears many times, name it with `type`:

```kai
effect Log    { log(msg: String) : Unit }
effect Audit  { audit(user: String, action: String) : Unit }

type Tracing = Log + Audit
```

From then on, `: Unit / Tracing` means `: Unit / Log + Audit`.
The alias is **transparent**:
it introduces no new effect, only shortens the row.

```kai
fn make_purchase(user: String, amount: Int) : Unit / Tracing {
  Log.log("start purchase")
  Audit.audit(user, "purchase($#{amount})")
  Log.log("end purchase")
}
```

One restriction: aliases are **closed**. You can't write
`type WithIo[e] = Io + e` (with a row variable), which spares
the compiler unification complications it doesn't need.

An alias used across several signatures, where the saving
shows:

```kai
# examples/ch12/07_alias.kai
effect Log {
  log(msg: String) : Unit
}

effect Audit {
  audit(user: String, action: String) : Unit
}

# `Tracing` groups the two instrumentation effects.
type Tracing = Log + Audit

fn make_purchase(user: String, amount: Int) : Unit / Tracing {
  Log.log("start: purchase by #{user} for #{amount}")
  Audit.audit(user, "purchase($#{amount})")
  Log.log("end: purchase by #{user}")
}

fn main() : Unit / Stdout {
  handle {
    handle {
      make_purchase("ada", 100)
      make_purchase("turing", 250)
    } with Audit {
      audit(user, action, resume) -> {
        println("[AUDIT] #{user}: #{action}")
        resume(())
      }
    }
  } with Log {
    log(msg, resume) -> {
      println("[LOG] " ++ msg)
      resume(())
    }
  }
}
```

```
$ kai run examples/ch12/07_alias.kai
[LOG] start: purchase by ada for 100
[AUDIT] ada: purchase($100)
[LOG] end: purchase by ada
[LOG] start: purchase by turing for 250
[AUDIT] turing: purchase($250)
[LOG] end: purchase by turing
```

## 12.11 Default handlers: the effect carries its own

So far you've written every `handle` by hand. But for some
effects one implementation is so obvious that writing it every
time is pure ceremony: if your effect is `Log` and the
"reasonable" implementation writes to stderr with a timestamp,
you'd want it to ship with the effect.

For that you declare a **`default { }` block** inside the effect.
It's just like a `handle ... with`, but it lives next to the
operations, and the compiler installs it around `main` when
nobody handles the effect by hand.

```kai
effect Log {
  info(msg: String) : Unit
  warn(msg: String) : Unit

  default {
    info(msg, resume) -> $extern_handler("kai_default_log_info")
    warn(msg, resume) -> $extern_handler("kai_default_log_warn")
  }
}
```

The clauses inside `default` have the **same shape** as those in
a `handle`: op name, parameters, `resume`, arrow, body. What
changes is where they live and who fires them. If `main()`
declares `: Unit / Log` and no `handle ... with Log` wraps it, the
compiler emits code equivalent to:

```kai
handle {
  original_main()
} with Log {
  info(msg, resume) -> ...   # the default block's clauses
  warn(msg, resume) -> ...
}
```

You don't write that wrapping: the compiler derives it from the
`default` block and emits it at program entry.

### `$extern_handler`: the sigil and the C bridge

The body of each clause above is `$extern_handler("kai_default_log_info")`.

`$` is a **sigil**: a character that marks a special syntactic
form. In kaikai it introduces a **compiler intrinsic**, a
construct the compiler resolves directly instead of looking up a
function defined in kaikai code. The general form is
`$name(args)`. Today there's just one: `$extern_handler`. There
may be more tomorrow; the sigil is reserved for that family.

`$extern_handler("kai_default_log_info")` means: "the body of this
clause is a call to the C symbol `kai_default_log_info`". The
compiler doesn't look for a kaikai function by that name; it
emits a direct call to the C runtime linked into the program.

It's the bridge between algebraic effects and the concrete world — files, sockets, syscalls. OS primitives live in
C; effects live in kaikai; `$extern_handler` joins them.

### When the default fires and when it doesn't

The lookup rule is §12.4's, with one extra step at the bottom:

1. The nearest `handle ... with Eff` that covers the op wins.
2. If no enclosing handle exists and the op is in `main`'s row,
   the compiler installs the effect's default.
3. If even the default doesn't cover the op, the compiler rejects
   the program when typechecking `main`.

The default **only** fires when the op would escape to `main`.
If your function is inside a `handle`, the handle wins. No
ambiguity, no surprising precedence: nearest wins, always.

### Looking at the original example again

This explains why `println` compiles without every signature
carrying `/ Stdout`:

```kai
fn hi() {
  println("hi")
}

fn main() {
  hi()
}
```

`Stdout` ships from stdlib with a `default` block whose clauses
call `$extern_handler("kai_default_stdout_print")` and friends.
The C symbol writes to the process's real `stdout`. Since `main`
doesn't handle `Stdout`, the compiler installs that default and
the program prints.

To control the output (silence in tests, redirect to a file,
capture it for assertions), you write your own
`handle ... with Stdout`, and inside the block the default
doesn't participate. **Nearest wins**: your `handle` is closer
than the implicit wrapping at `main`'s entry.

### Your own default: the complete example

If you equip your own effect with a default, programs that just
call `main` look just as simple:

```kai
effect MyLog {
  info(msg: String) : Unit
  default {
    info(msg, resume) -> $extern_handler("kai_default_log_info")
  }
}

fn greet(name: String) : Unit / MyLog {
  MyLog.info("hi, " ++ name)
}

fn main() : Unit / Stdout {
  let r = handle {
    MyLog.info("hello from extern_handler")
    7
  } with MyLog {
    info(msg, resume) -> resume(())   # silence inside the handle
  }
  print("result: #{r}")
}
```

Inside the `handle ... with MyLog` the explicit clauses win and
the `info` is silenced. Without that `handle`, the default would
fire and print via the C runtime. `greet` doesn't know the
difference: for it, `MyLog` is whatever the context decides.

### When there's no default — the effect without a net

Not every effect carries a `default`. The `Fail` you declared in
§12.5 is the clear counter-example: if an op can abort the
program, you don't want forgetting to handle it to be legal.
Since it carries no `default` block, a function producing
`/ Fail` must be handled somewhere before `main`, or the compiler
rejects it with a clear message.

Why does `Fail` live here, declared in the file itself, rather
than in the stdlib? A failure effect adds nothing
`Result[a, e]` with postfix `!` doesn't give you better: there
isn't a single `/ Fail` row in the whole stdlib. And its shape —
an operation returning `Nothing` — is precisely the one that
*can't* express the interesting failure, the one where the
consumer picks whether to skip or abort. For that the op has to
return `Unit` and let the handler decide whether to call `resume`.
Appendix D has the full table.

As an example, though, it's unbeatable: the shortest way to show
an operation that never returns.

The same applies to `State[T]`, `Reader[T]`, `Writer[W]`: generic
effects with **no** reasonable implementation outside a context,
so asking you to write one is discipline, not ceremony.

The mental rule: an effect carries a `default` when there's **one
obvious** implementation (write to `stdout`, read the system
clock, generate pseudo-random numbers). If "reasonable" depends on
the program, there's no default and you provide it.

### Wrapper function: the alternative when there's no default

When an effect doesn't ship a `default`, or when the default
exists but your program always wants a different one, the
idiomatic pattern is a **wrapper function**:

```kai
fn with_test_log[A](body: () -> A / MyLog) : A {
  handle {
    body()
  } with MyLog {
    info(msg, resume) -> resume(())   # silence in tests
  }
}

fn main() {
  with_test_log { ->
    greet("kaikai")
    greet("ada")
  }
}
```

The stdlib uses it for `with_reader(env) { body }`,
`with_writer { body }` and `with_mailbox { body }`. Unlike a
default, which lives in the effect declaration, the wrapping is
**explicit in the code**: whoever reads `main` sees the line,
opens the function, and knows what it does.

If your effect has one reasonable default for production and
another for tests, expose both as wrapper functions
(`with_test_log`, `with_quiet_log`) and let `main` use the
default. Tests call the wrapper.

The wrapper in a program: the body names no handler and the
function decides which one gets installed.

```kai
# examples/ch12/09_wrapper_default.kai
effect Log {
  log(msg: String) : Unit
}

fn greet(name: String) : Unit / Log {
  Log.log("hello, " ++ name)
}

# The user's "default": a function that takes a body and runs
# it under the standard handler for Log.
fn with_default_log[A](body: () -> A / Log) : A / Stdout {
  handle {
    body()
  } with Log {
    log(msg, resume) -> {
      println("[LOG] " ++ msg)
      resume(())
    }
  }
}

fn main() {
  # Use 1: with the default. greet knows nothing about the
  # handler.
  with_default_log(() => {
    greet("kaikai")
    greet("ada")
  })

  # Use 2: the caller picks another handler. with_default_log
  # is not involved.
  handle {
    greet("silent mode")
  } with Log {
    log(msg, resume) -> resume(())
  }

  println("(end)")
}
```

```
$ kai run examples/ch12/09_wrapper_default.kai
[LOG] hello, kaikai
[LOG] hello, ada
(end)
```

## 12.12 The stdlib handlers are kaikai code

When `println("hi")` just works, it's easy to imagine the
compiler ships a special case for `Stdout`. It doesn't. The handlers the runtime installs around `main` for
`Stdout`, `Stdin`, `Random`, `Clock`, `File`, `Env`, `NetTcp`, and
the rest are written in **plain stdlib kaikai**: each one is an
`effect ... { ops; default { ... } }` using the same
`$extern_handler` sigil you'd use to connect your effect to C.

```kai
# stdlib/io/console.kai (schematic form)
effect Stdout {
  print(s: String) : Unit
  default {
    print(s, resume) -> $extern_handler("kai_default_stdout_print")
  }
}
```

The compiler doesn't know `Stdout` by name. It knows **`default`
blocks** and **`$extern_handler`**. For `Stdout`, it installs the
default the same way it does for your `MyLog`: by walking the AST
of the effect declaration, not by reading a hardcoded table.

The motive is practical: the AST is the single source of truth,
with no internal tables to keep in sync, and your effects get
the same guarantees as stdlib ones. If your
effect declares `default { }` with `$extern_handler`, the
compiler installs it like a builtin.

The practical consequence: **you can read how `Stdout` is
implemented**. `kai doc effects.Stdout` shows its signature and
its default; the effect is kaikai code like yours. If you wonder
about default semantics — "what happens if the pipe is
closed?", "who catches `EPIPE`?" — the answer lives in the
clause `print(s, resume) -> ...` or in the C symbol it bridges.
The runtime has no secret behavior apart from code you can read.

The rule once more, to nail down the model: the compiler
resolves an effect by checking, in order, (1) the nearest `handle
... with`, (2) the effect's `default { }` block if the op escapes
to `main`, (3) compile error. The stdlib handlers aren't a fourth
category; they're instances of (2).

### Why the sigil has an odd name

`$extern_handler` may sound long because the sigil opens a
system: `$` reserves the namespace of a **family** of
intrinsics, and `$extern_handler` is the one that lives there. Any other bridge to the runtime — asking the current
`errno`, calling a platform-specific symbol — comes in under the
same sigil with a descriptive name: `$os_name`,
`$panic_with_trace`. Reserving `$<ident>(args)` leaves the door
open without relitigating the syntax every time.

If you never bridge an effect to C, you'll never write
`$extern_handler`. But when you see it in the stdlib you'll know
what it is: a clause that hands its body off to a runtime
symbol, with the same syntax as any other handler.

## 12.13 Generators: the continuation as a value

At the top of this chapter I asked you to hold the thought if
this sounded like generators. Time to pay that off, with a piece
you already have.

In §12.5 you learned what a handler can do with `resume`: call
it — in tail position or not — and the body carries on; or not
call it, and the body is discarded. The interesting one is
missing: **keep it**.

A kept `resume` is a value like any other. You put it in a
constructor, return it, and call it later from somewhere else
entirely. That is a generator.

```kai
# stdlib/gen.kai
pub effect Yield[t] { yield(v: t) : Unit }

pub type Gen[t, e] = Done | Next(t, Cont[Unit, Gen[t, e], e])

pub fn generate[t, e](body: () -> Unit / Yield[t] + e) : Gen[t, e] / e =
  handle { body(); Done } with Yield[t] { yield(v, resume) -> Next(v, resume) }
```

Read that clause slowly, because the whole idea is in it:
`yield(v, resume) -> Next(v, resume)`. The handler resumes
nothing: it packs the element with the rest of the computation
and returns it. Whoever receives that `Next(v, k)`
holds the first element and a function that, whenever they say
so, produces the next one.

You'll come back to the `e` in all three signatures below; for
now read it as "whatever effects the producer performs besides
`Yield`".

### The producer doesn't know it's a generator

```kai
# examples/ch12/13_generators.kai (fragment)
fn naturals(from: Int) : Unit / Yield[Int] = {
  Yield.yield(from)
  naturals(from + 1)
}
```

Ordinary recursion, the kind you wrote back in chapter 6. No
special keyword, no state machine, no odd return type. The
function never terminates, and that's fine: it runs on its own
stack segment and advances only when someone asks for the next
element.

Pulling the elements by hand shows the machinery:

```kai
let g = generate { naturals(10) }
match g {
  Done -> println("empty generator")
  Next(a, k) -> {
    println("first:  #{a}")
    match k(()) {
      Done       -> println("exhausted")
      Next(b, _) -> println("second: #{b}")
    }
  }
}
```

That `k(())` runs `naturals` from where it left off to its next
`Yield.yield`. If you never call `k`, the producer never runs
again: dropping a `Gen` discontinues its
producer and releases its segment.

### In practice, the pipes

Nobody writes `match` over `Next` in day-to-day code. `gen`
ships its stages with the canonical signatures, so the pipes
from §6.4 work exactly as they do over lists and streams:

```kai
let total = generate { naturals(1) }
  |  (n => n * n)              # lazy map: squares
  |? (n => n % 2 == 1)         # lazy filter: the odd ones
  |> take_until(n => n > 100)  # cut at the first one past 100
  |> reduce((a, b) => a + b)
```

```
$ kai run examples/ch12/13_generators.kai
first:  10
second: 11
sum of odd squares up to 100: Some(286)
```

`naturals(1)` never ends; `take_until` cuts. Between the two
there's no intermediate list, and the producer never generated
an element nobody was going to look at. The `Some` is there
because `reduce` returns an `Option`: a generator can be empty,
and the type says so instead of inventing a zero.

If chapter 6 left you wondering when to reach for `stream` and
when for this, it depends on which side you're on. `stream`
consumes something that already exists — a list, a file — and is
a re-runnable recipe. `gen` is for when you write the producer
yourself.

And if you write it yourself but it's pure, you want neither:
you want a `Seq`, §6.4's lazy sequence, whose cells are computed
once and then shared. What sets `gen` apart is that its producer
may perform effects: it's the only one of the three that
carries them in the row. A `Seq`'s stages must be pure,
so a `Seq` reads no file and asks nobody anything.

### The producer's effects, and who serves them

Look at the three signatures again: the `e` in all of them is the
producer's row. A generator doesn't demand a pure body. Whatever
the producer does besides `Yield` travels in the type, and it
happens **where someone steps the generator**, not where it was
created: the handlers that serve it are the ones around the
consumer.

```kai
# examples/ch12/15_producer_effects.kai (fragment)
fn noisy(n: Int) : Unit / Yield[Int] + Stdout = {
  println("  producing #{n}")
  Yield.yield(n)
  noisy(n + 1)
}
```

```
$ kai run examples/ch12/15_producer_effects.kai
the producer's effects run as you step it
  producing 1
  producing 2
  producing 3
total = Some(6)
```

`noisy` never ends and the `println` is its own, but the three
lines come out because the consumer asked for three elements.
There is no fourth: `take_until` cut at `3` and the producer never
got to take another step.

That leaves an uncomfortable question. If the consumer stops
whenever it likes and the producer had a file open, who closes
it? Not the consumer: it just stops calling `k`. The answer is
§12.8's, and it arrives without the consumer knowing it exists.

```kai
# examples/ch12/16_dropping_the_generator.kai (fragment)
fn with_resource() : Unit / Yield[String] + Stdout =
  handle {
    read_all()
  } with Logbook {
    initially { println("  opening the file"); 1 }
    finally   { println("  closing the file") }
    line(resume) -> resume("line #{state}", state + 1)
    return(x)    -> x
  }
```

```
 run examples/ch12/16_dropping_the_generator.kai
dropping the generator runs the cleanup
  opening the file
  read 'line 1' and I'm asking for no more
  closing the file
the producer is gone
```

The `finally` ran on its own, the moment the `Gen` was left
ownerless and before `main` moved on. Discarding a generator
takes it apart.

That's the division of labor the row proposes. It doesn't forbid
I/O in a producer — a rule easy to implement and annoying to
use. It tells you in the type which effects you must serve to
step it, and guarantees that dropping it halfway is a clean
operation.

### Why this matters more than it looks

Python needed a keyword for generators, then found out it didn't
compose with `async`: hence `async def`, and hence
`async function*`. Every new capability asked for new syntax, and
the combinations for more still. It's §12.1's complaint in a
different costume.

Here the whole mechanism is 108 lines of stdlib. The compiler
doesn't know `Yield`: there is no `yield` keyword, there's an
operation that happens to be called that. And it composes with
everything else because it isn't a special case of anything.

That's what you buy when the continuation is a first-class
value: generators nobody had to add to the language.

## 12.14 Case study: configuration processor

We close with an example that mixes the three patterns you've
used: logging, state, failure. The program takes `key=value`
lines, parses them, logs each step, counts how many succeeded,
and aborts if any line has the wrong format.

```kai
effect Log {
  log(msg: String) : Unit
}

effect State[T] {
  get() : T
  set(v: T) : Unit
}

effect Fail {
  fail(reason: String) : Nothing
}

type Entry = { key: String, value: String }

fn parse(line: String) : Entry / Fail {
  match string.split(line, "=") {
    [k, v] -> Entry { key: k, value: v }
    _      -> Fail.fail("invalid line: '#{line}'")
  }
}

fn process(lines: [String]) : Int / Log + State[Int] + Fail {
  list.foreach(lines, (l) => {
    let e = parse(l)
    Log.log("#{e.key} = #{e.value}")
    State.set(State.get() + 1)
  })
  State.get()
}
```

`process` declares the three effects and uses them freely: it
parses (can fail), logs, accumulates.
But it decides nothing about the context it runs in.

In `main`, the three nested handlers decide:

```kai
fn main() : Unit / Stdout {
  let n = handle {
    handle {
      handle {
        process(["name=ada", "age=42", "role=admin"])
      } with State[Int](0) {
        get(resume)    -> resume(state)
        set(v, resume) -> resume((), v)
        return(x)      -> x
      }
    } with Log {
      log(msg, resume) -> {
        println("[LOG] " ++ msg)
        resume(())
      }
    }
  } with Fail {
    fail(reason, resume) -> {
      println("error: " ++ reason)
      -1
    }
  }
  println("entries processed: #{n}")
}
```

Output:

```
$ kai run examples/ch12/08_config_parser.kai
[LOG] name = ada
[LOG] age = 42
[LOG] role = admin
entries processed: 3
```

If a line is invalid, the outer `Fail` catches it, prints the
reason, and `n` ends up `-1`. The inner `Log` and `State`
already emitted whatever they got to before the failure.

The three patterns cooperate, each doing its part, and
`process` is **directly testable**: no files, no IO, no mocks.
In a test, the three handlers get other implementations: `Log` accumulates messages into a
list instead of printing, `Fail` propagates inside a
`Result`, `State` starts from whatever value the test wants.

## 12.15 Philosophy: three ideas worth remembering

If this feels like a lot of pieces, three ideas underpin
everything else:

1. **Effects are visible in the type.** If a function can
   fail, suspend, mutate, or do IO, its signature says so.
   No invisible exceptions, no infectious `async`, no hidden
   dependencies.

2. **The handler decides what happens.** A function's body
   declares it needs a capability; the handler in context
   decides how to materialize it. That decoupling replaces
   dependency injection, mocking, and global configuration.

3. **Zero cost when unused.** The compiler resolves handlers
   at compile time when it can (which is most cases), and the
   generated code is as fast as if you'd written a direct
   `if`, with no structural overhead from effects in the
   type. Same promise as units of measure and
   contracts: rich information in the type, efficient code
   underneath.

Algebraic effects come from academia (Pretnar, Plotkin,
Power) and appeared in languages like Koka, Eff and Effekt
before kaikai. What kaikai contributes is readable syntax
(the `/ Eff` notation in the signature), integration with the
rest of the language (rows instead of lists, aliases), and a
default-handler model with no special cases: the stdlib
handlers are declared in kaikai with the same shape yours use.
But the underlying idea is old and solid.

If you're still not comfortable, don't worry. Effects are the
piece that takes longest to land. You'll come back to this
chapter several times, and each reading peels back one more
layer.

## Exercises

**12.1.** Write an effect `Clock` with one operation
`now() : Int` (milliseconds since start). Write a function
`measure` that runs a block and returns how long it took
using `Clock`. Then write two handlers: a real one (queries
the system clock) and a simulated one (advances a counter).
What is the second one for?

**12.2.** Modify `sum` from §12.6 to return both the total
and the number of elements summed, without adding parameters.
Hint: change `return(x) -> x`.

**12.3.** The case study in §12.14 prints `[LOG]` for each
entry. Change the `Log` handler so that instead of printing,
it accumulates the messages into a list and returns them as
part of the final result, along with `n`. Hint: you'll need
another `State`.

**12.4.** Write `fn count_evens(xs: [Int]) : Int` two ways:
one with `var` and `list.foreach`, the other without `var`,
using `list.filter` and `list.length`. Which feels clearer?
Why does the `var` version add no effect to the signature?

**12.5.** Build an effect `Choice` with one operation
`choose(options: [Int]) : Int` that supplies "some" of the
options. Write a handler that always picks the first, and
another that picks the last. How would the implementation
change if you wanted a handler that explored **all** options
(backtracking)? Hint: it would need to call `resume` more
than once. That's *multi-shot* and lives under
`resume_multishot`.

**12.6.** Take a program you have in another language where
you use dependency injection to mock services in tests. Write
down in pseudocode which effects you'd declare and what the
test vs production handlers would look like. How much of the
original code survives unchanged?

**12.7.** Read the difference between `resume` (one-shot) and
`resume_multishot` in the language documentation. Why does
kaikai make the common case cheap and force you to mark the
expensive case explicitly?

**12.8.** Declare an effect `MyLog` with operation `info(msg:
String) : Unit` and a `default { }` block that bridges to a
fictional C symbol `my_log_info_to_stderr` via
`$extern_handler`. Then write a wrapper function
`with_quiet_log` that silences the messages. A `main` without
the wrapper triggers the default; a `main` wrapped in
`with_quiet_log` doesn't. Compare with how you'd do the same
in a language with classical dependency injection.

**12.9.** Why doesn't the `Fail` of §12.5 carry a `default { }`
block? Pick three hypothetical effects (yours or stdlib ones you
imagine) and for each decide whether it would have a default.
Argue in one line why or why not. Then take the argument behind
`Fail`'s retirement from the stdlib (appendix D §D.6) and apply
it to all three: which of them would be better expressed as
`Result[a, e]`?

**12.10.** Read the declaration of `Stdout` in
`stdlib/io/console.kai` in the language repo. What does the
default's clause do when the pipe is closed (`EPIPE`)? Where
does that logic live: in kaikai or in the C symbol it bridges
to?

**12.11.** Chapter 13 covers fibers: concurrent tasks modeled
as effects. Note before reading it: what operations would an
effect `Spawn` need? What decision would you make as a handler
when a child fiber aborts?
