# Chapter 15 · Holes and kaikai with AI agents

This chapter is about a small tool with a big idea behind
it. The tool is called a **hole**: a gap you leave in your
code instead of an expression, with a `?` or a `?name`. The
big idea is that the compiler can **talk to you** as you
write: tell you what type is expected there, what names are
in scope, what expressions could fit. The program keeps
compiling with holes inside; it only aborts if execution
reaches one.

The chapter title can mislead: holes are useful even if you
never use an LLM. They let you design top-down (write the
signature first, fill in the body later) and make progress
piece by piece without the whole file failing to compile.

But holes are also the piece around which kaikai is designed
for **AI agents**. The compiler can emit its report as JSON,
and an LLM reads that JSON to understand what's being asked
of it. This is the language's strategic bet (`design.md`
calls it Tier 3): a new language, without a large training
corpus, can be writable by an agent if the tooling is
designed well.

Humans first.

## 15.1 Typed holes: `?` and `?name`

A hole is a legal expression in kaikai. You write it as
either `?` alone, or `?name` if you want to give it an
identity:

```kai
fn circle_area(r: Real) : Real = ?formula
```

This compiles. The function `circle_area` exists, has the
correct signature, and you can call it from other parts of
the program. When execution reaches `?formula`, the program
aborts with a clear message:

```
$ kai run examples/ch15/01_basic_hole.kai
panic: unfilled hole: ?formula at line 6 col 34
```

A hole is a **deferred promise**: you left a gap that you'll
fill later, and the system stays with you until you do. The panic gives you just enough to find
it: the hole's name and its exact location.

The type the compiler inferred doesn't ride in the panic, and
it's the first thing you'll want. It lives in the structured
report you put to work in §15.7: `kai build --holes-json` over this
same file returns `"expected_type": "Real"` alongside what's in
scope and a list of candidates. The panic is for when the
program surprises you at runtime; the report is for when you
sit down to fill the gap.

The name in `?name` identifies the hole in messages and,
more importantly, makes **two holes with the same name
within the same function share a type**:

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

The same `?word` in both branches, and what happens when the
program reaches it:

```kai
# examples/ch15/03_shared_hole.kai
fn classify(n: Int) : String {
  if n < 0 {
    ?word
  } else {
    ?word
  }
}

fn main() : Unit / Stdout {
  # Both branches are `?word`, so the compiler knows that
  # any value you pick for one works for the other.
  println(classify(-5))
}
```

```
$ kai run examples/ch15/03_shared_hole.kai
panic: unfilled hole: ?word at line 8 col 5
```

## 15.2 The conversation with the compiler

The point of holes is what the compiler tells you about them,
more than how nicely they abort. For each hole, it emits a
**report**:

```
$ kai build examples/ch15/01_basic_hole.kai --holes
examples/ch15/01_basic_hole.kai:6:34: type hole ?formula

  expected: Real

  in scope (local):
    r : Real

  candidates that fit:
    r
    real_sqrt(r)
    real_cbrt(r)
    real_exp(r)
    real_log(r)
    real_log2(r)
    real_log10(r)
    real_sin(r)

  288 more bindings in scope (--holes-scope lists them)
```

Four pieces of information:

- **The header** gives the position and the name: `?formula`.
  With several holes open at once — which is normal when you work
  this way — that's what tells you which one the block is about.
- **`expected`**: the type the hole's position demands. The
  compiler derives it from context: here the function returns
  `Real`, the body is a single expression, so the hole has to be
  `Real`.
- **`in scope (local)`**: the local names reachable from the
  hole, with their types. Here just `r : Real`, the parameter.
  The `(local)` matters: the report shows you your own names
  and counts the rest on the last line, because listing the
  nearly three hundred things the prelude brings along helps
  nobody. When you want them, `--holes-scope`.
- **`candidates that fit`**: expressions the compiler can
  synthesize that have the expected type. The synthesis is
  **bounded**: a single function application, with arguments
  taken from what's in scope, and a cap of eight proposals.

Those eight candidates teach something easy to misread: **none
of them is the answer**. The area of a circle is
`3.14 * r * r`, and that's two multiplications — two
applications — so the search doesn't reach it. The candidates
are a list of what fits in the gap: they tell you what you
have on hand, and in what shape, without trying to write your
function.

That's the conversation: while the signature is all you know,
the compiler helps you see what can go inside it. And it's
cheap to ask for: you run `kai build --holes` and read, no
guessing required.

### The effect row filters too

A pure example hides one piece: candidates are searched against
the effect row **at the hole's position**, not against the
whole program. Two holes that expect the same type and see the same
names in scope get different lists if their rows differ:

```kai
# examples/ch15/06_hole_with_effects.kai
effect Ask {
  question() : String
}

fn greeting(name: String) : String = ?text

fn interactive_greeting(name: String) : String / Ask = ?text_with_ask
```

The first one doesn't have `Ask`, so `Ask.question()` doesn't fit
— but the compiler doesn't hide it, it sets it aside with the
price tag attached:

```
  candidates that fit:
    name
    to_lower_unicode(name)
    ...

  fits if you add `/ Ask`:
    interactive_greeting(name)
    Ask.question()
```

The second one declares `Ask`, and the same operation shows up
among the ones that fit outright:

```
  candidates that fit:
    name
    greeting(name)
    Ask.question()
    ...
```

That "fits if you add" is my favorite part of the report: besides
what you can write there, it tells you what you could write if you
were willing to pay one more effect in the signature. The decision
stays yours, but now you make it looking at the price.

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
fn main() : Unit / Stdout {
  let ast = Sum(Lit(3), Mul(Lit(4), Lit(5)))
  println("3 + 4*5 = #{evaluate(ast)}")
}
```

Output:

```
$ kai run examples/ch15/05_top_down_design.kai
3 + 4*5 = 23
```

The program runs and evaluation works. Now you fill the two
holes one by one: implement `parse` (takes `[Token]`,
returns `Expr`), then `tokenize` (takes `String`, returns
`[Token]`). Once you fill the last one, `main` can call
`compute("3 + 4*5")` directly.

Contrast this with two more common ways of working:

- **Bottom-up:** implement the smallest pieces first,
  combine them. It works, but sometimes you discover the
  pieces don't fit at the end.
- **Big bang:** write everything at once, it doesn't compile
  until the end. Works if you have a crystal-clear problem.
  If not, it's painful.

Top-down with holes is the middle ground: the structure
exists from the start, and you verify each piece as you
fill it.

## 15.4 Partial programs: keep moving with the rest compiling

With holes, **you can always run what you have**. If a
function is complete, you test it without waiting for the
whole file:

```kai
fn double(x: Int) : Int = x * 2

fn average(a: Int, b: Int) : Int = ?formula

fn main() : Unit / Stdout {
  println("double(5) = #{double(5)}")
  # average isn't done, but the file still compiles.
}
```

`double` works and `kai run` prints its result. `average`
waits to be implemented; as long as you don't call it, the
program doesn't hit the hole and runs cleanly.

This reduces a lot of friction in keeping a program
"almost compiling" as you develop. Where other languages give
you a generic stub — `unimplemented()`, `return null` — in
kaikai the `?` is a primitive of the idiom, and the compiler
knows what type it has.

The full file: what's done runs; the hole waits:

```kai
# examples/ch15/02_partial_program.kai
fn double(x: Int) : Int = x * 2

fn average(a: Int, b: Int) : Int = ?formula

fn main() : Unit / Stdout {
  # double works, we can test it:
  println("double(5) = #{double(5)}")
  # average doesn't yet, but the file still compiles.
  # If you uncomment the next line, the program aborts:
  # println("average(4, 8) = #{average(4, 8)}")
}
```

```
$ kai run examples/ch15/02_partial_program.kai
double(5) = 10
```

### `todo!` — the other stub, and when to use it

There is a second form, not to be confused with `?`:

```kai
fn parse(s: String) : Config = todo!("parser still missing")
```

`todo!` compiles at any type and panics if you reach it:

```
$ kai run app.kai
panic: todo: parser still missing
```

So far it looks like `?`, which also compiles and also panics:

```
panic: unfilled hole: ?formula at line 6 col 34
```

The difference is in the compiler, not the runtime. A `?` is
an **open question**: `kai build --holes` reports it with its
expected type, the bindings in scope and the candidates that
fit. A `todo!` never shows up in that report: it is a
**decision already made** not to write this yet.

The rule follows on its own. Use `?` when you don't know what
goes there and want the compiler's help working it out. Use
`todo!` when you do know but it isn't the moment: the error
branch you'll fill in later, the case this version doesn't
handle. Leave a `todo!` where you needed an answer, and the
compiler stops offering help it actually had.

One detail: `todo!`'s message is a plain string literal, no
interpolation. `todo!("missing #{n}")` does not compile.

## 15.5 Holes in a match: the pending arm

A hole can be the body of a `match` arm:

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
only the expression in the last arm is missing. The
compiler verifies exhaustiveness (chapter 5 §5.4), accepts
the `match` as complete, and reports the hole with `Real`
as expected type and `b`, `h` in scope.

If you delete the arm instead of leaving a hole in it, the
compiler tells you the `match` is no longer exhaustive and
names the missing variant. Holes are orthogonal to pattern
checking; each one does its job.

The `match` with one arm pending: the two resolved cases run,
and the warnings point at the bindings the hole doesn't use
yet.

```kai
# examples/ch15/04_hole_in_pattern.kai
type Shape
  = Circle(Real)
  | Square(Real)
  | Triangle(Real, Real)

fn area(s: Shape) : Real {
  match s {
    Circle(r) -> 3.14 * r * r
    Square(l) -> l * l
    Triangle(b, h) -> ?triangle_formula
  }
}

fn main() : Unit / Stdout {
  println("circle 3 -> #{area(Circle(3.0))}")
  println("square 4 -> #{area(Square(4.0))}")
}
```

```
$ kai run examples/ch15/04_hole_in_pattern.kai
warning: unused binding `h`
  --> examples/ch15/04_hole_in_pattern.kai:15:17
     |
  15 |     Triangle(b, h) -> ?triangle_formula
     |                 ^
  = help: prefix with `_` to mark as intentionally unused
warning: unused binding `b`
  --> examples/ch15/04_hole_in_pattern.kai:15:14
     |
  15 |     Triangle(b, h) -> ?triangle_formula
     |              ^
  = help: prefix with `_` to mark as intentionally unused
circle 3 -> 28.259999999999998
square 4 -> 16
```

## 15.6 The LLM bet: a language designed for agents

So far you've used holes as a tool for humans. The most
strategic part of the chapter is that **holes are also the
entry point for an AI agent to write kaikai**.

The reasoning is simple. An LLM learns a language from the
**corpus** in its training data. Languages with a lot of
corpus (Python, JavaScript) are easy for models to
generate; new languages with little public code are hard.
If kaikai waited until it had a large corpus, it would
miss the experiment.

The alternative is to design the language so that the
compiler, rather than the corpus, teaches the agent. If the
compiler says precisely what's missing and where every time
the LLM produces incorrect code, the LLM can iterate to the
correct program in a few steps.

The key piece is **structured output**: the compiler emits
JSON that the agent reads directly, without heuristic
parsing. Three relevant channels:

1. **`kai typecheck --holes-json`**: the hole report in JSON.
2. **`kai typecheck --library-mode`**: the type of the
   expression at a line and column, among other queries.
3. **`kai typecheck --diags-json`**: compiler diagnostics
   (type errors, non-exhaustive matches, unhandled effects)
   in JSON.

In chapter 5 §5.4 you saw how a non-exhaustive match message
looks in human form. The JSON version carries the same
diagnostic as data: severity, file, line, column and message,
and in the `related` list each note (the missing variant, the
covered ones, the suggestion) with its own location. An agent
walks it without parsing heuristics and knows where to add
the missing arm.

## 15.7 The JSON output of holes

The JSON report carries the same data as the human one, minus
the formatting:

```json
[
  {
    "file": "examples/ch15/01_basic_hole.kai",
    "line": 6, "col": 34,
    "kind": "hole",
    "name": "formula",
    "message": null,
    "expected_type": "Real",
    "in_scope": [
      {"name": "r", "type": "Real"}
    ],
    "scope_elided": 563,
    "candidates": [
      {"expr": "r", "kind": "synth"},
      {"expr": "real_sqrt(r)", "kind": "synth"},
      {"expr": "real_cbrt(r)", "kind": "synth"},
      {"expr": "real_exp(r)", "kind": "synth"},
      {"expr": "real_log(r)", "kind": "synth"},
      {"expr": "real_log2(r)", "kind": "synth"},
      {"expr": "real_log10(r)", "kind": "synth"},
      {"expr": "real_sin(r)", "kind": "synth"}
    ],
    "candidates_needing_effects": [],
    "doc": null
  }
]
```

Each hole is an object, and the array has as many elements as the
file has holes. Four fields have no printed equivalent in the
human report, and for an agent they're worth their weight in gold:
`kind` separates a `?` (`"hole"`) from a `todo!` (`"todo"`), with
the `todo!`'s text in `message`; `scope_elided` says how many
bindings were left out of `in_scope`;
`candidates_needing_effects` carries the "fits if you add"
candidates along with the row they're missing; and `doc` holds the
docstring of the function containing the hole.

For a human this is noisy; for an agent it's exactly what's
needed. That precision has a practical payoff: an agent
getting it right on the first try instead of the third is what
separates a usable tool from one that just gets in the way.

## 15.8 Beyond holes: rich information as interface

Holes are the first piece of a general pattern. Other
compiler tools follow the same principle: emit structured
information that an agent can consume.

- **`kai typecheck --library-mode`** answers queries the file
  carries in `# @probe <kind> L:C` comments. With
  `# @probe type 4:14` it returns a JSON object whose `type`
  field is the type of the expression at that position; `def`
  says where a name is declared, and `sig` gives the signature
  of the enclosing call.
- **`kai test --json`** runs the tests and emits one JSON line
  per test, with `id`, `file`, `line`, `status` and
  `duration_ms`, plus a `message` when it fails, and a final
  `summary` line with the totals.
- **`kai typecheck --effects-json`** reports, per function,
  the inferred effect row and the handlers it installs.

The common rule: the agent never has to parse text. The
information arrives already structured.

## 15.9 A workflow with an agent

When you work with an AI agent on kaikai, the reasonable
flow is this:

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
3. **The agent runs `kai test`**, and `kai check` if there
   are properties. If everything passes, things proceed. If
   not, the failing test or the property's counterexample
   tells it what's wrong.
4. **The agent iterates.** Reads the failure, adjusts,
   proposes another implementation.

Three things about this flow:

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

Holes are a tool for talking to the compiler; the
programmer's judgment lies outside their reach. There are
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

I keep coming back to one idea about this on my blog:
tools don't replace judgment, they amplify it when they're
well designed. The compiler with holes and agents carries a
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

The agent runs `kai typecheck --holes-json` and receives:

```json
[
  {
    "file": "grades.kai",
    "line": 1, "col": 49,
    "kind": "hole",
    "name": "body",
    "message": null,
    "expected_type": "[String]",
    "in_scope": [
      {"name": "grades", "type": "[Pair[String, Int]]"}
    ],
    "scope_elided": 562,
    "candidates": [],
    "candidates_needing_effects": [
      {"expr": "Env.args()", "kind": "synth", "effects": ["Env"]},
      {"expr": "args()", "kind": "synth", "effects": ["Env"]}
    ],
    "doc": null
  }
]
```

The agent knows: expected type `[String]`, an input `grades` of
type `[Pair[String, Int]]` — the shape the compiler prints
`[(String, Int)]` as, per §4.6. And it knows something more
useful still: `candidates` comes back **empty**. The synthesis is
bounded and here it reaches nothing at all; the two that show up
behind an effect are `Env.args()`, which has nothing to do with
the problem. The compiler was honest: this one is on you. The
agent has to propose something substantial. A first proposal:

```kai
fn passed(grades: [(String, Int)]) : [String] =
  grades
    |? (.snd >= 4)
    | .fst
    |> list.sort
```

The agent runs `kai test`. Both tests pass: the filter keeps
Carmen and Berta (grades 5 and 6) and drops Ana (grade 3),
then `list.sort` over `[String]` puts them in ascending
lexicographic order. With both tests green, the agent is
done.

The human never touched the body. The compiler validated
types and tests. The agent iterated if needed.

Is it always this clean? No. There are functions where the
agent fails three times before getting it. There are
functions where the test counterexample is ambiguous and the
agent doesn't know what to adjust. But each iteration is
cheap (seconds), and the cost of being wrong is transparent
(the compiler or the test reports exactly what's wrong).

## 15.12 Philosophy: three ideas worth remembering

1. **Holes are a primitive for dialogue.** Unlike `null` or
   `unimplemented()`, they're a legal form of expression that
   compiles, that the compiler understands, and for which it
   emits structured information. The human
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
