# Chapter 8 · Modules, imports, organizing code

Up to this point all your code has lived in a single file. That's
the right way to start, but as soon as a program grows, a single
file becomes a problem: readers get lost, changes clash, searches
conflate logical modules that are physically tangled. The code
has to be split into named pieces.

kaikai handles this with a deliberately simple system. **One file
is one module.** There is no `module Foo` declaration. There are
no special files that reopen a module from elsewhere. The module
name is derived from the file path, and that's it. Above modules
sits a second scale: a **project**, described by a `kai.toml`,
that groups its modules and external dependencies. And above the
project, a **package manager** resolves dependencies across
projects.

This chapter walks through the three scales, from smallest to
largest.

## 8.1 One file, one module

Create a file `arithmetic.kai` with a handful of functions:

```kai
pub fn double(x: Int) : Int = x * 2

fn helper(x: Int) : Int = x + 1

pub fn double_plus_one(x: Int) : Int = helper(double(x))
```

Three design decisions appear in these three lines:

- **`pub` marks what the module exports.** By default, a
  declaration is private to the file. Only the things marked
  `pub` are visible from another module that imports this one.
  This is the opposite of Java or C++, where public is the
  default and you have to remember to write `private`.
- **Module names need no declaration.** The file
  `arithmetic.kai` is the module `arithmetic`. Put it under a
  subdirectory like `util/arithmetic.kai` and it becomes the
  module `util.arithmetic`. The name is derived from the path
  relative to the project root.
- **Any `fn`, `type`, `effect`, or `let` can carry `pub`.**
  There is no visibility distinction between types and
  functions: a construct is visible outside the module iff it
  is marked `pub`.

Private functions are useful for breaking up a public one
without polluting the consumer's namespace. In `arithmetic`,
`helper` exists only inside the file; whoever imports the
module never sees it.

## 8.2 `import` and qualified names

To use `arithmetic` from another file:

```kai
import arithmetic

fn main() {
  println("double_plus_one(5) = #{arithmetic.double_plus_one(5)}")
}
```

`import arithmetic` makes the `pub` items of that module
accessible under the prefix `arithmetic.`. The function
`double_plus_one` is called as `arithmetic.double_plus_one`.

The prefix is deliberate. When a project grows to fifteen or
twenty modules, seeing `arithmetic.double_plus_one` in an
expression tells you instantly where it comes from. The
alternative — pulling all names loose into the consumer's
namespace — saves keystrokes but loses the trail.

The same prefix is used for types the module exports and for
constructing them:

```kai
import geometry

fn main() {
  let a : geometry.Point = geometry.Point { x: 0.0, y: 0.0 }
  let b : geometry.Point = geometry.Point { x: 3.0, y: 4.0 }
  println("distance = #{geometry.distance(a, b)}")
}
```

Three uses of the prefix, all consistent: in the type
annotation (`: geometry.Point`), in the record construction
(`geometry.Point { ... }`), and in the function call
(`geometry.distance(a, b)`). One mental pattern.

If a module lives under a subdirectory, the import uses the
same dotted name as the module:

```kai
import util.math

fn main() {
  println("3^4 = #{math.pow(3, 4)}")
}
```

Two details: the file lives at `util/math.kai`, the module is
called `util.math`, but when you use it the prefix is only
`math` (the last segment). That keeps prefixes short without
losing the structural origin.

### Three import forms

kaikai admits three forms that cover the space:

```kai
import math.vector                      # use qualified: vector.dot(a, b)
import math.vector as V                 # alias: V.dot(a, b)
import math.vector.{dot, cross}         # specific names into scope
```

The first is the most common and should be your default: the
prefix `vector.` makes clear where each name comes from. The
second helps when the module name is long or appears many times
and a short alias buys you readability without losing the
trail. The third is **selective import**: an explicit list of
names brought into the local namespace. It pays off only when
those names are the protagonists of the file and the prefix
becomes noise (a `Point` that appears forty times, for
instance). The cost is that the reader no longer knows where
`Point` came from without looking up the file.

**There is no wildcard import.** That is, no
`import math.vector.*` or equivalent that pulls "everything the
module exports" into the local namespace. This is deliberate:
wildcards look convenient at write-time but make future
readers unable to trace where a name came from.

## 8.3 Visibility: the module's contract

`pub` is the contract your module offers to the world.
Everything not marked is private, and marking something `pub`
declares "I will sustain this name, this signature, this type".

A rule the language doesn't enforce but is worth applying:
**keep the public surface narrow.** Every `pub` name is a
commitment you'll have to maintain. If you export a useful
helper today that's specific to your implementation, tomorrow
during a refactor you'll have to choose between breaking
callers and carrying around code you no longer want. Public
is measured in what you promise; private, in what you can
change without notice.

In practice:

- **Exported types:** yes, usually part of the contract.
- **Helper functions:** rarely. If you need to export them,
  ask whether they belong in this module at all.
- **Constants:** yes, if they're part of the API. Otherwise,
  no. `pub` goes in front just like everywhere else, and the
  importer uses it qualified:

  ```kai
  # limits.kai
  pub const MAX_PORT : Int = 65535

  # main.kai
  import limits
  println("max = #{limits.MAX_PORT}")
  ```

Most languages with public-by-default end up with modules
whose "real API" is mixed with everything else. kaikai
inverts that: public is what you named explicitly.

### Private fields inside a public type

There's a useful asymmetry. When you declare
`pub type T = { ... }`, the record's fields are **public by
default**: the type is part of the contract, so are its
fields. That's what you want most of the time.

But sometimes the type itself belongs in the contract while
a particular field is an implementation detail. The `priv`
keyword before a field name marks it as invisible to other
modules:

```kai
pub type Account = {
  name:         String,
  priv balance: Real,
}
```

Outside the module that declares `Account`, `a.balance`
doesn't compile and a literal `Account { name: "x", balance:
100.0 }` doesn't either. Only the declaring module can read
the field and name it when constructing. §4.1.1 covered the
pattern in detail; what matters for ch. 8 is that `priv`
works at **field granularity**, complements the `pub` that
controls visibility at the declaration level, and together
they cover a very common case: "export the type, hide its
interior."

The `ch08/06_priv/` example is a two-file project that shows
exactly this rejection from the other side of the module
boundary.

## 8.4 The stdlib you get for free

There is one special module you **don't need to import**: the
**core**. Functions like `println`, `assert`, `string_concat`,
`real_sqrt` live in the global namespace and are available in
every `.kai` file without ceremony. Other languages call this
the *prelude* (Haskell) or *built-ins* (Python); kaikai calls
it core, and it lives under `stdlib/core/` in the compiler tree.

What lives in core is deliberately small: primitive types,
arithmetic operators, `Option` and `Result`, the `list` and
`string` modules (which is why you write `list.map(xs, f)`
without importing anything), and builtins like `println`,
`length` and `reduce`. The rest of the stdlib (encoding,
networking, files, cryptography) lives in separate modules
imported like any other:

```kai
import stream                # lazy pipelines over streams
import fs.path               # path manipulation
import encoding.json         # JSON parsing
```

The bar for core is high: only what almost every program needs
gets in.

## 8.5 Projects: `kai.toml`

So far we've talked about **modules** inside a single file
tree. When those modules become a unit you want to version,
distribute, or that depends on other similar units, you move to
the second scale: the **project**.

A kaikai project is described by a `kai.toml` file at its root.
The minimal form:

```toml
name = "myapp"
version = "0.1.0"

[dependencies]
```

`name` is the project's name. It must match a simple grammar:
lowercase, digits, underscore and hyphen, not starting with a
digit. This is the same shape Cargo, Go modules, and Hex.pm
use, and it dodges path traversal, flag collisions, and other
nasties.

`version` is the project's version. Before 1.0,
`0.MINOR.PATCH` with breaking changes bumping MINOR (cz
convention). After 1.0, standard semver.

`[dependencies]` is the table where you declare which other
projects yours needs. Empty if your project has no external
deps beyond the stdlib.

### `edition`

There's one more optional field worth pinning the moment a
project stops being a sketch:

```toml
name = "myapp"
version = "0.1.0"
edition = "hanga-roa"

[dependencies]
```

`edition` binds the source to a version of the **language
contract**: syntax, type-system semantics, stdlib signatures,
the `kai` CLI surface. While an edition is active, kaikai
guarantees your project keeps compiling as the compiler moves
forward, even when internals change. When an edition closes
and a new one opens, kaikai keeps accepting the old one — you
just have to declare which one you use.

If you omit the field, the compiler assumes the installation's
default edition. That's fine for sketches; for any project
that will live, pinning the edition is what stops a silent
upgrade from moving the ground under you. Ch. 16 covers the
rest: how editions are chosen, how to migrate between them,
and what `#[unstable]` means for APIs in flux.

### Starting a fresh project

```sh
$ mkdir myapp && cd myapp
$ kai init myapp
kai-pkg: wrote kai.toml for package 'myapp'
```

`kai init` writes the skeleton `kai.toml`. From there you add
`.kai` files and import them as in §8.2.

## 8.6 Dependencies: git, path, lock

When you declare a dependency, three forms are accepted:

```toml
[dependencies]
manutara = { source = "github.com/kaikailang-org/manutara", ref = "v0.1.0" }
kohau = "github.com/kaikailang-org/kohau@v0.2.0"
local = { path = "../another-lib" }
```

The first form (inline table with `source` and `ref`) is the
canonical shape for git dependencies. `source` is the repo
URL. `ref` is whatever git understands as a ref: a tag
(`v0.1.0`), a branch (`main`), or a commit SHA (`abc1234`).
Tags are the convention; branches and SHAs are escape hatches.

The second form (string `"<source>@<ref>"`) is the same thing
shortened. The `@` splits source from ref.

The third form (`{ path = "..." }`) is the **local
dependency**. It points at another project on disk, typically
because you're developing it in parallel. Edit the dependency,
re-run your app, changes show up instantly without
republishing.

### Adding a dependency

```sh
$ kai add github.com/kaikailang-org/manutara@v0.1.0
```

`kai add` does two things atomically: clones the dependency
and writes the entry in `kai.toml`. If the clone fails (bad
URL, missing ref, network error), neither manifest nor
lockfile changes. This matters: the working tree never drifts
into an inconsistent state.

### The lockfile

The first time dependencies are resolved, `kai` clones the
repos, captures the exact commit (SHA), and writes a
`kai.lock`:

```toml
# kai.lock — generated by kai-pkg. Do not edit by hand.

[[package]]
name = "manutara"
source = "github.com/kaikailang-org/manutara"
ref = "v0.1.0"
sha = "abc123def456..."
```

The lockfile closes the contract. If two developers run `kai
install` with the same `kai.toml` and the same `kai.lock`,
they **download exactly the same SHA**, exactly the same file
tree, exactly the same binary at the end. Reproducibility is
the lockfile's core promise.

That's why `kai.lock` is committed alongside the code: it's
part of the project's contract. `kai.toml` declares what you
want; `kai.lock` declares what you got.

### When the lock is updated

- `kai install` creates it if absent; respects it if present.
- `kai update` regenerates it with the latest version of each
  dependency that satisfies the declared ref.
- `kai add` refreshes it when you add a new dependency.
- `kai run` and `kai build` refresh it automatically when they
  detect deps in `kai.toml` not in the lock (first run after a
  `git clone`, say).

## 8.7 Version selection: MVS

When a project depends transitively on the same other project
through two paths with different declared versions, which
version wins?

kaikai handles this with **minimum-version selection (MVS)**,
the algorithm used by Go modules. The rule is blunt but
clear: from the set of versions declared by the transitive
chain, the **maximum** wins.

If your app declares `manutara@v0.1.0` and one of its
dependencies declares `manutara@v0.2.0`, the whole project
uses `v0.2.0`. The underlying assumption is that versions are
backward-compatible within a major: if everyone respects
semver, bumping to the higher number should not break anyone.

MVS contrasts with Cargo's or npm's algorithm, which solves
complex constraints and sometimes downgrades to satisfy
someone. MVS is **predictable**: given the same tree, the
result is the same. There is no "resolver failed", no
diamond-dependency hell.

The price is that the responsibility for compatibility rests
on library authors. If you bump to a version that breaks,
everyone depending transitively on you breaks. That forces
you to take versioning seriously.

## 8.8 Cache and `kai install`

When you download a dependency, it doesn't land in your
project: it lands in a **cache shared across projects**, by
default at `~/Library/Caches/kai/pkg` (macOS) or
`~/.cache/kai/pkg` (Linux).

The cache layout:

```
~/Library/Caches/kai/pkg/
  github.com/kaikailang-org/manutara/
    abc123def456.../              # content pinned to that SHA
    789abc012def.../              # another SHA of the same repo
```

Each entry is identified by its SHA, not by the user-facing
ref. So three different projects asking for
`manutara@v0.1.0` share the same on-disk tree. And if at some
point `v0.1.0` is updated upstream (tag movement, which
shouldn't happen but does), the cache pinned to the original
SHA stays intact.

`kai install` can be run explicitly, but **`kai run` and
`kai build` invoke it automatically** when they detect
unresolved deps. In practice, after `git clone`ing a project,
`kai run main.kai` is enough: the driver downloads what's
missing and runs.

## 8.9 Case study: refactoring a monolith

Imagine a project that started as a single `main.kai` of 800
lines. Inside, three responsibilities are tangled: parsing a
config format, business logic, and file IO. The change rate
has dropped: any modification forces reading too much.

The refactor proceeds in four steps.

### Step 1: split into modules of the same project

Identify the three responsibilities and break them into files:

```
myapp/
├── kai.toml
├── main.kai            # only the main flow
├── config.kai          # config parsing
└── domain.kai          # business logic
```

In `main.kai`:

```kai
import config
import domain

fn main() {
  let cfg = config.load("./config.toml")
  let result = domain.process(cfg)
  println("result: #{result}")
}
```

`config.kai` and `domain.kai` export only the functions
`main` needs. Everything else (helpers, internal types) stays
private.

### Step 2: review `pub`

Walk through every `pub`. For each one, ask: is this really
part of the module's contract, or did I leave it exported by
inertia? Every extra `pub` is a future commitment.

### Step 3: extract a local dependency

`config.kai` turns out to be useful beyond this project. You
extract it into its own repo:

```
config-lib/
├── kai.toml            # name = "config_lib"
└── config.kai

myapp/
├── kai.toml            # now depends on config_lib
├── main.kai
└── domain.kai
```

In `myapp/kai.toml`:

```toml
name = "myapp"
version = "0.1.0"

[dependencies]
config_lib = { path = "../config-lib" }
```

While developing, `config_lib` is a local dependency.
`main.kai` updates its import to `import config_lib.config`
(or an alias if the long name annoys you).

### Step 4: publish

When `config_lib` stabilizes, tag it:

```sh
$ cd ../config-lib
$ git tag v0.1.0
$ git push origin v0.1.0
```

And in `myapp` switch the path to git:

```toml
[dependencies]
config_lib = { source = "github.com/youruser/config-lib", ref = "v0.1.0" }
```

`kai install` downloads the pinned version and the lockfile
nails it down. The code in `main.kai` and `domain.kai`
doesn't change: the imports remain the same.

That's the full trajectory: from one file to modules, from
modules to a project, from a local project to a distributed
dependency. Every step is reversible and optional; none of them
forces you to the next.

## 8.10 Philosophy: simple and predictable

The decisions in this chapter aren't the most expressive
available. Other languages have more powerful module systems:
automatic re-exports, dynamic aliases, modules parameterized
by values. kaikai picks an austere variant and stops there.

The reason is the same as elsewhere in the language: what
eliminates head-scratching matters more than what adds power.
A module system where nothing is imported without appearing
in a visible list, where a module name is derived from its
path, and where dependencies are pinned to an exact SHA is a
system you can understand by reading, without having to
mentally execute it.

It's the same principle as exhaustive pattern matching: if
the compiler can take you to the exact place where you need
to act, you don't need a more sophisticated tool.

## Exercises

**8.1.** Take a program you wrote in earlier chapters and
split it into two files. Identify which declarations need to
be `pub` and which can stay private. Did you feel tempted to
mark something `pub` "just in case"?

**8.2.** Create a project with `kai init`. Add an auxiliary
file under a subdirectory (say, `util/strings.kai`). Import a
function from `main.kai`. What is the module's name from the
import side?

**8.3.** Write two sibling projects on disk: a library
`my_lib` with one public function, and an app `my_app` that
uses it with `{ path = "../my_lib" }`. Edit `my_lib`, re-run
`my_app`. How long is the edit-run cycle?

**8.4.** Open a kaikai project on GitHub (say,
`github.com/kaikailang-org/kaikai`) and read its `kai.toml` if any.
What dependencies does it declare? Do you recognize the
versioning pattern?

**8.5.** If `my_app` declares `manutara@v0.1.0` and a
transitive dependency declares `manutara@v0.2.0`, which
version does the project use? Why does this design avoid the
"diamond dependency hell"? Construct a scenario where MVS may
surprise you.

**8.6.** A library of yours had a `pub fn parse_legacy(s:
String)` that nobody uses anymore. Under what conditions
could you remove it without releasing a `1.0`? What kind of
communication with users do you need first?
