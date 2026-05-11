# Capítulo 13 · Concurrencia y memoria

La concurrencia es donde la mayoría de los lenguajes acumulan
deuda. Threads con shared memory llevan a races que aparecen una
vez al mes y se arreglan tres veces; `async`/`await` introduce
colores de funciones; los actores corrigen lo anterior pero
históricamente vienen con GC y un runtime pesado.

kaikai apuesta por una combinación poco usual: **fibras
cooperativas + memoria por fibra + Perceus**. La estructura tiene
tres consecuencias que valen la pena nombrar antes de la
sintaxis:

- **No hay shared memory entre fibras.** Cada fibra tiene su
  propio heap. Lo que una pasa a otra se copia o se mueve.
  Adiós a las data races por construcción.
- **No hay GC ni borrow checker.** Perceus libera la memoria
  cuando el último uso de cada valor termina, sin un colector
  asincrónico y sin pedirle al programador que anote lifetimes.
  El compilador descubre dónde poner los `free`s analizando el
  programa.
- **La concurrencia es un efecto.** `spawn` es una operación de
  un efecto `Spawn`, no una palabra clave. Crear y esperar
  fibras se compone con el resto del sistema (`State`, `Fail`,
  `Cancel`) usando la maquinaria del cap. 12.

Vamos por partes.

## 13.1 El modelo: fibras aisladas

Una **fibra** es una unidad de ejecución parecida a un thread,
pero mucho más liviana: del orden de cientos de bytes en vez de
megabytes. Una aplicación kaikai puede tener miles o cientos de
miles de fibras vivas sin reventar.

Las fibras son **cooperativas**. Cada una corre hasta que llega a
un **punto de yield**: una llamada que voluntariamente le pasa el
control al scheduler. Los puntos de yield son explícitos:

- `fiber_yield()`: "ya pude correr un rato, prueba otra".
- `fiber_await(f)`: "espera a que termine la fibra `f`".
- Las operaciones de IO que el scheduler intercepta (lecturas de
  red, sleep, etc.).

Sin yield, una fibra corre hasta terminar. Eso es **determinismo
local**: dentro de un bloque sin yields, sabes exactamente qué
pasa. Comparado con threads preemptivas, esto te quita una clase
entera de bugs: no hay carrera sobre datos que toques entre dos
yields porque nadie te va a interrumpir.

A cambio, una fibra que nunca cede el control bloquea a todas las
demás. Es responsabilidad del programador poner yields donde haga
sentido. En la práctica, las llamadas a IO ya los traen, y el
único caso donde hay que pensar en yields manuales es en bucles
puros de CPU intenso.

### Memoria por fibra

Cada fibra tiene su **propio heap**. Cuando una fibra crea un
record, una lista, un closure, el espacio sale de ese heap. La
otra fibra no puede tocarlo: ni leerlo, ni escribirlo. El sistema
de tipos lo garantiza.

¿Cómo se comunican dos fibras entonces? Pasándose valores.
Cuando una fibra envía un mensaje a otra (vía mailbox de actor o
vía el resultado de un `await`), el valor se copia al heap de la
fibra receptora. Para tipos pequeños esto es trivial; para
estructuras grandes, kaikai usa Perceus para mover en vez de
copiar cuando el emisor ya no va a usar el valor.

Lo importante es la garantía: **no hay manera de que dos fibras
tengan un puntero al mismo objeto**. Las data races, los
problemas de visibility de memoria, los bugs de cache coherence:
todo lo que en threads tradicionales necesita lectura/escritura
con `Atomic` o locks no existe acá. La concurrencia es por
mensajes, no por memoria compartida.

## 13.2 Perceus en una página

¿Cómo se libera la memoria? Sin GC y sin borrow checker, hay un
tercer enfoque: **reference counting estricto basado en Perceus**
(Lorenz, Leijen, Reinking, 2021).

La idea es que el compilador analiza cada función para descubrir
en qué punto cada valor deja de ser usado. En ese punto inserta
una instrucción que decrementa el contador de referencias del
valor: si llega a cero, se libera; si no, se queda para otro uso.

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

¿El costo? Cuando un valor se usa varias veces, los contadores
se mueven. Para valores muy compartidos esto puede agregar
overhead, y Perceus tiene optimizaciones agresivas para
minimizarlo (reuse in place: si un valor está por liberarse y
se necesita uno del mismo shape inmediatamente después, se
reusa la misma memoria sin tocar el contador). En la práctica
el costo es bajo y predecible.

Por qué esto importa para concurrencia: Perceus funciona por
fibra. Cada fibra tiene sus propios contadores, sus propios
liberados. No hay sincronización entre fibras para ningún
contador: nunca dos fibras se pasan punteros al mismo valor
con contador compartido. Esa es la razón por la que el modelo
"fibras aisladas" cierra cuando se le agrega Perceus: el
mismo invariante que protege contra data races también
simplifica el RC.

## 13.3 Crear y esperar fibras: las operaciones básicas

La forma más simple de usar fibras es con `fiber_spawn` y
`fiber_await`:

```kai
import spawn

fn worker(tag: String, n: Int) : Unit / Stdout + Spawn {
  if n > 0 {
    println(tag)
    fiber_yield()
    worker(tag, n - 1)
  }
}

fn main() {
  let f = fiber_spawn(() => worker("B", 3))
  worker("A", 3)
  fiber_await(f)
}
```

Salida:

```
$ kai run ejemplos/cap13/01_dos_fibras.kai
A
B
A
B
A
B
```

Lectura literal:

- `import spawn` trae las operaciones de fibras.
- `fiber_spawn(() => worker("B", 3))` crea una fibra nueva que
  va a correr el lambda cuando el scheduler la elija.
- `worker("A", 3)` corre en la fibra actual (la del `main`).
- `fiber_yield()` dentro de `worker` cede el control. Cada
  vuelta, la otra fibra toma su turno.
- `fiber_await(f)` espera a que `f` termine antes de que `main`
  retorne.

`Spawn` aparece en la firma de `worker` porque la función llama
a `fiber_yield()`, que es una operación de `Spawn`. La fila
contagia hacia arriba como con cualquier efecto del cap. 12.

### Por qué los yields son explícitos

En lenguajes con threads preemptivas (Java, Go, Rust con
`std::thread`), el scheduler puede interrumpir un thread en
cualquier instrucción. Eso obliga a programar como si cualquier
línea pudiera ser interrumpida por otra fibra modificando
datos compartidos.

En kaikai, **una fibra sigue corriendo hasta que llega a un
punto de yield**. Entre yields, tienes determinismo local: si
modificas un valor local, nadie más lo va a tocar hasta que tú
cedas el control. Esto reduce mucho la carga cognitiva.

A cambio, tienes que **acordarte de poner los yields**. La regla
mental es: si tu función tiene un bucle largo de puro cómputo,
agrega un `fiber_yield()` cada cierto número de iteraciones.
Las funciones de IO ya yieldan por dentro.

## 13.4 Nurseries: concurrencia estructurada

`fiber_spawn` + `fiber_await` funciona, pero tiene un problema:
si te olvidas del `await`, la fibra se queda viva más allá del
scope donde la creaste. Y si esa fibra falla, te enteras tarde
o no te enteras.

Las **nurseries** atan las fibras a un scope léxico. Una fibra
solo puede vivir dentro de un nursery, y el nursery espera a
todas sus hijas antes de salir.

```kai
import spawn

fn worker(tag: String, n: Int) : Unit / Stdout + Spawn {
  if n > 0 {
    println(tag)
    fiber_yield()
    worker(tag, n - 1)
  }
}

fn main() : Unit / Stdout + Spawn + Cancel {
  nursery { n ->
    let a = n.spawn(() => worker("A", 3))
    let b = n.spawn(() => worker("B", 3))
    n.await(a)
    n.await(b)
  }
}
```

`nursery { n -> ... }` abre un scope. Adentro, `n` es la
capacidad para crear y esperar fibras:

- `n.spawn(f)` crea una fibra hija. Devuelve un `Fiber[T]`
  donde `T` es el tipo que `f` devuelve.
- `n.await(f)` espera a esa fibra y devuelve su valor.
- `n.select([a, b, ...])` espera a que cualquiera termine y
  cancela las demás.
- `n.cancel(f)` cancela una fibra específica.
- `n.cancel_all()` cancela todas las hijas.

Lo que el nursery garantiza:

- **Al salir del bloque, todas las hijas terminaron.** No hay
  fugas: una fibra no sobrevive al `nursery` que la creó.
- **Si una hija falla con un efecto no manejado, las demás se
  cancelan.** El nursery acumula la causa y la re-lanza.
- **Si el nursery se cancela desde afuera, propaga la
  cancelación a todas sus hijas.**

Esto se llama **concurrencia estructurada**. La idea es de
Nathaniel Smith en su ensayo *"Notes on structured concurrency,
or: Go statement considered harmful"* (2018), y aparece también
en Trio, Kotlin coroutines, Swift y OCaml 5 Eio. La forma de
kaikai integra el patrón en el sistema de efectos: la capacidad
`Spawn` solo está disponible dentro de un nursery, y eso es lo
que el sistema de tipos exige.

### Por qué `Cancel` aparece en la firma de `main`

Fíjate que `main` declara `/ Stdout + Spawn + Cancel`. ¿Por qué
`Cancel`? Porque cada `spawn`, `await` y `select` es un punto
de yield, y todo punto de yield puede recibir una
`Cancel.raise()` desde el scheduler (si alguien cancela el
nursery desde afuera, o si una fibra hermana falla). Toda
función que use `Spawn` carga implícitamente `Cancel`.

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
  fiber_yield()
  contar(tag, n + 1)
}
```

`trabajador_largo` cuenta indefinidamente. Si el nursery la
cancela, el handler de `Cancel` imprime el mensaje y la fibra
sale. No se queda colgada, no aborta el proceso.

La clave conceptual: `Cancel.raise()` es la **operación**, y
`handle ... with Cancel { ... }` es el handler. Mismo patrón
del cap. 12. La cancelación no es magia: es un efecto más, con
un handler escrito por el usuario o instalado por el runtime.

## 13.6 El efecto `Mutable`: estado local controlado

Hasta aquí dijimos que no hay mutación. Eso es exacto desde el
punto de vista del programador casi siempre: las funciones se
ven puras. Pero el lenguaje tiene un mecanismo para mutación
**localizada**, y vale la pena entenderlo porque permite
escribir cierto tipo de algoritmos sin pena.

```kai
fn contar_pares(xs: [Int]) : Int {
  var n = 0
  list.foreach(xs, (x) => {
    if x % 2 == 0 {
      n := @n + 1
    }
  })
  @n
}
```

Tres construcciones nuevas:

- **`var n = 0`** declara una celda mutable local.
- **`@n`** lee el valor actual de la celda.
- **`n := v`** escribe `v` en la celda.

¿No habíamos dicho que no había mutación? Sí, pero solo
visible. Por dentro, `var` usa el efecto `Mutable`, y cada
lectura/escritura es una operación. La firma de `contar_pares`
debería decir `Int / Mutable`.

Y sin embargo, no lo dice. Mira: la firma es solo `Int`. ¿Por
qué?

Porque el compilador hace **enmascaramiento por scope**: si la
celda mutable no escapa del bloque donde se declara (no se
pasa como argumento, no se devuelve, no se guarda en una
estructura externa), el efecto `Mutable` se elimina de la
firma. Para quien la llama, la función es pura. La mutación es un
detalle de implementación.

Es la misma idea de `State[T]` del cap. 12, pero más eficiente:
en vez de un handler que intercepta cada operación, el
compilador inserta lectura/escritura directa al stack frame.
Costo cero, pero solo para el patrón local.

### Cuándo `Mutable` se vuelve visible

Si la celda escapa, el enmascaramiento no aplica:

```kai
fn problema(xs: Array[Int]) : Unit / Mutable {
  xs[0] := 999      # modifica memoria que vive afuera
}
```

Aquí `xs` es un argumento, no se creó adentro. El efecto
`Mutable` aparece en la firma porque la mutación es visible
para quien llama. Esto es deliberado: si una función modifica
algo de afuera, quien llama lo sabe por el tipo. Las
"asignaciones secretas" no existen.

## 13.7 Por qué las fibras no pueden escapar de su nursery

Un detalle del sistema de tipos: **`Fiber[T]` no es un valor
movible**. No puedes devolverlo de una función, no puedes
guardarlo en un `Option` o un record, no puedes pasarlo a otra
fibra.

```kai
fn no_compila() : Fiber[Int] {       # ERROR
  nursery { n ->
    n.spawn(() => 42)                 # no se puede devolver
  }
}
```

¿Por qué? Porque una fibra solo tiene sentido dentro del
nursery que la creó. Si se permitiera devolverla, ¿quién la
esperaría? ¿Quién la cancelaría si el nursery termina? La
estructura se rompe.

Una lista de fibras dentro del mismo nursery es legal:

```kai
nursery { n ->
  let fibers = [1, 2, 3] | (x) => n.spawn(() => procesar(x))
  fibers | (f) => n.await(f)
}
```

Pero esa lista vive dentro del nursery. No puede salir.

Esto cierra el modelo: cada fibra tiene un padre conocido, cada
fibra termina antes de que su padre termine, y el sistema de
tipos lo garantiza al nivel sintáctico, no al nivel de
convención. **No hay manera de que una fibra se quede
huérfana.**

## 13.8 Caso de estudio: cola de tareas con pool de trabajadores

Cerramos con un patrón clásico: una cola de tareas servida por
un pool de fibras trabajadoras. Cada trabajador toma la
siguiente tarea, la procesa, y vuelve por otra. Cuando la cola
se vacía, todos terminan.

```kai
import spawn

effect State[T] {
  get() : T
  set(v: T) : Unit
}

fn siguiente() : Option[String] / State[[String]] {
  match State.get() {
    []           -> None
    [h, ...rest] -> {
      State.set(rest)
      Some(h)
    }
  }
}

fn worker(id: Int) : Unit / Stdout + Spawn + State[[String]] {
  match siguiente() {
    None       -> println("worker #{id}: cola vacía, salgo")
    Some(tarea) -> {
      println("worker #{id}: procesando '#{tarea}'")
      fiber_yield()
      worker(id)
    }
  }
}
```

Hasta aquí, código puro de efectos: tres operaciones (`get`,
`set`, `siguiente`), una recursión que termina cuando la cola
se acaba. No hay locks, no hay atomics, no hay `Arc<Mutex<...>>`.

El `main` instala los handlers y arranca el pool:

```kai
fn main() : Unit / Stdout + Spawn + Cancel {
  handle {
    nursery { n ->
      let a = n.spawn(() => worker(1))
      let b = n.spawn(() => worker(2))
      let c = n.spawn(() => worker(3))
      n.await(a)
      n.await(b)
      n.await(c)
    }
  } with State[[String]](["alpha", "bravo", "charlie", "delta", "echo", "foxtrot"]) {
    get(resume)    -> resume(state)
    set(v, resume) -> resume((), v)
    return(x)      -> x
  }
  println("(todas las tareas procesadas)")
}
```

Salida:

```
$ kai run ejemplos/cap13/07_eco_concurrente.kai
worker 1: procesando 'alpha'
worker 2: procesando 'bravo'
worker 3: procesando 'charlie'
worker 1: procesando 'delta'
worker 2: procesando 'echo'
worker 3: procesando 'foxtrot'
worker 1: cola vacía, salgo
worker 2: cola vacía, salgo
worker 3: cola vacía, salgo
(todas las tareas procesadas)
```

Tres fibras se reparten seis tareas en paralelo cooperativo.
Cada una accede a la "cola compartida" vía el efecto `State`,
pero por dentro no hay shared memory: el handler de `State`
vive en el `main`, y las operaciones de las fibras son
mensajes a ese handler. La cola es serializada por
construcción.

¿Y si quisieras paralelismo real? El modelo de fibras de
kaikai es cooperativo dentro de un proceso. Para usar varios
núcleos físicos, kaikai apunta a un modelo de **actores
independientes en threads separados** (cap. 14), donde cada
actor corre fibras cooperativas en su propio hilo, y los
actores se comunican por mailbox. Lo mejor de los dos mundos:
cooperación rápida adentro, paralelismo real afuera.

## 13.9 Filosofía: dos invariantes que cargan el modelo

Si quieres recordar dos cosas del capítulo, que sean estas:

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

A cambio, hay clases enteras de bugs que no tienes que pensar:

- No hay `volatile` ni `Atomic` ni memory ordering.
- No hay `lock` ni `mutex` ni `RwLock`.
- No hay borrow checker, ni `'a` lifetimes, ni `Rc<RefCell<T>>`.
- No hay `async fn` ni `Future` ni colores de funciones.
- No hay GC pause-the-world.

Es un trade-off: pierdes la libertad de tener punteros
arbitrarios entre fibras. Pero la ganancia (en seguridad, en
predictibilidad, en simplicidad mental) es lo que justifica
el modelo.

## Ejercicios

**13.1.** Modifica el ejemplo §13.3 (dos fibras cooperativas)
para que `worker("A")` haga 5 iteraciones y `worker("B")` haga
2. ¿Cómo cambia la salida? ¿Qué pasa si quitas los
`fiber_yield()` de uno solo de los dos workers?

**13.2.** Toma `contar_pares` de §13.6 y reescríbelo sin `var`,
usando `list.filter` y `list.length`. ¿Cuál versión te parece
más clara? ¿Cuál crees que es más eficiente y por qué?

**13.3.** Implementa una función `with_timeout[T](ms: Int, f: ()
-> T / Spawn) : Option[T] / Spawn + Cancel + Time`. Usa
`n.select` para correr `f` contra una fibra que hace
`Time.sleep(ms)` y devuelve `None`. Pista: necesitas un tipo
suma local para distinguir "completó" de "timeout".

**13.4.** En §13.8, el `State` es una cola FIFO sin
preferencias. Modifica el ejemplo para que algunas tareas
tengan prioridad alta y los workers las procesen primero.
Pista: el `State` puede ser un record con dos listas.

**13.5.** Una fibra que entra a un bucle infinito sin
`fiber_yield()` bloquea a todas las demás. Escribe ese código
y observa qué pasa. Después agrega yields cada N
iteraciones. ¿Cada cuántas? ¿Cómo decides el N?

**13.6.** En tu lenguaje habitual, busca un programa
concurrente que escribiste o que mantienes. Cuenta cuántas
líneas son "trabajo real" (la lógica del programa) versus
cuántas son "concurrencia plumbing" (mutex, queues, atomics,
async/await, callbacks). Estima qué porcentaje del código
quedaría con el modelo de kaikai.
