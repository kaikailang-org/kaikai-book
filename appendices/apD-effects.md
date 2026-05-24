# Appendix D · Stdlib effects catalog

This appendix summarises the effects the stdlib exposes.
Reference material: when a function's signature in the
documentation says `: Unit / X`, you come here to confirm
what `X` provides.

The full specification lives at
`github.com/kaikailang-org/kaikai/docs/effects-stdlib.md`. Here we
show the effect's declaration and what it's for.

## D.1 Basic IO

### `Console`

```kai
effect Console {
  print(s: String)  : Unit
  eprint(s: String) : Unit
}
```

Print to stdout and stderr. Each operation appends a
newline. The runtime's default handler writes to the
corresponding file descriptor.

### `Stdin`

```kai
effect Stdin {
  read_line() : Result[String, String]
}
```

Read a line from standard input. Returns `Err(reason)` on
EOF or read error.

### `Env`

```kai
effect Env {
  get(name: String) : Option[String]
  args()            : [String]
}
```

Access to environment variables (`PATH`, `HOME`, etc.) and
to the command-line arguments (`argv`).

### `File`

```kai
effect File {
  read_file(path: String)                  : Result[String, String]
  write_file(path: String, content: String): Result[Unit, String]
  append(path: String, content: String)    : Result[Unit, String]
  exists(path: String)                     : Bool
  delete(path: String)                     : Result[String, Unit]
  rename(from: String, to: String)         : Result[String, Unit]
}
```

Operations on files. For anything non-trivial (streams,
directories, permissions), see `fs.dir` and the auxiliary
modules.

## D.2 Time and randomness

### `Clock`

```kai
effect Clock {
  now()           : Int          # nanoseconds since epoch
  sleep(ms: Int)  : Unit / Cancel
}
```

Clock and sleep. `sleep` is a yield point (carries
`Cancel`).

### `Random`

```kai
effect Random {
  int(min: Int, max: Int)   : Int
  real()                    : Real
  shuffle[a](xs: [a])       : [a]
}
```

Pseudo-random generation, not crypto-safe. For secrets, see
`SecureRandom`.

### `SecureRandom`

```kai
effect SecureRandom {
  bytes(n: Int) : [Byte]
}
```

Cryptographically secure random bytes (via `/dev/urandom`
or the system equivalent).

## D.3 Network

### `NetTcp`

```kai
effect NetTcp {
  connect(host: String, port: Int)   : Result[Conn, String]
  listen(host: String, port: Int)    : Result[Listener, String]
  accept(l: Listener)                : Result[Conn, String]
  send(c: Conn, data: [Byte])        : Result[Int, String]
  recv(c: Conn, max: Int)            : Result[[Byte], String]
  close(c: Conn)                     : Unit
}
```

Byte-level TCP sockets. Blocking operations (`connect`,
`accept`, `send`, `recv`) suspend the fiber via the
runtime's reactor when it lands (v1 makes them block the OS
thread).

### `NetUdp` and `NetDns`

UDP (`bind`/`send`/`recv`/`close`) and DNS (`resolve`).
Same style as `NetTcp`. The alias `Net = NetTcp + NetUdp +
NetDns` is useful when a function uses all three.

## D.4 Processes and signals

### `Process`

```kai
effect Process {
  run(cmd: String, args: [String]) : Result[ProcessResult, String]
  pid()                            : Int
}
```

Run external commands as subprocesses. `ProcessResult`
holds `exit_code`, `stdout`, and `stderr`.

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
  ref_make[T](init: T)              : Ref[T]
  ref_get[T](r: Ref[T])             : T
  ref_set[T](r: Ref[T], v: T)       : Unit
  array_make[T](n: Int, init: T)    : Array[T]
  array_length[T](a: Array[T])      : Int
  array_get[T](a: Array[T], i: Int)        : T
  array_set[T](a: Array[T], i: Int, v: T)  : Unit
  array_grow[T](a: Array[T], n: Int, init: T): Unit
}
```

The effect behind `Ref[T]` and `Array[T]`. Follows the
discipline of **observable effects** (chapter 12 §12.7): an
`array_set` requires `Mutable` in the row only when the
mutation is visible to the caller. An array created locally
and returned doesn't require `Mutable`.

## D.6 Errors and control

### `Fail`

```kai
effect Fail {
  fail(msg: String) : Nothing
}
```

Abort with a message. The operation returns `Nothing` (the
empty type), so the type system guarantees you can't call
`resume` after `Fail.fail`. It's the canonical pattern for
"lightweight exception" in kaikai.

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

## D.7 Concurrency

### `Spawn`

```kai
effect Spawn {
  spawn[T, e](f: () -> T / e) : Fiber[T]
  await[T](f: Fiber[T])       : T
  select[T](fs: [Fiber[T]])   : T
  yield()                     : Unit
  cancel[T](f: Fiber[T])      : Unit
}
```

Create fibers, await them, race them, yield, cancel.
`nursery { n -> ... }` from chapter 13 is sugar over
`handle ... with Spawn as n { ... }`.

### `Actor[Msg]`

```kai
effect Actor[Msg] {
  self()                         : Pid[Msg]
  send(pid: Pid[Msg], msg: Msg)  : Unit / Cancel
  receive()                      : Msg / Cancel
}
```

The effect underlying chapter 14's actor model.
`with_mailbox { ... }` and `spawn_actor(...)` are the
stdlib wrappers that install this handler.

### `Link` and `Monitor`

```kai
effect Link {
  link(pid: Pid[_]) : Unit
}

effect Monitor {
  monitor(pid: Pid[_])         : MonitorRef
  demonitor(ref: MonitorRef)   : Unit
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
effect Ffi
```

The effect carried by every function declared with
`extern "C" fn`. No operations of its own: it's a marker so
the type system knows which functions touch code not
audited by kaikai. Chapter 16 §16.9 covers the declaration
syntax, type mapping at the boundary, linking with C
shims, and what FFI v1 does and doesn't support.

## D.9 Composition: the `Io` alias

```kai
type Io = Console + Stdin + Env + File
```

Bundle of the most common effects for IO to the operating
system. A function that says `/ Io` declares it can touch
the console, read stdin, read env vars, manipulate files.
It's the equivalent of "this function is not pure, it does
things with the system".

## D.10 Default handlers

When `main` declares any of these effects in its row, the
runtime automatically installs a default handler:

- `Console`, `Stdin`, `Env`, `File` → IO to the system.
- `Clock`, `Random`, `SecureRandom` → system clock and RNG.
- `NetTcp`, `NetUdp`, `NetDns` → POSIX sockets.
- `Process`, `Signal` → POSIX calls.
- `Mutable` → real heap assignments.
- `Spawn`, `Cancel` → the runtime's fiber scheduler.

These handlers can be intercepted: any `handle ... with X
{ ... }` the user installs wins over the runtime's handler
for the duration of the `body` block. That's what enables
mocking in tests, capturing output, simulating the clock,
etc.
