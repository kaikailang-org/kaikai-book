# Appendix C · Operator table and precedence

This appendix lists every operator in the language with
its precedence and associativity. It's meant as a quick
reference: when you're not sure how `a | f |> g` parses, you
look it up and move on.

Precedence is numbered from highest (1, binds first) to
lowest (8, binds last). Each level resolves against the
level immediately above.

## C.1 Main table

| Level | Operators                                       | Associativity     |
|------:|-------------------------------------------------|-------------------|
| 1     | call `f(args)`, field `.`, index `[i]`          | Postfix           |
| 2     | unary `-`, `not`                                | Prefix            |
| 3     | `*`, `/`, `//`, `%`                             | Left              |
| 4     | `+`, `-` (binary), `++` (string concat)         | Left              |
| 5     | `==`, `!=`, `<`, `>`, `<=`, `>=`                | **Non-associative** |
| 6     | `and`                                           | Left (short)      |
| 7     | `or`                                            | Left (short)      |
| 8     | `\|>`, `\|`, `\|\|`, `\|?`                      | Left              |

### Per-level details

- **Level 1 (postfix).** Left-associative: `a.b.c` means
  `(a.b).c`; `f(x)(y)` means `(f(x))(y)`.
- **Level 2 (prefix).** Unary `-x` and `not x`. Apply before
  any binary operator.
- **Level 3 (multiplicative).** `*` and `/` on `Int` and
  `Real`, `//` is integer division, `%` is modulo. Left-
  associative: `a / b / c` is `(a / b) / c`.
- **Level 4 (additive).** Binary `+` and `-` on numbers,
  `++` to concatenate strings.
- **Level 5 (comparisons).** **Don't chain.** Writing
  `a < b < c` is a syntax error. The correct form is
  `a < b and b < c`. This eliminates the bug class where
  `1 == 1 == true` parses unexpectedly.
- **Level 6 (`and`) and 7 (`or`).** Short-circuit logical.
  `and` binds tighter than `or`, so
  `a or b and c` is `a or (b and c)`.
- **Level 8 (pipes).** Four operators at the same level:
  `|>` (apply), `|` (map), `||` (flat-map), `|?` (filter).
  All left-associative. `xs | f |> g` is `(xs | f) |> g`.

## C.2 Forms that **aren't** operators

Some forms that look like operators in other languages are
separate syntactic constructs in kaikai:

- **`=` (`let` binding)**: part of `let`'s syntax, not an
  operator. `let x = expr` is a declaration.
- **`:=` (write to mutable cell)**: part of `var`'s syntax.
  `name := expr` is the sugared form of
  `State.set(name, expr)`. It doesn't participate in the
  precedence table.
- **`@name` (read from mutable cell)**: sugared read of
  `State.get(name)`. It's a prefix of the name, doesn't
  participate in the table.
- **`->` (in `match`, in lambdas, in `handle`)**: syntactic
  separator, not an operator.
- **`/` (in effect signature)**: separates the return type
  from the effect row: `fn f() : Int / Log`. Only appears
  in signature position.
- **`!` (propagation of `Option`/`Result`)**: postfix on
  expressions returning `Option[T]` or `Result[E, T]`,
  performs early propagation of the error or `None`. Rough
  equivalent of Rust's `?`. It isn't a binary operator.
- **`?` and `?name` (holes)**: hole markers, not operators.
- **`...` (spread)**: appears in record and list literals
  (`[h, ...t]`, `Point { ...p, x: 10 }`); also in patterns.
  Not an operator.
- **`<>` (unit-of-measure annotation)**: `1.50<USD>`,
  `Real<EUR>`. The unit sits inside the angle brackets;
  these aren't the operators `<` and `>`.

## C.3 Useful equivalences

Some operators are syntactic sugar for calls to stdlib
functions. Knowing the equivalences helps when the operator
doesn't seem to work, or when you want to see the
underlying mechanism.

| Operator        | Equivalent to                            |
|-----------------|------------------------------------------|
| `x |> f`        | `f(x)`                                   |
| `x |> f(_, b)`  | `f(x, b)`                                |
| `xs | f`        | `list.map(xs, f)`                        |
| `xs || f`       | `list.flat_map(xs, f)`                   |
| `xs |? p`       | `list.filter(xs, p)`                     |
| `a ++ b`        | `string_concat(a, b)` (when they're `String`) |
| `a[i]`          | `Mutable.array_get(a, i)`                |
| `a[i] := v`     | `Mutable.array_set(a, i, v)`             |
| `@name`         | `State.get(name)` (with `var`)           |
| `name := v`     | `State.set(name, v)` (with `var`)        |

## C.4 Reminder: comparison is non-associative

The rule at level 5 deserves its own callout because it's
where readers from other languages get caught most.

In most languages:

```
1 == 1 == 1     # Python: false (1 == 1 → true, true == 1 → false)
1 < 2 < 3       # C: 1 (1 < 2 → 1, 1 < 3 → 1; not what it looks like)
```

In kaikai, neither one compiles. The compiler requires you
to spell out the intent:

```kai
1 == 1 and 1 == 1       # clearly: two comparisons
1 < 2 and 2 < 3         # range: each side compared explicitly
```

This eliminates a small but irritating class of bugs. For
anyone coming from Python who finds writing more annoying,
remember the rule is the same in Pascal, Eiffel, and SQL.
It isn't a kaikai oddity.
