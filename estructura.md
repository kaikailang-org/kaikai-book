# Estructura del libro

Tabla de contenidos detallada. Vive aparte del CLAUDE.md porque
cambia más seguido. Decisiones generales (foco, voz, idioma) están
en `CLAUDE.md` y no se repiten aquí.

## Decisiones que fijan el orden

1. **Apertura: tour del lenguaje** (estilo TGPL cap. 1). El lector
   no tiene background funcional; arrancar por efectos algebraicos
   sería violento. El tour deja al lector con un programa
   ejecutable y la sensación de "ya puedo leer esto".
2. **Concurrencia y memoria en un solo capítulo.** Perceus y las
   fibras se entienden mejor juntos: ambos definen el modelo de
   ejecución. Separarlos obliga al lector a montar dos modelos
   mentales antes de ver cómo encajan.
3. **Bootstrap de tres etapas: apéndice, no flujo principal.** Es
   parte del relato del proyecto, pero no del lenguaje que se
   está aprendiendo. Quien quiera entender cómo se construyó el
   compilador lo encuentra al final.

## Forma de cada capítulo

- **15–25 páginas equivalentes** (unas 4.000–7.000 palabras).
- **Apertura cálida** (estilo LYAH): un párrafo que sitúa por qué
  importa el tema, sin tecnicismos. Acá vive la voz del autor.
- **Cuerpo denso** (estilo TGPL): conceptos, ejemplos ejecutables,
  reglas claras. Cada ejemplo se compila y produce la salida
  prometida.
- **Cierre con un caso de estudio o un ejemplo integrador** cuando
  el capítulo lo amerita. No todos lo necesitan.
- **Ejercicios numerados** al final. Entre 3 y 8 según el peso del
  capítulo.

## Tabla de contenidos

### Frontmatter

#### Prólogo

Texto corto (4–8 páginas), en primera persona, sin numeración de
capítulo. No es un manual de uso del libro; es la pieza personal
que justifica por qué este libro existe y por qué este lenguaje
existe.

Lo redacta el autor con su voz de blog. Claude no escribe el
prólogo, lo edita o lo asiste a pedido. Material temático que
encaja:

- **Por qué un lenguaje nuevo en 2026**, cuando ya hay muchos.
  Lo que kaikai busca y lo que descarta a propósito (ningún GC,
  ningún borrow checker, ninguna typeclass, ningún async/await
  separado del resto).
- **El nombre.** kaikai en mapudungun, la línea con kimun y
  lonko, la decisión de poner nombres propios de la tierra del
  autor a sus herramientas.
- **Por qué este libro.** No es la doc del lenguaje (eso vive en
  `kaikai/docs`). Es un libro de lectura para quien quiera
  entender el lenguaje completo, en orden, con casos reales.
- **A quién está dirigido y a quién no.** Programador con
  experiencia, sin background funcional necesariamente. No es
  para principiantes absolutos.
- **Cómo leerlo.** En orden, o saltando a Parte III si vienes de
  un lenguaje funcional. Los ejemplos se compilan; el código
  está en el repo.
- **Agradecimientos.** A Leo Soto y otros colegas que aparecen
  en el blog; a los autores cuyas ideas kaikai recoge (Daan
  Leijen por Koka, Andreas Rossberg y Jonathan Brachthäuser por
  Effekt, Joe Armstrong por el espíritu BEAM).
- **Edición bilingüe.** Una nota corta sobre por qué hay edición
  en español y en inglés, y por qué cada una se escribió en su
  voz nativa, no como traducción.

Cierre con una frase con peso (estilo blog), no con un resumen
del libro.

### Parte I — Introducción

#### Capítulo 1 · Tour de kaikai

Recorrido panorámico. Al final del capítulo, el lector ha visto un
programa de cada forma principal del lenguaje y puede correrlos.
Se introducen sin profundizar: `fn main`, `let`, `if`, `match`,
tipos algebraicos, pipes, una fibra, un efecto. Es la pista de
aterrizaje, no el manual.

Materia prima: los cinco programas de
`../kaikai/examples/quickstart/`.

- 1.1 Hola, kaikai
- 1.2 Tipos algebraicos y `match`: FizzBuzz
- 1.3 Una calculadora con AST recursivo
- 1.4 Un efecto propio con su handler
- 1.5 Dos fibras cooperativas
- 1.6 Cómo instalar y correr `kai`
- 1.7 Cómo está organizado el resto del libro
- *Sin ejercicios*: el lector aún no tiene herramientas para
  inventar.

#### Capítulo 2 · Pensar en kaikai

Por qué el lenguaje toma las decisiones que toma. Lectura corta
(10–15 páginas), pensada para quien viene de un mundo imperativo y
necesita ablandar algunas asunciones antes de seguir.

- 2.1 Expresiones, no sentencias
- 2.2 Inmutabilidad por defecto, mutación como efecto
- 2.3 `Option` y `Result` en vez de `null` y excepciones
- 2.4 Funciones puras y efectos visibles en el tipo
- 2.5 Pattern matching como herramienta de control de flujo
- 2.6 Una breve genealogía: ML, Haskell, Erlang, Elixir, Koka,
      Effekt — qué tomó kaikai de cada uno
- *3 ejercicios* de comprensión, no de código.

### Parte II — El lenguaje

#### Capítulo 3 · Tipos básicos y expresiones

- 3.1 `Int`, `Real`, `Bool`, `Char`, `String`, `Unit`
- 3.2 Literales e interpolación de strings
- 3.3 Operadores aritméticos, lógicos, de comparación
- 3.4 `let` y la propagación local de tipos
- 3.5 `if` como expresión
- 3.6 Bloques y el valor de un bloque
- 3.7 La diferencia entre `=` y `{ ... }` en el cuerpo de una
      función
- *5 ejercicios*

#### Capítulo 4 · Tipos compuestos

- 4.1 Records y construcción literal
- 4.2 Acceso a campos, sugar posicional
- 4.3 Listas: construcción, recorrido, patrones
- 4.4 Strings como entidades aparte (no listas de chars)
- 4.5 `Option[T]` y `Result[E, T]` — uso cotidiano
- 4.6 Tuples y cuándo usarlas vs. records
- *6 ejercicios*

#### Capítulo 5 · Sum types, uniones y `match`

Capítulo de peso. Donde el lector imperativo se da cuenta de que
los tipos algebraicos son la herramienta central, no un adorno.

- 5.1 Tipos suma con `|`
- 5.2 Constructores con y sin payload
- 5.3 Recursividad en tipos: la lista, el árbol, la expresión
- 5.4 `match`: patrones, guardas, exhaustividad
- 5.5 Uniones de tipos existentes (`type T = A | B`) y subtipado
      por componentes
- 5.6 Errores como uniones, sin wrapper sums
- 5.7 Caso de estudio: evaluador de expresiones aritméticas con
      manejo de errores
- *6 ejercicios*

#### Capítulo 6 · Funciones y pipelines

- 6.1 Declaración, parámetros, tipo de retorno
- 6.2 Lambdas: `x => ...`, `(a, b) => ...`, placeholder `.`
- 6.3 Funciones de orden superior
- 6.4 `|>` (apply) vs `|` (map): dos tubos, dos intenciones
- 6.5 Trailing lambdas y otros sugars de m7b
- 6.6 Recursión y TCO obligatoria
- 6.7 Caso de estudio: pipeline de transformación de datos
- *5 ejercicios*

#### Capítulo 7 · Módulos, imports, organización del código

- 7.1 Un archivo, un módulo
- 7.2 `import`, visibilidad (`pub`)
- 7.3 Nombres calificados y resolución
- 7.4 El stdlib que viene gratis (`stdlib/core/`)
- 7.5 Tests inline: `test "..." { ... }` y `assert`
- *4 ejercicios*

#### Capítulo 8 · Protocolos

Single-dispatch, no typeclasses. El capítulo deja claro qué
escogió kaikai y por qué.

- 8.1 Por qué hay protocolos
- 8.2 Declarar un `protocol` y `impl`
- 8.3 `Show`, `Eq`, `Ord`, `Hash`, `Serialize` del stdlib
- 8.4 `#derive(...)` y cuándo usarlo
- 8.5 Por qué no hay typeclasses al estilo Haskell
- 8.6 Operadores: `+`, `==`, `<` como protocolos
- *5 ejercicios*

### Parte III — Lo distintivo

#### Capítulo 9 · Efectos algebraicos

El capítulo más largo y más importante del libro. Acá pagamos la
deuda con LYAH: tono cálido, repetir cuando hace falta, un
concepto a la vez. Pero sin diluir.

- 9.1 La fricción que los efectos resuelven (excepciones,
      async/await, dependency injection vista junta)
- 9.2 Declarar un `effect`
- 9.3 Llamar a una operación: la firma cambia
- 9.4 Instalar un handler con `handle ... with`
- 9.5 `resume`: por qué un handler decide qué pasa después
- 9.6 Efectos del stdlib: `Stdout`, `Stdin`, `Env`, `File`,
      `Random`, `Fail`
- 9.7 Handlers por defecto (los efectos "implícitos" de programas
      simples)
- 9.8 Componer efectos: filas, polimorfismo de filas
- 9.9 Aliases de efectos
- 9.10 Caso de estudio: parser de configuración con `Reader`,
       `Writer`, `Fail`
- *7 ejercicios*

#### Capítulo 10 · Concurrencia y memoria

Perceus y fibras juntos. Cada uno explica al otro: la mutación
visible vive bajo `Mutable`, las fibras son aisladas porque la
memoria es por-fibra.

- 10.1 El modelo: fibras aisladas, RC por fibra
- 10.2 Perceus en una página: por qué no hay GC ni borrow checker
- 10.3 `fiber_spawn`, `fiber_yield`, `fiber_await`
- 10.4 Cancelación cooperativa con el efecto `Cancel`
- 10.5 Nurseries y concurrencia estructurada
- 10.6 El efecto `Mutable` y arrays: cuándo se ve, cuándo se
       enmascara
- 10.7 Por qué las fibras no pueden escapar de su nursery
- 10.8 Caso de estudio: servidor concurrente de eco
- *6 ejercicios*

#### Capítulo 11 · Actores

- 11.1 `Actor[Msg]`: efecto parametrizado
- 11.2 `spawn_actor`, `with_mailbox`
- 11.3 `send`, `receive`, `self`
- 11.4 Link y monitor: supervisión al estilo BEAM
- 11.5 Patrones request/reply
- 11.6 Caso de estudio: actor supervisado con reintentos
- *5 ejercicios*

#### Capítulo 12 · kaikai y los LLMs

La apuesta estratégica del lenguaje (Tier 3 en `design.md`):
diseñar para que un LLM pueda autorearlo, aunque su corpus de
entrenamiento contenga poca o nada de kaikai. El capítulo no es
un panfleto sobre IA; es la explicación honesta de un principio
de diseño y de las herramientas concretas que lo sostienen.

Acá pagamos la deuda con varios posts del blog (*Juicio y
estilo*, *El poder de los agentes*, *Tus agentes necesitan un
jefe*, *Kimun*): la IA no reemplaza al programador, lo apalanca
si las herramientas están bien diseñadas. kaikai es un
experimento en esa dirección.

- 12.1 La apuesta: por qué un lenguaje nuevo se diseña pensando
       en LLMs
- 12.2 De qué sirve la información de tipos y efectos cuando el
       que escribe el código no eres tú
- 12.3 Holes tipados: `?` y `?nombre`
- 12.4 `--holes-json`: salida estructurada del compilador
- 12.5 Más allá de holes: `kai type --json`, contraejemplos de
       `match` no exhaustivo, diagnósticos en JSON
- 12.6 Un loop de trabajo con un agente: investigar, planificar,
       ejecutar (siguiendo lo que ya describí en el blog)
- 12.7 Lo que el lenguaje **no** automatiza: juicio, gusto,
       arquitectura
- 12.8 Caso de estudio: completar una función no trivial dejando
       holes y dejando que el agente itere
- *4 ejercicios* (un par requieren acceso a un LLM; los otros se
  resuelven a mano leyendo la salida del compilador)

### Parte IV — Práctica

#### Capítulo 13 · Tooling: el binario `kai`

- 13.1 `kai run`, `kai build`, `kai test`
- 13.2 `kai fmt`
- 13.3 `kai repl` y el flujo iterativo
- 13.4 `kai lsp` e integración con editores
- 13.5 Estructura típica de un proyecto kaikai
- *Sin ejercicios* — capítulo de referencia.

#### Capítulo 14 · Caso de estudio integrador

Un programa real, completo, comentado paso a paso. Candidato
inicial: un mini servidor HTTP de notas con persistencia en
archivo, usando efectos para IO, fibras para conexiones, y
actores para la cola de escritura. Tamaño objetivo: 300–500
líneas, repartidas en 4–6 módulos.

Se redacta al final, cuando los capítulos previos estabilicen
sintaxis y estilo de ejemplos.

### Apéndices

- **A. Bootstrap de tres etapas.** Cómo se construye el compilador
  desde una `cc` y nada más. Stage 0 → Stage 1 → Stage 2. Por qué
  esa decisión y qué sostiene.
- **B. Tabla de operadores y precedencia.**
- **C. Catálogo de efectos del stdlib.**
- **D. Glosario.** Términos del libro con su correspondencia
  inglés/español, especialmente los que dejamos en inglés en el
  texto en español (handler, fiber, effect row).
- **E. Para seguir.** Lecturas recomendadas: Effekt, Koka,
  Erlang/Elixir, Perceus paper, *No Silver Bullet*, *Simple Made
  Easy*.

## Cuenta gruesa

- 14 capítulos + 5 apéndices.
- ≈ 340 páginas en la edición impresa estimada (asumiendo 18–22
  páginas promedio por capítulo principal; el cap. 12 es algo
  más largo que la versión "solo holes").
- 6 casos de estudio integradores: evaluador de expresiones
  (cap. 5), pipeline de transformación (cap. 6), parser de
  configuración con efectos (cap. 9), servidor de eco
  concurrente (cap. 10), actor supervisado (cap. 11), completar
  función con holes + agente (cap. 12), servidor HTTP de notas
  (cap. 14).

## Orden de escritura sugerido

No coincide con el orden de lectura. Conviene escribir primero los
capítulos que más estabilizan vocabulario y estilo de ejemplos:

1. **Cap. 1 — Tour.** Establece el tono y el formato de los
   ejemplos. Si esto está bien, el resto fluye.
2. **Cap. 5 — Sum types.** Es el corazón del modelo de tipos. Si
   queda claro, la mitad del libro queda ordenada.
3. **Cap. 9 — Efectos.** Capítulo más difícil. Escribirlo temprano
   destapa cualquier ambigüedad de la doc del lenguaje.
4. **Cap. 10 — Concurrencia y memoria.** Depende de 9.
5. Resto en orden de tabla.

El cap. 14 (caso de estudio integrador) y los apéndices se
escriben al final.
