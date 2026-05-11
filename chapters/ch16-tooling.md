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
compiler (`kaic2`) that produces C, then invokes `cc` to
compile to an executable, and finally runs the executable.

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

### Fast compilation

`kai run` and `kai build` are designed to feel immediate. A
program of a few hundred lines compiles in less than a
second on a reasonable machine. That speed isn't an
accident: the compiler is self-hosted (kaikai compiled in
kaikai), avoids costly passes like global type inference
where it doesn't need to, and emits C directly instead of
going through LLVM. For larger programs there's a cache
(chapter 8 §8.8 covers the package cache; the per-file
compilation cache is another story).

To put it in perspective: a Rust compiler of comparable
size can take 30 seconds. A kaikai compiler of the same
size takes less than a second. The difference shows.

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

- One single correct way to print any file.
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

## 16.4 Package management: `init`, `add`, `install`, `update`

Chapter 8 §8.5-8.8 covered the package model (`kai.toml`
manifest, `kai.lock` lockfile, shared cache,
minimum-version selection). Here we list the subcommands
that orchestrate the model:

```
$ kai init myapp
kai-pkg: wrote kai.toml for package 'myapp'

$ kai add github.com/lnds/manutara@v0.1.0
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

## 16.5 Development mode: `kai watch`

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

## 16.6 Editor integration: `kai lsp`

`kai lsp` is the Language Server that kaikai exposes for
editors. It implements the standard Language Server Protocol,
so any editor with LSP support (VS Code, Neovim, Emacs,
IntelliJ with plugin) can connect and get:

- Type-on-hover: hover over an expression and see its type.
- Goto-definition: jump to where a name was declared.
- Live diagnostics: errors and warnings from the compiler
  appear in the buffer as you type.

The exact editor configuration varies. For VS Code, there's
an official extension that starts `kai lsp` automatically.
For Neovim, configure `nvim-lspconfig` with `kai lsp` as the
command.

The LSP is the piece that makes development in kaikai
comparable, in everyday ergonomics, to Rust or TypeScript:
feedback is instantaneous, no need to go to the terminal to
discover an error.

## 16.7 Environment variables

Three environment variables control the `kai` binary's
behaviour for special cases:

- **`CC`** (default: `cc`): the C compiler `kai` invokes to
  produce the final executable. If you have multiple C
  versions on the system, or want to use `clang`
  specifically, you set it here: `CC=clang kai run
  file.kai`.
- **`CFLAGS`** (default: empty): extra flags for the C
  compiler. Useful for optimisation (`CFLAGS=-O3`) or
  warnings (`CFLAGS=-Wall`).
- **`KAI_NO_STDLIB=1`**: skips automatic stdlib loading.
  For advanced cases: compiler bootstrap, embedded targets
  without full libc, experiments.
- **`KAI_STDLIB`**: override the stdlib root. By default,
  `kai` auto-detects where it lives (installed vs
  development checkout). If you want to use an alternate
  version, you point it here.
- **`KAI_INCLUDE`**: override the runtime headers
  (`runtime.h`) root. Same principle as `KAI_STDLIB`.

For normal use you don't need to touch any of this. The
binary comes preconfigured to find its own things.

## 16.8 Typical project structure

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

## 16.9 Philosophy: three principles of the tooling

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
   language. The philosophy is the same as Go's: minimise
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
