# Chapter 10 · Units of measure and branded types

In 1999, NASA lost the Mars Climate Orbiter — a 327
million-dollar project — because two software modules
exchanged numerical values without agreement on units. One
produced thrust in pound-force per second; another read it
as newtons per second. Nobody had written units on the
interface. The probe disintegrated on Mars.

It's an extreme example, but the family is huge: two
components sharing the same numeric type but not the same
interpretation. Passing seconds where milliseconds are
expected. Adding balances in different currencies. Mixing a
`UserId` with an `OrderId` because both are integers. In
every case, the language's type system sees two numbers or
two strings and has no way to distinguish them.

kaikai solves this whole family with a single construct:
**units of measure**. The idea, inherited from F#, is that
you can annotate a number with a unit (`Real<USD>`,
`Int<Seconds>`) and the compiler rejects any operation that
mixes incompatible units. The unit **lives in the type**,
**is erased at runtime**, and is documented in every
signature it touches.

And if §2.6 left you with the idea that in kaikai the type is
not the only label, this chapter is where that idea becomes
tangible: units are your first full-body encounter with a
**kind** — a family of labels with its own algebra, distinct
from types. You have already used another one without looking
at it head-on (the effect row); this is the first one you will
declare and manipulate yourself.

This chapter covers classical units (physics, finance, time)
and their less obvious but more frequent use in day-to-day
code: **branded types**, where the unit is just a label
distinguishing types that the language, without it, would
treat as the same.

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
`USD` the type system can use as an annotation. There's no implementation,
no runtime value — `unit` only declares the existence of the
symbol.

To annotate a number with a unit, use angle brackets in the
literal:

```kai
let price : Real<USD> = 1.50<USD>
let speed : Real<m / sec> = 9.81<m / sec>
let timeout : Int<sec> = 30<sec>
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
  `CLP`). The compiler enforces none of these conventions —
  it's community style.

## 10.2 Arithmetic with units

Arithmetic between values of the same unit works as you'd
expect. Adding two `Real<USD>` gives another `Real<USD>`:

```kai
let price : Real<USD> = 1.50<USD>
let tip : Real<USD> = 0.30<USD>
let total : Real<USD> = price + tip    # 1.80 USD
```

But **mixing incompatible units is a compile error**. If you
try:

```kai
let mix = price + 1.20<EUR>     # type error
```

the compiler rejects with an error saying "expected `USD`,
got `EUR`". The program never runs with mixed values; the bug
is caught at compile time, before it can do anything.

The broader rule:

- **`+`, `-`** between two values of the same unit: legal,
  preserves the unit.
- **`*`, `/`** between values with units: legal, **composes
  the units**. See §10.3.
- **`+`, `-`** between distinct units: type error.
- **Comparisons (`<`, `==`)** between distinct units: type
  error.

Arithmetic with a value without a unit and one with a unit
is asymmetric. Multiplying by a scalar (`2.0 * price`) is
legal — the scalar is treated as dimensionless. Adding a
scalar (`price + 1.0`) is an error: we don't know what unit
the `1.0` is in.

## 10.3 Unit algebra: product, quotient, power

Multiplying two units produces a composite unit. The classic
example is force:

```kai
let mass : Real<kg> = 70.0<kg>
let acceleration : Real<m / sec^2> = 9.81<m / sec^2>
let force : Real<kg * m / sec^2> = mass * acceleration
```

`kg * m / sec^2` is the composite unit of force. The
compiler deduces it automatically from the operands: `kg *
(m / sec^2)` simplifies to `kg * m / sec^2`. If you then
divide force by area to get pressure, the final unit is `kg
/ (m * sec^2)`, all derived mechanically:

```kai
let area : Real<m^2> = 4.0<m^2>
let pressure : Real<kg / (m * sec^2)> = force / area
```

The type system does **unit algebra**. `m * m` simplifies
to `m^2`, `sec / sec` cancels to no-unit, `(m / sec) *
(sec)` cancels to `m`. It's abelian algebra over unit
symbols — and any expression legal in elementary math over
units is legal in kaikai.

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

## 10.4 Generic units

So far, each function operates on a concrete unit. But many
operations are **unit-agnostic** — averaging, summing,
sorting, finding the maximum. Those functions are written
**generic over the unit**, just as a function can be generic
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
memory regions — chapter 19 walks through all of it. The
function `average` takes two `Real<u>` and returns
a `Real<u>` — the "for any u" lets you use it with `USD`,
`kg`, `m/sec`, anything, **as long as the two arguments
have the same unit**.

```kai
let pp : Real<USD> = average(10.0<USD>, 20.0<USD>)   # 15 USD
let pm : Real<kg>  = average(70.0<kg>, 80.0<kg>)     # 75 kg
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
`Real<USD>`. Pass `[Real<kg>]`, you get `Real<kg>`. The unit
is preserved without you naming it.

## 10.5 Explicit conversions

What if you **do** want to mix two distinct units? For
example, adding a USD balance with an EUR one. The compiler
doesn't allow it accidentally, but it does allow it with an
**explicit conversion**.

The technique is a conversion factor carrying the quotient
unit `dest/source`. Multiplying by it cancels the source
unit and leaves the destination one:

```kai
let eur_amount : Real<EUR> = 80.0<EUR>
let rate : Real<USD / EUR> = 1.10<USD / EUR>
let usd_amount : Real<USD> = eur_amount * rate    # 88 USD
```

The arithmetic follows: `EUR * (USD / EUR)` cancels `EUR`
and leaves `USD`. The compiler verifies the cancellation is
correct — if you put the rate the wrong way around
(`Real<EUR / USD>`), the multiplication produces `Real<EUR^2
/ USD>`, which doesn't fit the `Real<USD>` expected by the
`let`.

Mental rule: **conversion is multiplication by a factor
whose units cancel at the output**. It's exactly what
physicists do by hand when they write "10 km × 1000 m/km =
10000 m". kaikai forces writing that multiplication
explicitly.

I did it on purpose, and I think it also frees you. On purpose
because forcing a visible conversion makes the programmer
think about what rate they're using, when it was applied, and
where it came from. Freeing because once the conversion is
written, the compiler guarantees you didn't forget it
anywhere.

## 10.6 Branded types

Units are useful when the value "has a physical dimension":
meters, kilograms, dollars. But the same machinery applies
to a more everyday and more frequent case:
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

let user_id : Int<UserId>  = 42<UserId>
let order_id : Int<OrderId> = 99<OrderId>

cancel_order(user_id)   # type ERROR: UserId ≠ OrderId
```

Here the compiler catches the mix-up at compile time, where a
plain `Int` signature would have waved it through. The technique
of using a unit as a **label** over a numeric type is called
**branded type**, and it's one of the uses that pays off most
in everyday code. Typical cases:

- `Int<UserId>` vs `Int<OrderId>` — identifiers sharing
  underlying type.
- `Int<Cents>` vs `Int<Quantity>` — money in cents vs a
  count of units.
- `Int<Seconds>` vs `Int<Milliseconds>` — wrongly expressed
  timeouts are responsible for a non-trivial percentage of
  intermittent bugs.
- `String<Email>` vs `String<Username>` — strings that
  passed through different validations.
- `String<RawHtml>` vs `String<Sanitized>` — input not
  escaped vs ready for safe injection.

The first two cases over `Int` work in any current version
of kaikai. The last two over `String` are partially
implemented; full handling of branded types over `String`
and arbitrary records is an extension the language doc lists
as a near milestone.

### Zero cost at runtime

Units are erased after type checking. The binary that `kai
build` produces operates with plain `Int`, plain `Real`,
plain `String`. The unit **doesn't exist** at runtime: no
tag, no dynamic verification, no overhead. The promise is
the same as algebraic effects and contracts: information in
the type, zero cost at runtime.

## 10.7 Case study: multi-currency wallet

We close with an integrative example. A wallet contains
balances in different currencies. Adding balances of the
same currency is trivial; combining them into a total
requires conversion.

```kai
unit USD
unit EUR
unit CLP

fn add[c: Measure](a: Real<c>, b: Real<c>) : Real<c> = a + b

fn convert[source: Measure, dest: Measure](amount: Real<source>, rate: Real<dest / source>) : Real<dest> = amount * rate
```

Three declarations. `add` is generic over the currency and
preserves the unit of the arguments — same technique as
§10.4. `convert` takes an amount and a rate, and returns the
amount in the destination unit thanks to unit cancellation.

And the main calculation:

```kai
fn main() {
  let usd_balance_1 : Real<USD> = 100.0<USD>
  let usd_balance_2 : Real<USD> = 50.0<USD>
  let total_usd : Real<USD> = add(usd_balance_1, usd_balance_2)    # 150

  let eur_balance : Real<EUR> = 80.0<EUR>
  let eur_to_usd_rate : Real<USD / EUR> = 1.10<USD / EUR>
  let eur_in_usd : Real<USD> = convert(eur_balance, eur_to_usd_rate)
  let global_total : Real<USD> = add(total_usd, eur_in_usd)         # 238

  let clp_balance : Real<CLP> = 100000.0<CLP>
  let clp_to_usd_rate : Real<USD / CLP> = 0.0011<USD / CLP>
  let clp_in_usd : Real<USD> = convert(clp_balance, clp_to_usd_rate)
  let final_total : Real<USD> = add(global_total, clp_in_usd)        # 348
}
```

Three conversions, three uses of `add`. Each verified by
the compiler: had you tried to add `Real<EUR>` with
`Real<USD>` without converting somewhere, it wouldn't
compile. If the rate were inverted (`<EUR / USD>` instead of
`<USD / EUR>`), neither would. The full wallet is **a
mini-type-system over money** that the compiler upholds.

What happens the day a colleague arrives and adds a new
currency? They declare a `unit JPY`, add its rate, and the
rest of the code keeps compiling or not as appropriate. No
old calculation breaks — types are orthogonal — and
calculations that need to consider JPY have to say so
explicitly. It's the same principle chapter 5 showed with
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
**means nothing**. In kaikai with units, the same program
doesn't compile. The bug that in other languages is
discovered in production — or never, depending on luck —
doesn't exist here.

A note for production code: the stdlib ships a `money`
module with the ISO currencies already declared and a
`Money[c: Currency]` type built on `Decimal` (exact
arithmetic, not floating point). It uses its own kind,
`Currency`, stricter than `Measure`: adding and scaling are
allowed, but `USD^2` or `USD*EUR` cannot even be written.
Chapter 19 explains that difference; for learning the
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
