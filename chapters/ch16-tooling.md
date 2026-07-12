# Chapter 16 · Tooling: the `kai` binary

Every chapter so far has focused on the language: syntax,
types, effects, the memory model. But a language without
tooling doesn't get used. This chapter covers the other
side: the `kai` binary, which is the face every programmer
interacts with every day.

It's a short reference chapter. No exercises. The point is
for you to know which command to use when, and to have the
list at hand to come back to.

## 16.1 Compiling and running: `kai run`, `kai build`

The command you'll live with is `kai run`:

```
$ kai run hello.kai
hello, kaikai
```

`kai run` compiles the file to a native binary, runs it,
and forwards any extra arguments to the program. It's the
edit-save-run cycle of the day-to-day. Underneath there's a
compiler (`kaic2`) that by default lowers to a native object
with LLVM linked into the compiler itself — no `.ll` text on
disk, no separate `clang` process — and then runs the
executable.

If you want the binary without running it, use `kai build`:

```
$ kai build hello.kai
$ ./hello
hello, kaikai

$ kai build hello.kai -o build/hello
$ ./build/hello
hello, kaikai
```

`kai build` doesn't run the program: it leaves the
executable on disk. With `-o` you specify where. The binary
is **essentially static**: it doesn't depend on the kaikai
compiler, only on the system's libc. You can copy it to
another machine with the same OS and architecture and it
will run.

For the binary you'll ship or debug, there are two profiles:

```
$ kai build --release app.kai    # -O2, symbols stripped:
                                 # smaller, ready to ship
$ kai build --debug app.kai      # -O0 with DWARF tables
```

With `--debug`, `lldb` or `gdb` set breakpoints on `.kai`
lines, and a panic prints the stack trace as
`file.kai:line`. It's the native backend that builds the
DWARF tables; on `--backend=c` the flag is a no-op. With no
flag you get the usual middle ground: fast compilation,
symbols kept.

### Fast compilation

`kai run` and `kai build` are designed to feel immediate. A
program of a few hundred lines compiles in less than a
second on a reasonable machine. That speed isn't an
accident: the compiler is self-hosted (kaikai compiled in
kaikai), avoids costly passes like global type inference
where it doesn't need to, and lowers to LLVM in the same
process — no intermediate files written, no external linker
launched on the common path. For larger programs there's a
cache (chapter 8 §8.8 covers the package cache; the per-file
compilation cache is another story).

To put it in perspective: a Rust program of comparable
size can take 30 seconds to compile, where a kaikai program
of the same size takes less than a second — an order of
magnitude you feel on every save.

## 16.2 Tests, properties and benchmarks

Three subcommands cover the three verification constructs
from chapter 7:

- **`kai test`** runs `test "..." { ... }` blocks.
- **`kai check`** runs `check "..." with x: T { ... }` blocks
  (properties verified with randomly generated values).
- **`kai bench`** runs `bench "..." { ... }` blocks and
  reports timings.

```
$ kai test calculator.kai
  ok   sum of zero
  ok   unit product
  ok   literal evaluation

3/3 tests passed
```

```
$ kai check calculator.kai
  commutativity of addition: 100 iter, OK
  associativity of multiplication: 100 iter, OK

2/2 checks passed
```

```
$ kai bench calculator.kai
  small-tree evaluation: 1000 iter / median 12 ns / MAD 1 ns / mean 13 ns / range [10, 45]
  large-tree evaluation: 1000 iter / median 8.4 us / MAD 0.2 us / mean 8.5 us / range [8.0, 12.1]

2 benches
```

`kai bench` takes `--iters N` to set the iteration count
(default 1000). For costly benchmarks, lower it; for more
stable measurements, raise it.

The three commands share two important properties:

- **They only run the relevant blocks.** `kai test` ignores
  `check` and `bench`; `kai check` ignores `test` and `bench`.
- **The blocks don't land in the production binary.** `kai
  run` and `kai build` drop them entirely.

## 16.3 Formatting: `kai fmt`

`kai fmt` is the canonical formatter. `gofmt` style:

- One correct way to print any file.
- No configuration options. The project doesn't want style
  wars.
- Idempotent: formatting an already-formatted file doesn't
  change it.

Three ways to use it:

```
$ kai fmt file.kai                # rewrite in place
$ kai fmt --check file.kai        # exit 0 if formatted, 1 if not
$ cat file.kai | kai fmt --stdin  # read stdin, write stdout
```

The `--check` form is for CI: if the code isn't formatted,
the job fails and forces you to run `kai fmt` before
merging.

The `--stdin` form is for editors: your editor pipes the
buffer to the formatter before saving, gets the canonical
result back, and writes it.

## 16.4 The linter: `kai lint`

Where `kai fmt` is dictatorial, `kai lint` is opinionated.
It flags code that **compiles but reads like a mistake**,
the way Rust's Clippy sits beside `rustc`: the compiler
stays strict about correctness and silent about style; the
opinions live in the linter.

```
$ kai lint file.kai           # human-readable warnings
$ kai lint --json file.kai    # findings as JSON
```

Two properties define its character:

- **Opt-in and non-blocking.** Warnings only, always exits
  0, never changes what compiles. You run it when you want a
  second look, not as a toll.
- **Type- and effect-aware.** It's not a grep with
  delusions: it reuses the typed AST and the effect rows the
  compiler already produced, so it can tell apart what a
  text scanner can't.

The clearest example of that awareness is the
`discard_pure_value` rule. A block drops the value of every
statement that isn't its tail; if that dropped value is
**pure and non-Unit**, it's dead code or a forgotten use:

```kai
fn run() : Int {
  area(3, 4)        # warning: the Int is dropped
  0
}
```

But if the discarded call **carries effects**, the discard
is legitimate — you called for the effect, not the value —
and the rule stays quiet. That distinction requires the
effect row; a textual linter doesn't have it.

Other rules in the catalog nudge toward idiomatic kaikai:
`point_free_nudge` suggests the point-free section (§6.2)
when a unary lambda only projects on its parameter, and
`and_then_to_map_nudge` warns when an `and_then` is really a
`map`. The catalog grows in phases; `kai info lint` lists
the current state.

## 16.5 Package management: `init`, `add`, `install`, `update`

Chapter 8 §8.5-8.8 covered the package model (`kai.toml`
manifest, `kai.lock` lockfile, shared cache,
minimum-version selection). Here we list the subcommands
that orchestrate the model:

```
$ kai init myapp
kai-pkg: wrote kai.toml for package 'myapp'

$ kai add github.com/kaikailang-org/manutara@v0.1.0
$ kai install
$ kai update                # refresh all deps
$ kai update manutara       # refresh only manutara
$ kai show                  # print parsed kai.toml
```

`kai run` and `kai build` invoke `kai install` automatically
if they detect dependencies declared in `kai.toml` but not
resolved in `kai.lock`. In practice, after cloning a kaikai
project, `kai run` is enough to download whatever's
missing.

Don't confuse `kai update` with `kai upgrade`: `update`
refreshes your package's **dependencies**; `upgrade` updates
the **compiler itself** to the latest release (downloads,
verifies the SHA-256, and swaps the binary in place, as you
saw in chapter 1). On a Homebrew install, `upgrade` doesn't
touch the Cellar: it points you to `brew upgrade kaikai` and
exits.

## 16.6 Development mode: `kai watch`

`kai watch` is useful when you're iterating intensely on a
program:

```
$ kai watch main.kai
[watching main.kai...]
```

Every time you save the file, the watcher detects the
change, recompiles, and runs. It lets you keep the result
visible without going back to the terminal to type `kai
run`. It's the fastest way to explore a change in a demo or
a script.

## 16.7 Editor integration: `kai lsp`

`kai lsp` is the Language Server that kaikai exposes for
editors. It implements the standard Language Server Protocol,
so any editor with LSP support (VS Code, Neovim, Emacs,
IntelliJ with plugin) can connect and get:

- Type-on-hover: hover over an expression and see its type.
- Goto-definition: jump to where a name was declared.
- Document symbols: the file's symbol tree for the editor's
  side panel.
- Completion: candidate list as you type, with the type and
  origin of each one.
- Signature help: when you open a paren in a call, the
  function's signature shows with the current parameter
  highlighted.
- Live diagnostics: errors and warnings from the compiler
  appear in the buffer as you type. **Unfilled holes** surface
  as warnings — the editor reminds you of what's still pending
  without breaking your flow.

The exact editor configuration varies. For VS Code, there's
an official extension that starts `kai lsp` automatically.
For Neovim, configure `nvim-lspconfig` with `kai lsp` as the
command.

The LSP is the piece that makes development in kaikai
comparable, in everyday ergonomics, to Rust or TypeScript:
feedback is instantaneous, no need to go to the terminal to
discover an error.

## 16.8 Interactive documentation: `kai info`

Alongside `kai lsp`, which serves the editor, sits `kai info`:
language reference pages, organized by topic, accessible from
the command line without opening a browser. The style is Unix
`man` or `info`, but the content is kaikai itself.

With no arguments it lists the topics it knows about:

```
$ kai info
kai info — language reference, organized by topic.

Topics:
  actors       Message-passing concurrency built on fibers
  effects      Algebraic effects and handlers
  ffi          Foreign function interface — calling C via `Ffi`.
  fibers       Structured concurrency via nursery, spawn, await, cancel
  holes        Typed holes for incremental development.
  idiomatic    How to write kaikai the way kaikai wants to be written.
  install      Install and self-update the kaikai compiler.
  lint         A Clippy-style linter for suspect-but-valid code.
  llm          Bootstrap guide for an agentic AI pointed at a kaikai repo.
  loop         Control flow — `if`, `while`, `until`, and iteration via pipes.
  lsp          The kaikai Language Server (`kai lsp`).
  match        Pattern matching with exhaustiveness checking.
  packages     `kai.toml`, imports, visibility.
  pipes        Apply, map, flat-map, filter — four pipe operators.
  protocols    Single-dispatch protocols, Go/Clojure/Elixir-style.
  syntax       One-page reference of the forms kaikai actually has.
  testing      Test blocks, assertions, benchmarks, property checks.
  units        Units of measure on `Real`.
```

Pass a topic and it prints the page:

```
$ kai info holes
# holes
...
```

Three useful flags:

- `kai info --list` — topic names only, one per line. Handy
  for shells and scripts.
- `kai info -k <keyword>` — search across all topics. Returns
  the ones that mention the word.
- `kai info <topic> --json` — the structured page as JSON.

That last form is deliberate: kaikai treats its own
documentation as **data**, not as static prose. An AI agent
can consume `kai info effects --json` and have the full
documentation of the effect system at hand without having to
scrape markdown or keep a clone of the language's repo. It is
the other end of the bridge that ch. 15 opens from the holes
side: the language gives whoever is writing code — human or
agent — the information they need, in the format that best
suits them.

The same idea extends to `kai build`. Three flags emit
structured information instead of diagnostic prose:

- `kai build --diags-json` — every compiler error and warning
  as a JSON array, with fields `severity`, `file`, `line`,
  `col`, `message`, `code`. What the editor consumes through
  LSP is also reachable from scripts and agents that call
  `kai build` directly.
- `kai build --effects-json` — the effect row inferred for
  each `pub` function in the file. Lets an agent answer
  "does this function touch disk?" without parsing source.
- `kai build --library-mode` — compile without requiring a
  `fn main`. Useful for analyzing packages meant to be used
  as a library.

The three share a purpose: making the information the
compiler already has live outside the binary, in a format
any consumer can process without reimplementing the typer.

## 16.9 The stdlib reference: `kai doc`

`kai info` documents the **language**, by topic. Its sibling
`kai doc` documents the **stdlib**, by module: it reads the
`#[doc("...")]` attributes each stdlib function carries and
prints them in the terminal. Where `kai info effects` explains
the effect system, `kai doc effects` lists the atomic
capabilities the runtime ships.

With no arguments it lists the modules:

```
$ kai doc
kai doc — stdlib reference, by module.

Modules:
  array                Bridge helpers between `[T]` (linked list) and `Array[T]`
  collections/hashmap  Mutable, separately-chained hash table `HashMap[k, v]` behind the
  core/string          core.string — byte-indexed string helpers over the runtime string
  date                 Civil calendar dates (proleptic Gregorian).
  encoding/json        stdlib/encoding/json.kai — JSON encoder + decoder.
  string_builder       Amortized text accumulator.
  ...
```

Pass a module and it prints its symbol table with a one-line
summary for each entry:

```
$ kai doc date
# date   (date.kai)

  Civil calendar dates (proleptic Gregorian).

  add_days       Shift by `n` civil days (negative goes backwards). Total: every
  day_of_week    ISO-8601 weekday numbering: 1 = Monday … 7 = Sunday.
  make           Validating constructor. `None` when the month is outside 1..12 or
  parse          Strict ISO-8601 `YYYY-MM-DD`: exactly 10 chars, ASCII digits in the
  today          Today's civil date in UTC. The only effectful fn in this module —
  ...

Run 'kai doc date.<symbol>' for a symbol's signature and full doc.
```

And `module.symbol` shows a symbol's signature and full doc:

```
$ kai doc date.parse
# date.parse   (date.kai)

  parse(s: String) -> Option

  Strict ISO-8601 `YYYY-MM-DD`: exactly 10 chars, ASCII digits in the
  three fields, `-` separators. Anything else — wrong length, signs,
  spaces, `2026/01/02`, `2026-1-2` — is `None`, as is a well-formed
  string naming an invalid date (`2026-02-30`, `2026-13-01`).
```

`kai doc` resolves names against the current package, not just
the stdlib: if your project has a module carrying `#[doc("...")]`
attributes, it reads those too: you document your code with the
same attribute the stdlib uses, and the same tool surfaces it.

## 16.10 Two backends: native and C

`kai build` and `kai run` have two codegen backends. The default
is **`native`**: it lowers to LLVM linked into the compiler, in
the same process, and emits a native object. It writes no `.ll`
text and spawns no `clang`. Because libLLVM is linked into
`kaic2`, the binary you produce runs the native backend with no
system LLVM.

The other is **`--backend=c`**: the portable C-text backend,
which emits C and links it with `cc`. It's the compiler's own
bootstrap path and the more portable fallback. If you hit a
construct the native backend doesn't cover yet, `--backend=c`
usually compiles it.

```
$ kai build app.kai                  # native backend (default)
$ kai build --backend=c app.kai      # portable C backend
```

A handful of environment variables control the `kai` binary's
behavior for special cases:

- **`KAI_BACKEND`** (`c` | `native`): the default backend when
  you don't pass `--backend`. The flag overrides it.
- **`KAI_NATIVE_OPT`** (`0|1|2|3|s|z`, default `2`): the
  optimization level of the native backend's LLVM pipeline.
  `--debug` lowers it to `0`, `--release` keeps it at `2`.
- **`CC`** (default `cc`) and **`CFLAGS`**: the C compiler and
  its flags, used **only by the `c` backend** to produce the
  final executable (`CC=clang`, `CFLAGS=-O3`).
- **`KAI_NO_STDLIB=1`**: skips automatic stdlib loading. For
  advanced cases: compiler bootstrap, embedded targets without
  full libc, experiments.
- **`KAI_STDLIB`**: override the stdlib root. By default, `kai`
  auto-detects where it lives (installed vs development
  checkout). If you want to use an alternate version, you point
  it here.
- **`KAI_INCLUDE`**: override the runtime headers (`runtime.h`)
  root. Same principle as `KAI_STDLIB`.

For normal use you don't need to touch any of this. The binary
comes preconfigured to find its own things.

## 16.11 Typical project structure

A standard kaikai project looks like this:

```
myapp/
├── kai.toml              # package manifest
├── kai.lock              # lockfile (commit with the code)
├── main.kai              # entry point
├── lib/                  # public modules (if it's a library)
│   ├── core.kai
│   └── parser.kai
├── tests/                # heavy tests that don't fit inline
│   └── integration.kai
└── examples/             # demos that use the library
    └── basic/
        ├── kai.toml      # with `mylib = { path = ".." }`
        └── main.kai
```

Conventions:

- **`main.kai`** at the root if the project produces an
  executable. The signature must be `fn main() : ... = ...`.
- **`lib/`** for the importable code of a library project.
  When someone installs your package with `kai add`, what
  they see via import is what lives under `lib/`.
- **`tests/`** for tests you prefer to keep separate (for
  example, because they're slow or use IO). Inline tests in
  the source file remain the primary pattern.
- **`examples/<name>/`** for demos. Each demo has its own
  `kai.toml` declaring a local dependency on the main
  package. That lets you exercise the library as an external
  consumer would.

None of this is required. `kai run file.kai` runs any
`.kai` file regardless of where it lives. But when the
project grows, this structure pays off.

## 16.12 Talking to C: `extern "C"` and the `Ffi` effect

Sooner or later you need a library that already exists in
C: a database driver, a graphics framework, a numeric
package. kaikai's foreign function interface (**FFI**) is
how you call into it from kaikai code without giving up the
type system or the effect row.

### Declaring an external function

The simplest case is binding a libc function directly:

```kai
extern "C" fn llabs(n: Int) : Int / Ffi

fn main() : Unit / Console + Ffi {
  print("|-7| = #{llabs(0 - 7)}")
}
```

```
$ kai run abs.kai
|-7| = 7
```

Reading line by line:

- **`extern "C" fn name(args) : T / Ffi`** declares an
  external symbol. The compiler emits a forward declaration
  for the C linker to resolve. The body is implicit: the
  call site lowers to a direct C function call.
- **`/ Ffi`** is the effect. Any function that calls an
  `extern "C"` declaration — directly or transitively — has
  `Ffi` in its row. Same discipline as `Stdout` or `File`:
  a function that talks to C says so in its signature.

The compiler maps kaikai's primitive types to their C
equivalents at the boundary:

| kaikai | C |
|---|---|
| `Int` | `int64_t` |
| `Real` | `double` |
| `Bool` | `int8_t` (0 / 1) |
| `Char` | `int32_t` (codepoint) |
| `String` | `const char *` (NUL-terminated, kaikai-owned) |
| `Unit` | `void` (return only) |

For exact widths at the boundary there are **fixed-width**
annotations: `U8 U16 U32 U64 I8 I16 I32 I64 F32` pin the precise
C type (`uint8_t`, `int32_t`, `float`, …). They are *boundary-only*
annotations: on the kaikai side the value is still a plain `Int`
(or `Real` for `F32`), so it mixes with ordinary literals and
arithmetic. The shim C-casts at the call.

```kai
extern "C"("SetVolume") fn set_volume(level: U8) : Unit / Ffi
```

Lists and sum types don't cross directly; records do, as structs
by value, which we get to in a moment.

### Renaming the C symbol

Sometimes the C symbol name clashes with a kaikai
identifier or just reads badly inline. Use the optional
parenthesised override:

```kai
extern "C"("abs") fn c_abs(n: I32) : I32 / Ffi
```

The kaikai-side name is `c_abs`; the linker resolves
against `abs`. Useful when the C name is a kaikai
keyword, when you want a kaikai-flavored name on top of a
generic C one, or when you need two kaikai bindings that
target the same C symbol with different signatures.

Note the `I32`. The declaration the compiler emits **is**
the binding contract, and for a symbol the system headers
already declare (all of libc) it must match the exact C
type: `abs` is `int abs(int)`, so the binding says `I32`,
not `Int` — otherwise `cc` rejects the conflicting
redeclaration. And a symbol whose C type has no kaikai
mapping (`size_t`, a libc struct) isn't bound directly: you
wrap it in a small `.c`, as we'll see next.

### Linking against your own C code

For libraries that aren't already in libc, the typical
shape is: write a small C file with the functions you need,
let `kai build` invoke its C compiler with that file
included. The package manager doesn't automate C
compilation, so you wire it via the `CFLAGS` environment
variable that `kai` passes through to the host C compiler.

A minimal example. The C side:

```c
// shim.h
#include <stdint.h>
int64_t my_double(int64_t x);
```

```c
// shim.c
#include "shim.h"
int64_t my_double(int64_t x) { return x * 2; }
```

The kaikai side:

```kai
extern "C" fn my_double(x: Int) : Int / Ffi

fn main() : Unit / Console + Ffi {
  print("double(21) = #{my_double(21)}")
}
```

Building:

```
$ CFLAGS="-include shim.h shim.c" kai build app.kai -o app
$ ./app
double(21) = 42
```

The `CFLAGS` value lets you splice anything the host C
compiler accepts: `-include` to expose declarations,
extra `.c` sources to compile in, `-l<lib>` to link
against installed libraries, `pkg-config --cflags --libs
<package>` to pull in the flags of a system library. Wrap
the whole thing in a `Makefile` when it grows beyond one
line.

It works the same on both backends: the native backend also
links the final object with `cc`, so your extra C sources
come in through the same door.

### Structs by value

A kaikai record can cross the boundary as a C `struct` **by
value**, both ways, by declaring it with `extern "C" type`.
Each field carries an exact width (a fixed-width type or a
nested `extern "C" type`); `Int`, `Real`, and `String` are
rejected as struct fields, because they'd break the layout the
C compiler expects for small structs.

```kai
extern "C" type Color   = { r: U8, g: U8, b: U8, a: U8 }
extern "C" type Vector2 = { x: F32, y: F32 }

extern "C"("vec_add")
fn vec_add(a: Vector2, b: Vector2) : Vector2 / Ffi
```

The shim unwraps the record's fields into a local C struct with
the real widths, calls by value, and re-boxes the returned
struct into a fresh record. The ABI classification (small struct
in registers vs. memory, per SysV or AAPCS) is the C compiler's
job, not kaikai's.

There's one rule to know on the C side: the shim must declare
the struct with the tag the compiler mints, `struct
__kai_ffi_<Name>`, so the by-value calling convention lines up
field-for-field. The canonical, compiling example lives in
`examples/ffi/v2_struct_by_value.kai` with its `v2_shim.c`; `kai
info ffi` carries the exact reference.

Struct-by-value works on **both backends**. On native, the
emitter classifies the struct per the C ABI (registers vs.
memory) directly; on the C backend that classification is
inherited from `cc`. The usual caveat applies: if the struct
you bind is one the system headers already declare (libc's
`div_t`), the kaikai type name won't match C's, and you're
better off wrapping the call in your own shim.

### Opaque handles

For a resource the kaikai side passes from hand to hand but
never inspects — a database connection, a socket — there's
`extern "C" opaque`. The value sits behind a reference-counted
box that parks C's `void *`.

```kai
extern "C" opaque Conn

extern "C"("PQconnectdb") fn connect(s: String) : Conn / Ffi
extern "C"("PQexec")      fn exec(c: Conn, q: String) : Int / Ffi
extern "C"("PQfinish")    fn finish(c: Conn) : Unit / Ffi
```

kaikai's reference counting manages the handle **box**, but it
never frees the C resource living inside it: the binding author
calls the C destructor explicitly (`PQfinish` above). Passing
the handle to two calls doesn't free it twice. Opaque handles
work on both backends.

### What FFI still rejects

Out of scope, rejected at compile time:

- **C unions, bitfields, and variadic functions.** No direct
  binding to `printf`'s family; you wrap them in a fixed-arity
  C helper.
- **C callbacks back into kaikai.** A function-typed extern
  parameter doesn't fit: a kaikai closure is a heap box with
  captures, not a bare C function pointer.
- **Struct fields that aren't fixed-width** or a nested
  `extern "C" type`.

### When to reach for FFI

The honest rule: **only when you genuinely need the C
library**. Each `extern "C"` is a hole in the kaikai-side
guarantees. The compiler can't check what the C function
does with its arguments, can't prove its effects, can't
reason about its memory model. The `Ffi` effect at least
makes the hole visible in the signature, but the audit
weight of that signature is "trust the C library author"
plus "trust the C compiler".

For pure computation, prefer a kaikai implementation. For
IO and OS facilities, prefer the stdlib's effects
(`Stdout`, `File`, `NetTcp`, etc.) — those are already
wired to C internally but in a way the language designers
control. FFI is the right tool for binding existing C
ecosystems you don't want to rewrite: drivers, native UI
toolkits, hardware-specific libraries.

A small heuristic: if you find yourself writing a lot of
`extern "C"` declarations to wrap something, and the library
has a stable C API, that's a candidate to package as a
reusable kaikai binding the rest of the ecosystem can import,
instead of repeating the declarations in every project.

## 16.13 Editions: stability without stagnation

There's one decision the rest of the book takes for granted
without quite explaining it: kaikai uses **editions** to
separate *what we promise won't change* from *what we
reserve the right to move*. The idea isn't new — Rust
formalized it in 2014 — but kaikai takes it seriously from
the start.

### What an edition is

An edition is a name — `tongariki`, `hanga-roa`, `orongo` —
that pins a version of the **language contract** between
kaikai and your code. Within one edition, the following
don't change in incompatible ways:

- syntax and reserved keywords;
- type and effect system semantics;
- `pub` signatures in stdlib;
- the `kai` CLI flags and behavior;
- the `kai.toml` schema.

Outside the contract — and therefore free to change between
releases — is everything that doesn't touch your source:
internal variant layout, fiber stack format, on-disk cache
format, exact diagnostic wording, typer passes, Perceus
internals, performance characteristics.

The commitment to you is simple: **upgrading the compiler
is painless**. Read the release notes, install the new
version, recompile. The commitment to the kaikai team is
also simple: we can iterate hard on internals as long as we
don't break what's outside — which is the whole point of the
bargain.

### How you declare it

In your `kai.toml`:

```toml
name = "myapp"
version = "0.1.0"
edition = "hanga-roa"

[dependencies]
```

And to check the active edition of your installation:

```
$ kai --version
kaikai 0.99.6 - hanga-roa (stage 2, self-hosted)
```

If `kai.toml` omits the field, the compiler assumes the
installation's default edition. Recommendation: as soon as a
package is going to live past a weekend, pin it explicitly.
It's the difference between "compiles today" and "will
keep compiling."

### Multi-edition: old code, new compiler

The kaikai compiler accepts **any edition it knows about**.
If your package declares `edition = "tongariki"` and the
installation is on `hanga-roa`, the compiler applies the
tongariki rules to that package — even when another package
on the same machine builds against hanga-roa. That's the
mechanic behind "stability without stagnation": you don't
have to migrate your whole world at once.

When an edition is sunset (after the ecosystem has migrated),
later kaikai releases may drop support for it. Until then,
old and new coexist.

### The escape hatch: `#[unstable]`

Sometimes a module wants to expose a new API *for real*
without yet committing to the exact signature. The
`#[unstable]` annotation marks declarations as outside the
edition contract:

```kai
#[unstable]
pub fn from_stdin() : Source[String, Stdin + Spawn] / Spawn =
  ?from_stdin

#[unstable]
pub type Source[t, e] = { pid: Pid[Demand] }
```

Consuming an `#[unstable]` API has to be declared in **your
own** `kai.toml`:

```toml
[unstable]
ahu = true
```

The idea: nobody uses an API in flux without knowing. The
edition contract still covers everything else.

### Existing editions

At the time this book ships, kaikai knows three:

| Edition | Status | Notes |
|---|---|---|
| `tongariki` | closed | Fast-iteration phase before 2026. Only packages that haven't migrated. |
| `hanga-roa` | active (default) | The first public edition. This book is written against it. |
| `orongo` | future | The stabilization edition. It ships as 0.100.x: the "1.0" label is postponed indefinitely, because the stability commitment lives in the edition, not in a number. |

The names follow the Rapa Nui geography used across the
ecosystem: places on Rapa Nui in chronological order —
Tongariki, Hanga Roa, Orongo, and Anakena as the horizon
after that. The language's milestones are defined per
edition, never by a version number with an aura. When
`hanga-roa` is sunset, you'll get an announcement, a
migration guide, and `kai migrate` to automate the
mechanical changes — the tool already exists: it rewrites a
file's AST between editions, dry-run by default (prints
without touching anything), applying with `--write`,
idempotently. Until then, what you wrote against hanga-roa
keeps compiling.

## 16.14 Philosophy: three principles of the tooling

If you want to keep the overall feel of the tooling, three
ideas:

1. **Speed first.** Compiling and running must feel
   immediate. If the edit-save-run cycle is slow, the
   programmer writes less code, tests less, and builds less
   confidence. All of kaikai's tooling is designed against
   that clock.

2. **One right way for each thing.** A canonical formatter
   with no options. A package manager with MVS and no
   complex resolution. A test system integrated into the
   language. The philosophy is the same as Go's: minimize
   the decisions the programmer has to make about how to
   use the tools, to free time for deciding what to build.

3. **What matters is what comes out of the compiler.**
   Precise diagnostics, exact counterexamples, structured
   formats (JSON for holes and types). The compiler is the
   real interface of the language. Making it clear and fast
   is what makes kaikai usable, before any sophisticated
   IDE.

These aren't empty words. Every time the language grows a
feature, the question "how is this going to feel in the
tooling?" gets asked before "is it theoretically elegant?".
Sometimes elegance wins (algebraic effects do pay some
tooling complexity); sometimes tooling wins (exhaustiveness
rules and local inference get tuned to make the messages
good). The balance is live, and this chapter is its visible
face.
