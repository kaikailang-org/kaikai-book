# Appendix D · Stdlib effects catalog

This appendix summarises the effects the stdlib exposes.
Reference material: when a function's signature in the
documentation says `: Unit / X`, you come here to confirm
what `X` provides.

The full specification lives at
`github.com/kaikailang-org/kaikai/docs/effects-stdlib.md`. Here we
show the effect's declaration and what it's for.

## D.1 Basic IO

### `Stdout`, `Stderr` and `Stdin`

The three standard streams are separate effects, one per file
descriptor. That granularity is what lets a test harness capture
stdout without touching what goes to stderr.

```kai
effect Stdout {
  print(s: String) : Unit
  is_tty()         : Bool
}

effect Stderr {
  eprint(s: String) : Unit
  is_tty()          : Bool
}

effect Stdin {
  read_line()        : Option[String]
  read_bytes(n: Int) : String
  is_tty()           : Bool
}
```

`print` and `eprint` append a newline. Neither carries a failure
type: under the default handler the common recoverable fault
(the pipe closed on the other side, `EPIPE`) is absorbed
silently, and anything left is catastrophic enough to panic.
`read_line` returns `None` at EOF.

`is_tty()` answers whether the stream is a terminal, per
`isatty(3)` on its own descriptor. It's the standard gate for
ANSI colour: emit escapes when `Stdout.is_tty()`, plain text
under a pipe or a redirection. `Env.get("NO_COLOR")` covers the
other half of that convention.

The alias `Console = Stdout + Stderr + Stdin` bundles all three
when the distinction doesn't earn its keep.

### `Env`

```kai
effect Env {
  args()                               : [String]
  get(name: String)                    : Option[String]
  set_var(name: String, value: String) : Result[Unit, String]
  unset_var(name: String)              : Result[Unit, String]
  vars()                               : [Pair[String, String]]
}
```

Access to the command-line arguments (`argv`) and to
environment variables, for reading as well as writing.

### `File`

```kai
perm read
perm write

effect File {
  read_file(path: String)                    : Result[String, String]
  write_file(path: String, contents: String) : Result[Unit, String]
  open_read(path: String)                    : Result[FileHandle<read>, String]
  read_chunk(h: FileHandle<read>, max: Int)  : Result[String, String]
  open_write(path: String)                   : Result[FileHandle<read + write>, String]
  write_chunk(h: FileHandle<write>, data: String) : Result[Unit, String]
  close_file(h: FileHandle)                  : Unit
}
```

Two levels. `read_file` / `write_file` move the whole file in
one go, which is what you want most of the time. The rest is the
chunked path, for files that don't fit or that you don't want to
load whole.

Note the `<...>` on the handles: `FileHandle<read>` and
`FileHandle<read + write>` carry the capability **in the type**.
A handle opened for reading doesn't typecheck where a
`FileHandle<write>` is expected, and the compiler decides that,
not a runtime check. It's the `Perm` kind from chapter 19 §19.9
doing its job. What the type states is what the code asked for
at open time, not the permission the operating system holds over
the file: that failure still rides each op's `Result`.

For directories and metadata, see the `fs` modules.

### `Log`

```kai
effect Log {
  debug(msg: String) : Unit
  info(msg: String)  : Unit
  warn(msg: String)  : Unit
  error(msg: String) : Unit
}
```

Leveled logging. The default handler writes each message to
stderr as `[ISO8601Z] LEVEL message`; installing your own lets
you capture or filter it.

A note for anyone arriving from chapter 12: there we declare our
own, smaller `effect Log { log(msg: String) : Unit }` to teach
the mechanism. There's no conflict — a local declaration shadows
the stdlib name within its file. If you want the four-level one,
don't declare it.

### `Trace`

```kai
effect Trace {
  log(msg: String)         : Unit
  checkpoint(name: String) : Unit
}
```

Ad-hoc tracing, smaller than `Log` and aimed elsewhere: `log`
emits a single line, `checkpoint` marks a named point. It comes
from `trace`.

Unlike everything else in this section, **`Trace` ships no
default handler**. With none installed the program doesn't even
compile, because the name isn't in scope. The module carries
two:

- `trace.with_trace_default(body)` writes every op to stdout as
  `[trace] message`, and checkpoints as
  `[trace] checkpoint: name`.
- `trace.with_log_prefix(prefix, body)` prepends
  `prefix ++ ": "` to every op and re-emits it via `Trace.log`
  to the next handler on the stack, so it chains with the one
  above.

## D.2 Time and randomness

### `Clock`

```kai
effect Clock {
  wall_now()        : WallTime
  monotonic_now()   : Instant
  sleep_ns(ns: Int) : Unit
}
```

Two distinct clocks, deliberately. `wall_now` gives calendar
time (`WallTime` is `{ secs, nanos }` since epoch), which jumps
when someone adjusts the system clock. `monotonic_now` gives an
`Instant` that only moves forward: that's the one you want for
measuring how long something took. `sleep_ns` parks the fiber,
not the thread.

### `Random`

```kai
effect Random {
  int_range(lo: Int, hi: Int) : Int
}
```

A single operation, uniform over `[lo, hi]` with both ends
included. The default handler seeds a PCG64 from the process
clock and pid. Higher-level helpers live in the `Random` module,
built on this one op. Not for cryptography.

### `SecureRandom`

```kai
effect SecureRandom {
  int_range(min: Int, max: Int) : Int
  bytes(n: Int)                 : [Int]
}
```

Cryptographically secure randomness, deliberately separate from
`Random` so that a test handler stubbing `Random` cannot weaken
a security-sensitive path by accident. `bytes(n)` yields `n`
bytes as integers in `[0, 255]`. The default handler bridges to
the OS CSPRNG (`getrandom` / `arc4random`).

## D.3 Network

### `NetTcp`

```kai
effect NetTcp {
  connect(host: String, port: Int) : Result[Conn, String]
  listen(host: String, port: Int)  : Result[Listener, String]
  accept(l: Listener)              : Result[Conn, String]
  send(c: Conn, data: [Int])       : Result[Int, String]
  recv(c: Conn, max: Int)          : Result[[Int], String]
  recv_timeout(c: Conn, max: Int, nanos: Int) : Option[Result[[Int], String]]
  close(c: Conn)                   : Unit
}
```

Byte-level TCP sockets; the bytes travel as `[Int]` in
`[0, 255]`. The blocking operations (`connect`, `accept`,
`send`, `recv`) park the fiber via the runtime's reactor, not
the OS thread. `recv_timeout` returns `None` when the deadline
expires.

### `NetUdp` and `NetDns`

```kai
effect NetUdp {
  bind(host: String, port: Int)                    : Result[UdpSocket, String]
  send(s: UdpSocket, dst: SocketAddr, data: [Int]) : Result[Int, String]
  recv(s: UdpSocket, max: Int) : Result[Pair[SocketAddr, [Int]], String]
  close(s: UdpSocket)                              : Unit
}

effect NetDns {
  resolve(host: String) : Result[[IpAddr], String]
}
```

Same style as `NetTcp`. The stdlib ships **no** alias bundling
the three — the only ones it declares are `Console` and `Io`
(§D.9). A function using all three sums them in its row,
`/ NetTcp + NetUdp + NetDns`, or you declare the alias yourself,
which is one line once the three modules are imported:

```kai
import net.tcp
import net.udp
import net.dns

type Net = NetTcp + NetUdp + NetDns
```

## D.4 Processes and signals

### `Process`

```kai
type Child = { pid: Int }
type Exit  = Exited(Int) | Signaled(Int)

effect Process {
  start(cmd: String, args: [String]) : Child
  wait(c: Child)                     : Result[Exit, String]
  kill(c: Child, sig: Int)           : Result[Unit, String]
  exit(code: Int)                    : Nothing
  start_piped(cmd: String, args: [String],
              pipe_stdin: Bool, pipe_stdout: Bool) : Result[Child, String]
  write_stdin(c: Child, data: String) : Result[Unit, String]
  close_stdin(c: Child)               : Result[Unit, String]
  read_stdout(c: Child)               : Result[String, String]
}
```

Spawn and control subprocesses. `start` forks/execs and returns
a `Child` (an opaque handle carrying the pid); `wait` reaps it
into an `Exit`, which explicitly distinguishes exiting with a
code from dying on a signal. `kill` sends a raw POSIX signo.

`exit(code)` terminates the **current process** through
`_exit(2)`, so stdio buffers are **not** flushed: print
everything you want printed before calling it. The op never
resumes (it returns `Nothing`) and `Cancel` handlers do not run.
For the ordinary case — exiting with a status — returning an
`Int` from `main` is enough (chapter 16 §16.1), and that one
does take libc's full exit path.

`start_piped` is the `popen` shape: it attaches pipes to the
child's stdin and/or stdout, and from there `write_stdin`,
`close_stdin` and `read_stdout` carry the conversation.

### `Signal`

```kai
type Sig = SigInt | SigTerm | SigHup | SigUsr1 | SigUsr2

effect Signal {
  on(sig: Sig)  : Unit
  off(sig: Sig) : Unit
  await()       : Sig
}
```

Wait for a POSIX signal without blocking the rest of the
fibers. `on(sig)` subscribes the process to `sig`; the
runtime blocks the signal at the process level so the
kernel queues delivery instead of applying the default
disposition. `await()` parks the calling fiber until any
subscribed signal arrives and returns the matching `Sig`
variant. `off(sig)` unsubscribes.

The default handler is installed around `main` whenever
`Signal` is in the row. Only one fiber may sit in `await()`
at a time; a second concurrent call panics. Useful for
orderly shutdown — `Signal.on(SigInt); match Signal.await()
{ ... }` replaces the typical hand-written SIGINT handler.

## D.5 State

### `State[T]`

```kai
effect State[T] {
  get() : T
  set(v: T) : Unit
}
```

The canonical effect for carrying mutable state in an
encapsulated way. The syntax `var name = init` is sugar
over a `State[T]` `handle` (chapter 12 §12.7).

### `Reader[T]` and `Writer[W]`

```kai
effect Reader[T] {
  ask() : T
}

effect Writer[W] {
  tell(w: W) : Unit
}
```

Read-only environment (immutable configuration) and output
accumulation (logging, tracing). Classical effect-calculus
patterns.

### `Mutable`

```kai
effect Mutable {
  array_make[T](n: Int, init: T)             : Array[T]
  array_length[T](a: Array[T])               : Int
  array_get[T](a: Array[T], i: Int)          : T
  array_set[T](a: Array[T], i: Int, v: T)    : Array[T]
  array_grow[T](a: Array[T], n: Int, init: T) : Array[T]
  ref_make[T](init: T)                       : Ref[T]
  ref_get[T](r: Ref[T])                      : T
  ref_set[T](r: Ref[T], v: T)                : Unit
}
```

The effect behind `Ref[T]` and `Array[T]`. Follows the
discipline of **observable effects** (chapter 12 §12.7): an
`array_set` requires `Mutable` in the row only when the
mutation is visible to the caller. An array created locally
and returned doesn't require `Mutable`.

`array_set` and `array_grow` return the `Array[T]` rather than
`Unit`. Not because they copy: they hand back the same array so
Perceus (appendix B) can reason about the last use and decide
whether to mutate in place. Chaining the operation is idiomatic.

## D.6 Errors and control

### `ReadFault`

```kai
effect ReadFault {
  bad_chunk(msg: String)  : Unit      # resumable: skip and go on
  open_fault(msg: String) : Nothing   # abort-only
}
```

The recoverable fault of streamed reads, declared in
`stdlib/stream.kai`. It is the only failure-shaped effect the
stdlib declares, and its design explains why: `bad_chunk`
returns `Unit`, so a handler that resumes drops the bad chunk
and continues (skip policy), while one that abandons the
continuation aborts. `open_fault` returns `Nothing`: a stream
whose source cannot open has nothing to resume into.

`ReadFault` carries no default handler. A consumer that forces
the stream must pick a policy with `handle ... with ReadFault`,
or the typer reports `effect not handled: ReadFault`. The abort
path still releases the producer's handle: `read_lines` and
`write_lines` bracket the file in a handler carrying
`initially` / `finally` (chapter 12 §12.8), so `close_file` runs
on the unwind even though the fault jumps clean over the read
loop.

### `Cancel`

```kai
effect Cancel {
  raise() : Nothing
}
```

Cooperative cancellation. The scheduler injects
`Cancel.raise()` into a canceled fiber at the next yield
point. The fiber can install a `Cancel` handler for cleanup
(chapter 13).

### `Fail`: retired from the stdlib

`Fail` was a stdlib effect (`fail(msg: String) : Nothing`) with
a default handler that printed a banner and exited 1. **As of
kaikai 0.106 it is gone.** The removal ratifies what the stdlib
already practiced: every fallible API returns `Result` and
propagates with postfix `!`. Not one `/ Fail` row was left
across the stdlib.

What to reach for instead, by what you need:

| You need | Use |
|---|---|
| Inspectable failure | `Result[a, e]` with postfix `!` |
| A failure whose policy the consumer picks | a domain effect whose op returns `Unit`, so the handler can resume and skip |
| Deep non-local exit | `Cancel.raise() : Nothing` |
| Programming error | `panic` |

`Fail` remains a good teaching example of an operation that
returns `Nothing`, which is why chapter 12 declares it **locally**
in several examples. A `Fail` you declare yourself carries no
default, so an unhandled `fail` is a compile error (`effect not
handled: Fail`) rather than a runtime abort. That's the whole
practical difference.

## D.7 Concurrency

### `Spawn`

```kai
effect Spawn {
  yield()                       : Unit
  spawn[T](thunk: () -> T / e)  : Fiber[T]
  await[T](fiber: Fiber[T])     : T
  select[T](fibers: [Fiber[T]]) : T
  cancel[T](fiber: Fiber[T])    : Unit
  set_trap_exit(on: Bool)       : Unit
  scope_enter()                 : Unit
  scope_exit()                  : Unit
}
```

Create fibers, await them, race them, yield, cancel.
`nursery { n -> ... }` from chapter 13 is sugar over
`handle ... with Spawn as n { ... }`, and the last two
operations are the machinery behind that sugar: `scope_enter`
and `scope_exit` delimit the scope that joins the children.
`set_trap_exit` decides whether a fiber receives a linked
peer's death as a message instead of dying with it (chapter 14
§14.6).

### `Actor[Msg]`

```kai
effect Actor[Msg] {
  self()                        : Pid[Msg]
  send(pid: Pid[Msg], msg: Msg) : Unit
  receive()                     : Msg
  receive_timeout(nanos: Int)   : Option[Msg]
}
```

The effect underlying chapter 14's actor model.
`with_mailbox { ... }` and `spawn_actor(...)` are the
stdlib wrappers that install this handler. `receive_timeout`
returns `None` when nothing arrived within the deadline, which
is what keeps an actor from hanging on a message that will
never come.

### `Link` and `Monitor`

```kai
effect Link {
  link(peer: Pid[Nothing]) : Unit
}

effect Monitor {
  monitor(target: Pid[Nothing]) : Pid[Nothing]
  demonitor(ref: Pid[Nothing])  : Unit
}
```

BEAM-style supervision (chapter 14 §14.6). Links are
bidirectional: if one falls, the other receives
`Cancel.raise()`. Monitors are unidirectional: the
observer receives a `MonitorDown` message when the
observed actor terminates.

## D.8 Interoperability

### `Ffi`

```kai
effect Ffi {}
```

The effect carried by every function declared with
`extern "C" fn`. No operations of its own: it's a marker so
the type system knows which functions touch code not
audited by kaikai. Chapter 16 §16.12 covers the declaration
syntax, type mapping at the boundary, linking with C
shims, and what FFI v1 does and doesn't support.

## D.9 Composition: the `Console` and `Io` aliases

```kai
type Console = Stdout + Stderr + Stdin
type Io      = Console + Env + File
```

Two levels of bundling. `Console` gathers the three standard
streams; `Io` adds the environment and files on top. A function
that says `/ Io` declares it can touch the console, read env
vars and manipulate files: the equivalent of "this function is
not pure, it does things with the system".

Note who is **not** in `Io`: `Clock`, `Random`, `SecureRandom`,
the three network effects and `Process` are kept out on purpose. A
function that "logs and reads config" shouldn't silently gain
the capability to reach the network or spawn subprocesses just
because both live under one convenient name. Those effects
appear explicitly in the signature or not at all.

## D.10 Default handlers

When `main` declares any of these effects in its row, the
runtime automatically installs a default handler:

- `Stdout`, `Stderr`, `Stdin`, `Env`, `File` → IO to the system.
- `Clock`, `Random`, `SecureRandom` → system clock and RNG.
- `NetTcp`, `NetUdp`, `NetDns` → POSIX sockets.
- `Process`, `Signal` → POSIX calls.
- `Log` → each message to stderr as `[ISO8601Z] LEVEL message`.
- `Mutable` → real heap assignments.
- `Spawn`, `Cancel` → the runtime's fiber scheduler.

These handlers can be intercepted: any `handle ... with X
{ ... }` the user installs wins over the runtime's handler
for the duration of the `body` block. That's what enables
mocking in tests, capturing output, simulating the clock,
etc.
