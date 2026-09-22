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
- **El nombre.** `kai kai` en rapanui (la figura de cordel y el
  canto *pata'u ta'u*), con la lectura mapuche de la serpiente Kai
  Kai como eco secundario reconocido pero no declarado. La línea
  con `ahu`, `manutara`, `hopu`, `taura` y los demás nombres del
  ecosistema, todos de la misma cantera polinesia: la decisión de
  poner nombres propios de la tierra del autor a sus herramientas.
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

### Parte I: Introducción

#### Capítulo 1 · Tour de kaikai

Recorrido panorámico. Al final del capítulo, el lector ha visto un
programa de cada forma principal del lenguaje y puede correrlos.
Se introducen sin profundizar: `fn main`, `let`, `if`, `match`,
tipos algebraicos, pipes, una fibra, un efecto. Es la pista de
aterrizaje, no el manual.

Materia prima: los cinco programas de
`kaikai/examples/quickstart/`.

- 1.1 Hola, kaikai
- 1.2 Tipos algebraicos y `match`: FizzBuzz
- 1.3 Una calculadora con AST recursivo
- 1.4 Un efecto propio con su handler
- 1.5 Dos fibras cooperativas
- 1.6 Tipos a la medida con protocolos
- 1.7 Unidades de medida
- 1.8 Programación por contrato
- 1.9 Pruebas en el mismo archivo
- 1.10 Holes: agujeros que compilan
- 1.11 Dependencias y proyectos: `kai.toml`
- 1.12 Cómo instalar y correr `kai`
- 1.13 Cómo está organizado el resto del libro
- *Sin ejercicios*: el lector aún no tiene herramientas para
  inventar.

#### Capítulo 2 · Pensar en kaikai

Por qué el lenguaje toma las decisiones que toma. Lectura corta
(10–15 páginas), pensada para quien viene de un mundo imperativo y
necesita ablandar algunas asunciones antes de seguir.

- 2.1 Expresiones, no sentencias
- 2.2 Inmutabilidad por defecto
- 2.3 `Option` y `Result` en vez de `null` y excepciones
- 2.4 Pattern matching como herramienta de control de flujo
- 2.5 Funciones puras y efectos visibles
- 2.6 El tipo no es la única etiqueta
- 2.7 Una breve genealogía
- *3 ejercicios* de comprensión, no de código.

### Parte II: El lenguaje

#### Capítulo 3 · Tipos básicos y expresiones

- 3.1 Los siete tipos primitivos
- 3.2 Literales e interpolación de strings
- 3.3 Operadores aritméticos, lógicos y de comparación
- 3.4 Más números: anchos fijos y precisión arbitraria
- 3.5 `let` y la propagación local de tipos
- 3.6 `if` como expresión
- 3.7 Bloques y el valor de un bloque
- 3.8 Tres formas de cuerpo de función
- *5 ejercicios*

#### Capítulo 4 · Tipos compuestos

- 4.1 Records
- 4.2 Acceso a campos y destructuring
- 4.3 Listas (y `Vec[T]`, el vector de valor, para indexar
       sin mutar)
- 4.4 Strings, no listas de chars
- 4.5 `Option` y `Result`: el día a día
- 4.6 Tuplas
- 4.7 Mapas y conjuntos hash
- *6 ejercicios*

#### Capítulo 5 · Sum types, uniones y `match`

Capítulo de peso. Donde el lector imperativo se da cuenta de que
los tipos algebraicos son la herramienta central, no un adorno.

- 5.1 Tipos suma con `|`
- 5.2 Constructores con y sin payload
- 5.3 Recursión en tipos
- 5.4 `match`: patrones, guardas, exhaustividad
- 5.5 Uniones de tipos existentes
- 5.6 Errores como uniones, sin wrappers
- 5.7 Caso de estudio: evaluador con errores tipados
- *6 ejercicios*

#### Capítulo 6 · Funciones y pipelines

- 6.1 Declaración
- 6.2 Lambdas
- 6.3 Funciones de orden superior
- 6.4 Pipes: `|>`, `|`, `||`
- 6.5 Trailing lambdas y otros azúcares
- 6.6 Recursión y TCO obligatoria
- 6.7 Caso de estudio: pipeline de transformación
- *5 ejercicios*

#### Capítulo 7 · Pruebas, propiedades y benchmarks

Capítulo dedicado a las tres construcciones top-level que kaikai
provee para verificar y medir código: `test`, `check`, `bench`.
Las tres viven al lado del código que prueban, en el mismo
archivo, y se ejecutan vía el driver `kai`.

- 7.1 `test "..." { ... }` y `assert`
- 7.2 `kai test` y el ciclo corto de retroalimentación
       (`--json` para consumo por máquina)
- 7.3 `check "..."`: propiedades
- 7.4 `bench "..." { ... }`: medir, no adivinar
- 7.5 Cuándo usar cuál
- 7.6 Caso de estudio: pruebas para un mini-evaluador
- *5 ejercicios*

#### Capítulo 8 · Módulos, imports, organización del código

Un archivo es un módulo. Varios archivos forman un proyecto.
Varios proyectos se componen vía el package manager. Este
capítulo recorre las tres escalas.

- 8.1 Un archivo, un módulo
- 8.2 `import` y nombres calificados
- 8.3 Visibilidad: el contrato del módulo
- 8.4 El stdlib que ya tienes
- 8.5 Proyectos: `kai.toml`
- 8.6 Dependencias: git, path, lock
- 8.7 Selección de versiones: MVS
- 8.8 Cache y `kai fetch`
- 8.9 Caso de estudio: refactor de un proyecto monolítico
- 8.10 Filosofía: simple y previsible
- *6 ejercicios*

#### Capítulo 9 · Protocolos

Single-dispatch, no typeclasses. El capítulo deja claro qué
escogió kaikai y por qué.

- 9.1 Por qué hay protocolos
- 9.2 Declarar un `protocol` y `impl`
- 9.3 Los cinco protocolos del stdlib
- 9.4 `#[derive(...)]` y cuándo usarlo
- 9.5 Protocolos propios
- 9.6 Por qué no hay typeclasses al estilo Haskell
- 9.7 Cotas de protocolo en funciones genéricas
- 9.8 Operadores: `+`, `==`, `<` como protocolos
- *5 ejercicios*

#### Capítulo 10 · Unidades de medida y branded types

kaikai trae units of measure al estilo F#, una herramienta rara
en lenguajes mainstream. El capítulo cubre dos casos: la
familia clásica (física, finanzas, tiempo) y los branded types
(`String<UserId>`), que es donde más impacto tiene en código
web/fintech del día a día.

- 10.1 `unit` y literales anotados
- 10.2 Aritmética con unidades
- 10.3 Álgebra de unidades: producto, cociente, potencia
- 10.4 Unidades genéricas
- 10.5 Conversiones explícitas
- 10.6 Branded types
- 10.7 Caso de estudio: cartera multi-moneda
- *5 ejercicios*

#### Capítulo 11 · Programación por contrato y refinement types

kaikai recoge dos mecanismos de Eiffel, Ada y D que conviven
mejor de lo que se reconoce en el mainstream: **contratos**
(precondiciones y postcondiciones que viven en la firma) y
**refinement types** (restricciones sobre los valores que un
tipo admite). Los dos cierran la Parte II del libro como
remate del hilo "información en el tipo, costo cero en
runtime" que arrancan los efectos y que continúan UoM.

- 11.1 Por qué contratos y refinements van juntos
- 11.2 `requires` y `ensures` en una firma
- 11.3 `result` y los nombres en alcance dentro del `ensures`
- 11.4 Refinement types
- 11.5 Cuándo se prueba estáticamente, cuándo en runtime
- 11.6 Tres formas de garantía
- 11.7 La familia Design by Contract
- 11.8 Lo que kaikai no hace, y por qué
- 11.9 Caso de estudio: cuenta bancaria
- *6 ejercicios*

### Parte III: Lo distintivo

#### Capítulo 12 · Efectos algebraicos

El capítulo más largo y más importante del libro. Acá pagamos la
deuda con LYAH: tono cálido, repetir cuando hace falta, un
concepto a la vez. Pero sin diluir.

- 12.1 La fricción que los efectos resuelven
- 12.2 Declarar un `effect`
- 12.3 Llamar a una operación: la firma cambia
- 12.4 Manejar un efecto con `handle ... with`
- 12.5 `resume`: el handler decide qué pasa después
- 12.6 Handlers con estado: el patrón `State`
- 12.7 `var`, `Ref[T]` y `Array[T]`: dos mecanismos distintos
- 12.8 Componer efectos: handlers anidados
- 12.9 Instancias nombradas: el handler como valor
- 12.10 Alias de filas de efectos
- 12.11 Default handlers: el efecto trae el suyo
- 12.12 Los handlers del stdlib son código kaikai
- 12.13 Caso de estudio: procesador de configuración
- 12.14 Filosofía: tres ideas que vale recordar
- *9 ejercicios*

#### Capítulo 13 · Concurrencia y memoria

Perceus y fibras juntos. Cada uno explica al otro: la mutación
visible vive bajo `Mutable`, las fibras son aisladas porque la
memoria es por-fibra.

- 13.1 El modelo: fibras aisladas
- 13.2 Perceus en una página
- 13.3 Crear y esperar fibras: las operaciones básicas
- 13.4 Nurseries: concurrencia estructurada
- 13.5 Cancelación cooperativa
- 13.6 Memoria mutable por fibra
- 13.7 Por qué las fibras no pueden escapar de su nursery
- 13.8 Caso de estudio: repartir trabajo entre fibras
- 13.9 Filosofía: dos invariantes que vale recordar
- *6 ejercicios*

#### Capítulo 14 · Actores

- 14.1 `Actor[Msg]`: el efecto
- 14.2 `with_mailbox`: dar mailbox a la fibra actual
- 14.3 `spawn_actor`: crear un actor nuevo
- 14.4 Policies de mailbox: qué pasa cuando se llena
- 14.5 Patrón request/reply
- 14.6 Supervisión: links y monitores
- 14.7 Caso de estudio: supervisor con reintentos
- 14.8 Filosofía: actores son una biblioteca
- *5 ejercicios*

#### Capítulo 15 · Holes y kaikai con agentes IA

Holes (`?`, `?nombre`) son una herramienta de **diálogo con
el compilador** que sirve a dos audiencias: el programador
humano que diseña de arriba hacia abajo, y el agente IA al
que le pides que rellene un programa parcialmente
especificado. El capítulo abre con la utilidad humana
(porque holes son útiles aunque nunca uses un LLM) y escala
a la apuesta estratégica del lenguaje (Tier 3 en
`design.md`): kaikai diseñado para que un LLM pueda
autorearlo, aunque su corpus de entrenamiento contenga poca
o nada de kaikai.

Acá pagamos la deuda con varios posts del blog (*Juicio y
estilo*, *El poder de los agentes*, *Tus agentes necesitan
un jefe*, *Kimun*): la IA no reemplaza al programador, lo
apalanca si las herramientas están bien diseñadas. kaikai es
un experimento en esa dirección.

- 15.1 Holes tipados: `?` y `?nombre`
- 15.2 La conversación con el compilador
- 15.3 Diseño top-down: empieza por la firma
- 15.4 Programas parciales: avanzar con el resto compilando
- 15.5 Holes en patrones: el match incompleto
- 15.6 La apuesta LLM: lenguaje diseñado para agentes
- 15.7 La salida JSON de los holes
- 15.8 Más allá de holes: información rica como interfaz
- 15.9 Un loop de trabajo con un agente
- 15.10 Lo que el lenguaje no automatiza
- 15.11 Caso de estudio: completar una función no trivial
- 15.12 Filosofía: tres ideas que vale recordar
- *5 ejercicios* (un par requieren acceso a un LLM; los otros se
  resuelven a mano leyendo la salida del compilador)

### Parte IV: Práctica

#### Capítulo 16 · Tooling: el binario `kai`

- 16.1 Compilar y correr: `kai run`, `kai build`
- 16.2 Tests, propiedades y benchmarks
- 16.3 Formateo: `kai fmt`
- 16.4 El linter: `kai lint`
- 16.5 Gestión de paquetes: `init`, `add`, `fetch`, `update`
- 16.6 Modo de desarrollo: `kai watch`
- 16.7 Integración con editores: `kai lsp`
- 16.8 Documentación interactiva: `kai info`
- 16.9 La referencia del stdlib: `kai doc`
- 16.10 Dos backends: nativo y C
- 16.11 Estructura típica de un proyecto
- 16.12 Hablar con C: `extern "C"` y el efecto `Ffi`
- 16.13 Ediciones: estabilidad sin estancamiento
- 16.14 Filosofía: tres principios del tooling
- *Sin ejercicios*: capítulo de referencia.

#### Capítulo 17 · Caso de estudio: servidor HTTP

Un programa real, completo, comentado paso a paso. Mini
servidor HTTP de notas con persistencia en archivo, usando
efectos para IO, fibras para conexiones, y actores para la
cola de escritura. Tamaño objetivo: 300–500 líneas, repartidas
en 4–6 módulos.

El énfasis es **concurrencia y modularidad**: sum types,
match, actores, fibras, módulos. Cubre la mayor parte del
libro pero deja afuera UoM y contratos.

- 17.1 La forma del programa
- 17.2 El dominio: tipos puros
- 17.3 El almacén: actor con estado
- 17.4 Persistencia: actor de escritura
- 17.5 Parser HTTP
- 17.6 El main: armar todas las piezas
- 17.7 Lo que está ocurriendo, en términos del libro
- 17.8 Cómo extenderlo
- 17.9 Lo que muestra este caso

#### Capítulo 18 · Caso de estudio: ledger contable

Segundo programa integrador, esta vez orientado al dominio
financiero. Implementa un libro mayor de doble entrada
(double-entry ledger) con balances por cuenta, transacciones
atómicas, validación de cuadre (la suma de débitos iguala la
suma de créditos), y persistencia inmutable como log de
eventos.

El énfasis está donde el cap. 17 no llega: **UoM con monedas**
(`Real<USD>`, `Real<EUR>`, conversiones explícitas),
**contratos** (`requires` que el monto sea positivo,
`ensures` que la transacción cuadra), **inmutabilidad por
construcción** (el ledger nunca se modifica, solo se le
agregan eventos), y **branding de identificadores** (`Int<
CuentaId>` vs `Int<TransaccionId>`).

Tamaño objetivo: similar al cap. 17. Mismo patrón general
(dominio puro, actores con estado, persistencia) aplicado a
fintech.

- 18.1 La forma del programa
- 18.2 El dominio: unidades, branding, tipos algebraicos
- 18.3 La invariante central: cuadre
- 18.4 El almacén: actor con invariantes
- 18.5 El log de auditoría
- 18.6 El main: ejecutar un escenario
- 18.7 Lo que hace este caso distinto del cap. 17
- 18.8 Cómo extenderlo
- 18.9 Por qué fintech es un buen banco de pruebas
- 18.10 Filosofía: el cierre del libro

#### Capítulo 19 · Kinds: un catálogo de álgebras

Capítulo final, avanzado. Nombra el mecanismo general que el
lector ya usó sin saberlo: los kinds y sus theories de
unificación. No se necesita para escribir kaikai productivo;
cierra el libro mostrando que unidades, efectos, monedas y
regiones son cinco entradas del mismo catálogo.

- 19.1 Qué es un kind
- 19.2 Las theories: álgebras de unificación
- 19.3 El catálogo completo
- 19.4 Cuantificar sobre cualquier kind
- 19.5 Kinds propios
- 19.6 Region: memoria como habitante
- 19.7 Dinero: el álgebra que falta a propósito
- 19.8 Layout: el orden de los bytes
- 19.9 Perm: permisos que el tipo persigue
- 19.10 Dim: la forma como índice
- 19.11 Shape: el contenedor como habitante
- 19.12 Theory cerrada, modelos abiertos
- *5 ejercicios*

### Apéndices

- **A. Bootstrap de tres etapas.** Cómo se construye el compilador
  desde una `cc` y nada más. Stage 0 → Stage 1 → Stage 2. Por qué
  esa decisión y qué sostiene.
- **B. Perceus a fondo.** El §13.2 cubre la idea en una página
  para que el modelo de memoria cuadre con las fibras. Este
  apéndice se mete en los detalles: análisis paso a paso de
  drops, reuse in place, comparación con `Rc<RefCell>`, qué pasa
  con ciclos, y por qué la separación por fibra simplifica el RC.
- **C. Tabla de operadores y precedencia.**
- **D. Catálogo de efectos del stdlib.**
- **E. Glosario.** Términos del libro con su correspondencia
  inglés/español, especialmente los que dejamos en inglés en el
  texto en español (handler, fiber, effect row).
- **F. Para seguir.** Lecturas recomendadas: Effekt, Koka,
  Erlang/Elixir, Perceus paper, *No Silver Bullet*, *Simple Made
  Easy*.

## Cuenta gruesa

- 19 capítulos + 6 apéndices.
- ≈ 400 páginas en la edición impresa estimada (asumiendo 18–22
  páginas promedio por capítulo principal; el cap. 15 es algo
  más largo que la versión "solo holes").
- 8 casos de estudio integradores: evaluador de expresiones
  (cap. 5), pipeline de transformación (cap. 6), cartera de
  monedas con `Money<C>` (cap. 10), cuenta bancaria con
  contratos y refinements (cap. 11), parser de configuración
  con efectos (cap. 12), servidor de eco concurrente (cap. 13),
  actor supervisado (cap. 14), completar función con holes +
  agente (cap. 15), servidor HTTP de notas (cap. 17).

## Orden de escritura sugerido

No coincide con el orden de lectura. Conviene escribir primero los
capítulos que más estabilizan vocabulario y estilo de ejemplos:

1. **Cap. 1: Tour.** Establece el tono y el formato de los
   ejemplos. Si esto está bien, el resto fluye.
2. **Cap. 5: Sum types.** Es el corazón del modelo de tipos. Si
   queda claro, la mitad del libro queda ordenada.
3. **Cap. 12: Efectos.** Capítulo más difícil. Escribirlo
   temprano destapa cualquier ambigüedad de la doc del lenguaje.
4. **Cap. 13: Concurrencia y memoria.** Depende del 12.
5. Resto en orden de tabla.

El cap. 17 (caso de estudio integrador) y los apéndices se
escriben al final.
