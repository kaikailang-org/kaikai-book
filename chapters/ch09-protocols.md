# Chapter 9 · Protocols

You already know how to group data in records and sum types,
and how to write functions over it. One concrete question
remains: **how do you add operations to a type from outside
its declaration?**

For example: `Point` is a record with two fields. You want
it to print as `(3, 4)` when it appears in interpolation.
Do you modify the type? Pass a function to `println`?
Define a `println` variant just for `Point`? None of these
scale.

kaikai's answer is **protocols**: a named contract with a
small set of operations, that any type can satisfy. I picked the
word "protocol" over "trait" or "interface" because it describes
what actually happens: two parties agreeing on how to talk.
Protocols do what **interfaces** do in Go, **traits** in Rust,
**protocols** in Clojure and Elixir, and the easy part of
**typeclasses** in Haskell — from a precise point in the
design space: **single-dispatch, explicit, no constraint
propagation, no higher-kinded types**. That removes
complexity from the type system at the cost of some things
you can't express. In this chapter you get both sides.

## 9.1 Why protocols exist

Three concrete pains protocols solve.

**Printing your types without writing it each time.**
Printing a record in logs, responses, or errors should not
cost you a `user_to_string` function per type. With `Show`
implemented once, interpolation `"#{user}"` uses it
automatically.

**Structural equality without effort.** Any new type needs
"this equals that" at some point. Without protocols, you
write `eq_point`, `eq_account`, `eq_invoice`, and spend the
rest of the project remembering which name you used in which
file. With `Eq`, the operation is called `eq` for all of
them.

**Comparison, hashing, serialization.** Same argument,
multiplied by three operations almost every type needs
eventually.

Without protocols, each case is solved with naming conventions
or with huge `match`es enumerating every possible type. With
one mechanism, these three and the ones to come take one line
per type.

## 9.2 Declaring a `protocol` and `impl`

A protocol declares a name and one or more operations:

```kai
protocol Show {
  show(x: Self) : String
}
```

`Self` is a reserved name referring to the type that later
implements the protocol. Every operation mentions `Self` at
least once — that's why it's called **single-dispatch**: the
operation is decided from a single type, that of `Self`.

To implement it, you write `impl ... for ...`:

```kai
type Point = { x: Int, y: Int }

impl Show for Point {
  fn show(p: Point) : String =
    "(#{p.x}, #{p.y})"
}
```

From then on, `show(p)` calls your implementation when
`p : Point`:

```kai
fn main() {
  let p = Point { x: 3, y: 4 }
  println(show(p))                # prints "(3, 4)"
  println("p is at #{p}")         # interpolation: uses Show
}
```

Four details worth pinning down:

- **The body of the `impl` lists the protocol's functions one
  by one**, with the standard `fn` syntax. Each `fn` in the
  block must match the signature declared in the `protocol`,
  with `Self` substituted by the concrete type.

- **One implementation per (protocol, type) pair.** If two
  `impl Show for Point` appear in the same compilation, the
  compiler rejects with "duplicate impl". No overriding, no
  contextual resolution.

- **The orphan rule**: you can only implement a protocol `P`
  for a type `T` if your module declares `P`, declares `T`, or
  declares the type of one of `P`'s arguments. This prevents
  two external packages from defining conflicting impls for
  types they both import. It's a practical limitation, not a
  type-system one. And there's no exemption for the builtins:
  `impl Show for Int` in your module doesn't compile.

- **The name can be qualified.** When two of your imports
  export a protocol with the same name, say which one you mean
  — `impl drawing.Render for Box`, and the same inside a
  derive, `#[derive(protocols.Show)]`. It's the general rule
  from §8.2: the qualifier is a tiebreaker, and a bare name is
  fine whenever nothing collides.

With the builtins you hit the orphan rule sooner than you'd
expect: sooner or later
you want an `Int` or a `String` to behave differently in your
domain. The compiler spells out exactly where you stand:

```
error: orphan rule: `impl Show for Int` is in module `a`, but `Show` is declared in
`protocols` and `Int` is builtin; an impl must live in the module of its protocol, its
type, or a protocol argument's type
```

The way out is to wrap the builtin in a type of your own and
give that one the `impl`:

```kai
type Score = Score(Int)

impl Show for Score {
  fn show(self: Score) : String = match self { Score(n) -> "#{n} points" }
}
```

Now the impl lives in the module of its own type and the rule
holds by itself. You also gain what a bare `Int` never gave
you: `Score` and `Age` stop being the same type, and the
compiler stops letting you add them together.

A hand-written impl, and the interpolation that starts using
it without being asked:

```kai
# examples/ch09/01_basic_protocol.kai
type Point = { x: Int, y: Int }

# Manual implementation: format as Cartesian "(x, y)".
impl Show for Point {
  fn show(p: Point) : String =
    "(#{p.x}, #{p.y})"
}

fn main() {
  let origin = Point { x: 0, y: 0 }
  let p = Point { x: 3, y: 4 }
  println(show(origin))
  println(show(p))

  # Since Show is implemented, interpolation uses it
  # automatically:
  println("p is at #{p}")
}
```

```
$ kai run examples/ch09/01_basic_protocol.kai
(0, 0)
(3, 4)
p is at (3, 4)
```

## 9.3 The five stdlib protocols

kaikai ships five protocols in `stdlib/protocols.kai` you'll
use all the time:

| Protocol | Operations | What for |
|---|---|---|
| `Show` | `show(x: Self) : String` | Convert to string for printing |
| `Eq` | `eq(a: Self, b: Self) : Bool` | Equality |
| `Ord` | `cmp(a: Self, b: Self) : Int`, `min`, `max` | Total ordering |
| `Hash` | `hash(x: Self) : Int` | For hash tables and sets |
| `Serialize` | `to_string`, `from_string` | Text ↔ value conversion |

The primitive types (`Int`, `Real`, `Bool`, `String`, `Char`)
already implement all five. For a new type, you choose which
ones are worth implementing.

`Ord` is worth a note: it has **three operations**, not one.
`cmp(a, b) : Int` returns a negative integer if `a < b`, zero
if equal, positive if `a > b`. The other two — `min(a, b)`
and `max(a, b)` — return one of the two arguments according
to ordering. The three are implemented together in the same
block:

```kai
impl Ord for Account {
  fn cmp(a: Account, b: Account) : Int =
    if a.balance < b.balance { -1 }
    else if a.balance > b.balance { 1 }
    else { 0 }

  fn min(a: Account, b: Account) : Account =
    if a.balance < b.balance { a } else { b }

  fn max(a: Account, b: Account) : Account =
    if a.balance > b.balance { a } else { b }
}
```

If three operations feel like too much work, hold on for
§9.4: in many cases the compiler derives them for you.

`Eq` by id and `Ord` by balance on the same type, which is
exactly the case where deriving doesn't help:

```kai
# examples/ch09/02_eq_ord.kai
type Account = {
  id: Int,
  balance: Int
}

impl Eq for Account {
  fn eq(a: Account, b: Account) : Bool = a.id == b.id
}

# Ordering by balance, not id. The implementor chooses.
impl Ord for Account {
  fn cmp(a: Account, b: Account) : Int =
    if a.balance < b.balance {
      -1
    } else if a.balance > b.balance {
      1
    } else {
      0
    }
  fn min(a: Account, b: Account) : Account =
    if a.balance < b.balance { a } else { b }
  fn max(a: Account, b: Account) : Account =
    if a.balance > b.balance { a } else { b }
}

fn main() {
  let a1 = Account { id: 1, balance: 100 }
  let a2 = Account { id: 1, balance: 999 }  # same id, different balance
  let a3 = Account { id: 2, balance: 50 }

  let same_id_12 = eq(a1, a2)
  let same_id_13 = eq(a1, a3)
  println("a1 == a2: #{same_id_12}")  # true: id wins
  println("a1 == a3: #{same_id_13}")  # false

  let cmp12 = cmp(a1, a2)
  let cmp13 = cmp(a1, a3)
  println("cmp(a1, a2): #{cmp12}")  # negative: 100 < 999
  println("cmp(a1, a3): #{cmp13}")  # positive: 100 > 50

  let smaller = min(a1, a3)
  println("smaller balance: #{smaller.balance}")  # 50
}
```

```
$ kai run examples/ch09/02_eq_ord.kai
a1 == a2: true
a1 == a3: false
cmp(a1, a2): -1
cmp(a1, a3): 1
smaller balance: 50
```

## 9.4 `#[derive(...)]` and when to use it

When the obvious implementation — delegate to each field —
is enough, kaikai gives you a shortcut: the `#[derive(...)]`
directive before the type declaration.

```kai
#[derive(Show)]
type Person = {
  name: String,
  age: Int,
}

#[derive(Show, Eq)]
type Point = {
  x: Int,
  y: Int,
}
```

`#[derive(Show)]` tells the compiler "generate me a `Show` for
this record, walking the fields and delegating to each
field's `Show`". The result for `Person`:

```
$ kai run example.kai
Person { name: Ada, age: 30 }
```

That canonical format, `TypeName { field: value, ... }`, is
fine for debugging and logs. If you want a different format (say,
the classic `(3, 4)` for a point), you write the `impl` by
hand, like §9.1.

`#[derive(...)]` works for the five stdlib protocols, as long as
**every field of the record also implements** the protocol
you're deriving. If your record has a field whose type
doesn't have `Show`, `#[derive(Show)]` fails compilation with
a message pointing at the offending field.

The practical rule:

- **Start with `#[derive(...)]`** — the fastest way and almost
  always correct for records.
- **Switch to `impl` by hand** when the derived
  implementation isn't useful: different format, equality
  by some fields only, comparison by a specific field (not
  the natural ordering).

You already used `#[derive(Show)]` on `Point` in the tour
(§1.7); now you also know when the hand-written `impl` pays
off.

Two derived types, one with `Show` and one with both:

```kai
# examples/ch09/03_derive.kai
#[derive(Show)]
type Person = {
  name: String,
  age: Int
}

#[derive(Show, Eq)]
type Point = {
  x: Int,
  y: Int
}

fn main() {
  let ada = Person { name: "Ada", age: 30 }
  println(show(ada))

  # Automatic Show in interpolation.
  println("record: #{ada}")

  let p = Point { x: 3, y: 4 }
  let q = Point { x: 3, y: 4 }
  let r = Point { x: 5, y: 5 }

  let pq_eq = eq(p, q)
  let pr_eq = eq(p, r)
  println("p == q: #{pq_eq}")  # true
  println("p == r: #{pr_eq}")  # false
}
```

```
$ kai run examples/ch09/03_derive.kai
Person { name: Ada, age: 30 }
record: Person { name: Ada, age: 30 }
p == q: true
p == r: false
```

### Derives that aren't protocols: `Json`

Not everything a record derives is one of the five protocols.
There are two more derives, of a different nature: `Layout`,
which fixes a record's byte order for binary serialization
(you'll meet it in chapter 19), and `Json`, which maps the
record onto the JSON format.

`#[derive(Json)]` generates two things: `to_json`, which turns
your record into a JSON value, and a `<type>_of_json` shim, which
rebuilds it from one. It's the data boundary with the outside
world: APIs, config files, messages.

The generated code uses the JSON model that lives in
`encoding.json_bind`, so the deriving file has to import it.

```kai
# Listing 9.6 — examples/ch09/06_json.kai
import encoding.json.{json_decode, json_encode}
import encoding.json_bind

#[derive(Json)]
type Note = { title: String, priority: Int, tag: Option[String] }

fn main() : Unit / Stdout {
  let n = Note { title: "buy bread", priority: 1, tag: None }
  println(json_encode(to_json(n)))

  match json_decode("{\"title\":\"call back\",\"priority\":2}") {
    None    -> println("invalid json")
    Some(v) -> match note_of_json(v, "") {
      Ok(m)  -> println("#{m.title} (p#{m.priority})")
      Err(e) -> println(json_error_show(e))
    }
  }
}
```

```
$ kai run examples/ch09/06_json.kai
{"title":"buy bread","priority":1,"tag":null}
call back (p2)
```

The mapping rules are the ones you'd expect, and the compiler
applies them without asking. Field
names go to the wire verbatim — no case conversion. An `Option[T]`
field accepts an explicit `null` and a missing key alike — both
decode to `None`; **every other field is required**. Keys the
record does not declare are ignored. And if decoding fails, the
error carries the JSON path to the offending node
(`address.boxes[2].zip: expected String, got Number`), not a bare
"parse error".

When the outside world doesn't use your names, there are three
per-field overrides, each in its own attribute:

```kai
#[derive(Json)]
type Config = {
  #[json(rename = "user_name")] user: String,
  #[json(default = 3)]          retries: Int,
  #[json(skip)] #[json(default = false)] cached: Bool,
}
```

`rename` changes the name on the wire; `default = <expr>` supplies
a value when the key is missing (and makes that field optional);
`skip` drops the field from the wire entirely — and since there's
nothing to read on decode, it requires a `default` or an `Option`
type. A field needing two overrides (skipped and defaulted) is
written with two attributes, as above.

One limitation worth knowing up front: `#[derive(Json)]` works on
records, **not on sum types**. Encoding a tagged union is a
convention —does the tag live in a `"type"` key, a wrapper,
adjacent?— and the derive won't pick for you. For that,
`to_json`/`of_json` by hand.

## 9.5 Custom protocols

Nothing stops you from declaring your own protocols, with
the same syntax the stdlib uses:

```kai
protocol Drawable {
  draw(x: Self) : String
}

type Circle = { radius: Int }
type Square = { side: Int }
type Triangle = { base: Int, height: Int }

impl Drawable for Circle {
  fn draw(c: Circle) : String =
    "Circle of radius #{c.radius}"
}

impl Drawable for Square {
  fn draw(s: Square) : String =
    "Square of side #{s.side}"
}

impl Drawable for Triangle {
  fn draw(t: Triangle) : String =
    "Triangle #{t.base}x#{t.height}"
}
```

Now three different types share the operation `draw`,
which resolves statically: the compiler knows at each call
which `impl` to use from the type of the argument.

`Drawable` is a toy example; real cases you'll see in
kaikai code include `Encodable` for various formats,
`Loggable` so the logging system knows how to represent
your type, `Validable` for validation rules, etc. Any
"behavior several types share" is a candidate.

A custom protocol with three implementations, one per type:

```kai
# examples/ch09/04_own_protocol.kai
protocol Drawable {
  draw(x: Self) : String
}

# Three different types, three implementations.

type Circle = { radius: Int }

type Square = { side: Int }

type Triangle = { base: Int, height: Int }

impl Drawable for Circle {
  fn draw(c: Circle) : String =
    "Circle of radius #{c.radius}"
}

impl Drawable for Square {
  fn draw(s: Square) : String =
    "Square of side #{s.side}"
}

impl Drawable for Triangle {
  fn draw(t: Triangle) : String =
    "Triangle #{t.base}x#{t.height}"
}

fn main() {
  let c = Circle { radius: 5 }
  let s = Square { side: 3 }
  let t = Triangle { base: 4, height: 6 }

  println(draw(c))
  println(draw(s))
  println(draw(t))
}
```

```
$ kai run examples/ch09/04_own_protocol.kai
Circle of radius 5
Square of side 3
Triangle 4x6
```

## 9.6 Why no Haskell-style typeclasses

kaikai's protocols draw on Haskell typeclasses, but are
**deliberately simpler**. Three things Haskell does that
kaikai doesn't:

**No constraints in function signatures.** This is the most
visible difference. In Haskell, a function that sorts a list
declares that the element type must have `Ord`:

```haskell
sort :: Ord a => [a] -> [a]
```

The `Ord a =>` is the **constraint**. When you call `sort
xs`, the compiler looks up the `Ord` for the type of `xs` on
its own and "injects" it into the function without you
writing anything. The constraint travels hidden, and it
**propagates**: if `sort` calls another function that also
needs `Ord`, Haskell threads the lookup along on its own.

kaikai lets you write a bound in the signature — you'll see
it in §9.7 — but that bound is a **statement of intent**, not
a resolver traveling hidden. The difference shows when you
sort a list. In kaikai the function can take the
**comparator as an explicit argument**:

```kai
fn sort_by[T](xs: [T], cmp: (T, T) -> Int) : [T] = ...
```

And the call site **names** the comparator. If `Transaction`
implements `Ord`, its `cmp` is available as an ordinary
function, and you pass it:

```kai
list.sort_by(transactions, cmp)   # cmp comes from impl Ord for Transaction
```

It's little to type, but the conceptual difference is big:
what travels implicitly in Haskell, you write in kaikai.
`sort_by` doesn't "demand" that `T` have `Ord`, only that
**someone pass it a comparison function**.
That this function comes from an `impl Ord for T` is the
caller's decision, not the signature's.

**No higher-kinded types** (HKT). `protocol Functor[F[_]]`
doesn't parse. Type parameters of protocols are first-order.
This rules out a family of abstractions (Functor, Monad,
Applicative, etc.) that in Haskell are central — and that in
kaikai are addressed with algebraic effects (chapter 12) and
explicit combinators.

**No constraint propagation**. A polymorphic function does
not "carry" `Ord` to the functions it calls. The bound in
§9.7 documents what *that* function asks for; it doesn't
propagate on its own to the functions it invokes.

These restrictions buy you three things:

- **Fast compilation**. Type inference stays
  Hindley-Milner extended with effects, no Haskell-style
  constraint solver overhead.
- **Clear errors**. If a function needs `Ord` and doesn't
  receive it, the error points at the site missing the
  comparator. There are no chains of "no instance for `Ord
  (Maybe a)` because of `Ord a`".
- **The call site says what it does**. When you see
  `list.sort_by(xs, cmp)`, you know it's sorted with `cmp`.
  When you see `sort xs` in Haskell, you have to look at
  `sort`'s signature to know which `Ord` is used.

In exchange, you lose some abstractions that are elegant in
Haskell — particularly everything that lives over Functor
and friends. I made that trade-off with my eyes open: the
abstractions I wanted to prioritize live in the effect system
(chapter 12), not in the type system.

## 9.7 Protocol bounds on generic functions

So far protocols showed up in the `impl` that implements
them and the call site that calls an operation. There's a
third place: a generic function over some `T` can **require
that `T` implement a protocol**, and say so in the signature:

```kai
fn show_two[T: Show](a: T, b: T) : String =
  "#{show(a)} and #{show(b)}"
```

The bound `[T: Show]` reads "for any `T` that implements
`Show`". Inside the body, the protocol's operations are
available: `show(a)` dispatches to the `impl Show` of
whatever concrete type arrives at each call.

```kai
fn main() : Unit / Stdout {
  Stdout.print(show_two(1, 2))      # 1 and 2
  Stdout.print(show_two("x", "y"))  # x and y
}
```

If you come from another language with generics, this rings
a bell. In Rust it's `where T: Trait`; in Java, a bounded
generic `<T extends Comparable>`. The idea is the same — a
type parameter that isn't "anything" but "anything that
satisfies this contract" — except in kaikai the contract is a
protocol.

Bounds stack with `+` when the body uses more than one
protocol, and each type parameter carries its own:

```kai
fn label[T: Show + Eq](a: T, b: T) : String =
  if eq(a, b) { "equal: #{show(a)}" }
  else { "#{show(a)} and #{show(b)}" }

fn pair[T: Show, U: Show](a: T, b: U) : String =
  "#{show(a)}, #{show(b)}"
```

It works with any protocol, stdlib or your own. A function
that takes the `larger` of two values asks for `Ord`; one
that renders asks for your `Drawable`:

```kai
fn larger[T: Ord](a: T, b: T) : T = max(a, b)
fn render[T: Drawable](x: T) : String = "[" ++ draw(x) ++ "]"
```

Read carefully, because this is where kaikai parts ways with
Haskell even though the syntax looks alike. The bound is a
**statement of intent**, not the propagating constraint of
§9.6: the compiler doesn't resolve a dictionary and inject
it. Each call monomorphizes the function to the concrete
type, and there `show`, `eq`, or `cmp`
resolve to the matching `impl` — the same static dispatch as
always. The bound documents the contract in the signature and
makes the error, when a type doesn't implement the protocol,
clear: `no impl of 'Ord' for type 'X'`.

It's the natural next step from a generic over a bare `T`:
from "this function works for any type" to "this function
works for any type that knows how to `show`". Without
Haskell's implicit resolver or its propagation, the bound
leaves the contract written where it's read, which is almost
always what you wanted.

The three shapes of bound in one program: one from the stdlib,
one of your own, and one demanding two protocols at once.

```kai
# examples/ch09/05_bounds.kai
protocol Drawable {
  draw(x: Self) : String
}

type Circle = { radius: Int }

impl Drawable for Circle {
  fn draw(c: Circle) : String = "circle of radius #{show(c.radius)}"
}

fn larger[T: Ord](a: T, b: T) : T = max(a, b)

fn render[T: Drawable](x: T) : String = "[" ++ draw(x) ++ "]"

fn label[T: Show + Eq](a: T, b: T) : String =
  if eq(a, b) {
    "equal: #{show(a)}"
  } else {
    "#{show(a)} and #{show(b)}"
  }

fn main() : Unit / Stdout {
  Stdout.print(show(larger(3, 7)))
  Stdout.print(show(larger("a", "b")))
  Stdout.print(render(Circle { radius: 5 }))
  Stdout.print(label(1, 1))
  Stdout.print(label(2, 9))
}
```

```
$ kai run examples/ch09/05_bounds.kai
7
b
[circle of radius 5]
equal: 1
2 and 9
```

## 9.8 Operators: `+`, `==`, `<` as protocols

Standard operators **are** protocols. `==` is `Eq.eq`, `<` is
comparison based on `Ord.cmp`, `+` is `Add.add`. When you
declare `impl Eq for Account`, automatically `a1 == a2` (with
`a1, a2 : Account`) calls your implementation.

```kai
#[derive(Eq)]
type Point = { x: Int, y: Int }

fn main() {
  let p = Point { x: 3, y: 4 }
  let q = Point { x: 3, y: 4 }
  if p == q { println("equal") }   # uses derived Eq.eq
}
```

This unifies syntax: `+` for `Int`, `Real`, vectors,
matrices, money — all those that have `impl Add for ...`.
`==` for everything that has `Eq`. That uniformity is the
first benefit of having a single mechanism for "operations
dispatched by type".

Operators kaikai treats as protocols:

| Operator | Protocol | Op |
|---|---|---|
| `==`, `!=` | `Eq` | `eq` |
| `<`, `<=`, `>`, `>=` | `Ord` | `cmp` |
| `+`, `-`, `*`, `/` | `Add`, `Sub`, `Mul`, `Div` | `add`, `sub`, `mul`, `div` |
| `++` | `Concat` | `concat` |

Primitive types implement them all; yours do once you write
the `impl`. When an operator doesn't make sense for a type,
you don't implement it, and the compiler rejects the
expression.

## Exercises

**9.1.** Define `type Distance = { meters: Int }` and give
it an `impl Show` so `show(d)` produces `"42 m"`. Then test
`println("the distance is #{d}")` and confirm interpolation
picks up your `impl Show` automatically.

**9.2.** Define `type Card = { suit: String, value: Int }`
and give it `impl Ord` ordering by `value`. Verify with
three cards that `cmp(c1, c2)` returns the expected
numbers.

**9.3.** Take any record from earlier chapters and add
`#[derive(Show, Eq)]` above the declaration. Verify that
`show` and `eq` work without you writing anything else.

**9.4.** Declare your own protocol `Validable` with an
operation `validate(x: Self) : Result[Self, String]`
returning `Ok(x)` if the value is valid or `Err("reason")`
otherwise. Implement `Validable` for `type Age = { years:
Int }` so it rejects negative ages or those above 130.

**9.5.** Read the stdlib code in `stdlib/protocols.kai`.
How many operations does `Hash` have? How would it be
used to implement a hash table of `Account`? Design the
signature of the function you'd write to "look up an
account by id" in a hypothetical hash table — what would
need to be implemented in `Account` for it to work?
