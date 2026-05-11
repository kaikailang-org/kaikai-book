# Appendix A · Three-stage bootstrap

This appendix tells how the kaikai compiler is built from
nothing but a plain C compiler. It's not part of the
language the reader needs to know to program; it's part of
the project's story, an engineering decision with lasting
consequences.

If you find yourself asking "why does it matter how the
compiler is compiled?", the short answer: because it
defines whom you trust and why. A language whose compiler
is built from a plain `cc` and nothing else is a language
anyone can audit, reproduce, and maintain. That's technical
freedom few modern languages offer.

## A.1 The bootstrap problem

A compiler is a program. Like any program, it has to be
compiled to run. New compilers run into an immediate
paradox: what compiles the compiler the first time?

Three historical answers:

- **Write it in C (or assembly) the first time.** The
  classical route. GCC, MRI Ruby, CPython, V8 were born
  this way. The cost: the new compiler carries C's surface
  forever, or gets rewritten in itself later through a
  costly migration.
- **Write it in an existing language that already has a
  compiler.** That's what Rust did with OCaml initially,
  what Swift did with C++. It inherits the host language's
  dependencies: compiling Rust required installing OCaml,
  until Rust was rewritten in itself.
- **Incremental self-hosting.** Start with a small compiler
  (for a subset of the language), written in something
  portable, use it to compile a bigger compiler (written in
  the language), and so on. That's what kaikai does with
  its three stages.

## A.2 Stage 0: the compiler in C

`stage0` is a compiler written in standard C. Its only
dependency is any C compiler:

```sh
$ cc stage0/*.c -o kaic0
```

No frameworks, no generators, no exotic libraries. Plain C.
The file `stage0/runtime.h` is the runtime for compiled
programs: reference counters, list and string primitives,
panic. All of that fits in a few thousand lines.

What does `kaic0` compile? **kaikai-minimal**, a deliberate
subset of the language. The grammar and constructs in
kaikai-minimal are documented in `docs/kaikai-minimal.md`.
What's **not** in kaikai-minimal: algebraic effects, fibers,
protocols, contracts, units of measure. The minimum to
write a compiler.

Stage 0 is built to be auditable. A programmer who wants to
understand what's going on can read the C source line by
line: lexer, recursive-descent parser, simple type checker,
C emitter. Five files.

## A.3 Stage 1: the compiler in kaikai-minimal

Once `kaic0` works, we write a new compiler **in
kaikai-minimal**. This compiler, `stage1`, does something
`kaic0` can't: it compiles the **full** language. Effects,
fibers, protocols, contracts, all of it.

```sh
$ kaic0 stage1/main.kai -o kaic1
```

`kaic0` compiles `stage1` to produce an executable `kaic1`.
From here on, the C compiler is out of the picture: `kaic1`
is enough to process programs that use everything kaikai
offers.

It's the first "self-validation": the compiler written in
kaikai-minimal proves that kaikai-minimal is expressive
enough to implement a full compiler. If it weren't, this
step wouldn't terminate.

## A.4 Stage 2: full kaikai, self-hosted

`stage2` is the definitive version. Written in **full
kaikai** (not the minimal subset), using effects, fibers,
and everything the language offers. End-to-end idiomatic
kaikai code.

```sh
$ kaic1 stage2/main.kai -o kaic2
```

`kaic1` compiles `stage2`, producing `kaic2`. This is the
compiler that gets distributed. The user installing kaikai
gets `kaic2`, not `kaic0` or `kaic1`.

## A.5 The fixed point: bootstrap validation

There's a critical check at the end of the process:

```sh
$ kaic2 stage2/main.kai -o kaic2-self
$ diff kaic2 kaic2-self
```

They must be **bit-for-bit identical**. This means `kaic2`
compiled by `kaic1` produces exactly the same thing as
`kaic2` compiled by itself. In other words: `kaic2` is a
fixed point of the compilation process.

Why does this matter? Two reasons:

- **Detection of subtle compiler bugs.** If two compiler
  versions (`kaic1` and `kaic2`) produce different binaries
  from the same source, one of them has a bug. The fixed
  point confirms the whole chain converges to the same
  answer.
- **Resistance to the Thompson attack.** Ken Thompson
  published in 1984 a famous essay ("Reflections on
  Trusting Trust") showing that a malicious compiler can
  insert invisible backdoors that survive recompilation.
  The classical defense is **diverse double-compiling**:
  compile with two distinct chains and compare. The fixed
  point is the modern version of that idea: if the whole
  chain converges to one binary, and that binary is
  reproducible from auditable sources, trust is justified.

## A.6 Reproducible from a `cc`

The practical consequence of the three-stage bootstrap is
this: **with just a C compiler, you can rebuild kaikai
entirely from source**. No need to have kaikai previously
installed. No need to trust a binary downloaded from a web
page. No `curl | bash`.

```sh
$ git clone https://github.com/lnds/kaikai
$ cd kaikai
$ make
```

Underneath, `make` runs the three steps: stage 0 with cc,
stage 1 with stage 0, stage 2 with stage 1. It ends with a
`kaic2` in the `bin/` directory, and the fixed-point
verification ensures it's the right one.

This is technical freedom few modern languages give you.
Rust requires a previous Rust (downloaded as a blob). Go
requires a previous Go. Swift requires a previous Swift.
kaikai doesn't: your C compiler is the entry point.

## A.7 Costs and trade-offs

The three-stage bootstrap has costs. Worth listing because
every engineering decision has them:

- **Stage 0 has to be maintained whenever kaikai-minimal
  changes.** If a new language feature falls within the
  minimal subset, stage 0 has to learn it. That means new
  C code, written by hand.
- **It's expensive to add dependencies to the compiler.**
  Stage 2 might benefit from an external library (a parser
  combinator, an exotic data structure). But that library
  would have to be available in stage 1, which only
  understands kaikai-minimal. The pressure is toward
  keeping stage 2 self-contained.
- **Building everything from scratch takes time.** Not
  much (the three steps together take less than a minute
  on a reasonable machine), but more than a single `cargo
  build`. For continuous CI, that matters.

Is it worth it? The project's answer is yes, and the
reason is philosophical: the compiler is the most trusted
piece of software in the ecosystem. If the chain of trust
can be audited end-to-end from plain C, then the rest
follows.

## A.8 Going further

The design decisions live in `docs/design.md` at
`github.com/lnds/kaikai`. The physical files are under
`stage0/`, `stage1/`, `stage2/` of the repository. Ken
Thompson's essay *Reflections on Trusting Trust* (CACM
1984) is worth reading if you care about the philosophical
justification for this approach.
