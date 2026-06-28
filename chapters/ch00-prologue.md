# Prologue

> A *kaikai* is a single thread that draws a figure between the
> hands. In Rapa Nui culture, this corresponds to the whole
> practice: the thread, the figure, and the *pata'u ta'u* — the
> chant that goes with it.
>
> This book borrows that image. *Simple* comes from Latin
> *simplex*: "one fold, one thread." *Complex* comes from
> *complectere*: "braided together." The book's argument, and
> the language's bet, is that simplicity is not the opposite of
> hard, it is the opposite of entangled.
>
> The etymology and the simple/easy distinction come from
> Rich Hickey in his talk *Simple Made Easy* (Strange Loop, 2011),
> available at
> [InfoQ](https://www.infoq.com/presentations/Simple-Made-Easy/).
>
> Hickey's thesis runs through this whole book: simple is an
> objective property of things (how many threads compose them);
> easy is a property relative to the observer (how close it is to
> what they already know). Kaikai bets on the first even when it
> costs the second.

I've wanted to write a programming language since I learned how
to build compilers in college. Once I got into industry I ended
up solving more than a few problems by inventing small languages
for them — what we now call domain-specific languages, or DSLs.

Language design fascinates me. I love learning new languages,
comparing them, asking why their authors made the choices they
made. Along the way I also figured out why we have so many
programming languages: I gave a talk about it years ago, in
Spanish, [on YouTube](https://www.youtube.com/watch?v=Hp9HwLPYkjI).
In that same talk I introduced **Ogú**, a language I designed
and built years ago.

Ogú is a cartoon character — a caveman, friend of the kid
Mampato, created by the Chilean illustrator and cartoonist
Themo Lobos. Getting permission from the family to use the
character as the language's mascot is still one of the gestures
I'm proudest of. The repository goes back to 2010 or so. I
announced intentions on the blog, wrote parsers, started over,
wrote a grammar, changed it, read and re-read the classic
textbooks (the dragon book, *Modern Compiler Implementation*,
*Engineering a Compiler*), and made very little progress.

In 2017 I made a serious push: across two months, with sixty
hours total split between work and late nights, I built a first
version backed by Clojure. Ogú is essentially a transpiler —
the compiler translates Ogú syntax into *S-expressions* that
Clojure interprets, and the JVM does the rest. A *"fake it 'til
you make it"* solid enough to demo to my conference audience.

But Ogú ended up abandoned. The last commit is from 2021. The
[GitHub organization](https://github.com/ogu-lang) is still there
for anyone curious. I rewrote the parser in Scala — an exercise
in persistence and mild masochism. My problem was code
generation, but it was also my ambition.

A friend told me that if I was going to build a language, I'd
better answer what was *new* about it.

I learned new languages, the functional family in particular —
Haskell, F#. I fell in love with Rust, fought the borrow checker,
ended up fluent in lifetime annotations and the promise of
memory management without garbage collection.

I also studied category theory and had an epiphany about it,
which I wrote up at the time in the post
[*Revelaciones*](https://lnds.net/blog/lnds/2015/10/01/revelaciones/)
(2015, in Spanish). That's where I discovered monads. And right when I was deep in that batter, a post on
algebraic effects landed in my hands, alongside Bob Nystrom's
essay *"What Color is Your Function?"* I had a second epiphany.

That's how the idea for a new language was born. I called it
kaikai.

I initially had in mind the Kai Kai serpent from Mapuche
mythology, but I later discovered that in Rapa Nui culture,
*kai kai* refers to a game in which string figures are woven
with the fingers while a *pata'u ta'u* is chanted — a recited
verse. In kai kai, structure and narration go hand in hand,
much like a well-typed program.

What sets kaikai apart from earlier attempts, what makes it
original, is in this book: I'll let you find it for yourself.
What I do want to say here has to do with a central fact in
kaikai's making: the use of AI.

The compiler this book describes was built in a month. The
way Ogú was built in 60 hours, kaikai was built with the help
of Claude Code in roughly a month. Something that could have
taken years.

My reasoning was this: the AI has read and understood, better
than I have, every paper on algebraic effects, functional
programming, language design, and the rest. I might as well
use that to my advantage.

I acted as the architect — much of the design already existed
in my head — and the AI helped me put that design on disk.

Along the way I invented a method for working with AI in
language development at record speed. I documented it under the
name ELP: *Empirical Lane Parallelism*. This way of using
agents to amplify your development process and build robust
software in little time lives in
[github.com/lnds/elp](https://github.com/lnds/elp). I invite
you to read it if you want to understand how a compiler as
involved as kaikai's could come together in a single month.

## A note on how this book was written

This book was written with the assistance of an AI agent —
[Claude Code](https://claude.com/product/claude-code) from
Anthropic — under my direction as author and editor. I decided
which chapters existed, in what order, with what voice, with
what emphasis. Claude drafted, I edited, corrected, sent back,
edited again. We validated the examples against the compiler.
We checked technical claims against the language documentation.
We calibrated the book's voice against my blog.

I'm saying this to acknowledge the reality software engineers
face in 2026, not to apologize for it. The AI wrote parts of
it, but every decision was mine. In *The End of
Artisanal Software* I wrote that Jacquard looms are already
among us and that the question is not whether we'll use them
but how. This book is one concrete answer to that question:
AI doesn't let you do without the author; it lets you write
books you wouldn't have dared start. Without that support this
text would still be in my head, the way the sketch of Ogú
stayed in my head for years.

If you find inconsistencies, examples that don't compile,
outdated claims, or any other slip: the lapse is mine, not the
agent's. The book lives at
[`kaikailang-org/kaikai-book`](https://github.com/kaikailang-org/kaikai-book)
and reports are welcome as issues or pull requests.

## Conventions

A few paragraphs on how the book is organized and how to read
it. None of this is hard, but knowing it upfront saves friction.

### Structure

The book is organized into four parts, eighteen chapters and
six appendices.

- **Part I (chs. 1–2)** is the landing strip: a tour of the
  language with runnable programs and a short chapter on how
  to *think* in kaikai.
- **Part II (chs. 3–11)** covers the core: types, functions,
  modules, protocols, units of measure, contracts. What you
  need to read and write everyday kaikai.
- **Part III (chs. 12–15)** gets into what's distinctive:
  algebraic effects, fiber-based concurrency, actors, typed
  holes with AI assistance.
- **Part IV (chs. 16–18)** closes with tooling and two case
  studies.
- **Appendices A–F** stand as reference: compiler bootstrap,
  Perceus, operators, stdlib effect catalog, glossary, further
  reading.

If you come from a functional background and only the new
material interests you, start with Part III and circle back to
the core as needed.

### Shape of each chapter

Every chapter opens with a paragraph or two of context: why
the topic matters, what problem it solves. Then comes the
technical body — dense, with examples. Key chapters close with
a **case study** that pulls the concepts together in a
realistic program. At the end you'll find numbered
**exercises**, between three and eight depending on the
chapter's weight.

### Numbering and references

- **Chapters** are integers (ch. 7, ch. 12).
- **Sections** carry the chapter number (§7.3, §12.10).
- **Exercises** are cited as *7.3* inside the chapter, or
  *ch. 7, exercise 3* from elsewhere.
- **Appendices** are letters (appendix A, appendix D), with
  sections of the form §A.1.

### Typography

- **Bold** introduces a new term the first time it appears.
  If a word is bold, that's the definition.
- *Italics* are for emphasis and the titles of cited works
  (*The Go Programming Language*, *Learn You a Haskell*).
- `Monospaced text` is for identifiers, inline code, file
  names and commands.

### Code

Every block tagged `kai` is runnable. Copy it into a `.kai`
file, compile with `kai run`, and you'll get the output the
text promises. If a block carries *no* language tag, it's a
terminal session: what comes after the `$` is what you type,
what comes below is the output.

```
$ kai run examples/ch01/01_hello.kai
Hello, kaikai
```

Longer examples live under `examples/chNN/` in the
[book's repository](https://github.com/kaikailang-org/kaikai-book),
and the text references them by name when it's worth pulling
the whole file.

### Notation

The **language** is called `kaikai`, always lowercase, even at
the start of a sentence. The **command-line tool** is `kai`:
use it to compile (`kai run`), to run tests (`kai test`), to
check properties (`kai check`), to measure (`kai bench`).

Language identifiers, keywords, compiler messages and file
names stay in English in both editions. Technical words that
are already part of the profession's vocabulary — *handler*,
*fiber*, *effect row*, *pattern matching* — are used as is,
without italics.

### Language editions

The book is published in two editions: Spanish and English.
Both live in the same repository, in parallel trees. This is
the English edition. The Spanish edition is not a translation:
the two were written in parallel, with the same structure and
the same examples, each in its own native voice.

### Living software

The compiler, the stdlib and this book are evolving. Versions
move, examples occasionally stop compiling between releases,
appendices fall out of date. If you find a discrepancy between
the book and the compiler you have installed, please file an
issue against the
[book's repo](https://github.com/kaikailang-org/kaikai-book/issues).
The book records up front the compiler version each edition
was validated against.

## Who should read this book

Programmers with experience in some language — Python,
JavaScript, Go, Java, C#, Rust, anything — who are curious
about a new one. I don't assume a functional background: if
you've never touched Haskell, OCaml or Elixir, the introductory
chapters carry you through. If you come from the functional
world, you can skip to Part III and read what's distinctive
about kaikai head-on.

This is not a book for absolute beginners. I assume you know
what a function is, what a list is, what a type is, what a
test is.

## Thanks

To everyone who's read my blog for over twenty years: this
book exists because that conversation existed. The constancy
of those readers — the comments, the emails, the corrections,
the discussions that ran first on Twitter and later in
newsletters — kept reassuring me that writing was worth it.
Without that patient audience, kaikai would have stayed in my
head alongside Ogú.

To Themo Lobos, who is no longer with us, for Ogú the caveman
and for giving three generations of Chileans the conviction
that imagined worlds are built by hand. I recommend his
graphic novel *Mata-ki-te-rangi* (which became the first
Chilean animated feature film: *Ogú y Mampato en Rapa Nui*).
To the authors whose ideas kaikai picks up: Daan Leijen for
Koka, Andreas Rossberg and Jonathan Brachthäuser for Effekt,
Joe Armstrong for the BEAM spirit, and the academic community
that carried algebraic effects from Plotkin and Pretnar to a
usable tool. To the friends who used to tease me about Ogú
and now ask about kaikai.

And to Anthropic, for building a tool that let me write the
compiler and this book in a month and not in the next decade.

---

The compiler is alive, the language is evolving, and the
community is small but attentive. There's room for more.
