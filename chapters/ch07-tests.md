# Chapter 7 · Tests, properties, and benchmarks

So far you've been writing functions and looking at the
output. That's a reasonable cycle while your program fits in
your head, but it doesn't scale. As soon as your code grows
past a few dozen lines — as soon as there are more than three
functions calling each other — you stop being able to verify
by eye that each change preserves behavior.

That's what tests are for. kaikai brings **three top-level
constructs** dedicated to verification: `test`, `check`, and
`bench`. All three run via the `kai` driver, and all three
are stripped out when you build a binary for production.

The usual thing is to write them in the same file as the code
they exercise, but the language doesn't force it: an
`arithmetic_test.kai` that imports `arithmetic` and declares its
`test` blocks compiles and runs fine. The driver finds it on its
own, too: `kai test ./...` walks the package's `*_test.kai`
files even when nothing imports them, runs each as its own unit,
and exits non-zero if any of them fails. That holds for a
**library** as well — a package that by definition declares no
entry point.

This chapter walks through the three, explains when to use
which, and closes with a case study: a mini-evaluator with
contractual tests, verified properties, and benchmarks
measuring per-operation cost.

## 7.1 `test "..." { ... }` and `assert`

The simplest form is a test with a name and a body:

```kai
fn factorial(n: Int) : Int =
  if n <= 1 { 1 } else { n * factorial(n - 1) }

test "base case" {
  assert factorial(0) == 1
  assert factorial(1) == 1
}

test "small cases" {
  assert factorial(3) == 6
  assert factorial(5) == 120
}

test "significant case" {
  assert factorial(10) == 3628800
}
```

`test` is a **top-level block** — it lives alongside `fn` in
the same file, not nested in another function. Its name is a
string literal the runner prints verbatim. Inside, you write
assertions with `assert`: a `Bool` expression that must be
`true`. If all the block's assertions pass, the test passes.
If **one** fails, the test fails and the runner moves on to
the next.

The test name should say **what is being tested**, not how.
"base case" is good; "test 1" isn't.

`assert` also accepts an optional message with a comma:

```kai
test "valid ranges" {
  let n = classify(42)
  assert n > 0, "expected positive, got #{n}"
}
```

The message appears when the assertion fails. Useful when
the expression you tested doesn't, by itself, tell you what
was unexpected.

### What the runner prints

```
$ kai test examples/ch07/01_basic_test.kai
  ok   base case
  ok   small cases
  ok   significant case

3/3 tests passed
```

If a test fails, the output changes to show it:

```
$ kai test examples/ch07/02_assert_fails.kai
  ok   double preserves positives
  FAIL broken test: assert will fail : assertion failed
  ok   this test still runs

2/3 tests passed
```

Three details worth recalling:

- **Tests run in declaration order.** Your file lists them
  top-to-bottom and the runner runs them in that order. No
  parallelism within a single file.
- **A failing test doesn't stop the rest.** The runner moves
  on and reports the final count.
- **`test` blocks don't end up in the production binary.**
  `kai run` and `kai build` discard them. They're only
  compiled and executed under `kai test`.

### What effects a test may carry

A `test` body — like a `bench` or a `check` body — carries no
effect row and cannot declare one. So the question is what it's
allowed to do inside, and the answer is: whatever a program entry
may. It absorbs the builtin effects that come with a default
handler (`Stdout`, `File`, `Clock`, …) plus the `Ffi` capability
the compiler synthesises. That's why a test can call an
`extern "C"` fn with nothing wrapped around it:

```kai
# examples/ch07/06_effects_in_tests.kai
extern "C" fn llabs(x: Int) : Int / Ffi

test "a test can call an extern C fn directly" {
  assert llabs(0 - 5) == 5
}
```

An effect of **your own** is another story, and this is where
people trip. There's no handler for it at the runner's entry, so
calling it bare doesn't compile:

```
error: effect not handled: Clock
  --> x.kai:6:21
    |
  6 |   assert Clock.now() == 1234
    |                    ^
  = note: enclosing row: (empty)
```

That last note is the clue: the row surrounding the test is
empty, and there's nowhere to declare one. The way out is to
install the handler inside the body — which is usually what you
wanted anyway, since now the test decides what the clock returns
instead of depending on the real one:

```kai
test "a user-declared effect is handled inside the body" {
  let t = handle { Clock.now() } with Clock {
    now(resume) -> resume(1234)
  }
  assert t == 1234
}
```

Seen that way the restriction works in your favor: a test that
needs an effect of yours forces you to say what you're replacing
it with, right where it's read.

## 7.2 `kai test` and the short feedback loop

The command is straightforward:

```
$ kai test my_file.kai
```

Compiles the file in `--test` mode (which activates `test`
blocks), produces a binary, runs it, and reports. The
edit→run cycle takes a second or two on small files.

If you are inside a project (a directory with `kai.toml`),
`kai test .` runs the main package's tests and also
auto-discovers any `.kai` under the `tests/` directory. Each
file under `tests/` is compiled as its own unit — not as
part of the package, but as a standalone test program. If
you need to exercise a `pub` function of the package from
`tests/`, import it like any other dependency:
`import my_package`.

If you call `kai test my_file.kai` against a loose file, the
runner runs everything that file and its imports declare
with `test`. There is no `pytest`-style discovery on loose
files; the model only discovers when there is a `kai.toml`
defining the package.

Three practical recommendations you'll internalize within
weeks:

- **Tests next to the code, in the same file.** Don't
  separate them into `tests/` or parallel files. When you
  touch a function, its tests are right there.
- **One test per aspect, not per line.** If your function
  has a base case, small cases, and an edge case, write
  three `test`s. If "small cases" has three examples, add
  them as three `assert`s in the same block.
- **Descriptive names.** The name appears in the runner's
  output every time you run the tests. `"validate email
  rejects spaces"` reads; `"test_3"` doesn't.

### Results for machines: `--json`

The colored, ticked output is for you. When the reader is
another program — a CI runner annotating the commit, a
dashboard, a script diffing two runs — there is a second
shape:

```
$ kai test --json my_file.kai
{"type":"test","id":"my_file.kai:one","file":"my_file.kai","line":3,"status":"pass","duration_ms":0}
{"type":"summary","passed":1,"failed":0,"duration_ms":0}
```

It is NDJSON: one JSON object per line, one per `test` block,
and a `summary` at the end. Without the flag the human output
is unchanged, so adding it to a pipeline does not alter what
you see in the terminal.

Three details for whoever consumes it. A failing block also
carries a `message` with the assert's text, and the exit code
is still 1. The `id` — `file:test name` — is the canonical way
to name a block: stable across runs as long as the name and
the file hold. And if a test body prints, that output goes to
the same stdout as the records, interleaved among them: a
parser has to tolerate lines that are not JSON.

## 7.3 `check "..."` — properties

The tests you've seen so far check **fixed cases**: "for this
input, I expect this output". This is what other languages
call "example-based testing". It's the most common, but it
has an obvious limit: it only tests what you write.

**Properties** flip the thing around. Instead of "for
`square(7)` I expect `49`", you write "for every integer `n`,
`square(n)` must be `>= 0`". The runner generates random
values of `n` and verifies the property over each. If it
finds a counterexample, it shows you; if it passes a hundred
iterations without failure, it considers the property
proved.

```kai
fn double(n: Int) : Int = n * 2

check "double is even" with n: Int {
  double(n) % 2 == 0
}

check "addition is commutative" with a: Int, b: Int {
  a + b == b + a
}

check "addition is associative" with a: Int, b: Int, c: Int {
  (a + b) + c == a + (b + c)
}

check "reverse of reverse" with xs: [Int] {
  list.reverse(list.reverse(xs)) == xs
}
```

`check "..." with name: Type { body }` declares a property.
The `with` clause lists the parameters the runner generates
randomly; the `body` is a `Bool` expression that must be
`true`.

```
$ kai check examples/ch07/03_check_properties.kai
  double is even: 100 iter, OK
  addition is commutative: 100 iter, OK
  addition is associative: 100 iter, OK
  reverse of reverse: 100 iter, OK

4/4 checks passed
```

A hundred iterations per property is the default; each
iteration generates fresh values. For `Int`, the default
range is `[-50, 50]`. For `[Int]`, small lists. For records
and sum types, the generator structures the components
recursively.

### When a property fails

```kai
check "all Ints are positive" with n: Int {
  n > 0
}
```

```
$ kai check false_property.kai
  all Ints are positive: counterexample at iter 1: n=-32

0/1 checks passed
```

The runner gives you the **exact counterexample** (`n =
-32`) at the first failing iteration. That tells you three
things:

- The property is false for some value of `n`.
- The concrete value.
- Which iteration failed (useful for reproducing with the
  same seed if you want to debug).

Unlike a `test` with a fixed case, where the test name is
what diagnoses the failure, a `check` gives you the test case
**along with** the report. You don't have to write it: you
have it.

### When to write a `check`

Properties are useful when you can **state a universal
truth** about your code. Some common examples:

- **Inverses**: `parse(format(x)) == x`,
  `decompress(compress(x)) == x`. The byte round-trip that
  `#[derive(Layout)]` generates (chapter 19) is exactly this
  shape.
- **Idempotence**:
  `normalize(normalize(s)) == normalize(s)`.
- **Algebraic invariants**: commutativity, associativity,
  identity.
- **Conservation**: the `length` of the output equals that
  of the input, the sum is preserved, etc.
- **Monotonicity**: if `a < b`, then `f(a) < f(b)`.

If what you want to verify is "for input 7, output is 14",
that's a `test`. If it's "for any input, what comes out is
twice the value", that's a `check`.

## 7.4 `bench "..." { ... }` — measure, don't guess

The third construct is for **performance**. `bench` takes a
block and measures how long it takes to execute, repeated
many times for the average:

```kai
fn fib(n: Int) : Int =
  if n < 2 { n } else { fib(n - 1) + fib(n - 2) }

bench "arithmetic: 2 + 3 * 4" {
  2 + 3 * 4
}

bench "fib(10)" {
  fib(10)
}

bench "fib(15)" {
  fib(15)
}
```

```
$ kai bench examples/ch07/04_basic_bench.kai
  arithmetic: 2 + 3 * 4: 1000 iter / median 0 ns / MAD 0 ns / mean 29 ns / range [0, 1000]
  fib(10): recursion without memo: 1000 iter / median 0 ns / MAD 0 ns / mean 200 ns / range [0, 1000]
  fib(15): cost grows exponentially: 1000 iter / median 2000 ns / MAD 0 ns / mean 2281 ns / range [2000, 8000]
  list.sum [1..100]: 1000 iter / median 2000 ns / MAD 0 ns / mean 2098 ns / range [2000, 3000]

4 benches
```

Each bench runs 1000 iterations (configurable with `--iters N`)
and reports four numbers: the median, the MAD (median absolute
deviation), the mean, and the range.

Look at the first two lines, because they teach you how to read
the report: the median and the MAD are both 0. That doesn't mean
the operation is free. It means **you didn't measure it**: each
iteration costs less than the clock's resolution, so the clock
returned zero every time.

And when that happens, the mean is no use either. The only thing
keeping it off zero is scheduler noise — which is where ranges
like `[0, 1000]` come from. Two rows reading `median 0 / MAD 0`
can show wildly different means with no difference in work
between them; comparing those means is reading noise.

So `median 0 / MAD 0` is not a measurement, it's a warning that
you need to measure differently: make each iteration do more
work, or write a program that repeats the operation in a loop,
consumes the result so the optimizer can't delete it, and time
that whole program. A solid measurement looks like `fib(15)`:
median and mean in the same order of magnitude, with the MAD
small next to both.

What matters about benchmarks isn't the absolute number — it
depends on the machine and on what else is running — but the
**comparison**. When you refactor a critical function, you
run the bench before and after. When your pipeline starts to
feel slow, you compare candidate function versions. The
rule:

> **Optimizing without measuring is guessing.**

There's no point benchmarking code that doesn't bother you; but
when something drags, measuring before you touch it keeps you
from optimizing what wasn't the problem. That's what `bench` is
for.

Three practical pieces of advice:

- **The body of the `bench` is what's measured.** If your
  setup is expensive and you don't want to include it, do it
  outside the block and leave only the operation to measure
  inside.
- **kaikai doesn't discard "pure" calls without observable
  effect.** `bench "fib(10)" { fib(10) }` actually computes
  `fib(10)` each iteration. In other languages with more
  aggressive optimizations you have to use tricks to avoid
  dead-code elimination; here you don't.
- **The absolute number is suggestive, not authoritative.**
  To compare, always measure on the same machine, in the
  same session, without other heavy loads running in
  parallel.

## 7.5 When to use which

You have the three tools. The decision boils down to a
simple question:

| Question | Tool |
|---|---|
| For this concrete input, does the output match my expectation? | `test` |
| For **every** input, does this invariant hold? | `check` |
| How much does this operation cost? | `bench` |

The three complement each other. A serious project will have
all three in the same file: tests for the contractual cases
(the customer's, the edges, the ones that historically
failed), checks for the algebraic invariants the code
preserves, and benchmarks for the few critical functions
where performance matters.

A note on writing order. The natural sequence is:

1. **Start with a `test`** — the concrete case for the
   feature you're working on. It's the easiest to write and
   the easiest to look at when something fails.
2. **Add `test`s** for edge cases as they show up.
3. **Move to `check`s** when you see a pattern in the tests:
   "all these cases are checking the same invariant, just
   with different data". That's a sign that a property
   should capture the general rule.
4. **Add a `bench`** when you start to notice slowness, or
   before an optimization refactor to have a baseline.

Not the other way around. Starting with a `check` when you
don't yet know what properties you'll preserve leads to
vague properties that pass by accident. Starting with a
`bench` before performance matters is premature
optimization, so start with tests.

## 7.6 Case study: tests for a mini-evaluator

Closing with an integrative example: a small arithmetic
expression evaluator with error handling, tested with the
three tools. The complete code is in
`examples/ch07/05_evaluator_tests.kai`; here we walk
through the parts.

### The AST and the evaluator

```kai
type Expr
  = Lit(Int)
  | Add(Expr, Expr)
  | Mul(Expr, Expr)
  | Div(Expr, Expr)

type EvalError = DivByZero(Int)

fn eval(e: Expr) : Result[Int, EvalError] = match e {
  Lit(n)    -> Ok(n)
  Add(a, b) -> { ... }
  Mul(a, b) -> { ... }
  Div(a, b) -> {
    let va = eval(a)!
    let vb = eval(b)!
    if vb == 0 { Err(DivByZero(va)) } else { Ok(va / vb) }
  }
}
```

It's a smaller cousin of the chapter 5 evaluator: four
constructors, one error category (division by zero). Enough
to show the flow.

### Tests for contractual cases

```kai
test "literal" {
  assert must_yield(Lit(42), 42)
}

test "combined: 2 + 3 * 4 = 14" {
  assert must_yield(Add(Lit(2), Mul(Lit(3), Lit(4))), 14)
}

test "division by zero is an error" {
  assert must_fail(Div(Lit(10), Lit(0)))
}
```

Three tests documenting three behaviors. `must_yield` and
`must_fail` are helpers wrapping the `match` over `Result`
and returning `Bool`, so the `assert` stays readable.

```
4/4 tests passed
```

### Checks for invariants

```kai
check "Lit(n) evaluates to n" with n: Int {
  must_yield(Lit(n), n)
}

check "Add(a, b) == Add(b, a)" with a: Int, b: Int {
  must_yield(Add(Lit(a), Lit(b)), a + b) and must_yield(Add(Lit(b), Lit(a)), a + b)
}
```

Two properties. The first says a literal evaluates to itself
— a trivial invariant but important: if it failed, something
is very wrong in the evaluator. The second checks that
addition is commutative **through the evaluator**, not just
at the integer-arithmetic level.

```
2/2 checks passed
```

A hundred iterations per property with randomly generated
values. None failed. If in the future someone breaks
commutativity — say, by adding a side effect to evaluating
`Add` that depends on order — the `check`s detect the
counterexample immediately.

### Benchmarks for performance decisions

```kai
bench "literal" {
  eval(Lit(42))
}

bench "deep expression (3 levels)" {
  eval(Add(Mul(Lit(2), Lit(3)), Add(Lit(4), Mul(Lit(5), Lit(6)))))
}
```

Two benches: the cheap case (a literal) and a more complex
case (three nesting levels). On my machine:

```
  literal: 1000 iter / median 0 ns / MAD 0 ns / mean 52 ns / range [0, 1000]
  deep expression (3 levels): 1000 iter / median 1000 ns / MAD 0 ns / mean 574 ns / range [0, 2000]
```

Read those two rows with the rule above in hand. The literal one
reads `median 0 / MAD 0`: evaluating `Lit(42)` is cheaper than
the clock, so that row measured nothing and its mean is noise.
The deep-expression row did measure: median and mean in the same
order of magnitude.

So this pair does **not** entitle you to say "the second costs N
times the first": that would require comparing two measurable
things, and one of them isn't. It tells you something else, just
as useful: the cheap case is below what the bench can resolve,
and the expensive one is what's worth watching if the evaluator
starts to weigh. If you really need the ratio between them, take
`bench` out of the picture and time a program that repeats the
operation and consumes the result.

### Who tests the tests?

So far everything is green: four tests, two checks, zero
failures. But a green run proves one thing only — that the tests
passed. It doesn't prove they would have failed had the code been
wrong, and that is what you actually want from a suite.

`kai mutate` measures it head-on. It breaks the code on purpose,
one construct at a time — a `match` arm that disappears, a `>=`
that becomes `>`, a `false` that becomes `true` — and runs your
tests against each broken version. If any test fails, the mutant
is killed: something noticed. If they all pass, the mutant
survives, and that's a hole.

```
$ kai mutate --module examples/ch07/05_evaluator_tests.kai \
             --oracle 'kai test examples/ch07/05_evaluator_tests.kai'
```

`--oracle` is the command that decides whether the code is
healthy: anything that exits 0 when all is well. The default is
`kai test` over the package; here I point it at this one file
because `examples/ch07` also holds `02_assert_fails.kai`, which
fails on purpose, and with it in the count every mutant would be
killed without anything having really noticed.

The whole run fits on a screen:

```
killed    examples/ch07/05_evaluator_tests.kai:33  negate
killed    examples/ch07/05_evaluator_tests.kai:33  literal
SURVIVED  examples/ch07/05_evaluator_tests.kai:41  literal
SURVIVED  examples/ch07/05_evaluator_tests.kai:47  literal
killed    examples/ch07/05_evaluator_tests.kai:48  literal

survivors — the suite did not notice these:

examples/ch07/05_evaluator_tests.kai	41	15	literal
    41c41
    <     Err(_) -> false
    ---
    >     Err(_) -> true
examples/ch07/05_evaluator_tests.kai	47	14	literal
    47c47
    <     Ok(_) -> false
    ---
    >     Ok(_) -> true

24 mutants in 18s: 3 killed, 19 did not compile, 2 survived
```

Twenty-four mutants, and only five of them reached the tests.
The other nineteen never compiled — which is not a failing of the
tool but the type system doing its work ahead of the suite. Five
come from dropping a `match` arm, which leaves the match
non-exhaustive, and fourteen from eliding a call, which leaves a
`!` sitting on something that isn't a `Result`. Both are compile
errors in kaikai, so those mutants die before any test gets a
say. `kai mutate` counts them in a bucket of their own for
exactly that reason: a mutant that doesn't compile tells you
nothing about what your tests are watching. In a language with
exhaustive matching and strong types that bucket fills up fast,
and it's worth knowing before you read the result — mutation
ends up measuring a smaller target than you might expect.

The five that did compile are the ones that talk. Three died and
two survived, and both survivors sit in the same awkward place:
not in the evaluator but in the tests' own helpers. Line 41 is
the `Err` branch of `must_yield`. No test
hands `must_yield` an expression that fails, so nobody finds out
if that branch says `true` — and a `must_yield` that accepts
errors lets through any regression in `eval` that starts
returning `Err` where it shouldn't. Line 47 is the same hole
backwards: nobody hands `must_fail` an expression that evaluates
fine.

Closing them costs two one-line tests:

```kai
test "must_yield rejects an error" {
  assert not must_yield(Div(Lit(10), Lit(0)), 0)
}

test "must_fail rejects a result" {
  assert not must_fail(Lit(1))
}
```

With them — the same evaluator, in
`examples/ch07/07_mutants.kai` — the run ends like this:

```
24 mutants in 18s: 5 killed, 19 did not compile, 0 survived
```

The same five mutants that compile, all five now caught. Zero
survivors is as much as you can ask for.

Notice what it doesn't report: a percentage. `kai mutate` hands
you survivors, each with file, line and diff, because a survivor
is something you can fix this afternoon and a "92% mutation
score" is a number nobody fixes. Nor is it something to run on
every commit: each mutant costs a run of your tests. It's a
review tool, for when you wonder whether that very green suite is
looking at anything.

A green test says your code passed. A surviving mutant says what
your tests stopped looking at.

### What the file doesn't show

The mechanism is direct. The file declares functions, declares
tests, declares checks, declares benches, all in the same
place. Three commands process it:

```
$ kai test  examples/ch07/05_evaluator_tests.kai
$ kai check examples/ch07/05_evaluator_tests.kai
$ kai bench examples/ch07/05_evaluator_tests.kai
```

And `kai run` and `kai build` ignore the three constructs.
The deployed binary loads neither tests nor checks nor
benches — only production code.

That unification is what makes the model comfortable. There
is no separate test project, no frameworks to import, no
decisions about where to put each thing. The question
"where are the tests for this function?" has only one
possible answer: next to the function.

## Exercises

**7.1.** Take a simple function you've already written —
from earlier chapters or new — and write three tests for
it: one with a typical case, one with an edge case, and one
with an invalid input (if the type allows). Run `kai test`
and verify all three pass.

**7.2.** Write `fn is_sorted(xs: [Int]) : Bool` returning
`true` if the list is sorted ascending. Then write a `check`
that verifies `is_sorted(list.sort(xs))` for any `xs :
[Int]`. What if your `is_sorted` has a bug — say, accepts
lists with one "skipped" element? The runner should give
you a counterexample.

**7.3.** Go back to the §7.6 evaluator. Add a new
constructor `Sub(Expr, Expr)` to `Expr` and the
corresponding branch in `eval`. What tests break? Which
tests should you add to cover the new case? Is there any
**new property** worth writing as a `check` (e.g.,
`Sub(Lit(a), Lit(0)) == Lit(a)`)?

**7.4.** For an operation of your choice, write two
implementations: a "naive" one and an "optimized" one.
Write a `bench` for each. How many times faster is the
optimized one? Does the difference justify the added
complexity?

**7.5.** Look closely at this innocent-looking `check`:

```kai
check "concatenating lists preserves length" with xs: [Int], ys: [Int] {
  list.length(list.concat([xs, ys])) == list.length(xs) + list.length(ys)
}
```

What property does it express? Why is it trivial but
useful? What should happen if someone (you, in six months,
in a hurry) "optimizes" `list.concat` and breaks the
property? Write the check, run it, then mentally try to
break `list.concat` — at which iteration do you think the
counterexample would appear?
