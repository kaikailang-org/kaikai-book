# Chapter 10 · Units of measure: your first kind

In 1999, NASA lost the Mars Climate Orbiter — a 327
million-dollar project — because two software modules
exchanged numerical values without agreement on units. One
produced impulse in pound-force seconds; another read it as
newton-seconds. Nobody had written units on the
interface. The probe came in too low and was lost
in the Martian atmosphere.

It's an extreme example, but the family is huge: two
components sharing the same numeric type but not the same
interpretation. Passing seconds where milliseconds are
expected. Adding balances in different currencies. Mixing a
`UserId` with an `OrderId` because both are integers. In
every case the type system sees two numbers or two strings
and has no way to tell them apart.

kaikai solves this whole family with a single construct:
**units of measure**. The idea, inherited from F#, is that
you can annotate a number with a unit (`Real<USD>`,
`Int<Seconds>`) and the compiler rejects any operation that
mixes incompatible units. The unit **lives in the type**,
**is erased at runtime**, and is documented in every
signature it touches.

If §2.6 left you with the idea that in kaikai the type is
not the only label, here that idea becomes tangible: units are
your first full-body encounter with a **kind** — a family of
labels with its own algebra, distinct from types. You've
already used another one without looking at it head-on (the
effect row); this is the first one you declare and manipulate
yourself.

You'll learn the classical units (physics, finance, time) and
their less obvious but more frequent use in day-to-day code:
**branded types**, where the unit is just a label
distinguishing types that the language would otherwise treat
as the same.

## 10.1 `unit` and annotated literals

A unit is declared by writing `unit` before a name:

```kai
unit USD
unit EUR
unit m
unit sec
unit kg
```

That's the whole declaration: `unit USD` introduces a symbol
`USD` the type system can use as an annotation. No
implementation, no runtime value — `unit` only declares that
the symbol exists.

To annotate a number with a unit, use angle brackets in the
literal:

```kai
let price: Real<USD> = 1.50<USD>
let speed: Real<m / sec> = 9.81<m / sec>
let timeout: Int<sec> = 30<sec>
```

Three things to pin down:

- **Units are written with `<...>`**, not `[...]`. Brackets
  are for type parameters (`List[Int]`, `Option[String]`);
  angle brackets are for units.
- **Both the literal and the type are annotated.**
  `1.50<USD>` is a `Real` literal with unit `USD`.
  `Real<USD>` is the type. They match, but each plays a role.
- **The compiler accepts any identifier as a unit.** By
  convention, SI units go in lowercase (`m`, `s`, `kg`),
  person-named in titlecase (`Newton`, `Pascal`), and
  currencies in uppercase per ISO 4217 (`USD`, `EUR`,
  `CLP`). These are community conventions; the compiler
  enforces none of them.

## 10.2 Arithmetic with units

Arithmetic between values of the same unit works as you'd
expect. Adding two `Real<USD>` gives another `Real<USD>`:

```kai
# examples/ch10/01_basic_units.kai
unit USD

unit EUR

fn main() {
  let price: Real<USD> = 1.50<USD>
  let tip: Real<USD> = 0.30<USD>
  let total: Real<USD> = price + tip
  println("total = #{total}")

  # Units are preserved in return types.
  let value_eur: Real<EUR> = 1.20<EUR>
  println("value_eur = #{value_eur}")

  # The next line does NOT compile — USD + EUR is a type error.
  # let mix = price + value_eur
}
```

```
$ kai run examples/ch10/01_basic_units.kai
total = 1.8 USD
value_eur = 1.2 EUR
```

But **mixing incompatible units is a compile error**. If you
try:

```kai
let mix = price + 1.20<EUR>     # type error
```

the compiler rejects it with an error saying "expected
`USD`, got `EUR`". The program never runs with mixed values;
the bug is caught before it can do anything.

The broader rule:

- **`+`, `-`** between two values of the same unit: legal,
  preserves the unit.
- **`*`, `/`** between values with units: legal, **composes
  the units**. You'll try it in §10.3.
- **`+`, `-`** between distinct units: type error.
- **Comparisons (`<`, `==`)** between distinct units: type
  error.

Arithmetic with a value without a unit and one with a unit
is asymmetric. Multiplying by a scalar (`2.0 * price`) is
legal — the scalar is treated as dimensionless. Adding a
scalar (`price + 1.0`) is an error: there's no telling what
unit the `1.0` is in.

## 10.3 Unit algebra: product, quotient, power

Multiplying two units produces a composite unit. The classic
example is force:

```kai
let mass: Real<kg> = 70.0<kg>
let acceleration: Real<m / sec^2> = 9.81<m / sec^2>
let force: Real<kg * m / sec^2> = mass * acceleration
```

`kg * m / sec^2` is the composite unit of force. The
compiler deduces it automatically from the operands: `kg *
(m / sec^2)` simplifies to `kg * m / sec^2`. If you then
divide force by area to get pressure, the final unit is `kg
/ (m * sec^2)`, all derived mechanically:

```kai
let area: Real<m^2> = 4.0<m^2>
let pressure: Real<kg / (m * sec^2)> = force / area
```

The type system does **unit algebra**. `m * m` simplifies
to `m^2`, `sec / sec` cancels to no-unit, `(m / sec) *
(sec)` cancels to `m`. It's abelian algebra over unit
symbols — and any expression legal in elementary math over
units is legal in kaikai.

In a program, the unit rides along with the value all the
way to the print, `sec^2` included — a unit nobody declared:

```kai
# examples/ch10/02_unit_algebra.kai
unit m

unit sec

unit kg

fn main() {
  let velocity: Real<m / sec> = 9.81<m/sec>
  println("v = #{velocity}")

  # Composite unit: acceleration.
  let g: Real<m / sec^2> = 9.81<m/sec^2>
  println("g = #{g}")

  # Product of units: F = m * a has unit kg*m/sec^2.
  let mass: Real<kg> = 70.0<kg>
  let force: Real<kg * m / sec^2> = mass * g
  println("F = m * g = #{force}")

  # Product of the same unit with itself: time squared.
  let t: Real<sec> = 3.0<sec>
  let t2: Real<sec^2> = t * t
  println("t² = #{t2}")
}
```

```
$ kai run examples/ch10/02_unit_algebra.kai
v = 9.81 m/sec
g = 9.81 m/sec^2
F = m * g = 686.7 kg m/sec^2
t² = 9 sec^2
```

### Aliases for derived units

When a composition appears often, you can name it with a
`unit` with a body:

```kai
unit Newton = kg * m / sec^2
unit Pascal = Newton / m^2
unit Hertz  = 1 / sec
```

From there, `Real<Newton>` is exactly the same as
`Real<kg * m / sec^2>` — the compiler accepts them
interchangeably. The difference is for the reader:
`Real<Newton>` communicates intent; `Real<kg * m / sec^2>`
communicates derivation.

`Newton` in use, next to the proof that both spellings are the
same unit as far as the compiler is concerned:

```kai
# examples/ch10/03_alias.kai
unit m

unit sec

unit kg

unit Newton = kg*m/sec^2

fn main() {
  let g: Real<m / sec^2> = 9.81<m/sec^2>
  let mass: Real<kg> = 70.0<kg>
  let force: Real<Newton> = mass * g
  println("F = #{force}")

  # Newton and kg*m/sec^2 are the same unit — interchangeable.
  let force_explicit: Real<kg * m / sec^2> = force
  println("same unit: #{force_explicit}")
}
```

```
$ kai run examples/ch10/03_alias.kai
F = 686.7 kg m/sec^2
same unit: 686.7 kg m/sec^2
```

### Rounding without losing the unit

Dividing two measurements rarely lands on a round number. A
hundred meters in 9.58 seconds is 10.438413361169102 m/sec, and
that is what a `Real` prints: as many digits as it takes to read
back as the same number. For a report you want two decimals,
and the natural worry is that rounding hands you back a bare
number.

It doesn't. The rounding family in `math.real` — `trunc`,
`floor`, `ceil`, `round`, `round_half_even`, `round_to` — is
generic over `Measure`, the same way the `average` you write in
§10.4 is. A `Real<u>` goes in and a `Real<u>` comes out.

```kai
# examples/ch10/07_rounding.kai
import math.real

unit m

unit sec

fn main() : Unit / Stdout {
  let v: Real<m / sec> = 100.0<m> / 9.58<sec>
  let vr: Real<m / sec> = real.round_to(v, 2)

  println("#{v}")
  println("#{vr}")
  println("#{real.round_to(v, 1)}")
  println("#{real.round(v)}")

  # The hole's spec formats without touching the value, and the
  # unit travels with it.
  println("#{v:.2}")
}
```

```
$ kai run examples/ch10/07_rounding.kai
10.438413361169102 m/sec
10.44 m/sec
10.4 m/sec
10 m/sec
10.44 m/sec
```

The annotation on `vr` is the part that matters. The unit
appearing in the printed text proves little; `Real<m / sec>`
accepting the result proves the unit survived in the type, which
is where the compiler checks it.

There is a second tool worth not confusing with the first. If
all you want is to **display** the number with two decimals,
the interpolation hole takes the format spec from §3.2 and
respects the unit: `#{v:.2}` prints `10.44 m/sec` without
touching the value. Round with `real.round_to` when the rounded
number is the one that keeps travelling through the program;
use the spec when the rounding is only for the eye.

## 10.4 Generic units

So far each function operates on a concrete unit, but many
operations are **unit-agnostic** — averaging, summing,
sorting, finding the maximum. Those are written **generic
over the unit**, just as a function can be generic
over the element type of a list.

```kai
fn average[u: Measure](a: Real<u>, b: Real<u>) : Real<u> =
  (a + b) / 2.0
```

`u : Measure` declares `u` as a type parameter in the
**kind** `Measure`. The only thing `u` admits is being a
unit. And `Measure` is not a one-off: it is one entry in the
language's kind catalog (`stdlib/core/kinds.kai`), the same
mechanism that classifies types, effects, currencies and
memory regions — you'll walk through all of it in chapter
19. The
function `average` takes two `Real<u>` and returns
a `Real<u>` — the "for any u" lets you use it with `USD`,
`kg`, `m/sec`, anything, **as long as the two arguments
have the same unit**.

The whole file, with the function and both of its uses:

```kai
# examples/ch10/04_generic.kai
fn average[u: Measure](a: Real<u>, b: Real<u>) : Real<u> =
  (a + b) / 2.0

unit USD

unit kg

fn main() {
  let p1: Real<USD> = 10.0<USD>
  let p2: Real<USD> = 20.0<USD>
  let pp: Real<USD> = average(p1, p2)
  println("avg prices = #{pp}")

  let m1: Real<kg> = 70.0<kg>
  let m2: Real<kg> = 80.0<kg>
  let pm: Real<kg> = average(m1, m2)
  println("avg masses = #{pm}")

  # average(p1, m1) would be a type error: USD ≠ kg.
}
```

```
$ kai run examples/ch10/04_generic.kai
avg prices = 15 USD
avg masses = 75 kg
```

But this is a type error:

```kai
let mix = average(10.0<USD>, 70.0<kg>)   # u can't be USD and kg
```

The compiler instantiates `u = USD` for the first argument, and
demands the second use `u = USD` too. `kg` doesn't fit, and
the program doesn't compile.

Generic units are what makes the system **scalable**. Stdlib
functions (`list.sum`, `list.max`, `list.min`) are
polymorphic over the unit: pass a `[Real<USD>]`, you get
`Real<USD>`; pass `[Real<kg>]`, you get `Real<kg>`. The unit
is preserved without you naming it.

## 10.5 Explicit conversions

Sometimes you **do** want to mix two distinct units — adding
a USD balance to an EUR one, say. The compiler won't let you
do it by accident, but it will with an **explicit
conversion**.

The technique is a conversion factor carrying the quotient
unit `dest/source`. Multiplying by it cancels the source
unit and leaves the destination one:

```kai
let eur_amount: Real<EUR> = 80.0<EUR>
let rate: Real<USD / EUR> = 1.10<USD / EUR>
let usd_amount: Real<USD> = eur_amount * rate    # 88 USD
```

The arithmetic follows: `EUR * (USD / EUR)` cancels `EUR`
and leaves `USD`. The compiler verifies the cancellation is
correct — if you put the rate the wrong way around
(`Real<EUR / USD>`), the multiplication produces `Real<EUR^2
/ USD>`, which doesn't fit the `Real<USD>` expected by the
`let`.

Mental rule: **conversion is multiplication by a factor
whose units cancel at the output**. It's what you do by hand
in physics when you write "10 km × 1000 m/km = 10000 m";
kaikai makes you write that multiplication.

I did it on purpose, and I think it also frees you. A visible
conversion makes you think about what rate you're using, when
it applies, and where it came from; and once it's written,
the compiler guarantees you didn't forget it anywhere.

## 10.6 Branded types

Units are useful when the value "has a physical dimension":
meters, kilograms, dollars. But the same machinery applies
to a more everyday case:
**distinguishing values that have the same underlying type
but mean different things**.

The classic example is identifiers. A `UserId` is an
integer. An `OrderId` too. Without units, the compiler
cannot tell them apart:

```kai
fn cancel_order(id: Int) : Unit / Stdout = ...
fn send_email(uid: Int) : Unit / Stdout = ...

let user_id = 42
let order_id = 99
cancel_order(user_id)   # bug: we passed a user id to a
                        # function expecting an order id,
                        # but it compiles anyway.
```

With units, both identifiers are distinct types:

```kai
unit UserId
unit OrderId

fn cancel_order(id: Int<OrderId>) : Unit / Stdout = ...
fn send_email(uid: Int<UserId>) : Unit / Stdout = ...

let user_id: Int<UserId>  = 42<UserId>
let order_id: Int<OrderId> = 99<OrderId>

cancel_order(user_id)   # type ERROR: UserId ≠ OrderId
```

Using a unit as a **label** over a numeric type is called a
**branded type**, and it's one of the uses that pays off most
in everyday code. Typical cases:

- `Int<UserId>` vs `Int<OrderId>` — identifiers sharing
  underlying type.
- `Int<Cents>` vs `Int<Quantity>` — money in cents vs a
  count of units.
- `Int<Seconds>` vs `Int<Milliseconds>` — wrongly expressed
  timeouts are responsible for a non-trivial percentage of
  intermittent bugs.

Units label numeric types: `Int`, `Real`, and `Decimal`. A
string has no way to take one: `"ada@x.cl"<Email>` is not a
valid literal. To keep a validated email apart from a
username, use a record with a private field (§4.1): the module
exposes the function that validates and builds the value, and
nobody else can make one.

Two of those cases in a program that runs. The commented-out
lines are precisely the ones the compiler rejects:

```kai
# examples/ch10/05_branded.kai
unit UserId

unit OrderId

unit Seconds

unit Milliseconds

fn cancel_order(id: Int<OrderId>) : Unit / Stdout =
  println("cancelling order #{id}")

fn timeout_ms(t: Int<Milliseconds>) : Unit / Stdout =
  println("timeout = #{t}")

fn main() {
  let _uid: Int<UserId> = 42<UserId>
  let oid: Int<OrderId> = 99<OrderId>

  cancel_order(oid)

  # The next line does NOT compile: a UserId where an OrderId
  # is expected, even though both are Int.
  # cancel_order(_uid)

  let _wait_sec: Int<Seconds> = 30<Seconds>
  let wait_ms: Int<Milliseconds> = 30<Milliseconds>

  timeout_ms(wait_ms)

  # Nor this: passing seconds where milliseconds were expected.
  # timeout_ms(_wait_sec)
}
```

```
$ kai run examples/ch10/05_branded.kai
cancelling order 99
timeout = 30
```

### Zero cost at runtime

Units are erased after type checking. The binary that
`kai build` produces operates with plain `Int`, `Real`, and
`Decimal`. The unit **doesn't exist** at runtime: no tag, no
dynamic verification, no overhead. The promise is
the same as algebraic effects and contracts: information in
the type, zero cost at runtime.

## 10.7 Case study: multi-currency wallet

We close with an integrative example. A wallet contains
balances in different currencies. Adding balances of the
same currency is trivial; combining them into a total
requires conversion.

```kai
# examples/ch10/06_wallet.kai
unit USD

unit EUR

unit CLP

fn add[c: Measure](a: Real<c>, b: Real<c>) : Real<c> = a + b

# Explicit conversion: the factor carries the quotient unit
# `dest/source`; multiplying cancels the source unit and
# leaves the destination one.
fn convert[source: Measure, dest: Measure](
  amount: Real<source>,
  rate: Real<dest / source>
) : Real<dest> = amount * rate
```

Three declarations. `add` is generic over the currency and
preserves the unit of the arguments — same technique as
§10.4. `convert` takes an amount and a rate, and returns the
amount in the destination unit thanks to unit cancellation.

And the main calculation:

```kai
fn main() {
  let usd_balance_1: Real<USD> = 100.0<USD>
  let usd_balance_2: Real<USD> = 50.0<USD>
  let total_usd: Real<USD> = add(usd_balance_1, usd_balance_2)
  println("total USD = #{total_usd}")

  let eur_balance: Real<EUR> = 80.0<EUR>

  # To combine USD and EUR, convert explicitly:
  let eur_to_usd_rate: Real<USD / EUR> = 1.10<USD/EUR>
  let eur_in_usd: Real<USD> = convert(eur_balance, eur_to_usd_rate)
  let global_total: Real<USD> = add(total_usd, eur_in_usd)
  println("total converted to USD = #{global_total}")

  # Convert CLP to USD with its own rate.
  let clp_balance: Real<CLP> = 100000.0<CLP>
  let clp_to_usd_rate: Real<USD / CLP> = 0.0011<USD/CLP>
  let clp_in_usd: Real<USD> = convert(clp_balance, clp_to_usd_rate)
  let final_total: Real<USD> = add(global_total, clp_in_usd)
  println("final total = #{final_total}")
}
```

```
$ kai run examples/ch10/06_wallet.kai
total USD = 150 USD
total converted to USD = 238 USD
final total = 348 USD
```

Three conversions, three uses of `add`. Each verified by
the compiler: had you tried to add `Real<EUR>` with
`Real<USD>` without converting somewhere, it wouldn't
compile. If the rate were inverted (`<EUR / USD>` instead of
`<USD / EUR>`), neither would. The full wallet is **a
mini-type-system over money** that the compiler upholds.

The day a colleague adds a new currency, they declare a
`unit JPY`, add its rate, and the rest of the code keeps
compiling or not as appropriate. No
old calculation breaks — types are orthogonal — and
calculations that need to consider JPY have to say so
explicitly. It's the principle you met in chapter 5 with
union errors: adding a new component is safe because the
compiler walks you to the exact place needing change.

Compare with the no-units version:

```kai
fn add(a: Real, b: Real) : Real = a + b

let total = add(usd_balance, eur_balance)   # compiles, sums values
                                            # in different currencies
                                            # without converting.
```

It works, returns a number, and produces a total that
**means nothing**. With units, the same program doesn't
compile: the bug that other languages discover in production
— or never, depending on luck — doesn't exist here.

A note for production code: the stdlib ships a `money`
module with the ISO currencies already declared and a
`Money[c: Currency]` type built on `Decimal` (exact
arithmetic, not floating point). It uses its own kind,
`Currency`, stricter than `Measure`: adding and scaling are
allowed, but `USD^2` or `USD*EUR` cannot even be written.
You'll find that difference in chapter 19; for learning the
mechanics of units, this chapter's `Real<USD>` is the way.

## Exercises

**10.1.** Define `unit Celsius` and `unit Fahrenheit`. Write
`fn celsius_to_fahrenheit(c: Real<Celsius>) :
Real<Fahrenheit>` applying the right formula. What's the
conversion factor? Does it have a unit?

**10.2.** Define `unit Cents` (cents) and write `fn pay(amount:
Int<Cents>) : Unit / Stdout`. Build an example where the
language detects a bug of "passing an amount in dollars
where cents were expected".

**10.3.** Take the §10.7 case study and add a new currency
`JPY` with its rate. How many lines do you have to change?
Is there any line of existing code that breaks just because
you added the unit?

**10.4.** Write a generic function
`fn range[u: Measure](xs: [Real<u>]) : Option[Real<u>]`
that returns the difference between max and min of a list,
or `None` if empty. What unit does the result have?

**10.5.** In your work or a personal project, identify
**two** places where two distinct integers mean different
things (identifiers, indices, counters, timeouts). Write
in pseudo-kaikai how the affected function signatures would
look using branded types. How many historical bugs could
have been avoided?
