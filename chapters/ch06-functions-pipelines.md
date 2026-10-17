# Chapter 6 · Functions and pipelines

So far you've been seeing functions as you needed them: the
first ones in the tour, those of chapter 3 with their two
body forms, the recursive ones of chapter 5 that decompose
sum types. This chapter puts everything together and adds
what was missing: how to declare functions carefully, how to
write lambdas, what higher-order functions are, and the four
pipe operators kaikai uses to chain transformations.

Of everything I decided, the four pipes are what I argued with
myself about the longest: four operators is a lot for a language
that prides itself on having few forms. I kept them in the end,
and §6.4 explains why.

We will also look in detail at something kaikai promises and
very few languages guarantee seriously: **tail-call
elimination**. That guarantee is what lets you replace `for`
and `while` with recursion without fear of overflowing the stack.

## 6.1 Declaration

A function is declared with `fn`, typed parameters, return
type, and a body separated by `=`:

```kai
fn double(x: Int) : Int = x * 2
```

The body can take **three forms**. The first is a single
expression, like the one above.

The second is a block `{ ... }` with intermediate `let`s and
the implicit final expression:

```kai
fn square_plus_one(x: Int) : Int {
  let square = x * x
  square + 1
}
```

The third is **arms with patterns**, where the function
decides what to do based on the shape of its arguments. Each
arm starts with `case`, followed by a pattern, an arrow `->`,
and the expression that case produces:

```kai
fn sign(n: Int) : String {
  case 0            -> "zero"
  case k when k > 0 -> "positive"
  case _            -> "negative"
}
```

This is exactly equivalent to:

```kai
fn sign(n: Int) : String =
  match n {
    0          -> "zero"
    k if k > 0 -> "positive"
    _          -> "negative"
  }
```

just without the `match` wrapper. When the function has
**multiple parameters**, the patterns are listed
comma-separated, one per argument:

```kai
fn divide(a: Real, b: Real) : Result[Real, Error] {
  case _, 0.0 -> Err(DivByZero)
  case a, b   -> Ok(a / b)
}
```

A language rule: inside a function's `{ ... }` block, **either
all arms are `case` arms or all are statements**. Mixing is a
parse error. If you need setup before discriminating, wrap a
`match` in the short form or extract a helper.

The practical rule for choosing among the three:

- **Short body with `=`** when the function is a direct
  expression, no intermediate steps.
- **Block with `{ ... }`** when there are intermediate `let`s
  or several visually-separated steps.
- **Multi-clause with `case`** when the function dispatches
  primarily on the shape of its arguments. The natural form
  for many recursive functions and for dispatchers over sum
  types.

Three notes worth pinning down:

- **Parameter annotations: mandatory.** kaikai infers types
  on local bindings (`let x = 5`), but not on function
  signatures. Each parameter must say its type.
- **Return type: required on public functions, recommended
  always.** The compiler can infer it on local functions, but
  the signature documents the contract and makes type errors
  reported at the right place. Annotate.
- **Functions with effects: the effect goes after `/`.** A
  function that writes to stdout is `: Unit / Stdout`, and
  chapter 12 covers it carefully. For now, just know that if
  your function calls `println`, its signature says so.

`main` is the only function where the return type is
optional. If you omit it, kaikai assumes `Unit`.

Both bodies and one effectful function, in a program:

```kai
# examples/ch06/01_functions.kai
# Short body: a single expression after `=`.
fn double(x: Int) : Int = x * 2

# Long body: a block with `let`s and a final expression.
fn square_plus_one(x: Int) : Int {
  let square = x * x
  square + 1
}

# Pure function with no useful return value: serves an effect.
# Although `Unit` is optional in `main`, in helper functions it
# pays to annotate when there are effects involved.
fn announce(message: String) : Unit / Stdout =
  println("[ANNOUNCE] " ++ message)

fn main() {
  println("double(7)         = #{double(7)}")
  println("square_plus_one(3) = #{square_plus_one(3)}")
  announce("ready")
}
```

```
$ kai run examples/ch06/01_functions.kai
double(7)         = 14
square_plus_one(3) = 10
[ANNOUNCE] ready
```

## 6.2 Lambdas

A **lambda** is an anonymous function, an expression that
evaluates to a function value. kaikai gives you three forms
to write them:

```kai
# Form 1 — single-argument arrow
let square = (x) => x * x

# Form 2 — multi-argument arrow
let sum = (a, b) => a + b

# Form 3 — placeholder, implicit unary lambda
xs |> list.filter(. > 0)
```

The first two are interchangeable; choice is style. The third
is **sugar** that only applies when the context **expects a
function** — the second argument of `list.filter`, for
example, is `(Int) -> Bool`, and the compiler converts `. > 0`
into `(n) => n > 0`.

The placeholder rules:

- `.` only works where a function is expected. Outside that,
  it's a compile error.
- Unary functions only. For two or more arguments, explicit
  arrow.
- Multiple `.` occurrences in the same expression refer to
  the **same value**. For example, `xs |> list.map(. * .)`
  squares.

When to use which? My suggestion:

- **Placeholder** when the lambda is trivial and inside a
  pipe. `xs |> list.filter(. > 0)` reads at a glance.
- **Arrow** when the lambda has several steps or when the
  argument appears in non-obvious places.
- **Named function** when the lambda is used more than once,
  or when the name documents the intent.

### Point-free sections: projecting without naming the parameter

There is a case even more common than the placeholder: the
lambda that does nothing but **reach into the element** to pull
out a field or call a method. `(p) => p.name`, `(s) =>
s.length()`. No computation, no operator, just a projection.
For that kaikai has an even shorter form, the **point-free
section**: a leading `.` followed by the field, the field path,
or the method call.

```kai
type Addr = { city: String }
type Person = { name: String, age: Int, addr: Addr }

let people = [Person { name: "ana", age: 30, addr: Addr { city: "Hanga Roa" } }]
let names  = people | .name           # (p) => p.name
let cities = people | .addr.city       # (p) => p.addr.city
let lengths = names | .length()        # (s) => s.length()
```

The section reads as the projection itself, with no parameter
name to invent. The receiver is supplied implicitly (the first
argument by UFCS), so `.starts_with("a")` reads its written
argument *after* the receiver. It works as the function of `|`,
`||`, `|?`, `|!` and as a combinator argument (`.map`,
`.and_then`,
`.filter`):

```kai
let starts = names |? .starts_with("a")  # (s) => s.starts_with("a")
let n      = Some("hi").map(.length())   # in argument position
```

Inside a pipe stage the projection does not have to stand alone.
On the right of `|`, `||`, `|?` or `|!`, the `.` **is** that
stage's
element, and every `.` in the stage is the same element, so you
can keep operating on what you project:

```kai
let adults = people |? .age > 18         # (p) => p.age > 18
let tens   = [1, 2, 3] | . * 10          # (n) => n * 10
let capped = [1, 2, 3] | max(., 2)       # (n) => max(n, 2)
```

Note the last one: a `.` inside a call argument refers to the
stage's element, not to the argument. `xs | f(g(.))` means
`xs | (x) => f(g(x))`.

The explicit arrow cuts that scope off: write it and the `.`
inside belongs to whatever stage sits within it. Two nested
stages that both use `.` do not compile, and the error asks you
to name one of the two elements with `(x) => ...`.

The practical rule: if the stage reads at a glance, leave it
point-free; if it takes several steps, or the element shows up in
non-obvious places, give it a name with the arrow.

Lambdas are **first-class values**: you bind them with `let`,
pass them as arguments, return them from functions, store
them in records. That's what makes higher-order functions
natural.

All three forms, plus a lambda bound with `let` and passed as
an argument:

```kai
# examples/ch06/02_lambdas.kai
fn call_with(f: (Int) -> Int, x: Int) : Int = f(x)

fn main() {
  # Form 1 — single-argument arrow.
  let square = x => x * x
  println("square(7)    = #{square(7)}")

  # Form 2 — multi-argument arrow.
  let sum = (a, b) => a + b
  println("sum(3, 4)    = #{sum(3, 4)}")

  # Form 3 — placeholder, implicit unary lambda.
  # Only valid where a function is expected.
  let xs = [1, 2, 3, 4, 5]
  let doubles = xs |> list.map(n => n * 2)
  println("sum of doubles = #{list.sum(doubles)}")

  # Lambdas are first-class values: pass them as arguments,
  # bind to `let`, return them from functions.
  println("call_with(square, 5) = #{call_with(square, 5)}")
}
```

```
$ kai run examples/ch06/02_lambdas.kai
square(7)    = 49
sum(3, 4)    = 7
sum of doubles = 30
call_with(square, 5) = 25
```

## 6.3 Higher-order functions

A **higher-order function** is one that takes or returns
another function. That's the whole definition. What's
interesting isn't the name: it's what it lets you do.

The simplest case is a function that applies another twice:

```kai
fn twice[a](f: (a) -> a, x: a) : a = f(f(x))
```

`f` is the first parameter, of type `(a) -> a` — any function
from `a` to `a`. `twice(plus_one, 5)` computes
`plus_one(plus_one(5))` = `7`. The function is **generic**
over `a`: it works with `Int`, `String`, any type as long as
`f` has the same input type as output. The annotation `[a]`
after the name declares the type parameter.

A more interesting case is a function that **returns**
another — a *closure*:

```kai
fn add_n(n: Int) : (Int) -> Int = (x) => x + n
```

`add_n(10)` returns a new function that adds 10 to its
argument. The trick is that the lambda **captures** `n` from
the context where it was created. Once returned, that
function has a copy of `n` inside:

```kai
let plus_ten = add_n(10)
plus_ten(7)        # 17
plus_ten(100)      # 110
```

And the classic composition:

```kai
fn compose[a, b, c](f: (b) -> c, g: (a) -> b) : (a) -> c =
  (x) => f(g(x))
```

`compose(f, g)` is the function that first applies `g`, then
`f`. Three type parameters (`a`, `b`, `c`) because chained
functions touch three distinct types in general.

Higher-order functions are the main tool to abstract **over
the what-to-do**. Instead of writing `for each element, do X`
and `for each element, do Y`, you write `for each element, do
F`, where `F` is a parameter. That's how `list.map`,
`list.filter`, `list.foldl` are born — the staples of functional
list processing.

A function that takes another, one that returns a new one, and
the composition of the two:

```kai
# examples/ch06/03_higher_order.kai
# Takes a function as argument.
fn twice[a](f: (a) -> a, x: a) : a = f(f(x))

# Returns a new function (closure that captures `n`).
fn add_n(n: Int) : (Int) -> Int = x => x + n

# Function composition is a higher-order function.
fn compose[a, b, c](f: (b) -> c, g: (a) -> b) : (a) -> c = x => f(g(x))

fn main() {
  let plus_one = x => x + 1
  println("twice(+1, 5)        = #{twice(plus_one, 5)}")

  let plus_ten = add_n(10)
  println("plus_ten(7)         = #{plus_ten(7)}")

  let square = x => x * x
  let comp = compose(square, plus_one)
  println("(square . +1)(4)    = #{comp(4)}")
}
```

```
$ kai run examples/ch06/03_higher_order.kai
twice(+1, 5)        = 7
plus_ten(7)         = 17
(square . +1)(4)    = 25
```

## 6.4 Pipes: `|>`, `|`, `||`, `|?`, `|!`

kaikai has four pipe operators. All four are distinct and
each communicates a specific intent.

### `|>` — apply

`xs |> f` is exactly `f(xs)`. The operator takes the
left-hand side and puts it as the **first argument** of the
right-hand call. If `f` has more arguments, they go in the
parens:

```kai
xs |> list.sum                   # ≡ list.sum(xs)
xs |> list.filter(is_even)       # ≡ list.filter(xs, is_even)
xs |> list.map((n) => n * 2)     # ≡ list.map(xs, (n) => n * 2)
```

But there's a useful detail: sometimes the piped value
**doesn't want** to go as the first argument. For example, a
division function where what you're piping is the divisor,
not the dividend. kaikai lets you indicate the exact position
with an underscore `_`:

```kai
fn divide(a: Int, b: Int) : Int = a / b

100 |> divide(_, 4)        # ≡ divide(100, 4) = 25
100 |> divide(1000, _)     # ≡ divide(1000, 100) = 10
```

The `_` is the **slot** where the LHS lands. Without `_`, the
LHS goes to the first argument — the short form of `f(_, a,
b)`. With `_`, wherever you put it. This lets you write
natural pipelines even when stdlib functions weren't designed
with the "main argument" in first position.

The three positions in a program, with the short form and the
explicit one giving the same result:

```kai
# examples/ch06/07_pipe_underscore.kai
fn divide(a: Int, b: Int) : Int = a / b

fn between(low: Int, x: Int, high: Int) : Bool =
  x >= low and x <= high

fn main() {
  # Without _: value goes to the first argument.
  let r1 = 100 |> divide(4)  # ≡ divide(100, 4) = 25
  println("100 / 4    = #{r1}")

  # With _ at position 1: explicit, same effect.
  let r2 = 100 |> divide(_, 4)
  println("100 / 4    = #{r2}")

  # With _ at position 2: value goes as the divisor.
  let r3 = 100 |> divide(1000, _)
  println("1000 / 100 = #{r3}")

  # With _ at an intermediate position.
  let r4 = 50 |> between(0, _, 100)
  println("between 0 and 100: #{r4}")
}
```

```
$ kai run examples/ch06/07_pipe_underscore.kai
100 / 4    = 25
100 / 4    = 25
1000 / 100 = 10
between 0 and 100: true
```

### `|` — map

`xs | f` is exactly `list.map(xs, f)`. A specific operator
for mapping over lists:

```kai
let doubles = xs | (n) => n * 2     # ≡ list.map(xs, (n) => n * 2)
```

Why have `|` if `|>` already covers the case? Because
`xs | f` reads as "xs processed with f", which is exactly
what a map is. The shorter form makes list-transformation
pipelines read like declarative sequences.

### `||` — flat-map

`xs || f` desugars directly to `list.flat_map(xs, f)`, just
like `|` desugars to `list.map(xs, f)`. The three following
forms are equivalent:

```kai
let extended = [10, 20, 30] || neighbors                    # sugar
let extended = list.flat_map([10, 20, 30], neighbors)       # direct call
let extended = [10, 20, 30] | neighbors |> list.concat      # map + concat
```

The first reads "expand each element". The second is the
named operation. The third shows how flat-map is defined: map
and concat. Use `||` to make the operation evident in a
pipeline; use the direct call when you're not in a pipeline.

### `|?` — filter

`xs |? p` is exactly `list.filter(xs, p)`. Filters the list
keeping the elements where the predicate is true:

```kai
fn is_even(n: Int) : Bool = n % 2 == 0

[1, 2, 3, 4, 5, 6] |? is_even      # = [2, 4, 6]
```

The predicate is any expression the context admits as `(a) ->
Bool`: a function name, an arrow, a block lambda:

```kai
xs |? is_even                       # name
xs |? (n) => n > 3                  # arrow
xs |? { n -> n % 3 == 0 }           # block
```

`|?` completes the three canonical sequence transformations:
`|` is map, `||` is flat-map, `|?` is filter. Each one has its
own operator. One is left, the one that transforms nothing.

### `|!` — each

The four pipes so far produce a value. `|!` doesn't: it runs
the stage for its **effect** on every element and returns
`Unit`. `xs |! f` is exactly `list.each(xs, f)`.

```kai
[1, 2, 3] |! println("n = #{.}")   # ≡ list.each(xs, (n) => println("n = #{n}"))
```

This is the pipe that takes the place of the `for` loop other
languages have. When you walk a collection to print, to write
or to send a message, the right operator is `|!`, not `|`: `|`
builds a list of results nobody will use, and over a `Stream`
it runs nothing at all until something consumes that list.

Because it returns `Unit`, `|!` **ends** the pipeline. You
filter and transform first, then consume at the end:

```kai
[1, 2, 3, 4, 5, 6] |? is_even | . * 10 |! println("#{.}")
```

No pipe can follow a `|!`, and the compiler says it in those
words:

```kai
# does not compile
[1, 2, 3] |! println("#{.}") | . * 2
```

```
error: `|!` ends a pipeline; it returns `Unit`
```

The check runs the other way too: if the stage returns a value
instead of `Unit`, the error points at the operator and offers
the way out — `|` to transform, or `|> ignore` to drop the
result.

### Together

The five operators mix freely:

```kai
let total =
  orders
  |? is_pending
  | apply_discount
  | amount_of
  |> list.sum
```

Each step does one thing and the result reads left to right,
with no intermediate variables or nested parens. That
readability is the reason kaikai has five operators and not one.

And each operator on its own, with its equivalence alongside:

```kai
# examples/ch06/04_pipes.kai
fn double(n: Int) : Int = n * 2

fn is_even(n: Int) : Bool = n % 2 == 0

# `|>` — apply: LHS is the first arg of the call on the right.
# `xs |> f` ≡ `f(xs)`.
fn example_apply() : Int {
  let xs = [1, 2, 3, 4, 5]
  xs |> list.sum
}

# `|` — map over lists: `xs | f` ≡ `list.map(xs, f)`.
fn example_map() : Int {
  let xs = [1, 2, 3, 4, 5]
  let doubles = xs | double
  list.sum(doubles)
}

# `||` — flat-map: `xs || f` ≡ `list.flat_map(xs, f)`.
# Each element produces a list; all are concatenated.
fn neighbors(n: Int) : [Int] = [n - 1, n, n + 1]

fn example_flat_map() : Int {
  let xs = [10, 20, 30]
  let extended = xs || neighbors
  list.length(extended)
}

# `|?` — filter over lists: `xs |? p` ≡ `list.filter(xs, p)`.
fn example_filter() : Int {
  let xs = [1, 2, 3, 4, 5, 6]
  let evens = xs |? is_even
  list.sum(evens)
}

# `|!` — each: runs the stage for its effect on every element
# and returns `Unit`, so it ends the pipeline.
# `xs |! f` ≡ `list.each(xs, f)`.
fn example_each() : Unit / Stdout {
  let xs = [1, 2, 3]
  xs |! println("|!: element            = #{.}")
}

fn main() {
  println("|>: total              = #{example_apply()}")
  println("|:  sum of doubles     = #{example_map()}")
  println("||: length of extended = #{example_flat_map()}")
  println("|?: sum of evens       = #{example_filter()}")
  example_each()
}
```

```
$ kai run examples/ch06/04_pipes.kai
|>: total              = 15
|:  sum of doubles     = 30
||: length of extended = 9
|?: sum of evens       = 12
|!: element            = 1
|!: element            = 2
|!: element            = 3
```

### The same pipes, but lazy: `Stream`

There's a detail about the list pipes worth keeping in mind:
each step **materializes** a new list. `xs | f` builds the
full list of results before handing it to the next step. For
a ten-element list that's nothing; for a ten-million-element
one, it's ten million intermediate cells per `|` in the
pipeline.

The `stream` module gives you the same four operators —`|`,
`|?`, `||`, `|!`— over a `Stream`: a **lazy** pipeline that
runs in constant memory. Nothing is computed when you write the
`map` or the `filter`; the work happens only when a *sink*
—`foldl`, `to_list`, `count`, `each`— walks the stream and
forces it. `|!` is that `each` written as a pipe, the shortest
way to consume a stream. And there's no intermediate list
between steps: each element
travels the whole pipeline before the next one starts.

```kai
import stream

let total = stream.from_list([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
  |  (x) => x * x          # lazy map
  |? (x) => x % 2 == 0     # lazy filter
  |> stream.foldl(0, (acc, x) => acc + x)
# total = 220
```

If you come from Python these are the lazy generators and
iterators; from Java, `Stream`s; from Rust, iterators. The
idea is the same: describe the transformation without running
it, and let the consumer decide how much to pull.

That's what makes `stream.read_lines(path)` shine: it hands
you a stream of a file's lines, read in constant memory. You
can filter, map, and fold a gigabyte-sized file without
loading it whole —each line comes in, travels the pipeline,
and is discarded before the next is read. A `Stream` isn't a
cursor that advances once; it's a **re-runnable recipe**. The
full catalog is in `kai doc stream`.

A lazy pipeline end to end: two stages that produce nothing
and a sink that walks the stream exactly once.

```kai
# examples/ch06/09_stream.kai
import stream

fn main() : Unit / Stdout {
  # map and filter are lazy: neither builds an intermediate list.
  # `stream.foldl` is the sink that walks the stream once and
  # accumulates the result.
  let total = stream.from_list([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    | (x => x * x)
    # lazy map: square each element
    |? (x => x % 2 == 0)
    # lazy filter: keep the evens
    |> stream.foldl(0, (acc, x) => acc + x)

  Stdout.print("sum of even squares = #{total}")
}
```

```
$ kai run examples/ch06/09_stream.kai
sum of even squares = 220
```

### Lazy and shared too: `Seq`

A `Stream` is a recipe: every walk runs it again. That is what you
want for a gigabyte-sized file, and exactly what you don't want
when computing an element is expensive and you are going to read
it twice.

`Seq[t]` is the other option: a lazy list whose cells are computed
when read, and **at most once**. The first read runs the
computation; every later one hands back what it left behind. You
write it by putting `lazy` in front of a list literal, and inside
`lazy` a range may have no end:

```kai
lazy []                # empty
lazy [1, 2, 3]         # three cells
lazy [2..]             # the integers from 2 up, unbounded
lazy [0, 5..]          # 0, 5, 10, 15, ... unbounded
lazy [p, ...rest]      # one cell and the rest of the sequence
```

List patterns read one too: `[]` and `[first, ...rest]` match a
`Seq` just as they match a list, and the `match` forces only the
cell it is looking at. A range without an end outside `lazy` does
not compile, and the error says what is missing: a list has an
end, a lazy sequence does not.

That each cell is computed once and shared has a consequence that
does not jump out at you: a sequence can be defined **in terms of
itself**.

```kai
import seq

# The naturals: zero, followed by the naturals plus one.
const nat: Seq[Int] = lazy [0, ...seq.map(nat, (x) => x + 1)]

# The unbounded sieve: one filter stage per prime found.
fn sieve(xs: Seq[Int]) : Seq[Int] = match xs {
  []           -> lazy []
  [p, ...rest] -> lazy [p, ...sieve(rest |? (x) => x % p != 0)]
}
```

```
$ kai run examples/ch06/11_seq.kai
naturals: [0, 1, 2, 3, 4, 5, 6, 7]
primes up to 30: [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
the 1000th prime: 7919
```

`nat` names itself inside its own definition and that is fine:
when `map` asks for the next cell, the previous one is already
computed and stored. The sieve is the same idea at work. For every
prime it finds it adds a filter stage over the rest, so the chain
of filters grows as it goes, and nobody decided up front how many
primes would be needed. The 1000th prime comes out of reading
cells that, once computed, stay computed: asking again sieves
nothing. With a re-runnable recipe, every read would sieve from
two all over again.

The language's three lazy forms divide up by who produces and by
what happens when you read them again:

| | who produces | on a second read |
|---|---|---|
| `Stream` | something that already exists, a resource even | runs again |
| `Seq` | you write it, and it is pure | already computed |
| `Gen` | you write it, and it may perform effects | advances, never returns |

A `Seq`'s stages cannot perform effects: they run when somebody
reads a cell, and whoever wrote them does not pick that moment.
The sinks can (`each` and `foldl` run in the consumer and carry
its row). And a `Seq` stays on the fiber that made it: if another
fiber needs a slice, send it `to_list` of that slice. The full
catalog is in `kai doc seq`.

The table's `Gen` is chapter 12's, and there is one difference
from Python's `yield` worth noting here: you write the producer
yourself, with ordinary recursion, and what turns it into a lazy
sequence is an effect handler. A `Stream` consumes something that
already exists; a generator produces. Both fall out of the same
mechanism.

## 6.5 Trailing lambdas and other sugars

kaikai has several syntactic sugars you'll see in real code,
mostly when you use higher-order functions. The main ones:

### Trailing lambdas

When a function takes a lambda as its **last** argument, you
can pull it out of the parens and put it in braces, with the
syntax `{ param -> body }`:

```kai
list.map(xs) { n -> n * 2 }
list.filter(xs) { n -> n > 0 }
```

Equivalent to `list.map(xs, (n) => n * 2)`. Both forms are
accepted; trailing is friendlier when the lambda's body is
long.

When you're inside a pipeline with `|`, the block-lambda is
even more compact. `|` already expects a function as its
second argument, so you can write the body directly:

```kai
xs | { n -> n * 2 }              # equivalent to xs | ((n) => n * 2)
xs | { n -> n * n + 1 }
```

This reads almost like prose. It works for `|` and `||`, and
mixes with the rest of the pipeline without noise.

One detail bites when you nest. A lambda stage does not open a
scope for the stages that follow it, so the next lambda lands
as its sibling, at the same level of the pipe.

```kai
# does not compile
[0..2] | (r) => [0..2] | (c) => r * 10 + c
```

```
error: cannot find `r` in this scope
```

`(c) => …` ended up as a stage of the outer pipe, so `r` was
never in sight. Parentheses put the inner pipe inside the
lambda:

```kai
[0..2] | (r) => ([0..2] | (c) => r * 10 + c)
# [[0, 1, 2], [10, 11, 12], [20, 21, 22]]
```

### Double trailing lambda

If the **two** last arguments are lambdas, both go in braces:

```kai
fn while(pred: () -> Bool, body: () -> Unit) : Unit / e = ...

while { i < 10 } { i := i + 1 }
```

This gives kaikai user-defined control flow. `while` is an
ordinary stdlib function from `loop`; it just looks like a
keyword. Its sibling `until` loops until the condition becomes
true, with a difference that matters: it checks **after** the
body, so `until` always runs at least once, while a `while`
whose condition starts false runs none.

### Block as a lambda

`{ x -> body }` is an alternative lambda form that reads better
when the body spans several lines:

```kai
xs | { n ->
  let squared = n * n
  squared + 1
}
```

It is the same thing as `(n) => { let squared = n * n; squared +
1 }`, with less visual noise.

### Tuple patterns as the parameter

A block lambda's parameter may be a **tuple pattern**. If what
flows through the pipe is pairs — the result of `list.zip` or
`list.enumerate`, say — you destructure on the spot, with no
intermediate `let`:

```kai
let pairs = list.zip(xs, ys)
let sums = pairs | { (a, b) -> a + b }

list.foreach(list.enumerate(rows)) { (i, row) ->
  println("#{i}: #{row}")
}
```

The pattern must be **irrefutable**: `(a, b)` over a pair always
matches. A pattern that can fail — `(Some(n))`, say — is
rejected with a non-exhaustive-match diagnostic; that's what
`match` is for. And note a deliberate asymmetry: the
destructuring is block-lambda only. The arrow form
`(a, b) => ...` remains a **two-parameter** lambda, not one that
takes a pair.

None of these sugars introduce new semantics. They are
alternative ways to write lambdas that the compiler desugars
before type inference. Use them when the reading improves;
ignore them when it doesn't.

The forms one after another: the first three give the same
result, and the last two show what the braces are for when the
body grows or the parameter is a pair.

```kai
# examples/ch06/08_trailing_blocks.kai
fn main() {
  let xs = [1, 2, 3, 4, 5]

  # 1. Form with parens and classic arrow.
  let a = list.map(xs, n => n * 2)
  println("a sum=#{list.sum(a)}")

  # 2. Trailing lambda: body in braces at the end.
  let b = list.map(xs) { n -> n * 2 }
  println("b sum=#{list.sum(b)}")

  # 3. Block-lambda in pipe: shortest form.
  let c = xs | { n -> n * 2 }
  println("c sum=#{list.sum(c)}")

  # Multi-line bodies: braces form reads better.
  let d = xs
    | { n ->
      let square = n * n
      square + 1
    }
  println("d sum=#{list.sum(d)}")

  # 4. The parameter may be a tuple pattern: it destructures
  #    the pair on the spot, no intermediate `let`.
  let pairs = list.zip(xs, [10, 20, 30, 40, 50])
  let e = pairs | { (a, b) -> a + b }
  println("e sum=#{list.sum(e)}")
}
```

```
$ kai run examples/ch06/08_trailing_blocks.kai
a sum=30
b sum=30
c sum=30
d sum=60
e sum=165
```

## 6.6 Recursion and mandatory TCO

An important promise from kaikai: **every recursive call in
tail position compiles to a loop**. No stack consumption. No
risk of stack overflow from a long recursion.

Let's see what "tail position" means. A call is in **tail
position** if it's the last thing the function does before
returning. Compare these two versions of `sum`:

```kai
# NOT in tail position: the call leaves `h + ...` pending.
fn sum_naive(xs: [Int]) : Int {
  case []         -> 0
  case [h, ...t]  -> h + sum_naive(t)
}
```

Here, after `sum_naive(t)` returns, you still have to add
`h`. The call **is not** the last thing; an operation
remains. Each call consumes a stack frame.

```kai
# In tail position: the last thing in each recursive arm is
# **only** the call, no pending operation.
fn sum_tco_loop(xs: [Int], acc: Int) : Int {
  case [], a         -> a
  case [h, ...t], a  -> sum_tco_loop(t, a + h)
}

fn sum(xs: [Int]) : Int = sum_tco_loop(xs, 0)
```

Here, in each recursive arm, `sum_tco_loop(t, a + h)` is
**the last thing**. The sum `a + h` is evaluated first,
passed as an argument, and then the call happens. When the
call returns, the current function returns immediately too:
nothing remains to do. The compiler detects this pattern and
compiles to a loop, no new frame.

```kai
# This works without blowing the stack:
let many = [1..100_000]
sum(many)        # 5_000_050_000
```

The **accumulator** technique you see in `sum_tco_loop` is
the standard way to convert a naive recursion into a tail
recursion: you add an extra parameter that carries the
partial result, and at the end you return it.

Why does this matter, really?

- **Without mandatory TCO, you couldn't replace `for` and
  `while`.** With limited stack, an iteration over a million
  elements would run out. Only with guaranteed TCO can you
  take the leap to programming with recursion.
- **It's a language guarantee, not an opportunistic
  optimization.** Some languages optimize TCO when they
  remember; kaikai promises it. A function whose final
  expression calls itself runs in constant stack, and that is
  mandatory, not a heuristic.
- **Mutual recursion is part of the promise too, with one
  condition.** If `is_even` ends by calling `is_odd` and vice
  versa, the cycle runs in constant stack on both backends: the
  compiler fuses the group into a single self-recursive
  function, so the cycle becomes the same loop a self-call
  compiles to. It holds for cycles of two and for longer ones.
  The condition is that the members share **one signature**:
  same parameter types, same return type, same effect row, and
  no type parameters. A cycle whose members disagree spends a
  frame per hop, and deep enough it dies with `kai: fiber stack
  overflow`.
- **A tail call that closes no cycle does keep its frame.** `f`
  calling `g`, where `g` never leads back to `f`, is an ordinary
  call. The guarantee is about cycles, not about anything
  written in tail position.
- **Nothing warns you in advance.** The compiler doesn't flag
  recursion you thought was in tail position and isn't — you
  find out when the program blows the stack. That's why the
  accumulator form is what you write from the start, not what
  you reach for once it hurts.

The classic pair, plus a cycle of three to show the guarantee is
not limited to pairs:

```kai
# A cycle of two.
fn even(n: Int) : Bool = if n == 0 { true } else { odd(n - 1) }

fn odd(n: Int) : Bool = if n == 0 { false } else { even(n - 1) }

# A cycle of three: the guarantee is not limited to pairs.
fn a(n: Int) : Bool = if n == 0 { true } else { b(n - 1) }

fn b(n: Int) : Bool = if n == 0 { false } else { c(n - 1) }

fn c(n: Int) : Bool = if n == 0 { true } else { a(n - 1) }

fn main() : Unit / Stdout {
  println("even(5000000) = #{even(5000000)}")
  println("odd(5000000)  = #{odd(5000000)}")
  println("a(5000000)    = #{a(5000000)}")
}
```

```
$ kai run examples/ch06/10_mutual_recursion.kai
even(5000000) = true
odd(5000000)  = false
a(5000000)    = true
```

Five million hops in each cycle, and neither grows the stack.
Without the guarantee this would not reach the first `println`.

In practice, most recursive functions you write to process
lists or trees will have the shape `match xs { [] -> base;
[h, ...t] -> recursion }`. The naive version (with pending
operation) is the first you write; the accumulator version
is the one you keep. For more complex operations, the
higher-order functions (`list.foldl`, `reduce`) are
already TCO-written and are almost always what you wanted.

Both versions in one program, and the hundred-thousand-element
list that only the second one walks without growing the stack:

```kai
# examples/ch06/05_recursion_tco.kai
# Linear recursion NOT in tail position: each call leaves
# `h + ...` pending. Works but grows the stack.
fn sum_naive(xs: [Int]) : Int {
  case [] -> 0
  case [h, ...t] -> h + sum_naive(t)
}

# Tail-recursive: the last thing each branch does is **only**
# the call, no pending operation. kaikai compiles to a loop.
fn sum_tco_loop(xs: [Int], acc: Int) : Int {
  case [], a -> a
  case [h, ...t], a -> sum_tco_loop(t, a + h)
}

fn sum(xs: [Int]) : Int = sum_tco_loop(xs, 0)

fn main() {
  let thousand = [1..1000]
  println("sum 1..1000 (naive) = #{sum_naive(thousand)}")
  println("sum 1..1000 (tco)   = #{sum(thousand)}")

  # With TCO we can sum much larger lists without worrying
  # about the stack:
  let hundred_k = [1..100_000]
  println("sum 1..100_000 (tco) = #{sum(hundred_k)}")
}
```

```
$ kai run examples/ch06/05_recursion_tco.kai
sum 1..1000 (naive) = 500500
sum 1..1000 (tco)   = 500500
sum 1..100_000 (tco) = 5000050000
```

## 6.7 Case study: transformation pipeline

Let's close with an integrative case. You have a list of
orders from a store, with an id, an amount, and a status.
You want the total to bill **considering only pending
orders** and **applying a 10% discount on high amounts**:

```kai
# examples/ch06/06_pipeline.kai
type Status = Pending | Paid | Cancelled

type Order = {
  id: Int,
  amount: Int,
  status: Status
}

# Small functions, each doing one thing.
fn is_pending(o: Order) : Bool =
  match o.status {
    Pending -> true
    Paid -> false
    Cancelled -> false
  }

# Discount: 10% on amounts >= 1000, 0% on the rest.
fn apply_discount(o: Order) : Order =
  if o.amount >= 1000 {
    Order { ...o, amount: o.amount - o.amount / 10 }
  } else {
    o
  }

fn amount_of(o: Order) : Int = o.amount
```

Each small function does **one thing**. One decides if an
order is pending, another applies a discount if applicable,
another extracts the amount. None knows about the pipeline;
all are useful on their own.

And the pipeline composes them:

```kai
fn main() {
  let orders = [
    Order { id: 1, amount: 500, status: Pending },
    Order { id: 2, amount: 2000, status: Pending },
    Order { id: 3, amount: 1500, status: Paid },
    Order { id: 4, amount: 800, status: Cancelled },
    Order { id: 5, amount: 1200, status: Pending }
  ]

  # Pipeline: filter pending, apply discount, sum.
  let total =
    orders
      |? is_pending
      | apply_discount
      | amount_of
      |> list.sum

  println("total to bill: #{total}")
}
```

```
$ kai run examples/ch06/06_pipeline.kai
total to bill: 3380
```

Five lines, four steps. Filter the pending, apply discount
to each, extract the amount, sum everything. If later the
client asks for "let's add a 100 fixed fee for orders >
5000", you add a small function and put it in the pipeline:

```kai
fn fee_if_large(o: Order) : Order =
  if o.amount > 5000 {
    Order { ...o, amount: o.amount + 100 }
  } else {
    o
  }

let total =
  orders
  |? is_pending
  | apply_discount
  | fee_if_large
  | amount_of
  |> list.sum
```

That's one more line and no new coupling. That's the point of
functional style: **small functions composed in linear-reading
pipelines**. The complexity lives in each individual
function; composition is trivial.

Compare with the typical imperative version:

```python
total = 0
for o in orders:
    if o.status != "pending":
        continue
    amt = o.amount
    if amt >= 1000:
        amt -= amt // 10
    if amt > 5000:
        amt += 100
    total += amt
```

Works, but the calculation logic is tangled with the loop
mechanics. Reordering transformations, adding a step,
removing a step — operations that in the pipeline are one
line, in the imperative version are a refactor.

If you come from Java, JavaScript, C# or Kotlin, you've seen
something similar with their respective stream/iterator APIs.
The difference is that in kaikai the pipeline is a syntactic
construction of the language, not an API on top of the
language. You don't need to wrap the list in a special
object, no `.collect()` methods or terminators; pipes are as
ordinary as `+` or `*`.

## Exercises

**6.1.** Write `fn apply_n(f: (Int) -> Int, x: Int, n: Int)
: Int` that applies `f` to `x` exactly `n` times. For
example, `apply_n(plus_one, 5, 3)` should be `8`. Use tail
recursion.

**6.2.** Define `fn compose3[a, b, c, d](f: (c) -> d,
g: (b) -> c, h: (a) -> b) : (a) -> d` that composes three
functions. Test with `compose3(square, plus_one, double)(2)`.

**6.3.** Rewrite the §6.7 pipeline using only `|>` (no `|`,
`|?` or `||`). How many more characters? How does
readability change?

**6.4.** Define a sum type `type Operation = Add(Int) |
Multiply(Int) | Negate`. Write `fn apply_op(op: Operation,
x: Int) : Int` that runs the operation on `x`, and
`fn run_all(ops: [Operation], x: Int) : Int` that runs a
sequence of operations starting with `x`. Hint: `list.foldl`
with `apply_op` flipped is a good path.

**6.5.** You have a list of strings with numbers: `["10",
"abc", "20", "", "30"]`. You want the sum of the **valid
numbers**, ignoring the rest. Build a pipeline using
`list.flat_map` (or `||`) and `string_to_int : String ->
Option[Int]`. Hint: a function `Option[a] -> [a]` helps —
if it's `Some(x)` return `[x]`, if `None` return `[]`. That
step is the natural flat-map.
