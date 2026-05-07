# Chapter 1 · A Tour of kaikai

The best way to get to know a language is to read it and run it.
This chapter is a guided tour of kaikai in five short programs.
None of them runs longer than thirty lines, every one of them
compiles, and together they cover the shapes you will see again
and again in the rest of the book: declarations, algebraic data
types, pattern matching, effects, fibers.

We will not explain every detail yet. The point is to leave you
with a view of the language from above, and the sense that you
can already read kaikai code even when some of the corners are
still blurry. The corners come into focus in the chapters that
follow.

If you want to follow along on your own machine, the source
files for this chapter live under `ejemplos/cap01/` in the book
repository. Installation of `kai` is covered at the end of the
chapter, in §1.6 — if you need it now, jump there first and come
back.

## 1.1 Hello, kaikai

The oldest exercise in the book, in kaikai:

```kai
fn main() {
  println("Hello, kaikai")
}
```

```
$ kai run ejemplos/en/cap01/01_hello.kai
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
tries not to make you write the obvious.

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

`loop` is recursive. There is no `while`, no `for`. Well —
there are conveniences for iteration in chapter 6, but the base
is recursion. So that base does not cost your program anything,
the language guarantees **mandatory tail-call optimisation**: a
recursive call in tail position does not consume stack.
`loop(1, 1_000_000)` works without blowing up.

One thing that will look strange and that we leave for chapter
9: the signature of `loop` says `: Unit / Stdout`. The part
after the slash is the set of **effects** the function uses.
`Stdout` means "this function writes to the terminal". Without
it, the compiler would not let you call `println` inside. Don't
worry about the details yet — the full story is in chapter 9.

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
$ kai run ejemplos/en/cap01/03_calculator.kai
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
kaikai lets you, but it asks you to declare it (chapter 10).
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
$ kai run ejemplos/en/cap01/04_effect.kai
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
  saying *how* the effect is realised. `greet` is agnostic: it
  doesn't know whether messages go to the terminal, to a file,
  or nowhere at all.
- The decision happens at `handle ... with Log { ... }`. There,
  inside `main`, we say: "for this block, when someone invokes
  `Log.log(msg)`, run this code". The handler prints the
  message with an `[INFO]` prefix and hands control back via
  `resume(())`, which continues the program where it left off.

This looks like try/catch, like a dependency-injection
container, like middleware, like callbacks. But **it is one
idea** that subsumes all four. If it confuses you the first
time around, that's fine. Chapter 9 returns to it with time
and several examples before asking you to write a handler of
your own.

What is worth keeping from this section: the type of `greet`
tells you it needs `Log`. The compiler will not let you call
it from a context where `Log` is not handled. Effects are
**visible in the type**, not hidden. This solves an old itch
of languages that have invisible exceptions.

## 1.5 Two cooperative fibers

The last program of the tour uses concurrency.

```kai
import spawn

fn worker(tag: String, n: Int) : Unit / Stdout + Spawn {
  if n > 0 {
    println(tag)
    fiber_yield()
    worker(tag, n - 1)
  }
}

fn main() {
  let f = fiber_spawn(() => worker("B", 3))
  worker("A", 3)
  fiber_await(f)
}
```

```
$ kai run ejemplos/en/cap01/05_concurrent.kai
A
B
A
B
A
B
```

A **fiber** is a unit of cooperative execution. It weighs
much less than an OS thread and lives inside the process.
`fiber_spawn` schedules a new fiber but does not run it
immediately; the scheduler picks it up at the next cooperation
point. `fiber_yield` is exactly that: a point where the
current fiber says "I can wait — give someone else a turn".

Without the `fiber_yield` calls, worker A would run all three
iterations before giving B a chance. With them, the output
ends up interleaved.

The signature of `worker` is `: Unit / Stdout + Spawn`. Two
effects: the one we already knew for printing, and `Spawn` for
spawning and coordinating fibers. The `+` operator composes
effects: a function may carry several at once, declared in its
type.

`(() => worker("B", 3))` is a **lambda**: an anonymous
function with no arguments that calls `worker`. We pass it to
`fiber_spawn` so it runs inside the new fiber.

There is much to say about kaikai's concurrency model — why
fibers are isolated, how they cancel, what happens to memory —
but all of it lives in chapter 10. What matters for the tour is
that the language has structured concurrency as a first-class
feature, and it is treated, once again, as an effect.

## 1.6 Installing and running `kai`

To run any of the programs above you need the `kai` binary.
The project lives at
[github.com/lnds/kaikai](https://github.com/lnds/kaikai).

From a fresh checkout, all you need is a C compiler:

```
$ make all
$ make test
```

`make all` builds stage 0 (written in C), stage 1 (written in
kaikai-minimal and compiled by stage 0), and the `kai` binary
in the repo root. `make test` runs the stage 0, stage 1, and
phase 4 test suites to confirm the build is healthy.

From there, the three commands you'll use throughout the book
are:

```
$ kai run file.kai     # compile and run
$ kai build file.kai -o name   # produce a native binary
$ kai test file.kai    # run the `test "..." { ... }` blocks in the file
```

`kai run` is the workhorse while you read this book. Edit a
file, run it, look at the output, edit again.

Chapter 13 covers the rest of the tooling — `fmt`, `repl`,
`lsp`, editor integration. For now, `run` is enough.

## 1.7 How the rest of the book is laid out

We saw, without going deep, almost everything that makes
kaikai distinctive. The rest of the book takes each piece and
treats it seriously.

- **Part II — The Language** (chapters 3 to 8) covers basic
  types, compound types, sum types and `match`, functions,
  modules, and protocols. It is the solid, predictable half.
- **Part III — What Sets It Apart** (chapters 9 to 12) takes
  algebraic effects, fiber-based concurrency, actors, and the
  language's bet around LLMs. This is the half where kaikai
  earns its novelty.
- **Part IV — Practice** (chapters 13 and 14) covers the
  tooling and closes with an integrating case study.
- Before all that, **chapter 2** softens a few assumptions if
  you come from an imperative world: expressions vs
  statements, immutability by default, `Option` instead of
  `null`, visible effects. It is short but useful.

If you come from Haskell, OCaml, Elixir, or Scala, you can
skip chapter 2 and even skim Part II; what is new for you
lives in Part III. If you come from Python, Go, Java,
JavaScript, or C#, read chapter 2 carefully and do the
exercises in Part II.

Either way: the example sources are in `ejemplos/` in the
book repository. Compile everything. Run everything. The only
way to learn a language is to write it.
