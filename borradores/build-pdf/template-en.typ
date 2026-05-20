// Plantilla del libro kaikai (edición en inglés, borrador).
// Uso: #import "template-en.typ": book ; #show: book

#let kaikai-blue = rgb("#0d3b66")
#let kaikai-amber = rgb("#faa916")
#let kaikai-wine = rgb("#5b2333")
#let body-color = rgb("#1a1a1a")
#let muted = rgb("#666666")

#let cover(title, subtitle, author, logo-path) = {
  set page(margin: 0pt, fill: white)
  place(
    top + center,
    dy: 4cm,
    image(logo-path, width: 60%),
  )
  place(
    horizon + center,
    dy: 1cm,
    block(width: 80%)[
      #set text(font: "Helvetica Neue", fill: kaikai-blue)
      #align(center)[
        #text(size: 56pt, weight: 800)[#title]
        #v(0.6em)
        #text(size: 20pt, weight: 400, fill: muted)[#subtitle]
      ]
    ],
  )
  place(
    bottom + center,
    dy: -3cm,
    block[
      #set text(font: "Helvetica Neue", size: 16pt, fill: kaikai-wine, weight: 600)
      #align(center)[#author]
      #v(0.2em)
      #set text(size: 11pt, fill: muted, weight: 400)
      #align(center)[English edition · Draft]
    ],
  )
  pagebreak(weak: false)
}

#let copyright-page(author, year) = {
  set page(margin: (x: 3cm, y: 3cm))
  set text(font: "Helvetica Neue", size: 10pt, fill: muted)
  v(1fr)
  align(left)[
    Copyright © #year · #author \
    Draft of the #emph[kaikai] book. Limited distribution. \
    The #emph[kaikai] language and its documentation live at
    #link("https://github.com/kaikailang-org/kaikai")[github.com/kaikailang-org/kaikai].

    #v(1em)

    This book ships in two editions: Spanish and English. Both are
    first-class citizens; neither is a translation of the other.
    This is the English edition.

    #v(1em)

    Typography: New Computer Modern (body), Helvetica Neue
    (headings), JetBrains Mono (code). Set with Typst.
  ]
  v(1fr)
  pagebreak(weak: false)
}

#let book(
  title: "Simple programming with kaikai",
  subtitle: "A language for humans and agents",
  author: "Eduardo Díaz",
  year: 2026,
  logo-path: "kaikai-logo.svg",
  body,
) = {
  cover(title, subtitle, author, logo-path)
  copyright-page(author, year)

  set document(title: title, author: author)
  set page(
    paper: "a4",
    margin: (x: 3cm, top: 2.8cm, bottom: 2.8cm),
    numbering: "1",
    number-align: center,
    header: context {
      let page-num = counter(page).get().first()
      if page-num > 1 {
        let chap = query(heading.where(level: 1).before(here()))
        if chap.len() > 0 {
          set text(size: 9pt, fill: muted, font: "Helvetica Neue")
          if calc.even(page-num) {
            align(left)[#chap.last().body]
          } else {
            align(right)[#title]
          }
        }
      }
    },
  )
  set text(
    font: ("New Computer Modern", "Times New Roman", "Times"),
    size: 11pt,
    fill: body-color,
    lang: "en",
  )
  set par(justify: true, leading: 0.65em, first-line-indent: 0pt)

  set raw(syntaxes: "kaikai.sublime-syntax", theme: "kaikai.tmTheme")

  show heading.where(level: 1): it => {
    pagebreak(weak: true)
    v(2cm)
    set text(font: "Helvetica Neue", size: 28pt, weight: 700, fill: kaikai-blue)
    block(it.body)
    v(0.4cm)
    line(length: 30%, stroke: 2pt + kaikai-amber)
    v(1cm)
  }
  show heading.where(level: 2): it => {
    v(0.8em)
    set text(font: "Helvetica Neue", size: 16pt, weight: 600, fill: kaikai-blue)
    block(it)
    v(0.2em)
  }
  show heading.where(level: 3): it => {
    v(0.5em)
    set text(font: "Helvetica Neue", size: 13pt, weight: 600, fill: kaikai-wine)
    block(it)
  }
  show heading.where(level: 4): it => {
    v(0.3em)
    set text(font: "Helvetica Neue", size: 11pt, weight: 700, fill: body-color)
    block(it)
  }

  show raw.where(block: true): it => {
    block(
      width: 100%,
      fill: rgb("#f7f7f5"),
      stroke: (left: 2pt + kaikai-amber),
      inset: (x: 10pt, y: 8pt),
      radius: 2pt,
      text(
        font: ("JetBrains Mono", "Menlo", "Monaco"),
        size: 9.5pt,
        it,
      ),
    )
  }
  show raw.where(block: false): it => {
    box(
      fill: rgb("#f0f0ed"),
      inset: (x: 2pt, y: 0pt),
      outset: (y: 2pt),
      radius: 1pt,
      text(
        font: ("JetBrains Mono", "Menlo", "Monaco"),
        size: 0.92em,
        it,
      ),
    )
  }

  set list(indent: 1em, marker: ([•], [‣], [·]))
  set enum(indent: 1em)

  show quote.where(block: true): it => block(
    width: 100%,
    inset: (left: 1em, y: 0.5em),
    stroke: (left: 3pt + muted),
    text(style: "italic", it.body),
  )

  {
    set page(numbering: "i")
    counter(page).update(1)
    set text(font: ("New Computer Modern", "Times New Roman"))
    align(center)[
      #set text(font: "Helvetica Neue", size: 24pt, weight: 700, fill: kaikai-blue)
      Contents
    ]
    v(1cm)
    outline(title: none, depth: 2, indent: auto)
    pagebreak(weak: false)
  }

  counter(page).update(1)
  body
}
