# Chapter 4 · Compound Types

The seven primitives from chapter 3 give you raw pieces. To
build real programs, you glue them into structures: aggregates
with named fields, lists, tuples, and the two stdlib types you'll
reach for more than any other, `Option` and `Result`. If I had to
keep a single stdlib decision, I'd keep those two. They are the
ones that have saved me the most bugs.

This chapter covers all of that. **Sum types** (`type Tag =
Foo | Bar(Int)`) you saw in the tour deserve their own chapter
and we treat them in chapter 5.

## 4.1 Records

A **record** is an aggregate with named fields. You declare it
with `type` and braces:

```kai
type Point = { x: Int, y: Int }

type Employee = {
  name: String,
  age: Int,
  salary: Int,
}
```

The trailing comma on the last field is optional but
idiomatic: it means adding a new field doesn't touch the
previous line, which keeps git diffs clean.

To build a record value, you write the type name followed by
braces with the fields:

```kai
let origin = Point { x: 0, y: 0 }
let p      = Point { x: 3, y: 4 }
let ada    = Employee { name: "Ada", age: 30, salary: 1500 }
```

To read a field, you use `.`:

```kai
println("p is at (#{p.x}, #{p.y})")
println("#{ada.name} is #{ada.age}")
```

That's enough for the day-to-day. Three details worth pinning
down:

- **Records are immutable.** `p.x = 7` does not exist. If you
  need a point with one different field, you build a new one
  with the **spread** sugar:

  ```kai
  let p  = Point { x: 3, y: 4 }
  let p2 = Point { ...p, x: 7 }    # Point { x: 7, y: 4 }
  ```

  `...p` copies all fields of `p`; the named initializers
  after it (here `x: 7`) override what they repeat. It's the
  same idea as list spread (see §4.3) applied to records.

- **Records are nominal.** `Point { x: Int, y: Int }` and
  another `Position { x: Int, y: Int }` with the same fields
  are distinct types. The compiler doesn't conflate them even
  if they have the same shape. I wanted it that way: if you
  want a position, say position.

- **Spread has rules.** Only one spread per literal, and it
  must come first — `Point { x: 7, ...p }` is a parse error.
  The initializers that follow must be named (`x: expr`), not
  punned or positional. These are deliberate: they make it
  obvious who wins on a duplicate.

### 4.1.1 Private fields

Record fields are public by default: any module that imports
the type can read them and name them when constructing a
literal. The `priv` keyword in front of a field name flips
that default:

```kai
# module `safe`
pub type Account = {
  name:         String,    # public by default
  priv balance: Real,      # private to module `safe`
}

pub fn open(name: String) : Account =
  Account { name: name, balance: 0.0 }

pub fn deposit(a: Account, amount: Real) : Account =
  Account { ...a, balance: a.balance + amount }

pub fn balance_of(a: Account) : Real = a.balance
```

From inside the `safe` module, the `balance` field reads and
writes like any other. From outside, it doesn't:

```kai
import safe

fn main() {
  let a = safe.open("savings")
  println("#{a.name}")            # OK, `name` is public
  println("#{safe.balance_of(a)}")  # OK, going through the getter

  # The next two lines don't compile:
  # println("#{a.balance}")          # ← field `balance` is private to module `safe`
  # let d = safe.Account {            # ← cannot construct `Account` from outside …
  #   name: "x",
  #   balance: 1000.0,
  # }
}
```

The rule is strict: no external reads, no mention inside a
construction literal. If module `safe` wants a consumer to
create accounts, it exposes constructors (`open`) and
operations (`deposit`) that preserve the invariants; the
raw field stays hidden.

This turns a record into a lightweight abstract type: public
shape, interior under the author's control. We'll use this
in ch. 17 to hide the store actor's state, and in ch. 18 so
ledger balances can't be constructed from outside the domain
module.

## 4.2 Field access and destructuring

Accessing with `.` is fine for one or two fields. When you
need several at once, **destructuring** is cleaner:

```kai
fn distance_squared(a: Point, b: Point) : Int = {
  let Point { x: ax, y: ay } = a
  let Point { x: bx, y: by } = b
  let dx = ax - bx
  let dy = ay - by
  dx * dx + dy * dy
}
```

When the field names work as variables, you can drop the `:`
and just give the field name — binding the field to a variable
of the same name:

```kai
fn describe(p: Point) : String = {
  let Point { x, y } = p
  "(" ++ int_to_string(x) ++ ", " ++ int_to_string(y) ++ ")"
}
```

Destructuring works in `match` too. That's its most useful
form: deciding what to do **based on the specific values of
the fields**:

```kai
fn classify(p: Point) : String =
  match p {
    Point { x: 0, y: 0 } -> "origin"
    Point { x: 0, y: _ } -> "Y axis"
    Point { x: _, y: 0 } -> "X axis"
    Point { x, y }       -> "point at (#{x}, #{y})"
  }
```

The compiler checks exhaustiveness, just like with sum types:
remove the last arm and it stops compiling. Exhaustiveness
over `Int` fields is covered by the final `Point { x, y }`
arm, which matches any `Point`. Without that catch-all arm
the `match` is not total.

## 4.3 Lists

A list is an immutable, linked sequence of values of the same
type. The type is written with brackets around the element
type: `[Int]`, `[String]`, `[Point]`, `[[String]]` (list of
lists).

Building literals:

```kai
let primes = [2, 3, 5, 7, 11]
let empty : [Int] = []
```

kaikai also has **range literals**, which the type system
treats as just another list:

```kai
let r1 = [1..10]        # [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
let r2 = [1..10..2]     # [1, 3, 5, 7, 9]
let r3 = [10..1..-1]    # [10, 9, 8, ..., 1]
```

One cost detail worth knowing: the range is **lazy**. The
runtime stores it as three numbers (start, end, step), not ten
cells, and elements are generated only when something consumes
them. `[1..1_000_000] |> list.sum` never materializes a million
cells; to your code it is indistinguishable from the handwritten
list.

To extend an existing list, use `...` (spread):

```kai
let xs = [1, 2, 3]
let ys = [0, ...xs, 99]      # [0, 1, 2, 3, 99]
```

To take them apart, the patterns of `match`:

```kai
fn sum(xs: [Int]) : Int =
  match xs {
    [] -> 0
    [h, ...t] -> h + sum(t)
  }
```

`[]` matches the empty list. `[h, ...t]` matches any non-empty
list, binding `h` to the first element ("head") and `t` to the
rest ("tail"). These two patterns cover every possible case,
making the `match` exhaustive.

More specific patterns are also legal:

```kai
match xs {
  []                       -> "empty"
  [only]                   -> "one: #{only}"
  [first, second, ...]     -> "at least two"
}
```

The compiler requires you to cover all cases. If you write
just `[]` and `[h, ...t]`, it's enough for any list — but if
you want to single out "exactly one element", you write
`[only]` before the catch-all.

A language convention: if **the tail matters**, give it a
name — `[h, ...t]` and then use `t`. If **it doesn't**, write
`...` alone, no name — `[h, ...]`. It's the difference
between "I take the head, the rest I keep for later" and "I
take the head, the rest I discard". An invented name that
goes unused is visual noise; the bare form communicates intent
without forcing a name that adds nothing.

For indexed access, the stdlib exposes `list.nth`:

```kai
let first  = list.nth(xs, 0)    # Option[Int]
let third  = list.nth(xs, 2)    # Option[Int]
```

Notice the return type: **`Option[a]`**, not `a`. A linked
list does not guarantee that an index exists — if you ask for
element 99 of a list of three, there is no value to return.
The type forces you to consider it. This is consistent with
`Option` and `Result` (see §4.5): kaikai prefers to enclose
the possibility of failure in the type rather than abort at
runtime.

Two more things about indexed access. One: it is **`O(n)`** —
lists are linked, not indexed; walking to position `i` costs
`i` steps. For fast random access kaikai has `Array[T]`,
which we cover in chapter 13.

The other: the syntax `xs[i]` that some languages use for
lists is reserved in kaikai for `Array[T]`. Writing it on a
list is a type error. The reason is the same: `xs[i]` suggests
cheap, guaranteed access, which would be lying about a linked
list.

For most code, you don't want to index by hand anyway.
Recursion over `[h, ...t]` or the higher-order functions of
chapter 6 (`map`, `filter`, `reduce`) are the natural way to
process lists.

Lists are **immutable**. There is no `xs[0] = 99`. If you
need a modified list, you build a new one.

## 4.4 Strings, not lists of chars

Worth pausing on something many languages mix up: in kaikai,
**a `String` is not a list of `Char`**. They are distinct
types:

```kai
let s : String = "hi"
let cs : [Char] = ['h', 'i']
```

`s` and `cs` are not interchangeable. You can't write `s[0]`
expecting a `Char`, and you can't pass a `String` where
`[Char]` is expected.

Why? Because in Unicode there is no simple correspondence
between "character" and "index". An emoji can occupy several
codepoints; an accented letter may have one or two
representations; a grapheme can skip bytes and codepoints
arbitrarily. Treating a string as a list of chars forces a
decision about what counts as "a character" — and every
decision is wrong for some case.

Internally, a `String` is a UTF-8 buffer. The operations
that make sense live in the `string` module of the stdlib, and
there kaikai is deliberate about a distinction many languages
paper over: the difference between **bytes** and **Unicode
codepoints**. They are not the same thing the moment you leave
ASCII, and each function's name tells you which unit it works in.

- `length(s)` (and its explicit synonym `byte_length(s)`) counts
  **bytes**, in O(1). For `"á"` it returns 2, because "á" takes
  two bytes in UTF-8; for `"☃"`, 3.
- `char_count(s)` counts **Unicode codepoints** — the honest
  length in characters. For `"á"` it returns 1; for `"☃"`, also 1.
- `chars(s)` decodes the buffer and returns the **codepoints** as
  `[Char]`. `bytes(s)` returns the **bytes** as `[Char]`, one per
  byte (a multibyte codepoint is split into its bytes).

```kai
import core.string
import core.list

fn main() {
  let s = "café"
  println("bytes:      #{string.length(s)}")              # 5
  println("codepoints: #{string.char_count(s)}")          # 4
  println("chars:      #{list.length(string.chars(s))}")  # 4
  println("bytes list: #{list.length(string.bytes(s))}")  # 5
}
```

```
$ kai run examples/ch04/07_strings.kai
bytes:      5
codepoints: 4
chars:      4
bytes list: 5
```

The mental rule is short: **`length` and `slice` reason in bytes;
`char_count` and `chars` reason in codepoints.** That `length` is
cheap and byte-based I decided deliberately — the representation is
UTF-8 and the `slice`/`char_at` family indexes by byte, so
`length` reports the unit those cuts use. When what you care about
is the character count rather than the byte count, you ask for
`char_count` or `chars` and kaikai pays the cost of decoding.
(Graphemes like an "é" built from `e` plus a combining accent are
yet another layer; there even codepoints fall short, but you rarely
need them.)

The same care shows up in case folding. `core.char` ships
`to_upper`, `to_lower`, `is_upper` and `is_lower` for ASCII. Since
0.109 its sibling `core.char_unicode` extends all four to the
alphabets whose mapping is a uniform codepoint offset: Latin-1,
Latin Extended-A, Greek and Cyrillic. Whatever falls outside that
rule passes through untouched, and kaikai would rather tell you so
in the module's name than pretend to full Unicode coverage:

```
$ kai run examples/ch04/10_case_folding.kai
CAFÉ
ПРИВЕТ
OMEGA
ΩΜΕΓΑ
ΩΜέΓΑ
☃ 42
K
```

The `ΩΜέΓΑ` line marks the edge: `ωμεγα` folds whole, while in
`ωμέγα` the `έ` stays down, because its uppercase form does not sit
at a fixed offset. Full Unicode folding needs tables, and those do
not live in the stdlib yet.

For concatenation, you saw it in chapter 3: use `++`:

```kai
let greeting = "Hello, " ++ name
```

For interpolation, `#{...}` inside a literal `"..."`.

`++` is fine for joining two or three pieces. But beware of
building a large string by gluing fragments in a loop: because a
`String` is immutable, every `++` copies the whole accumulator to
produce a new one, which lands you in O(n²) — the classic
quadratic of concatenation. That is what `StringBuilder` is for: a
text accumulator that holds the fragments as you add them and only
joins them at the end, in a single pass, with `build`. Appending is
amortized O(1), and the whole assembly is O(n).

```kai
import string_builder
import core.list

fn join(names: [String]) : String = {
  let sb = list.foldl(names, string_builder.new(),
                      (b, n) => string_builder.append(b, "#{n}, "))
  string_builder.build(sb)
}
```

```
$ kai run examples/ch04/09_string_builder.kai
ana, ben, cleo,
```

`append` rides the `Mutable` effect — internally it writes into
the builder's fragment array — while `build` is pure: it only reads
and joins. Notice that `join` declares no `/ Mutable` in its
signature even though it drives `append`: since the builder is born
and dies inside, never escaping, kaikai *masks* the effect at the
function boundary. The rest of the API (`new`, `with_capacity`,
`append_char`, `len`, `is_empty`) is in `kai doc string_builder`.

## 4.5 `Option` and `Result`: the daily tools

You saw these two in chapter 2:

```kai
type Option[a] = None | Some(a)
type Result[a, e] = Ok(a) | Err(e)
```

Here we look at them in use. They are two generic sum types
from the stdlib that you will use **constantly**. A reminder
of the idea: `Option` represents "there might be no value";
`Result`, "there might be a value or an error".

A function that finds the first even element of a list:

```kai
fn first_even(xs: [Int]) : Option[Int] =
  match xs {
    [] -> None
    [h, ...t] -> if h % 2 == 0 { Some(h) } else { first_even(t) }
  }
```

And the caller has to consider both cases explicitly:

```kai
match first_even(xs) {
  Some(n) -> println("found: #{n}")
  None    -> println("no evens")
}
```

A function that parses an age from a string can fail in two
distinct ways — and that's exactly what `Result` is for:

```kai
type AgeError = NotNumeric | OutOfRange

fn parse_age(s: String) : Result[Int, AgeError] =
  match string_to_int(s) {
    None -> Err(NotNumeric)
    Some(n) ->
      if n < 0 or n > 130 { Err(OutOfRange) }
      else { Ok(n) }
  }
```

`Result[Int, AgeError]` reads as "an `Int` or an error of
type `AgeError`". The successful value is in the first parameter
and the error in the second, as in Rust and most modern
languages.

Three patterns you'll see often:

- **Chain a failure with `!`.** If you have an expression that
  returns `Result[A, E]` and you want "if it fails, propagate
  the error; otherwise continue with the value", you write
  `expr!`. You saw this in §2.3.
- **Higher-order functions**: `option.map`, `option.and_then`,
  `result.map_err`. We cover them in chapter 6.
- **Convert between the two**: `option.ok_or(error)` takes an
  `Option[a]` and an error of type `e` and returns a
  `Result[a, e]`. Useful when the information lost by `None`
  isn't enough.

`Option` and `Result` are sum types like any other. We've
separated them from chapter 5 because their role in
day-to-day design is central — you'll use them before you
start declaring your own sum types.

## 4.6 Tuples

A tuple is a **positional** aggregate: like a record, but
without field names. The syntax is parentheses with elements:

```kai
let point2d = (3, 4)
let trio    = ("Ada", 30, true)
```

The type is written the same way: `(Int, Int)`, `(String,
Int, Bool)`.

kaikai admits tuples of **arity 2 to 4**. There are no
1-element tuples — a single parenthesis, `(e)`, is grouping,
not a tuple. And `(a, b, c, d, e)` is a parse error.

Why the bound? Because long tuples are unreadable. If you're
hitting 5 elements, almost always what you wanted was a
record with named fields.

To take a tuple apart, destructuring:

```kai
fn divmod(a: Int, b: Int) : (Int, Int) = (a / b, a % b)

fn main() {
  let (quotient, remainder) = divmod(17, 5)
  println("17/5 = #{quotient}, remainder #{remainder}")
}
```

Internally, tuples are sugar over three records from the
stdlib: `Pair[A, B]` for arity 2, `Triple[A, B, C]` for 3,
`Quad[A, B, C, D]` for 4. The declaration

```kai
let p = (1, 2)
```

is exactly equivalent to

```kai
let p = Pair { fst: 1, snd: 2 }
```

This is useful to know when you see a type `Pair[Int, String]`
in a stdlib signature: now you know it's the same as
`(Int, String)`, and you can destructure it with
`let (a, b) = p`.

### Tuple or record?

When in doubt, **use a record**. Tuples are convenient for
cases where names don't add — the result of `divmod`, where
"the first value is the quotient and the second the
remainder" is information the reader already gets from the
function name. Or when the aggregate lives one step:

```kai
xs |> map((e) => (e.name, e.age))
```

But as soon as the same aggregate appears more than once, or
crosses a module boundary, or its shape is something the
reader can't deduce, prefer a record. An `Employee` is much
easier to read than a `(String, Int, Bool, String, Int)`.

## 4.7 Hash maps and sets

Everything we've seen so far is immutable: a new record
doesn't mutate the old one, a list with one more element is a
new list. For most code that's exactly what you want. But
sometimes you need a real associative table — insert and look
up by key in near-constant time — and building a fresh record
on every insertion won't cut it. For that the stdlib ships two
**mutable** structures: `HashMap[k, v]`, which maps keys to
values, and `HashSet[a]`, a set with no duplicates.

That they're mutable shows up in the effect row: their
operations yield `Mutable`. If you come from Python or Java, a
dictionary that changes in place feels obvious; what's new here
is that the language says so in the type. A function that
touches a `HashMap` carries `/ Mutable` in its signature, and
the compiler makes you declare it. That's not red tape: it's
the same honesty as every other effect. Immutability is still
the default; mutation is there, marked.

Key access uses indexing, `m[key]`, which returns an `Option`
— `Some(v)` if the key is present, `None` if it isn't — so a
missing key never blows up in your face:

```kai
import collections.hashmap as hashmap

let current = match m[w] {
  Some(n) -> n
  None    -> 0
}
hashmap.put(m, w, current + 1)
```

A full example: count how often each word in a list appears,
first with a `HashMap`, and along the way use a `HashSet` to
count how many distinct words there are.

```kai
import collections.hashmap as hashmap
import collections.hashset as hashset

fn word_frequencies(words: [String]) : hashmap.HashMap[String, Int] / Mutable = {
  let m = hashmap.empty()
  count(m, words)
  m
}

fn count(m: hashmap.HashMap[String, Int], words: [String]) : Unit / Mutable = match words {
  []           -> ()
  [w, ...rest] -> {
    let current = match m[w] { Some(n) -> n  None -> 0 }
    hashmap.put(m, w, current + 1)
    count(m, rest)
  }
}

fn main() : Unit / Stdout + Mutable = {
  let text = ["sun", "sea", "sun", "wind", "sea", "sun"]
  let m = word_frequencies(text)
  match m["sun"] {
    Some(n) -> Stdout.print("sun appears #{n} times")
    None    -> Stdout.print("sun does not appear")
  }
  Stdout.print("distinct words: #{hashmap.size(m)}")

  # A HashSet drops duplicates on insertion.
  let seen = hashset.empty()
  mark(seen, text)
  Stdout.print("unique via set: #{hashset.size(seen)}")
}

fn mark(s: hashset.HashSet[String], words: [String]) : Unit / Mutable = match words {
  []           -> ()
  [w, ...rest] -> { hashset.add(s, w); mark(s, rest) }
}
```

```
$ kai run examples/ch04/08_maps.kai
sun appears 3 times
distinct words: 3
unique via set: 3
```

`hashmap.put` inserts or replaces in place; `hashmap.get` is
the named form of `m[key]`; `size`, `keys`, `values`, `remove`
and `contains` round out the day-to-day. The `HashSet` is the
valueless face of the same idea: `add`, `contains`, `size`,
plus the set operations `union`, `intersection` and
`difference`. The full list, with signatures, comes out of
`kai doc collections/hashmap` and `kai doc collections/hashset`
(ch. 16 covers `kai doc`).

One note on order: neither the `HashMap` nor the `HashSet`
promises a traversal order. `keys`, `values` and `to_pairs`
hand you the elements in the internal bucket order, which is
not insertion order. If you need order, sort at the end or
reach for the stdlib's ordered structure (`Map`, built on an
AVL tree).

`Map` also compares by content: two maps holding the same
pairs are equal even when they were built by inserting in a
different order. That makes it the right structure when the
result leaves the function and something downstream will
compare it against an expectation. The bridge between the two
families lives in `collections/convert`: `convert.to_map(h)`
freezes a `HashMap` once the fast build is done, and
`convert.to_hashmap(m)` goes the other way.

## Exercises

**4.1.** Define a record `Book` with fields `title`, `author`
and `pages`. Write a function `fn short(b: Book) : Bool` that
returns `true` if the book has fewer than 200 pages. Build
two books and try the function.

**4.2.** Write `fn maximum(xs: [Int]) : Option[Int]` returning
the largest element of the list, or `None` if the list is
empty. Use recursion and `match`.

**4.3.** Rewrite `fn parse_age` from §4.5 so it distinguishes
**three** errors: not numeric, negative age, age > 130. Use
a sum type with three constructors and a `Result`.

**4.4.** Define a function `fn split(xs: [Int]) : ([Int],
[Int])` returning a tuple with the evens and odds of `xs`,
each in original order. Why a tuple and not two return
values? And why a tuple and not a record?

**4.5.** Given a `[Point]` (with `Point = { x: Int, y: Int }`),
write `fn center(ps: [Point]) : Option[Point]` returning the
average of coordinates, or `None` if the list is empty. Hint:
you'll need two passes or an accumulator, and `int_to_real`
to average — but note the final result has to be a `Point`
with `Int` fields, so you'll also need `real_to_int` (or
settle for the integer part).

**4.6.** On paper, without writing code, draw what happens in
memory when you run these three lines:

```kai
let xs = [1, 2, 3]
let ys = [0, ...xs]
let zs = [99, ...xs]
```

How many lists were created? How many elements were copied?
Are there cells that `xs`, `ys`, `zs` share? The answer
helps you understand why immutability isn't expensive when
the structures are linked.
