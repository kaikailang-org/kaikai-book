# Appendix B · Perceus in depth

§13.2 covers Perceus in one page: the compiler analyzes the
program, knows the exact point where each value stops being
used, and inserts a `drop` there that decrements the
reference counter and frees the memory if it reaches zero.
No GC, no borrow checker, no lifetime annotations.

This appendix goes deeper. What it's for: if you come from
Rust and wonder why kaikai doesn't need a borrow checker;
if you come from Java and wonder why kaikai doesn't need
GC pauses; or if you simply want to understand how an idea
published in 2021 changed the balance between RC, GC, and
ownership.

You don't need to read this appendix to program in kaikai.
§13.2's model is enough. This text is for whoever wants to
see the gears.

## B.1 The paper, in one sentence

The paper that invented Perceus is **"Perceus: Garbage Free
Reference Counting with Reuse"** (Reinking, Xie, de Moura,
Leijen — PLDI 2021). The central sentence:

> Inserting reference count operations *after* type checking,
> using *precise last-use information*, makes RC competitive
> with tracing GC while keeping deterministic deallocation.

Three words carry weight:

- **After type checking.** The analysis runs over the
  already-typed program, not the raw AST. That gives enough
  information to reason about shape and uniqueness.
- **Precise last-use.** For each variable, the compiler
  identifies the exact place where it's used for the last
  time. After that point, the `drop` is safe.
- **Reuse.** This is the trick that makes Perceus
  competitive with GC: when a value is about to be freed
  and a value of the same shape is about to be created, the
  compiler reuses the same memory.

Let's take it apart.

## B.2 Step by step: where the drops go

Take this simple function:

```kai
fn example(xs: [Int]) : Int {
  let n = list.length(xs)
  let s = list.sum(xs)
  s + n
}
```

What has to happen to `xs` when the function ends? It
depends on who created it. If the list is owned by the
function (it was created inside, or was moved in as an
argument), it has to be freed. If it's shared with others,
not.

Perceus analyzes the body and finds:

- `xs` is used in line 2 (`list.length`).
- `xs` is used again in line 3 (`list.sum`).
- After that it isn't used again.

The compiler inserts:

```
fn example(xs: [Int]) : Int {
  let n = list.length(dup(xs))   # dup: increment xs's rc
  let s = list.sum(xs)            # last use: passes ownership
  s + n
}
```

`dup(xs)` increments the RC because `list.length` will
"consume" a reference (doing its own drop at the end). The
second use, `list.sum(xs)`, no longer needs `dup`: it's
the last use, and the reference the function already holds
is transferred.

`list.sum` and `list.length` internally do the same:
whenever they walk the list's tail, they decide whether
they're at the last use. If so, they don't duplicate. If
not, they do.

The final program has **the minimum number of operations
possible** on the counters. That minimisation is the
paper's core.

## B.3 Reuse in place

The most interesting part of Perceus is **reuse in place**.
When a function is about to free a value of some shape and
create another one of the same shape right after, the
compiler reuses the same memory block. No free, no
allocation: overwrite.

The canonical example is `map` over lists:

```kai
fn map[a, b](xs: [a], f: (a) -> b) : [b] {
  match xs {
    []           -> []
    [h, ...rest] -> [f(h), ...map(rest, f)]
  }
}
```

Without reuse, this `map` would:

1. Free the cons cell `[h, ...rest]` (after extracting both).
2. Allocate a new cons `[f(h), ...]`.

With reuse:

1. Overwrite the existing cons with the new head.

Same cons, same memory position, same cost as a mutation.
But **the program's result is identical**: the function is
still pure from the programmer's view.

The conditions for reuse in place are three, all verifiable
at compile time:

1. **The receiver has a unique reference** (RC == 1).
2. **The new value has the same shape**: same tag, same
   fields.
3. **No live aliasing elsewhere**: nobody else holds a
   pointer to the original cons.

When all three hold, the compiler emits code
indistinguishable from a destructive mutation. But
conceptually it's still immutable: if the program changes
and two references to the cons appear, reuse silently turns
off and falls back to "free + allocate". The programmer
doesn't notice.

This optimization is what makes algorithms like `map`,
`filter`, AVL trees, list parsing, **as fast as the mutable
versions in imperative languages**. It's why Koka and Lean
4 (which also use Perceus) can compile competitively with C.

## B.4 Compared to Rust's `Rc<RefCell<T>>`

If you come from Rust, this rings a bell: Rust also has RC
(`Rc<T>`, `Arc<T>`). How is Perceus different?

| Aspect | Rust `Rc<T>` | Perceus in kaikai |
|---|---|---|
| Who decides increments | Programmer (clone) | Compiler |
| Who decides decrements | Automatic destructor | Compiler |
| Annotations required | `Rc<T>`, `Arc<T>`, `Rc::clone(&x)` | none |
| Content mutability | Needs `RefCell<T>` | Immutable by default |
| Cycles | Silent memory leak | Impossible (no mutation) |
| Single-use cost | Pays the `Rc` always | No cost: compiler emits no RC |

The strongest difference is the last one. In Rust, when you
declare `Rc<T>` you pay the counter ALWAYS, even when the
value has a single use. In kaikai, **if the value has a
single use, no RC is emitted**. The compiler inserts the
`dup`s only where they're needed, after last-use analysis.

That means a pure functional kaikai program, where nothing
is genuinely shared between several variables, has zero RC
overhead. Lists, records, closures all get freed at their
last use without going through a counter. RC only appears
when the program actually needs to share.

## B.5 What about cycles?

The classical critique of RC is that **it doesn't handle
cycles**: if two values reference each other and nobody
else references them, neither one ever reaches 0, and they
leak. That's why Python has a "cycle collector" on top of
its RC, and Rust forces you to use `Weak` manually.

Why doesn't Perceus need either?

**Because values in kaikai are immutable.**

To create a cycle, you need mutation: A points to B, then
you modify B to point to A. Without mutation, you can't
build the second step. When you build B, A doesn't exist
yet; when you build A pointing to B, A isn't reachable from
B.

The only exceptions are mutation mechanisms kaikai provides
deliberately: local `var` (which the compiler masks and
restricts), `Ref[T]`, actor mailboxes, mutable arrays. All
of them have specific disciplines that prevent cycles
(mailboxes, for example, live in a specific actor and the
runtime's GC manages them).

In practice: a typical kaikai program doesn't build cycles.
Data structures are trees (lists, AVL, JSON, ASTs). When a
programmer wants something with cycles (a graph, an LRU
cache), they reach for explicit structures encoding
adjacency without direct pointers: indices in an array,
identifiers in a map. It's more work, but the intellectual
cost stays visible where it belongs.

## B.6 Why per-fiber separation simplifies RC

Chapter 13 mentions that each fiber has its own heap. This
isn't just error isolation: **it's what makes Perceus
lock-free**.

If two fibers shared pointers to the same value, the
counter's increments and decrements would have to be
**atomic**. Atomic means the CPU emits a memory barrier,
synchronizes with other cores, pays overhead. In programs
with many fibers, that overhead is enormous.

When each fiber has its own heap, counters are local.
**No synchronization**. A `dup` is a `++` on an integer,
without barriers. A `drop` is a `--`, ditto.

This is why kaikai's fiber model and Perceus are designed
together: each enables the other. Isolated fibers allow RC
without synchronization; efficient RC allows millions of
fibers without paying GC.

When two fibers need to share a value, they do so via an
explicit operation (`send` to a mailbox, return from an
`await`). The runtime copies the value (or moves it, if
safe) to the receiver's heap. The transfer is explicit in
the program, and therefore predictable.

## B.7 What it costs and what you get

Perceus has costs. Worth listing:

- **Static analysis is compiler work.** Slower than raw
  types. In kaikai, the analysis is integrated with
  inference and runs in milliseconds for typical programs.
- **When a value is genuinely duplicated, it pays the RC.**
  If you have many heavy shared structures, the `dup`/`drop`
  costs.
- **Reuse in place depends on static uniqueness.** If the
  analysis can't prove uniqueness, the optimization doesn't
  apply and you fall back to the safe version.

What you get:

- **Determinism.** You know exactly when each value gets
  freed. No pauses, no "the GC ran now",  no nondeterminism
  between runs.
- **Memory predictability.** Peak memory can be estimated
  by looking at the program. There's no "the GC waited too
  long and it piled up".
- **Zero annotations.** No `'a`, no `&mut`, no
  `Rc::clone(&x)`. The compiler does the work.
- **Composes with effects.** RC doesn't interact with
  effects in weird ways. `handle` and `resume` have no
  hidden GC overhead.

## B.8 Going further

If this appendix leaves you wanting more, the sources:

- **Reinking, Xie, de Moura, Leijen, *"Perceus: Garbage
  Free Reference Counting with Reuse"*** (PLDI 2021). The
  paper. It's readable.
- **Lorenz, Leijen, *"Reference Counting with Frame Limited
  Reuse"*** (ICFP 2023). An extension that improves reuse
  when the shape doesn't quite match.
- **Koka language documentation** (Daan Leijen et al.).
  Koka is where Perceus was born; much of the vocabulary
  ("reuse in place", "borrowed binds", "drop
  specialisation") comes from there.
- **Lean 4 RC implementation** (de Moura et al.). Lean 4
  also uses Perceus, with an approach closer to formal
  certification.

In the kaikai source, the analysis lives in
`stage2/perceus.kai`. If you want to see how it's
implemented, that's the starting point.
