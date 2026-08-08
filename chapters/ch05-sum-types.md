# Chapter 5 · Sum types, unions, and `match`

This is the chapter where, if you come from an imperative
language, you change how you model data. Sum types and the
`match` that goes with them are not an exotic construction:
they are the tool that replaces half of the class hierarchies,
flag-based enums, `instanceof` chains and visitor patterns
you've probably been writing. Once you have them in hand, you
don't want to give them up. That is exactly what happened to me:
I came to the functional family late, with my head already shaped
by class hierarchies, and after sum types going back was uphill.

The chapter goes from less to more. We start with basic sum
types, pass through type recursion, see `match` with all its
forms, reach unions of existing types — an idea uncommon in
mainstream languages — and close with a complete arithmetic
expression evaluator with typed errors.

## 5.1 Sum types with `|`

A **sum type** declares that a value can be one of several
distinct constructors. The syntax is direct:

```kai
type Color = Red | Green | Blue
```

`Color` is a type. `Red`, `Green`, `Blue` are its three
**constructors**. A value of type `Color` is exactly one of
the three. There is no fourth hidden value, no `null`, no
"unknown color": the type enumerates its inhabitants and stops
there.

If you come from a language with `enum`, this looks similar —
with two differences: constructors **can carry data**, and
the compiler **verifies that you cover them all** when you
decide based on the constructor.

Start with the first. A constructor can take positional
parameters, like a record with numbered fields:

```kai
type Shape
  = Circle(Real)
  | Rectangle(Real, Real)
  | Triangle(Real, Real, Real)
```

`Circle(2.0)` is a `Shape` value with a real inside.
`Rectangle(3.0, 4.0)` is another `Shape` with two values.
`Triangle(3.0, 4.0, 5.0)` is a third. All three fall under
the same `Shape` type, but the compiler knows which is which
and forces us to handle them separately when we consume them.

```kai
fn area(s: Shape) : Real =
  match s {
    Circle(r)         -> 3.14159 * r * r
    Rectangle(w, h)   -> w * h
    Triangle(a, b, c) -> {
      let s = (a + b + c) / 2.0
      s
    }
  }
```

`match` is an expression that decides based on the
constructor. Each arm is a pattern followed by `->` and the
expression that arm produces. The patterns unpack the data at
the same time: in `Circle(r)`, `r` is the variable bound to
the `Real` that came inside the constructor. There is no
separate cast or indexed access; the pattern does the work.

Three details you'll use all the time:

- **The compiler checks exhaustiveness.** If you remove the
  `Triangle(...)` arm and the compiler knows `s : Shape` can
  be a triangle, it doesn't compile. This saves you from
  subtle bugs when you add a new constructor: every `match`
  that doesn't cover it becomes a compile error pointing
  exactly at the spot needing attention.

- **Constructors are names like any other.** When you declare
  `type Color = Red | Green | Blue`, kaikai creates four
  symbols: `Color` is the type, and `Red`, `Green`, `Blue`
  are simultaneously types (each with one inhabitant) and
  values. In chapter 9 we'll see how this lets you extend a
  sum type with protocols defined for individual constructors.

- **The `|` operator always means union of types.** We'll see
  more in §5.5: `Color = Red | Green | Blue`, `EvalError =
  ArithError | EnvError`, and `Result = Ok(Int) | Err(String)`
  are the same construction. The difference between
  "declaring new types" and "composing existing types" is
  decided by the compiler inspecting whether the names on the
  right are already declared.

## 5.2 Constructors with and without payload

You saw it above; let's pin it down. A constructor can:

- **Carry no data** (`Red`, `Green`, `Blue`). It is a unique
  value of the type, with no parameters.
- **Carry one or more positional values** (`Circle(Real)`,
  `Rectangle(Real, Real)`). The constructor is applied like a
  function to the data to produce the value.

There is no hard limit on how many values a constructor can
carry — the grammar accepts them all — but for ergonomics, if
you go past three or four positional values it pays to declare
a record and put it in the payload. The difference between

```kai
type Event
  = Login(String, String, Int, Bool)
  | Logout(String, Int)
```

and

```kai
type LoginData = { user: String, ip: String, timestamp: Int, success: Bool }
type LogoutData = { user: String, timestamp: Int }
type Event = Login(LoginData) | Logout(LogoutData)
```

is that the second reads better wherever you build or
destructure an event. The way I see it: if the data names
itself by position — a point is `(Real, Real)` — keep it
positional. If the data forces the reader to remember the
order, use a record.

## 5.3 Recursion in types

Now the construction earns its keep: a constructor of a sum
type can mention the type itself in its fields. That gives you
trees, lists, small graphs, and the representation of any
nested structure.

A binary tree:

```kai
type Tree
  = Leaf
  | Node(Int, Tree, Tree)
```

`Tree` is `Leaf` (no data) or `Node` with an integer and two
subtrees. The subtrees are `Tree` themselves, so they can
recursively be `Leaf` or `Node`, to whatever depth you want.

A function over a tree is also recursive: the base case is
`Leaf`, the recursive case descends into the children.

```kai
fn height(t: Tree) : Int {
  case Leaf            -> 0
  case Node(_, l, r)   -> 1 + max_int(height(l), height(r))
}
```

The pattern `Node(_, l, r)` ignores the node's data (we don't
care about it for height) and binds the two subtrees to `l`
and `r`. Then we recurse on each and take max plus one.

The same applies to an arithmetic expression AST:

```kai
type Expr
  = Lit(Int)
  | Add(Expr, Expr)
  | Mul(Expr, Expr)
  | Neg(Expr)

fn eval(e: Expr) : Int =
  match e {
    Lit(n)    -> n
    Add(a, b) -> eval(a) + eval(b)
    Mul(a, b) -> eval(a) * eval(b)
    Neg(x)    -> -eval(x)
  }
```

Building an expression is transparent: `Mul(Neg(Add(Lit(2),
Lit(3))), Lit(4))` is the literal representation of `-(2 + 3)
* 4`, which evaluates to `-20`. The tree and the code that
walks it write themselves once you know how to look at it
this way.

This replaces class hierarchies with visitor patterns in OO
languages. The key difference: in kaikai, adding a new node
to `Expr` is one line, and every `match` over `Expr` in the
codebase becomes a compile error pointing at the spots that
need attention. In a visitor pattern, you add a new method
in each subclass and the compiler does not help you avoid
forgetting any.

## 5.4 `match`: patterns, guards, exhaustiveness

You've seen `match` in action. Now we formalize.

A `match` takes a **scrutinee expression** (what's being
inspected) and a series of **arms**, each with a **pattern**
followed by `->` and the expression that arm produces. The
arm whose pattern matches the value of the scrutinee is the
one that runs; its value is the value of the `match`.

Patterns kaikai accepts:

- **Literals**: `0`, `"hi"`, `true`. Match the exact value.
- **Constructors**: `Some(x)`, `Lit(n)`, `Add(a, b)`. Match
  the constructor and bind the data to variables.
- **Records**: `Point { x, y }`, `Point { x: 0, y: _ }`.
- **Lists**: `[]`, `[h, ...t]`, `[only]`, `[first, second,
  ...]`.
- **Wildcard**: `_`. Matches anything, binds nothing.
- **Variable**: any undeclared identifier. Matches anything
  and binds the value to that variable.

Patterns nest: `Some(Point { x, y })` matches a `Some` that
contains a `Point`, unpacking `x` and `y` in one pass.

### Guards

A pattern can be followed by `if` and a condition — a
**guard** — that's evaluated after the structural match. If
the guard is false, the arm doesn't apply and the next arm is
tried:

```kai
fn sign(n: Int) : String =
  match n {
    0           -> "zero"
    k if k > 0  -> "positive"
    _           -> "negative"
  }
```

The pattern `k if k > 0` matches any integer, binds it to
`k`, then evaluates `k > 0`. If true, runs the arm; otherwise
moves on. The final `_` arm has no guard and matches
everything else — integers that are neither zero nor
positive.

Guards are convenient but don't participate in the
exhaustiveness check: the compiler can't know that `k > 0`
and `k < 0` complement each other, so it needs a final
guardless pattern that covers "everything else". If you omit
it, it doesn't compile.

### Exhaustiveness

The compiler verifies that **every possible inhabitant** of
the scrutinee's type is covered. If your `Expr` has four
constructors and your `match` covers three, it doesn't
compile, and the message doesn't stop at "something missing":
it tells you what's missing, what's covered, and how to fix it:

```
error: non-exhaustive match on Expr: missing Neg
  --> eval.kai:12:3
    |
 12 |   match e {
    |   ^
  = note: missing variant: `Neg`
  = note: covered: Lit, Add, Mul
  = help: add an arm `Neg -> ...` or a wildcard `_ -> ...`
```

The wildcard `_` covers everything not covered by the
preceding arms, so a `match` with a final `_` is trivially
exhaustive. But using `_` as a final arm instead of
enumerating the cases is a way of **silencing** the compiler:
when you add a new constructor to `Expr`, the `match`es with
a final `_` will absorb it without complaint, and you'll lose
the warning.

Practical rule: use `_` only when you really don't care about
distinguishing the rest. If there are three cases and all
three matter, write the three.

## 5.5 Unions of existing types

So far every `|` we've seen had **new names** on the right —
`Red`, `Green`, `Lit`, `Circle` — that kaikai auto-declares
as constructors. But the operator doesn't require new names.
If the names on the right are **already declared as types**,
kaikai builds a **union** that can carry any value of those
types.

This is the key tool for composing errors across layers:

```kai
type IdentityError = AccountNotFound | KycExpired | Frozen
type AuthError     = InsufficientBalance | OverDailyLimit

type QueryError = IdentityError | AuthError
```

`QueryError` is the union of the two prior types. A value of
`QueryError` is **any** value of `IdentityError` or **any**
value of `AuthError`. There is no new wrapper:
`AccountNotFound` was already a valid value, and now it is
also a valid value of `QueryError`.

That step is called **implicit upcast**: a variable typed
`IdentityError` fits where `QueryError` is expected, no
conversion:

```kai
let id_err : IdentityError = AccountNotFound
let qe : QueryError        = id_err     # OK, no ceremony
```

This is what other languages force you to do with wrapper
constructors (`QEIdentity(IdentityError)`), `From` impls, or
manual conversions with `map_err`. In kaikai, none of those
three things exist: the compiler knows `IdentityError` is a
component of `QueryError` and rewrites the upcast for you.

### Pattern matching over unions

A `match` over a union value has two flavors that kaikai
lets you **mix freely**.

The first, already familiar, enumerates every constructor
individually:

```kai
fn describe(e: QueryError) : String =
  match e {
    AccountNotFound      -> "id: account not found"
    KycExpired           -> "id: KYC expired"
    Frozen               -> "id: frozen"
    InsufficientBalance  -> "auth: insufficient balance"
    OverDailyLimit       -> "auth: over daily limit"
  }
```

This works, but is tedious for big unions. And worse, if a
component grows — you add `RegulatoryHold` to `AuthError` —
the `match` becomes a compile error in five places instead of
one.

The second flavor is the **narrowing pattern** `bind :
ComponentType`, which matches when the value belongs to the
named component and binds it under that narrower type:

```kai
fn describe(e: QueryError) : String =
  match e {
    ie : IdentityError -> "id: " ++ id_str(ie)
    ae : AuthError     -> "auth: " ++ auth_str(ae)
  }
```

Each arm delegates to a function that knows that specific
component. If `AuthError` grows, only `auth_str` changes. The
`match` over `QueryError` doesn't notice.

The two forms also mix in a single `match` when you want to
extract a specific case and delegate the rest:

```kai
match e {
  AccountNotFound     -> "id: specifically, account missing"
  ie : IdentityError  -> "id: " ++ id_str(ie)        # KycExpired, Frozen
  ae : AuthError      -> "auth: " ++ auth_str(ae)
}
```

The compiler treats narrowing arms as if they covered every
constructor of their component, so exhaustiveness closes
correctly.

### A deliberate limitation: upcast doesn't chain

There's a kaikai rule worth knowing. The implicit upcast
**works only one step**:

```kai
type IdentityError = AccountNotFound | KycExpired
type AuthError     = OverLimit | DailyCap
type QueryError    = IdentityError | AuthError
type RoutingError  = NotFound | ServerDown
type AppError      = QueryError | RoutingError

fn handle_app(e: AppError) : String = "..."
```

And a value of the innermost type:

```kai
let id : IdentityError = AccountNotFound
handle_app(id)       # ERROR: IdentityError is not a direct
                     # component of AppError.
```

Although every `IdentityError` is logically an `AppError`
(through `QueryError`), the compiler doesn't search that
chain. To go from `IdentityError` to `AppError` you must
write the intermediate step explicit:

```kai
let q : QueryError = id           # one step: IdentityError → QueryError
handle_app(q)                      # another step: QueryError → AppError
```

I left it that way on purpose. Chained subtyping makes type
inference
brittle and error messages hard to phrase. The "one step"
rule keeps kaikai with a predictable type system whose
messages point to the right place.

## 5.6 Errors as unions, no wrappers

Unions are so useful for errors that the pattern is worth
naming. When a function can fail in several ways and those
ways break down into clear categories, the natural pattern
is:

1. Each category is a small sum type.
2. The composite error is the union of the categories.
3. Each function returns `Result[T, CompositeError]`.
4. The `!` operator propagates the error of any layer up to
   the composite `Result`, via the implicit upcast.

```kai
fn check_identity(req: Req) : Result[Account, IdentityError] = ...
fn check_auth(c: Account) : Result[Approved, AuthError] = ...

fn query_balance(req: Req) : Result[Balance, QueryError] = {
  let acc = check_identity(req)!     # IdentityError <: QueryError
  let app = check_auth(acc)!         # AuthError <: QueryError
  Ok(load_balance(app))
}
```

Each `!` unpacks the `Ok` and propagates the `Err` with the
correct upcast to the outer `Result[_, QueryError]`. Zero
wrappers, zero `map_err`, zero `From`. The signature of
`query_balance` documents exactly which errors it can emit,
and the compiler ensures every one of them is covered when
something consumes the result.

Compare it with the typical imperative version:

```python
# Python: nothing in the return type tells you what may fail
def query_balance(req):
    acc = check_identity(req)   # may throw AccountNotFound, KycExpired...
    app = check_auth(acc)       # may throw InsufficientBalance...
    return load_balance(app)
```

The caller of `query_balance` in Python has to read the inner
functions' code — or the docs, if any — to know which
exceptions to expect. In kaikai the signature tells them.

## 5.7 Case study: evaluator with typed errors

We close the chapter with an integrative case. We'll build an
evaluator of arithmetic expressions with two categories of
error:

- **Arithmetic**: division by zero, square root of a negative.
- **Environment**: undefined variable.

The two form a union, `EvalError`, and the evaluator returns
`Result[Real, EvalError]`. Full code in
`examples/ch05/05_evaluator.kai`; here we walk through the
interesting parts.

### The AST

```kai
type Expr
  = Lit(Real)
  | Var(String)
  | Add(Expr, Expr)
  | Mul(Expr, Expr)
  | Div(Expr, Expr)
  | Sqrt(Expr)
```

Six constructors, two of them recursive. `Var(String)`
introduces something new compared to the chapter 1
evaluator: expressions can now reference variables, so the
evaluator needs an **environment** that associates names with
values.

### The errors

```kai
type ArithError = DivByZero | NegativeSqrt(Real)
type EnvError   = Undefined(String)
type EvalError  = ArithError | EnvError
```

Three types: two categories and the union. Four constructors
in total, distributed over categories that make sense on
their own. `NegativeSqrt(Real)` carries the value that was
passed to sqrt — useful information for the final error
message. `Undefined(String)` carries the name of the missing
variable.

### The environment

```kai
type Env = [(String, Real)]

fn lookup(env: Env, name: String) : Result[Real, EvalError] {
  case [], _                          -> Err(Undefined(name))
  case [(k, v), ...], n when k == n   -> Ok(v)
  case [_, ...rest], n                -> lookup(rest, n)
}
```

`Env` is an alias for a list of pairs — linear lookup, enough
for a toy evaluator. `lookup` is written in the **multi-clause
form** of chapter 6: each `case` lists one pattern per
argument separated by comma, with an optional `when` for
guards. Three cases:

- Empty list: variable wasn't there; return an error.
- Head with the key we're looking for: success.
- Any other head: continue with the tail.

Notice the `Err` is of type `EvalError`, not `EnvError` — but
`Undefined(name)` constructs as `EnvError` and the implicit
upcast promotes it to `EvalError` at the return site, no
explicit conversion.

`eval` (next) uses the `match`-with-wrapper form because it
dispatches on a sum type with many constructors and the form
`match e { ... }` reads better when the discriminator is a
single well-marked argument. The two forms coexist in the
same file without tension.

### The evaluator

```kai
fn eval(env: Env, e: Expr) : Result[Real, EvalError] =
  match e {
    Lit(n)    -> Ok(n)
    Var(name) -> lookup(env, name)
    Add(a, b) -> {
      let va = eval(env, a)!
      let vb = eval(env, b)!
      Ok(va + vb)
    }
    Mul(a, b) -> {
      let va = eval(env, a)!
      let vb = eval(env, b)!
      Ok(va * vb)
    }
    Div(a, b) -> {
      let va = eval(env, a)!
      let vb = eval(env, b)!
      if vb == 0.0 { Err(DivByZero) } else { Ok(va / vb) }
    }
    Sqrt(x) -> {
      let v = eval(env, x)!
      if v < 0.0 { Err(NegativeSqrt(v)) } else { Ok(sqrt(v)) }
    }
  }
```

Each `match` case corresponds to a constructor of `Expr`.
Recursive cases use `!` to evaluate subtrees and propagate
any error that appears; cases that can fail locally
(division by zero, negative sqrt) construct an `Err` of the
appropriate type and let the upcast promote it.

The `!` operator appears several times and is worth reading
carefully. `eval(env, a)!` means: if `eval(env, a)` returns
`Ok(v)`, bind `va` to `v`; if it returns `Err(e)`, **exit
immediately** from the current function returning that `Err`.

### What `!` does internally

`!` is a **return** in disguise. The line

```kai
let acc = check_identity(req)!
```

is exactly equivalent to:

```kai
let acc = match check_identity(req) {
  Ok(x)  -> x                  # unpack and continue
  Err(e) -> return Err(e)      # exit query_balance with that error
}
```

For `Option[A]` the desugar is analogous: `Some(x)` unpacks,
`None` triggers `return None`.

Three things to pin down:

- **It's not a `panic` or an exception.** The program does
  not abort; the current function ends normally returning the
  `Err` or `None` to its caller. Control flows out **one level
  only**, no further.
- **It only works if the current function returns a
  compatible type.** If your function returns `Int`, you
  can't use `!` on a `Result` inside — the `return Err(e)`
  has nowhere to land. The compiler tells you so clearly.
- **The upcast happens at the `return`.** When
  `check_identity(req)` returns `Result[_, IdentityError]`
  but `query_balance` declares `Result[_, QueryError]`, the
  `return Err(e)` applies the upcast `IdentityError <:
  QueryError` on the way out. That's why `!` and union
  errors compose so well: each level of the cascade absorbs
  the error of the layer below without writing conversions.

If you come from Rust, this is exactly the `?` operator. If
you come from Swift, it's what `try` with `throws` does. If
you come from Haskell, it's the `do`-notation over `Either`
collapsed into a single symbol.

### Printing the result

```kai
fn describe(e: EvalError) : String =
  match e {
    DivByZero        -> "division by zero"
    NegativeSqrt(v)  -> "sqrt of negative (" ++ real_to_string(v) ++ ")"
    Undefined(name)  -> "undefined variable: " ++ name
  }

fn print_result(r: Result[Real, EvalError]) : Unit =
  match r {
    Ok(v)  -> println("ok: " ++ real_to_string(v))
    Err(e) -> println("error: " ++ describe(e))
  }
```

`describe` consumes an `EvalError` enumerating its three
constructors. Here `match` enumerates because we want
specific messages per constructor; in other cases — when
the logic differs per category — we'd use narrowing.

The main program assembles the environment, evaluates several
expressions, and prints them:

```kai
fn main() {
  let env : Env = [("x", 9.0), ("y", 4.0)]

  print_result(eval(env, Add(Var("x"), Var("y"))))    # ok: 13
  print_result(eval(env, Sqrt(Var("x"))))             # ok: 3
  print_result(eval(env, Div(Lit(10.0), Lit(0.0))))   # division by zero
  print_result(eval(env, Sqrt(Lit(0.0 - 1.0))))       # negative sqrt
  print_result(eval(env, Var("z")))                    # undefined variable
}
```

The pretty thing about this case: every error is documented
in the type of the evaluator. If later you want to add an
**TypeError** (say, attempting to add two non-numbers), you
declare the new category, include it in `EvalError`, and the
compiler walks you to every place that needs to adapt.

## Exercises

**5.1.** Define `type Maybe[a] = Just(a) | Nothing` (another
form of `Option`) and write `fn or_else[a](m: Maybe[a],
default: a) : a` returning the value if `Just`, the default
if `Nothing`. Note: `Nothing` is also a kaikai primitive
type (the bottom type from chapter 3); use `Empty` or
another name if shadowing bothers you.

**5.2.** Extend the §5.7 evaluator to support subtraction:
add `Sub(Expr, Expr)` to the AST, add the matching arm in
`eval`, and verify that `2 - 3` evaluates to `-1`. How many
lines did you have to change? How many places did the
compiler walk you to?

**5.3.** Define a binary decision tree:

```kai
type Decision[a]
  = Leaf(a)
  | Question(String, Decision[a], Decision[a])
```

where a `Question` has text, a "yes" branch and a "no"
branch. Write `fn apply[a](d: Decision[a], answers:
[(String, Bool)]) : Option[a]` walking the tree following
the answer to each question, returning `Some` with the
final decision if it reaches a `Leaf`, or `None` if some
question has no answer.

**5.4.** Take the union example with `IdentityError` and
`AuthError`. Add a third component `RoutingError` with two
constructors. Rewrite the `match` with narrowing so the
code stays equally short. Then add a new constructor to
`AuthError` (say `Blocked`) — what happens to your code?
How many places does the compiler intervene?

**5.5.** Create a sum type for a chat message: `type Message
= Text(String) | Image(String, Int, Int) | Audio(String,
Int)` (path, dimensions or duration). Write a function
`fn description(m: Message) : String` returning a human
description, and a function `fn heavy(m: Message) : Bool`
returning `true` if the message is image or audio. The
second function should use narrowing in the `match`, not
enumeration.

**5.6.** On paper, draw the evaluation tree the §5.7
evaluator builds when processing the expression
`Mul(Add(Var("x"), Lit(2.0)), Var("y"))` with environment
`[("x", 9.0), ("y", 4.0)]`. How many calls to `eval`? How
many to `lookup`? In what order? This helps you understand
why the `!` operator cuts execution as soon as something
fails: three cascaded calls, one line per level.
