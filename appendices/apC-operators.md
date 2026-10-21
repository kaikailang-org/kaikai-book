# Appendix C · Operator table and precedence

Every operator in the language, with its precedence and
associativity. It's a quick reference: when you're not sure
how `a | f |> g` parses, you look it up and move on.

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
| 5     | `??` (`Option` default)                         | Right             |
| 6     | `==`, `!=`, `<`, `>`, `<=`, `>=`                | **Non-associative** |
| 7     | `and`                                           | Left (short)      |
| 8     | `or`                                            | Left (short)      |
| 9     | `\|>`, `\|`, `\|\|`, `\|?`, `\|!`               | Left              |

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
- **Level 5 (`??`).** The default for an `Option`: `o ?? d` is
  what `o` carries when it is `Some`, and `d` when it is
  `None`. Right-associative, so `a ?? b ?? c` is
  `a ?? (b ?? c)`, and the right side runs only in the `None`
  case.
- **Level 6 (comparisons).** **Don't chain.**
  `a < b < c` is a syntax error; write `a < b and b < c`.
  That eliminates the bug class where
  `1 == 1 == true` parses unexpectedly.
- **Level 7 (`and`) and 8 (`or`).** Short-circuit logical.
  `and` binds tighter than `or`, so
  `a or b and c` is `a or (b and c)`.
- **Level 9 (pipes).** Five operators at the same level:
  `|>` (apply), `|` (map), `||` (flat-map), `|?` (filter) and
  `|!` (each). All left-associative: `xs | f |> g` is
  `(xs | f) |> g`. `|!` returns `Unit`, so it ends the pipeline
  and no pipe can follow it.

## C.2 Forms that **aren't** operators

Some forms that look like operators in other languages are
separate syntactic constructs in kaikai:

- **`=` (`let` binding)**: part of `let`'s syntax, not an
  operator. `let x = expr` is a declaration.
- **`:=` (write to mutable cell)**: part of `var`'s syntax.
  `name := expr` is the sugared form of
  `State.set(name, expr)`. It doesn't participate in the
  precedence table.
- **`&expr` and `@r` (`Ref[T]` cells)**: `&v` builds a cell
  holding `v` and `@r` reads it. Both are prefixes and do not
  participate in the table. A `var`'s cell is a different
  thing: it reads naked, by its name.
- **`;` (expression separator)**: separates two expressions
  written on the same line. A newline does the same, so you
  rarely need it; at the end of a line it's harmless and does
  not discard the expression's value (§3.7).
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

Some operators are sugar for calls to stdlib functions. The
equivalences help when the operator doesn't seem to work, or
when you want to see the mechanism underneath.

| Operator        | Equivalent to                            |
|-----------------|------------------------------------------|
| `x |> f`        | `f(x)`                                   |
| `x |> f(_, b)`  | `f(x, b)`                                |
| `xs | f`        | `list.map(xs, f)`                        |
| `xs || f`       | `list.flat_map(xs, f)`                   |
| `xs |? p`       | `list.filter(xs, p)`                     |
| `xs |! f`       | `list.each(xs, f)`                       |
| `a ++ b`        | `string_concat(a, b)` (when they're `String`) |
| `a[i]`          | `Mutable.array_get(a, i)`                |
| `a[i] := v`     | `Mutable.array_set(a, i, v)`             |
| `&v` / `@r`     | `Ref[T]` cell: make and read             |
| `name := v`     | `State.set(name, v)` (with `var`)        |

## C.4 Reminder: comparison is non-associative

The level 5 rule deserves its own callout: it's the one most
likely to catch you if you come from another language.

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

That eliminates a small but irritating class of bugs. If you
come from Python and the extra typing annoys you, the rule is
the same in Pascal, Eiffel, and SQL. It isn't a kaikai
oddity.
