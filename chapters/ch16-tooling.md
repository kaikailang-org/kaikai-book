# Chapter 16 · Tooling: the `kai` binary

So far you've learned the language: syntax, types, effects,
the memory model. But a language without tooling doesn't get
used, and I think that is where several languages better than
this one have stalled. This chapter covers the other side: the
`kai` binary, the thing you work with every day.

It's a reference chapter, with no exercises. You learn which
command to use when, and you keep the list at hand to come
back to.

## 16.1 Compiling and running: `kai run`, `kai build`

The command you'll live with is `kai run`:

```
$ kai run hello.kai
hello, kaikai
```

`kai run` compiles the file to a native binary, runs it, and
forwards any extra arguments to the program. It's your daily
edit-save-run cycle. Underneath, the compiler (`kaic2`) lowers
by default to a native object with LLVM linked into itself — no
`.ll` text on disk, no separate `clang` process — and then runs
the executable.

For the binary without running it, use `kai build`:

```
$ kai build hello.kai
$ ./hello
hello, kaikai

$ kai build hello.kai -o build/hello
$ ./build/hello
hello, kaikai
```

`kai build` just leaves the executable on disk; `-o` says
where. The binary is **essentially static**: it doesn't depend
on the kaikai compiler, only on the system's libc. Copy it to
another machine with the same OS and architecture and it runs.

For shipping or debugging there are two profiles:

```
$ kai build --release app.kai    # -O2, symbols stripped:
                                 # smaller, ready to ship
$ kai build --debug app.kai      # -O0 with DWARF tables
```

With `--debug`, `lldb` or `gdb` set breakpoints on `.kai`
lines, and a panic prints the stack trace as
`file.kai:line`. The native backend builds the DWARF tables;
on `--backend=c` the flag is a no-op. With no flag you get the
middle ground: fast compilation, symbols kept.

### What your program hands back to the shell

A binary talks to the shell through its **exit status**. In
kaikai that costs no system call: if
`main` returns an `Int`, that integer *is* the process status.
With any other return type the program exits 0.

```kai
# examples/ch16/01_exit_status.kai
fn validate(port: Int) : Result[Int, String] =
  if port > 0 and port < 65536 { Ok(port) }
  else { Err("port out of range: #{port}") }

fn main() : Int / Stdout {
  match validate(70000) {
    Ok(p)      -> { println("listening on #{p}"); 0 }
    Err(msg)   -> { println("error: #{msg}"); 1 }
  }
}
```

```
$ kai run examples/ch16/01_exit_status.kai
error: port out of range: 70000
$ echo $?
1
```

It's the C, Go and Rust convention: the `Result` you already
use internally settles, in that final `match`, which number the
process leaves with. Without it, a `set -e`, a CI gate or a
`make` reads as success what your program considers a failure.

Two details:

- **POSIX keeps the low 8 bits.** Returning `256` exits 0 and
  `-1` exits 255. The operating system truncates, not kaikai,
  same as in any other language.
- **Buffered output still flushes.** Returning from `main` takes
  libc's full exit path, so what you printed makes it out.
  `os.process.exit`, by contrast, cuts through `_exit(2)` and
  can cost you the last few lines.

### Fast compilation

`kai run` and `kai build` are designed to feel immediate: a
program of a few hundred lines compiles in under a second on a
reasonable machine. That's no accident. The compiler is
self-hosted (kaikai compiled in kaikai) and lowers to LLVM in
the same process: it builds the module through the LLVM API
and emits the native object directly, with no intermediate
`.ll` text and no separate `clang`. Only the final link
against the runtime goes through `cc`. For larger programs
there's a cache (chapter 8 §8.8 covers the package cache; the
per-file compilation cache is another story).

When you want to start from scratch, `kai clean` deletes the
package's `.kai-cache` and reports the path it removed and how
many MiB that freed. With `--cache` it
also deletes the shared user caches — compiled modules, native
objects, fetched dependencies — which the next build refills
with whatever it needs.

That "under a second" is the steady state, the one you live
in: the chapter-17 case study — about 430 lines across five modules —
builds in about 0.6 seconds. With a cold cache it costs several
times that; on my machine, 4.1 seconds for the same project.
Keep that in mind before you time a cold build and draw the
wrong conclusion.

For perspective, a Rust program of comparable size can take 30
seconds to compile — an order of magnitude you feel on every
save.

### Just check: `kai typecheck`

When all you want to know is whether the program is
well-typed — no binary, no run — `kai typecheck` is the
fastest "does this compile?" answer:

```
$ kai typecheck app.kai
$ echo $?
0
```

On success it prints nothing and exits `0`. On an error, it
prints the diagnostic and exits `1`:

```
$ kai typecheck app.kai
error: type mismatch in function call
  --> app.kai:5:17
    |
  5 |   let n = double(s)
    |                 ^
  = note: expected: (Int) -> Int
  = note: found:    (String) -> ?t0
  = note: in argument 1 of `double`
```

The caret lands on the argument that doesn't fit, and the notes
name which one it is (`in argument 1 of `double``) and what was
expected there.

The point is what `typecheck` does **not** do. It runs the
compiler's full front-end — lexer, parser, name resolution, HM
and effect-row inference, the kind and unit machinery, protocol-
dispatch validation — then monomorphises and stops. No
codegen, no link, no binary. It skips everything a `build`
spends *after* it knows the program is correct, which is why it
finishes in a fraction of the time.

The checking is the same in both; `typecheck` just gets off the
train earlier. If it's silent, the front-end is clean.

The exit code matches too, which matters if you're scripting
it: 0 on a healthy program, 1 on any front-end error, whether
it's a type error, a parse error or an unknown name.
`typecheck` invents no codes of its own: what it prints and the
number it exits with are what `kai build` would have given you.

One honest limit, because the name promises a touch more:
`typecheck` covers the front-end, not the whole pipeline. It
doesn't see backend coverage gaps — a form the front-end
accepts and the code generator cannot emit. A file that passes
`typecheck` almost always builds, but "almost always" is not
"always". For total certainty, the judge is still `kai build`.

The structured-report flags (`--diags-json`, `--holes-json`)
work on `typecheck` just as on `build`: the same report,
without paying for codegen. That makes it the natural tool for
chapter 15's hole loop, where each iteration costs only the
front-end.

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
(default 1000): lower for costly benchmarks, higher for stable
measurements.

The three commands share two properties:

- **They only run the relevant blocks.** `kai test` ignores
  `check` and `bench`; `kai check` ignores `test` and `bench`.
- **The blocks don't land in the production binary.** `kai
  run` and `kai build` drop them entirely.

For an external runner there are two flags that run nothing:
`kai test --json --list` prints the blocks the run would
report, with their id, file and line, and `kai test --json
--deps` adds, per test file, the sources its build reads. They
are there to build a CI plan without compiling.

A fourth command runs none of those blocks: it puts them to the
test. `kai mutate` breaks the code on purpose, one construct at a
time, runs your tests against each broken version, and reports
the **survivors** — the mutants no test noticed:

```
$ kai mutate                                 # the package's modules, judged by `kai test`
$ kai mutate --module src/parser.kai         # a single file
$ kai mutate --limit 20 --operator arm       # a first look, cheapest operator first
$ kai mutate --oracle './run-tests.sh'       # any command that exits 0 when all is well
$ kai mutate --list                          # the sites, without running anything
```

There are six operators: `arm` drops a `match` arm, `compare`
shifts a comparison boundary (`>=` to `>`), `connect` swaps `and`
for `or`, `negate` inverts a condition, `literal` perturbs a
literal, and `call` elides a call. Every mutant costs one run of
the oracle, so start with `--module` and `--limit`. In §7.6 you
ran it over the evaluator and found two holes.

## 16.3 Formatting: `kai fmt`

`kai fmt` is the canonical formatter. `gofmt` style:

- One correct way to print any file.
- One knob, and it isn't a style knob: the line width. The
  project doesn't want style wars.
- Idempotent: formatting an already-formatted file doesn't
  change it.

The width drives the layout. A construct that fits on its
line stays there; one that doesn't breaks at its own points —
after the `=`, one argument per line, one pipe stage per line.
A break you already wrote at one of those points is kept, so
your hand-wrapped pipe chain survives the formatter. The
default is 100 columns; `--width N` changes it for one
run, and the `width` key of the `[fmt]` table in `kai.toml`
fixes it for the package:

```toml
[fmt]
width = 80
```

Four ways to use it:

```
$ kai fmt file.kai                # rewrite in place
$ kai fmt .                       # format the whole package
$ kai fmt --check file.kai        # exit 0 if formatted, 1 if not
$ cat file.kai | kai fmt --stdin  # read stdin, write stdout
```

`--check` is for CI: if the code isn't formatted, the job
fails and forces you to run `kai fmt` before merging.

`--stdin` is for editors: your editor pipes the buffer to the
formatter before saving and writes back the canonical result.

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

The clearest example is the `non_tail_list_recursion` rule. A
function that calls itself on
the tail of a list, outside tail position, spends one stack
frame per element, and a fiber's stack is small:

```kai
pub fn interleave(xs: [String], sep: String) : [String] = match xs {
  []           -> []
  [x, ...rest] -> [sep, x, ...interleave(rest, sep)]   # warning
}
```

With a single head, though — `[x * 2, ...double(rest)]` — the
compiler turns the recursion into a loop when the function's
effect row is empty, and the rule stays quiet. Make that same
function call `println` and the row is no longer empty, the loop
doesn't happen, and the rule speaks up. That distinction
requires the effect row; a textual linter doesn't have it.

The rule you'll see most is `discard_pure_value`. A block drops
the value of every statement that isn't its tail; if that value
isn't `Unit`, it's a forgotten use, whether or not the call that
produced it performs an effect:

```kai
fn run() : Unit / Stdout {
  area(3, 4)        # warning: the Int is dropped
  parse("42")       # warning: the Result is dropped
  println("done")
}
```

To drop a value on purpose, say so: `parse("42") |> ignore` or
`let _ = parse("42")`. Neither form is flagged.

Other rules in the catalog nudge toward idiomatic kaikai.
`point_free_nudge` suggests the point-free section (§6.2)
when a unary lambda only projects on its parameter.
`and_then_to_map_nudge` warns when an `and_then` is really a
`map`, and `match_option_to_combinator` does the same for a
`match` over `Option` that already has a combinator.
`list_concat_literal_to_spread` catches `[h] ++ t`, which
builds a one-element list only to concatenate it away — the
spread `[h, ...t]` emits the cons directly and skips the
allocation. The rest sweep up residue: `redundant_if_bool`,
`redundant_match_catchall`, `dead_code_unused_priv`,
`effect_over_declared` and `effect_ffi_without_extern`.

Eleven as of today, and the number will climb. A rule earns its
place only when the two forms can be shown equivalent, because
a noisy linter is worse than none. `kai info lint` lists the
current state.

## 16.5 Package management: `init`, `add`, `fetch`, `update`

You met the package model (`kai.toml` manifest, `kai.lock`
lockfile, shared cache, minimum-version selection) in chapter
8 §8.5-8.8. These are the subcommands that drive it:

```
$ kai init myapp
kai-pkg: wrote kai.toml for package 'myapp'

$ kai add github.com/kaikailang-org/manutara@v0.1.0
$ kai fetch                 # resolve deps and write kai.lock
$ kai update                # refresh all deps
$ kai update manutara       # refresh only manutara
$ kai show                  # print parsed kai.toml
```

`kai run` and `kai build` invoke `kai fetch` on their own when
dependencies are declared in `kai.toml` but not resolved in
`kai.lock`. After cloning a kaikai project, `kai run` is
enough to download whatever's missing.

The names split the work the way a Rust or Go user expects:
`fetch` resolves dependencies, and `install` does what it means
in those ecosystems — **put a binary on your PATH** — rather than
what it means in npm:

```
$ kai install .                        # build the cwd package and install its binary
$ kai install github.com/x/pepito      # from a git source
$ kai install github.com/x/pepito@v1   # pinned to a tag, branch, or SHA
$ kai install --list                   # what this prefix installed
```

The binary is named from the manifest's `name` field, not
from the source URL, and lands in `$KAIKAI_HOME/bin`, which
the installer already put on your PATH. Replacing an existing
one requires `--force`. The no-argument form still resolves
dependencies, but warns that its name is now `fetch`:

```
$ kai install
kai: warning: 'kai install' with no argument resolves dependencies; that is now 'kai fetch'.
  'kai install <spec>' installs a package's binary. The no-argument form changes at the next edition.
```

When `hanga-roa` closes, that form goes away.

### Shipping completions with the binary

Half of what makes a CLI pleasant is the shell completing
subcommands and flags. A package declares the scripts it ships
and `kai install` puts each where its shell already looks:

```toml
[completions]
zsh  = "completions/_foo"
bash = "completions/foo.bash"
fish = "completions/foo.fish"
```

Paths are relative to the package; the destination filename
comes from the manifest's `name`, not from the source path, so
the file lands under the name the shell searches for. The three
directories live under `$KAIKAI_HOME/share`, and `install.sh`
wires them into the shell's search path once — so every later
`kai install` works with no per-package step. When that wiring
is missing, `kai install` prints the line to add; it never
edits a startup file behind your back.

One detail with a story behind it: zsh gets its directory
**prepended** to `fpath`, not appended. Appended, a stock
function of the same name still wins — zsh ships an `_mh` that
claims `mark` and then suppresses even filename completion when
MH isn't installed.

Like `[native]`, it's declarative and bounded: three shells, one
fixed destination each, no hooks. A path that escapes the
package or names a missing file is skipped with a warning and
the binary still installs.

Don't confuse `kai update` with `kai upgrade`: `update`
refreshes your package's **dependencies**; `upgrade` updates
the **compiler itself** to the latest release (downloads,
verifies the SHA-256, and swaps the binary in place, as you
did in chapter 1). On a Homebrew install, `upgrade` doesn't
touch the Cellar: it points you to `brew upgrade kaikai` and
exits.

## 16.6 Development mode: `kai watch`

`kai watch` is for when you're iterating hard on a program:

```
$ kai watch main.kai
[watching main.kai...]
```

Every time you save the file, the watcher recompiles and runs.
You keep the result in view without going back to the terminal
to type `kai run` — the fastest way to explore a change in a
demo or a script.

## 16.7 Editor integration: `kai lsp`

`kai lsp` is kaikai's Language Server. It implements the
standard Language Server Protocol, so any editor with LSP
support (VS Code, Neovim, Emacs, IntelliJ with plugin) connects
and gets:

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

Setup varies by editor. VS Code has an official extension that
starts `kai lsp` on its own. In Neovim, you configure
`nvim-lspconfig` with `kai lsp` as the command.

The LSP makes everyday development in kaikai comparable to Rust
or TypeScript: feedback is instant, with no trip to the
terminal to discover an error.

## 16.8 Interactive documentation: `kai info`

Alongside `kai lsp`, which serves the editor, sits `kai info`:
language reference pages, organized by topic, on the command
line with no browser. The style is Unix `man` or `info`, but
the content is kaikai itself.

With no arguments it lists the topics it knows about:

```
$ kai info
kai info — language reference, organized by topic.

Topics:
  actors       Message-passing concurrency built on fibers — `Actor[Msg]` effect
  contracts    Design-by-Contract — `requires` / `ensures` on a function, and
  deltas       Where kaikai deliberately differs from Rust/Go/Python/JS/Haskell
  effects      Algebraic effects and handlers — kaikai's first-class mechanism for
  ffi          Foreign function interface — calling C via the `Ffi` capability.
  fibers       Structured concurrency via nursery, spawn, await, cancel — BEAM-style
  holes        Typed holes for incremental development.
  idiomatic    How to write kaikai the way kaikai wants to be written — the idioms,
  install      Install and self-update the kaikai compiler.
  kinds        Kinds classify types the way types classify values — one closed
  lint         A Clippy-style linter for suspect-but-valid code, beside the compiler.
  llm          Bootstrap guide for an agentic AI pointed at a kaikai repo — what
  loop         Control flow — `if`, `while`, `until`, and iteration via pipes.
  lsp          The kaikai Language Server (`kai lsp`) for editor integration.
  match        Pattern matching with exhaustiveness checking.
  mutate       Break the code on purpose and ask whether anything notices.
  net          Byte-level networking — TCP, UDP, DNS, and Unix-domain sockets.
  packages     `kai.toml`, imports, visibility.
  pipes        Apply (`|>`), map (`|`), flat-map (`||`), filter (`|?`), each (`|!`) —
  protocols    Single-dispatch protocols, Go/Clojure/Elixir-style.
  seq          `Seq[t]` — the lazy sequence: pure, shared, possibly endless. Written
  syntax       One-page reference of the forms kaikai actually has. Every form on
  testing      Test blocks, assertions, benchmarks, property checks.
  units        Units of measure on `Real` — phantom-type discipline, zero runtime
  vec          `Vec[T]` — the pure value vector: flat contiguous storage with
...
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

I added that last form on purpose: kaikai treats its own
documentation as **data**. An AI agent consumes
`kai info effects --json` and has the full effect-system docs
at hand without scraping markdown or cloning the language's
repo. It is the other end of the bridge that ch. 15 opens from
the holes side: the language gives whoever is writing code —
human or agent — the information they need, in the format that
suits them best.

The idea extends to `kai build`. Three flags emit
structured information instead of diagnostic prose:

- `kai build --diags-json` — the compiler's diagnostics as
  JSON: an object with the file, a `status` (the exit code
  the build would give) and a `diagnostics` array. Each entry
  carries `severity`, `file`, `line`, `col`, `message` and a
  `related` list with the notes. What the editor consumes
  through LSP is also reachable from scripts and agents that
  call `kai build` directly. The array does not cover
  everything: a kind error or a contract violation leaves
  `status` at 1 and the array empty, with the text on stderr.
  The reliable signal that a build fails is `status`.
- `kai build --effects-json` — every function's effect row,
  one entry per function with `file`, `fn`, `line`, `col`,
  `effects`, `row_open` and `handlers_installed`. The report
  includes the prelude's functions, so a consumer filters by
  `file`. Lets an agent answer "does this function touch
  disk?" without parsing source.
- `kai build --library-mode` — runs the front-end without
  requiring a `fn main` and answers the `# @probe <kind> L:C`
  comments it finds in the source: type, definition,
  completion, signature. It is what `kai lsp` uses underneath
  for hover and go-to-definition.

All three get out of the compiler what it already knows, in a
format any consumer can process without reimplementing the
typer.

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
  collections/queue    Amortised-O(1) two-list FIFO queue (Okasaki).
  collections/stack    LIFO stack, a wrapper over `[a]`.
  date                 Civil calendar dates (proleptic Gregorian).
  encoding/base64      Base64 encoder/decoder.
  encoding/hex         Hexadecimal encoding of `[Int]` byte lists.
  path                 POSIX path manipulation.
  string_builder       `StringBuilder` — an amortised text accumulator.
  uuid                 RFC 4122 UUID v4 generator + parser.
  ...
```

Pass a module and it prints its symbol table with a one-line
summary for each entry:

```
$ kai doc date
# date   (date.kai)

  Civil calendar dates (proleptic Gregorian).

  add_days               Shift by `n` civil days (negative goes backwards).
  day_of_week            ISO-8601 weekday numbering: 1 = Monday … 7 = Sunday.
  days_in_month          Days in `m` of year `y`.
  make                   Validating constructor.
  to_string              `YYYY-MM-DD`, zero-padded (year to 4 digits, month/day to 2).
  today                  Today's civil date in UTC.
  ...

Run 'kai doc date.<symbol>' for a symbol's signature and full doc.
```

And `module.symbol` shows a symbol's signature and full doc:

```
$ kai doc date.parse
# date.parse   (date.kai)

  parse(s: String) -> Option[Date]

  Strict ISO-8601 `YYYY-MM-DD`: exactly 10 chars, ASCII digits in the
  three fields, `-` separators. Anything else — wrong length, signs,
  spaces, `2026/01/02`, `2026-1-2` — is `None`, as is a well-formed
  string naming an invalid date (`2026-02-30`, `2026-13-01`).
```

`kai doc` also resolves names against the current package. You
document your code with the same `#[doc("...")]` the stdlib
uses, and the same tool surfaces it.

## 16.10 Two backends: native and C

`kai build` and `kai run` have two codegen backends. The default
is **`native`**: it lowers to LLVM linked into the compiler, in
the same process, and emits a native object, with no `.ll`
text and no `clang`. Because libLLVM is linked into `kaic2`,
the native backend needs no system LLVM.

The other is **`--backend=c`**: it emits C and links it with
`cc`. It's the compiler's own
bootstrap path and the more portable fallback. If you hit a
construct the native backend doesn't cover yet, `--backend=c`
usually compiles it.

```
$ kai build app.kai                  # native backend (default)
$ kai build --backend=c app.kai      # portable C backend
```

A handful of environment variables tune `kai` for special
cases:

- **`KAI_THREADS`** (integer): how many OS threads the M:N
  scheduler of the program you run will use. With the variable
  unset, the runtime takes the host's core count (capped at 32).
  `KAI_THREADS=1` falls back to the byte-identical
  single-threaded cooperative scheduler — handy when you want
  reproducible output. It's the only one on this list that
  affects the executable rather than the compile.
- **`KAI_BACKEND`** (`c` | `native`, default `native`): the
  backend used when you don't pass `--backend`. The flag
  overrides it.
- **`KAI_NATIVE_OPT`** (`0|1|2|3|s|z`): the optimization
  level of the native backend's LLVM pipeline. `kai build` uses
  `2` and `kai run` uses `1`, since a program compiled to run once
  never earns back the time `-O2` takes. `--debug` lowers it to
  `0`, `--release` keeps it at `2`.
- **`CC`** (default `cc`) and **`CFLAGS`**: the C compiler and
  its flags, used **only by the `c` backend** to produce the
  final executable (`CC=clang`, `CFLAGS=-O3`).
- **`KAI_NO_STDLIB=1`**: skips automatic stdlib loading. For
  advanced cases: compiler bootstrap, embedded targets without
  full libc, experiments.
- **`KAI_STDLIB`**: override the stdlib root. By default, `kai`
  auto-detects where it lives (installed vs development
  checkout). To use an alternate version, point it here.
- **`KAI_INCLUDE`**: override the runtime headers (`runtime.h`)
  root. Same principle as `KAI_STDLIB`.

For normal use you touch none of this: the binary finds its own
things, and `kai env` shows you **what** it found, already
resolved:

<!-- transcripto: paths and toolchain id are per machine -->
```
$ kai env
KAIKAI_HOME=/Users/you/.kaikai
KAI_STDLIB=/Users/you/.kaikai/share/kaikai/stdlib
KAI_TOOLCHAIN_ID=1791118538-57238280
KAI_KAIC2=/Users/you/.kaikai/libexec/kaikai/kaic2
```

It's the first thing to check when something compiles on one
machine and not another: it's rarely the code, almost always
`KAI_STDLIB` pointing somewhere else. Given a name as an
argument it prints just that value, handy for a script.

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
- **`lib/`** for the importable code of a library. Whoever
  adds your package with `kai add` sees, via import, what lives
  under `lib/`.
- **`tests/`** for tests you prefer to keep separate (for
  example, because they're slow or use IO). Inline tests in
  the source file remain the primary pattern.
- **`examples/<name>/`** for demos. Each demo has its own
  `kai.toml` with a local dependency on the main package, so
  you exercise the library as an external consumer would.

None of this is required: `kai run file.kai` runs any `.kai`
file wherever it lives. But when the project grows, this
structure pays off.

## 16.12 Talking to C: `extern "C"` and the `Ffi` effect

Sooner or later you need a library that already exists in
C: a database driver, a graphics framework, a numeric
package. With kaikai's foreign function interface (**FFI**)
you call into it without giving up the type system or the
effect row.

### Declaring an external function

The simplest case is binding a libc function directly:

```kai
# examples/ch16/ffi/01_libc_abs.kai
extern "C" fn llabs(n: Int) : Int / Ffi

fn main() : Unit / Stdout + Ffi {
  print("|-7| = #{llabs(-7)}")
}
```

```
$ kai run examples/ch16/ffi/01_libc_abs.kai
|-7| = 7
```

Line by line:

- **`extern "C" fn name(args) : T / Ffi`** declares an
  external symbol. The compiler emits a forward declaration
  for the C linker to resolve. The body is implicit: the
  call site lowers to a direct C function call.
- **`/ Ffi`** is the effect. Any function that calls an
  `extern "C"` declaration — directly or transitively — has
  `Ffi` in its row. Same discipline as `Stdout` or `File`:
  a function that talks to C says so in its signature.

At the boundary, the compiler maps kaikai's primitives to
their C equivalents:

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
by value, which you'll meet further down.

### Renaming the C symbol

When the C symbol name clashes with a kaikai identifier or
reads badly inline, use the optional parenthesised override:

```kai
extern "C"("abs") fn c_abs(n: I32) : I32 / Ffi
```

The kaikai-side name is `c_abs`; the linker resolves against
`abs`. Useful when the C name is a kaikai keyword, when you
want a kaikai-flavored name, or when you need two bindings
that target the same C symbol with different signatures.

Note the `I32`. The declaration the compiler emits **is**
the binding contract, and for a symbol the system headers
already declare (all of libc) it must match the exact C
type: `abs` is `int abs(int)`, so the binding says `I32`,
not `Int` — otherwise `cc` rejects the conflicting
redeclaration. A symbol whose C type has no kaikai mapping
(`size_t`, a libc struct) isn't bound directly: you wrap it in
a small `.c`, as in the next section.

The complete binding, with its call site:

```kai
# examples/ch16/ffi/02_rename.kai
extern "C"("abs") fn c_abs(n: I32) : I32 / Ffi

fn main() : Unit / Stdout + Ffi {
  print("|-7| = #{c_abs(-7)}")
}
```

```
$ kai run examples/ch16/ffi/02_rename.kai
|-7| = 7
```

### Linking against your own C code

For libraries that aren't in libc, you write a small C file
with the functions you need and let `kai build` compile it with
its C compiler. There are two ways to wire it up, depending on
whether this is a one-off program or something other people
will use.

A minimal example. The C side:

```c
// examples/ch16/ffi/03_shim/shim.h
#include <stdint.h>
int64_t my_double(int64_t x);
```

```c
// examples/ch16/ffi/03_shim/shim.c
#include "shim.h"

int64_t my_double(int64_t x) {
  return x * 2;
}
```

The kaikai side:

```kai
# examples/ch16/ffi/03_shim/app.kai
extern "C" fn my_double(x: Int) : Int / Ffi

fn main() : Unit / Stdout + Ffi {
  print("double(21) = #{my_double(21)}")
}
```

For a one-off program you wire it by hand through the
`CFLAGS` environment variable, which `kai` passes to the host
C compiler:

```
$ cd examples/ch16/ffi/03_shim
$ CFLAGS="shim.c" kai build app.kai -o app
$ ./app
double(21) = 42
```

`CFLAGS` lets you splice in anything the host C compiler
accepts: `-include` to expose declarations,
extra `.c` sources to compile in, `-l<lib>` to link
against installed libraries, `pkg-config --cflags --libs
<package>` to pull in the flags of a system library. It is
the escape hatch, and it keeps precedence over everything
else.

But `CFLAGS` doesn't travel. If your binding is a package,
whoever uses it has no business knowing there's a `.c`
inside, let alone guessing the right environment variable.
That's what the manifest's `[native]` table is for:

```toml
[native]
sources = ["c/shim.c"]   # vendored C, relative to the package
include = ["c"]          # -I dirs for compiling those sources
libs = ["sqlite3"]       # system libraries, -l<name> at link
```

With that declared, the consumer types plain `kai build`.
Every verb honors the table — `build`, `run`, `test`,
`install` — on both backends, and it propagates transitively:
if A and B both depend on the same shim-binding package, the
shim compiles and links exactly once.

It is purely declarative: `sources`, `include`, `libs`, no
build scripts and no free-form flags. A build
script is somebody else's code running on the installer's
machine — attack surface and a reproducibility hole — and
free-form flags would turn the manifest into a build system.
The distinction that does matter is between `sources` and
`libs`: a vendored source always works, because the `.c`
travels with the package and compiles on the target machine;
a system library may be absent there through nobody's fault,
and when the link fails the driver names the package and the
library that was missing.

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

On the kaikai side an `extern "C" type` is an ordinary record:
`Vector2 { x: 1.0, y: 2.0 }` builds one, `Vector2 { ...v, x: 5.0 }`
copies one with a field changed, and `v.x` reads a field. It
follows the visibility rules of `type`, too: to use it from
another module, or to name it in a `pub` signature, mark it
`pub` after `extern "C"` (`extern "C" pub type Vector2 = ...`).
The same goes for `extern "C" opaque`.

On the C side, the shim includes the `kai_ffi.h` that kaikai
generates beside the build, with one `typedef` per
`extern "C" type`, and names those same types. That keeps one
definition of each struct, so a layout mismatch is a C compile
error rather than silently corrupted data at the boundary:

```c
#include "kai_ffi.h"        /* provides Color, Vector2 */

Vector2 vec_add(Vector2 a, Vector2 b) {
    Vector2 r = { a.x + b.x, a.y + b.y };
    return r;
}
```

The canonical example lives in
`examples/ffi/v2_struct_by_value.kai` in the language repo;
`kai info ffi` carries the reference.

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

An extern type, `opaque` or `type`, is private unless you mark
it, like any other declaration. While the handle stays inside
the module that is fine; the day a `pub` signature names it or
another module imports it, write
`extern "C" pub opaque Conn`. Forget it and the compiler names
both the type and the signature leaking it:

```
error: pub fn `open` exposes non-pub type `Conn` from module `conn`; mark `Conn` as `pub` or remove it from the signature
```

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
guarantees. The compiler can't check what the C function does
with its arguments, prove its effects, or reason about its
memory model. The `Ffi` effect at least makes the hole visible
in the signature, but auditing that signature means "trust the
C library author" plus "trust the C compiler".

For pure computation, prefer a kaikai implementation. For IO
and OS facilities, prefer the stdlib's effects (`Stdout`,
`File`, `NetTcp`, etc.) — they're already wired to C
internally, in a way the language designers control. FFI is
the tool for binding existing C ecosystems you don't want to
rewrite: drivers, native UI toolkits, hardware-specific
libraries.

A heuristic: if you find yourself writing a lot of
`extern "C"` declarations to wrap a library with a stable C
API, package them as a reusable kaikai binding the rest of the
ecosystem can import, instead of repeating the declarations in
every project.

## 16.13 Editions: stability without stagnation

The rest of the book takes one decision for granted without
quite explaining it: kaikai uses **editions** to
separate *what we promise won't change* from *what we
reserve the right to move*. The idea isn't new — Rust
formalized it in 2014 — but kaikai takes it seriously from
the start.

### What an edition is

An edition is a name — `tongariki`, `hanga-roa`, `orongo` —
that bounds the **language contract** between kaikai and
your code. The contract covers what you touch when you
write:

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

What you need to be clear about today: **the contract is
sealed when the edition closes, not before.** In `hanga-roa`
that surface is still being decided. An incompatible change to
the list above is part of the work of building the promise; it
doesn't break it. A `pub` signature is put to the test, and if
it does not earn its place, it leaves.

Those changes don't get buried in git history. They're
recorded as they happen in the language repository's
`docs/editions.md`, under *Breaking changes accumulated for
the Orongo cut*, each with its migration beside it. That list
will feed the release notes and the `kai migrate` rules when
`orongo` closes the edition. Until then it's your changelog:
what you read before you upgrade.

The commitment comes in two tenses. Today, under `hanga-roa`,
breaking changes are few, recorded, and ship with migration
guidance. Under `orongo`, the surface is pinned and upgrading
the compiler stops requiring any reading first. The edition is
the mechanism that decides when the surface stops moving.

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
kaikai 0.169.0 - hanga-roa (stage 2, self-hosted)
demos baseline: 37
native p2:      active
home:           https://kaikai-lang.org
```

The first line gives you version and edition. The other three
are build diagnostics — how many demos the baseline covers,
which native backend came up active — and you'll want them
when you report a problem.

If `kai.toml` omits the field, the compiler assumes the
installation's default edition. As soon as a package is going
to live past a weekend, pin it explicitly: it's the difference
between "compiles today" and "will keep compiling."

### Multi-edition: old code, new compiler

The compiler accepts **any edition it knows about**. If your
package declares `edition = "tongariki"` and the installation
is on `hanga-roa`, the compiler applies the tongariki rules to
that package — even when another package on the same machine
builds against hanga-roa. That's the mechanic behind
"stability without stagnation": you don't have to migrate your
whole world at once.

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

That way nobody uses an API in flux without knowing, and the
edition contract still covers everything else.

### Existing editions

At the time this book ships, kaikai knows three:

| Edition | Status | Notes |
|---|---|---|
| `tongariki` | closed | Fast-iteration phase before 2026. Only packages that haven't migrated. |
| `hanga-roa` | active (default) | The first public edition. This book is written against it. |
| `orongo` | future | The stabilization edition. No version number is pinned to it yet: an edition spans many compiler releases, because the commitment lives in the edition, not in a number. The "1.0" label is postponed indefinitely. |

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

The tooling comes down to three ideas:

1. **Speed first.** Compiling and running must feel
   immediate. If the edit-save-run cycle is slow, you write
   less code, test less, and trust what you have less. All of
   kaikai's tooling is designed against that clock.

2. **One right way for each thing.** A canonical formatter
   with no style options. A package manager with MVS and no
   complex resolution. A test system integrated into the
   language. The philosophy is Go's: minimize the decisions
   about how to use the tools, so your time goes to deciding
   what to build.

3. **What matters is what comes out of the compiler.**
   Precise diagnostics, exact counterexamples, structured
   formats (JSON for holes and types). The compiler is the
   real interface of the language. Making it clear and fast
   is what makes kaikai usable, before any sophisticated
   IDE.

Every time the language grows a feature, the question "how is
this going to feel in the tooling?" gets asked before "is it
theoretically elegant?".
Sometimes elegance wins (algebraic effects do pay some
tooling complexity); sometimes tooling wins (exhaustiveness
rules and local inference get tuned to make the messages
good). The balance is live, and this chapter is its visible
face.
