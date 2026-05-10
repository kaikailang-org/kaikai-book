# Chapter 4 · Compound Types

The seven primitives from chapter 3 give you raw pieces. To
build real programs, you glue them into structures: aggregates
with named fields, lists, tuples, and the two stdlib gems you
will see more than any other type, `Option` and `Result`.

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
  if they have the same shape. This is on purpose: if you
  want a position, say position.

- **Spread has rules.** Only one spread per literal, and it
  must come first — `Point { x: 7, ...p }` is a parse error.
  The initializers that follow must be named (`x: expr`), not
  punned or positional. These are deliberate: they make it
  obvious who wins on a duplicate.

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

kaikai also has **range literals**, sugar that produces a
list:

```kai
let r1 = [1..10]        # [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
let r2 = [1..10..2]     # [1, 3, 5, 7, 9]
let r3 = [10..1..-1]    # [10, 9, 8, ..., 1]
```

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
code points; an accented letter may have one or two
representations; a grapheme can skip bytes and code points
arbitrarily. Treating a string as a list of chars forces a
decision about what counts as "a character" — and every
decision is wrong for some case.

kaikai makes the `String` **opaque**: the operations that
make sense are exposed in the `string` module of the stdlib
(`length`, `starts_with`, `ends_with`, `trim`, `repeat`,
`join`) and we don't conflate text with lists.
`string.length(s)` counts **bytes**, not characters or
graphemes. For `"á"` it returns 2 (because "á" in UTF-8 takes
two bytes); for `"☃"` it returns 3. It's a conscious choice:
the internal representation of a string is UTF-8, and kaikai
prefers a predictable and cheap answer over a philosophically
correct but expensive one. If you need to count graphemes or
logical characters, you use module functions that explicitly
decode Unicode with its subtlety.

For concatenation, you saw it in chapter 3: use `++`:

```kai
let greeting = "Hello, " ++ name
```

For interpolation, `#{...}` inside a literal `"..."`.

## 4.5 `Option` and `Result`: the daily tools

You saw these two in chapter 2:

```kai
type Option[a] = None | Some(a)
type Result[e, a] = Err(e) | Ok(a)
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

fn parse_age(s: String) : Result[AgeError, Int] =
  match string_to_int(s) {
    None -> Err(NotNumeric)
    Some(n) ->
      if n < 0 or n > 130 { Err(OutOfRange) }
      else { Ok(n) }
  }
```

`Result[AgeError, Int]` reads as "an `Int` or an error of
type `AgeError`". The error is in the first parameter and the
successful value in the second, the opposite of the convention
some languages use — kaikai follows Haskell on this point.

Three patterns you'll see often:

- **Chain a failure with `!`.** If you have an expression that
  returns `Result[E, A]` and you want "if it fails, propagate
  the error; otherwise continue with the value", you write
  `expr!`. You saw this in §2.3.
- **Higher-order functions**: `option.map`, `option.and_then`,
  `result.map_err`. We cover them in chapter 6.
- **Convert between the two**: `option.ok_or(error)` takes an
  `Option[a]` and an error of type `e` and returns a
  `Result[e, a]`. Useful when the information lost by `None`
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
