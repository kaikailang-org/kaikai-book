# Chapter 12 · Algebraic effects

This is the chapter where kaikai earns its novelty. Up to now
we've seen types, pattern matching, protocols, units of
measure, contracts. All elegant pieces, none unique to kaikai:
you'd find counterparts in Haskell, Rust, F#. **Algebraic
effects** are what set kaikai apart from nearly every
production-ready language today.

The idea is easy to state and strange at first: **a function
declares in its signature which effects it uses, but not how
they happen**. Printing to a screen, reading a file, failing
with an error, suspending execution, generating a random
number — these are all effects. The function says "I need
this capability"; code further up decides what "this
capability" means in the current context. The separation
between **what** and **how** is the heart of the system.

If that sounds like *dependency injection*, hold the thought.
If it sounds like exceptions, hold that too. If it sounds
like generators, also yes. The reason one mechanism resembles
so many things is that, in the theory underneath, all those
things are the same. Algebraic effects are the generalisation.

We'll move slowly. This chapter rewards patience more than
speed: the first reading is for each idea to register; solid
intuition lands when you come back a month later and it
suddenly feels obvious.

## 12.1 The friction effects resolve

Before showing the syntax, let's look at the concrete
problems effects solve. If you recognize the pattern from
your work, you'll know why a new tool is worth learning.

### Invisible exceptions

In Java or Python, any function call can throw an exception
and nothing in the signature tells you. You read the code and
you don't know what can fail. You find out in production.

```python
def load_user(id):
    return db.get(id)   # can this fail? with what exceptions?
```

Languages with checked exceptions (Java) tried to fix it by
forcing you to declare `throws`. The result was that people
wrote `throws Exception` to silence the compiler, and we were
back where we started. Modern functional languages (Rust,
OCaml, kaikai's chapter 5) push you toward `Result` or
`Option`: the cost of failure shows up in the type, the
caller decides what to do. Good for local failures, heavy
when many functions fail: signatures fill up with wrapping
and unwrapping.

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

Bob Nystrom named this in 2015 with his famous essay **"What
Color is Your Function?"**. The idea: `async` splits functions
into two colors. Red ones (`async`) and blue ones (non-async).
A red function can call a blue one, but a blue one can't call
a red one. If you have a blue function and you need to use a
red one inside, you have to repaint the blue. And the one
that called it. All the way up. It's an infection that won't
stay local.

The essay's point isn't that `async` is bad. It's that this
kind of marker in the signature, when it's specific to one
type of effect, creates two parallel systems that don't
compose. `async` doesn't compose with generators: you need
`async function*`. It doesn't compose cleanly with exceptions
(exceptions in async functions become rejected promises).
Each new combination needs its own syntax.

Algebraic effects solve the problem at the root: **there are
no special colors**, only one dimension — the effect row.
`async` doesn't need to be a syntactic property of the
function; it's simply one effect among others. And the row
extends without new syntax: `/ Async + Fail` is no stranger
than `/ Async`.

### Dependency injection

To make a function testable, you pass the "external things"
it uses as parameters: the clock, the logger, the database
client. You pass mocks in tests, the real things in
production.

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

Algebraic effects are **one construct** that covers all four.
What exceptions, `async`/`await`, and dependency injection do
separately and often poorly, effects do with a single
mechanism.

## 12.2 Declaring an `effect`

An effect is an **interface**. It declares what operations
exist, with what signatures, but not how they're implemented.

```kai
effect Log {
  log(msg: String) : Unit
}
```

This introduces an effect named `Log` with one operation,
`log`, that takes a string and returns nothing useful. Any
function that calls `Log.log(...)` is using the `Log` effect.

What it does **not** introduce: implementation. There's no
body here, no `if`, no print. Just the signature. That's the
fundamental difference with a protocol or a traditional
interface: the effect decides nothing, it only declares what
can be requested.

Operations in an effect are declared without the `fn` keyword
and without a body — just name, parameters, return type. The
same effect can have several operations:

```kai
effect Io {
  print(s: String)  : Unit
  read_line()       : String
}
```

## 12.3 Calling an operation: the signature changes

To use an operation, call the effect as if it were a
namespace and the operation a method:

```kai
fn greet(name: String) : Unit / Log {
  Log.log("hello, " ++ name)
}
```

Two new things:

- **`Log.log(...)`** is the invocation syntax. The effect is
  the namespace; the operation is the method.
- **`: Unit / Log`** in the signature. The slash introduces
  the **effect row**. It's the list of effects the function
  needs to run. Without `/ Log`, the function doesn't
  compile: it's using a capability it didn't declare.

The type system guarantees that **every function using an
effect declares it**. If you call `Log.log(...)` from a
function without `/ Log`, the compiler rejects it with a
clear message. There's no escape: effects are visible in the
signature, always.

And this is recursive. If `greet` uses `Log` and `main` calls
`greet`, then `main` also needs `Log` in its signature,
unless it **handles** the effect first (that's §12.4).

```kai
fn main() : Unit / Log {       # propagates the effect
  greet("kaikai")
}
```

This is the same contagion principle we saw with
`async`/`await`, but without the color problem: there's no
special syntax to "pay for the effect" at the call site.
`Log.log(...)` is a call like any other. The signature is
where the discipline lives, and adding a new effect doesn't
introduce a new incompatible color: it only extends the row.

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

`Log + Fail` is the **row** of effects. Order doesn't matter:
the row is a set, not a sequence. `Log + Fail` and
`Fail + Log` are the same row to the compiler. The `+`
operator is just syntax for building it.

## 12.4 Handling an effect with `handle ... with`

The interesting part: **deciding what an effect means** at a
specific point in the program. That's what `handle ... with`
does.

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

Read literally: "run this block, and whenever someone inside
invokes `Log.log`, do this". The handler intercepts each
call to `log`, decides what happens, and resumes with
`resume(...)`.

Three details worth pinning down:

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

The remarkable thing: **`main` doesn't need to declare `Log`
in its signature**. The `handle` "consumes" it: the inside
uses it, the `with` provides it, and `main`'s effect row
comes out without `Log`. The type system stays strict, but
the handler is the door through which an effect leaves the
scope.

### The same body with two handlers

The power shows when you notice that `greet` doesn't change
between runs. One handler gives you verbose logs; another
gives you silence:

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

`greet` doesn't notice the difference. The same is true for a
handler that writes to a file, one that accumulates messages
into a list, one that ships them over the network. The
function `greet` is **handler-agnostic**.

This is what replaces dependency injection. No constructor to
pass around, no service to mock: the handler IS the
implementation.

## 12.5 `resume`: the handler decides what happens next

`resume` is the piece that confuses people most at first, and
the one that pays off most once you get it. It's the
**continuation** of the body from the point of the operation.

When the body invokes `Log.log("hi")`, control jumps to the
handler. The handler receives two things:

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

`Log.log` returns nothing useful, but other operations do.
An effect can **supply** a value:

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

This replaces many uses of dependency injection: instead of
threading `name` as a parameter through the whole call tree,
you "ask" for it via an effect, and the handler in `main`
decides the answer. In tests, a different handler answers
something else.

### Handlers that DON'T call `resume`

If the handler **doesn't** call `resume`, the body is
discarded and the handler's value becomes the value of the
entire `handle`. This is how exceptions are built:

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
(chapter 3's bottom type): no inhabitants, no value of
`Nothing` can be constructed. By construction, there's
nothing to pass to `resume`, so the type system guarantees
you can't continue the body after `Fail.fail`. The program
doesn't break if you try; the compiler doesn't let you write
the code.

That's the key: kaikai's "exceptions" are a special case of
the general mechanism. There's no special syntax for
`try/catch`; there's `handle` and an effect whose operation
returns `Nothing`.

## 12.6 Handlers with state: the `State` pattern

So far our handlers have been stateless: they decide what to
do and resume. But a handler can carry **its own state**
without the body noticing. This replaces global mutation.

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

Three new things:

- **`State[T]` is parametric.** The type `T` is what state
  holds. Here it'll be `Int`.
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
- **`return(x) -> x`** runs when the body completes normally.
  `x` is the body's result. Here we drop the final state and
  return only `x`; if you wanted both, you'd write
  `return(x) -> (x, state)`.

From the body's view, there's no mutation: only invocations
to pure-looking operations. Mutation lives entirely inside
the handler. From outside the `handle`, nothing shows.

This pattern is generic: with the same shape you build
`Reader` (read-only environment), `Writer` (output
accumulation), counters, caches, sessions. All without
touching global variables, all without threading parameters.

## 12.7 `var`, `Ref[T]` and `Array[T]`: two distinct mechanisms

`State[T]` is the general tool for carrying a changing value,
but writing `handle ... with State[Int](0)` every time you
want a local counter would be tedious. So kaikai ships
syntactic sugar and, separately, a stdlib effect for cases
where memory outlives a block. They're two distinct
constructs and worth keeping apart.

### `var`: sugar over `State[T]`

The short form for a local cell:

```kai
fn count_evens(xs: [Int]) : Int {
  var n = 0
  list.foreach(xs, (x) => {
    if x % 2 == 0 {
      n := @n + 1
    }
  })
  @n
}
```

Three new forms:

- **`var n = 0`** declares the cell with its initial value.
- **`@n`** reads the current value.
- **`n := v`** writes `v`.

How does it work? **`var` is syntactic sugar over `State[T]`.**
The compiler rewrites

```kai
var n = 0
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
where the `var` appears, the `State[Int]` effect closes right
there and never escapes the function's signature. From the
caller's side, `count_evens` is just `: Int`. No effects.

It's not magic masking: the `handle` is literally next to the
`var`. The row closes at the exact spot where the cell is
declared.

And it isn't slow: the compiler detects the pattern "local
cell with one-shot resume" and specializes it down to a stack
frame slot, equivalent to a C mutable variable. Zero cost
compared to the imperative code you'd otherwise write.

### `Mutable`: the effect behind `Ref[T]` and `Array[T]`

`var` covers local cells. But there are cases where memory
needs to **outlive a block**: an array you'll return, a cell
you'll pass between functions, a structure shared by several
routines. For those cases kaikai ships two stdlib types,
`Ref[T]` and `Array[T]`, and both live under the **`Mutable`**
effect.

```kai
fn fill(n: Int) : Array[Int] {
  let a = Mutable.array_make(n, 0)
  var i = 0
  list.foreach([0..n], (_) => {
    a[i] := @i * 2
    i := @i + 1
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

Look at the signature of `fill`: it says `: Array[Int]`,
**without `Mutable`**. Why, given the function obviously
mutates?

Because `Mutable` follows the discipline of **observable
effects**: the effect shows up in the signature only when the
mutation is **visible to the caller**. And here it isn't. The
array is created inside, filled inside, and returned only
when it's complete. Whoever receives it gets a settled value;
they don't observe any mutation.

### When `Mutable` becomes visible

If the mutation is **observable**, the effect appears:

```kai
fn fill_in_place(a: Array[Int]) : Unit / Mutable {
  let n = Mutable.array_length(a)
  var i = 0
  list.foreach([0..n], (_) => {
    a[i] := @i * 2
    i := @i + 1
  })
}
```

Here `a` comes from outside. The caller holds a reference to
the same array we're modifying. The mutation is visible to
the caller, and the signature must declare it.

The rule from §12.3 still applies, just for any other effect:
the type system guarantees that every function producing an
observable effect declares it. Hidden assignments don't
exist.

### `Mutable` versus `State[T]`

Both represent mutable state. When to use which?

- **`var` (which is `State[T]`)**: the cell lives inside the
  block. No need to survive the function, no need to be
  passed to other routines — just a local accumulator or
  counter. Signature stays clean.
- **`Mutable` with `Ref[T]` or `Array[T]`**: memory outlives
  the block or is shared across functions. Appears in the
  signature whenever the mutation is observable to the
  caller.

If you pass a `Ref[T]` or `Array[T]` as argument, or return
one after mutating it, you're in `Mutable` territory. If you
just need a local counter, it's `var`.

## 12.8 Composing effects: nested handlers

Real functions use more than one effect. One that logs and
accumulates can declare `/ Log + State[Int]`, and in `main`
you handle it with two nested `handle`s:

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
only prints. Either order works. But with `Fail` inside
`State`, the order decides whether state survives a failure
(outer `Fail`) or is discarded (inner `Fail`). Each
combination has an explicit, checkable semantics.

This is a deep difference with `try/catch + global
variables`: there, the order is implicit and runtime-
dependent. Here it's explicit and you decide it in the
signature of the `handle`s.

## 12.9 Effect row aliases

When a combination appears many times, name it with `type`:

```kai
effect Log    { log(msg: String) : Unit }
effect Audit  { audit(user: String, action: String) : Unit }

type Tracing = Log + Audit
```

From there on, writing `: Unit / Tracing` is the same as
writing `: Unit / Log + Audit`. The alias is **transparent**:
it introduces no new effect, only shortens the row.

```kai
fn make_purchase(user: String, amount: Int) : Unit / Tracing {
  Log.log("start purchase")
  Audit.audit(user, "purchase($#{amount})")
  Log.log("end purchase")
}
```

One restriction: aliases must be **closed**. You can't write
`type WithIo[e] = Io + e` (with a row variable). The
restriction sidesteps unification complications the compiler
doesn't need to pay for.

## 12.10 Your own default handler: the wrapper pattern

What if you want **your** effect to come with a "preinstalled"
handler, the way `println` comes with `Stdout`? The short
answer is that in v1 you can't: the runtime installs default
handlers only for stdlib effects (`Stdout`, `Stdin`, `Env`,
`File`, `Random`, `Time`, etc.), and the ability to register
automatic handlers for your own effects is out of scope.

The idiomatic pattern that gets close is to write a **wrapper
function** that applies the standard handler:

```kai
effect Log {
  log(msg: String) : Unit
}

fn with_default_log[A](body: () -> A / Log) : A {
  handle {
    body()
  } with Log {
    log(msg, resume) -> {
      println("[LOG] " ++ msg)
      resume(())
    }
  }
}
```

`with_default_log` takes a body that needs `Log` and returns
**the same type the body returns**, already handled. Whoever
uses it gets the standard handler without writing it:

```kai
fn main() {
  with_default_log(() => {
    greet("kaikai")
    greet("ada")
  })
}
```

Whoever wants different behavior just doesn't call
`with_default_log` and writes their own `handle`. The
difference from an "automatic" handler is the extra line
wrapping the body, but in exchange the default behavior is
**explicit and opt-in**, not hidden in the runtime. This is
what the stdlib itself does for constructs like `try { body }`
or `with_state(0) { body }`: trailing-lambda syntax keeps it
almost as clean as an implicit handler:

```kai
fn main() {
  with_default_log { ->
    greet("kaikai")
    greet("ada")
  }
}
```

There's a pedagogical value on top of the practical one: when
the default handler lives in a named function in the effect's
module, the reader who runs into `with_default_log` can go
read it and see exactly what it does. The runtime doesn't
offer that transparency for its own defaults.

If your effect has one default for production and another for
tests, expose both as `with_default_log` and `with_test_log`,
same signature. Whoever writes tests picks the second;
whoever writes `main`, the first. The effect's module becomes
a catalog of "canonical configurations".

## 12.11 Runtime default handlers

There are effects a program uses so often that `kai` handles
them without you declaring anything. The clearest case is
`println`: it writes to standard output, which is an effect.
Why doesn't it show up in every signature?

```kai
fn hi() {
  println("hi")
}

fn main() {
  hi()
}
```

This compiles. The reason: `println` is backed by a `Stdout`
handler that kaikai installs automatically around `main`. For
simple programs, you don't have to think about the effect.
When you want to control it (silence in tests, redirect to
file, capture the output), install your own `Stdout` handler,
and inside the `handle` the runtime's one steps out.

The rule: **handlers closer to the use win**. The runtime's
implicit handler is the farthest, so it's the last resort.
Any `handle` you place closer intercepts first.

Other effects with default handlers in `main`: `Stdin`,
`Random`, `Time`, `Env`. This is so "hello-world" programs
don't carry signature ceremony. The language reference's
chapter 12 lists exactly which.

## 12.12 Case study: configuration processor

We close with an example that mixes the three patterns we
saw: logging, state, failure. The program processes a list of
lines with format `key=value`, parses them, logs each step,
counts how many succeeded, and aborts if any line has the
wrong format.

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

`process` declares the three effects in its signature and
uses them freely: it parses (can fail), logs, accumulates.
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
      0 - 1
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

And if a line is invalid, the outer `Fail` catches it, prints
the reason, and `n` ends up `-1`. The inner `Log` and `State`
already emitted whatever they caught before the failure.

Why is this a good closing example? Because it shows the
three patterns cooperating, each contributing something
different, and because `process` is **directly testable**:
no files, no IO, no mocks. In a test, the three handlers have
different implementations: `Log` accumulates messages into a
list instead of printing, `Fail` propagates inside a
`Result`, `State` starts from whatever value the test wants.

## 12.13 Philosophy: three ideas worth remembering

If this feels like a lot of pieces, three ideas underpin
everything else:

1. **Effects are visible in the type.** If a function can
   fail, suspend, mutate, or do IO, its signature says so.
   No invisible exceptions, no infectious `async`, no hidden
   dependencies.

2. **The handler decides what happens.** A function's body
   declares it needs a capability. The handler in context
   decides how to materialize it. That decoupling replaces
   dependency injection, mocking, global configuration.

3. **Zero cost when unused.** The compiler resolves handlers
   at compile time when it can (which is most cases), and the
   generated code is as fast as if you'd written a direct
   `if`. There's no structural overhead from having effects
   in the type. Same promise as units of measure and
   contracts: rich information in the type, efficient code
   underneath.

Algebraic effects come from academia (Pretnar, Plotkin,
Power) and appeared in languages like Koka, Eff and Effekt
before kaikai. What kaikai contributes is readable syntax
(the `/ Eff` notation in the signature), integration with the
rest of the language (rows instead of lists, aliases), and
default handlers so simple programs don't carry ceremony. But
the underlying idea is old and solid.

If after this chapter you're still not comfortable, don't
worry. Effects are the piece that takes the longest to land.
You'll read this chapter several times. Each reading peels
back one more layer.

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

**12.3.** The case study in §12.12 prints `[LOG]` for each
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

**12.8.** Take `Log` from §12.10 and add a second "default":
`with_silent_log`, which drops the messages. Then write a
function that uses `Log` and test it with both handlers
without modifying the function. Compare with how you'd do the
same thing in a language with classical dependency injection.

**12.9.** Chapter 13 covers fibers: concurrent tasks
modeled as effects. Note before reading it: what operations
would an effect `Spawn` need? What decision would you make as
a handler when a child fiber aborts?
