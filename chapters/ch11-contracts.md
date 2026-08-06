# Chapter 11 · Programming by contract and refinement types

This chapter closes Part II and completes the thread
"information in the type, zero cost at runtime" opened by units
of measure (chapter 10) and finished here by two mechanisms that
come from Eiffel (1986) and Ada 2012: **contracts** —
preconditions and postconditions that live in a function's
signature — and **refinement types** — restrictions on the
values a type accepts.

The two mechanisms share the same idea: **state restrictions
in the type, have the compiler verify them where it can, and
defer them to runtime where it can't**. Where they differ is
in scope: contracts speak about **operations** (what a
function expects and guarantees); refinements speak about
**values** (which numbers or strings are valid). The two
cover distinct areas and complement each other.

## 11.1 Why contracts and refinements go together

Imagine you want to model a bank account. The natural rule
is "the balance can never be negative". There are two ways
to express it:

- **In the value**: declare `type ValidBalance = Int where
  self >= 0`. Any value of type `ValidBalance` satisfies the
  rule by construction. The compiler rejects any attempt to
  put a negative.
- **In the operation**: declare `fn withdraw(c: Account,
  amount: Int) : Account requires c.balance >= amount
  ensures result.balance >= 0`. The function demands a
  condition on the arguments and promises one on the result.

Both forms say the same and one without the other is
incomplete. Refinements describe **which values are legal**;
contracts describe **what operations do with those values**.
A robust bank account uses both: balance refined to
non-negative, operations with preconditions ensuring the rule
holds.

kaikai treats both as a single project. The language doc
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
  must be `true` when **entering** the function. The caller
  is responsible. If violated, the bug is the caller's.
- **`ensures <expr>`** — a **postcondition**. The expression
  must be `true` when **exiting** the function. Your body is
  responsible. If violated, the bug is internal.
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

Three details worth pinning down:

- **`requires` and `ensures` are not comments**. They are
  code the compiler emits as actual verifications. If a
  precondition is violated at runtime, the program aborts
  with a clear message — including the value that broke the
  contract and a hint on how to rule it out:

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

- **The compiler proves statically what it can**. If you
  call `divide(10, 0)` with literals, the compiler sees `b
  == 0` and rejects the call at compile time — no waiting
  for runtime. If you call with dynamic values, it inserts
  the assert.

- **Contracts don't run in release builds**, depending on a
  compiler flag. In that mode, `requires` and `ensures`
  vanish from the binary; cost is zero. For development and
  tests, contracts are evaluated.

## 11.3 `result` and names in scope inside `ensures`

Inside a postcondition you have access to:

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

The first says "the output is twice the input". The second
says "the resulting list has the same length as the input"
— a reasonable invariant of any sort. Note we're **not**
saying that `result` is sorted — only that it preserves
length. Postconditions document what's worth documenting;
they don't have to be exhaustive.

Unlike Eiffel, **there is no `old`**. In Eiffel you need
`ensures balance = old balance + amount` because records are
mutable and the `balance` you see in `ensures` has already
changed. In kaikai records are immutable: the `c` that comes
in and the `result` that comes out are **distinct values**,
both in scope, no need for a "value before the call"
mechanism.

## 11.4 Refinement types

While contracts speak about operations, **refinement types**
speak about values. A refinement type is a base type plus a
predicate:

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

Building a value of the refined type requires the predicate
to hold. If you satisfy it with a literal, the compiler
verifies at compile time:

```kai
let x : NonNeg = 16        # OK: 16 >= 0
let y : NonNeg = 0 - 5     # ERROR: -5 doesn't satisfy self >= 0
```

If you satisfy it with a dynamic value, the compiler inserts
a runtime check — same as a `requires` whose argument can't
be deduced statically.

Functions that accept refined types **benefit from the
guarantee without checking it**. If your signature says `n:
NonNeg`, inside you can assume `n >= 0` without writing an
`if`. That's exactly what a contract `requires n >= 0` does,
but encoded in the type instead of the signature.

When do you use one and when the other? The simple rule:

- **Refinement type** when the restriction **defines what
  is a valid value** of the domain. `Age`, `Probability`,
  `Port` are classic examples: the type makes no sense
  outside the restriction.
- **Contract** when the restriction is **about the
  operation**, not the value. "Don't divide by zero" is
  about the divisor; "the amount to withdraw must be
  positive" is about the withdraw operation; "the resulting
  list preserves length" is about the function's behavior.

Sometimes both apply and you choose for readability. The
bank account in §11.7 uses contracts because "the balance
can't be left negative" is a property of **the operations'
behavior**, not of the balance's value.

## 11.5 When proved statically, when at runtime

kaikai treats contracts and refinements as a **continuum
between static and dynamic**, decided by what the compiler
can demonstrate. Three levels:

**Compile time, fully proved.** When arguments are literals
or the compiler knows their ranges:

```kai
divide(10, 0)              # compile ERROR: 0 != 0 is false
let x : NonNeg = 0 - 5     # compile ERROR: -5 < 0
```

The program doesn't even produce a binary. The strongest
guarantee.

**Compile time, partially proved.** When ranges can be
inferred via bounded analysis, kaikai proves what it safely can
without invoking a heavy SMT solver. The scope is limited:
literal-comparators over `Int`, `Bool`. If the predicate
crosses complex arithmetic or functions the compiler can't
inspect, it's deferred.

**Runtime.** When the above isn't decidable, the compiler
emits an assert in the generated code. The program compiles;
the check happens when executing the function. If it fails,
abort with `panic: requires violated`.

What kaikai **doesn't do**, deliberately, is **invoke an SMT
solver like Z3 or CVC5** to prove arbitrarily complex
contracts. That's the boundary with SPARK (the verifiable
subset of Ada). kaikai prefers a small interval evaluator,
decidable, linear — and deferring the rest to runtime — over
having unpredictable compilation and heavy external
dependencies.

Mental rule: **what the compiler can prove cheaply, it
proves; the rest is checked at runtime**. The binary carries
both cases without you having to distinguish which applied.

## 11.6 Three forms of guarantee

We have three mechanisms for "guaranteeing the code does the
right thing" spread across three chapters:

| Mechanism | Ch. | What it guarantees | When verified |
|---|---|---|---|
| **`test`** | 7 | For a specific input, the output is this | Under `kai test` |
| **`check`** | 7 | For **every** input, this invariant holds | Under `kai check`, with generated values |
| **Sum types + `match`** | 5 | Cover every possible case of the type | Compile time |
| **Contracts + refinements** | 11 | Restrictions on input/output and valid values | Compile time when possible, runtime when not |

The four are distinct tools with overlapping areas. A
well-written function probably uses all four:

- **Types** as narrow as possible for the domain (sum
  types, refinements, units of measure).
- **Contracts** documenting what the function demands and
  guarantees, in relational terms.
- **Tests** covering the specific contractual cases the
  client asks for.
- **Checks** verifying algebraic invariants ("inverting
  twice is identity", "sorting preserves length").

They aren't redundant: each catches a distinct class of
bugs and the four together catch a much wider range than any
of them individually. And all four have zero
runtime cost when they don't fail: a passing `test` doesn't
run in production; a contract that proves statically
generates no assert; a legal refinement generates no dynamic
check.

## 11.7 The Design by Contract family

Contracts aren't a kaikai invention. They have a history,
and it's worth placing kaikai in that history.

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

kaikai takes the idea but puts contracts in the **signature**,
not in the body, and removes `old` because records are
immutable.

**Ada 2012** added "aspect specifications" to Ada with the
syntax `with Pre =>`, `with Post =>`. This is the closest to
kaikai stylistically:

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

**SPARK** is the verifiable subset of Ada, which uses an SMT
solver to prove arbitrary contracts statically. kaikai
**doesn't adopt this on purpose**: SPARK requires installing
Z3 or similar, and compile times become unpredictable. The
language doc (`refinements-and-contracts.md`) says it
explicitly: the interval evaluator is a few hundred lines
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
   mutability; contracts have to handle `old` and aliasing.
   kaikai starts from immutability: the postcondition speaks
   about the input and the output as two values that
   coexist, no extra machinery.

3. **Continuity with the rest of the type system**.
   Contracts and refinements are the **third leg** of
   "information in the type, zero cost at runtime", together
   with algebraic effects and units of measure. All three
   use the same pattern: declare in the signature or the
   type, check statically when possible, runtime when
   needed. Eiffel and Ada don't have algebraic effects or
   UoM, so their contracts live more alone.

## 11.8 What kaikai doesn't do, and why

It's worth enumerating what kaikai **deliberately** doesn't
support:

- **No SMT solving**. If your contract is `ensures
  result.entries == sort(c.entries)`, kaikai won't prove
  statically that your body in fact sorts the list. It will
  check it at runtime.
- **No arbitrary refinements over complex structures**.
  `Real where 0.0 <= self <= 1.0` is legal. `[Int] where
  list.length(self) > 0` is not: direct refinements are scoped
  to predicates over scalars. The restriction is expressed with
  a sum type (`type NonEmptyList = ...`) or a wrapper.
- **No contract inheritance** in Eiffel style. kaikai has no
  classes or inheritance; contracts live in each individual
  function's signature.

Why these restrictions? The argument is the same as the
whole language: **simplicity and predictability**. A type
system that invokes a solver is opaque — the programmer
doesn't know why their program compiles or doesn't, and
error messages become unintelligible. A bounded system, that
proves the obvious and defers the rest, gives weaker
guarantees but **understandable ones**, and leaves the runtime
checks to catch what static analysis couldn't.

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
Human reading:

- **`open`** opens an account with non-negative initial
  balance. The postcondition confirms the new account's
  balance is exactly what was deposited.
- **`deposit`** demands the amount be positive (no
  zero-or-negative deposits) and promises the final balance
  is the initial plus the amount.
- **`withdraw`** demands positive amount and sufficient
  balance, and promises the final balance is initial minus
  amount.

What if someone — you, in six months, in a hurry —
writes `withdraw(account, 0 - 50)` (passing a negative)? The
contract `requires amount > 0` is violated and the program
aborts with a message pointing at the exact `requires` line.
Instead of failing silently or leaving an inconsistent balance,
the program aborts on entry and tells you which `requires` line
it tripped.

And if `withdraw`'s body had a bug — someone changes
`c.balance - amount` to `c.balance + amount` accidentally —
the `ensures result.balance == c.balance - amount` violates
on exit and aborts too. The postcondition is your insurance
against internal bugs, just as `requires` is your insurance
against caller misuse.

With four lines of contracts, this minimal bank account
documents its rules, verifies them when running, and leaves
a clear diagnostic when they break. Compare with the
contractless version:

```kai
fn withdraw(c: Account, amount: Int) : Account =
  Account { ...c, balance: c.balance - amount }
```

Works in the happy case. But a caller passing a negative
ends up with an account whose balance grew (because
`c.balance - (-50) == c.balance + 50`), and nobody finds
out. A caller passing more amount than balance ends up with
a negative-balance account, and nobody finds out. The bugs
that in kaikai with contracts are immediate aborts, in
kaikai without contracts are silently incorrect balances in
production.

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
