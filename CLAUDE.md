# Libro: kaikai

Libro técnico sobre **kaikai**, el lenguaje de programación que está
diseñando Eduardo Díaz (lnds). Inspirado estructuralmente en
*The Go Programming Language* (Donovan & Kernighan, 2015), pero
escrito con la voz del autor.

## Foco

El libro enseña kaikai a un programador profesional que ya conoce
otro lenguaje (Python, Go, JavaScript, Java, Rust, C#) **pero que
no necesariamente ha trabajado en un lenguaje funcional**. No es
un manual de referencia — la referencia vive en `../kaikai/docs/`.
Es un libro de lectura: capítulos cortos, ejemplos que se compilan
y corren, prosa que explica decisiones de diseño y muestra cómo
*pensar* en kaikai.

Tres lectores objetivo, en orden de prioridad:

1. **Programador con experiencia y sin background funcional.**
   Sabe escribir código, conoce un lenguaje imperativo u OO,
   nunca tocó (en serio) Haskell, OCaml, Elixir, F#, Scala. Para
   este lector, los conceptos funcionales — inmutabilidad por
   defecto, pattern matching, tipos algebraicos, expresiones en
   vez de sentencias — son nuevos y hay que introducirlos
   explícitamente, sin asumir que ya los entiende.
2. **Programador con experiencia funcional previa** que viene a
   ver qué tiene de propio kaikai. Para él, los capítulos
   introductorios pueden saltarse; el contenido distintivo
   (efectos algebraicos, fibras, Perceus, holes tipados) es lo
   que justifica la lectura.
3. **Adoptante temprano** que ya bajó el compilador y quiere
   usarlo para algo real. Lee como referencia narrativa, no como
   tutorial.

Implicaciones de tener al lector #1 como prioridad:

- **Los conceptos funcionales se introducen, no se asumen.** La
  primera vez que aparece pattern matching, inmutabilidad,
  expresión vs sentencia, currificación o tipos algebraicos,
  hay un párrafo que lo explica con un puente desde lo que el
  lector ya conoce ("si vienes de Python, esto es como…").
- **Esos puentes son explícitos pero no invasivos.** No
  convertimos el libro en una comparativa permanente. Una
  comparación corta cuando el concepto debuta, después se
  habla en términos de kaikai.
- **No asumimos que se ama lo funcional desde el primer
  párrafo.** Hay que mostrar por qué vale la pena, no
  proclamarlo.

No es para principiantes absolutos en programación. Asumimos que el
lector sabe qué es una función, un tipo, una lista, un test.

## Inspiración: dos referencias, no una

El libro vive entre dos polos. Ninguno gana entero.

### *The Go Programming Language* (Donovan & Kernighan)

Aporta el **esqueleto técnico**:

- **Densidad y respeto por el lector.** Sin relleno, sin "como
  vimos en el capítulo anterior", sin recordatorios pueriles.
- **Programas reales y ejecutables desde el capítulo 1.** Cada
  ejemplo se puede tipear y correr. Nada de pseudocódigo.
- **Estructura clásica:** tour del lenguaje → tipos básicos →
  tipos compuestos → funciones → métodos/protocolos →
  efectos/concurrencia → tooling → casos de estudio.
- **Casos de estudio integradores** al final de capítulos clave
  (en TGPL: el web crawler, el chat server). Para kaikai
  proponemos: un calculador de expresiones, un servidor
  concurrente de fibras, un parser de configuración con efectos,
  un actor supervisado.
- **Ejercicios al final de cada capítulo.** Numerados, citables.
- **Tipografía limpia, código en bloques, pocas figuras.**

Lo que **no** tomamos de TGPL:

- El tono distante y enciclopédico de Kernighan.
- La neutralidad sobre el lenguaje. Este libro defiende kaikai. No
  es un panfleto, pero tampoco oculta que el autor lo diseñó.

### *Learn You a Haskell for Great Good!* (Lipovača)

Aporta la **calidez y la pedagogía gradual**:

- **Tono cercano, segunda persona, mentor amigable.** Especialmente
  importante porque el lector objetivo no tiene background
  funcional y los efectos algebraicos amenazan con asustarlo. Donde
  el contenido se pone novedoso, el tono se ablanda.
- **Construir intuición antes que rigor.** Primero "para qué
  sirve" y "cómo se siente usarlo", después la formalización.
  Cuando aparece un tipo algebraico, un handler de efectos o una
  fibra, el primer encuentro es un ejemplo concreto, no una
  definición.
- **Repetir cuando hace falta.** A diferencia de TGPL, está bien
  volver sobre un concepto en otro contexto. La inmutabilidad o
  el pattern matching se reencuentran varias veces en escenarios
  distintos hasta que se vuelven naturales.
- **Permiso para hacer guiños y bromas.** Sin caer en el exceso
  de LYAH. Un comentario al pasar, un nombre con humor en un
  ejemplo, está bien y suelta al lector.

Lo que **no** tomamos de LYAH:

- Las ilustraciones a mano y el bestiario. No es nuestra estética.
- La extrema lentitud. LYAH puede dedicar páginas a una idea
  pequeña; nosotros vamos más rápido.

### Cómo se mezclan

- **Densidad estilo TGPL en el cuerpo técnico**, **calidez estilo
  LYAH en aperturas, transiciones y donde el tema asusta**.
- **Capítulos cortos** (más cerca de LYAH que de TGPL): unas
  15–25 páginas equivalentes, con secciones de 300–800 palabras.
- **Voz del autor (lnds) por encima de ambos.** Primera persona
  cuando viene al caso, opinión marcada, anécdotas escasas pero
  efectivas. Las dos referencias dan el formato; la voz es
  propia.

## Estilo del autor (lnds)

Estudiar `../lnds-blog/content/posts/` para calibrar voz. Patrones
recurrentes:

- **Primera persona, registro conversacional pero técnico.** "Yo
  pienso", "déjame decirte", "tengo la suerte de trabajar con". No
  es académico ni distante.
- **Cita a clásicos sin pedantería.** Brooks, Dijkstra, Hickey,
  Weizenbaum, Knuth aparecen porque vienen al caso, no para lucir.
- **Una idea fuerte por sección, con título explícito.** Secciones
  cortas (300–600 palabras), encadenadas por argumento.
- **Anécdotas personales escasas pero efectivas.** Un párrafo sobre
  cuándo y por qué tomó una decisión. Sin autobiografías.
- **Opiniones marcadas, no escondidas.** "Esto es equivocado", "el
  futuro pertenece a quienes...". El lector sabe dónde está parado
  el autor.
- **Cierres con peso.** Frase corta, con resonancia. Evitar
  resúmenes burocráticos del tipo "en este artículo vimos…".
- **Vocabulario propio y mapudungun donde aporta.** kaikai, kimun,
  lonko son nombres con historia. Explicar la primera vez, usarlos
  con confianza después.

## Idioma

**El libro se publica en dos ediciones: español e inglés.** Ambas
versiones son ciudadanas de primera clase, no una el original y la
otra una traducción de cortesía. Un programador hispanohablante y
uno anglosajón deben encontrar el mismo libro, no dos libros
distintos.

Implicaciones prácticas:

- **Cada edición vive en su propio árbol de carpetas, en su
  idioma:**
  - Español: `capitulos/capNN-*.md`, `ejemplos/capNN/`.
  - Inglés: `chapters/chNN-*.md`, `examples/chNN/`.
- **Los ejemplos son paralelos por idioma.** Los strings
  literales, los comentarios y los nombres de archivo están en
  el idioma de la edición que los cita; identificadores,
  palabras clave del lenguaje y APIs de kaikai se quedan en su
  forma original (inglés). Si una edición agrega un ejemplo, la
  otra debe alcanzarla antes de publicar.
- **No traducir literal.** Cada edición se redacta en la voz nativa
  de su idioma. Un giro chileno puede tener un equivalente
  anglosajón distinto, no una traducción palabra por palabra. La
  voz del autor (lnds) se calibra por separado:
  - **Español:** posts del blog en `../lnds-blog/content/posts/`.
  - **Inglés:** documentos de diseño y commits en `../kaikai/` y
    `../kaikai/docs/` — donde lnds ya escribe técnicamente en
    inglés. Más prosa que la doc, menos que el blog en español.
- **Idioma de trabajo en este repo: el del capítulo que se está
  escribiendo.** Si un capítulo nace en español, redactar primero
  en español y abrir la versión en inglés cuando esté pulido (o al
  revés). No mezclar idiomas dentro de un mismo borrador.
- **Estructura, ejercicios y figuras** son comunes a ambas
  ediciones; los ejercicios viven dentro del capítulo (donde
  pueden adaptarse al idioma del texto), las figuras viven una
  sola vez bajo `figuras/` cuando son neutrales al idioma.

Reglas de español (cuando aplica):

- Español neutro latinoamericano con tuteo.
- Prohibido el voseo / registro argentino (regla absoluta del
  autor, ver `~/.claude/CLAUDE.md`).
- Coloquialismos chilenos puntuales (`po`, `harto`, `cachar`) son
  aceptables si encajan natural en la voz, sin abusar.
- Términos técnicos en inglés cuando son estándar (handler, fiber,
  effect row). No traducir por traducir.

Reglas de inglés (cuando aplica):

- Registro técnico-conversacional, alineado con los docs de
  `../kaikai/docs/` pero más prosa.
- Ortografía estadounidense (color, behavior, optimization).
- No emular pasivamente a Kernighan: el tono es del autor, no del
  libro de referencia.

En ambos idiomas, identificadores, código, mensajes del compilador
y nombres de archivos siempre en su forma original (inglés).

## Convenciones de texto y código

- **Markdown** para los borradores. La conversión final
  (LaTeX/PDF/EPUB) es trabajo posterior. No optimizar Markdown
  para un toolchain específico todavía.
- **Bloques de código siempre ejecutables.** Cada snippet completo
  debe poder copiarse a un archivo `.kai`, compilarse con
  `kai run`, y producir la salida que el texto promete. Si el
  snippet es parcial (un fragmento dentro de una explicación),
  marcarlo claramente.
- **Mostrar la salida del programa** debajo del código, prefijada
  con `$` para el comando y sin prefijo para el output:
  ```
  $ kai run ejemplos/cap02/hola.kai            # edición en español
  $ kai run examples/ch02/hello.kai            # edición en inglés
  Hola, kaikai
  ```
- **Numerar los ejemplos por capítulo** y guardarlos bajo
  `ejemplos/capNN/` (español) o `examples/chNN/` (inglés). El
  texto referencia por nombre de archivo.
- **Diagramas mínimos.** Cuando hagan falta, ASCII o un .png
  generado aparte. Evitar dependencias de herramientas exóticas.
- **Pies de figura y de código numerados** (Figura 2.3, Listado
  4.1) para poder citar.

## Referencia al lenguaje

El lenguaje vive en `../kaikai`. Ahí está la verdad sobre la
sintaxis, los efectos, el stdlib y el toolchain.

- **Antes de afirmar algo sobre kaikai, verificar contra
  `../kaikai/docs/` o contra los ejemplos de
  `../kaikai/examples/`.** El lenguaje está en evolución; lo que
  era cierto hace un mes puede no serlo hoy.
- **Si un ejemplo del libro no compila, se arregla el ejemplo, no
  el lenguaje.** Si surge una fricción real escribiendo el libro
  que apunta a un problema del diseño, anotarlo aparte y
  comentarlo con el autor — no resolverlo modificando `../kaikai`
  desde este repo.
- Documentos clave en `../kaikai/docs/` para tener a mano:
  `design.md` (principios y tier list), `kaikai-minimal.md`
  (gramática y precedencia), `effects.md` /
  `effects-stdlib.md` / `syntax-sugars.md` (efectos),
  `structured-concurrency.md` y `actors.md` (concurrencia),
  `unions.md`, `protocols.md`, `typed-holes.md`.
- Ejemplos canónicos: `../kaikai/examples/quickstart/` (los cinco
  programas que cubren las formas principales) y
  `../kaikai/examples/phase4/`.

## Estructura del repo (provisional)

```
CLAUDE.md             — este archivo
README.md             — descripción pública del proyecto del libro
estructura.md         — tabla de contenidos detallada (próximo paso)
capitulos/            — capítulos en español, capNN-*.md
chapters/             — capítulos en inglés, chNN-*.md
ejemplos/capNN/       — código .kai de la edición en español
examples/chNN/        — código .kai de la edición en inglés
figuras/              — imágenes y diagramas comunes cuando son neutrales
borradores/           — material en bruto, ideas, notas que no
                        califican aún como capítulo
```

No crear esta estructura entera de golpe; aparece a medida que se
escriben los capítulos.

## Cómo trabajar este libro con Claude

- **Tarea por defecto: escribir prosa o código de ejemplo.** No
  refactorizar el lenguaje, no abrir issues en `../kaikai`, no
  modificar el compilador.
- **Pedir confirmación antes de crear capítulos nuevos o cambiar la
  tabla de contenidos.** La estructura general se discute con el
  autor y vive en `estructura.md` una vez acordada.
- **No inventar features de kaikai.** Si el texto necesita ilustrar
  algo y no está claro si existe, leer `../kaikai/docs/` o
  preguntar. No suponer la sintaxis.
- **Conservar la voz del autor.** Cuando se redacta una sección
  desde cero, leer dos o tres posts recientes del blog
  (`../lnds-blog/content/posts/`) y calibrar antes de empezar.
- **Capítulos cortos, no monolíticos.** Si una sección pasa de
  unas 1500 palabras o un ejemplo de unas 60 líneas, pensar si
  conviene partir.
