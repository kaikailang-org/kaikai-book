# Chapter 15 · Holes and kaikai with AI agents

This chapter is about a small tool with a big idea behind
it. The tool is called a **hole**: a gap you leave in your
code instead of an expression, with a `?` or a `?name`. The
big idea is that the compiler can **talk to you** as you
write: tell you what type is expected there, what names are
in scope, what expressions could fit. The program keeps
compiling with holes inside; it only aborts if execution
reaches one.

Holes are useful even if you never use an LLM. They let you
design top-down (write the signature first, fill in the body
later) and make progress piece by piece without the whole
file failing to compile. That's the human side.

But holes are also the piece around which kaikai is designed
for **AI agents**. The compiler can emit its report as JSON,
and an LLM reads that JSON to understand what's being asked
of it. This is the language's strategic bet (`design.md`
calls it Tier 3): a new language, without a large training
corpus, can be writable by an agent if the tooling is
designed well.

We'll take it in order, humans first.

## 15.1 Typed holes: `?` and `?name`

A hole is a legal expression in kaikai. You write it as
either `?` alone, or `?name` if you want to give it an
identity:

```kai
fn circle_area(r: Real) : Real = ?formula
```

This compiles. The function `circle_area` exists, has the
correct signature, and can be called from other parts of the
program. What happens when execution reaches `?formula` is
that the program aborts with a clear message:

```
$ kai run examples/ch15/01_basic_hole.kai
panic: unfilled hole: ?formula at line 1 col 27, expected Real
```

It isn't a compile-time error but a **deferred promise**:
you left a gap that you'll fill later, and the system stays
with you until you do. The panic carries everything an agent
(human or AI) needs in order to fill it: the hole's name, its
exact location, and the type the compiler inferred it should
have.

The difference between `?` and `?name` is that the name
helps identify the hole in messages and, more importantly,
makes **two holes with the same name within the same
function share a type**:

```kai
fn classify(n: Int) : String {
  if n < 0 {
    ?word
  } else {
    ?word
  }
}
```

The two `?word`s unify: if you decide one is `String`, the
other is too. That reduces the temptation to write
inconsistent implementations across branches of an `if` or
a `match`.

Anonymous holes (`?` with no name) are each independent.

## 15.2 The conversation with the compiler

The point of holes isn't in aborting nicely; it's in what
the compiler tells you about them. For each hole, it emits
a **report**:

```
$ kai build examples/ch15/01_basic_hole.kai --holes
examples/ch15/01_basic_hole.kai:1:32: type hole

  expected: Real

  in scope:
    r : Real

  candidates that fit:
    r
    real_mul(r, r)

  replace `?formula` with one of the candidates or a literal Real.
```

Four pieces of information:

- **`expected`**: the type the hole's position demands. The
  compiler infers it from context: here, the function
  returns `Real`, the body is a single expression, therefore
  the hole must be `Real`.
- **`in scope`**: every name reachable from the hole's
  point, with its type. Here only `r : Real` (the
  parameter).
- **`candidates that fit`**: expressions the compiler can
  synthesize that have the expected type. For `Real` with
  `r` in scope: `r` itself, `real_mul(r, r)` which is also
  `Real`. Synthesis is **bounded**: at most one function
  application. It doesn't give you the full body; it gives
  you hints.
- **`replace`**: the final suggestion, in one line.

That's the conversation. While the signature is all you
know, the compiler helps you see what could go inside.

Like any compiler report, the cost of invoking it is low:
you run `kai build --holes` and read. You don't have to
guess.

## 15.3 Top-down design: start from the signature

The most natural use of holes is **top-down design**. You
start by writing the signature of what you want, without
knowing how it'll be implemented. You put a `?` in the body.
The program compiles. You move on to the next function.

```kai
fn tokenize(s: String) : [Token] = ?tokens

fn parse(ts: [Token]) : Expr = ?ast

fn evaluate(e: Expr) : Int {
  match e {
    Lit(n)     -> n
    Sum(a, b)  -> evaluate(a) + evaluate(b)
    Mul(a, b)  -> evaluate(a) * evaluate(b)
  }
}

fn compute(s: String) : Int = evaluate(parse(tokenize(s)))
```

Three signatures, one complete function (`evaluate`). The
file compiles. You can run tests against `evaluate` with
hand-built ASTs, before implementing `parse` or `tokenize`:

```kai
fn main() : Unit / Console {
  let ast = Sum(Lit(3), Mul(Lit(4), Lit(5)))
  println("3 + 4*5 = #{evaluate(ast)}")
}
```

Output:

```
$ kai run examples/ch15/05_top_down_design.kai
3 + 4*5 = 23
```

The program runs. Evaluation works. Now you'll fill the two
holes one by one: implement `parse` (takes `[Token]`,
returns `Expr`), then `tokenize` (takes `String`, returns
`[Token]`). And when you fill the last one, `main` can call
`compute("3 + 4*5")` directly.

Contrast this with two more common ways of working:

- **Bottom-up:** implement the smallest pieces first,
  combine them. It works, but sometimes you discover the
  pieces don't fit at the end.
- **Big bang:** write everything at once, it doesn't compile
  until the end. Works if you have a crystal-clear problem.
  If not, it's painful.

Top-down with holes is the middle ground: the structure
exists from the start, the correctness of each piece is
verified as you fill it.

## 15.4 Partial programs: keep moving with the rest compiling

A consequence of designing with holes is that **you can
always run what you have**. If a function is complete, you
can test it without waiting for the whole file:

```kai
fn double(x: Int) : Int = x * 2

fn average(a: Int, b: Int) : Int = ?formula

fn main() : Unit / Console {
  println("double(5) = #{double(5)}")
  # average isn't done, but the file still compiles.
}
```

`double` works and `kai run` prints its result. `average`
waits to be implemented; as long as we don't call
`average`, the program doesn't hit the hole and runs
cleanly.

This reduces a lot of friction in keeping a program
"almost compiling" as you develop. Other languages push you
toward stubs with `unimplemented()`, `todo()`, or `return
null`; in kaikai the `?` is a primitive of the idiom, and
the compiler understands it has a type.

## 15.5 Holes in patterns: the incomplete match

A hole in pattern position works too:

```kai
type Shape
  = Circle(Real)
  | Square(Real)
  | Triangle(Real, Real)

fn area(s: Shape) : Real {
  match s {
    Circle(r)       -> 3.14 * r * r
    Square(l)       -> l * l
    Triangle(b, h)  -> ?triangle_formula
  }
}
```

Here the `match` already covers all three constructors;
what's missing is the expression in the last arm. The
compiler verifies exhaustiveness (chapter 5 §5.4), tells
you the `match` is complete, and reports the hole with
`Real` as expected type and `b`, `h` in scope.

If you haven't yet decided whether you want `Triangle` in
the type, you remove it and the compiler tells you `match`
is no longer exhaustive. Holes are orthogonal to pattern
checking; each one does its job.

## 15.6 The LLM bet: a language designed for agents

Up to here holes are a tool for humans. The most strategic
part of chapter 15 is that **holes are also the entry point
for an AI agent to write kaikai**.

The reasoning is simple. An LLM learns a language from the
**corpus** in its training data. Languages with a lot of
corpus (Python, JavaScript) are easy for models to
generate; new languages with little public code are hard.
If kaikai waited until it had a large corpus, it would
miss the experiment.

But there's an alternative: design the language so that the
compiler is what teaches the agent, not the corpus. If when
the LLM produces incorrect code, the compiler can say
precisely what's missing and where, the LLM can iterate to
the correct program in a few steps.

The key piece is **structured output**: the compiler emits
JSON that the agent reads directly, without heuristic
parsing. Three relevant channels:

1. **`kai build --holes-json`**: the hole report in JSON.
2. **`kai type --json`**: the type of any expression.
3. **Compiler diagnostics in JSON**: type errors,
   non-exhaustive matches, unhandled effects.

Chapter 5 §5.4 showed how a non-exhaustive match message
looks in human form. The JSON version has the same fields
as data: scrutinee type, list of missing variants, list of
covered variants, suggestion. An agent can parse it and
produce the code that covers the missing variant without
needing to read natural language.

## 15.7 The JSON output of holes

The JSON report has a stable schema:

```json
[
  {
    "file": "area.kai",
    "line": 1, "col": 32,
    "name": "formula",
    "expected_type": "Real",
    "in_scope": [
      {"name": "r", "type": "Real"}
    ],
    "candidates": [
      {"expr": "r", "kind": "local"},
      {"expr": "real_mul(r, r)", "kind": "application"}
    ]
  }
]
```

Each hole is an object. The array has as many elements as
there are holes in the file. The fields are the same as the
human report in §15.2, but as structured data.

For a human this is noisy; for an agent it's exact. And that
exactness changes the practical outcome: an agent that gets it
on the first try instead of the third is what separates a tool
you actually reach for from one that gets in your way.

## 15.8 Beyond holes: rich information as interface

Holes are the first piece of a general pattern. Other
compiler tools follow the same principle: emit structured
information that an agent can consume.

- **`kai type <expr>`** returns the type of an expression in
  the context of a file. With `--json`, the result is an
  object with fields `type`, `effects` (the row), and
  `notes` (references to the definition).
- **`kai check`** runs the file's properties and tests and
  reports results. With `--json`, each test/check/bench is
  an object with `name`, `status`, `duration_ms`, and a
  `counterexample` field for `check`s that failed (with the
  exact value that broke the property).
- **Compiler diagnostics** (errors and warnings) have a
  `--json` form: error type, location, span, human message,
  structured message, list of suggestions.

The common rule: the agent never has to parse text. The
information arrives already structured.

## 15.9 A workflow with an agent

When a programmer works with an AI agent on kaikai, the
reasonable flow is this:

1. **The human writes the signature and the tests.** Defines
   what the program is expected to do. Puts holes in the
   bodies.
2. **The agent reads `kai typecheck --holes-json`.** It knows
   what type is expected, what bindings are in scope, what
   candidates are reasonable. It generates an implementation
   proposal. It uses `typecheck` rather than `build` on
   purpose: the report is the same, but each query costs only
   the front-end (chapter 16 §16.1), and in a loop that gets
   paid many times over.
3. **The human runs `kai check`.** If the tests pass, things
   proceed. If not, the counterexample tells the agent
   what's wrong.
4. **The agent iterates.** Reads the counterexample,
   adjusts, proposes another implementation.

Three things worth noting about this flow:

- **The human decides the what.** Signature, tests,
  properties are what say what the program should do.
- **The agent decides the how.** Function bodies,
  intermediate structures, implementation details.
- **The compiler mediates.** It's the referee: it says
  whether the proposal meets the types, the tests, the
  properties. The agent never accepts anything without the
  compiler having said it passes.

This inverts the usual "LLM writes, human reviews"
arrangement: the specification is human, the body is the
agent's, and the compiler is what reconciles the two.

## 15.10 What the language doesn't automate

Holes are a tool for talking to the compiler. They're not a
tool for talking to the programmer's judgment. There are
things the compiler can't tell you, that no `--holes-json`
will deliver:

- **Which function your program needs.** If you decide that
  `circle_area` should exist, that's your decision. The
  compiler won't invent the signature for you.
- **What to name things.** If you call your function
  `process_data` instead of `transform_records`, no hole
  will correct you. Taste and readability are yours.
- **Whether the architecture makes sense.** That the
  compiler accepts a piece doesn't mean the piece belongs
  where you put it. Deciding what belongs in each module,
  what effects each function should expose, when to extract
  an abstraction: that's design, and design is human.

The author has a recurring idea about this on the blog:
tools don't replace judgment, they amplify it when they're
well designed. The compiler with holes and agents reads a
mechanical part of the work (the details that satisfy the
type constraints). The other part (what to build, what to
abstract, what to prioritize) remains the programmer's.

## 15.11 Case study: completing a non-trivial function

We close with a realistic exercise. Imagine you want to
write a function that takes a list of pairs `[(String,
Int)]` representing student grades, and returns the names
of those who passed (grade >= 4) in alphabetical order.

The human writes the signature and two tests:

```kai
fn passed(grades: [(String, Int)]) : [String] = ?body

test "empty list" {
  assert passed([]) == []
}

test "filter and sort" {
  let r = passed([("Carmen", 5), ("Ana", 3), ("Berta", 6)])
  assert r == ["Berta", "Carmen"]
}
```

The human runs `kai build --holes-json`. The agent
receives:

```json
{
  "name": "body",
  "expected_type": "[String]",
  "in_scope": [
    {"name": "grades", "type": "[(String, Int)]"}
  ],
  "candidates": [
    {"expr": "[]", "kind": "literal"}
  ]
}
```

The agent knows: expected type `[String]`, an input
`grades` of type `[(String, Int)]`. Candidates are thin
because the compiler's synthesis is bounded; the agent has
to propose something more substantial. A first proposal:

```kai
fn passed(grades: [(String, Int)]) : [String] =
  grades
    |? . .1 >= 4
    | . .0
    |> list.sort
```

The agent runs `kai check`. Both tests pass: the filter
keeps Carmen and Berta (grades 5 and 6) and drops Ana
(grade 3), then `list.sort` over `[String]` puts them in
ascending lexicographic order. If both pass, the agent is
done.

The human never touched the body. The compiler validated
types and tests. The agent iterated if needed. Each one did
what it does best.

Is it always this clean? No. There are functions where the
agent fails three times before getting it. There are
functions where the test counterexample is ambiguous and the
agent doesn't know what to adjust. But each iteration is
cheap (seconds), and the cost of being wrong is transparent
(the compiler or the test reports exactly what's wrong).

## 15.12 Philosophy: three ideas worth remembering

1. **Holes are a primitive for dialogue.** They're not
   `null` or `unimplemented()`: they're a legal form of
   expression that compiles, that the compiler understands,
   and for which it emits structured information. The human
   uses them for top-down design; the agent uses them as
   entry point.

2. **The compiler is the language's interface.** What the
   compiler says (expected types, errors, counterexamples,
   candidates) is what defines what you can do in kaikai.
   Designing that output well (both human and JSON) is what
   makes the language accessible to humans and agents
   alike.

3. **The human says the what; the agent says the how; the
   compiler verifies.** That's the division kaikai proposes
   for AI-assisted work. Each part does what it does best.
   None replaces the others.

## Exercises

**15.1.** Take a simple function you know (say
`fn sum_evens(xs: [Int]) : Int`). Write the signature with a
`?body` and the tests you'd expect. Without looking at the
implementation, write three body proposals by hand and run
them. How many tries until you find the right one?

**15.2.** Write a function with two branches of an `if`,
where each branch is a `?name` with the same name. Verify
that the compiler unifies the types of the two. Then change
one of the names and observe: now each branch has its own
type. In which cases is each form better for you?

**15.3.** Read `kai build --holes-json` on a file with three
holes at different positions. What information do all the
holes share? What information is specific to each one?

**15.4.** (Requires access to an AI agent.) Take a function
from chapter 5 (say the expression evaluator from §5.7) and
delete the body of one of the `match` branches, replacing it
with a `?name`. Ask the agent to complete it using only the
compiler's JSON output as input. How fast does it resolve?

**15.5.** Discuss with a colleague: what parts of the work
you do today programming could an agent do if you gave it
enough structured information from the compiler? What parts
definitely couldn't? Why?
