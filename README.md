# The kaikai Programming Language

A book about [kaikai](https://github.com/lnds/kaikai), a functional,
statically typed programming language with algebraic effects as a
first-class primitive, Elixir-style pipelines, native-code
compilation via LLVM, and a memory model based on Perceus reference
counting plus isolated BEAM-style fibers — no garbage collector and
no borrow checker.

By Eduardo Díaz ([lnds](https://github.com/lnds)).

[Leer este README en español](./LEEME.md).

## What this book is

A reading book, not a reference manual. The reference lives in the
language repo under [`kaikai/docs`](https://github.com/lnds/kaikai/tree/main/docs).
This book is the long-form companion: chapters that explain the
*why* behind the language and walk through working programs from
the first page.

The structural inspiration is *The Go Programming Language* by
Donovan and Kernighan: dense prose, real programs from chapter
one, integrating case studies, exercises at the end of each
chapter. The pedagogical inspiration is *Learn You a Haskell for
Great Good!* by Lipovača: warm tone where the material gets new,
concepts introduced gradually, room for the reader to breathe.

The voice is mine, not theirs. First person where it earns its
place; opinions where they are owed. I designed the language;
this book takes a side.

## Who it is for

A working programmer with experience in some imperative or
object-oriented language (Python, Go, Java, JavaScript, C#, Rust)
**who has not necessarily worked in a functional language**.
Concepts like algebraic data types, pattern matching, immutability
by default, and effects-in-types are introduced with bridges from
what you already know — not assumed.

If you already know Haskell, OCaml, Elixir or Scala, the early
chapters can be skimmed; the distinctive material lives in Part
III (effects, fibers, actors, holes-and-LLMs).

It is **not** for absolute beginners. You should already know
what a function, a type, a list, and a test are.

## Editions

The book ships in two editions, both first-class — neither is a
translation of the other:

- **Spanish** — chapters under `capitulos/`, examples under
  `ejemplos/`. Voice calibrated on my [blog](https://lnds.net).
- **English** — chapters under `chapters/`, examples under
  `examples/`. Voice calibrated on the design docs of
  `kaikai/docs/` and adjacent technical writing.

Code samples are language-specific: strings, comments and file
names live in the language of the citing edition. Identifiers,
language keywords and kaikai stdlib APIs stay in their original
form (English). Figures live once under `figuras/` when they are
language-neutral.

## Repository layout

```
CLAUDE.md             — instructions for the agent assisting the writing
estructura.md         — full table of contents (18 chapters + 6 appendices)
capitulos/            — Spanish chapters, capNN-*.md
chapters/             — English chapters, chNN-*.md
ejemplos/capNN/       — sources cited by the Spanish edition
examples/chNN/        — sources cited by the English edition
figuras/              — diagrams and images (shared when neutral)
borradores/           — raw notes and material that is not yet a chapter
README.md             — this file
LEEME.md              — Spanish version of this file
```

## Building and running examples

You need the `kai` compiler installed. From a fresh checkout of
the language repo:

```sh
cd /path/to/kaikai
make all
```

Once `kai` is on your `PATH`, every example in this book runs
with:

```sh
kai run examples/chNN/<file>.kai     # English edition sources
kai run ejemplos/capNN/<file>.kai    # Spanish edition sources
```

Examples are verified against the version of `kai` in use at the
time the chapter is written. Chapter commits note the version
explicitly when an example depends on a recently-fixed bug.

## Status

In progress. The book is being written chapter by chapter,
starting from chapter 1. See `estructura.md` for the full plan
and `git log` for what has actually landed.

## License

To be defined. The text and the code samples will likely live
under different licenses (CC-BY-SA for the prose, MIT or similar
for the kaikai source).

## Contact

Issues and pull requests welcome on this repo. For comments on the
language itself rather than the book, use
[lnds/kaikai](https://github.com/lnds/kaikai).
