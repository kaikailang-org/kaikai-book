# Chapter 9 · Protocols

So far you've seen how to group data (records, sum types)
and how to define functions over it. What's missing is a
concrete question: **how do you add operations to a type
from outside its declaration?**

For example: `Point` is a record with two fields. You want
it to print as `(3, 4)` when it appears in interpolation.
Do you modify the type? Pass a function to `println`?
Define a `println` variant just for `Point`? None of these
scale.

kaikai's answer is **protocols**: a named contract with a
small set of operations, that any type can satisfy.
Conceptually, protocols do what **interfaces** do in Go,
**traits** in Rust, **protocols** in Clojure and Elixir, and
the easy part of **typeclasses** in Haskell. But kaikai
picks a precise point in the design space:
**single-dispatch, explicit, no constraint propagation, no
higher-kinded types**. That removes complexity from the
type system at the cost of some things you can't express —
and this chapter covers both sides.

## 9.1 Why protocols exist

Three concrete pains protocols solve.

**Printing your types without writing it each time.** When
you declare a record, wanting to print it in logs, responses,
errors should not cost you a `user_to_string` function per
type. With `Show` implemented once, interpolation
`"#{user}"` uses it automatically.

**Structural equality without effort.** Any new type needs
"this equals that" at some point. Without protocols, you
write `eq_point`, `eq_account`, `eq_invoice`, and spend the
rest of the project remembering which name you used in which
file. With `Eq`, the operation is called `eq` for all of
them.

**Comparison, hashing, serialization.** Same argument as the
previous one, multiplied by the three standard operations almost
every type needs eventually.

Without protocols, each of the three is solved with naming
conventions case by case, or with huge `match`es enumerating
each possible type. With one mechanism, the three (and the
ones to come) are solved in one line per type.

## 9.2 Declaring a `protocol` and `impl`

The syntax is direct. A protocol declares a name and one or
more operations:

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
    "(" ++ int_to_string(p.x) ++ ", " ++ int_to_string(p.y) ++ ")"
}
```

And from then on, `show(p)` calls your implementation when
`p : Point`:

```kai
fn main() {
  let p = Point { x: 3, y: 4 }
  println(show(p))                # prints "(3, 4)"
  println("p is at #{p}")         # interpolation: uses Show
}
```

Three details worth pinning down:

- **The body of the `impl` lists the protocol's functions one
  by one**, with the standard `fn` syntax. Each `fn` in the
  block must match the signature declared in the `protocol`,
  with `Self` substituted by the concrete type.

- **One implementation per (protocol, type) pair.** If two
  `impl Show for Point` appear in the same compilation, the
  compiler rejects with "duplicate impl". No overriding, no
  contextual resolution.

- **The orphan rule**: you can only implement a protocol `P`
  for a type `T` if `P` is declared in your module **or** `T`
  is declared in your module. This prevents two external
  packages from defining conflicting impls for types they
  both import. It's a practical limitation, not a type-system
  one.

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
already have implementations for the five protocols. When you
declare a new type, you choose which protocols are worth
implementing for it.

`Ord` is worth a note: it has **three operations**, not one.
`cmp(a, b) : Int` returns a negative integer if `a < b`, zero
if equal, positive if `a > b`. The other two — `min(a, b)`
and `max(a, b)` — return one of the two arguments according
to ordering. The three are implemented together in the same
block:

```kai
impl Ord for Account {
  fn cmp(a: Account, b: Account) : Int =
    if a.balance < b.balance { 0 - 1 }
    else if a.balance > b.balance { 1 }
    else { 0 }

  fn min(a: Account, b: Account) : Account =
    if a.balance < b.balance { a } else { b }

  fn max(a: Account, b: Account) : Account =
    if a.balance > b.balance { a } else { b }
}
```

If implementing three operations of `Ord` feels like too much
work, hold on for §9.4: in many cases, the compiler derives
them for you.

## 9.4 `#[derive(...)]` and when to use it

For records where the obvious "delegate to each field"
implementation is enough, kaikai gives you a shortcut: the
`#[derive(...)]` directive before the type declaration.

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

The canonical format — `TypeName { field: value, ... }` — is
what `#[derive(Show)]` produces, and is reasonable for
debugging and logs. If you want a different format (say,
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

You already saw `#[derive(Show)]` over `Point` in the tour
(§1.6); here we show the manual implementation too and when
each form pays off.

### Derives that aren't protocols: `Json`

Not everything a record derives is one of the five protocols.
There are two more derives, of a different nature: `Layout`, which
fixes a record's byte order for binary serialization (we see it in
chapter 19), and `Json`, which weaves the record into the JSON
format.

`#[derive(Json)]` generates two things: `to_json`, which turns
your record into a JSON value, and a `<type>_of_json` shim, which
rebuilds it from one. It's the data boundary with the outside
world: APIs, config files, messages.

```kai
# Listing 9.6 — examples/ch09/06_json.kai
import encoding.json.{json_decode, json_encode}

#[derive(Json)]
type Note = { title: String, priority: Int, tag: Option[String] }

fn main() : Unit / Stdout = {
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

The mapping rules are the ones you'd expect, and worth having
straight because the compiler applies them without asking. Field
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

The five from the stdlib are the most common, but nothing
prevents you from declaring your own. It's exactly the same
syntax the stdlib uses, but in your code:

```kai
protocol Drawable {
  draw(x: Self) : String
}

type Circle = { radius: Int }
type Square = { side: Int }
type Triangle = { base: Int, height: Int }

impl Drawable for Circle {
  fn draw(c: Circle) : String =
    "Circle of radius " ++ int_to_string(c.radius)
}

impl Drawable for Square {
  fn draw(s: Square) : String =
    "Square of side " ++ int_to_string(s.side)
}

impl Drawable for Triangle {
  fn draw(t: Triangle) : String =
    "Triangle " ++ int_to_string(t.base) ++ "x" ++ int_to_string(t.height)
}
```

From then on, three different types share the operation
`draw`. The polymorphic function `draw` resolves
statically: the compiler knows in each call which `impl` to
use from the type of the argument.

`Drawable` is a toy example; real cases you'll see in
kaikai code include `Encodable` for various formats,
`Loggable` so the logging system knows how to represent
your type, `Validable` for validation rules, etc. Any
"behavior several types share" is a candidate.

## 9.6 Why no Haskell-style typeclasses

kaikai's protocols may resemble Haskell typeclasses — and
draw inspiration from them — but are **deliberately
simpler**. Three things kaikai doesn't do that Haskell does:

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

The difference is small to write but big conceptually: in
Haskell the `Ord` is implicit, in kaikai it's explicit. The
function `sort_by` doesn't "demand" `T` to have `Ord` — it
demands that **someone pass it a comparison function**.
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

What do you gain with these restrictions? Three things:

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

What do you lose? Some abstractions that are elegant in
Haskell — particularly everything that lives over Functor
and friends. That trade-off is deliberate: the abstractions
kaikai prioritizes live in the effect system (chapter 12),
not in the type system.

## 9.7 Protocol bounds on generic functions

So far protocols showed up in two places: the `impl` that
implements them and the call site that calls an operation.
There's a third. A generic function over some `T` can
**require that `T` implement a protocol**, and write it in
the signature:

```kai
fn show_two[T: Show](a: T, b: T) : String =
  "#{show(a)} and #{show(b)}"
```

The bound `[T: Show]` reads "for any `T` that implements
`Show`". Inside the body, the protocol's operations are
available: `show(a)` dispatches to the `impl Show` of
whatever concrete type arrives at each call.

```kai
fn main() : Unit / Stdout = {
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

Now read carefully, because this is where kaikai parts ways
with Haskell even though the syntax looks alike. The bound is
a **statement of intent**, not the propagating constraint of
§9.6. The compiler doesn't resolve a dictionary and inject
it: what happens is that each call monomorphizes the function
to the concrete type, and there `show`, `eq`, or `cmp`
resolve to the matching `impl` — the same static dispatch as
always. The bound documents the contract in the signature and
makes the error, when a type doesn't implement the protocol,
clear: `no impl of 'Ord' for type 'X'`.

This is the natural evolution of a generic over some bare
`T`: from "this function works for any type" to "this
function works for any type that knows how to `show`". The
bound doesn't give you Haskell's implicit resolver or its
propagation; it gives you the contract written where it's
read, which is almost always what you wanted.

## 9.8 Operators: `+`, `==`, `<` as protocols

A practical note: standard operators **are** protocols. `==`
is `Eq.eq`, `<` is comparison based on `Ord.cmp`, `+` is
`Add.add`. When you declare `impl Eq for Account`,
automatically `a1 == a2` (with `a1, a2 : Account`) calls
your implementation.

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
`==` for everything that has `Eq`. The uniformity isn't
accidental; it's the first benefit of having a single
mechanism for "operations dispatched by type".

Operators kaikai treats as protocols:

| Operator | Protocol | Op |
|---|---|---|
| `==`, `!=` | `Eq` | `eq` |
| `<`, `<=`, `>`, `>=` | `Ord` | `cmp` |
| `+`, `-`, `*`, `/` | `Add`, `Sub`, `Mul`, `Div` | `add`, `sub`, `mul`, `div` |
| `++` | `Concat` | `concat` |

Primitive types implement them all. Your types implement
them when you declare them. And when an operator doesn't
make sense for a type, you simply don't implement it — and
the compiler rejects that expression.

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
