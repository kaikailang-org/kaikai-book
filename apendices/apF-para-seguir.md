# Apéndice F · Para seguir

El libro cubrió kaikai pero apenas tocó la familia de ideas
sobre las que se construye. Si te interesa profundizar, esta
es una lista corta de fuentes que vale la pena leer, agrupadas
por tema. No pretende ser exhaustiva; pretende ser útil. Son las
que yo leí mientras diseñaba el lenguaje, y las ordeno por lo
que me sirvieron a mí.

## F.1 Efectos algebraicos

La pieza del lenguaje que más merece lectura externa es la de
efectos algebraicos. La literatura es accesible y vale la
pena ir al original.

- **Plotkin, Pretnar, *"Handlers of Algebraic Effects"***
  (ESOP 2009). El paper que introduce los handlers como los
  conocemos. Técnico pero corto.
- **Bauer, Pretnar, *"Programming with Algebraic Effects and
  Handlers"*** (J. Logical and Algebraic Methods in Programming,
  2015). Más pedagógico que el anterior; bueno como segunda
  lectura.
- **Lenguaje Koka** (Daan Leijen, Microsoft Research).
  `koka-lang.github.io`. Probablemente el lenguaje con la
  mejor implementación de efectos algebraicos hoy. Mucha de
  la inspiración sintáctica de kaikai viene de ahí.
- **Lenguaje Effekt.** `effekt-lang.org`. Tiene un sistema de
  efectos basado en capabilities. Comparable a Koka pero con
  otra estética.
- **Eduardo Díaz, *Revelaciones*** (lnds.net, 2015,
  `https://lnds.net/blog/lnds/2015/10/01/revelaciones/`). La
  previa histórica al camino de kaikai: teoría de categorías y
  mónadas como puente desde el mundo funcional clásico hacia
  los efectos algebraicos. Mencionado en el prólogo.

## F.2 Perceus y reference counting

- **Reinking, Xie, de Moura, Leijen, *"Perceus: Garbage Free
  Reference Counting with Reuse"*** (PLDI 2021). El paper que
  inventa el sistema que kaikai usa para liberar memoria. Es
  legible.
- **Lorenz, Leijen, *"Reference Counting with Frame Limited
  Reuse"*** (ICFP 2023). Extensión que mejora reuse cuando el
  shape no calza exactamente.
- **Lean 4** (`leanprover.github.io`). Sistema de pruebas que
  usa una variante de Perceus en su runtime. Es más complejo
  que Koka pero también está bien documentado.

## F.3 Modelo de actores y BEAM

- **Joe Armstrong, *Programming Erlang*** (Pragmatic
  Bookshelf, 2007/2013). El libro canónico de Erlang escrito
  por su creador. Cubre la filosofía de "let it crash" con
  más profundidad que cualquier introducción reciente.
- **Saša Jurić, *Elixir in Action*** (Manning, 2019). El
  modelo de actores explicado para programadores modernos,
  con código Elixir. La parte de OTP es excelente.
- **Cesarini, Vinoski, *Designing for Scalability with
  Erlang/OTP*** (O'Reilly, 2016). Para cuando quieras pensar
  en sistemas distribuidos serios.

## F.4 Concurrencia estructurada

- **Nathaniel J. Smith, *"Notes on structured concurrency,
  or: Go statement considered harmful"*** (vorpus.org, 2018).
  El ensayo seminal sobre concurrencia estructurada. Lectura
  obligatoria si vas a escribir cualquier código concurrente
  en cualquier lenguaje moderno.
- **Bob Nystrom, *"What Color is Your Function?"***
  (journal.stuffwithstuff.com, 2015). El ensayo sobre el
  problema de los colores que motivó la apuesta de kaikai
  por efectos en vez de `async`/`await`. Corto, divertido,
  con tirón.
- **Trio (Python)**, **Kotlin coroutines**, **Swift
  structured concurrency**, **OCaml 5 Eio**. Cuatro
  implementaciones concretas del mismo modelo. Comparar
  cómo lo expresa cada uno ayuda a fijar la idea.

## F.5 Diseño de lenguajes

- **Fred Brooks, *"No Silver Bullet"*** (IEEE Computer,
  1986). El ensayo clásico sobre la complejidad esencial vs
  accidental en software. Sigue vigente cuarenta años después
  porque acertó.
- **Rich Hickey, *"Simple Made Easy"*** (Strange Loop, 2011,
  video en infoq.com). Una hora de Rich Hickey distinguiendo
  *simple* de *easy*. Cambia la forma de evaluar APIs y
  lenguajes.
- **Marlow, Goldsmith et al., *"Out of the Tar Pit"*** (paper
  2006, accesible online). Diagnóstico de por qué el software
  se vuelve complicado y propuesta de cómo evitarlo. Muy
  influyente en el pensamiento funcional moderno.
- **Steele, Sussman, *"Lambda: The Ultimate Imperative"***
  (MIT AI Memo, 1976). Uno de los papers fundadores que
  muestra que la programación funcional con clausuras y
  recursión cubre todo lo que los lenguajes imperativos
  hacen.

## F.6 Sistemas de tipos

- **Benjamin Pierce, *Types and Programming Languages*** (MIT
  Press, 2002). El libro de referencia para sistemas de tipos.
  No se lee de una sentada, se consulta capítulo por capítulo.
- **Robert Harper, *Practical Foundations for Programming
  Languages*** (Cambridge University Press, 2016, 2da ed.).
  Más moderno que Pierce. Cubre efectos, polimorfismo de filas,
  cosas que no estaban en el de Pierce.
- **Pierce et al., *Software Foundations*** (volúmenes
  online en `softwarefoundations.cis.upenn.edu`). Curso
  interactivo sobre sistemas de tipos verificados en Coq.
  Para quien quiera el rigor pleno.

## F.7 Contratos y diseño por contrato

- **Bertrand Meyer, *Object-Oriented Software Construction***
  (Prentice Hall, 1997, 2da ed.). El libro original de Eiffel
  y de design by contract. Aunque el contexto OO no es el de
  kaikai, los argumentos sobre por qué los contratos importan
  son los mismos.
- **John Barnes, *Programming in Ada 2012 with a Preview of
  Ada 2022*** (Cambridge University Press, 2014). Ada es el
  otro gran exponente de contratos en un lenguaje de uso
  industrial. Para entender cómo se ven en producción.

## F.8 La comunidad y el código

- **Repositorio oficial**: `github.com/kaikailang-org/kaikai`. El
  compilador, el stdlib, los documentos de diseño. Issues
  abiertos para reportes y propuestas.
- **Este libro**: `github.com/kaikailang-org/kaikai-book`. PRs con
  correcciones son bienvenidos. El libro está en español e
  inglés; ambas ediciones se mantienen en paralelo.
- **Blog del autor**: `lnds.net`. Donde aparecen ideas
  antes que en el libro, con menos disciplina y más juicio
  personal.

## F.9 Cierre

Si el libro te dejó con ganas de probar algo, la mejor manera
de aprender es escribir código. Toma cualquier programa que
ya hayas escrito en otro lenguaje (cualquier lenguaje), y
pruébalo a portarlo a kaikai. Vas a tropezar con cosas que el
libro no cubrió, vas a abrir issues, vas a aprender lo que
ningún libro puede enseñar.

El compilador está vivo, el lenguaje está evolucionando, y la
comunidad es pequeña pero atenta. Hay lugar para más.
