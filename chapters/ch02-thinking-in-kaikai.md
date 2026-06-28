# Chapter 2 · Thinking in kaikai

Chapter 1 showed you the language from above. Before getting
into the detail of types, functions, and modules, it is worth
pausing on a handful of habits kaikai asks of you that you
probably did not bring with you from Python, Java, Go,
JavaScript, or C#.

This is the shortest chapter in the book, and you can skip it.
If you have already programmed in Haskell, OCaml, Elixir, or
Scala, what follows will sound familiar — head to Part II and
we'll meet you in chapter 3. If you come from an imperative
background, give it the twenty minutes it asks for. They will
save you a lot of friction across the next hundred and fifty
pages.

We are not going to open up the theory of each idea — that's
the job of the chapters that follow. What we want is to name
the habit change, show it, and give you the words to recognize
it when it shows up.

## 2.1 Expressions, not statements

In most of the languages you probably know, code is built from
two kinds of pieces:

- **Expressions**, which produce a value: `x + 1`, `f(2)`,
  `a == b`.
- **Statements**, which do not produce a value but execute
  something: a two-armed `if`, a `for`, a `return`, an
  assignment.

Statements have to be lined up in a sequence. Expressions do
not: they compose by nesting.

kaikai erases that boundary. **Almost everything is an
expression.** An `if` produces a value. A `match` produces a
value. A block `{ ... }` produces a value — the value of its
last expression. A function does not need a `return` because
its body *is* the expression that gets returned.

Compare two ways of writing the same thing. The classic
imperative form:

```
String s;
if (x > 0) {
  s = "positive";
} else {
  s = "non-positive";
}
print(s);
```

In kaikai:

```kai
let s = if x > 0 { "positive" } else { "non-positive" }
println(s)
```

The difference isn't in line count but in how you think about
the code. The imperative version forces you to **declare `s`
first**, because the `if` cannot return anything; then it
**assigns to `s` in each branch**. In kaikai, the `if` *is* the
value, and `s` binds directly to the result. Declaration and
assignment merge. There is no assignment at all: `s` is bound
once and never changes.

The practical consequences show up quickly:

- **Fewer lines, no loss of clarity.** Three steps (declare,
  decide, assign) collapse into one.
- **Fewer temporaries.** If you only need a value to pass into
  the next call, you build it inline.
- **Fewer "forgot to initialize" bugs.** No
  declared-but-uninitialized variables.
- **Smoother refactoring.** An expression can be lifted into a
  function or replaced by another expression without disturbing
  the surrounding context; a statement, less so.

You see the same with `match`. In most languages with a
`switch`, each `case` is a statement that runs a block and then
either breaks or falls through, depending on the rules. In
kaikai, `match` is an expression that returns a value, and each
arm is the expression that value might be. You saw this in
chapter 1, in `label` and in `eval`. You will see it
constantly.

A related point: the body of a function can take two shapes,
and the choice between them communicates intent.

```kai
fn double(x: Int) : Int = x * 2

fn classify(x: Int) : String {
  if x < 0 { "negative" }
  else if x == 0 { "zero" }
  else { "positive" }
}
```

Use `=` and a single expression when the function is direct.
Use `{ ... }` when there are several steps or visual separation
helps. The compiler accepts both; the difference is for the
reader.

A useful consequence of treating everything as an expression is
that **chained transformations** become comfortable. From the
Elixir world, kaikai borrows the pipe operator `|>`:

```kai
xs |> filter(is_even) |> map(double) |> list.length
```

is equivalent to `list.length(map(filter(xs, is_even),
double))`. The piped form reads left-to-right, in the order the
transformations happen, and avoids intermediate names. It is
only possible because each step is an expression that can be
composed with the next.

`|>` is the most general of three pipe operators kaikai
provides for chaining. The other two — `|` (map over lists) and
`||` (flat-map) — are shortcuts for the cases that appear over
and over. Chapter 6 covers the three in detail.

## 2.2 Immutability by default

`let x = 5` binds `x` to the value `5`. That's it. You cannot
write `x = 6` later. If your code seems to need to "change `x`",
in kaikai that means one of two things:

- You actually need a *new* value derived from the first. The
  right move is to bind another name, or to redefine `x` in a
  nested scope.
- You actually need *visible* mutation. That's a real but small
  case, and kaikai gives it to you, but it asks you to declare
  it. Mutation of an array, for example, lives under the
  `Mutable` effect, which appears in the signature of any
  function that uses it. We'll cover this calmly in chapter 12.

Why take this path? Because most of the time, "changing a
variable" is a habit inherited from the imperative model, not
a real need. When you program with values that don't change:

- **Reasoning becomes local.** If `x` was bound to `5` on line
  12, it is still `5` on line 30. Period. No need to hunt for
  who modified it in between.
- **Concurrency becomes simpler.** Two fibers can read the same
  value without synchronization; nobody is going to overwrite
  it.
- **Bugs go away.** A whole category of errors ("I expected X,
  but at the end of the method it was Y") just doesn't exist.
- **Tests are simpler.** A pure function — input, output, no
  hidden state — is tested by giving it inputs and comparing
  outputs. That's all.

A note on vocabulary. The usual way to bind a name is `let`,
which is immutable. For the cases where you really need a
local mutable cell — a counter, an accumulator, a cursor —
kaikai gives you `var`. `:=` is the single mark of mutability:
it declares the cell, writes it, and a bare name reads it.

```kai
var n := 0
n := n + 1
println(int_to_string(n))   # 1
```

What's worth noticing: `var` is not really a new
construct in the language. It is **syntactic sugar** over the
`State` effect. The line `var n := 0` rewrites to a
`handle ... with State[Int](0) as n { ... }` covering the rest
of the block. Reading `n` rewrites to `n.get()`, and `n := v` to
`n.set(v)`. The base language is the same algebraic-effects
machinery from chapter 12; what changes is the face it shows
for common cases.

What matters for your mental model is that this rewrite happens
**inside the block**: the `handle` opens and closes right
there, so the `State` effect does not leak into the function's
signature. A function with a `var` inside has the same
signature it would have without it.

More visible mutations — writing to an array that lives beyond
the block, sending to another actor's mailbox, modifying memory
observed from outside — *do* show up in the signature, under
effects like `Mutable`, `Actor`, or whichever fits. We'll see
that distinction in chapter 12.

The practical rule is simple: use `let` by default; if you
need a local variable that changes, `var` with `:=`;
if what you want to mutate is something visible from outside,
you are in effects territory and you'll have to declare them.

## 2.3 `Option` and `Result` instead of `null` and exceptions

The oldest question in language design: what does a function do
when it cannot return what it promised?

The C, Java, Python, JavaScript answer (and many others) is to
**lie**: the function says it returns a `User`, but in some
cases it returns a magic value called `null` (or `None`, or
`nil`) which **is not a user**, and which the type system does
not distinguish from a real one. The caller has to remember to
check. Tony Hoare, who invented the null reference back in
1965, called that decision his "billion-dollar mistake".

The other traditional answer is to throw an exception. The
function does not return anything and, without telling the type
system, it diverts control to some distant `catch`. Which
`catch`? Depends. Sometimes there isn't one and the program
dies.

kaikai picks a third path, old in the ML family but still
uncommon outside of it: **encode the possibility of failure in
the return type**.

```kai
type Option[a] = None | Some(a)
type Result[e, a] = Err(e) | Ok(a)
```

A function that may not find its result returns
`Option[User]`: either `Some(usr)` when found, or `None`
otherwise. A function that may fail in several ways returns
`Result[Error, User]`: either `Ok(usr)`, or `Err(reason)`. In
both cases, the type forces you to consider both
possibilities.

Compare:

```python
# Python: the caller has to remember
def find(id: int) -> User:
    ...   # sometimes returns None, sometimes not, check the docs

usr = find(7)
print(usr.name)   # crash if usr is None
```

```kai
# kaikai: the type says so
fn find(id: Int) : Option[User] = ...

let r = find(7)
match r {
  Some(usr) -> println(usr.name)
  None      -> println("not found")
}
```

In the kaikai version, `match` is exhaustive: if you forget the
`None` branch, it does not compile. The compiler reminds you
of what Python leaves to your memory.

What about exceptions? kaikai has an equivalent mechanism — the
`Fail` effect, and more generally the algebraic effects from
chapter 12 — but there too, what can fail appears in the type.
The "invisible exceptions" that in Java or Python can spring
out of any call do not exist in kaikai. If a function can jump
elsewhere, its signature says so.

This changes how programming feels. Instead of wrapping every
external call in a `try` just in case, you read the signature,
see what can fail, and decide right there what to do.

### A note on `!`

In kaikai, the postfix `!` operator applies to an `Option` or
a `Result` and propagates the negative case: if the value is
`Ok(v)` or `Some(v)`, the expression evaluates to `v` and the
program continues; if it is `Err(e)` or `None`, the current
function returns right there with that `Err` or `None`,
handing it to the caller.

```kai
fn load() : Result[Error, User] {
  let id = parse_id(input)!        # if it fails, propagate
  let data = read_file(id)!        # likewise
  Ok(build_user(id, data))
}
```

This is the same as Rust's `?`. And it is worth saying what it
**isn't**: in Elixir, naming a function `File.read!` is a
convention for the version that *raises* an exception instead
of returning an `{:ok, _} | {:error, _}` tuple. In kaikai the
convention is the opposite: `!` is not part of a name, it is an
operator, and it **never raises**. It only unpacks the happy
case and propagates the negative one through the return type.
If you have seen plenty of `File.read!` in Elixir code and it
made you nervous, you can relax: in kaikai that same syntax is
on the safe side.

## 2.4 Pattern matching as a control-flow tool

In an imperative language, deciding what to do based on the
shape of a value usually takes three steps:

1. **Check the shape** with `if`, `instanceof`, `is`,
   `typeof`, or a discriminator field.
2. **Get at the data** carried by that shape, with casts, `as`,
   or named accesses that assume step 1 worked.
3. **Do something** with that data.

kaikai folds the three into a single construct: `match`.

```kai
match expr {
  Lit(n)    -> n
  Add(l, r) -> eval(l) + eval(r)
  Mul(l, r) -> eval(l) * eval(r)
  Neg(x)    -> -eval(x)
}
```

Each arm is a **pattern** followed by the expression that
pattern produces. `Lit(n)` doesn't only say "this was built
with `Lit`"; it also declares that `n` is the `Int` carried
inside, ready to use on the right-hand side. Check, unpack,
bind — in one move.

Patterns nest. If you have an `Option[Result[Error, Int]]` and
you want to distinguish the three possible shapes, you write:

```kai
match x {
  None              -> "not present"
  Some(Err(reason)) -> "failed: " ++ reason
  Some(Ok(value))   -> "ok: " ++ int_to_string(value)
}
```

Patterns can also carry **guards** — extra conditions evaluated
after the structural match — and wildcards (`_`) when you don't
care about the value.

The crucial part: the compiler checks **exhaustiveness**. If
`Tag` has four constructors and your `match` covers three, it
does not compile. If you add a fifth constructor to a type and
there are thirty `match` sites in the codebase, those thirty
sites become compile errors that tell you exactly where to come
back. This turns a feared refactor into a tedious but safe one.

Without pattern matching, languages handle this case with
visitor patterns, class hierarchies, or chains of `if /
else if / else`. Each works, but all of them lose the link
`match` keeps between the type of the value and the way you
decide on it.

After a few weeks with kaikai, `match` becomes one of those
tools you don't want to give up.

## 2.5 Pure functions and visible effects

The four ideas above converge on a bigger one, which is the
language's central bet: **separate the pure from what touches
the world**, and have the type system police that distinction.

A *pure* function is a function whose result depends only on
its arguments. Calling it with the same arguments always
returns the same value. It does not print. It does not read
from disk. It does not send messages. It does not look at a
clock. It does not roll a die.

Pure functions are easy to test, easy to reason about, easy to
parallelize, easy to cache. The catch is that a program made
only of pure functions does nothing useful: it never talks to
the world.

kaikai puts effects in the type system. You saw this in chapter
1: a function that writes to stdout says `: Unit / Stdout` in
its signature. A function that uses `Log` says
`: ... / Log`. A function that may fail and bail out says
`: ... / Fail`. And a pure function, one that does not touch
the world, says nothing after the `/`. Its signature is just
`fn f(x: Int) : Int`.

The effect on the right-hand side of `/` is not decoration. It
is a constraint: the compiler will not let you call an effectful
function from a context where those effects are not being
handled. Some handler up the stack has to take ownership.
This solves, all at once and at the language level, several
old itches:

- The **invisible exceptions** that Java and Python permit
  because no signature declares them.
- The **cancellation handling** that in `async`/`await`
  languages becomes a thread of plumbing inside the business
  logic, rather than a separate mechanism.
- The **dependency injection** that in OO languages requires
  whole containers to do what an effect handler does in five
  lines.
- **Logging**, **config access**, **the clock**, **the
  database**: every dependency that traditionally sneaks in
  hidden can be an effect, declared in the type, and chosen by
  the caller.

If you've never seen this before, it sounds too ambitious to be
true. It is and it isn't. Chapter 11 gives it the space it
deserves. For now, it is enough to know that the signatures you
see with `/ something` are not noise: they are information
about what that function can do to your program.

## 2.6 A short genealogy

kaikai did not appear from nowhere. It inherits decisions from
several language families, and it helps to know which ones to
understand why things look the way they do.

- **From ML (1973), OCaml, and Haskell** come algebraic data
  types, pattern matching, Hindley-Milner type inference, and
  `Option`/`Result`. Old, good ideas that "modern" languages
  like Rust and Swift now rediscover without always
  acknowledging their grandparents.
- **From Erlang (1986) and Elixir** come isolated processes
  with private memory, the idea that concurrency is built on
  passing messages rather than sharing memory, and the
  supervision model with `link` and `monitor`. In kaikai those
  processes are called fibers and actors.
- **From Elixir** also comes the pipe operator `|>` we saw
  earlier.
- **From Koka (Daan Leijen, Microsoft Research)** and
  **Effekt (Andreas Rossberg, Jonathan Brachthäuser)** come
  algebraic effects with effect rows in the type system.
  kaikai follows Effekt closely on how handlers are
  expressed, and Koka on some internal decisions.
- **From Koka** also comes **Perceus**, the
  compile-time-optimized reference counting scheme kaikai uses
  to manage memory without a garbage collector or a borrow
  checker.
- **From Go** kaikai takes the decision to ship a single
  binary as compiler, formatter, and test runner; the primacy
  of programs that build and run fast; and the discipline of
  keeping few forms in the language.
- **From Rust**, kaikai learns what *not* to do: sum types and
  pattern matching are lessons Rust teaches well. The borrow
  checker, on the other hand, kaikai prefers to avoid —
  Perceus plus isolated fibers solve the problem without
  asking the programmer to internalize lifetimes.

None of these decisions is new. What kaikai attempts is a
coherent combination: algebraic types + algebraic effects +
Perceus + BEAM-style fibers, in a language that compiles fast
to native code and that an experienced programmer can read
without taking a course first.

The rest of the book digs into each of those decisions. If you
made it this far, you have the map.

## Exercises

**2.1.** Go back to `02_fizzbuzz.kai` from chapter 1. Identify
all the **expressions** that return a value. How many are
there? Are there any strict **statements** — something that
runs for its side effect without producing anything useful —
beyond the calls to `println`?

**2.2.** In your day-to-day language, write a short version of
the following: a function `classify_age(n)` that returns the
string `"child"`, `"young"`, `"adult"`, or `"senior"` based on
ranges. How many local variables did you use? How many
assignments? Now rewrite it in pseudo-kaikai (it doesn't have
to compile) using `if` as an expression.

**2.3.** Find a function in your work codebase that returns
`null` or throws an exception to signal "no result". Write down
in a comment what its signature would be in kaikai using
`Option` or `Result`. What do you gain? What do you lose?
