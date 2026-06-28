# Chapter 18 · Case study: accounting ledger

Chapter 17 showed an HTTP server: many clients, one fiber
per connection, actors for state encapsulation. That's the
family of problems where concurrency dominates.

This chapter closes the book with a very different case:
**a double-entry accounting ledger**, where precision matters
more than concurrency. A debit that doesn't match its credit is
a bug your auditor finds before you do, and here "it works and
the tests pass" isn't enough — you have to show **why** it
works, and the type system has a lot to say about that.

Why fintech deserves its own chapter: it's one of the
domains where getting it wrong is most expensive and where
having guarantees in the type pays off most. Mixing USD with
EUR, adding debits to credits, allowing a withdrawal without
checking the balance — each of these costs real money. The
language's tools (units of measure,
contracts, branding) are designed so that these mistakes
don't compile, not so that you discover them in production.

The program: a double-entry ledger that holds accounts with
balances, records transactions (each with debits and
credits), validates that transactions balance, and persists
an immutable audit log. Size: about 280 lines across five
modules.

## 18.1 The shape of the program

Five files:

```
ledger/
├── kai.toml             # manifest
├── main.kai             # entry point, runs example operations
├── domain.kai           # types: Account, Movement, Transaction
├── balance.kai          # validation of the debit = credit invariant
├── store.kai            # actor that holds accounts and transactions
└── persistence.kai      # actor that writes the audit log
```

The structure deliberately mirrors chapter 17. What changes
is the emphasis:

- **`domain.kai`** is richer than chapter 17's. Units of
  measure appear (`Real<USD>`), branded types
  (`Int<AccountId>`, `Int<TransactionId>`), and a
  `Movement` sum type that distinguishes debits from
  credits.
- **`balance.kai`** is new. A module dedicated to one
  invariant: the sum of debits in a transaction must equal
  the sum of credits. It appears both as a pure testable
  function AND as a **contract** (`requires`) on the
  registration operation.
- **`store.kai`** is the same actor pattern, but now it
  validates balance before accepting a transaction and
  keeps per-account balances. Transactions are
  **immutable**: only ever added, never modified.
- **`persistence.kai`** is the audit log. A strong
  conceptual idea: in accounting, what's written stays. The
  file is legal evidence.

## 18.2 The domain: units, branding, algebraic types

The center of the program is the types:

```kai
pub unit USD

pub unit AccountId
pub unit TransactionId

#[derive(Show)]
pub type Account = {
  id:      Int<AccountId>,
  name:    String,
  balance: Real<USD>,
}

#[derive(Show)]
pub type Movement
  = Debit(Int<AccountId>, Real<USD>)
  | Credit(Int<AccountId>, Real<USD>)

#[derive(Show)]
pub type Transaction = {
  id:           Int<TransactionId>,
  description:  String,
  movements:    [Movement],
}
```

Three type-system decisions worth listing:

- **`Real<USD>` instead of `Real`.** Chapter 10 covered
  units of measure. They matter especially in this domain:
  an accounting program that mixes USD and EUR without
  converting produces numbers that look right but mean
  nothing. With UoM, that mix doesn't compile. To extend
  the program to multiple currencies, you declare
  `unit EUR`, define an exchange rate as `Real<USD / EUR>`,
  and the type system walks you through it. Without UoM,
  you discover the bug when a customer complains.
- **`Int<AccountId>` vs `Int<TransactionId>`.** Chapter 10
  also covered branded types. Having raw `Int` as ids
  means passing a transaction id where an account id is
  expected compiles fine and blows up at runtime (or
  worse, silently produces a wrong result). With branding,
  the type system tells you first.
- **`Movement` as a sum type.** A debit and a credit have
  the same physical fields (account + amount) but mean
  different things. Modeling them as two constructors of
  the same sum type has two effects: the exhaustive pattern
  match ensures every operation handles them explicitly,
  and the type system won't let us add "debit amount" with
  "credit amount" without going through a clear conversion.

Compare with the version without rich types: a record
`{ account: Int, amount: Real, kind: String }` where `kind`
is `"debit"` or `"credit"`. It works, but `kind: String`
allows `"DEBIT"`, `"CR"`, `""`, all invalid. Every function
that touches movements has to validate. With the sum type,
the invalid **can't be constructed**.

## 18.3 The central invariant: balance

The `balance.kai` module is small but important. It defines
the double-entry invariant: in every transaction, the sum
of debits must equal the sum of credits.

```kai
pub fn total_debits(ms: [domain.Movement]) : Real<USD> {
  match ms {
    []                              -> 0.0<USD>
    [domain.Debit(_, m), ...rest]   -> m + total_debits(rest)
    [domain.Credit(_, _), ...rest]  -> total_debits(rest)
  }
}

pub fn total_credits(ms: [domain.Movement]) : Real<USD> { ... }

pub fn balances(ms: [domain.Movement]) : Bool =
  total_debits(ms) == total_credits(ms)
```

Three pure functions, a boolean invariant. Tests verify
the contract piece by piece:

```kai
test "balances with one debit and one credit" {
  let ms = [
    domain.Debit(1<AccountId>, 100.0<USD>),
    domain.Credit(2<AccountId>, 100.0<USD>),
  ]
  assert balances(ms)
}

test "doesn't balance when amounts differ" { ... }
test "balances with multiple lines" { ... }
```

Again, no actors or IO involved: just the logic, tested
directly. If six months from now we change how movements are
represented, these tests ensure the invariant still holds.

And where chapter 11 pays off: we also declare a **version
with a contract**:

```kai
pub fn apply_if_balanced(ms: [domain.Movement]) : [domain.Movement]
  requires balances(ms)
  ensures  balances(result)
= ms
```

`requires balances(ms)` declares that **calling this
function with a movement set that doesn't balance is an
error**. If the compiler can prove it statically, it
rejects the call at compile time; if not, it inserts a
runtime assert. `ensures balances(result)` declares that
**the function's result also balances** (trivial here:
returns the same list). The two contracts together form the
function's legal signature: the preconditions it demands
and the postcondition it guarantees.

In a real accounting system, this pattern multiplies: each
operation that touches movements carries the domain's
contracts in its signature.

## 18.4 The store: actor with invariants

The store holds the ledger's state: known accounts,
registered transactions, next-ID counters.

```kai
type State = {
  accounts:         [domain.Account],
  transactions:     [domain.Transaction],
  next_account_id:  Int,
  next_tx_id:       Int,
}
```

The `process` function takes a command and the state,
returns a response and the new state. The important part:
**every transaction goes through balance validation before
being registered**.

```kai
Register(desc, movs) ->
  if not balance.balances(movs) {
    (domain.UnbalancedError("..."), s)
  } else {
    match verify_accounts(movs, s.accounts) {
      Some(missing_id) -> (domain.UnknownAccount(missing_id), s)
      None -> {
        let tx = domain.Transaction { id: s.next_tx_id<TransactionId>, ... }
        let updated_accounts = apply_movs(s.accounts, movs)
        let s2 = State { ...s, transactions: [tx, ...s.transactions], ... }
        (domain.TransactionRegistered(tx), s2)
      }
    }
  }
```

Two validations before accepting:

1. **Balance**: the sum of debits equals the sum of
   credits.
2. **Known accounts**: every account mentioned in the
   movements is registered.

If either fails, we return an error without modifying
state. That's an **atomic transaction**: either it applies
in full, or it doesn't apply at all. There's no "half-
registered transaction with broken balance".

Transactions **accumulate, are never modified**. The list
grows. This is deliberate: a ledger is by design an
immutable history. Erasing a past transaction doesn't
exist; correcting errors means writing a **new** inverse
transaction, which also stays in the history.

That immutability is free in kaikai. Lists are immutable by
construction; adding an element creates a new list.
"Destructive modification" isn't available to the actor's
loop unless we asked for it, with `var` or `Array[T]`. And
since the actor recurses with the new state, every
"version" of the ledger survives intact until the next
step.

## 18.5 The audit log

The `persistence.kai` module is practically identical to
chapter 17's: an actor that receives log lines and appends
them to the file. The conceptual difference: for an
accounting system, **the file is the truth**.

In real accounting, transaction records are **append-only**:
once an entry is written, it stays. Corrections are done by
adding new inverse entries, not by modifying the originals.
This is regulatory (auditors require it) but also
architectural: an event-sourced system that persists every
event lets you reconstruct any intermediate state.

```kai
pub type Event = Line(String)

fn loop(path: String) : Unit / Actor[Event] + File {
  match Actor.receive() {
    Line(s) -> {
      file.append(path, s ++ "\n")
      loop(path)
    }
  }
}
```

Each event the store produces (account created, transaction
registered) is sent to the log via `Actor.send`. The log
writes them in strict FIFO order. If the disk write falls
behind, events accumulate in the mailbox; the store keeps
responding.

A production improvement left as exercise: instead of
strings, persist a structured format (JSON, CBOR, TLV)
that can be replayed at startup to reconstruct the in-
memory state. This is **event sourcing** and kaikai allows
it naturally.

## 18.6 The main: run a scenario

`main.kai` doesn't open a socket this time: it just
executes a sequence of operations to show the system in
action.

```kai
fn main() : Unit / Console + File + Spawn + Cancel + ... {
  let store_pid = store.start()
  let log_pid   = persistence.start(LOG_PATH)

  step(store_pid, log_pid, domain.CreateAccount("cash"))
  step(store_pid, log_pid, domain.CreateAccount("sales"))
  step(store_pid, log_pid, domain.CreateAccount("expenses"))

  step(store_pid, log_pid, domain.Register("card sale", [
    domain.Debit(1<AccountId>, 50.0<USD>),
    domain.Credit(2<AccountId>, 50.0<USD>),
  ]))

  step(store_pid, log_pid, domain.Register("team coffee", [
    domain.Debit(3<AccountId>, 8.0<USD>),
    domain.Credit(1<AccountId>, 8.0<USD>),
  ]))

  # Unbalanced attempt: the store rejects it.
  step(store_pid, log_pid, domain.Register("error", [
    domain.Debit(1<AccountId>, 100.0<USD>),
    domain.Credit(2<AccountId>, 50.0<USD>),
  ]))

  step(store_pid, log_pid, domain.QueryBalance(1<AccountId>))
  ...
}
```

`step` is a helper that calls the store, prints the
response, and records the event in the audit log. After
running `main`, the ledger has three accounts, two
registered transactions (sale and coffee), one rejected
(the unbalanced attempt), and the final balances reflect
the entries. The file `ledger.audit.log` contains one line
per account and transaction.

## 18.7 What makes this case different from chapter 17

Same overall pattern, different emphasis. What appears
here that didn't in the previous chapter:

- **Units of measure.** `Real<USD>` in every amount. The
  type system rejects mixing currencies without explicit
  conversion (chapter 10).
- **Branded types.** `Int<AccountId>` vs
  `Int<TransactionId>`. The compiler won't let us mix them
  up (chapter 10).
- **Contracts.** `requires balances(ms)` in
  `apply_if_balanced`. The domain invariant lives in the
  function's signature, verifiable statically or
  dynamically (chapter 11).
- **Immutability by construction.** Transactions are never
  modified, only added. The ledger structure guarantees
  event sourcing.

What appears identically:

- **Sum types and exhaustive match.** `Command`,
  `Response`, `Movement`. The compiler ensures every
  operation handles every case.
- **Actors with state.** The store and persistence are
  actors, same as chapter 17.
- **Modularity.** Pure types separated from the actor
  machinery. `process` is tested without fibers.
- **Audit log via actor.** The pattern "an actor
  encapsulates costly IO" repeats.

That **symmetry between the two cases** is the lesson. The
domain changes (HTTP vs accounting), the language tools
that matter most change, but the program's structure stays
the same: pure domain, actors with state, separate
persistence, modules by responsibility.

## 18.8 How to extend it

Ideas to take the example further, in roughly increasing
difficulty:

- **Multiple currencies.** Declare `unit EUR`, `unit CLP`,
  let each account carry its currency as type parameter.
  Cross-currency transactions require an explicit exchange
  rate (`Real<USD / EUR>`).
- **Account types.** Distinguish assets, liabilities,
  equity, income, expenses. Each type has different rules
  for what "debit" and "credit" mean (in an asset account,
  debit increases; in a liability, debit decreases).
  Branded types like `Account<Asset>` capture this.
- **Accounting periods.** Close the fiscal year: every
  income and expense account transfers to retained
  earnings, and the ledger starts the new period with
  opening balances.
- **Reconstruction from the audit log.** At startup, read
  the log file and replay events to rebuild the in-memory
  state. This is canonical event sourcing.
- **Reports.** Income statement, balance sheet, ledger by
  account. Each is a pure function that walks the
  transactions and produces a formatted string.
- **Non-negative balance enforcement.** If you model a
  "non-negative balance" account as `Real<USD> where self
  >= 0.0<USD>` (refinement type from chapter 11), the
  type system rejects any movement that would push it
  negative.
- **Serve over HTTP.** Combine this program with
  chapter 17's: the accept loop stays the same, the
  handler that used to call the notes store now calls the
  ledger store. The program's structure changes very
  little.

Each one moves the system closer to a production system.
None forces you to rewrite the earlier pieces.
Orthogonality pays off.

## 18.9 Why fintech is a good testbed

Fintech is one of the few domains where the industry
welcomes tooling that weighs in on the development process.
If a function disburses the wrong amount, the company would
rather the compiler catch it than discover it in production.
If the system guarantees that debits match credits, the
regulator sleeps better. If types distinguish currencies,
next quarter's exchange-rate change won't introduce a subtle
bug.

Languages that offer those guarantees — Haskell, OCaml, F#
— have had a good reception in fintech historically. kaikai
aims for the same level of guarantees with less ceremony:
units without external packages, contracts in the signature,
branding without macros. The promise is that you can write
code as directly as in Python or Go, with the guarantees a
strong type system gives you.

Does the promise hold? That's for the person writing the
code to decide. This chapter tried to show a slice of a
domain where the bet pays off.

## 18.10 Philosophy: the book's closing

There's a pattern this book has been proposing, chapter
after chapter, without naming it explicitly until now.
Worth naming at the end.

**A real program is made of small, orthogonal pieces.**
Pure types describing the domain. Pure functions
transforming the domain. Actors wrapping the mutable state
that needs to persist between calls. Fibers running
concurrent work cooperatively. Modules separating
responsibilities. Contracts placing domain invariants in
the signatures of functions that preserve them.

Each piece is tested in isolation. Each piece declares in
its signature everything it does. Each piece can be
replaced without touching the rest.

This isn't exclusive to kaikai. It's described, in
different words, in Brooks's *No Silver Bullet*, Hickey's
*Simple Made Easy*, Moseley and Marks's *Out of the Tar
Pit*. What kaikai does is offer a syntax and a type system
that **make this style natural**. Signatures that hide
nothing are free because effects are in the type. Pure
functions are cheap because immutability is the default.
Actors are a library because algebraic effects make them
possible. Domain invariants live in the signature because
contracts live in the language.

If you keep one idea from reading this book, let it be
this: **the language isn't what matters; what matters is
what it lets you build, and what it helps you avoid
building wrong**. kaikai bets that with effects, fibers,
contracts, units, and holes in place, the programmer
writes less wrong code and more code that deserves to be
in production. If the bet works for you, this book has
done its job.

Thanks for reading this far. The compiler, the stdlib,
the design documents, and the examples live at
`github.com/kaikailang-org/kaikai`. There's an emerging community,
issues to close, language pieces still taking shape. If you
find this experiment interesting, there's room for you to
help make it better.
