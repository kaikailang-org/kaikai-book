# Chapter 11 · Programming by contract and refinement types

This chapter closes Part II and the thread "information in the
type, zero cost at runtime" that units of measure opened in
chapter 10. Two mechanisms from Eiffel (1986) and Ada 2012
finish it: **contracts** — preconditions and postconditions in a
function's signature — and **refinement types** — restrictions
on the values a type accepts.

These are forty-year-old ideas, and I still think the industry
paid them far less attention than they deserved.

Both share one idea: **state restrictions in the type, have
the compiler verify them where it can, and defer them to
runtime where it can't**. They differ in scope: contracts speak
about **operations** (what a function expects and guarantees);
refinements, about **values** (which numbers or strings are
valid). They complement each other.

## 11.1 Why contracts and refinements go together

Say you're modeling a bank account. The natural rule is "the
balance can never be negative", and you can express it two
ways:

- **In the value**: declare `type ValidBalance = Int where
  self >= 0`. Any value of type `ValidBalance` satisfies the
  rule by construction; the compiler rejects any negative.
- **In the operation**: declare `fn withdraw(c: Account,
  amount: Int) : Account requires c.balance >= amount
  ensures result.balance >= 0`. The function demands a
  condition on the arguments and promises one on the result.

Both say the same thing, and each is incomplete without the
other. Refinements describe **which values are legal**;
contracts, **what operations do with those values**. A robust
bank account uses both: a balance refined to non-negative, and
operations whose preconditions keep the rule.

kaikai treats them as a single project. The language doc
(`refinements-and-contracts.md`) says:

> Together they form a single coherent mechanism — types
> describe what values are valid, contracts describe what
> operations guarantee — and the two share most of the
> implementation machinery.

That's why they live in the same chapter.

## 11.2 `requires` and `ensures` in a signature

A contract is written as annotations on the signature of a
function, between the return type and the body:

```kai
fn divide(a: Int, b: Int) : Int
  requires b != 0
  ensures  result * b + (a % b) == a
= a / b
```

Both body spellings take contracts. When the body is braced,
the clauses are written the same way and the brace opens after
them:

```kai
fn withdraw(balance: Int, amount: Int) : Int
  requires amount > 0
  requires balance >= amount
  ensures  result == balance - amount
{
  let remaining = balance - amount
  remaining
}
```

Three components:

- **`requires <expr>`** — a **precondition**. The expression
  must be `true` when **entering** the function. If violated,
  the bug is the caller's.
- **`ensures <expr>`** — a **postcondition**. The expression
  must be `true` when **exiting** the function. If violated,
  the bug is in the body.
- **`result`** — a reserved name inside `ensures` that
  refers to the return value.

A function can have multiple `requires` and multiple
`ensures`. The compiler accumulates them:

```kai
fn withdraw(c: Account, amount: Int) : Account
  requires amount > 0
  requires c.balance >= amount
  ensures  result.balance == c.balance - amount
=
  Account { ...c, balance: c.balance - amount }
```

Two preconditions (positive amount, sufficient balance), one
postcondition (the resulting account has exactly `c.balance -
amount`). Preconditions are verified in order on entry; the
postcondition on exit.

Three details:

- **`requires` and `ensures` are code**: the compiler emits
  them as actual checks. If a precondition is violated at
  runtime, the program aborts with a message that includes the
  value that broke the contract and a hint on how to rule it
  out:

  ```
  panic: requires violated in `divide`
  required: b != 0
  declared at line 2, col 14
    = help: narrow `b` to `Int where != 0`
  argument b was: 0
  ```

  The `argument b was:` line shows you the offending value
  without reproducing the case, and `help: narrow` points at
  the refinement that would have turned this runtime abort
  into a compile-time error.

- **The compiler proves statically what it can**. Call
  `divide(10, 0)` with literals and it sees `b == 0` and
  rejects the call at compile time. With dynamic values, it
  inserts the assert.

- **Contracts are checked in `--release` too**. The optimized
  build does not switch them off: a `requires` that depends on
  run-time values is still checked there. Nobody proved that
  invariant, and dropping it would trade a guarantee for one
  `if`.

## 11.3 `result` and names in scope inside `ensures`

Inside a postcondition you have:

- **`result`** — the return value.
- **The names of the parameters** — their input values.
- **Any pure function** the module provides.

This lets you write relations between input and output:

```kai
fn duplicate(n: Int) : Int
  ensures result == n * 2
= n + n

fn sort(xs: [Int]) : [Int]
  ensures list.length(result) == list.length(xs)
= ...
```

The first says "the output is twice the input"; the second,
"the resulting list has the same length as the input" — a
reasonable invariant of any sort. Notice it does **not** say
`result` is sorted. Postconditions document what's worth documenting;
they don't have to be exhaustive.

Unlike Eiffel, **there is no `old`**. In Eiffel you need
`ensures balance = old balance + amount` because records are
mutable and the `balance` you see in `ensures` has already
changed. In kaikai records are immutable: the `c` that comes
in and the `result` that comes out are **distinct values**,
both in scope, so there's no "value before the call" to name.

Both clauses in signatures that run, with `result` naming the
return value:

```kai
# examples/ch11/01_basic_contracts.kai
fn divide(a: Int, b: Int) : Int
  requires b != 0
  ensures result * b + a % b == a
= a / b

fn factorial(n: Int) : Int
  requires n >= 0
= if n <= 1 { 1 } else { n * factorial(n - 1) }

fn main() {
  println("10 / 3 = #{divide(10, 3)}")
  println("17 / 5 = #{divide(17, 5)}")
  println("5! = #{factorial(5)}")
  println("10! = #{factorial(10)}")
}
```

```
$ kai run examples/ch11/01_basic_contracts.kai
10 / 3 = 3
17 / 5 = 3
5! = 120
10! = 3628800
```

## 11.4 Refinement types

**Refinement types** speak about values. A refinement type is
a base type plus a predicate:

```kai
type NonNeg = Int where self >= 0
type Probability = Real where self >= 0.0 and self <= 1.0
type Age = Int where self >= 0 and self <= 130
type Port = Int where self >= 1 and self <= 65535
```

The predicate refers to `self` — the value being restricted.
Any value of type `NonNeg` satisfies `self >= 0` by
construction; any `Probability` falls in the unit interval;
any `Port` is within TCP range.

To build a value of the refined type, the predicate must hold.
With a literal, the compiler verifies it at compile time:

```kai
let x: NonNeg = 16        # OK: 16 >= 0
let y: NonNeg = -5     # ERROR: -5 doesn't satisfy self >= 0
```

With a dynamic value, it inserts a runtime check — same as a
`requires` whose argument can't be deduced statically.

Two refinements declared and used, with the two lines the
compiler rejects commented out at the end:

```kai
# examples/ch11/04_refinements.kai
type NonNeg = Int where self >= 0

type Probability = Real where self >= 0.0 and self <= 1.0

fn double(n: NonNeg) : NonNeg = n + n

fn event(p: Probability, description: String) : Unit / Stdout =
  println("#{description} with prob #{p}")

fn main() {
  let x: NonNeg = 16
  println("double(16) = #{double(x)}")

  let pr: Probability = 0.3
  event(pr, "rain tomorrow")

  # The next line does NOT compile: -5 doesn't satisfy NonNeg.
  # let y : NonNeg = -5

  # Nor this: 1.5 doesn't satisfy 0.0 <= self <= 1.0.
  # let pr2 : Probability = 1.5
}
```

```
$ kai run examples/ch11/04_refinements.kai
double(16) = 32
rain tomorrow with prob 0.3
```

### Where it's checked: not just in a `let`

The `let` is the easy case to see, but the check goes wherever
a value **enters** a refined type: a record field, a
constructor payload, a list element, a `var`. Each is a
construction, and each is checked.

```kai
type Service = { name: String, port: Port }

let s = Service { name: "http", port: 0 }
```

```
error: record field 'port': literal 0 violates `self >= 1 and self <= 65535`
```

With a refuting literal, it doesn't compile. With a value the
compiler can't decide, the check drops to runtime and the
program aborts showing the predicate:

```
panic: refinement violated in `main`
predicate: self >= 1 and self <= 65535
```

This matters more than it looks: you can't smuggle an invalid
value in by tucking it inside a structure. The refinement's
boundary is the type, anywhere it shows up.

### A refinement doesn't walk into a generic on its own

Know this limit before you hit it: an `[Int]` doesn't become a
`[Port]` by itself:

```kai
fn open_all(ps: [Port]) : Int = length(ps)

let raw: [Int] = [80, 443]
open_all(raw)                   # ERROR
```

```
error: argument 1 of `open_all`: `[Int]` does not narrow to
`[Int where self >= 1 and self <= 65535]`: inside a generic type
nothing checks `self >= 1 and self <= 65535`; map the value
through a function that checks it
```

The error says why: inside `[t]` there's nowhere to put the
check. Verifying the whole list would be a cost you didn't ask
for; letting it through unchecked would be a lie. So you make
it explicit: run the elements through a function returning
`Port`, and each one pays for its own guarantee on the way in.

With a mutable type the rule is stricter still, and it cuts
both ways:

```
error: argument 1 of `zero`: `Array[Int where self >= 1 and self
<= 65535]` does not fit `Array[Int]`: a mutable type keeps its
refinements exactly
```

It has to be that way: if an `Array[Port]` could pass as an
`Array[Int]`, whoever received it could write a zero into it
and break the refinement behind the owner's back.

Functions that accept refined types **get the guarantee
without checking it**. If your signature says `n: NonNeg`,
inside you assume `n >= 0` without writing an `if` — what
`requires n >= 0` does, but encoded in the type.

When to use which:

- **Refinement type** when the restriction **defines what
  is a valid value** of the domain. `Age`, `Probability`,
  `Port`: the type makes no sense outside the restriction.
- **Contract** when the restriction is **about the
  operation**. "Don't divide by zero" is
  about the divisor; "the amount to withdraw must be
  positive" is about the withdraw operation; "the resulting
  list preserves length" is about the function's behavior.

When both apply, you choose for readability. The bank account
in §11.7 uses contracts because "the balance can't be left
negative" is a property of **the operations' behavior**.

## 11.5 When proved statically, when at runtime

kaikai treats contracts and refinements as a **continuum
between static and dynamic**, decided by what the compiler
can demonstrate. Three levels:

**Compile time, fully proved.** When arguments are literals
or the compiler knows their ranges:

```kai
divide(10, 0)              # compile ERROR: 0 != 0 is false
let x: NonNeg = -5     # compile ERROR: -5 < 0
```

The program doesn't even produce a binary: the strongest
guarantee you can ask for.

**Compile time, partially proved.** When ranges can be
inferred via bounded analysis, kaikai proves what it safely can
without an SMT solver. The scope is limited:
literal-comparators over `Int`, `Bool`. If the predicate
crosses complex arithmetic or functions the compiler can't
inspect, it's deferred.

**Runtime.** When none of that decides, the compiler emits an
assert. The program compiles and the check runs with the
function; if it fails, it aborts with
`panic: requires violated`.

What kaikai **doesn't do**, deliberately, is **invoke an SMT
solver like Z3 or CVC5** to prove arbitrarily complex
contracts. That's the boundary with SPARK (the verifiable
subset of Ada). kaikai prefers a small interval evaluator,
decidable, linear — deferring the rest to runtime — over
unpredictable compilation and heavy external dependencies.

Mental rule: **what the compiler can prove cheaply, it
proves; the rest is checked at runtime**. You don't need to
know which case applied.

In this program the commented line doesn't compile because the
zero is a literal; the one left standing compiles and aborts
when it reaches a zero by arithmetic.

```kai
# examples/ch11/02_violation.kai
fn divide(a: Int, b: Int) : Int
  requires b != 0
= a / b

fn main() {
  println("before")
  # This does NOT compile — the compiler detects b == 0 with literal:
  # let bad = divide(10, 0)

  # But this does compile, and aborts at runtime:
  let dynamic_zero = 10 - 10
  let r = divide(10, dynamic_zero)
  println("we never get here: #{r}")
}
```

```
$ kai run examples/ch11/02_violation.kai
before
panic: requires violated in `divide`
required: b != 0
declared at line 9, col 14
  = help: narrow `b` to `Int where != 0`
argument b was: 0
```

## 11.6 Three forms of guarantee

You now have three mechanisms for "guaranteeing the code does
the right thing", spread across three chapters:

| Mechanism | Ch. | What it guarantees | When verified |
|---|---|---|---|
| **`test`** | 7 | For a specific input, the output is this | Under `kai test` |
| **`check`** | 7 | For **every** input, this invariant holds | Under `kai check`, with generated values |
| **Sum types + `match`** | 5 | Cover every possible case of the type | Compile time |
| **Contracts + refinements** | 11 | Restrictions on input/output and valid values | Compile time when possible, runtime when not |

The four overlap in part. A well-written function probably
uses all of them:

- **Types** as narrow as possible for the domain (sum
  types, refinements, units of measure).
- **Contracts** documenting what the function demands and
  guarantees, in relational terms.
- **Tests** covering the specific contractual cases the
  client asks for.
- **Checks** verifying algebraic invariants ("inverting
  twice is identity", "sorting preserves length").

Each catches a distinct class of bugs, and together they catch
far more than any one alone. All four have zero
runtime cost when they don't fail: a passing `test` doesn't
run in production; a contract that proves statically
generates no assert; a legal refinement generates no dynamic
check.

## 11.7 The Design by Contract family

Contracts have a history, and kaikai has a place in it.

**Eiffel (Bertrand Meyer, 1986)** introduced the term
"Design by Contract" and most of the ideas:
`require`/`ensure` over methods, class invariants,
inheritance with weakening preconditions and strengthening
postconditions. The canonical syntax lives inside the body:

```eiffel
deposit (amount: REAL)
  require
    positive_amount: amount > 0
  do
    balance := balance + amount
  ensure
    balance_increased: balance = old balance + amount
end
```

kaikai takes the idea, but puts contracts in the **signature**
and drops `old` because records are immutable.

**Ada 2012** added "aspect specifications" with the syntax
`with Pre =>`, `with Post =>` — the closest to kaikai in style:

```ada
function Divide (A, B : Integer) return Integer
  with Pre  => B /= 0,
       Post => Divide'Result * B = A;
```

Ada's `with Pre => / Post =>` and kaikai's `requires /
ensures` are the same annotational idea. Ada also introduced
**subtypes with predicates** (`subtype Positive is Integer
range 1 .. Integer'Last`), which are direct ancestors of
kaikai's refinement types.

**SPARK**, the verifiable subset of Ada, uses an SMT solver to
prove arbitrary contracts statically. kaikai **leaves it out on
purpose**: SPARK requires installing Z3 or similar, and compile
times become unpredictable. The language doc
(`refinements-and-contracts.md`) says so: the interval evaluator is a few hundred lines
max, decidable, linear; what doesn't fit there is deferred
to runtime without remorse.

**D** has contracts similar to kaikai with the syntax `in {
... } / out (result) { ... }`. **Cobra**, **Kotlin** (with
`require/check`), **Clojure** (with `:pre/:post`) are other
lighter-weight versions of the same idea.

What **distinguishes** kaikai in this family:

1. **No SMT**. The SPARK line is out of bounds. The
   consequence is that complex contracts are checked at
   runtime; the benefit is fast compilation and no external
   dependencies.

2. **Purity by default**. Eiffel and Ada deal with rampant
   mutability; their contracts handle `old` and aliasing.
   kaikai starts from immutability: the postcondition speaks
   about the input and the output as two values that
   coexist.

3. **Continuity with the rest of the type system**.
   Contracts and refinements are the **third leg** of
   "information in the type, zero cost at runtime", together
   with algebraic effects and units of measure. All three
   use the same pattern: declare in the signature or the
   type, check statically when possible, runtime when
   needed. Eiffel and Ada don't have algebraic effects or
   UoM, so their contracts live more alone.

## 11.8 What kaikai doesn't do, and why

Here's what I decided **not** to support:

- **No SMT solving**. If your contract is `ensures
  result.entries == sort(c.entries)`, kaikai won't prove
  statically that your body sorts the list; it checks it at
  runtime.
- **No arbitrary refinements over complex structures**.
  `Real where 0.0 <= self <= 1.0` is legal. `[Int] where
  list.length(self) > 0` is not: direct refinements are scoped
  to predicates over scalars. The restriction is expressed with
  a sum type (`type NonEmptyList = ...`) or a wrapper.
- **No contract inheritance** in Eiffel style. kaikai has no
  classes or inheritance; contracts live in each individual
  function's signature.

The argument is the whole language's: **simplicity and
predictability**. A type system that invokes a solver is opaque
— you don't know why your program compiles or doesn't, and
error messages become unintelligible. A bounded system that
proves the obvious and defers the rest gives weaker guarantees
but **understandable ones**, with runtime checks catching what
static analysis couldn't.

## 11.9 Case study: bank account

We close with a minimal bank account where contracts
document and ensure behavior.

```kai
type Account = {
  holder: String,
  balance: Int,
}

fn open(holder: String, initial_deposit: Int) : Account
  requires initial_deposit >= 0
  ensures  result.balance == initial_deposit
=
  Account { holder: holder, balance: initial_deposit }

fn deposit(c: Account, amount: Int) : Account
  requires amount > 0
  ensures  result.balance == c.balance + amount
=
  Account { ...c, balance: c.balance + amount }

fn withdraw(c: Account, amount: Int) : Account
  requires amount > 0
  requires c.balance >= amount
  ensures  result.balance == c.balance - amount
=
  Account { ...c, balance: c.balance - amount }
```

Three operations, five preconditions, three postconditions.
In plain words:

- **`open`** opens an account with non-negative initial
  balance. The postcondition confirms the new account's
  balance is exactly what was deposited.
- **`deposit`** demands a positive amount and promises the
  final balance is the initial plus the amount.
- **`withdraw`** demands positive amount and sufficient
  balance, and promises the final balance is initial minus
  amount.

What if someone — you, in six months, in a hurry — writes
`withdraw(account, -50)`? The program does not compile. The call sits commented out at the end
of `examples/ch11/03_bank_account.kai`; uncomment it and the
compiler answers:

```
examples/ch11/03_bank_account.kai:44:17: error: call to `withdraw`: literal args violate `amount > 0`
```

The argument is a constant, so the compiler evaluates it
against the `requires`. When the negative amount comes from
outside — a form, a file — the contract is checked on entry
and the program aborts pointing at the exact `requires` line. No failing silently, no inconsistent
balance carried along.

And if someone accidentally changes `c.balance - amount` to
`c.balance + amount` in `withdraw`'s body, the
`ensures result.balance == c.balance - amount` fails on exit
and aborts too. The postcondition is your insurance
against internal bugs, just as `requires` is your insurance
against caller misuse.

With four lines of contracts, this account documents its
rules, verifies them when running, and leaves a clear
diagnostic when they break. Compare the contractless version:

```kai
fn withdraw(c: Account, amount: Int) : Account =
  Account { ...c, balance: c.balance - amount }
```

It works in the happy case. But a caller passing a negative
ends up with an account whose balance grew (because
`c.balance - (-50) == c.balance + 50`), and one withdrawing
more than the balance leaves it negative. Nobody finds out.
The bugs that are immediate aborts with contracts become
silently wrong balances in production without them.

## Exercises

**11.1.** Define `type Age = Int where self >= 0 and self
<= 130`. Write `fn average_ages(a: Age, b: Age) : Age`. On
which line does the verification appear when you build an
`Age` from a dynamic value?

**11.2.** Take the `divide` function from §11.2. Add a
postcondition ensuring that when `b > 0` and `a > 0`, the
result is non-negative. How does the postcondition look?
What happens if your body had a bug returning a negative
in some case?

**11.3.** Rewrite the bank account from §11.9 using a
**refinement type** for the balance (`type ValidBalance =
Int where self >= 0`), and `Account = { holder: String,
balance: ValidBalance }`. Which preconditions and
postconditions become redundant with this change? What
information does the signature lose?

**11.4.** Imagine a function `fn percentile(p: Probability,
xs: [Real]) : Real`. What preconditions would you add over
`xs`? What postconditions document correct behavior? Which
of the two forms (refinement type or contract) would you
use for each restriction?

**11.5.** Read `docs/refinements-and-contracts.md` from the
kaikai repo. Identify a restriction the doc mentions as
"post-MVP". Discuss with a colleague or with an AI agent
what consequences implementing it would have — what new
class of errors it would catch, what class of programs
would become more loaded with checks.
