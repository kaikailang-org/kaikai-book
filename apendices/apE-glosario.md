# Apéndice E · Glosario

Términos que el libro usa con un significado específico, con
su equivalencia en inglés cuando corresponde. Los términos en
inglés están así a propósito: son los nombres que usan la
documentación del lenguaje y la comunidad de los lenguajes
funcionales, y traducirlos confunde más que ayuda. El glosario
los nombra para que el lector que entra desde otro lenguaje
encuentre rápido a qué se refieren.

## A

**Actor.** Una fibra con un mailbox tipado encima. Procesa
mensajes que recibe en orden, mantiene estado interno entre
mensajes. En kaikai, los actores son una biblioteca construida
sobre el efecto `Actor[Msg]`.

**Algebraic effect** *(efecto algebraico)*. Un efecto en el
sentido del cap. 12: una construcción del lenguaje que declara
operaciones (con su firma) sin decidir cómo se implementan, y
permite que un `handle` decida en cada punto del programa qué
significa cada operación.

**Array** *(arreglo)*. Estructura de datos con acceso por
índice en tiempo constante. En kaikai, `Array[T]` es mutable;
la mutación está bajo el efecto `Mutable`.

**Assert** *(aserción)*. Construcción dentro de bloques
`test`, `check`, contratos. Si la condición es `false`, el
bloque o el programa abortan.

## B

**Backpressure** *(retropresión)*. Mecanismo para que un
consumidor lento haga frenar a un productor rápido. En kaikai,
la policy `Bounded(N, BlockSender)` de un mailbox bloquea el
emisor cuando el mailbox está lleno.

**Bottom type** *(tipo bottom)*. Tipo sin habitantes, escrito
`Nothing`. Una función que devuelve `Nothing` no puede
regresar normalmente: o no termina, o aborta, o llama a un
efecto que no devuelve. Por eso `Fail.fail(...) : Nothing` es
la firma natural de una operación que no resume.

**Bounded** *(acotado)*. Una policy de mailbox con capacidad
fija. Cuando se llena, el comportamiento depende de la regla
de overflow: `DropOldest`, `DropNewest` o `BlockSender`.

**Branded type** *(tipo con marca)*. Un tipo numérico o
string marcado con una unidad simbólica (`Int<UserId>`) para
que el sistema de tipos lo distinga de otros tipos con la
misma representación. Caso particular del sistema de unidades
de medida.

## C

**Cancellation** *(cancelación)*. El acto de pedirle a una
fibra que termine antes de tiempo. En kaikai es un efecto:
`Cancel.raise()`. La fibra puede instalar un handler para
hacer limpieza antes de desenrollarse.

**Capability** *(capacidad)*. El binding que un `handle ...
with Effect` le da al body para invocar las operaciones del
efecto. Por defecto, el nombre de la capacidad es el del
efecto: dentro de un handler de `Log`, se llama `Log.log(...)`.
La sintaxis `with X as nombre` permite renombrarla.

**Closure** *(clausura)*. Un valor de función que captura
variables del scope donde se creó.

**Continuation** *(continuación)*. El "resto de lo que falta
hacer" en un punto del programa. En kaikai aparece como el
argumento `resume` que reciben los handlers de efectos: llamar
a `resume(v)` continúa el cómputo del body con `v`.

**Contracts** *(contratos)*. `requires` (precondición) y
`ensures` (postcondición) en la firma de una función,
verificados estáticamente cuando es posible y dinámicamente
cuando no. Cap. 11.

## D

**Default handler** *(handler por defecto)*. El handler que
el runtime instala automáticamente alrededor de `main` para
ciertos efectos (`Console`, `File`, `Spawn`, etc.). Los
handlers del usuario instalados con `handle ... with X` se
imponen sobre el handler por defecto mientras están en scope.

**Doble entrada** *(double-entry, en contabilidad)*. Sistema
contable donde cada transacción tiene débitos que igualan los
créditos. Aparece en el caso de estudio del cap. 18.

**Drop** *(liberar)*. La operación que Perceus inserta en el
último uso de cada valor para decrementar su contador de
referencia. Si llega a cero, la memoria se libera.

## E

**Effect** *(efecto)*. Ver *Algebraic effect*.

**Effect row** *(fila de efectos)*. La lista de efectos en una
firma: `Int / Log + Fail + State[Int]`. Se construye con `+`
y se trata como un conjunto, no como una secuencia.

**Event sourcing.** Patrón arquitectónico donde el estado del
sistema es la suma de los eventos ocurridos; el log de eventos
es la fuente de verdad y el estado en memoria se reconstruye
replicándolo. Aparece en el cap. 18.

**Exhaustiveness** *(exhaustividad)*. Propiedad que el
compilador verifica en `match`: que todos los habitantes del
tipo del escrutinio estén cubiertos. Cap. 5.

## F

**Fiber** *(fibra)*. Unidad de ejecución cooperativa. En
kaikai una fibra es liviana (cientos de bytes), tiene su
propio heap, no comparte memoria con otras fibras, y solo cede
el control en puntos de yield explícitos. Cap. 13.

**Function coloring problem.** El problema donde una
característica del lenguaje (típicamente `async/await`) parte
las funciones en dos colores incompatibles, y cambiar una
función contagia a todas las que la llaman. Aparece en el
ensayo *"What Color is Your Function?"* de Bob Nystrom (2015),
y kaikai lo resuelve metiendo todo en filas de efectos.

## H

**Handler.** El bloque `with Effect { ... }` que decide qué
hacer con las invocaciones a un efecto. Para cada operación
recibe los argumentos y un `resume`, y decide si continuar
el body o no.

**Hole** *(agujero, hueco)*. Una expresión `?` o `?nombre`
que compila pero aborta en runtime si la ejecución llega a
ella. Sirve para diseño top-down (humano) y como interfaz
para agentes IA. Cap. 15.

## I

**Inmutabilidad por defecto.** Los valores en kaikai son
inmutables por construcción: `let x = ...` declara un binding
que no cambia. Las construcciones mutables (`var`, `Ref[T]`,
`Array[T]`) son la excepción explícita.

## L

**Last-use analysis** *(análisis de último uso)*. La fase del
compilador donde se identifica, para cada variable, el punto
exacto en el que se usa por última vez. Perceus usa este
análisis para insertar `drop`s en el lugar correcto.

**Linked** *(enlazado, en actores)*. Dos actores enlazados con
`Link.link(pid)` se enteran mutuamente cuando uno termina:
si uno cae, el otro recibe `Cancel.raise()`. Cap. 14.

## M

**Mailbox** *(buzón)*. La cola de mensajes asociada a un
actor. El actor procesa los mensajes en orden FIFO. La
**policy** del mailbox decide qué hacer cuando se llena
(unbounded, drop-oldest, drop-newest, block-sender).

**Match.** Expresión de pattern matching. Cubre todos los
constructores de un sum type (exhaustivo) y permite extraer
componentes de records y listas. Cap. 5.

**Monitor** *(monitor, en actores)*. Un actor que monitorea a
otro recibe un mensaje `MonitorDown` cuando el monitoreado
termina, sin acoplar su propia vida a la del observado. Cap. 14.

**MVS** *(minimum-version selection)*. Algoritmo de resolución
de dependencias del gestor de paquetes. Cuando un proyecto
declara `manutara@v0.1.0` y otro `manutara@v0.2.0`, MVS elige
la **máxima** de las versiones declaradas. Cap. 8.

## N

**Nothing.** Ver *Bottom type*.

**Nursery** *(guardería).** Un scope léxico que contiene
fibras hijas y garantiza que ninguna sobreviva al bloque.
Se construye con `nursery { n -> ... }`, que es azúcar sobre
`handle ... with Spawn as n { ... }`. Cap. 13.

## O

**Operation** *(operación)*. La declaración nombrada dentro
de un `effect`: un nombre, parámetros, tipo de retorno. Las
operaciones se invocan con `Effect.op(args)`.

## P

**Pattern matching.** La construcción `match` y los patrones
en `let`. Permite descomponer valores estructurados (sum
types, records, listas) en componentes. Cap. 5.

**Perceus.** El sistema de reference counting estático que
kaikai usa para liberar memoria sin GC ni borrow checker.
Inventado por Reinking, Xie, de Moura y Leijen (PLDI 2021).
Apéndice B y cap. 13 §13.2.

**Pid** *(process id, identificador de proceso)*. Handle
tipado de un actor: `Pid[Msg]`. Identifica un mailbox y
también garantiza que solo se pueden enviar mensajes de tipo
`Msg` a ese mailbox.

**Pipe** *(pipe, tubería)*. Operadores `|>`, `|`, `||`, `|?`.
Encadenan transformaciones. Cap. 6.

**Polymorphism** *(polimorfismo)*. La capacidad de una función
de operar sobre múltiples tipos. En kaikai aparece como
generics (`fn map[a, b](xs: [a], f: (a) -> b) : [b]`) y como
filas polimórficas (`/ e` donde `e` es una variable de fila).

**Protocol** *(protocolo)*. Una interfaz declarada con
`protocol`, implementada por tipos vía `impl Protocol for T`.
Es single-dispatch (resuelve por un solo tipo). Cap. 9.

**Pure** *(puro)*. Una función es pura si no produce efectos
(su fila está vacía). Las funciones puras son fáciles de
testear, paralelizar y razonar.

## R

**Ref** *(referencia)*. Una celda mutable con sobrevida
arbitraria, accesible vía `Mutable.ref_make` /
`Mutable.ref_get` / `Mutable.ref_set`. Cap. 12 §12.7.

**Refinement type** *(tipo refinado)*. Un tipo con un
predicado restrictivo: `Int where self >= 0`. Cap. 11.

**Resume.** Ver *Continuation*.

**Reuse in place** *(reutilización en sitio)*. Optimización
de Perceus: cuando un valor único se va a liberar y se va a
crear otro del mismo shape inmediatamente después, se reusa
la misma memoria sin tocar contadores. Apéndice B.

**Row variable** *(variable de fila)*. Una variable
polimórfica que representa "el resto de los efectos" en una
firma: `fn map[A, B, e](xs: [A], f: (A) -> B / e) : [B] / e`.

## S

**Self-hosting.** Estado en el que un compilador está escrito
en el mismo lenguaje que compila. El compilador `kaic2` de
kaikai está escrito en kaikai. Apéndice A.

**Span.** El rango de bytes en el archivo fuente donde vive
una construcción. Los mensajes del compilador usan spans para
señalar dónde ocurrió un error.

**Spawn.** Crear una fibra o un actor nuevo. Operación del
efecto `Spawn`.

**Stage 0/1/2.** Los tres compiladores que forman el
bootstrap de kaikai. Stage 0 en C, stage 1 en kaikai-minimal,
stage 2 en kaikai completo. Apéndice A.

**State[T].** Efecto del stdlib para llevar estado mutable
encapsulado. La forma azucarada `var nombre = init` desazucara
a `handle ... with State[T](init)` (cap. 12 §12.7).

**Stdout, Stderr, Stdin.** Salida estándar, salida de error
estándar, entrada estándar. En kaikai estos están bajo el
efecto `Console` (para los dos primeros) y `Stdin` (para el
último).

**Sum type** *(tipo suma, tipo algebraico de datos)*. Un tipo
con varios constructores, cada uno cargando datos distintos.
La construcción `type Forma = Circulo(Real) | Cuadrado(Real)`.
Cap. 5.

## T

**Tail call** *(llamada de cola)*. Una llamada a función que
está en la posición de "lo último que hace la función actual".
El compilador la compila a un salto, no a una llamada con
push de stack, así que la recursión por cola corre sin
consumir memoria de pila. Cap. 6.

**Top-down design** *(diseño descendente)*. Estilo de diseño
en el que se empieza por la firma de las funciones de nivel
superior, dejando holes en los cuerpos, y se completan las
piezas internas después. Cap. 15.

**Trap exit.** Capacidad de un actor de **no** propagarse
automáticamente cuando una fibra hermana cae. Se activa con
`fiber_set_trap_exit(true)`; el actor recibe un mensaje
informativo en vez de un `Cancel.raise()`. Cap. 14.

## U

**Unidad de medida.** Una unidad simbólica declarada con
`unit` que anota a un valor numérico (`Real<USD>`,
`Int<Seconds>`). El sistema de tipos rechaza operaciones que
mezclan unidades incompatibles. Cap. 10.

## V

**Var.** Construcción de declaración de celda mutable local.
Es azúcar sobre `State[T]`. Cap. 12 §12.7.

## Y

**Yield** *(ceder)*. El acto en que una fibra le pasa el
control al scheduler para que otra fibra pueda correr.
`fiber_yield()` lo hace explícitamente; las operaciones de IO
y `Spawn.await` lo hacen implícitamente.
