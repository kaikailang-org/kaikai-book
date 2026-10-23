# Appendix G · WebAssembly

Everything in this book compiles to a native binary: `kai run`
builds an executable for your machine and runs it. A kaikai program
can also end up as a WebAssembly module, though, either for a
console runtime such as `wasmtime` or inside a web page. The
language is the same. What changes is the world the program asks
things of.

That "world" is not a figure of speech. In kaikai every effect a
program needs is written in its type, and `main` is no exception:
its effect row is the list of what the program asks of its
environment. When you switch targets, the compiler checks that list
against what the target can provide and tells you what's missing
**before** it generates anything. This appendix walks through both
targets with that idea in hand.

## G.1 Two targets

`kai build` and `kai run` take a `--target` flag:

| Target | For | What it produces |
|---|---|---|
| `wasm32-wasi` | console programs on a WASI runtime | a single `.wasm` |
| `wasm32-browser` | programs that live in a page | the `.wasm`, the page that loads it, and the code that hosts it |

Both compile through the C backend (Chapter 16 explains why there
are two backends) with a pinned toolchain: the first time you use
either one, `kai` downloads wasi-sdk 34 into your cache, checks its
SHA-256 against the value baked into `kai`, and reuses it from then
on. If the download fails or the checksum doesn't match, the build
stops; `kai` never quietly falls back to some other compiler it
finds on `PATH`. If you already have that wasi-sdk installed,
`KAI_WASI_SDK=<dir>` uses it instead of downloading.

## G.2 The console: `wasm32-wasi`

WASI is the interface a WebAssembly module uses to talk to the
operating system: files, environment variables, the clock, random
numbers, standard input and the exit status. A program that only
computes and prints can't tell the difference:

```kaikai
# examples/apG/01_collatz.kai
# How many steps each number takes to reach 1.

fn steps(n: Int, k: Int) : Int =
  if n == 1 { k }
  else if n % 2 == 0 { steps(n / 2, k + 1) }
  else { steps(3 * n + 1, k + 1) }

fn main() {
  [6, 7, 27, 97] |! println("#{.} reaches 1 in #{steps(., 0)} steps")
}
```

```
$ kai run --target=wasm32-wasi examples/apG/01_collatz.kai
6 reaches 1 in 8 steps
7 reaches 1 in 16 steps
27 reaches 1 in 111 steps
97 reaches 1 in 118 steps
```

`kai run` builds the module in a scratch directory and runs it on
`wasmtime`, which has to be on your `PATH` and recent enough
(version 49 or later, where WebAssembly exception handling is on by
default). Arguments after the file go to the program, the whole
environment is inherited, and the program's exit status becomes
`kai`'s.

When you want the module itself, to take somewhere else, use
`build`:

```
$ kai build --target=wasm32-wasi examples/apG/01_collatz.kai -o collatz.wasm
$ wasmtime collatz.wasm
```

The `.wasm` doesn't care about your operating system or your CPU:
it's the same file on your Mac and on a Linux server that has never
seen a kaikai compiler, as long as `wasmtime` is there.

### Files: what the runtime lets you see

A WASI module can't see your disk. It sees only the directories the
runtime **preopens** for it. `kai run` preopens the current
directory, so a program that sticks to relative paths just works:

```kaikai
# examples/apG/02_logbook.kai
import fs.file

fn main() : Unit / Stdout + File {
  let path = "logbook.txt"
  file.write(path, "monday: compiled to wasm\n")
  file.append(path, "tuesday: ran it on wasmtime\n")
  println(file.read(path) |> trim())
  let _ = file.delete(path)
  println("is the file still there? #{file.exists(path)}")
}
```

```
$ kai run --target=wasm32-wasi examples/apG/02_logbook.kai
monday: compiled to wasm
tuesday: ran it on wasmtime
is the file still there? false
```

Change `path` to `/tmp/logbook.txt` and the same program dies with
`panic: file.write: write failed`. That isn't the operating system
denying permission: as far as the module is concerned, `/tmp` does
not exist. To open other directories, `KAI_WASI_DIRS` takes a
`:`-separated list that replaces the current directory:

```
$ KAI_WASI_DIRS=/tmp kai run --target=wasm32-wasi logbook_in_tmp.kai
```

Notice that `main`'s type already said the program touches files:
it says `File`. WASI supplies the other half, *which* files.
Between the two, whoever runs the module knows exactly what they're
handing over.

### What doesn't run on WASI: fibers

There are no fibers on this target. A fiber has to suspend its
stack and resume it later, and in `wasmtime` that waits on
WebAssembly's stack-switching proposal, which isn't available yet.
Since `Spawn` is an effect like any other, the compiler sees it in
`main`'s row:

```kaikai
# examples/apG/03_fibers.kai
import spawn

fn main() : Unit / Stdout + Spawn {
  let f = spawn.spawn { println("from another fiber") }
  spawn.await(f)
}
```

```
$ kai run --target=wasm32-wasi examples/apG/03_fibers.kai
error: `main` performs effect `Spawn`, which the `wasm32-wasi` target cannot run
  --> examples/apG/03_fibers.kai:3:1
    |
  3 | fn main() : Unit / Stdout + Spawn {
    | ^
  = help: fibers are not available on wasm32-wasi; handle `Spawn` in `main` with a handler of your own, or remove it from `main`'s row
```

This is my favorite part of the appendix. In most languages, a
program that uses threads compiles happily for a target without
threads and blows up at run time, in the worst possible place. Here
the error shows up at compile time and points at the exact line,
because the information was already in the type. Nobody had to
write a special check for WebAssembly: it's the same effect row you
read in Chapter 12, compared against a different list.

The same goes for `Actor`, `Cancel`, `Link`, `Monitor`, `Signal`
and the network effects (`NetTcp`, `NetUdp`, `NetUnix`, `NetDns`):
WASI preview 1 has no sockets. Everything else in the language
runs, plus `File`, `Env`, `Stdin`, `Stdout`, `Clock` (a `sleep`
blocks the whole instance), `Random`, `SecureRandom` and
`Process.exit`.

There's one case the type can't see: a handler that keeps its
continuation to resume later, like a generator. That one stops at
run time, with a message naming the target. Chapter 12 explains
what keeping `resume` means; here it's enough to know that it's the
same machinery fibers use, so it isn't available either.

## G.3 The page: `wasm32-browser`

The other target takes the program to the browser:

```kaikai
# examples/apG/04_page.kai
type Shape = Circle(Int) | Rect(Int, Int)

fn area(s: Shape) : Int = match s {
  Circle(r) -> 3 * r * r
  Rect(w, h) -> w * h
}

fn main() {
  println("hello from the page")
  [Circle(2), Rect(3, 4)] |! println("area #{area(.)}")
}
```

```
$ kai build --target=wasm32-browser examples/apG/04_page.kai -o web/page
```

`-o` names a prefix, not a file, because four files come out:

```
web/page.wasm      the module
web/page.mjs       starts page.wasm on the host
web/page.html      a <pre id="kai-stdout"> and one module script
web/kai_host.mjs   the host: what the program asks of the page
```

Serve the directory with any static server and open `page.html`.
What the program prints shows up in the `<pre>` and in the browser
console:

```
hello from the page
area 12
area 12
```

The same host runs under Node, which is handy for testing without a
browser: `node web/page.mjs` prints the same thing to the terminal.

`kai run` doesn't take this target: a page is served, not run from
the console. The browser has limits of its own, and the compiler
enforces them just as it does for WASI: a `main` that asks for
files on disk, standard input, signals or sockets is rejected at
build time.

### The page as effects

Printing into a `<pre>` gets you started, but a page is made of
nodes, events, timers and HTTP requests. The standard library models
them as four effects: `Dom` (`web.dom`), `Timer` (`web.timer`),
`Fetch` (`web.fetch`) and `Storage` (`web.storage`). `web.run { ... }`
is the handler that wires them to the real page.

A click counter:

```kaikai
# examples/apG/05_counter.kai
import web.dom
import web.run

fn count(button: Node, n: Int) : Unit / Dom {
  let e = Dom.next_event()
  if e.kind == "click" {
    Dom.set_text(button, "clicks: #{n + 1}")
    count(button, n + 1)
  } else {
    count(button, n)
  }
}

fn main() : Unit / Js + Ffi + Clock =
  run.run(() => {
    let button = Dom.create("button")
    Dom.set_text(button, "clicks: 0")
    Dom.append(Dom.query("body") ?? button, button)
    Dom.listen(button, "click")
    count(button, 0)
  })
```

If you come from JavaScript, the odd thing here is that there are
no callbacks. You don't register a function to be called when a
click happens: `Dom.listen` asks the host to queue that button's
clicks, and `Dom.next_event()` **waits** for the next one, as if you
were reading a line from standard input. The counter's state doesn't
live in a variable someone mutates from the outside; it's the `n`
argument of a recursive function. It's the style of Chapter 14's
actors, where a process is a loop that receives messages, applied to
a user interface.

`count`'s signature says `Dom` and nothing else: that function
touches the page and can't do anything more. `main`'s says `Js`,
which ties it to this target. Try `kai run examples/apG/05_counter.kai`
and the compiler tells you the native target can't run `Js`.

### Fibers in the page

Unlike WASI, the browser does have fibers, actors, `Clock.sleep` and
`receive_timeout`. This program is a clocked version of the tour's
two fibers:

```kaikai
# examples/apG/06_clocks.kai
import spawn
import time
import loop

fn clock(name: String, ms: Int, times: Int) : Unit / Stdout + Clock {
  loop.repeat(times) {
    time.sleep(time.millis(ms))
    println("#{name}: tick")
  }
}

fn main() : Unit / Stdout + Clock + Spawn {
  let slow = spawn.spawn { clock("slow", 250, 2) }
  clock("fast", 100, 4)
  spawn.await(slow)
  println("done")
}
```

Built with `--target=wasm32-browser` and opened in the page, it
prints the same as `kai run` does on your machine:

```
fast: tick
fast: tick
slow: tick
fast: tick
fast: tick
slow: tick
done
```

The difference is in how it waits. A `sleep` in the page blocks
nothing: the fiber parks on the browser's event loop and the page
keeps responding in the meantime. Underneath, suspension goes
through JavaScript Promise Integration (JSPI), a recent WebAssembly
extension.

## G.4 Requirements and limits

What each target needs, in one place:

- **`wasm32-wasi`:** `wasmtime` 49 or later on `PATH` for
  `kai run`. The `.wasm` is a WASI preview 1 module that uses
  WebAssembly exception handling.
- **`wasm32-browser`:** a browser with WebAssembly exception
  handling (Chrome and Edge 137, Firefox 131, Safari 18.4). If the
  program suspends (a fiber, a `sleep`, a handler that keeps its
  continuation) it also needs JSPI: Chrome and Edge 137, Firefox
  153, Safari 27. The host refuses to load the program on a browser
  without it, rather than failing halfway through.
- **Both:** the C backend, since `--backend=native` doesn't emit
  WebAssembly. Non-tail recursion is bounded by the engine's stack,
  around 6,000 calls in Chrome: less than your machine gives you, so
  a recursive function over a long list is better written with tail
  recursion or with pipes.
- **`kai test`** has no `--target`: tests always run on your
  machine.

For what this appendix doesn't cover (calling JavaScript with
`extern "js"`, declaring JavaScript modules under `[js]` in
`kai.toml`, or drawing a whole frame with `Dom.put_pixels`), the
reference is one command away:

```
$ kai info wasm
```

WebAssembly isn't a new language you have to learn. It's one more
place where the one you already know runs, and `main`'s effect row
tells you, before you build, whether your program fits there.
