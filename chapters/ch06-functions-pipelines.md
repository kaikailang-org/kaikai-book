# Chapter 6 · Functions and pipelines

So far you've been seeing functions as you needed them: the
first ones in the tour, those of chapter 3 with their two
body forms, the recursive ones of chapter 5 that decompose
sum types. This chapter puts everything together and adds
what was missing: how to declare functions carefully, how to
write lambdas, what higher-order functions are, and the four
pipe operators kaikai uses to chain transformations.

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
fn square_plus_one(x: Int) : Int = {
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
fn divide(a: Real, b: Real) : Result[Error, Real] {
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

### Point-free sections: when the lambda only projects

There is a case even more common than the placeholder: the
lambda that does nothing but **reach into the element** to pull
out a field or call a method. `(p) => p.name`, `(s) =>
s.length()`. No computation, no operator, just a projection.
For that kaikai has an even shorter form, the **point-free
section**: a leading `.` followed by the field, the field path,
or the method call.

```kai
type Addr = { city: String }
type Person = { name: String, addr: Addr }

let people = [Person { name: "ana", addr: Addr { city: "Hanga Roa" } }]
let names  = people | .name           # (p) => p.name
let cities = people | .addr.city       # (p) => p.addr.city
let lengths = names | .length()        # (s) => s.length()
```

The section reads as the projection itself, with no parameter
name to invent. The receiver is supplied implicitly (the first
argument by UFCS), so `.starts_with("a")` reads its written
argument *after* the receiver. It works as the function of `|`,
`||`, `|?` and as a combinator argument (`.map`, `.and_then`,
`.filter`):

```kai
let starts = names |? .starts_with("a")  # (s) => s.starts_with("a")
let n      = Some("hi").map(.length())   # in argument position
```

One limit to keep clear from the start: a point-free section
**only projects**. The moment the body does anything more (an
operator, a comparison, two uses of the parameter), it stops
being point-free and you go back to the arrow. This does **not**
compile:

```kai
let adults = people |? .age > 18         # ERROR: mixes projection with `>`
```

What you want there is the explicit arrow, `(p) => p.age > 18`.
The practical rule: if the lambda *only* pulls out a field or
calls a method, write it point-free; if it does anything else,
arrow.

Lambdas are **first-class values**: you bind them with `let`,
pass them as arguments, return them from functions, store
them in records. That's what makes higher-order functions
natural.

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

## 6.4 Pipes: `|>`, `|`, `||`, `|?`

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

`|?` closes the family of list-specific pipes: `|` is map,
`||` is flat-map, `|?` is filter. The three canonical
list-transformation operations have their own operator.

### Together

The four operators mix freely:

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
readability is the reason kaikai has four operators and not one.

### The same pipes, but lazy: `Stream`

There's a detail about the list pipes worth keeping in mind:
each step **materializes** a new list. `xs | f` builds the
full list of results before handing it to the next step. For
a ten-element list that's nothing; for a ten-million-element
one, it's ten million intermediate cells per `|` in the
pipeline.

The `stream` module gives you the same three operators —`|`,
`|?`, `||`— over a `Stream`: a **lazy** pipeline that runs in
constant memory. Nothing is computed when you write the `map`
or the `filter`; the work happens only when a *sink* —`foldl`,
`to_list`, `count`, `each`— walks the stream and forces it.
And there's no intermediate list between steps: each element
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

### Double trailing lambda

If the **two** last arguments are lambdas, both go in braces:

```kai
fn while_loop(cond: () -> Bool, body: () -> Unit) : Unit / e = ...

while_loop { i < 10 } { i := i + 1 }
```

This gives kaikai user-defined control flow. `while_loop` is
an ordinary stdlib function; it just looks like a keyword.

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
  remember; kaikai promises it. If a recursive call is in tail
  position, the compiler converts it — there's no heuristic
  deciding whether to bother.
- **The compiler warns you if you think you wrote TCO but
  didn't.** There's a flag for that, so you don't find out by
  surprise when your program dies in production.

In practice, most recursive functions you write to process
lists or trees will have the shape `match xs { [] -> base;
[h, ...t] -> recursion }`. The naive version (with pending
operation) is the first you write; the accumulator version
is the one you keep. For more complex operations, the
higher-order functions (`list.foldl`, `reduce`) are
already TCO-written and are almost always what you wanted.

## 6.7 Case study: transformation pipeline

Let's close with an integrative case. You have a list of
orders from a store, with an id, an amount, and a status.
You want the total to bill **considering only pending
orders** and **applying a 10% discount on high amounts**:

```kai
type Status = Pending | Paid | Cancelled

type Order = {
  id: Int,
  amount: Int,
  status: Status,
}

fn is_pending(o: Order) : Bool =
  match o.status {
    Pending   -> true
    Paid      -> false
    Cancelled -> false
  }

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
let total =
  orders
  |? is_pending
  | apply_discount
  | amount_of
  |> list.sum
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
