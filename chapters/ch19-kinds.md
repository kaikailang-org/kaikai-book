# Chapter 19 · Kinds: a catalog of algebras

This chapter pays a promise §2.6 left open: in kaikai the type
is not the only label, and the families of labels — the
**kinds** — share one mechanism that someone owed you in full.
You have been touching it in pieces. When you wrote
`fn average[u: Measure](...)` in chapter 10, that `u: Measure`
annotation was not an ordinary type parameter: `u` could not be
`Int` or `String` or any type at all, only a *unit*. You were
quantifying over a different family of things, with different
rules.

And there isn't just one. The types the inferencer unifies, the
effect rows composed in every signature, the units that multiply
and cancel, the stdlib's currencies, the runtime's memory
regions: each is a distinct kind, with its own algebra. kaikai
declares all of them in one place, with one mechanism, and this
chapter walks the whole catalog.

It is the most abstract chapter in the book, which is why it
comes last: you need none of this to write productive kaikai. But
if you made it here, I'd bet the question has already formed on
its own: what do chapter 10's units, chapter 12's effects and
chapter 13's memory have in common? The answer is short and, I
think, elegant. Let's see it.

## 19.1 What a kind is

A type classifies values: `42` inhabits `Int`, `"hello"` inhabits
`String`. A **kind** classifies one rung up: its inhabitants are
not values but the symbols that participate in types. `Int`
inhabits the kind `Type`. The unit `m` inhabits the kind
`Measure`. The effect `Stdout` inhabits the kind `Effect`.

You saw the practical consequence in chapter 10: a parameter
`[u: Measure]` accepts only units, and the compiler reasons about
`u` with the rules of units — `u^2` makes sense, `u` and `kg`
unify only if they are the same. Compare an ordinary `[t]`
parameter, which accepts types and is reasoned about with the
rules of types. The kind annotation tells the compiler **which
algebra to use** when it has to decide whether two things are
equal.

That is the whole concept: a kind is a family of habitants, plus
the algebra the compiler unifies them with. kaikai calls that
algebra a **theory**.

## 19.2 Theories: unification algebras

When the compiler sees `Real<m * s>` and `Real<s * m>`, are they
the same type? To answer, it needs to know that the product of
units commutes. When it sees the effect rows `Stdout + Fail` and
`Fail + Stdout`, it needs to know that order in a row is
irrelevant. When it sees two regions `r1` and `r2`, it needs to
know they are never equal unless they are literally the same one.

Each of those questions is answered by a **theory**: a set of
equational rules the compiler applies when unifying habitants of
a kind. Three things define one:

- **It is decidable.** The unification algorithm always
  terminates, and fast. There is no SMT solver, no search: these
  algebras were chosen precisely because their unification is a
  direct computation.
- **It erases at runtime.** Just like chapter 10's units: the
  theory decides *at compile time* which programs are legal, then
  vanishes from the binary.
- **The catalog is closed.** You can declare new habitants
  (`unit parsec`) and even new kinds (§19.5), but you cannot
  declare a new theory. Try, and the compiler answers
  `unknown theory`. That is a design decision, not a temporary
  limitation; §19.8 defends it.

## 19.3 The full catalog

The catalog lives in `stdlib/core/kinds.kai`, and it is short.
Here is an excerpt (the real file carries a comment per entry):

```kai
# excerpt of stdlib/core/kinds.kai
theory HindleyMilner = builtin
theory EffectRow     = builtin
theory AbelianGroup  = { assoc, commut, inverse, identity }
theory Module        = { assoc, commut, inverse, identity }
theory Structural    = builtin

kind Type     : HindleyMilner with type
kind Effect   : EffectRow     with effect
kind Measure  : AbelianGroup  with unit
kind Currency : Module        with currency
kind Region   : Structural    with region
```

Each `kind` names its theory and, after the `with`, its
**introducer word**: the declaration that mints habitants. `type`
mints habitants of `Type`. `effect` mints habitants of `Effect`.
`unit` mints habitants of `Measure`. You have been minting kind
habitants for the whole book; all that was missing was the org
chart:

| Kind | Theory | Introducer | Habitants | What the theory decides |
|---|---|---|---|---|
| `Type` | `HindleyMilner` | `type` | `Int`, `String`, yours | type equality and inference |
| `Effect` | `EffectRow` | `effect` | `Stdout`, `Fail`, yours | rows: order irrelevant, duplicates collapse |
| `Measure` | `AbelianGroup` | `unit` | `m`, `s`, `USD` if you like | product, quotient and power of units |
| `Currency` | `Module` | `currency` | `USD`, `EUR`, … (`stdlib/money.kai`) | addition and scaling; **no** product |
| `Region` | `Structural` | `region` | one fresh per `region` block | identity: each arena is only itself |

Three theories say `builtin`: their engine is the compiler
itself. `HindleyMilner` is the type inferencer that has been with
you since chapter 3; `EffectRow` is chapter 12's row unification;
`Structural` is symbol equality, which the core already knew how
to do. The other two are described by algebraic properties
(associative, commutative, with inverse, with identity), and the
difference between them — identical at first glance — is *which
operation* those properties govern. In `AbelianGroup`, the
habitants themselves form a group under product: `m * s`, `m^2`,
`1/s` are new, derived habitants. In `Module`, the structure is
additive only: *quantities* of a habitant add up and scale by a
number, but habitants never multiply each other. `USD^2` is not a
habitant of `Currency`; it does not exist. That asymmetry is
deliberate, and §19.7 exploits it.

Note what is **not** in the table: anything of yours. The
language's complete catalog fits on one screen. Five kinds, five
theories, and every chapter you have read so far is built on
them.

## 19.4 The same shape, three kinds

What makes this a *system* rather than five stacked features is
that quantification works the same over any kind. Compare these
three signatures:

```kai
fn area_of[u: Measure](width: Real<u>, height: Real<u>) : Real<u^2>
fn insert[r: Region](t: Tree<r>, k: Int) : Tree<r>
pub fn convert[a: Currency, b: Currency](m: Money[a], rate: dec.Decimal) : Money[b]
```

The first you wrote in chapter 10. The second you will meet in
§19.6. The third comes verbatim from `stdlib/money.kai`. All
three say the same thing: "for any habitant of this kind". And in
all three, the compiler applies the kind's theory when checking
the body: in `area_of` it can form `u^2` because `AbelianGroup`
has a product; in `insert` it demands that the tree coming in and
the tree going out live in the *same* region, because
`Structural` never unifies distinct regions; in `convert` it lets
`a` and `b` differ because they are two parameters — chapter 10's
explicit door between currencies, now with its mechanism in
plain view.

Listing 19.1 is the first signature, complete and running:

```kai
# Listing 19.1 — examples/ch19/01_generic_over_units.kai
unit m
unit s

fn area_of[u: Measure](width: Real<u>, height: Real<u>) : Real<u^2> =
  width * height

fn main() : Unit / Stdout = {
  let a1 = area_of(3.0<m>, 4.0<m>)      # Real<m^2>
  let a2 = area_of(3.0<s>, 4.0<s>)      # Real<s^2>
  println("#{a1}")
  println("#{a2}")
}
```

```
$ kai run examples/ch19/01_generic_over_units.kai
12 m^2
12 s^2
```

Look at the output: `Show` on a unit-carrying `Real` prints the
unit, power included. "Seconds squared" is a strange unit in this
world's physics, but the algebra holds no opinions about physics
— only about consistency.

## 19.5 Your own kinds

`Measure` is not special. The `kind` declaration is available to
you, with the two non-builtin theories as options. One case where
it pays: separating unit systems that must never mix, not even
through an accidental conversion.

```kai
# Listing 19.2 — examples/ch19/02_own_kind.kai
kind Metric   : AbelianGroup with metric
kind Imperial : AbelianGroup with imperial

metric m
metric s
imperial ft

fn speed(d: Real<m>, t: Real<s>) : Real<m/s> = d / t

fn main() : Unit / Stdout = {
  let v = speed(100.0<m>, 9.58<s>)
  println("#{v}")

  # This does not compile: m lives in Metric, ft lives in Imperial.
  #   fn bad(a: Real<m>, b: Real<ft>) : Real<m> = a + b
}
```

```
$ kai run examples/ch19/02_own_kind.kai
10.4384 m/s
```

Each `kind ... with word` also mints its own introducer word:
here `metric` and `imperial` declare habitants exactly as `unit`
does for `Measure`. Two habitants of different kinds **never**
unify, even when both measure length. Within chapter 10, `m + ft`
was a unit error; here it is a deeper one: there is not even a
shared algebra in which to pose the question. It is the Mars
Climate Orbiter class of bug — pound-force read as newtons —
closed not by a naming convention but by a kind boundary.

Additive kinds can be declared too
(`kind Points : Module with points`): they fit quantities that
add and scale but where "points squared" would be nonsense — game
points, frequent-flyer miles, academic credits. The two remaining
`builtin` theories accept no user kinds: write
`kind Zone : Structural` and the compiler tells you a builtin
theory cannot classify a user-declared kind. Regions, types and
effects have exactly one kind each, and it belongs to the
language.

## 19.6 Region: memory as a habitant

Chapter 13 owes you one. When we said Perceus inserts increments
and decrements at the exact points where values die, a question
was left open: what if a computation builds a million short-lived
values only to fold them into one number? Every cell pays its way
in and out of the counter, and all that bookkeeping is work a
human reading the program would know to be unnecessary: *none of
this survives the computation*.

The `region` block is how you tell the compiler:

```kai
# Listing 19.3 — examples/ch19/03_region_scratch.kai
fn sum(xs: [Int]) : Int = match xs {
  []        -> 0
  [h, ...t] -> h + sum(t)
}

fn main() : Unit / Stdout = {
  let total = region {
    let a = [1, 2, 3, 4, 5]        # built in the arena
    let b = [10, 20, 30]           # built in the arena
    sum(a) + sum(b)                # scalar result
  }                                # arena freed here, in one shot
  println("#{total}")
}
```

```
$ kai run examples/ch19/03_region_scratch.kai
75
```

Every constructor written lexically inside the block allocates in
an **arena**: a slab of memory that grows by bump — a pointer
that advances, no counter anywhere — and is freed whole at the
closing brace. The two lists above pay not a single increment or
decrement. The scalar crosses the boundary for free.

What if the structure needs to cross *functions* before folding?
That is where the kind comes in. The `region { r -> ... }` form
binds a name for the region, and that `r` is a fresh habitant of
`Region` that types can carry:

```kai
# Listing 19.4 — examples/ch19/04_tree_in_arena.kai
type Tree = Leaf | Node(Tree, Int, Tree)

fn insert[r: Region](t: Tree<r>, k: Int) : Tree<r> =
  match t {
    Leaf -> Node(Leaf, k, Leaf)
    Node(l, v, rr) ->
      if k < v { Node(insert(l, k), v, rr) }
      else if k > v { Node(l, v, insert(rr, k)) }
      else { Node(l, v, rr) }
  }

fn tree_sum[r: Region](t: Tree<r>) : Int =
  match t {
    Leaf -> 0
    Node(l, v, rr) -> tree_sum(l) + v + tree_sum(rr)
  }

fn build[r: Region](t: Tree<r>, n: Int) : Tree<r> =
  if n == 0 { t } else { build(insert(t, n), n - 1) }

fn main() : Unit / Stdout = {
  let total = region { r ->
    let tree = build(Leaf, 100)
    tree_sum(tree)
  }                                # 100 nodes freed in one shot
  println("#{total}")
}
```

```
$ kai run examples/ch19/04_tree_in_arena.kai
5050
```

Read the signatures with §19.4 eyes: `insert` is generic over the
region exactly as `area_of` is generic over the unit. `Tree<r>`
marks in the type that these nodes live in arena `r`; the `Tree`
type is declared once, knowing nothing about regions, and any
function becomes region-polymorphic by annotating `[r: Region]`.
A hundred nodes, zero counter operations, one free.

`Structural` is the simplest theory in the catalog, and here is
why: each `region { r -> }` block mints a *fresh* habitant,
distinct from every other. Two regions never unify. That is what
keeps a `Tree<r1>` out of an arena `r2` that is freed at a
different time: the error is a type error, at compile time, by
the same mechanism that rejects `m + ft`.

Two pieces of fine print, both load-bearing:

- **What escapes gets copied.** The block's value crosses the
  boundary: a scalar for free; a structure is deep-copied onto
  the normal RC heap before the arena dies. A region whose result
  is the whole structure is *slower* than no region at all. The
  niche is scratch that folds down to little.
- **The arena is lexical in the unnamed form.** In a
  `region { ... }` without a binder, only constructors written
  inside the block allocate in the arena; a helper called from
  the block allocates on the normal heap. To cross functions, use
  the binder and `[r: Region]` signatures, as in listing 19.4.

`region` is opt-in: the compiler never infers it for you. The
language's default remains chapter 13's — Perceus, exact and
pause-free — and `region` is the lever you pull when the profiler
shows you a computation that builds and discards by the
truckload.

## 19.7 Money: the algebra that is missing on purpose

Chapter 10 modeled currencies with `unit USD`, and it works. But
it leaves a curious door open: in `Measure`, habitants form a
group under product, so `USD^2` and `USD*EUR` are perfectly
formable units. No sane accounting program produces them on
purpose — but a bug can, and the type system would accept them
with the same solemnity it accepts `m/s^2`.

For money, the stdlib uses the `Currency` kind, whose theory
`Module` simply **has no** habitant product. The type
`Money[c: Currency]` mounts the currency on `Decimal` — exact
fixed-point arithmetic, not floating point, which for money is
the only defensible choice:

```kai
# Listing 19.5 — examples/ch19/05_money.kai
import money
import decimal as dec
import decimal_proto

fn main() : Unit / Stdout = {
  let a: Money[USD] = 10.50<USD>
  let b: Money[USD] = 4.50<USD>
  let total = a + b                       # same currency: Money[USD]

  let k: dec.Decimal = 3
  let triple = total * k                  # scalar: still USD

  let rate: dec.Decimal = 0.92
  let in_euros: Money[EUR] = money.convert(total, rate)

  println("total  = #{money.to_string(total)} USD")
  println("triple = #{money.to_string(triple)} USD")
  println("euros  = #{money.to_string(in_euros)} EUR")
}
```

```
$ kai run examples/ch19/05_money.kai
total  = 15.0 USD
triple = 45.0 USD
euros  = 13.800 EUR
```

Adding the same currency: yes. Scaling by a number: yes — that is
a module's "external multiplication", in the algebraic sense of
the word. Converting: only through the explicit door of
`money.convert`, target currency pinned by the annotation. And
multiplying two monies?

```kai
# Listing 19.6 — examples/ch19/06_usd_times_eur.kai (does not compile)
let u: Money[USD] = 10.00<USD>
let e: Money[EUR] = 5.00<EUR>
let nonsense = u * e            # error: `EUR USD` does not exist
```

```
$ kai build examples/ch19/06_usd_times_eur.kai
error: operator `*` cannot combine `Currency` quantities: the
result unit `EUR USD` does not exist
  = note: `Currency` is a Module kind: a quantity is either
    scalar or carries exactly one habitant with exponent 1 —
    habitant products and powers are not expressible
```

That error is worth reading twice. It does not say "operation
forbidden by a special rule for money". It says the result type
**cannot be formed**: in the algebra of `Currency` there is no
habitant that means "euros times dollars". It is the difference
between a guard at the door and a building without that door. The
same mechanism that grants the physicist her `kg·m/s^2` denies
the accountant his `USD*EUR` — not two checking systems, but two
theories in one catalog.

And this answers the question left hanging in chapter 10: when
`unit USD`, when `Money[USD]`? If you are learning the mechanics
of units, or modeling magnitudes that genuinely multiply (price
per energy: `USD/kWh` times `kWh` gives `USD`), the `Measure`
kind is your tool. If you are writing the accounting system,
`Currency` removes a whole family of meaningless types from your
program and throws in `Decimal` for free.

## 19.8 Closed theories, open models

I close with the design question, because I know the reader
coming from Haskell has it loaded: why a closed catalog? Why not
typeclasses, or higher-kinded types, or user-definable theories,
letting everyone build their own algebra?

Because each catalog entry buys its decidability separately.
`AbelianGroup` unification is exponent arithmetic; `Module`'s, a
habitant-and-exponent-1 check; `Structural`'s, symbol equality.
Each is a small, fast algorithm with no pathological cases. An
arbitrary user-defined theory would be an arbitrary unification
problem — and the history of type systems is littered with
innocent-looking algebras whose unification is undecidable. The
price would be paid exactly where kaikai refuses to pay it:
compile time and error quality, the two things this book has
spent eighteen chapters defending.

kaikai's bet is **closed theories, open models**: the language
ships the algebras and guarantees they unify fast; you bring the
habitants (`unit parsec`, `currency CLP`) and the kinds those
algebras admit (`kind Points : Module`). It is the same
silhouette as chapter 9's protocols — closed single dispatch over
a simple mechanism, rather than open typeclasses over a complex
one — applied one floor up.

What the catalog gives you today, you have seen: dimensions for
the physicist, currencies for the accountant, arenas for the
microsecond-chaser, and a single mental model for all three. And
the catalog is designed to grow: a new entry is one decidable
unification theory plus one introducer word, and the rest of the
language — quantification, the `<...>` syntax, runtime erasure —
receives it for free. Which entries earn a slot is a design
conversation, not a mechanism problem. The mechanism, as you just
saw, fits on one screen.

## Exercises

**19.1.** Declare `kind Miles : Module with miles` and a habitant
`miles frequent`. Write one function that adds frequent-flyer
miles and another that scales them by a status multiplier. Verify
that `Int<frequent> * Int<frequent>` does not compile. What does
the error say, and how does it resemble listing 19.6's?

**19.2.** Take §10.7's multi-currency wallet and rewrite it with
`Money[c: Currency]` instead of `Real<USD>`. What changes in the
signatures? What new error does the compiler catch that the
`Measure` version let through?

**19.3.** In listing 19.4, change `tree_sum(tree)` to `tree` as
the `region` block's value. It still compiles — but measure with
`kai bench` the original against the new version building
10,000-node trees. Explain the difference using §19.6's fine
print.

**19.4.** Listing 19.3 uses `region { ... }` with no binder.
Extract the construction of the two lists into a helper
`fn make() : ([Int], [Int])` called from inside the block. Does
the program still compile? Do the lists still live in the arena?
Justify with §19.6's fine print.

**19.5.** Chapter 12 showed that effect rows ignore order:
`Stdout + Fail` unifies with `Fail + Stdout`. Write that rule as
algebraic properties in the catalog's style
(`{ assoc, commut, ... }`). Which property must the row theory
*not* have so that `Fail + Fail` collapses to `Fail`? Why do you
think `EffectRow` is `builtin` rather than declared by
properties?
