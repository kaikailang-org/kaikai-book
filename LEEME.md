# El Lenguaje de Programación kaikai

Un libro sobre [kaikai](https://github.com/lnds/kaikai), un
lenguaje de programación funcional, con tipado estático, efectos
algebraicos como primitiva de primera clase, pipelines al estilo
Elixir, compilación a código nativo vía LLVM y un modelo de
memoria basado en reference counting Perceus más fibras aisladas
estilo BEAM: sin garbage collector y sin borrow checker.

Por Eduardo Díaz ([lnds](https://github.com/lnds)).

[Read this README in English](./README.md).

## Qué es este libro

Un libro de lectura, no un manual de referencia. La referencia
vive en el repo del lenguaje, bajo
[`kaikai/docs`](https://github.com/lnds/kaikai/tree/main/docs).
Este libro es el compañero de fondo: capítulos que explican el
*por qué* del diseño y recorren programas reales desde la
primera página.

La inspiración estructural es *The Go Programming Language* de
Donovan y Kernighan: prosa densa, programas reales desde el
capítulo uno, casos de estudio integradores, ejercicios al
final de cada capítulo. La inspiración pedagógica es *Learn You
a Haskell for Great Good!* de Lipovača: tono cálido cuando el
material se pone novedoso, conceptos que se introducen
gradualmente, espacio para que el lector respire.

La voz es mía, no la de ellos. Primera persona cuando viene al
caso; opiniones marcadas cuando corresponden. Yo diseñé el
lenguaje; este libro toma partido.

## A quién está dirigido

Un programador en ejercicio con experiencia en algún lenguaje
imperativo u orientado a objetos (Python, Go, Java, JavaScript,
C#, Rust) **pero que no necesariamente ha trabajado en un
lenguaje funcional**. Conceptos como tipos algebraicos, pattern
matching, inmutabilidad por defecto y efectos-en-los-tipos se
introducen con puentes desde lo que ya conoces, no se asumen.

Si ya manejas Haskell, OCaml, Elixir o Scala, los primeros
capítulos puedes hojearlos; el material distintivo vive en la
Parte III (efectos, fibras, actores, holes-y-LLMs).

**No es** para principiantes absolutos. Asumimos que ya sabes
qué es una función, un tipo, una lista y un test.

## Ediciones

El libro se publica en dos ediciones, ambas de primera clase:
ninguna es traducción de la otra.

- **Español**: capítulos en `capitulos/`, ejemplos en
  `ejemplos/`. Voz calibrada contra mi [blog](https://lnds.net).
- **Inglés**: capítulos en `chapters/`, ejemplos en
  `examples/`. Voz calibrada contra los documentos de diseño en
  `kaikai/docs/` y otra prosa técnica adyacente.

Los ejemplos de código son específicos de cada idioma: strings,
comentarios y nombres de archivo viven en el idioma de la
edición que los cita. Los identificadores, palabras clave del
lenguaje y APIs del stdlib de kaikai se quedan en su forma
original (inglés). Las figuras viven una sola vez bajo
`figuras/` cuando son neutrales al idioma.

## Estructura del repositorio

```
CLAUDE.md             instrucciones para el agente que asiste la escritura
estructura.md         tabla de contenidos completa (18 capítulos + 6 apéndices)
capitulos/            capítulos en español, capNN-*.md
chapters/             capítulos en inglés, chNN-*.md
ejemplos/capNN/       fuentes citadas por la edición en español
examples/chNN/        fuentes citadas por la edición en inglés
figuras/              diagramas e imágenes (comunes cuando son neutrales)
borradores/           notas y material que aún no es capítulo
README.md             versión en inglés de este archivo
LEEME.md              este archivo
```

## Compilar y correr los ejemplos

Necesitas el compilador `kai` instalado. Desde un clon fresco del
repo del lenguaje:

```sh
cd /ruta/a/kaikai
make all
```

Una vez que `kai` esté en tu `PATH`, cada ejemplo del libro corre
con:

```sh
kai run ejemplos/capNN/<archivo>.kai     # edición en español
kai run examples/chNN/<archivo>.kai      # edición en inglés
```

Los ejemplos se verifican contra la versión de `kai` que está en
uso al momento de escribir cada capítulo. Los commits de cada
capítulo dejan registro explícito de la versión cuando un
ejemplo depende de un bug recientemente corregido.

## Estado

En progreso. El libro se está escribiendo capítulo a capítulo,
desde el capítulo 1. El plan completo está en `estructura.md` y
lo que efectivamente ha quedado escrito está en `git log`.

## Licencia

A definir. Lo más probable es que el texto y el código de
ejemplo terminen bajo licencias distintas (CC-BY-SA para la
prosa, MIT o similar para el código kaikai).

## Contacto

Issues y pull requests son bienvenidos en este repo. Para
comentarios sobre el lenguaje en sí, no sobre el libro, usa
[lnds/kaikai](https://github.com/lnds/kaikai).
