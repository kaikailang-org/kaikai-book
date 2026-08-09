# Appendix F · Going further

The book covered kaikai but barely touched the family of
ideas it's built on. If you want to dig in, here's a short
list of sources worth reading, grouped by topic. Not meant
to be exhaustive — meant to be useful.

## F.1 Algebraic effects

The piece of the language that most rewards outside reading
is algebraic effects. The literature is accessible and the
originals are worth going to directly.

- **Plotkin, Pretnar, *"Handlers of Algebraic Effects"***
  (ESOP 2009). The paper that introduced handlers as we
  know them today. Technical but short.
- **Bauer, Pretnar, *"Programming with Algebraic Effects
  and Handlers"*** (J. Logical and Algebraic Methods in
  Programming, 2015). More pedagogical than the previous
  one; good as a second read.
- **Koka language** (Daan Leijen, Microsoft Research).
  `koka-lang.github.io`. Probably the best implementation
  of algebraic effects today. Much of kaikai's syntactic
  inspiration comes from here.
- **Effekt language.** `effekt-lang.org`. Has an effect
  system based on capabilities. Comparable to Koka with a
  different aesthetic.
- **Eduardo Díaz, *Revelaciones*** (lnds.net, 2015, in Spanish,
  `https://lnds.net/blog/lnds/2015/10/01/revelaciones/`). The
  historical preface to kaikai's path: category theory and
  monads as the bridge from classical functional programming
  toward algebraic effects. Mentioned in the prologue.

## F.2 Perceus and reference counting

- **Reinking, Xie, de Moura, Leijen, *"Perceus: Garbage
  Free Reference Counting with Reuse"*** (PLDI 2021). The
  paper that invented the system kaikai uses to free
  memory. It's readable.
- **Lorenz, Leijen, *"Reference Counting with Frame
  Limited Reuse"*** (ICFP 2023). Extension that improves
  reuse when the shape doesn't quite match.
- **Lean 4** (`leanprover.github.io`). Proof system that
  uses a Perceus variant in its runtime. More complex than
  Koka but also well-documented.

## F.3 Actor model and BEAM

- **Joe Armstrong, *Programming Erlang*** (Pragmatic
  Bookshelf, 2007/2013). The canonical Erlang book written
  by its creator. Covers the "let it crash" philosophy
  more deeply than any recent introduction.
- **Saša Jurić, *Elixir in Action*** (Manning, 2019). The
  actor model explained for modern programmers, with
  Elixir code. The OTP part is excellent.
- **Cesarini, Vinoski, *Designing for Scalability with
  Erlang/OTP*** (O'Reilly, 2016). For when you want to
  think about serious distributed systems.

## F.4 Structured concurrency

- **Nathaniel J. Smith, *"Notes on structured concurrency,
  or: Go statement considered harmful"*** (vorpus.org,
  2018). The seminal essay on structured concurrency.
  Required reading if you'll write any concurrent code in
  any modern language.
- **Bob Nystrom, *"What Color is Your Function?"***
  (journal.stuffwithstuff.com, 2015). The essay on the
  coloring problem that motivated kaikai's bet on effects
  instead of `async`/`await`. Short, funny, with bite.
- **Trio (Python)**, **Kotlin coroutines**, **Swift
  structured concurrency**, **OCaml 5 Eio**. Four concrete
  implementations of the same model. Comparing how each
  one expresses it helps the idea stick.

## F.5 Language design

- **Fred Brooks, *"No Silver Bullet"*** (IEEE Computer,
  1986). The classic essay on essential vs accidental
  complexity in software. Still relevant forty years later
  because it was right.
- **Rich Hickey, *"Simple Made Easy"*** (Strange Loop,
  2011, video on infoq.com). An hour of Rich Hickey
  distinguishing *simple* from *easy*. Changes how you
  evaluate APIs and languages.
- **Marlow, Goldsmith et al., *"Out of the Tar Pit"***
  (paper 2006, accessible online). Diagnosis of why
  software grows complicated and proposal for how to avoid
  it. Very influential in modern functional thinking.
- **Steele, Sussman, *"Lambda: The Ultimate Imperative"***
  (MIT AI Memo, 1976). One of the founding papers showing
  that functional programming with closures and recursion
  covers everything imperative languages do.

## F.6 Type systems

- **Benjamin Pierce, *Types and Programming Languages***
  (MIT Press, 2002). The reference book for type systems.
  Not read at one sitting, but consulted chapter by
  chapter.
- **Robert Harper, *Practical Foundations for Programming
  Languages*** (Cambridge University Press, 2016, 2nd ed.).
  More modern than Pierce. Covers effects, row
  polymorphism, things Pierce's didn't have.
- **Pierce et al., *Software Foundations*** (online volumes
  at `softwarefoundations.cis.upenn.edu`). Interactive
  course on type systems verified in Coq. For those who
  want full rigour.

## F.7 Contracts and design by contract

- **Bertrand Meyer, *Object-Oriented Software
  Construction*** (Prentice Hall, 1997, 2nd ed.). The
  original Eiffel and design-by-contract book. Although the
  OO context isn't kaikai's, the arguments for why
  contracts matter are the same.
- **John Barnes, *Programming in Ada 2012 with a Preview
  of Ada 2022*** (Cambridge University Press, 2014). Ada is
  the other major exponent of contracts in an industrial
  language. To see what they look like in production.

## F.8 Community and code

- **Official repository**: `github.com/kaikailang-org/kaikai`. The
  compiler, the stdlib, the design documents. Bug reports
  and proposals are welcome as issues.
- **This book**: `github.com/kaikailang-org/kaikai-book`. PRs with
  fixes are welcome. The book is in Spanish and English;
  both editions are maintained in parallel.
- **Author's blog**: `lnds.net`. Where ideas appear before
  they make it into the book, with less discipline and
  more personal judgment.

## F.9 Closing

If the book left you wanting to try something, the best way
to learn is to write code. Take any program you've written
in another language (any language) and try porting it to
kaikai. You'll run into things the book didn't cover, you'll
open issues, you'll learn what no book can teach.

The compiler is alive, the language is evolving, and the
community is small but attentive. There's room for more.
