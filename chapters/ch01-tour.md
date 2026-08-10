# Chapter 1 · A Tour of kaikai

The best way to get to know a language is to read it and run it.
That is how I learned every language I know, which is why this
book opens with programs instead of definitions. This chapter is
a guided tour of kaikai in ten short programs.
None of them runs longer than thirty lines, every one of them
compiles, and together they cover the shapes you will see again
and again in the rest of the book: declarations, algebraic data
types, pattern matching, effects, fibers, protocols, units of
measure, contracts, inline tests, and typed holes.

We will not explain every detail yet. The point is to leave you
with a view of the language from above, and the sense that you
can already read kaikai code even when some of the corners are
still blurry. The corners come into focus in the chapters that
follow.

If you want to follow along on your own machine, the source
files for this chapter live under `examples/ch01/` in the book
repository. Installation of `kai` is covered at the end of the
chapter, in §1.12 — if you need it now, jump there first and come
back.

## 1.1 Hello, kaikai

The oldest exercise in the book, in kaikai:

```kai
fn main() {
  println("Hello, kaikai")
}
```

```
$ kai run examples/ch01/01_hello.kai
Hello, kaikai
```

Four things to notice before moving on:

- Every kaikai program starts at `fn main()`. There is no
  configuration file, no `package main` declaration, no
  enclosing class. A function with that name in some file is
  enough.
- `fn` introduces functions. The keyword is short on purpose —
  you will type it a lot.
- Curly braces `{ ... }` group a block of statements, but a
  block is also an expression: the last value it produces is
  the value of the block. We don't lean on this here, but you
  will use it.
- `println` does not require an `import`. It is available in
  every program because it writes to standard output through
  an effect that kaikai installs by default. Chapter 9 opens
  that box; for now, it just works.

There is no semicolon at the end of the line. There is no
`return` for a function that does not return a value. You don't
even need to declare a return type on `main` when there is
nothing useful to return. All of this is by design: kaikai
tries not to make you write the obvious. When there *is*
something useful to return, one convention is worth knowing up
front: a `main` returning `Int` uses that number as the
process's exit status, just like C or Go. Chapter 16 §16.1
picks it up.

## 1.2 Algebraic types and `match`: FizzBuzz

The classic interview exercise, in kaikai:

```kai
type Tag
  = Both
  | Fizz
  | Buzz
  | Other(Int)

fn classify(n: Int) : Tag {
  if n % 15 == 0     { Both }
  else if n % 3 == 0 { Fizz }
  else if n % 5 == 0 { Buzz }
  else               { Other(n) }
}

fn label(c: Tag) : String {
  match c {
    Both     -> "FizzBuzz"
    Fizz     -> "Fizz"
    Buzz     -> "Buzz"
    Other(n) -> int_to_string(n)
  }
}

fn loop(i: Int, n: Int) : Unit / Stdout {
  if i <= n {
    println(label(classify(i)))
    loop(i + 1, n)
  }
}

fn main() {
  loop(1, 15)
}
```

What is interesting about this version is not that it prints
`1, 2, Fizz, 4, Buzz, ...`. Any language can do that. What is
interesting is what we did to get there.

We defined a **sum type**: `Tag` is one of four constructors.
Three are bare names (`Both`, `Fizz`, `Buzz`) and one carries a
payload (`Other(Int)`). If you come from an imperative
language, this looks like an `enum` with associated data. If
you come from an object-oriented one, it looks like a sealed
class hierarchy. The difference is that this declaration
brings no inheritance, no virtual methods, nothing beyond what
you see: four ways to construct a value of type `Tag`.

`classify` decides which of the four to build. Look at the
`if`: no `then`, no parentheses around the condition, and each
branch is a block that produces a value. The `if` itself is an
expression that returns a `Tag`, and the body of the function
*is* that expression — no `return`, no intermediate
assignment. This is what chapter 2 will call **expression, not
statement**, and it is one of the few habit changes you will
have to make.

`label` consumes a `Tag` with `match`. Each arm is a **pattern**
followed by `->` and the expression that pattern produces. The
pattern `Other(n)` doesn't only say "this was built with the
`Other` constructor"; it also unpacks the payload and binds it
to the name `n`, ready to use on the right-hand side.
Destructuring, comparing, and declaring a name happen in a
single move.

`loop` is recursive. There is no `while` statement and no `for`
statement: recursion is the base of iteration. A `while` does
exist, but it is an ordinary stdlib function that reads like a
keyword, and chapter 6 covers it along with the rest of the
iteration conveniences. So that base does not cost your program anything,
the language guarantees **mandatory tail-call optimization**: a
recursive call in tail position does not consume stack.
`loop(1, 1_000_000)` works without blowing up.

One thing that will look strange and that we leave for chapter
12: the signature of `loop` says `: Unit / Stdout`. The part
after the slash is the set of **effects** the function uses.
`Stdout` means "this function writes to the terminal". Without
it, the compiler would not let you call `println` inside. Don't
worry about the details yet — the full story is in chapter 12.

## 1.3 A calculator with a recursive AST

Something with a bit more meat. A small calculator that
represents arithmetic expressions as a tree.

```kai
type Expr
  = Lit(Int)
  | Add(Expr, Expr)
  | Mul(Expr, Expr)
  | Neg(Expr)

fn eval(e: Expr) : Int {
  match e {
    Lit(n)    -> n
    Add(l, r) -> eval(l) + eval(r)
    Mul(l, r) -> eval(l) * eval(r)
    Neg(x)    -> -eval(x)
  }
}

fn main() {
  let e = Add(Lit(2), Mul(Lit(3), Lit(4)))
  println(int_to_string(eval(e)))
}
```

```
$ kai run examples/ch01/03_calculator.kai
14
```

`Expr` is a sum type just like the one in FizzBuzz, with one
difference: **it mentions itself in its own constructors**.
`Add` takes two `Expr`s. So does `Mul`. `Neg` takes one. As a
result, a value of type `Expr` can be a tree of any depth.

That is the key tool for representing languages,
configurations, queries, commands, almost any structure with
nesting. You will see it often. Chapter 5 dedicates a whole
section to this pattern.

`eval` walks the tree with `match`. Each case recurses on the
children. Exhaustiveness is checked by the compiler: if you add
a constructor to `Expr` and forget an arm in `eval`, it does
not compile. This is huge and will save you many hours.
Chapter 5 explores it carefully; for now, trust it.

`let` introduces a local binding. The type is inferred from
the right-hand side. There is no `var`, no `mutable`, no
reassignment: `let e = ...` binds `e` to a value, and that
value does not change. If you really need to mutate something,
kaikai lets you, but it asks you to declare it (chapter 12).
This is the other half of the habit change: **immutability by
default**.

## 1.4 A custom effect with a handler

Until now, every effect we used was `println`, which works
because kaikai installs a default handler for it. Let's see
what happens when we declare our own.

```kai
effect Log {
  log(msg: String) : Unit
}

fn greet(name: String) : Unit / Log {
  Log.log("hello, " ++ name)
}

fn main() {
  handle {
    greet("kaikai")
    greet("world")
  } with Log {
    log(msg, resume) -> {
      println("[INFO] " ++ msg)
      resume(())
    }
  }
}
```

```
$ kai run examples/ch01/04_effect.kai
[INFO] hello, kaikai
[INFO] hello, world
```

This is the example most likely to make you slow down. That is
deliberate. Algebraic effects are kaikai's distinctive bet, and
we want you to see them running before we explain them
seriously.

What is going on:

- `effect Log { log(msg: String) : Unit }` declares a new
  effect called `Log` with one operation, `log`, taking a
  string and returning nothing.
- `greet` uses that operation. Its signature — `: Unit / Log` —
  declares that the function has the `Log` effect, without
  saying *how* the effect is realized. `greet` is agnostic: it
  doesn't know whether messages go to the terminal, to a file,
  or nowhere at all.
- The decision happens at `handle ... with Log { ... }`. There,
  inside `main`, we say: "for this block, when someone invokes
  `Log.log(msg)`, run this code". The handler prints the
  message with an `[INFO]` prefix and hands control back via
  `resume(())`, which continues the program where it left off.

It resembles try/catch, dependency injection, middleware, and
callbacks at once — and it's a single idea underlying all four. If it confuses you the first
time around, that's fine. Chapter 12 returns to it with time
and several examples before asking you to write a handler of
your own.

What is worth keeping from this section: the type of `greet`
tells you it needs `Log`. The compiler will not let you call
it from a context where `Log` is not handled. Effects are
**visible in the type**, not hidden. This solves an old itch
of languages that have invisible exceptions.

## 1.5 Two cooperative fibers

The fifth program of the tour uses concurrency.

```kai
import spawn

fn worker(tag: String, n: Int) : Unit / Stdout + Spawn {
  if n > 0 {
    println(tag)
    spawn.yield()
    worker(tag, n - 1)
  }
}

fn main() {
  let f = spawn.spawn(() => worker("B", 3))
  worker("A", 3)
  spawn.await(f)
}
```

```
$ KAI_THREADS=1 kai run examples/ch01/05_concurrent.kai
A
B
A
B
A
B
```

A **fiber** is a unit of cooperative execution. It weighs
much less than an OS thread and lives inside the process.
`spawn.spawn` schedules a new fiber but does not run it
immediately; the scheduler picks it up at the next cooperation
point. `spawn.yield` is exactly that: a point where the
current fiber says "I can wait — give someone else a turn".

Without the `spawn.yield` calls, worker A would run all three
iterations before giving B a chance. With them, the output
ends up interleaved.

The `KAI_THREADS=1` in that command deserves a note. By
default kaikai spreads fibers across as many OS threads as
your machine has cores, and then the order of `A` and `B` is
the scheduler's call: it changes run to run. On a single
thread, `spawn.yield` is the only thing handing out turns, and
the alternation becomes visible. It's a teaching crutch for
this example, not how you'll run your programs; chapter 13
takes it apart properly.

The signature of `worker` is `: Unit / Stdout + Spawn`. Two
effects: the one we already knew for printing, and `Spawn` for
spawning and coordinating fibers. The `+` operator composes
effects: a function may carry several at once, declared in its
type.

`(() => worker("B", 3))` is a **lambda**: an anonymous
function with no arguments that calls `worker`. We pass it to
`spawn.spawn` so it runs inside the new fiber.

There is much to say about kaikai's concurrency model — why
fibers are isolated, how they cancel, what happens to memory —
but all of it lives in chapter 12. What matters for the tour is
that the language has structured concurrency as a first-class
feature, and it is treated, once again, as an effect.

## 1.6 Custom-fitted types with protocols

By now you've seen primitive types and sum types. One construct
is missing: **records**, which are what most languages call a
*struct* — a named-fields aggregate.

```kai
type Point = { x: Int, y: Int }
```

And with that comes the natural question: how do you "add
operations" to a type? For example, how do we tell the compiler
that my `Point` knows how to print itself as a string?

kaikai's answer is **protocols**: a named contract with a small
set of operations, that any type may satisfy. Conceptually it
matches Go interfaces, Rust traits, or Clojure / Elixir
protocols.

```kai
#[derive(Show)]
type Point = { x: Int, y: Int }

fn main() {
  let p = Point { x: 3, y: 4 }
  println(show(p))
}
```

```
$ kai run examples/ch01/07_protocols.kai
Point { x: 3, y: 4 }
```

`Show` is one of the stdlib protocols (`Eq`, `Ord`, `Hash`,
`Show`, `Serialize`). Its contract is a single op: given a
value, return a `String`. The line `#[derive(Show)]` above the
record tells the compiler to **synthesize** a `Show`
implementation for `Point`, walking the fields and delegating
to each one's `Show`. Since `Int` already implements `Show` in
the stdlib, the whole record is covered without writing
anything else.

A hand-written implementation would look like:

```kai
impl Show for Point {
  fn show(p: Point) : String =
    "(" ++ show(p.x) ++ ", " ++ show(p.y) ++ ")"
}
```

And `show(Point { x: 3, y: 4 })` would now return `"(3, 4)"`
instead of the record's default format.

The takeaway for the tour: **kaikai picks explicit
single-dispatch**, not Haskell-style typeclasses. No constraint
inference, no higher-kinded types, no chained ad-hoc
parametric polymorphism. One simple mechanism, like Go or
Clojure. Chapter 9 develops the idea.

## 1.7 Units of measure

kaikai ships an uncommon feature for *mainstream* languages:
**units of measure**. F# has had them since 2010 and almost no
other language offers them out of the box. The idea is to mark
a number with a unit (`Real<USD>`, `Real<m/s>`,
`Int<Seconds>`) and let the compiler reject incompatible
mixes.

```kai
unit USD
unit EUR

fn main() {
  let price : Real<USD> = 1.50<USD>
  let total : Real<USD> = price + 2.00<USD>
  println("total = #{total}")
}
```

```
$ kai run examples/ch01/08_units.kai
total = 3.5 USD
```

`unit USD` declares a unit. `1.50<USD>` is an annotated
literal. `Real<USD>` is the type of a real with that unit. And
if you try:

```kai
let mix = price + 1.00<EUR>     # error: USD ≠ EUR
```

the compiler complains before the program runs. This catches
an entire class of bugs that usually surface in production:
the classic Mars Climate Orbiter[^mco], adding balances in
different currencies, passing a timeout in milliseconds where
seconds were expected.

[^mco]: NASA's Mars Climate Orbiter spacecraft was lost in
    September 1999 as it entered the Martian atmosphere. The
    root cause: one software module computed thrust in
    pound-force per second (imperial units) while another
    read the same value as newtons per second (metric units).
    Nobody had labeled the units at the interface. The
    mission cost USD 327 million.

The best part of the scheme is that **units are erased at
compile time**. The binary `kai build` produces operates on
plain `Real`, no overhead. It's the same promise effects make:
the information lives in the type and costs nothing at runtime.

There is much more to say — generic units, unit algebra
(`m/s^2`, `kg * m / s^2`), explicit conversions, and a very
useful variant called *branded types* that tags strings and
integers with names like `UserId` or `OrderId` so the compiler
won't let you confuse them. All of that lives in chapter 10.
For now, knowing it exists is enough.

## 1.8 Programming by contract

kaikai carries another tool inherited from a short list of
languages (Eiffel in the eighties, Ada 2012, D) for stating what
a function expects from its caller and what it guarantees in
return: **preconditions** and **postconditions**.

```kai
fn divide(a: Int, b: Int) : Int
  requires b != 0
  ensures  result * b + (a % b) == a
= a / b

fn main() {
  println("10 / 2 = #{divide(10, 2)}")
  println("17 / 3 = #{divide(17, 3)}")
}
```

```
$ kai run examples/ch01/09_contracts.kai
10 / 2 = 5
17 / 3 = 5
```

`requires b != 0` says "this function demands that `b` not be
zero at the moment of the call". The compiler does two things
with that precondition. If it can **prove it at compile time**
(because the arguments are literals, or because it already knows
the possible ranges), it rejects the call before emitting code:
a literal `divide(10, 0)` is a compile error, not a runtime one.
If the arguments are dynamic and the compiler can't decide, it
inserts an assert checked **on entry**, and the program aborts
if the precondition fails.

`ensures result * b + (a % b) == a` says "this function
guarantees the fundamental identity of integer division holds on
the way out". `result` is a reserved name inside `ensures` that
refers to the return value. The postcondition is checked **on
exit**: if some internal bug made the function return something
that violated it, the program aborts there too.

Contracts are not comments. They are code the compiler emits as
real checks: static where it can manage, dynamic where it can't.
The day something violates a contract, you find out at the exact
spot.

How do they differ from the tests in the next section? A test
says "for this specific input, I expect this specific output". A
contract says "for **every** input satisfying this precondition,
the output satisfies this postcondition". One is a fixed case;
the other is a universal promise documented in the signature.

There is a sibling mechanism that extends the same idea to
**values** rather than operations: **refinement types**, which
let you declare types like `Int where >= 0` or
`Real where 0.0 <= self <= 1.0`. They are the structural
counterpart to contracts, with the type describing which values
are valid and the contract describing what operations do with
them. Both live together in chapter 11.

## 1.9 Inline tests

kaikai treats tests as part of the language proper: they live
in the same file as the code they exercise, with their own
syntax beside the functions.

```kai
fn square(n: Int) : Int = n * n

test "square of zero" {
  assert square(0) == 0
}

test "square preserves positives" {
  assert square(7) == 49
}

test "square of negatives" {
  assert square(-5) == 25
}
```

```
$ kai test examples/ch01/06_tests.kai
  ok   square of zero
  ok   square preserves positives
  ok   square of negatives

3/3 tests passed
```

`test "..." { ... }` is a top-level block. Inside, you use
`assert` to write assertions — if one fails, the test fails
and the runner moves on. In a normal build (`kai run`,
`kai build`), `test` blocks are ignored: they don't add weight
to the binary you ship.

There are two close relatives that share the same shape:

- **`check "..." with x: T { ... }`** declares a **property**
  the runner verifies with random inputs. This is what other
  languages call property-based testing.
- **`bench "..." { ... }`** is a benchmark: the runner runs
  the block many times and reports nanoseconds per iteration.

The three forms complement each other: `test` for fixed
cases, `check` for invariants that must hold over any input,
`bench` to measure performance instead of guessing. Chapter 7
treats each one in detail.

## 1.10 Holes: gaps that still compile

There is one last construct worth seeing in the tour, because it
shifts how you write code a little. kaikai lets you leave
**holes** where you don't yet know what belongs, and the program
compiles anyway.

```kai
fn circle_area(r: Real) : Real = ?formula

fn circle_perimeter(r: Real) : Real = ?

fn main() {
  println("compiled: the body is pending")
}
```

```
$ kai run examples/ch01/10_holes.kai
compiled: the body is pending
```

`?` and `?name` are **typed expressions**. The compiler accepts
the program, infers the expected type at each hole (at
`?formula`, it knows you owe it a `Real`), and leaves the rest of
the file compiling. If something calls `circle_area` at runtime
without the hole being filled, the program aborts with
`panic: unfilled hole`. Since `main` never calls it, the program
above finishes cleanly.

What is this good for? Three things:

- **Designing top-down.** You write the function's signature,
  leave the body as `?`, and compile. The compiler tells you
  what type belongs there and which values are in scope. You
  hold a conversation with the compiler before writing the body.
- **Making progress on a partial program.** You have ten
  functions left to write, but you want the program to compile
  so you can run the first one and see whether the idea holds.
  The other nine stay `?`; the code compiles; you try the first;
  the rest can wait.
- **Working with an AI agent.** You hand the agent a signature
  with holes and ask it to fill them. The compiler's
  documentation was designed so that information — expected
  type, bindings in scope, plausible candidates — can be emitted
  as structured JSON, ready to feed the agent.

The first two help the human programmer. The third is the
language's most strategic bet: kaikai wants to be a language an
LLM can write well in even when its training corpus holds little
kaikai, because the compiler does much of the work. Chapter 15
takes that bet apart at length.

## 1.11 Dependencies and projects: `kai.toml`

Every example in the tour so far has been a loose file. A real
project looks different: you will have several files, you will
depend on libraries other people published, and you will want a
colleague to clone the repo and get exactly the build you have.

kaikai handles this with a minimal manifest, **`kai.toml`**:

```toml
name = "my_app"
version = "0.1.0"

[dependencies]
manutara = "github.com/kaikailang-org/manutara@v0.1"
local    = { path = "../local-thing" }
```

Day to day it comes down to three commands:

```
$ kai init                                        # creates kai.toml in the current directory
$ kai add github.com/kaikailang-org/manutara@v0.1 # adds a dependency
$ kai run main.kai                                # compiles and runs
```

`kai add` clones the dependency's repository, caches it under
`~/.cache/kai/pkg/` addressed by SHA, and updates two files:
`kai.toml` (what you asked for) and **`kai.lock`** (which exact
version got resolved). The lockfile is what buys you
**reproducible builds**: when your colleague clones the repo and
runs `kai fetch`, they get bit-for-bit the same dependencies
you have.

Dependency resolution is **git-first**: a URL can name a tag
(`@v0.1`), a branch (`@main`), or a specific commit (`@abc123`).
No central registry, no TLS, no authentication. If the repo is on
GitHub, GitLab, or your own private git server, kaikai knows how
to go fetch it.

Chapter 8 covers this properly: how to organize a project into
modules, what goes in `[dependencies]`, how version selection
works when two dependencies want different things. For now it's
enough to know it exists, and that **you don't need an external
build system**: `kai` is the only binary.

## 1.12 Installing and running `kai`

To run any of the programs above you need the `kai` binary.
The short path is the installer:

```
$ curl -fsSL https://raw.githubusercontent.com/kaikailang-org/kaikai/main/install.sh | sh
```

It downloads the latest release, verifies its SHA-256, unpacks
it under `~/.kaikai/`, and adds `~/.kaikai/bin` to your shell's
`PATH`. If you'd rather use Homebrew,
`brew install kaikailang-org/kaikai/kaikai` lands in the same
place. The binary is self-contained — it carries its own LLVM,
no separate toolchain needed — though for now the prebuilt
releases cover macOS on Apple Silicon.

On other platforms you build from source, which lives at
[github.com/kaikailang-org/kaikai](https://github.com/kaikailang-org/kaikai)
and asks only for a C compiler:

```
$ make tier0
$ ./bin/kai run examples/minimal/hello.kai
```

`make tier0` builds the full bootstrap chain — stage 0 (written
in C), stage 1 (kaikai-minimal), and stage 2, the self-hosted
compiler you use day to day — and runs the fast test batteries
to confirm the build is healthy.

Once installed, the compiler updates itself:

```
$ kai upgrade
```

It queries the latest release and, if it is newer than the one
you have, downloads it, verifies it, and swaps it in place. If
you are already current, it says so and touches nothing.

From there, the three commands you'll use throughout the book
are:

```
$ kai run file.kai     # compile and run
$ kai build file.kai -o name   # produce a native binary
$ kai test file.kai    # run the `test "..." { ... }` blocks in the file
```

`kai run` is the workhorse while you read this book. Edit a
file, run it, look at the output, edit again.

Chapter 16 covers the rest of the tooling: `fmt`, `lsp`,
`watch`, editor integration. For now, `run` is enough.

## 1.13 How the rest of the book is laid out

We saw, without going deep, almost everything that makes
kaikai distinctive. The rest of the book takes each piece and
treats it seriously.

- **Part II — The Language** (chapters 3 to 11) covers basic
  types, compound types, sum types and `match`, functions,
  testing and benchmarking, modules, protocols, units of
  measure, and programming by contract. It is the solid,
  predictable half.
- **Part III — What Sets It Apart** (chapters 12 to 15) takes
  algebraic effects, fiber-based concurrency, actors, and the
  language's bet around LLMs. This is the half where kaikai
  earns its novelty.
- **Part IV — Practice** (chapters 16 to 19) covers the
  tooling, closes with two integrating case studies (an HTTP
  server and an accounting ledger), and finishes with the
  catalog of kinds, the most abstract chapter and the most
  skippable.
- Before all that, **chapter 2** softens a few assumptions if
  you come from an imperative world: expressions vs
  statements, immutability by default, `Option` instead of
  `null`, visible effects. It is short but useful.

If you come from Haskell, OCaml, Elixir, or Scala, you can
skip chapter 2 and even skim Part II; what is new for you
lives in Part III. If you come from Python, Go, Java,
JavaScript, or C#, read chapter 2 carefully and do the
exercises in Part II.

Either way: the example sources are in `examples/` in the
book repository. Compile everything. Run everything. The only
way to learn a language is to write it.
