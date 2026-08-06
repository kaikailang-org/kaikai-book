# Chapter 3 · Basic types and expressions

Time to get to the primitives. This chapter covers kaikai's seven
basic types, the shape of literals, the operators that handle
them, and how values bind to names with `let`. It also pins down
something you've already seen in passing: **`if` and blocks are
expressions**, not statements.

If you read chapter 2, what follows is the concrete content of
those warnings. If you skipped it and you come from an imperative
background, go back. It will save you friction.

## 3.1 The seven primitive types

Day-to-day kaikai rests on seven basic types:

| Type | What it's for | Example literal |
|---|---|---|
| `Int` | Signed 64-bit integers | `42`, `-7`, `1_000_000` |
| `Real` | Double-precision IEEE 754 floats | `3.14`, `-0.5`, `1e10` |
| `Bool` | True / false | `true`, `false` |
| `String` | Unicode text | `"hello"`, `"α + β"` |
| `Char` | One Unicode character | `'a'`, `'\n'`, `'\u{2603}'` |
| `Unit` | The type with one value | `()` |
| `Nothing` | The empty type, no inhabitants | (no literal) |

The first five are what you'd expect from any language. The last
two deserve a word.

`Unit` is the type of the value `()`. It has a single inhabitant.
It's what a function returns when it "doesn't return anything
useful": the equivalent of C's `void`, but it's a real type with
a real value, one you can pass as an argument or store in a
variable. `println(...)` returns `Unit`. A block that ends
without an explicit value returns `Unit`.

`Nothing` is the opposite. **Zero inhabitants.** No expression
produces a `Nothing` the program can use. So what is it for?
For describing the return type of things that **never finish
normally**: a `panic(...)` that aborts the process, an infinite
loop, a `forever` whose body cannot exit. A function
`fn endless_loop() : Nothing` tells the type system that any
code after calling it is unreachable, which is why an expression
of type `Nothing` fits any context where another type is
expected. You'll bump into `Nothing` rarely, but it helps to
know the name.

These seven aren't the language's only numbers — there are
fixed-width integers and arbitrary-precision types, covered in
section 3.4 — but they are what you'll be typing 95% of the
time.

## 3.2 Literals and string interpolation

Numeric literals accept underscores as visual separators:

```kai
let population = 19_000_000
let pi         = 3.141_592
let scale      = 1e6
```

`String` values use double quotes. The day-to-day shape is
**interpolation**:

```kai
let name = "kaikai"
let age  = 1
println("Hello, #{name}. The language is #{age} year old.")
```

Output:

```
Hello, kaikai. The language is 1 year old.
```

Any expression fits inside `#{...}`, not just names. Its value
is converted to `String` automatically:

```kai
let a = 7
let b = 2
println("The sum of #{a} and #{b} is #{a + b}.")
```

To concatenate without interpolation, use `++`:

```kai
let greeting = "Hello, " ++ name
```

The operator is `++`, not `+`, to avoid confusing it with
addition. It's a small detail that prevents a classic bug.

For multi-line content, kaikai has **triple-quoted strings**:

```kai
let message = """
  This is a multi-line
  message that preserves indentation
  relative to the closing fence.
  """
```

Each line's indentation is measured against the closing `"""`,
so you can format the string visually without dragging extra
spaces into the output. Escape sequences (`\n`, `\t`,
`\u{HHHH}`, etc.) work the same as in regular strings.

`Char` values use single quotes: `'a'`, `'\n'`, `'\u{2603}'`. A
`Char` is not a `String` of length one — they are distinct
types. That avoids a class of bugs typical of languages that
conflate the two.

## 3.3 Arithmetic, logical and comparison operators

The arithmetic operators:

```
+   addition              (Int or Real)
-   subtraction / negate  (Int or Real)
*   product               (Int or Real)
/   division              (Int or Real)
%   remainder             (Int or Real)
```

The five are **overloaded by type**: they work with both `Int`
and `Real`, and the result has the same type as the operands.
What does **not** exist is implicit coercion between `Int` and
`Real`: you cannot mix them in the same expression. If you
need to, you convert explicitly with `int_to_real(...)` or
`real_to_int(...)`.

The detail worth pinning down: `/` with two `Int`s already
truncates the remainder. To get a quotient with a fractional
part, both operands have to be `Real`.

```kai
let a : Int = 7
let b : Int = 2
println("a / b = #{a / b}")     # 3 — on Int, / truncates

let x : Real = 7.0
let y : Real = 2.0
println("x / y = #{x / y}")     # 3.5 — on Real, fractional
                                #       part is preserved
```

If you come from Python 3 there's a habit change. Over there,
`/` always returns float; in kaikai the type rules: `Int / Int`
is `Int`, and if you want the fractional part you convert
explicitly or work with `Real` from the start.

Negatives bring a second habit change, a sneakier one because
nothing errors out: **`/` truncates toward zero, and the
remainder from `%` carries the sign of the dividend.**

```kai
println("#{-17 / 5}")      # -3, not -4
println("#{-17 % 5}")      # -2, not 3
println("#{17 % -5}")      #  2 — the 17 sets the sign
```

Python decides the other way — it floors, so `-17 // 5` is
`-4` and `-17 % 5` is `3`. If you come from C, Go, Java or
Rust, kaikai does what you already expected. The identity that
holds in every case is `(a / b) * b + a % b == a`.

The practical consequence: if you use `%` to test for
evenness, to wrap an index into a ring buffer, or to bucket
values, and the input can go negative, you'll get a negative
remainder back. `x % 2 == 1` is false for every negative odd
`x`; the question you meant to ask is `x % 2 != 0`.

Logical operators are words, not symbols:

```
and   or   not
```

```kai
if x > 0 and x < 10 { ... }
if not empty { ... }
```

Most languages you've used reach for `&&`, `||` and `!`. kaikai
went with words because they read more cleanly, and because
those symbols are reserved for other purposes (`||` is flat-map
in pipes, chapter 6).

Comparison operators are the usual ones:

```
==  !=  <  >  <=  >=
```

They return `Bool`. They work over any type that implements the
`Eq` protocol (for `==`/`!=`) and `Ord` (for the rest). We'll
see those in chapter 9; for now, every primitive type
implements them.

## 3.4 More numbers: fixed widths and arbitrary precision

`Int` and `Real` cover nearly all the code you'll write. The
rest has hard requirements: talking to C with the exact width
the ABI expects, counting past 2⁶³, or carrying quantities where
binary rounding is unacceptable. For those cases kaikai brings
two more families. You won't need them soon, but it pays to know
they exist and where each one's guarantees end.

### Fixed-width integers

Four types with an exact width: `Int32`, `UInt32`, `UInt64`, and
`Int128`. The literal names them with a suffix attached to the
digits:

```kai
let w = 42i32 + 7i32
let big : Int128 = 9223372036854775808i128   # 2⁶³: out of
                                             # Int's reach
let mask = 0xFFi32                           # the suffix works on
let bits = 0b1010u8                          # any base
```

Two rules govern them. First: **they don't mix with `Int`**. An
`Int32` does not unify with an `Int`; adding them is a type
error, just like mixing `Int` with `Real`. You convert by full
name — `int_to_int32(...)`, `int32_to_int(...)`, and the
analogues for `u32`, `u64`, and `i128`. No silent coercions here
either.

Second: **arithmetic wraps**. Adding `1i32` to `Int32`'s maximum
doesn't promote and doesn't throw: it wraps around in two's
complement, like C.

```kai
let edge = 2147483647i32 + 1i32   # -2147483648
```

The example `examples/ch03/05_fixed_width.kai` walks through
both rules:

```
$ kai run examples/ch03/05_fixed_width.kai
w = 49
edge = -2147483648
big = 9223372036854775808
n32 + 1 = 11
back = 11
```

When do you use them? Mostly at the C boundary: in an
`extern "C"` signature, an `Int32` crosses as `int32_t`, a
`UInt64` as `uint64_t` — the width you declare is the width that
travels (chapter 16). `Int128` also stands on its own: it
reaches ~38 digits where `Int` stops at ~19, with the same
arithmetic as always.

### Arbitrary precision: `BigInt`, `DecimalBig`, `Rational`

When no fixed width is enough, the stdlib offers three types
that grow as needed. They are opt-in — you import them, they
don't come preloaded — because their cost is real: heap values,
software arithmetic. kaikai charges you only when you ask.

- **`BigInt`** (`import math.bigint`): an arbitrary-precision
  integer that never overflows. The `n` suffix builds one from a
  literal: `99n`. The suffix only reaches literals that fit in
  `Int`; for larger values you start from a string with
  `bigint.from_string("…")`.
- **`DecimalBig`** (`import decimal_big`): fixed-point over
  `BigInt`, meant for exact decimal quantities. `add`, `sub`,
  and `mul` are total; `div` asks for the target scale
  explicitly, because truncating is a decision, not an accident.
  Comparing `1.5` with `1.50` yields equality: scale is not part
  of the value. Its sibling `Decimal` (`import decimal`) uses
  `Int128` as the carrier — lighter, with a ceiling near 38
  digits. It has a suffix too: `12.0d` is a `Decimal`.
- **`Rational`** (`import rational`): an exact fraction, a
  `num/den` pair over `BigInt` always reduced to lowest terms.
  `1/2 + 1/3` is exactly `5/6`, with no rounding anywhere.

These types are records with invariants — a `Rational` is always
reduced, a `Decimal` carries its scale — so you don't build them
with the raw record literal, which would skip that logic. The
short form is the **positional constructor**: a type marked with
the `#[constructor]` attribute lets `Type(args)` call the
function that actually builds it. `Rational(1, 2)` is
`rational.make(1, 2)`, reduction included; `Complex(1.5, 2.0)` is
`complex.mk(...)`. It's sugar, not magic: the arity must match
the marked function — `Rational(5)`, with a single argument,
doesn't exist (that's what `rational.from_int(5)` is for).

The example `examples/ch03/06_big_numbers.kai` shows all three
in action:

```
$ kai run examples/ch03/06_big_numbers.kai
a² = 1000000014000000049
d × 2 = 246913578024691357802469135780.246913578
1/2 + 1/3 = 5/6
```

If you come from Python, `BigInt` is what they simply call `int`
over there: the difference is that in kaikai the 64-bit integer
is the common, fast case, and arbitrary precision is the
exception you ask for by name. And if your problem is money, the
full answer combines these types with the units of measure of
chapter 10 — exact decimals supply the arithmetic; units, the
discipline of not adding pesos to dollars.

## 3.5 `let` and local type propagation

`let` binds a name to a value. The type is inferred from the
right-hand side:

```kai
let x = 42                # x : Int
let y = 3.14              # y : Real
let name = "kaikai"       # name : String
```

If you want the type explicit, annotate with `:`:

```kai
let x : Int  = 42
let y : Real = 3.14
```

The annotation is more than decoration. It's there for two
reasons: to document intent when the type isn't obvious, and
to guide the type inferrer in the few cases where local
inference isn't enough. The practical rule is **annotate the arguments
and return type of public functions, and leave local `let`s
unannotated**. Types travel through the signatures and the
body stays clean.

Once a name is bound, you can't bind the same name again in
the same block. The next line would error:

```kai
let x = 42
let x = 7        # error: name already defined in this scope
```

What you *can* do is bind the same name **in an inner scope**,
which produces *shadowing* — the local name hides the outer
one:

```kai
let x = 42
{
  let x = 7      # OK: shadowing inside the block
  println("#{x}")    # 7
}
println("#{x}")      # 42 — the outer one was untouched
```

This is orthogonal to mutation. You're not "changing `x`":
you're introducing a different `x` in a nested scope, which
ceases to exist when the scope closes. The outer one was never
touched.

For the cases where you need a real mutable cell, kaikai gives
you `var`: `name := v` declares and writes, and a bare name
reads. You saw this in §2.2 and we'll come back to it in
chapter 12 when we talk about effects.

## 3.6 `if` as an expression

An `if` in kaikai produces a value:

```kai
let s = if x > 0 { "positive" } else { "non-positive" }
```

Both branches must produce values of the same type, and that's
the type of the `if`. The syntax has no `then`, no parentheses
around the condition, and each branch is a block.

If the condition has multiple branches, they chain with
`else if`:

```kai
fn sign(n: Int) : String =
  if n < 0 { "negative" }
  else if n == 0 { "zero" }
  else { "positive" }
```

Each brace opens a block whose value is the result of the
branch. The whole function is a single expression, bound to the
signature with `=`. There's no `return`.

A variant worth pinning down: **an `if` without `else` always
has type `Unit`**. The compiler does not synthesize a value for
the missing branch; it makes the simplest possible call and
says "the type of the `if` is `Unit`, and if the condition is
false, the value is `()`".

So the usual shape of an `if` without `else` is a body that
runs for its side effect:

```kai
if i <= n {
  println(label(classify(i)))
  loop(i + 1, n)
}
```

It's the standard "do something or stop". And if the `then`
branch happens to produce a value of a different type, that
value **is silently discarded** — the `if` is still `Unit`:

```kai
if x > 0 {
  x + 1     # an Int, but thrown away
}
```

This compiles, produces no warning, and is rarely what you
intended. The error usually shows up a little later, when you
try to use the result of the `if`:

```kai
let r = if x > 0 { 42 }
println(int_to_string(r))   # error: r is Unit, not Int
```

The practical rule is simple: if **you care about the value**,
write a full `if/else`; if **you care about the side effect**,
write a bare `if` and don't bind it to anything.

## 3.7 Blocks and the value of a block

A block `{ ... }` is an **expression** whose value is the value
of the last expression inside. The earlier lines run in order,
and their values are discarded — except where you bind them
with `let`.

```kai
fn square_plus_one(x: Int) : Int = {
  let square = x * x
  square + 1
}
```

`square` is a local binding. The last line, `square + 1`, is
the return expression. There's no `return`; the block's value
is the function's value.

This composes with everything else: an `if` branch can be a
block, a `match` arm can be a block, a lambda body can be a
block. The whole language reduces to expressions returning
values.

## 3.8 The difference between `=` and `{ ... }` in a function body

A function body can take two shapes. You saw this in chapter
1; we pin it down here.

Short form, with `=` and a single expression:

```kai
fn double(x: Int) : Int = x * 2

fn sign(n: Int) : String =
  if n < 0 { "negative" }
  else if n == 0 { "zero" }
  else { "positive" }
```

Long form, with `{ ... }`:

```kai
fn square_plus_one(x: Int) : Int = {
  let square = x * x
  square + 1
}
```

The compiler accepts both. The difference is for the reader:

- **Short form** when the function is a direct expression with
  no intermediate steps. Reads like a mathematical definition.
- **Long form** when there are intermediate bindings or several
  steps that benefit from visual separation.

There's no "preferred" form: pick whichever communicates intent
better for that particular function. The usual rule of thumb is
that one-line functions go with `=`, and the ones that need to
breathe go with `{ ... }`.

## Exercises

**3.1.** Write a function `fn fahrenheit_to_celsius(f: Real) :
Real` using only what's in this chapter. Verify that
`fahrenheit_to_celsius(32.0)` gives `0.0` and that
`fahrenheit_to_celsius(212.0)` gives `100.0`. Use `=` and a
single expression.

**3.2.** Write `fn is_even(n: Int) : Bool` and
`fn parity(n: Int) : String`, where `parity` returns `"even"`
or `"odd"`. The second function should use the first, not
duplicate the logic.

**3.3.** Given the function:

```kai
fn total_price(units: Int, unit_price: Int) : Int = {
  let subtotal = units * unit_price
  let tax = subtotal * 19 / 100
  subtotal + tax
}
```

What does `total_price(3, 100)` print? Modify the function so
the tax is computed correctly as a real-valued percentage (with
fractional part), not as an integer. Which types do you change?

**3.4.** Write `fn maximum(a: Int, b: Int, c: Int) : Int` that
returns the largest of the three arguments, using `if` as an
expression and without `match` or stdlib helpers. How many
`else if`s do you need?

**3.5.** Read the documentation for `++` and figure out what
happens if you write `"hello, " ++ 42`. Does it compile? If
not, how do you fix it? Reason about it before testing.
