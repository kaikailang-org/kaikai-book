# Capítulo 13 · Concurrencia y memoria

La concurrencia es donde la mayoría de los lenguajes acumulan
deuda. Threads con shared memory llevan a races que aparecen una
vez al mes y se arreglan tres veces antes de irse de verdad;
`async`/`await` introduce colores de funciones; los actores
corrigen lo anterior pero históricamente vienen con GC y un
runtime pesado.

Frente a esas tres formas, kaikai apuesta por una combinación
poco usual: **fibras cooperativas + memoria por fibra +
Perceus**. Antes de la sintaxis, sus tres consecuencias:

- **No hay shared memory entre fibras.** Cada fibra tiene su
  propio heap. Lo que una pasa a otra se copia. Las data
  races desaparecen por construcción.
- **No hay GC ni borrow checker.** Perceus libera la memoria
  cuando termina el último uso de cada valor, sin un colector
  asincrónico y sin que anotes lifetimes. El compilador
  descubre dónde poner los `free`s.
- **La concurrencia es un efecto.** `spawn` es una operación de
  un efecto `Spawn`, no una palabra clave. Crear y esperar
  fibras se compone con el resto del sistema (`State`, `Cancel`,
  un `Fail` que declares tú) usando la maquinaria del cap. 12.

## 13.1 El modelo: fibras aisladas

Una **fibra** es una unidad de ejecución parecida a un thread,
pero mucho más liviana: cientos de bytes en vez de megabytes.
Una aplicación kaikai puede tener miles o cientos de miles de
fibras vivas sin reventar.

Las fibras son **cooperativas**. El runtime las reparte entre
varios hilos del sistema (§13.8), y en su hilo cada fibra corre
hasta llegar a un **punto de yield**: una llamada que le pasa
el control al scheduler. Nadie la interrumpe a la mitad. Los
puntos de yield son explícitos:

- `spawn.yield()`: "ya pude correr un rato, prueba otra".
- `spawn.await(f)`: "espera a que termine la fibra `f`".
- Las operaciones de IO que el scheduler intercepta (lecturas de
  red, sleep, etc.).

Sin yield, una fibra corre hasta terminar. Otras fibras pueden
estar corriendo al mismo tiempo en otros hilos, pero ninguna
alcanza tus datos, porque cada fibra tiene su propia memoria
(lo ves enseguida). Eso es **determinismo local**: dentro de
una fibra, sabes exactamente qué pasa con tus valores. Frente a
threads preemptivas con memoria compartida te ahorras una
clase entera de bugs: no hay carrera sobre los datos que tocas.

A cambio, una fibra que nunca cede el control acapara su hilo y
no se entera si la cancelan. Con un solo hilo
(`KAI_THREADS=1`, §13.8) bloquea a todas las demás. Poner
yields donde tenga sentido te toca a ti; en la
práctica las llamadas a IO ya los traen, y solo piensas en
yields manuales en bucles puros de CPU intenso.

### Memoria por fibra

Cada fibra tiene su **propio heap**. Cuando una fibra crea un
record, una lista o un closure, el espacio sale de ese heap, y
otra fibra no puede leerlo ni escribirlo. El sistema de tipos
lo garantiza.

Dos fibras se comunican pasándose valores. Cuando una envía un
mensaje a otra (vía mailbox de actor o vía el resultado de un
`await`), el valor se copia al heap de la receptora. Un `Int`
no cuesta nada; una lista grande cuesta en proporción a su
tamaño. Ese costo es lo que permite que el conteo de
referencias de Perceus (§13.2) no necesite instrucciones
atómicas, aunque emisora y receptora corran en hilos
distintos.

Lo importante es la garantía: **no hay manera de que dos fibras
tengan un puntero al mismo objeto**. Las data races, los
problemas de visibility de memoria, los bugs de cache coherence:
todo lo que en threads tradicionales necesita lectura/escritura
con `Atomic` o locks no existe aquí.

## 13.2 Perceus en una página

Sin GC ni borrow checker, la memoria se libera con un tercer
enfoque: **reference counting estricto basado en Perceus**
(Lorenz, Leijen, Reinking, 2021).

El compilador analiza cada función para descubrir en qué punto
cada valor deja de usarse, y ahí inserta una instrucción que
decrementa su contador de referencias: si llega a cero, se
libera; si no, queda para otro uso.

```kai
fn ejemplo(xs: [Int]) : Int {
  let n = list.length(xs)   # primer uso de xs
  let s = list.sum(xs)       # último uso de xs: aquí se "consume"
  s + n                      # xs ya no existe; n y s sí
}
```

A diferencia de un GC:

- **No hay pausa.** El liberado es síncrono, predecible, parte
  del código generado.
- **No hay overhead asincrónico.** El compilador conoce el
  ciclo de vida exacto de cada valor.
- **No hay hilo aparte.** El scheduler no compite con un
  colector.

A diferencia de un borrow checker:

- **No hay anotaciones de lifetime.** El programador no escribe
  `'a` ni `&` ni `mut`.
- **No hay limitaciones de pattern de uso.** Si necesitas dos
  referencias al mismo valor, el compilador inserta los
  increments y decrements necesarios.

El costo: cuando un valor se usa varias veces, los contadores
se mueven. Para valores muy compartidos esto puede agregar
overhead, y Perceus tiene optimizaciones agresivas para
minimizarlo (reuse in place: si un valor está por liberarse y
se necesita uno del mismo shape inmediatamente después, se
reusa la misma memoria sin tocar el contador). En la práctica
el costo es bajo y predecible.

Para el caso extremo, un cálculo que arma montañas de
estructura descartable solo para plegarla a un escalar,
existe un escape opt-in: el bloque `region`, que asigna en
una arena y la libera entera de un golpe, sin contadores de
por medio. Es parte del mismo catálogo de kinds que las
unidades del capítulo 10, y lo conoces en el capítulo 19.

Por qué esto importa para concurrencia: Perceus funciona por
fibra. Cada fibra tiene sus propios contadores y sus propios
liberados, y no hay sincronización entre fibras para ningún
contador, porque nunca dos fibras se pasan punteros al mismo
valor con contador compartido. Por eso el modelo de "fibras
aisladas" cierra con Perceus: el mismo invariante que protege
contra data races simplifica el RC.

## 13.3 Crear y esperar fibras: las operaciones básicas

La forma más simple de usar fibras es con `spawn.spawn` y
`spawn.await`:

```kai
import spawn

fn worker(tag: String, n: Int) : Unit / Stdout + Spawn {
  if n > 0 {
    println(tag)
    spawn.yield()
    worker(tag, n - 1)
  }
}

fn main() {
  let f = spawn.spawn(() => worker("B", 3))
  worker("A", 3)
  spawn.await(f)
}
```

Una salida posible:

<!-- transcripto: orden no determinista, como dice el texto -->
```
$ kai run ejemplos/cap13/01_dos_fibras.kai
A
B
A
B
A
B
```

**"Una salida posible" es literal.** Este programa no promete
ese orden. `A` y `B` son fibras independientes: nada en el
código dice que la primera `A` va antes que la primera `B`. El
runtime reparte las fibras entre tantos hilos del sistema como
núcleos tenga tu máquina, así que vas a ver órdenes distintos
entre corrida y corrida: `A A A B B B` es tan válido como el
intercalado de arriba.

Para obtener la salida perfectamente alternada:

```
$ KAI_THREADS=1 kai run ejemplos/cap13/01_dos_fibras.kai
A
B
A
B
A
B
```

`KAI_THREADS=1` fuerza al scheduler a un solo hilo, y ahí sí
`spawn.yield()` es lo único que decide de quién es el turno.
Usa ese modo para leer los ejemplos del capítulo cuando el
punto sea *ver* la alternancia. Lo retomas en §13.8; por ahora
quédate con que la alternancia es una propiedad del scheduler
de un hilo, no una garantía del lenguaje.

Lectura literal:

- `import spawn` trae las operaciones de fibras.
- `spawn.spawn(() => worker("B", 3))` crea una fibra nueva que
  va a correr el lambda cuando el scheduler la elija.
- `worker("A", 3)` corre en la fibra actual (la del `main`).
- `spawn.yield()` dentro de `worker` cede el control: la fibra
  declara un punto donde puede perder el turno.
- `spawn.await(f)` espera a que `f` termine antes de que `main`
  retorne.

`Spawn` aparece en la firma de `worker` porque la función llama
a `spawn.yield()`, una operación de `Spawn`. La fila contagia
hacia arriba como cualquier efecto del cap. 12.

### Por qué los yields son explícitos

En lenguajes con threads preemptivas (Java, Go, Rust con
`std::thread`), el scheduler puede interrumpir un thread en
cualquier instrucción, y eso te obliga a programar como si
cualquier línea pudiera ser interrumpida por otra fibra que
modifica datos compartidos.

En kaikai, **una fibra sigue corriendo hasta que llega a un
punto de yield**. Entre yields tienes determinismo local:
ninguna otra fibra corre en tu hilo, y las que corren en otros
hilos no tienen cómo alcanzar tus valores. Esto reduce mucho
la carga cognitiva.

A cambio, tienes que **acordarte de poner los yields**. La regla
mental: si tu función tiene un bucle largo de puro cómputo,
agrega un `spawn.yield()` cada cierto número de iteraciones.
Las funciones de IO ya yieldan por dentro.

## 13.4 Nurseries: concurrencia estructurada

`spawn.spawn` + `spawn.await` funciona, pero si te olvidas del
`await`, la fibra sigue viva más allá del scope donde la
creaste. Y si esa fibra falla, te enteras tarde o no te
enteras.

Las **nurseries** atan las fibras a un scope léxico. Una fibra
solo puede vivir dentro de un nursery, y el nursery espera a
todas sus hijas antes de salir.

```kai
# ejemplos/cap13/02_nursery.kai
import spawn

fn worker(tag: String, n: Int) : Unit / Stdout + Spawn {
  if n > 0 {
    println(tag)
    spawn.yield()
    worker(tag, n - 1)
  }
}

fn main() : Unit / Stdout + Spawn + Cancel {
  nursery { n ->
    n.spawn(() => worker("A", 3)) |> ignore
    n.spawn(() => worker("B", 3)) |> ignore
  }
}
```

Una salida posible:

<!-- transcripto: orden no determinista, como dice el texto -->
```
$ kai run ejemplos/cap13/02_nursery.kai
A
A
A
B
B
B
```

`nursery { n -> ... }` abre un scope. Adentro, `n` es la
capacidad para crear fibras:

- `n.spawn(f)` crea una fibra hija. Devuelve un `Fiber[T]`
  donde `T` es el tipo que `f` devuelve. Aquí no lo necesitas,
  porque el nursery espera a las fibras de todos modos, y
  `|> ignore` dice que lo descartas a propósito.
- `n.await(f)` espera a esa fibra y devuelve su valor. Solo lo
  necesitas cuando quieres el resultado.
- `n.select([a, b, ...])` espera a que cualquiera termine y
  cancela las demás.
- `n.cancel(f)` cancela una fibra específica.
- `n.cancel_all()` cancela todas las hijas.

Lo que el nursery garantiza:

- **Al salir del bloque, todas las hijas terminaron.** El
  nursery hace *join* automático de cada hija al cerrar la
  llave, sin que pidas un `await`. No hay fugas: ninguna fibra
  sobrevive al `nursery` que la creó.
- **Si una hija falla por su cuenta, las demás se cancelan.**
  Cuando una hija lanza `Cancel` sin que nadie se lo haya
  pedido (un crash), el nursery cancela a las hermanas que
  siguen vivas y re-lanza la causa fuera del scope. En cambio,
  una hija que cancelas a pedido con `n.cancel` termina como
  resultado esperado y no contagia a las demás.
- **Si el nursery se cancela desde afuera, propaga la
  cancelación a todas sus hijas.**

![Figura 13.1](../figuras/fig13-1-nursery-es.png)

Figura 13.1 · *Concurrencia estructurada en una imagen. El
nursery es un ámbito léxico; las fibras hijas viven adentro;
nada se escapa. Si una hija falla, el nursery cancela al
resto antes de re-lanzar; si al padre lo cancelan desde
afuera, la cascada baja.*

Esto se llama **concurrencia estructurada**. La idea es de
Nathaniel Smith en su ensayo *"Notes on structured concurrency,
or: Go statement considered harmful"* (2018), y aparece también
en Trio, Kotlin coroutines, Swift y OCaml 5 Eio. kaikai integra
el patrón en el sistema de efectos: la capacidad `Spawn` solo
está disponible dentro de un nursery, y el sistema de tipos lo
exige.

`n.select` es la primitiva de carrera: el nursery devuelve el
valor de la primera hija que termina y cancela a la otra sin
que lo pidas.

```kai
# ejemplos/cap13/04_race.kai
import spawn

fn rapido() : Int / Stdout + Spawn {
  println("rapido: empieza")
  spawn.yield()
  println("rapido: termina")
  1
}

fn lento() : Int / Stdout + Spawn {
  println("lento: empieza")
  spawn.yield()
  spawn.yield()
  spawn.yield()
  println("lento: termina")
  2
}

fn main() : Unit / Stdout + Spawn + Cancel {
  let ganador = nursery { n ->
    let a = n.spawn(() => rapido())
    let b = n.spawn(() => lento())
    n.select([a, b])
  }
  println("ganó: #{ganador}")
}
```

Una salida posible:

<!-- transcripto: orden no determinista, como dice el texto -->
```
$ kai run ejemplos/cap13/04_race.kai
rapido: empieza
lento: empieza
lento: termina
rapido: termina
ganó: 1
```

### Por qué `Cancel` aparece en la firma de `main`

`main` declara `/ Stdout + Spawn + Cancel` porque cada `spawn`,
`await` y `select` es un punto de yield, y todo punto de yield
puede recibir una `Cancel.raise()` desde el scheduler (si
alguien cancela el nursery desde afuera, o si una fibra
hermana falla). Toda función que use `Spawn` carga
implícitamente `Cancel`.

### `nursery` es azúcar sobre un `handle`

`nursery { n -> ... }` parece una palabra clave del lenguaje,
pero no lo es. Las fibras son **un efecto** llamado `Spawn`,
declarado así en el stdlib:

```kai
effect Spawn {
  spawn[T, e](f: () -> T / e) : Fiber[T]
  await[T](f: Fiber[T])       : T
  select[T](fs: [Fiber[T]])   : T
  yield()                     : Unit
  cancel[T](f: Fiber[T])      : Unit
}
```

Es un efecto ordinario, declarado igual que `Log` o `State[T]`
del cap. 12. Y `nursery { n -> body }` se reescribe en tiempo
de compilación a `handle { body } with Spawn as n { ... }`,
con un handler interno que gestiona el árbol de fibras hijas,
espera a las pendientes al salir y propaga fallos.

El lenguaje core, entonces, **no tiene primitivas de
concurrencia**: tiene efectos. Las fibras, los nurseries y la
cancelación son una biblioteca sobre dos efectos del stdlib
(`Spawn` y `Cancel`). En el cap. 14 los actores repiten el
patrón (efecto `Actor[Msg]`): lo distintivo de kaikai es que
**todas sus construcciones son la misma** (efectos
algebraicos) con nombres distintos.

Para quedarte con los resultados en vez de solo esperarlos,
un `await` por hija:

```kai
# ejemplos/cap13/05_worker_pool.kai
import spawn

fn procesar(id: Int, x: Int) : Int / Stdout + Spawn {
  println("worker #{id}: procesando #{x}")
  spawn.yield()
  spawn.yield()
  let r = x * x
  println("worker #{id}: listo #{x} -> #{r}")
  r
}

fn main() : Unit / Stdout + Spawn + Cancel {
  let resultados = nursery { n ->
    let a = n.spawn(() => procesar(1, 3))
    let b = n.spawn(() => procesar(2, 5))
    let c = n.spawn(() => procesar(3, 7))
    [n.await(a), n.await(b), n.await(c)]
  }
  println("resultados: #{resultados}")
}
```

Una salida posible:

<!-- transcripto: orden no determinista, como dice el texto -->
```
$ kai run ejemplos/cap13/05_worker_pool.kai
worker 1: procesando 3
worker 2: procesando 5
worker 2: listo 5 -> 25
worker 1: listo 3 -> 9
worker 3: procesando 7
worker 3: listo 7 -> 49
resultados: [9, 25, 49]
```

## 13.5 Cancelación cooperativa

La cancelación en kaikai es **cooperativa**: el scheduler no
mata a una fibra de golpe. Le entrega una `Cancel.raise()` en
el próximo punto de yield. La fibra puede:

- **Desenrollarse limpiamente.** Si no maneja `Cancel`, el
  unwinding la saca de cualquier `handle`, `nursery`, etc., y
  los handlers de cancelación por encima toman el control.
- **Manejar `Cancel` para hacer cleanup.** La fibra instala un
  handler de `Cancel` que corre el cleanup (cerrar archivos,
  soltar conexiones) y NO llama a `resume`, dejando que el
  unwinding continúe.

```kai
fn trabajador_largo(tag: String) : Unit / Stdout + Spawn + Cancel {
  handle {
    contar(tag, 0)
  } with Cancel {
    raise(resume) -> {
      println("#{tag}: cancelado, hago cleanup")
      # no llamamos a resume: la fibra se desenrolla
    }
  }
}

fn contar(tag: String, n: Int) : Unit / Stdout + Spawn + Cancel {
  println("#{tag}: #{n}")
  spawn.yield()
  contar(tag, n + 1)
}
```

`trabajador_largo` cuenta indefinidamente. Si el nursery la
cancela, el handler de `Cancel` imprime el mensaje y la fibra
sale, sin quedarse colgada ni abortar el proceso.

La clave conceptual: `Cancel.raise()` es la **operación**, y
`handle ... with Cancel { ... }` es el handler. Mismo patrón
del cap. 12: la cancelación es un efecto más, con un handler
que escribes tú o que instala el runtime.

### `Spawn.cancel(f)` y los handlers de `Cancel`

Dos nombres parecidos que conviene separar:

- **El efecto `Cancel`** es lo que la fibra **recibe** cuando
  la cancelación le llega. Su única op `raise()` la inyecta
  el scheduler en el próximo punto de yield.
- **`Spawn.cancel(f)`** es lo que una fibra **llama** para
  pedirle al scheduler que entregue `Cancel.raise()` a la
  fibra `f`.

Cuando llamas `n.spawn(...)` con un binding `n` y obtienes una
fibra hija, `Spawn.cancel(hija)` no la mata: agenda la entrega.
La hija, en su próximo yield, recibe `Cancel.raise()` y corre
su propio handler de `Cancel`, el que instaló con
`with Cancel { ... }`. Si no instaló ninguno, se desenrolla
limpiamente y los handlers más arriba en la pila (típicamente
del nursery) toman el control.

La única excepción es el **trap-exit** del modelo de actores
(cap. 14): una fibra puede marcarse para que los crashes de
sus pares le lleguen como mensajes a su mailbox en vez de
gatillar cancelación. Es una opción explícita y local; por
omisión rige la cancelación cooperativa descrita aquí.

Una hija que se rinde por su cuenta, las hermanas que reciben
la cancelación, el cleanup de cada una y la caída que el
nursery re-lanza al salir:

```kai
# ejemplos/cap13/03_cancel.kai
import spawn

# Una fibra que cuenta mientras nadie la cancela.
fn trabajador_largo(tag: String) : Unit / Stdout + Spawn + Cancel {
  handle {
    contar(tag, 0)
  } with Cancel {
    raise(resume) -> {
      println("#{tag}: cancelado, hago cleanup")
      # no llamamos a resume: la fibra se desenrolla
    }
  }
}

fn contar(tag: String, n: Int) : Unit / Stdout + Spawn + Cancel {
  println("#{tag}: #{n}")
  spawn.yield()
  contar(tag, n + 1)
}

# Una fibra que se rinde después de unos pasos.
fn renunciar(n: Int) : Unit / Stdout + Spawn + Fail {
  if n > 2 {
    Fail.fail("renuncio después de 3 pasos")
  } else {
    println("paso #{n}")
    spawn.yield()
    renunciar(n + 1)
  }
}

effect Fail {
  fail(motivo: String) : Nothing
}

fn main() : Unit / Stdout + Spawn + Cancel {
  nursery { n ->
    n.spawn(() => trabajador_largo("A")) |> ignore
    n.spawn(() => trabajador_largo("B")) |> ignore
    let r = n.spawn(
      () => handle {
        renunciar(0)
      } with Fail {
        fail(motivo, resume) -> {
          println("la fibra se rinde: #{motivo}")
          Cancel.raise()
        }
      }
    )
    n.await(r)
  }
}
```

Una salida posible:

<!-- transcripto: orden no determinista, como dice el texto -->
```
$ kai run ejemplos/cap13/03_cancel.kai
A: 0
A: 1
B: 0
A: 2
A: 3
A: 4
B: 1
B: 2
B: 3
A: 5
paso 0
paso 1
B: 4
paso 2
A: 6
A: 7
A: 8
A: 9
B: 5
A: 10
la fibra se rinde: renuncio después de 3 pasos
A: 11
A: 12
A: cancelado, hago cleanup
B: 6
B: cancelado, hago cleanup
kai: nursery child cancelled; no survivors
```

## 13.6 Memoria mutable por fibra

En el cap. 12 §12.7 conociste `var` (celdas locales, azúcar
sobre `State[T]`) y el efecto `Mutable` (que rige a `Ref[T]` y
`Array[T]` cuando la mutación es observable). Todo eso funciona
igual que en código secuencial, con una sola adición del modelo
de fibras: **la memoria mutable vive en el heap de la fibra que
la creó**.

Cuando una fibra crea un `Array[T]` o un `Ref[T]`, el espacio
sale de su propio heap y ninguna otra fibra tiene cómo
acceder a él: no hay punteros compartidos ni paso por
referencia entre fibras. Para darle un valor mutable a otra
fibra, lo mandas por mailbox (cap. 14) y el runtime copia el
contenido al heap del receptor.

La regla se chequea en el borde del `spawn`, no cuando el
programa corre. Si el thunk que le pasas a `n.spawn` arrastra
`Mutable` en su fila de efectos, el compilador lo rechaza ahí
mismo:

```kai
fn tocar(a: Array[Int]) : Unit / Mutable {
  a[0] := 42
}

nursery { n ->
  n.spawn(() => tocar(a)) |> ignore   # ERROR
}
```

```
error: a spawned fiber cannot mutate state it did not create: `Mutable` in its effect row
  = note: the spawned fiber gets a copy of what it captures, so a write is lost to the parent
  = help: let one fiber own the state and send it the updates as messages (`kai info actors`)
```

La nota es el punto completo: la hija escribiría sobre su
propia copia y el padre nunca vería el cambio. El compilador
prefiere no dejarte escribir código que parece compartir
estado y no lo comparte. El camino es el que dice la ayuda:
una fibra dueña del estado, y las demás le mandan mensajes.
El cap. 14 lo arma con actores.

Por eso la mutación no introduce data races en kaikai. Con
threads y memoria compartida, un `Array[T]` mutable necesita
locks o atomics para tocarse desde varios hilos. En kaikai, el
sistema de tipos garantiza que ningún `Array[T]` está siendo
modificado por dos fibras al mismo tiempo, porque ningún
`Array[T]` es accesible desde dos fibras al mismo tiempo. La
aislación de memoria del §13.1 cubre también las celdas
mutables.

## 13.7 Por qué las fibras no pueden escapar de su nursery

Un detalle del sistema de tipos: **`Fiber[T]` es un handle
atado a su nursery**. Ninguna función puede devolverlo, ni solo
ni envuelto: el compilador rechaza `Fiber[T]` en cualquier
parte del tipo de retorno, sea `Option[Fiber[Int]]`,
`[Fiber[Int]]` o el payload de un tipo suma.

```kai
fn no_compila() : Fiber[Int] {       # ERROR
  nursery { n ->
    n.spawn(() => 42)                 # no se puede devolver
  }
}
```

Una fibra solo tiene sentido dentro del nursery que la creó.
Si pudieras devolverla, ¿quién la esperaría? ¿Quién la
cancelaría al terminar el nursery? La estructura se rompe.

Dentro del nursery, en cambio, puedes guardar un `Fiber[T]` en
una lista, un `Option` o un record, o capturarlo en la clausura
de una fibra hermana que lo espere. Una lista de fibras es el
caso típico:

```kai
nursery { n ->
  let fibers = [1, 2, 3] | (x) => n.spawn(() => procesar(x))
  fibers | (f) => n.await(f)
}
```

Esa lista vive dentro del nursery y no puede salir.

Esto cierra el modelo: cada fibra tiene un padre conocido y
termina antes que él, y el sistema de tipos lo garantiza a
nivel sintáctico, no por convención. **No hay manera de que
una fibra se quede huérfana.**

## 13.8 Caso de estudio: repartir trabajo entre fibras

Cerramos con un patrón que vas a escribir muchas veces:
repartir una lista de tareas entre varias fibras trabajadoras
y juntar los resultados al final.

Antes del código, una restricción que decide la forma de la
solución: **los handlers de efectos son locales a la fibra**. Si instalas un handler de
`State` en el `main` y una fibra hija ejecuta `State.get()`,
el programa ni siquiera compila:

```
error: effect not handled in spawned fiber: State
  --> main.kai:6:23
    |
  6 |       let f = n.spawn(() => State.get())
    |                       ^
  = note: a fiber does not inherit the parent's handlers
  = help: handle the effect inside the spawned body: `handle { ... } with State { ... }`
```

Es el mismo invariante de aislación que sostiene todo el
capítulo: una capacidad es parte del contexto de una fibra, y
una fibra no hereda el contexto de quien la creó. A través de
un `spawn` pasas los valores que capturas en el lambda, de ida,
y el valor de retorno que recoge `await`, de vuelta. Las capacidades
que sí resuelven dentro de una hija son de dos clases, y
ninguna es tuya: las que el runtime provee por fibra (`Stdout`,
`Clock`) y las que son de la fibra por construcción (`Cancel`,
`Spawn`, `Actor`).

El compilador lo ataja en la línea del `spawn`, donde está el
error, en vez de dejarlo reventar en runtime cuando la fibra
llega a la operación.

Así que la "cola compartida" que escribirías en Go con un
canal, o en Java con un `BlockingQueue`, aquí no se escribe
así. Repartes el trabajo por adelantado y cada fibra devuelve
lo suyo:

```kai
import spawn
import core.list

fn procesar_lote(id: Int, lote: [String]) : [String] / Spawn =
  lote
    | (t => {
      spawn.yield()
      "worker #{id}: #{t}"
    })
```

`procesar_lote` no sabe que existen otras fibras: recibe su
lote, lo recorre y arma la lista de salida. El `spawn.yield()`
está para que las trabajadoras se turnen; no cambia el
resultado, solo lo hace concurrente de verdad.

El `main` reparte, espera y concatena:

```kai
fn main() : Unit / Stdout + Spawn + Cancel {
  let resultados = nursery { n ->
    let a = n.spawn(() => procesar_lote(1, ["alpha", "bravo"]))
    let b = n.spawn(() => procesar_lote(2, ["charlie", "delta"]))
    let c = n.spawn(() => procesar_lote(3, ["echo", "foxtrot"]))
    n.await(a) ++ n.await(b) ++ n.await(c)
  }
  resultados |! println(.)
  println("(#{list.length(resultados)} tareas procesadas)")
}
```

Salida:

```
$ kai run ejemplos/cap13/06_reparto_de_lotes.kai
worker 1: alpha
worker 1: bravo
worker 2: charlie
worker 2: delta
worker 3: echo
worker 3: foxtrot
(6 tareas procesadas)
```

Esta vez la salida **sí** está garantizada. Las fibras corren
como quieran y en los núcleos que haya, pero ninguna imprime:
solo devuelven listas, y el `main` las concatena en el orden
que eligió al escribir `n.await(a) ++ n.await(b) ++
n.await(c)`; recién ahí imprime. El orden de la salida es
consecuencia del código, no del scheduler.

Esa es una regla de diseño que vale más que el ejemplo: **si
te importa el orden, ordénalo tú en el punto de reunión, no
confíes en el de ejecución.**

¿Y si el trabajo no se puede repartir por adelantado, si las
tareas llegan de a poco, o son de duración muy dispareja y
quieres que la fibra que se desocupa tome la siguiente? Ahí sí
necesitas algo que posea la cola y responda pedidos. Ese algo
es un actor, y es el capítulo 14.

### Concurrencia y paralelismo

Dos palabras que se confunden seguido:

**Concurrencia** es una propiedad de tu programa: tener varias
líneas de trabajo vivas a la vez, que progresan de manera
independiente. **Paralelismo** es una propiedad de la máquina:
que dos de esas líneas ejecuten instrucciones en el mismo
instante, en núcleos distintos.

kaikai te da las dos. Las fibras, cooperativas y atadas a un
nursery, son el mecanismo de concurrencia, y el runtime las
reparte por omisión sobre tantos hilos del sistema como núcleos
tenga la máquina, con un scheduler M:N que roba trabajo entre
hilos. No pides ni configuras nada: el programa que escribiste
en §13.3 ya usa tus dieciséis núcleos si los tienes.

Lo que **no** cambia con el número de hilos es la semántica:

- Cada fibra sigue teniendo su propia memoria. Un mensaje que
  cruza de un hilo a otro se copia, así que el conteo de
  referencias de Perceus sigue sin necesitar atómicos.
- Las fibras siguen siendo cooperativas: ninguna es
  interrumpida a media instrucción. Entre dos yields, una
  fibra tiene determinismo local.
- Nurseries, cancelación y `await` se comportan igual con uno
  o con treinta y dos hilos.

Lo que sí cambia es lo que ya viste: **el orden en que se
intercalan fibras independientes deja de ser predecible**. Con
un hilo, `spawn.yield()` decide los turnos y la salida es
reproducible; con varios, no. Para eso está `KAI_THREADS=1`:
fuerza el scheduler cooperativo de un solo hilo. Es la
herramienta para depurar una carrera, para un test que compara
salida literal o para leer un ejemplo pedagógico como los de
este capítulo.

```sh
$ ./programa                  # tantos hilos como núcleos
$ KAI_THREADS=4 ./programa    # cuatro, ni más ni menos
$ KAI_THREADS=1 ./programa    # cooperativo, reproducible
```

La pregunta útil es si te va a servir. Si tu programa está
limitado por IO (esperar red, leer archivos, recibir
mensajes), las fibras te pagan incluso con un hilo, porque
mientras una espera bytes las otras corren. Si está limitado
por CPU, además de estructura te dan velocidad, siempre que el
trabajo se pueda partir en pedazos que no dependan uno del
otro. El ejemplo de esta sección tiene exactamente esa forma.

## 13.9 Filosofía: dos invariantes que vale recordar

Del capítulo, quédate con dos cosas:

1. **Cada fibra tiene su propio heap.** No hay shared memory
   entre fibras. La comunicación es por mensajes (mailbox de
   actor, resultado de `await`). Las data races no existen por
   construcción, no por disciplina.

2. **Cada fibra tiene una vida atada a un scope léxico.** No
   puede escapar del `nursery` que la creó; el sistema de
   tipos rechaza cualquier intento. Si el padre termina, todas
   las hijas terminaron. Si una hija falla, las hermanas se
   cancelan.

Estos dos invariantes se sostienen mutuamente. La aislación de
memoria es lo que permite que Perceus funcione por fibra sin
sincronización. La estructura léxica es lo que permite
liberar la memoria predeciblemente al final del scope.
Cualquier modelo que rompa uno de los dos rompe el otro.

A cambio, dejas de pensar en clases enteras de bugs:

- No hay `volatile` ni `Atomic` ni memory ordering.
- No hay `lock` ni `mutex` ni `RwLock`.
- No hay borrow checker, ni `'a` lifetimes, ni `Rc<RefCell<T>>`.
- No hay `async fn` ni `Future` ni colores de funciones.
- No hay GC pause-the-world.

Es un trade-off: pierdes la libertad de tener punteros
arbitrarios entre fibras. Lo que ganas en seguridad y en
simplicidad mental justifica el modelo.

## Ejercicios

**13.1.** Modifica el ejemplo §13.3 (dos fibras cooperativas)
para que `worker("A")` haga 5 iteraciones y `worker("B")` haga
2. ¿Cómo cambia la salida? ¿Qué pasa si quitas los
`spawn.yield()` de uno solo de los dos workers?

**13.2.** Una fibra crea un `Array[Int]` localmente y lo
modifica con `a[i] := v`. Después termina sin pasarlo a nadie.
¿Por qué este programa no introduce data races aunque otra fibra
esté corriendo concurrentemente? Da el argumento en dos líneas,
en términos del modelo de memoria por fibra de §13.1.

**13.3.** Implementa una función `with_timeout[T](ms: Int, f: ()
-> T / Spawn) : Option[T] / Spawn + Cancel + Time`. Usa
`n.select` para correr `f` contra una fibra que hace
`Time.sleep(ms)` y devuelve `None`. Pista: necesitas un tipo
suma local para distinguir "completó" de "timeout".

**13.4.** El §13.8 reparte los lotes de antemano y en partes
iguales. Modifícalo para que los lotes tengan tamaños muy
dispares (uno con diez tareas, dos con una) y mide cuánto
tarda el conjunto. Después reparte las once tareas en tres
lotes parejos y vuelve a medir. ¿Por qué el reparto estático
deja núcleos ociosos, y qué necesitarías para evitarlo?

**13.5.** Una fibra que entra a un bucle infinito sin
`spawn.yield()` no cede su turno. Escribe ese código y observa
qué pasa: primero con `KAI_THREADS=1`, después sin la
variable. ¿Por qué el síntoma cambia? Agrega yields cada N
iteraciones. ¿Cada cuántas? ¿Cómo decides el N?

**13.6.** En tu lenguaje habitual, busca un programa
concurrente que escribiste o que mantienes. Cuenta cuántas
líneas son "trabajo real" (la lógica del programa) versus
cuántas son "concurrencia plumbing" (mutex, queues, atomics,
async/await, callbacks). Estima qué porcentaje del código
quedaría con el modelo de kaikai.
