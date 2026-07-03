# Appendix E · Glossary

Terms the book uses with a specific meaning. Definitions
are short and point to the chapter where the term appears.

## A

**Actor.** A fiber with a typed mailbox on top. Processes
messages it receives in order, keeps internal state between
messages. In kaikai, actors are a library built on the
`Actor[Msg]` effect.

**Algebraic effect.** An effect in the sense of chapter 12:
a language construct that declares operations (with their
signatures) without deciding how they're implemented, and
lets a `handle` decide what each operation means at any
point in the program.

**Array.** Data structure with constant-time indexed
access. In kaikai, `Array[T]` is mutable; mutation lives
under the `Mutable` effect.

**Assert.** Construct used inside `test`, `check`, and
contract blocks. If the condition is `false`, the block or
the program aborts.

## B

**Backpressure.** Mechanism by which a slow consumer slows
down a fast producer. In kaikai, the mailbox policy
`Bounded(N, BlockSender)` blocks the sender when the
mailbox is full.

**Bottom type.** A type with no inhabitants, written
`Nothing`. A function returning `Nothing` can't return
normally: it either loops forever, aborts, or calls a
non-returning effect. That's why `Fail.fail(...) : Nothing`
is the natural signature for an operation that doesn't
resume.

**Bounded.** A mailbox policy with fixed capacity. When
full, behavior depends on the overflow rule: `DropOldest`,
`DropNewest`, or `BlockSender`.

**Branded type.** A numeric or string type marked with a
symbolic unit (`Int<UserId>`) so the type system
distinguishes it from other types with the same underlying
representation. A special case of the units-of-measure
system.

## C

**Cancellation.** Asking a fiber to end before its natural
completion. In kaikai it's an effect: `Cancel.raise()`. The
fiber can install a handler to clean up before unwinding.

**Capability.** The binding that a `handle ... with Effect`
gives the body to invoke the effect's operations. By
default, the capability's name is the effect's name: inside
a `Log` handler, you call `Log.log(...)`. The `with X as
name` syntax binds the instance as a **capability value**: a
value whose type is the effect itself, which can be passed
down as an argument (`fn f(c: X)`) but cannot escape its
`handle`. Chapter 12 §12.9.

**Capability value.** See *Capability* and *Named
instance*.

**Closure.** A function value that captures variables from
the scope where it was created.

**Continuation.** "The rest of what's left to do" at a
point in the program. In kaikai it appears as the `resume`
argument that effect handlers receive: calling `resume(v)`
continues the body's computation with `v`.

**Contracts.** `requires` (precondition) and `ensures`
(postcondition) in a function's signature, verified
statically when possible and dynamically when not.
Chapter 11.

## D

**Default handler.** The handler the runtime installs
automatically around `main` for certain effects (`Console`,
`File`, `Spawn`, etc.). User-installed handlers via
`handle ... with X` take priority over the default while in
scope.

**Double-entry.** Accounting system in which every
transaction has debits equal to credits. Appears in
chapter 18's case study.

**Drop.** The operation Perceus inserts at the last use of
each value to decrement its reference count. If it reaches
zero, memory is freed.

## E

**Effect.** See *Algebraic effect*.

**Effect row.** The list of effects in a signature:
`Int / Log + Fail + State[Int]`. Built with `+` and treated
as a set, not a sequence.

**Event sourcing.** Architectural pattern where the
system's state is the sum of events that occurred; the
event log is the source of truth and the in-memory state is
reconstructed by replaying it. Appears in chapter 18.

**Exhaustiveness.** Property the compiler verifies on
`match`: every inhabitant of the scrutinee's type must be
covered. Chapter 5.

## F

**Fixed-width integers.** The types `Int32`, `UInt32`,
`UInt64`, and `Int128`, written with a literal suffix
(`42i32`, `42u64`). They are distinct from `Int`: no mixing
without an explicit conversion, and their arithmetic wraps
in two's complement at the type's width. In an `extern "C"`
signature they cross with the exact width they declare.
Chapter 3 §3.4.

**Fiber.** A unit of cooperative execution. In kaikai a
fiber is lightweight (hundreds of bytes), has its own heap,
shares no memory with other fibers, and yields control
only at explicit yield points. Chapter 13.

**Function coloring problem.** The problem where a language
feature (typically `async/await`) splits functions into two
incompatible colors, and changing one function infects
every function that calls it. Discussed in Bob Nystrom's
2015 essay *"What Color is Your Function?"*; kaikai solves
it by routing everything through effect rows.

## H

**Handler.** The `with Effect { ... }` block that decides
what to do with invocations to an effect. For each
operation it receives the arguments and a `resume`, and
decides whether to continue the body.

**Hole.** A `?` or `?name` expression that compiles but
aborts at runtime if execution reaches it. Used for top-
down design (human) and as an interface for AI agents.
Chapter 15.

## I

**Immutability by default.** Values in kaikai are
immutable by construction: `let x = ...` declares a binding
that doesn't change. Mutable constructs (`var`, `Ref[T]`,
`Array[T]`) are the explicit exception.

## L

**Last-use analysis.** The compiler phase where, for each
variable, the exact point of its last use is identified.
Perceus uses this analysis to insert `drop`s in the right
place.

**Linked (in actors).** Two actors linked with
`Link.link(pid)` find out about each other's termination:
if one falls, the other receives `Cancel.raise()`.
Chapter 14.

**Lint.** The `kai lint` command: a Clippy-style linter
that flags valid-but-suspect code. Opt-in, warnings only,
aware of types and effect rows. Chapter 16 §16.4.

## M

**Mailbox.** The message queue associated with an actor.
The actor processes messages in FIFO order. The mailbox's
**policy** decides what to do when it fills up (unbounded,
drop-oldest, drop-newest, block-sender).

**Match.** Pattern-matching expression. Covers every
constructor of a sum type (exhaustive) and lets you extract
components from records and lists. Chapter 5.

**Monitor (in actors).** An actor monitoring another
receives a `MonitorDown` message when the monitored actor
terminates, without coupling its own life to the
observed's. Chapter 14.

**MVS (minimum-version selection).** Dependency resolution
algorithm used by the package manager. When one project
declares `manutara@v0.1.0` and another declares
`manutara@v0.2.0`, MVS picks the **maximum** of the
declared versions. Chapter 8.

## N

**Named instance.** A handler bound to a name with
`with Eff(init) as x`. Lets several handlers of the same
effect coexist, each addressable through its capability
value, which can be passed as an argument. Chapter 12
§12.9.

**Nothing.** See *Bottom type*.

**Nursery.** A lexical scope that contains child fibers and
guarantees none survives the block. Built with
`nursery { n -> ... }`, which is sugar over `handle ...
with Spawn as n { ... }`. Chapter 13.

## O

**Operation.** A named declaration inside an `effect`: a
name, parameters, return type. Operations are invoked with
`Effect.op(args)`.

## P

**Pattern matching.** The `match` construct and patterns in
`let`. Lets you decompose structured values (sum types,
records, lists) into components. Chapter 5.

**Perceus.** The static reference-counting system kaikai
uses to free memory without GC or borrow checker. Invented
by Reinking, Xie, de Moura, and Leijen (PLDI 2021).
Appendix B and chapter 13 §13.2.

**Pid (process id).** Typed handle of an actor:
`Pid[Msg]`. Identifies a mailbox and also guarantees that
only messages of type `Msg` can be sent to it.

**Pipe.** Operators `|>`, `|`, `||`, `|?`. Chain
transformations. Chapter 6.

**Polymorphism.** A function's ability to operate over
multiple types. In kaikai it appears as generics
(`fn map[a, b](xs: [a], f: (a) -> b) : [b]`) and as
polymorphic rows (`/ e` where `e` is a row variable).

**Protocol.** An interface declared with `protocol`,
implemented by types via `impl Protocol for T`. It's
single-dispatch (resolves on a single type). Chapter 9.

**Pure.** A function is pure if it produces no effects (its
row is empty). Pure functions are easy to test,
parallelize, and reason about.

## R

**Ref.** A mutable cell with arbitrary lifetime, accessed
via `Mutable.ref_make` / `Mutable.ref_get` /
`Mutable.ref_set`. Chapter 12 §12.7.

**Refinement type.** A type with a restricting predicate:
`Int where self >= 0`. Chapter 11.

**Resume.** See *Continuation*.

**Reuse in place.** Perceus optimization: when a unique
value is about to be freed and another of the same shape
is about to be created, the same memory is reused without
touching counters. Appendix B.

**Row variable.** A polymorphic variable representing "the
rest of the effects" in a signature: `fn map[A, B, e](xs:
[A], f: (A) -> B / e) : [B] / e`.

## S

**Self-hosting.** The state where a compiler is written in
the same language it compiles. The kaikai compiler
`kaic2` is written in kaikai. Appendix A.

**Span.** The byte range in the source file where a
construct lives. Compiler messages use spans to point to
where an error occurred.

**Spawn.** Create a new fiber or actor. Operation of the
`Spawn` effect.

**Stage 0/1/2.** The three compilers that make up kaikai's
bootstrap. Stage 0 in C, stage 1 in kaikai-minimal, stage 2
in full kaikai. Appendix A.

**State[T].** Stdlib effect for carrying encapsulated
mutable state. The sugared form `var name = init` desugars
to `handle ... with State[T](init)` (chapter 12 §12.7).

**Stdout, Stderr, Stdin.** Standard output, standard error,
standard input. In kaikai these live under the `Console`
effect (for the first two) and `Stdin` (for the last).

**Sum type (algebraic data type).** A type with several
constructors, each carrying different data. The construct
`type Shape = Circle(Real) | Square(Real)`. Chapter 5.

## T

**Tail call.** A function call in "last thing the current
function does" position. The compiler compiles it to a
jump, not a stack-pushing call, so tail recursion runs
without consuming stack memory. Chapter 6.

**Top-down design.** Design style starting from the
signatures of top-level functions, leaving holes in the
bodies, and filling the inner pieces afterward.
Chapter 15.

**Trap exit.** An actor's ability to **not** propagate
cancellation automatically when a sibling fiber falls.
Enabled with `fiber_set_trap_exit(true)`; the actor
receives an informational message instead of
`Cancel.raise()`. Chapter 14.

## U

**Unit of measure.** A symbolic unit declared with `unit`
that annotates a numeric value (`Real<USD>`,
`Int<Seconds>`). The type system rejects operations that
mix incompatible units. Chapter 10.

## V

**Var.** Construct that declares a local mutable cell.
Syntactic sugar over `State[T]`. Chapter 12 §12.7.

## Y

**Yield.** The act of a fiber handing control back to the
scheduler so another fiber can run. `fiber_yield()` does
it explicitly; IO operations and `Spawn.await` do it
implicitly.
