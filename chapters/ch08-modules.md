# Chapter 8 · Modules, imports, organizing code

So far all your code has lived in a single file. That's the
right way to start, but once a program grows, the single file
gets in the way: readers get lost and changes clash. Time to
split the code into named pieces.

kaikai handles this with a simple system, and I chose that
simplicity on purpose. **One file is one module.** There is no
`module Foo` declaration and no special file that reopens a
module from elsewhere; the module name comes from the file
path. Above modules sits the **project**, described by a
`kai.toml`, which groups its modules and external
dependencies. Above the project, a **package manager**
resolves dependencies across projects. You'll work through the
three scales from smallest to largest.

## 8.1 One file, one module

Create a file `arithmetic.kai` with a handful of functions:

```kai
pub fn double(x: Int) : Int = x * 2

fn helper(x: Int) : Int = x + 1

pub fn double_plus_one(x: Int) : Int = helper(double(x))
```

Three design decisions appear in these three lines:

- **`pub` marks what the module exports.** A declaration is
  private to the file unless it carries `pub`; only what's
  marked is visible to a module that imports this one. This is
  the opposite of Kotlin or Scala, where public is the
  default and you have to remember to write `private`.
- **Module names need no declaration.** The file
  `arithmetic.kai` is the module `arithmetic`. Put it under a
  subdirectory like `util/arithmetic.kai` and it becomes the
  module `util.arithmetic`. The name is derived from the path
  relative to the project root.
- **Any `fn`, `type`, `effect`, or `let` can carry `pub`.**
  There is no visibility distinction between types and
  functions: a construct is visible outside the module only if
  it is marked `pub` (or `pub(pkg)`, which shows up in
  section 8.5).

Private functions let you break up a public one without
polluting the importer's namespace: `helper` exists only inside
`arithmetic`.

The example that runs is that same file with a `main` using
both public functions:

```kai
# examples/ch08/01_one_file/main.kai
pub fn double(x: Int) : Int = x * 2

fn helper(x: Int) : Int = x + 1

pub fn double_plus_one(x: Int) : Int = helper(double(x))

fn main() {
  println("double_plus_one(5) = #{double_plus_one(5)}")
}
```

```
$ kai run examples/ch08/01_one_file/main.kai
double_plus_one(5) = 11
```

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

The prefix is on purpose, and I know it annoys some people.
When a project grows to fifteen or twenty modules, seeing
`arithmetic.double_plus_one` in an expression tells you
instantly where it comes from. Pulling every name loose into
your namespace saves keystrokes but loses that trail.

The same prefix is used for types the module exports and for
constructing them:

```kai
# examples/ch08/02_two_files/geometry.kai
pub type Point = { x: Real, y: Real }

pub fn distance(a: Point, b: Point) : Real {
  let dx = a.x - b.x
  let dy = a.y - b.y
  real_sqrt(dx * dx + dy * dy)
}

fn square(x: Real) : Real = x * x

# examples/ch08/02_two_files/main.kai
import geometry

fn main() {
  let a: geometry.Point = geometry.Point { x: 0.0, y: 0.0 }
  let b: geometry.Point = geometry.Point { x: 3.0, y: 4.0 }
  println("distance = #{geometry.distance(a, b)}")
}
```

```
$ kai run examples/ch08/02_two_files/main.kai
distance = 5
```

The prefix goes in the type annotation (`: geometry.Point`),
the record construction (`geometry.Point { ... }`), and the
call (`geometry.distance(a, b)`). One mental pattern.

If a module lives under a subdirectory, the import uses the
same dotted name as the module:

```kai
# examples/ch08/05_project/util/math.kai
pub fn pow(base: Int, exp: Int) : Int {
  if exp == 0 {
    1
  } else {
    base * pow(base, exp - 1)
  }
}

# examples/ch08/05_project/main.kai
import util.math

fn main() {
  println("3^4 = #{math.pow(3, 4)}")
}
```

```
$ kai run examples/ch08/05_project/main.kai
3^4 = 81
```

The file lives at `util/math.kai` and the module is called
`util.math`, but when you use it the prefix is only `math`, the
last segment. Prefixes stay short without losing the structural
origin.

### Three import forms

kaikai admits three forms:

```kai
import math.vector                      # use qualified: vector.dot(a, b)
import math.vector as V                 # alias: V.dot(a, b)
import math.vector.{dot, cross}         # specific names into scope
```

The first is the most common and the default: the prefix
`vector.` makes clear where each name comes from. The second
helps when the module name is long or shows up often, and a
short alias buys readability without losing the trail. The
third is **selective import**: an explicit list of names
brought into the local namespace. It pays off only when those
names are the protagonists of the file and the prefix becomes
noise (a `Point` that appears forty times, say). The cost is
that the reader no longer knows where `Point` came from without
scrolling up.

**There is no wildcard import** — no `import math.vector.*` or
anything else that pulls "everything the module exports" into
the local namespace. I left it out on purpose: wildcards are
convenient at write-time and leave future readers unable to
trace where a name came from.

The three forms as three projects that run. Each carries its
own `geometry.kai`; what changes is the `import` line and,
with it, how the call reads:

```kai
# examples/ch08/03_qualified/main.kai
import geometry

fn main() {
  let d = geometry.distance_from_origin(3.0, 4.0)
  println("distance from origin = #{d}")
}

# examples/ch08/04_alias/main.kai
import geometry as G

fn main() {
  let d = G.distance_from_origin(3.0, 4.0)
  println("distance from origin = #{d}")
}

# examples/ch08/02b_selective/main.kai
import geometry.{Point, distance}

fn main() {
  let a: Point = Point { x: 0.0, y: 0.0 }
  let b: Point = Point { x: 3.0, y: 4.0 }
  println("distance = #{distance(a, b)}")
}
```

```
$ kai run examples/ch08/03_qualified/main.kai
distance from origin = 5
```

```
$ kai run examples/ch08/04_alias/main.kai
distance from origin = 5
```

```
$ kai run examples/ch08/02b_selective/main.kai
distance = 5
```

### When two modules export the same name

Sooner or later two of your dependencies put the same word on
different things. Neither is wrong: each domain names its own
concern with the term that fits, and `Reading` is as good a name
for a sensor as it is for an alarm.

```kai
# examples/ch08/07_collisions/sensors.kai
pub type Reading = { celsius: Real }
pub const MAX: Int = 100

# examples/ch08/07_collisions/alarms.kai
pub type Reading = { severity: Int }
pub const MAX: Int = 5
```

Import both and write a bare `MAX`, and the compiler refuses to
choose for you:

```
error: bare name 'MAX' is exported by multiple modules: sensors, alarms
  --> main.kai:5:26
    |
  5 |   Stdout.print("max = #{MAX}")
    |                         ^
  = note: constant candidates: sensors.MAX, alarms.MAX
  = help: qualify the constant, e.g. `sensors.MAX`
```

Choosing for you would be worse than the error. With any
tie-break rule — import order, say — *which* `MAX` you get would
depend on how the lines happen to be sorted, and the day somebody
sorts them alphabetically the program changes meaning without a
single expression being touched.

A contested type, effect, or protocol produces the same report as
the constant, candidates named, with the matching word:
`type candidates`, `effect candidates`.

The way out is the qualifier, and it works everywhere a name
appears: types, constructors (in expression and in pattern
position), functions, constants, protocols in an `impl` head and
inside `#[derive(...)]`, and effects in a row, in a `handle`
head, and on their operations.

```kai
# examples/ch08/07_collisions/main.kai
import sensors
import alarms

fn main() : Unit / Stdout {
  let t: sensors.Reading = sensors.Reading { celsius: 21.5 }
  let a: alarms.Reading = alarms.Reading { severity: 3 }

  Stdout.print("#{t.celsius} degrees (max #{sensors.MAX})")
  Stdout.print("severity #{a.severity} (max #{alarms.MAX})")
}
```

```
$ kai run examples/ch08/07_collisions/main.kai
21.5 degrees (max 100)
severity 3 (max 5)
```

The qualifier is only a tiebreaker: `sensors.MAX` and `MAX` name
the same constant whenever there is no collision, so there's no
need to qualify defensively. And each module keeps its own
declaration: two dependencies may each declare their own
`effect Emit` without colliding, and `with ea.Emit` reaches only
`ea`'s.

One case never becomes a dispute: a namesake of something that
was already there. If you import a module that declares its own
`effect Log`, a bare `Log` in that file is the module's: what
you imported wins over what was already there, and the stdlib's
stays one qualifier away, as `effects.Log`.

The rule holds for functions too, and that's where it's easier to
trip, because the core's names are the most obvious ones in the
trade: `map`, `filter`, `each`, `reduce`. A file that imports
`gen` — the generators from §12.13, which ship their own stages
under those names — changes who a bare `map` calls:

```kai
import gen

let xs = [1, 2, 3]
map(xs, double)      # ERROR: this `map` is gen's, not list's
```

```
error: type mismatch in function call
  = note: expected: (Gen[Int, _], (Int) -> Int) -> Gen[Int, _]
  = note: found:    ([Int], (Int) -> Int) -> ?t4
  = note: in argument 1 of `gen.map`
```

No guessing: the error shows you the signature it found and,
in that last note, which module the `map` that took the name
came from. The
ways out are the usual two, qualify or pipe:

```kai
list.map(xs, double) # [2, 4, 6]
xs | double          # [2, 4, 6]
```

That's the price of the import winning, and it's worth paying:
the alternative is that a core name is untouchable, and that the
author of a module can't call their `map` `map`.

The other way out is the selective import, which settles it for
the whole file instead of at every use:

```kai
import sensors.{MAX}    # a bare `MAX` is now sensors'
import alarms

# MAX        -> 100
# sensors.MAX -> 100
# alarms.MAX  ->   5
```

Naming `MAX` in the selective import takes it out of the
dispute: the bare name becomes `sensors`', and the other stays
available qualified. Nothing is hidden.

Pick based on how even the split is. If the file is ninety
percent sensors and touches alarms twice, the selective import
removes noise. If it uses both equally, qualifying at the use
site reads more honestly: the reader sees where each name comes
from without scrolling up to the imports.

### An import you don't use

An `import` the file never mentions — neither as a qualifier nor
through any name the module exports — is a warning:

```
warning: unused import `actor`
```

A warning today, an error at the Orongo edition, as in Go. The
migration is mechanical: delete the line.

One exception, so you don't mistake it for a false negative: a
module that only brings `impl`s into scope is used **by being
loaded**, not by being named, and that import is never reported
even though it appears nowhere else.

Do look twice before deleting, though. Either the import is
dead, or the name you meant to take from it is quietly coming
from somewhere else. Either way, you want to know.

## 8.3 Visibility: the module's contract

`pub` is the contract your module offers to the world.
Everything not marked is private, and marking something `pub`
declares "I will sustain this name, this signature, this type".

A rule the language doesn't enforce but is worth applying:
**keep the public surface narrow.** If you export a helper
that's useful today but specific to your implementation, the
day you refactor you'll have to choose between breaking callers
and carrying code you no longer want. Public is measured in
what you promise; private, in what you can change without
notice.

In practice:

- **Exported types:** yes, usually part of the contract.
- **Helper functions:** rarely. If you need to export them,
  ask whether they belong in this module at all.
- **Constants:** yes, if they're part of the API. Otherwise,
  no. `pub` goes in front just like everywhere else, and the
  importer uses it qualified:

  ```kai
  # limits.kai
  pub const MAX_PORT: Int = 65535

  # main.kai
  import limits
  println("max = #{limits.MAX_PORT}")
  ```

Between `pub` and private there is a middle grade:
`pub(pkg)`. A declaration marked that way is visible to every
module of its own package and does not exist for whoever uses
it as a dependency. It is what you want for the helper two of
your modules share and that is not part of the contract:

```kai
# util/internal.kai
pub(pkg) fn secret() : Int = 42
pub fn public() : Int = 1
```

From another module of the same package both names are there.
From a package that declares you as a dependency only `public`
is, and asking for the other is an error that names what there
is:

```
error: module 'internal' does not export 'secret'; available exports: public
```

Most languages with public-by-default end up with modules
whose "real API" is mixed with everything else. kaikai
inverts that: public is what you named explicitly.

### Private fields inside a public type

When you declare `pub type T = { ... }`, the record's fields
are **public by default**: if the type is in the contract, so
are its fields, and that's usually what you want. But sometimes
a field is an implementation detail. The `priv` keyword before
a field name hides it from other modules:

```kai
pub type Account = {
  name:         String,
  priv balance: Real,
}
```

Outside the module that declares `Account`, `a.balance`
doesn't compile and a literal `Account { name: "x", balance:
100.0 }` doesn't either. Only the declaring module can read
the field and name it when constructing. You met the pattern
in §4.1.1; what matters here is that `priv` works at **field
granularity** and complements `pub`, which works per
declaration. Together they cover a very common case: "export
the type, hide its interior."

A two-file project shows it from the other side of the module
boundary. The client builds and reads the account only through
the module's functions; the two commented lines are the
rejections:

```kai
# examples/ch08/06_priv/safe.kai
pub type Account = {
  name: String,
  priv balance: Real
}

pub fn open(name: String) : Account =
  Account { name: name, balance: 0.0 }

pub fn deposit(a: Account, amount: Real) : Account =
  Account { ...a, balance: a.balance + amount }

pub fn balance_of(a: Account) : Real = a.balance

# examples/ch08/06_priv/main.kai
import safe

fn main() {
  let a0 = safe.open("savings")
  let a1 = safe.deposit(a0, 100.0)
  let a2 = safe.deposit(a1, 50.0)
  println("#{a2.name}: #{safe.balance_of(a2)}")

  # println("#{a2.balance}")
  # let _ = safe.Account { name: "x", balance: 999.0 }
}
```

```
$ kai run examples/ch08/06_priv/main.kai
savings: 150
```

## 8.4 The stdlib you get for free

There is one special module you **don't need to import**: the
**core**. Functions like `println`, `assert`, `string_concat`,
`real_sqrt` live in the global namespace, available in every
`.kai` file without ceremony. Other languages call this
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

So far you've worked with **modules** inside a single file
tree. When those modules become a unit you want to version or
distribute, or one that depends on others, you move to the
second scale: the **project**.

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
projects yours needs. It stays empty if you depend only on the
stdlib.

### The package as a boundary

`kai.toml` also draws a visibility boundary. The file tree
under it is a **package**, and between private and `pub` there
is a third level: `pub(pkg)` exports a declaration to the
modules of the same package, its tests included, and to no one
else.

```kai
# fragment: util.kai inside a project
pub(pkg) fn helper(n: Int) : Int = n * 2   # every module under this kai.toml

pub fn api(n: Int) : Int = helper(n)        # what other packages see
```

A module from another package that reads `helper` gets an
error naming the declaration, and `kai doc` leaves it out.
That's where the things your modules share with each other go,
without committing to them as API.

Inside a package, modules may also import each other in a
cycle: `even.kai` imports `odd` and `odd.kai` imports `even`.
Since every top-level signature is explicit, the compiler
collects the whole cycle's signatures before reading any body.
A cycle that crosses packages, runs through the stdlib, or
joins files with no `kai.toml` is an error.

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
forward. When an edition closes
and a new one opens, kaikai keeps accepting the old one — you
just have to declare which one you use.

If you omit the field, the compiler assumes the installation's
default edition. Fine for a sketch; for a project that will
live, pinning the edition stops a silent upgrade from moving the
ground under you. You'll find the rest in ch. 16: how editions
are chosen, how to migrate between them, and what `#[unstable]`
means for APIs in flux.

### Starting a fresh project

```sh
$ mkdir myapp && cd myapp
$ kai init myapp
kai-pkg: wrote kai.toml for package 'myapp'
```

`kai init` writes the skeleton `kai.toml`. From there you add
`.kai` files and import them as in §8.2.

## 8.6 Dependencies: git, path, lock

A dependency can be declared in three forms:

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
shortened, with `@` splitting source from ref.

The third form (`{ path = "..." }`) is the **local
dependency**. It points at another project on disk, typically
because you're developing it in parallel. You edit the
dependency, re-run your app, and the changes show up instantly,
no republishing.

### Adding a dependency

```sh
$ kai add github.com/kaikailang-org/manutara@v0.1.0
```

`kai add` does two things atomically: clones the dependency
and writes the entry in `kai.toml`. If the clone fails (bad
URL, missing ref, network error), neither manifest nor
lockfile changes: the working tree never drifts into an
inconsistent state.

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

If two developers run `kai fetch` with the same `kai.toml`
and the same `kai.lock`, they **download exactly the same
SHA**, the same file tree, and end up with the same binary.
That reproducibility is the lockfile's core promise.

That's why `kai.lock` is committed alongside the code: it's
part of the project's contract. `kai.toml` declares what you
want; `kai.lock` declares what you got.

### When the lock is updated

- `kai fetch` creates it if absent; respects it if present.
- `kai update` regenerates it with the latest version of each
  dependency that satisfies the declared ref.
- `kai add` refreshes it when you add a new dependency.
- `kai run` and `kai build` refresh it automatically when they
  detect deps in `kai.toml` not in the lock (first run after a
  `git clone`, say).

## 8.7 Version selection: MVS

A project can depend transitively on another through two
paths, each declaring a different version. kaikai picks the
winner with **minimum-version selection (MVS)**, the algorithm
used by Go modules. The rule is blunt but clear: of all the
versions declared across the transitive chain, the **maximum**
wins.

If your app declares `manutara@v0.1.0` and one of its
dependencies declares `manutara@v0.2.0`, the whole project
uses `v0.2.0`. MVS assumes that versions are
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

## 8.8 Cache and `kai fetch`

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

Each entry is identified by its SHA, not by the ref you see.
So three projects asking for `manutara@v0.1.0` share the same
on-disk tree, and if `v0.1.0` moves upstream (a moved tag
shouldn't happen, but does), the cache pinned to the original
SHA stays intact.

You can run `kai fetch` by hand, but **`kai run` and
`kai build` invoke it automatically** when they detect
unresolved deps. After cloning a project, `kai run main.kai` is
enough: the driver downloads what's missing and runs.

The cache doesn't grow without bound. An entry no build has
used in five days removes itself, and if you need it again, the
next `kai run` fetches it again. `KAI_CACHE_TRIM=0` turns that
trim off and `KAI_CACHE_TRIM_DAYS` changes the age. To free space
right away, `kai clean --cache` deletes the shared caches, and
plain `kai clean` the project's `.kai-cache`.

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

Walk through every `pub` and ask whether it's really part of
the module's contract or a helper left exported by inertia.
Every extra `pub` is a future commitment.

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

`kai fetch` downloads the pinned version and the lockfile
nails it down. The code in `main.kai` and `domain.kai`
doesn't change: the imports remain the same.

That's the full trajectory: from one file to modules, from
modules to a project, from a local project to a distributed
dependency. Every step is reversible, and none forces you to
the next.

## 8.10 Philosophy: simple and predictable

Other languages have more expressive module systems:
automatic re-exports, dynamic aliases, modules parameterized
by values. kaikai picks an austere variant and stops there.

The reason is the same as elsewhere in the language: what
eliminates head-scratching matters more than what adds power.
A module system where nothing is imported without appearing
in a visible list, where a module name is derived from its
path, and where dependencies are pinned to an exact SHA can be
understood by reading, without mentally executing it.

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
