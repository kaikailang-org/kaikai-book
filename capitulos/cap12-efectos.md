# Capítulo 12 · Efectos algebraicos

Este es el capítulo donde kaikai paga su novedad. Hasta ahora
hemos visto tipos, pattern matching, protocolos, unidades de
medida, contratos. Todas son piezas elegantes pero no únicas: las
encontrarías parecidas en Haskell, en Rust, en F#. Los **efectos
algebraicos** son lo que distingue a kaikai de casi cualquier
lenguaje de uso real hoy.

También son la razón por la que este proyecto existe, como
conté en el prólogo.

La idea es simple de enunciar y rara al principio: **una función
declara en su firma qué efectos usa, pero no cómo se realizan**.
Imprimir a pantalla, leer un archivo, fallar con un error,
suspender la ejecución, generar un número aleatorio: todos son
efectos. La función dice "yo necesito esta capacidad"; otro código
más arriba decide qué significa "esta capacidad" en este contexto.
La separación entre **qué** y **cómo** es el corazón del sistema.

Si esto suena a *dependency injection*, mantén la idea cerca. Si
suena a excepciones, también. Si suena a generadores, igualmente.
La razón por la que un solo mecanismo se parece a tantas cosas es
que en la teoría detrás, todas esas cosas son lo mismo. Los
efectos algebraicos son la generalización.

Vamos despacio. Este capítulo se lee mejor con paciencia que con
prisa: la primera lectura es para que cada idea aparezca; la
intuición sólida llega cuando vuelvas un mes después y todo se
sienta obvio.

## 12.1 La fricción que los efectos resuelven

Antes de mostrar la sintaxis, veamos los problemas concretos que
los efectos resuelven. Si reconoces el patrón en tu trabajo,
sabrás por qué pagar el costo de aprender una herramienta nueva.

### Excepciones invisibles

En Java o Python, cualquier llamada a una función puede lanzar una
excepción y nada en la firma te lo dice. Lees el código y no sabes
qué puede fallar. Lo descubres en producción.

```python
def cargar_usuario(id):
    return db.get(id)   # ¿puede fallar? ¿con qué excepciones?
```

Lenguajes con excepciones verificadas (Java) intentaron arreglarlo
forzándote a declarar `throws`. El resultado fue que la gente
escribió `throws Exception` para callarlo, y volvimos al inicio.
Lenguajes funcionales modernos (Rust, OCaml, kaikai con el cap. 5)
empujan a usar `Result` o `Option`: el costo de fallar aparece en
el tipo, y quien llama decide qué hacer. Bien para fallas locales,
pero pesado cuando hay muchas funciones que fallan: la firma se
llena de wrapping y unwrapping.

### `async`/`await` que infecta

En JavaScript, Python, C#, Rust, marcar una función como `async`
te obliga a marcar como `async` también a todas las que la llaman.
Un cambio aparentemente local contagia el árbol entero de llamadas.

```js
async function leer(path) { ... }
async function procesar(path) {
  const data = await leer(path);   // procesar también tuvo que ser async
  return transformar(data);
}
```

Bob Nystrom le puso nombre a esto en 2015 en un ensayo famoso:
**"What Color is Your Function?"**. La idea es que `async` divide
las funciones en dos colores: las rojas (`async`) y las azules
(no-async). Una roja puede llamar a una azul, pero una azul no
puede llamar a una roja. Si tienes una función azul y necesitas
usar una roja adentro, tienes que repintar la azul, y la que la
llamaba, y así hasta arriba. Es una infección que no se queda
local.

El punto del ensayo no es que `async` sea malo, sino que esta
clase de marcadores en la firma, cuando son específicos a un solo tipo
de efecto, crean dos sistemas paralelos que no componen. `async`
no compone con generadores: necesitas `async function*`. No
compone con excepciones de la misma manera (las excepciones en
funciones async se vuelven rejected promises). Cada combinación
nueva requiere su propia sintaxis.

Los efectos algebraicos resuelven el problema al nivel de raíz:
**no hay colores especiales**, hay una sola dimensión que es la
fila de efectos. `async` no necesita ser una propiedad sintáctica
de la función; es simplemente un efecto entre otros. Y la fila se
extiende sin sintaxis nueva: `/ Async + Fail` no es más raro que
`/ Async`.

### Inyección de dependencias

Para hacer una función testeable, le pasas como parámetro las
"cosas externas" que usa: el reloj, el logger, el acceso a base de
datos. Le pasas mocks en los tests, las cosas reales en producción.

```java
class Procesador {
  public Procesador(Clock clock, Logger logger, DbClient db) { ... }
  public void run() { ... }
}
```

Funciona, pero ensucia las firmas y obliga a wiring manual. Y
cuando una función nueva quiere usar uno de los servicios, hay que
agregarlo a constructores arriba en la jerarquía.

### El patrón común

Las tres frustraciones tienen la misma forma:

- Una función necesita una **capacidad** (la capacidad de fallar,
  la capacidad de suspenderse, la capacidad de loggear).
- La capacidad debe ser **explícita** (visible en el tipo) para no
  sorprender.
- La capacidad debe ser **provista por el contexto** (quien llama, test,
  framework) sin que la función se entere.
- Múltiples capacidades deben **componerse limpio**.

Los efectos algebraicos son **una sola construcción** que cubre
los cuatro puntos. Lo que las excepciones, `async`/`await` y la
inyección de dependencias hacen por separado y con frecuencia mal,
los efectos lo hacen con un solo mecanismo.

## 12.2 Declarar un `effect`

Un efecto es una **interfaz**. Declara qué operaciones existen,
con qué firma, pero no cómo se implementan.

```kai
effect Log {
  log(msg: String) : Unit
}
```

Esto introduce un efecto llamado `Log` con una operación `log` que
recibe un string y no devuelve nada útil. Cualquier función que
llame a `Log.log(...)` está usando el efecto `Log`.

Lo que **no** introduce: implementación. Aquí no hay cuerpo, no
hay `if`, no hay print. Solo la firma. Esa es la diferencia
fundamental con un protocolo o una interfaz tradicional: el efecto
no decide nada, solo declara lo que se puede pedir.

Las operaciones de un efecto se declaran sin la palabra `fn` y sin
cuerpo: solo nombre, parámetros y tipo de retorno. Un mismo efecto
puede tener varias operaciones:

```kai
effect Io {
  print(s: String) : Unit
  read_line()      : String
}
```

## 12.3 Llamar a una operación: la firma cambia

Para usar una operación, llamas al método del efecto:

```kai
fn greet(name: String) : Unit / Log {
  Log.log("hola, " ++ name)
}
```

Dos cosas nuevas:

- **`Log.log(...)`** es la sintaxis de invocación. El efecto es el
  nombre del namespace; la operación es el método.
- **`: Unit / Log`** en la firma. La barra introduce la **fila de
  efectos** (effect row). Es la lista de efectos que esta función
  necesita para correr. Sin ese `/ Log`, la función no compila:
  está usando una capacidad que no declaró.

El sistema de tipos garantiza que **toda función que usa un efecto
lo declara**. Si llamas `Log.log(...)` desde una función sin
`/ Log`, el compilador rechaza con un mensaje claro. No hay
escape: los efectos son visibles en la firma, siempre.

Y esto vale recursivamente. Si `greet` usa `Log` y `main` llama a
`greet`, entonces `main` también necesita `Log` en su firma, a
menos que **maneje** el efecto antes (eso es §12.4).

```kai
fn main() : Unit / Log {       # propaga el efecto
  greet("kaikai")
}
```

Es el mismo principio del contagio que vimos en `async`/`await`,
pero sin el problema de los colores: aquí no hay sintaxis especial
para "pagar el efecto" en la llamada. `Log.log(...)` es una
llamada como cualquier otra. La fila en la firma es donde vive la
disciplina, y agregar un efecto nuevo no introduce un color nuevo
incompatible con el resto: solo extiende la fila.

### Varios efectos: la fila

Si una función usa más de un efecto, los enumera con `+`:

```kai
fn procesar() : Int / Log + Fail {
  Log.log("inicio")
  if condicion_mala() {
    Fail.fail("no se puede")
  }
  42
}
```

`Log + Fail` es la **fila** de efectos. El orden no importa: la
fila es un conjunto, no una secuencia. `Log + Fail` y `Fail + Log`
son la misma fila para el compilador. El operador `+` es solo
sintaxis para construirla.

(`Fail` no viene del stdlib: es un efecto que declararemos en
§12.5, igual que `Log` en §12.2. Lo uso desde ya porque el nombre
se explica solo.)

Si esto te suena al capítulo 10, donde `m * s` y `s * m` eran
la misma unidad, no es coincidencia. Los efectos son otra de
las familias de etiquetas del §2.6: habitan su propio kind, con
su propia álgebra (la fila, donde el orden no cuenta y los
duplicados colapsan), y el compilador la aplica al unificar
firmas igual que aplica el álgebra de unidades. El capítulo 19
muestra las dos como entradas del mismo catálogo.

## 12.4 Manejar un efecto con `handle ... with`

La parte interesante: **decidir qué significa un efecto** en un
punto del programa. Eso es lo que hace `handle ... with`.

```kai
fn main() {
  handle {
    greet("kaikai")
    greet("Eduardo")
  } with Log {
    log(msg, resume) -> {
      println("[INFO] " ++ msg)
      resume(())
    }
  }
}
```

Lectura literal: "ejecuta este bloque, y para cuando alguien dentro
invoque `Log.log`, hazlo así". El handler intercepta cada llamada
a `log`, decide qué pasa, y reanuda con `resume(...)`.

Tres detalles que vale fijar:

- **`handle { body } with Effect { clauses }`** es una construcción
  de control, en la misma familia que `if` y `match`. No es una
  llamada a función. `handle` y `with` son palabras reservadas.
- **`body` es donde `Effect` queda manejado.** Adentro, llamar a
  `Log.log(...)` es legal sin tener `Log` en la fila de la función
  que envuelve, porque el handler la provee. Afuera del `with`, el
  efecto vuelve a ser exigido por el sistema de tipos.
- **`resume(())` continúa la ejecución del body** desde el punto
  donde se llamó `log`, con el valor que pasaste como argumento.

Lo notable: **el `main` no necesita declarar `Log` en su firma**.
El `handle` lo "consume": el bloque de adentro lo usa, el `with`
lo provee, y la fila de efectos del `main` queda sin `Log`. El
sistema de tipos sigue siendo estricto, pero el handler es la
puerta por la que un efecto sale del scope.

### El mismo body con dos handlers

Lo poderoso aparece cuando notas que `greet` no cambia entre
ejecuciones. Con un handler obtienes logs verbosos; con otro,
silencio:

```kai
# Handler verboso
handle {
  greet("modo verboso")
} with Log {
  log(msg, resume) -> {
    println("[INFO] " ++ msg)
    resume(())
  }
}

# Handler silencioso
handle {
  greet("modo silencioso")
} with Log {
  log(msg, resume) -> resume(())   # ignora el mensaje
}
```

`greet` no se entera de la diferencia. Lo mismo vale para un
handler que escribe a archivo, uno que acumula los mensajes en una
lista, uno que los manda por red. La función `greet` es **agnóstica
al handler**.

Esto es lo que reemplaza la inyección de dependencias. No hay
constructor que pasar ni servicio que mockear; el handler es
la implementación.

## 12.5 `resume`: el handler decide qué pasa después

`resume` es la pieza que más confunde al inicio y la que más rinde
cuando se entiende. Es el **continuation** del body desde el punto
de la operación.

Cuando el body invoca `Log.log("hola")`, el control de la
ejecución salta al handler. El handler recibe dos cosas:

1. El argumento que se pasó a la operación: `"hola"`.
2. Una función `resume` que, si se llama, continúa el body desde
   donde se quedó.

```kai
log(msg, resume) -> {
  println("[INFO] " ++ msg)   # decide qué hacer con el efecto
  resume(())                   # devuelve el control al body
}
```

`resume(())` pasa `()` como valor de retorno de la operación
`log` (que devuelve `Unit`). El body continúa después del
`Log.log(...)` con ese valor.

### Operaciones que devuelven valores

`Log.log` no devuelve nada útil, pero otras operaciones sí. Un
efecto puede **proveer** un valor:

```kai
effect Ask {
  name() : String
}

fn saludar() : String / Ask {
  "hola, " ++ Ask.name()
}

fn main() : Unit / Stdout {
  let mensaje = handle {
    saludar()
  } with Ask {
    name(resume) -> resume("mundo")
  }
  println(mensaje)   # imprime "hola, mundo"
}
```

`Ask.name()` suspende el body. El handler recibe `resume` y decide
qué `String` darle a quien llamó: aquí, `"mundo"`. `resume("mundo")`
continúa el body con ese valor, y el `++` lo concatena.

Esto reemplaza muchos usos de la inyección de dependencias: en vez
de pasar `nombre` como parámetro hasta el fondo del árbol de
llamadas, lo "preguntas" via efecto, y el handler en `main` decide
qué responder. En tests, otro handler responde algo distinto.

### Handlers que NO llaman a `resume`

Si el handler **no** llama a `resume`, el body se descarta y el
valor del handler se vuelve el valor de todo el `handle`. Esto es
como las excepciones se construyen:

```kai
effect Fail {
  fail(motivo: String) : Nothing
}

fn dividir(a: Int, b: Int) : Int / Fail {
  if b == 0 { Fail.fail("división por cero") }
  else      { a / b }
}

fn main() : Unit / Stdout {
  let r = handle {
    let x = dividir(10, 2)
    let y = dividir(20, 0)    # aquí se invoca Fail.fail
    x + y                      # nunca llega
  } with Fail {
    fail(motivo, resume) -> {
      println("falló: " ++ motivo)
      0                        # valor de reemplazo
    }
  }
  println("resultado: #{r}")   # imprime: resultado: 0
}
```

La firma `fail(motivo: String) : Nothing` declara que la operación
**nunca regresa**. `Nothing` es el tipo vacío de kaikai (el bottom
type del cap. 3): no tiene habitantes, no se puede construir un
valor de `Nothing`. Por construcción, no hay nada que pasar a
`resume`, así que el sistema de tipos garantiza que no se puede
continuar el body después de `Fail.fail`. El programa no se rompe
si lo intentas, el compilador no te deja escribir el código.

Esa es la clave: las "excepciones" de kaikai son un caso particular
del mecanismo general. No hay sintaxis especial para `try/catch`;
hay `handle` y un efecto cuya operación devuelve `Nothing`.

## 12.6 Handlers con estado: el patrón `State`

Hasta aquí los handlers fueron sin estado: solo decidían qué hacer
y reanudaban. Pero un handler puede llevar **su propio estado**
sin que el body se entere. Esto reemplaza la mutación global.

```kai
effect State[T] {
  get() : T
  set(v: T) : Unit
}

fn suma(xs: [Int]) : Int {
  handle {
    list.foreach(xs, (x) => State.set(State.get() + x))
    State.get()
  } with State[Int](0) {
    get(resume)    -> resume(state)         # devuelve estado
    set(v, resume) -> resume((), v)         # cambia estado
    return(x)      -> x                      # descarta estado al final
  }
}
```

Tres cosas nuevas:

- **`State[T]` es paramétrico.** El tipo `T` es lo que el estado
  guarda. Aquí va a ser `Int`.
- **`with State[Int](0)`** instala el handler con estado inicial
  `0`. El argumento entre paréntesis es el valor inicial.
- **`state`** es un identificador especial disponible dentro de
  las cláusulas del handler. Se refiere al valor actual del estado.
- **`resume(value, new_state)`** tiene dos argumentos cuando el
  handler tiene estado: el valor de retorno de la operación, y el
  estado nuevo. `resume(value)` sin segundo argumento deja el
  estado igual.
- **`return(x) -> x`** se ejecuta cuando el body termina
  normalmente. `x` es el resultado del body. Aquí descartamos el
  estado final y devolvemos solo `x`; si quisieras ambos, harías
  `return(x) -> (x, state)`.

Para el body, no hay mutación: solo invocaciones a operaciones
puras. La mutación vive completa dentro del handler. Desde afuera
del `handle`, no se ve nada.

Este patrón es genérico: con la misma forma se construyen
`Reader` (entorno de lectura), `Writer` (acumulación de salida),
contadores, caches, sesiones. Todos sin tocar variables globales y
sin propagar parámetros.

## 12.7 `var`, `Ref[T]` y `Array[T]`: dos mecanismos distintos

`State[T]` es la herramienta general para llevar un valor que
cambia, pero escribir un `handle ... with State[Int](0)` cada
vez que quieres un contador local sería tedioso. Por eso kaikai
trae azúcar sintáctica y, separadamente, un efecto del stdlib
para casos donde la memoria sobrevive al bloque. Son dos
construcciones distintas que vale la pena no confundir.

### `var`: azúcar sobre `State[T]`

La forma corta de una celda local:

```kai
fn contar_pares(xs: [Int]) : Int {
  var n := 0
  list.foreach(xs, (x) => {
    if x % 2 == 0 {
      n := n + 1
    }
  })
  n
}
```

El `:=` es la única marca de mutabilidad:

- **`var n := 0`** declara la celda con su valor inicial.
- **`n := v`** escribe `v`.
- **`n`** lee el valor actual: un nombre desnudo, sin marca.

¿Cómo funciona por dentro? **`var` es azúcar sintáctico sobre
`State[T]`.** El compilador reescribe

```kai
var n := 0
... resto del bloque ...
```

a

```kai
handle {
  ... resto del bloque ...
} with State[Int](0) as n {
  get(resume)    -> resume(state)
  set(v, resume) -> resume((), v)
  return(x)      -> x
}
```

Como el `handle` que se inserta queda **dentro del mismo
bloque** donde el `var` aparece, el efecto `State[Int]` se
cierra ahí mismo y no escapa a la firma de la función. Para
quien la llama, `contar_pares` es `: Int`. Sin efectos.

El efecto no se enmascara: el `handle` está literalmente al
lado del `var`. La fila se cierra en el lugar exacto donde la
celda se declara.

Y no es caro: el compilador detecta el patrón "celda local con
`resume` de un disparo" y lo especializa a una posición de
stack frame, equivalente a una variable mutable de C. Costo
cero comparado con el código imperativo equivalente.

### `Mutable`: el efecto detrás de `Ref[T]` y `Array[T]`

`var` cubre celdas locales. Pero hay casos donde la memoria
tiene que **sobrevivir al bloque**: un array que vas a
devolver, una celda que pasas entre funciones, una estructura
que comparten varias rutinas. Para esos casos kaikai trae dos
tipos del stdlib, `Ref[T]` y `Array[T]`, y ambos viven bajo el
efecto **`Mutable`**.

```kai
fn rellenar(n: Int) : Array[Int] {
  let a = Mutable.array_make(n, 0)
  var i := 0
  list.foreach([0..n], (_) => {
    a[i] := i * 2
    i := i + 1
  })
  a
}
```

- **`Mutable.array_make(n, init)`** crea un array de tamaño
  `n` con valor inicial `init`.
- **`a[i]`** lee la posición `i`. Azúcar para
  `Mutable.array_get(a, i)`.
- **`a[i] := v`** escribe la posición `i`. Azúcar para
  `Mutable.array_set(a, i, v)`.

`Ref[T]` es la versión de una sola celda: `Mutable.ref_make(v)`,
`Mutable.ref_get(r)`, `Mutable.ref_set(r, v)`. No tiene azúcar
de indexación, pero el resto es paralelo a `Array[T]`.

Mira la firma de `rellenar`: dice `: Array[Int]`, **sin
`Mutable`**. ¿Por qué, si la función claramente muta?

Porque `Mutable` sigue la disciplina de **efectos observables**:
el efecto aparece en la firma solo cuando la mutación es
**visible para quien llama**. Y aquí no lo es. El array se
crea adentro, se llena adentro, y se devuelve cuando ya está
listo. Quien recibe el array obtiene un valor ya armado,
no observa ninguna mutación.

### Cuándo `Mutable` se vuelve visible

Si la mutación es **observable**, el efecto aparece en la
firma:

```kai
fn rellenar_en_sitio(a: Array[Int]) : Unit / Mutable {
  let n = Mutable.array_length(a)
  var i := 0
  list.foreach([0..n], (_) => {
    a[i] := i * 2
    i := i + 1
  })
}
```

Aquí `a` llega de afuera. Quien llama tiene una referencia al
mismo array que estamos modificando. La mutación es visible
para el caller, y la firma debe declararlo.

La regla del cap. 12 §12.3 se aplica igual que con cualquier
otro efecto: el sistema de tipos garantiza que toda función
que produce un efecto observable lo declara. Las "asignaciones
secretas" no existen.

### `Mutable` versus `State[T]`

Ambos representan estado mutable. ¿Cuándo conviene cada uno?

- **`var` (que es `State[T]`)**: la celda vive dentro del
  bloque. No tiene que sobrevivir a la función, no se pasa a
  otras rutinas, solo es un acumulador o contador local. La
  firma queda limpia.
- **`Mutable` con `Ref[T]` o `Array[T]`**: la memoria sobrevive
  al bloque o se comparte entre funciones. Aparece en la
  firma cuando la mutación es observable para quien llama.

Si pasas un `Ref[T]` o un `Array[T]` como argumento, o lo
devuelves después de mutarlo, estás en territorio de
`Mutable`. Si solo necesitas un contador local, es `var`.

## 12.8 Componer efectos: handlers anidados

Las funciones reales usan más de un efecto. Una que logguea y
acumula puede declarar `/ Log + State[Int]`, y en `main` la
manejas con dos `handle`s anidados:

```kai
fn acumular(xs: [Int]) : Int / Log + State[Int] {
  list.foreach(xs, (x) => {
    Log.log("sumando #{x}")
    State.set(State.get() + x)
  })
  State.get()
}

fn main() : Unit / Stdout {
  let total = handle {
    handle {
      acumular([10, 20, 30])
    } with State[Int](0) {
      get(resume)    -> resume(state)
      set(v, resume) -> resume((), v)
      return(x)      -> x
    }
  } with Log {
    log(msg, resume) -> {
      println("[LOG] " ++ msg)
      resume(())
    }
  }
  println("total = #{total}")
}
```

El orden de anidación importa **cuando los handlers interactúan**.
Aquí no interactúan: `State` solo lee y escribe su estado, `Log`
solo imprime. Cualquiera de los dos órdenes funciona. Pero si
tuvieras `Fail` adentro de `State`, el orden decide si el estado
sobrevive a una falla (Fail externo) o se descarta (Fail interno).
Cada combinación tiene una semántica explícita y verificable.

Esa es una diferencia profunda con `try/catch + variables
globales`: ahí el orden es implícito y depende del runtime. Aquí es
explícito y lo decides en la firma de los `handle`.

### Limpieza garantizada: `initially` y `finally`

El anidamiento trae un problema que las excepciones también
tienen y resuelven a medias. Si un handler externo abandona el
`resume`, como el `Fail` de §12.5, el body interior nunca
vuelve. Cualquier línea que hayas escrito *después* del `handle`
para cerrar un archivo, soltar un lock o devolver una conexión al
pool no corre nunca. El salto no local se la comió.

Un handler puede llevar dos cláusulas más para cerrar ese hueco:

- `initially { }` corre una vez, cuando el handler se instala,
  antes del body. Su valor es el estado del handler, legible como
  `state` en las cláusulas. Ocupa el mismo espacio que la forma
  `with Eff(init)`: se escribe una o la otra, nunca las dos.
- `finally { }` corre cuando el scope se desarma, **por cualquier
  camino**: retorno normal, una cláusula que abandona `resume`
  (incluida una instalada más afuera, cuyo salto se brinca este
  scope), y cancelación cooperativa (cap. 13). No corre en
  `panic`, que aborta el proceso en vez de desarmarlo.

Juntas son el *bracket* de adquirir/liberar. Y lo son de verdad,
no por convención: la adquisición vive **dentro** de la
construcción que garantiza la liberación, así que no existe una
ventana en la que el recurso está abierto y todavía sin protección.

```kai
# ejemplos/cap12/12_limpieza.kai
effect Fail {
  fail(motivo: String) : Nothing
}

effect Conexion {
  consultar(sql: String) : String
}

fn reporte() : String / Conexion + Fail {
  let fila = Conexion.consultar("SELECT total FROM ventas")
  Fail.fail("se cortó la red antes del segundo query")
}

fn main() : Unit / Stdout {
  let r = handle {
    handle {
      reporte()
    } with Conexion {
      initially { println("abriendo conexión"); 42 }
      finally   { println("cerrando conexión #{state}") }
      consultar(sql, resume) -> resume("1500")
      return(x)              -> x
    }
  } with Fail {
    fail(motivo, resume) -> "abortado: #{motivo}"
    return(x)            -> x
  }
  println(r)
}
```

```
$ kai run ejemplos/cap12/12_limpieza.kai
abriendo conexión
cerrando conexión 42
abortado: se cortó la red antes del segundo query
```

El `Fail` externo abandonó el `resume` y el body de `Conexion`
nunca terminó. Aun así la conexión se cerró, y se cerró *antes* de
que el valor de reemplazo llegara a `main`. Ese orden no es
casualidad: el desarme del scope interior ocurre en el camino del
salto, no después.

Hay una regla que conviene tener presente: **la limpieza corre en
el contexto de evidencia del momento en que se instaló**. Si el
`finally` realiza un efecto, ese efecto se despacha a los handlers
que estaban vivos cuando el handler se instaló, no a los del punto
de salto: esos marcos ya no existen. La consecuencia práctica es
que un `finally` no puede realizar el efecto que su propio handler
descarga. Eso te lo dice el compilador ("effect not handled") y
nunca se convierte en un ciclo en tiempo de ejecución.

`finally` no recibe parámetros y su valor se descarta: corre por su
efecto, no por lo que devuelve. Para transformar el resultado del
`handle` está `return(x)`, que es otra cosa.

Dos detalles de convivencia. `initially` y la forma `with Eff(init)`
ocupan el mismo espacio, así que escribir las dos es un error de
parseo: eliges una. Y ninguna de las dos palabras es reservada,
son contextuales, de modo que un efecto tuyo puede seguir
declarando una operación llamada `finally` sin que nada se rompa.

## 12.9 Instancias nombradas: el handler como valor

Hasta aquí, cada operación encuentra su handler por el nombre del
efecto: `Log.log(...)` sube hasta el `handle ... with Log` más
cercano. Eso deja una pregunta sin respuesta: ¿y si necesitas
**dos** handlers del mismo efecto, vivos a la vez, y quieres
elegir a cuál le hablas?

La respuesta es darle un nombre a cada instancia:

```kai
handle {
  ...
} with Cell(10) as a {
  get(resume)    -> resume(state)
  set(v, resume) -> resume((), v)
  return(x)      -> x
}
```

El `as a` liga `a` como un **capability value**: un valor cuyo
tipo es el efecto mismo (`Cell`, `State[Int]`). Dentro del cuerpo,
`a.get()` opera contra *esa* instancia: el handler que tiene
nombre `a`, y no el `Cell` más cercano.

Lo interesante empieza cuando el capability viaja. Una instancia
nombrada **se puede pasar como argumento**:

```kai
fn add(c1: Cell, c2: Cell, dst: Cell) : Unit =
  dst.set(c1.get() + c2.get())
```

Mira esa firma con calma, porque tiene una sutileza. `Cell`
aparece como **tipo de parámetro**, no en la fila de efectos.
Son dos modos distintos de pedir lo mismo:

- **En la fila** (`fn f() : T / Cell`): el efecto se *demanda*, y
  lo satisface un `handle` que envuelva la llamada, o un default.
- **Como parámetro** (`fn f(c: Cell) : T`): el capability lo
  *provee* quien llama, pasándolo explícito. No va en la fila,
  porque la función no le pide nada al contexto: ya tiene su
  evidencia en la mano.

Con eso, tres instancias del mismo efecto conviven sin pisarse
(`ejemplos/cap12/11_instancias.kai`):

```kai
handle {
  handle {
    handle {
      add(a, b, destino)
      println("destino = #{destino.get()}")
    } with Cell(0) as destino { ... }
  } with Cell(20) as b { ... }
} with Cell(10) as a { ... }
```

```
$ kai run ejemplos/cap12/11_instancias.kai
destino = 30
```

`add` suma las celdas que le den, sin saber cuál es cuál. Antes
de las instancias nombradas, la única salida era declarar tres
efectos idénticos (`CellA`, `CellB`, `CellDst`) y manejar cada
uno por separado. Ceremonia pura, y no escala.

Una restricción importante: el capability es **de segunda
clase**. Puede bajar por la pila, como argumento de llamada o
como receptor de operaciones, pero no puede *escapar*:
guardarlo en un record, devolverlo desde la función, capturarlo
en una closure que sobreviva al `handle`, o cruzarlo a una fibra
con `spawn`. Un handler es una promesa con alcance léxico; un
valor que necesita vivir más que su `handle` no es un
capability, es un `Ref[T]` bajo `Mutable` (§12.7) o un actor
(capítulo 14).

Si vienes de la inyección de dependencias, esta sección te
debería sonar: pasar el capability como parámetro **es**
inyectar la dependencia, con la diferencia de que aquí el tipo
la rastrea y el compilador rechaza los usos que la harían
escapar de su vida útil. Y si el wiring explícito te estorba,
la fila de efectos sigue ahí: son los dos extremos del mismo
mecanismo, y eliges por llamada.

## 12.10 Alias de filas de efectos

Cuando una combinación aparece muchas veces, le das un nombre con
`type`:

```kai
effect Log    { log(msg: String) : Unit }
effect Audit  { audit(usuario: String, accion: String) : Unit }

type Tracing = Log + Audit
```

A partir de ahí, escribir `: Unit / Tracing` es lo mismo que
escribir `: Unit / Log + Audit`. El alias es **transparente**: no
introduce un efecto nuevo, solo abrevia la fila.

```kai
fn realizar_compra(usuario: String, monto: Int) : Unit / Tracing {
  Log.log("inicio compra")
  Audit.audit(usuario, "compra($#{monto})")
  Log.log("fin compra")
}
```

Una restricción: los alias deben ser **cerrados**. No puedes
escribir `type WithIo[e] = Io + e` (con variable de fila). Esa
restricción evita complicaciones en la unificación que el
compilador no necesita pagar.

## 12.11 Default handlers: el efecto trae el suyo

Hasta aquí cada `handle` que vimos lo escribimos a mano. Pero hay
efectos donde una de las implementaciones es tan obvia que pedirle
al usuario que la escriba cada vez es ceremonia pura: si tu efecto
es `Log` y la implementación "razonable" imprime con timestamp,
querrías que esa implementación venga con el efecto.

Kaikai permite declarar un **bloque `default { }`** dentro de la
declaración del efecto. Es exactamente lo mismo que un `handle ...
with`, pero vive al lado de las operaciones y el compilador lo
instala alrededor de `main` cuando nadie maneja el efecto a mano.

```kai
effect Log {
  info(msg: String) : Unit
  warn(msg: String) : Unit

  default {
    info(msg, resume) -> $extern_handler("kai_default_log_info")
    warn(msg, resume) -> $extern_handler("kai_default_log_warn")
  }
}
```

Las cláusulas del bloque `default` tienen la **misma forma** que
las de un `handle`: nombre de operación, parámetros, `resume`,
flecha, cuerpo. Lo que cambia es dónde viven y quién las dispara.
Si `main()` declara `: Unit / Log` y no hay ningún `handle ... with
Log` envolviéndolo, el compilador genera código equivalente a:

```kai
handle {
  main_original()
} with Log {
  info(msg, resume) -> ...   # las cláusulas del default
  warn(msg, resume) -> ...
}
```

El usuario no escribe ese wrapping. El compilador lo deriva del
bloque `default` y lo emite al entrar al programa.

### `$extern_handler`: el sigil y el puente a C

El cuerpo de cada cláusula del ejemplo anterior es
`$extern_handler("kai_default_log_info")`. Eso necesita
explicación.

`$` es un **sigil**: un carácter que marca una forma sintáctica
especial. En kaikai introduce un **compiler intrinsic**, una
construcción que el compilador resuelve directamente en vez de
buscar una función definida en código kaikai. La forma general es
`$nombre(args)`. Hoy hay uno solo: `$extern_handler`. Mañana puede
haber más; el sigil queda reservado para esa categoría.

`$extern_handler("kai_default_log_info")` significa: "el cuerpo
de esta cláusula es una llamada al símbolo C `kai_default_log_info`".
Cuando el efecto se dispara, el compilador no busca una función
kaikai que se llame así; emite directo una llamada al runtime de C
que está enlazado al programa.

Esto es el puente entre los efectos algebraicos de alto nivel y el
mundo concreto: archivos, sockets, syscalls. Las primitivas del
sistema operativo viven en C; los efectos viven en kaikai;
`$extern_handler` los conecta.

### Cuándo dispara el default y cuándo no

La regla de búsqueda es la misma de §12.4 pero con un escalón
extra al final:

1. El `handle ... with Eff` más cercano que cubre la operación gana.
2. Si no hay handle envolvente y la operación está en la fila de
   `main`, el compilador instala el default del efecto.
3. Si ni siquiera el default cubre la operación, el compilador
   rechaza el programa al typecheckar `main`.

Mira el detalle: el default **solo** se instala cuando la operación
escaparía a `main`. Si tu función está dentro de un `handle`, gana
el handle, no el default. No hay ambigüedad ni precedencia
sorpresiva: lo más cercano siempre gana.

### Volver al ejemplo desde otro ángulo

Esto explica por qué `println` compila sin que cada firma cargue
`/ Stdout`:

```kai
fn hola() {
  println("hola")
}

fn main() {
  hola()
}
```

`Stdout` viene del stdlib con un bloque `default` cuyas cláusulas
llaman a `$extern_handler("kai_default_stdout_print")` y similares.
El símbolo C escribe al `stdout` real del proceso. Como `main` no
maneja `Stdout`, el compilador instala ese default y el programa
imprime.

Cuando quieras controlar la salida (silenciar en tests, redirigir
a archivo, capturar para asertar contra ella), pones tu propio
`handle ... with Stdout` y dentro del bloque el default del runtime
no participa. **Lo más cercano gana**: el `handle` que escribiste
está más cerca que el wrapping implícito al entrar a `main`.

### Tu propio default: el ejemplo completo

Si declaras un efecto y lo equipas con un default, los programas
que solo usan `main` se ven igual de simples:

```kai
effect MyLog {
  info(msg: String) : Unit
  default {
    info(msg, resume) -> $extern_handler("kai_default_log_info")
  }
}

fn greet(name: String) : Unit / MyLog {
  MyLog.info("hola, " ++ name)
}

fn main() : Unit / Stdout {
  let r = handle {
    MyLog.info("hello from extern_handler")
    7
  } with MyLog {
    info(msg, resume) -> resume(())   # silencia adentro del handle
  }
  print("result: #{r}")
}
```

Adentro del `handle ... with MyLog`, las cláusulas explícitas
ganan: el `info` queda silenciado. Si en otro `main` no hubiera
ese `handle`, el default dispararía e imprimiría vía el runtime de C.
La función `greet` no se entera: para ella, `MyLog` es lo que sea
que el contexto haya decidido.

### Cuándo no hay default: el efecto sin red

No todos los efectos traen `default`. El `Fail` que declaramos en
§12.5 es el contraejemplo claro: si una operación puede abortar el
programa, no quieres que "olvidarse de manejarla" sea legal. Como
lo declaraste tú y no lleva bloque `default`, una función que
produce `/ Fail` obliga a ser manejada en algún lado antes de
`main`, o el compilador rechaza con un mensaje claro.

Vale la pena decir de dónde viene ese ejemplo. Hasta la versión
0.105, `Fail` era un efecto del stdlib **con** default: el runtime
imprimía un banner y salía con código 1. En 0.106 lo retiraron.
El argumento fue que no aportaba nada que `Result[a, e]` con `!`
postfijo no diera mejor (de hecho, no quedaba una sola fila
`/ Fail` en todo el stdlib) y que su forma, una operación que
devuelve `Nothing`, era justamente la que *no* podía expresar la
falla interesante: aquella en la que el consumidor elige si saltear
o abortar. Para eso el efecto tiene que devolver `Unit` y dejar que
el handler decida si llama a `resume`. El apéndice D tiene la tabla
completa de reemplazos.

Que `Fail` sobreviva en este capítulo como efecto declarado en el
propio archivo no es nostalgia: sigue siendo la forma más corta de
mostrar qué significa una operación que no vuelve.

Lo mismo vale para `State[T]`, `Reader[T]`, `Writer[W]`: efectos
genéricos en los que **no existe** una implementación razonable
sin contexto, así que pedirle al usuario que la escriba no es
ceremonia sino disciplina.

La regla mental: un efecto trae `default` cuando hay **una sola**
implementación obvia (escribir a `stdout`, leer del reloj del
sistema, generar números pseudo-aleatorios). Si "razonable" depende
del programa, no hay default y el usuario lo provee.

### Función envoltorio: la alternativa cuando no hay default

Cuando un efecto no trae `default`, o cuando el default existe pero
tu programa siempre quiere otro, el patrón idiomático es una
**función envoltorio**:

```kai
fn with_test_log[A](body: () -> A / MyLog) : A {
  handle {
    body()
  } with MyLog {
    info(msg, resume) -> resume(())   # silencia en tests
  }
}

fn main() {
  with_test_log { ->
    greet("kaikai")
    greet("ada")
  }
}
```

Es lo que el stdlib usa para construcciones como
`with_reader(env) { body }`, `with_writer { body }` y
`with_mailbox { body }`. La diferencia con un default es que la
envoltura es **explícita en el código**: quien lee `main` ve la
línea, abre la función, sabe qué hace. Un default vive en la
declaración del efecto.

Si tu efecto tiene un default razonable para producción y uno
distinto para tests, expón los dos como funciones envoltorio
(`with_test_log`, `with_quiet_log`) y deja que `main` use el
default. Quien escribe tests llama a la envoltorio.

## 12.12 Los handlers del stdlib son código kaikai

Cuando un programa `println("hola")` simplemente funciona, es fácil
imaginar que el compilador trae un caso especial para `Stdout`. No
es así. Los handlers que el runtime instala alrededor de `main`
para `Stdout`, `Stdin`, `Random`, `Clock`, `File`, `Env`, `NetTcp`,
y los demás están escritos en **stdlib kaikai normal**: cada uno
es un `effect ... { ops; default { ... } }` que usa el mismo sigil
`$extern_handler` que tú usarías para conectar tu efecto con C.

```kai
# stdlib/io/console.kai (forma esquemática)
effect Stdout {
  print(s: String) : Unit
  default {
    print(s, resume) -> $extern_handler("kai_default_stdout_print")
  }
}
```

El compilador no conoce a `Stdout` por su nombre. Conoce **bloques
`default`** y **`$extern_handler`**. Para `Stdout`, instala el
default igual que para tu `MyLog`: caminando el AST de la
declaración del efecto, no leyendo una tabla hardcoded.

El motivo no es estético: el AST se vuelve la única fuente de
verdad, sin tablas internas que mantener en paralelo, y los
efectos de usuario obtienen exactamente las mismas garantías
que los del stdlib. Si tu efecto declara `default { }` con
`$extern_handler`, el compilador lo instala como builtin.

La consecuencia práctica: **puedes leer cómo está implementado
`Stdout`**. `kai doc effects.Stdout` te muestra su firma y su
default; el efecto es código kaikai como el tuyo. Si
te aparece una duda sobre la semántica del default (¿qué pasa si el
pipe está cerrado?, ¿quién captura `EPIPE`?), la respuesta vive
en la cláusula `print(s, resume) -> ...` o en el símbolo C al que
puentea. No hay un comportamiento secreto del runtime separado del
código que puedes leer.

Vale repetir la regla para amarrar el modelo: el compilador resuelve
un efecto buscando, en orden, (1) el `handle ... with` más cercano,
(2) el `default { }` block del efecto si la operación escapa a
`main`, (3) error de compilación. Los handlers del stdlib no son
una cuarta categoría; son instancias de (2).

### Por qué el sigil tiene un nombre raro

`$extern_handler` puede sonar largo. La razón es que el sigil es
un sistema, no una sola operación. La trilogía #533 introdujo `$`
como prefijo para una **familia** de intrinsics; `$extern_handler`
es el primero. Si más adelante kaikai necesita exponer otros
puentes al runtime (pedir el `errno` actual, llamar a un símbolo
de plataforma específica), vivirán bajo el mismo sigil con nombres
descriptivos: `$os_name`, `$panic_with_trace`, lo que sea. Reservar
`$<ident>(args)` deja la puerta abierta sin reabrir el debate
sintáctico cada vez.

Para tu día a día: si nunca conectas un efecto a C, nunca vas a
escribir `$extern_handler`. Pero cuando lo veas en stdlib sabes
qué es: una cláusula que cede el cuerpo a un símbolo del runtime,
declarada con la misma sintaxis que cualquier otro handler.

## 12.13 Caso de estudio: procesador de configuración

Cerramos con un ejemplo que mezcla los tres patrones que vimos:
logueo, estado, fallo. El programa procesa una lista de líneas
con formato `clave=valor`, las parsea, registra cada paso, cuenta
cuántas pasaron, y aborta si alguna línea no tiene el formato
esperado.

```kai
effect Log {
  log(msg: String) : Unit
}

effect State[T] {
  get() : T
  set(v: T) : Unit
}

effect Fail {
  fail(motivo: String) : Nothing
}

type Entrada = { clave: String, valor: String }

fn parsear(linea: String) : Entrada / Fail {
  match string.split(linea, "=") {
    [c, v] -> Entrada { clave: c, valor: v }
    _      -> Fail.fail("línea inválida: '#{linea}'")
  }
}

fn procesar(lineas: [String]) : Int / Log + State[Int] + Fail {
  list.foreach(lineas, (l) => {
    let e = parsear(l)
    Log.log("#{e.clave} = #{e.valor}")
    State.set(State.get() + 1)
  })
  State.get()
}
```

`procesar` declara los tres efectos en su firma y los usa
libremente: parsea (puede fallar), registra (loggea), acumula
(estado). Pero no decide nada sobre el contexto en que corre.

En `main`, los tres handlers anidados deciden:

```kai
fn main() : Unit / Stdout {
  let n = handle {
    handle {
      handle {
        procesar(["nombre=ada", "edad=42", "rol=admin"])
      } with State[Int](0) {
        get(resume)    -> resume(state)
        set(v, resume) -> resume((), v)
        return(x)      -> x
      }
    } with Log {
      log(msg, resume) -> {
        println("[LOG] " ++ msg)
        resume(())
      }
    }
  } with Fail {
    fail(motivo, resume) -> {
      println("error: " ++ motivo)
      0 - 1
    }
  }
  println("entradas procesadas: #{n}")
}
```

Salida:

```
$ kai run ejemplos/cap12/08_parser_config.kai
[LOG] nombre = ada
[LOG] edad = 42
[LOG] rol = admin
entradas procesadas: 3
```

Y si una línea es inválida, el `Fail` exterior la atrapa, imprime
el motivo, y `n` queda en `-1`. El `Log` y el `State` interiores
ya emitieron lo que alcanzaron antes del fallo.

¿Por qué este es un buen ejemplo para terminar el capítulo? Porque
muestra los tres patrones cooperando, cada uno aportando algo
distinto, y porque la función `procesar` es **directamente
testeable**: sin tocar archivos, sin tocar IO, sin mocks. En un
test, los tres handlers tienen otras implementaciones: el `Log`
acumula en una lista en vez de imprimir, el `Fail` propaga en un
`Result`, el `State` parte del valor que el test quiera.

## 12.14 Filosofía: tres ideas que vale recordar

Si esto te parece muchas piezas, vale fijar las tres ideas que
todo lo demás sostiene:

1. **Los efectos son visibles en el tipo.** Si una función puede
   fallar, suspenderse, mutar, o llamar a IO, su firma lo dice.
   Sin excepciones invisibles, sin `async` infeccioso, sin
   dependencias ocultas.

2. **El handler decide qué pasa.** El cuerpo de una función
   declara que necesita una capacidad. El handler en el contexto
   decide cómo materializarla. Ese desacople es lo que reemplaza
   inyección de dependencias, mocking, configuración global.

3. **Costo cero cuando no se usa.** El compilador resuelve los
   handlers en tiempo de compilación cuando puede (la mayoría de
   los casos), y el código generado es tan rápido como si hubieras
   escrito un `if` directo. No hay sobrecarga estructural por
   tener efectos en el tipo. Es la misma promesa de las unidades
   de medida y los contratos: información rica en el tipo, código
   eficiente abajo.

Los efectos algebraicos vienen de la academia (Pretnar, Plotkin,
Power) y aparecieron en lenguajes como Koka, Eff y Effekt antes
que en kaikai. Lo que kaikai aporta es una sintaxis legible (la
notación `/ Eff` en la firma), una integración con el resto del
lenguaje (filas en vez de listas, alias), y un modelo de defaults
que no tiene casos especiales: los handlers del stdlib están
declarados en kaikai con la misma forma que los tuyos. Pero la
idea de base es vieja y sólida.

Si después de este capítulo todavía no estás cómodo, no te
preocupes. Los efectos son la pieza que más tiempo toma asentar.
Volverás a leer este capítulo varias veces. Cada lectura agarra
una capa más.

## Ejercicios

**12.1.** Escribe un efecto `Clock` con una operación `now() : Int`
(milisegundos desde el inicio). Escribe una función `medir` que
ejecute un bloque y devuelva cuánto tiempo tomó usando `Clock`.
Después escribe dos handlers: uno real (consulta el reloj del
sistema) y uno simulado (avanza un contador). ¿Para qué sirve el
segundo?

**12.2.** Modifica `suma` de §12.6 para que devuelva tanto el
total como la cantidad de elementos sumados, sin agregar
parámetros. Pista: cambia `return(x) -> x`.

**12.3.** El caso de estudio §12.13 imprime con `[LOG]` cada
entrada. Cambia el handler de `Log` para que en vez de imprimir,
acumule los mensajes en una lista y los devuelva como parte del
resultado final, junto con `n`. Pista: necesitas otro `State`.

**12.4.** Escribe `fn contar_pares(xs: [Int]) : Int` de dos formas:
una con `var` y `list.foreach`, otra sin `var`, usando `list.filter`
y `list.length`. ¿Cuál te parece más clara? ¿Por qué la versión con
`var` no agrega efectos a la firma?

**12.5.** Construye un efecto `Choice` con una operación
`choose(opciones: [Int]) : Int` que entrega "alguna" de las
opciones. Escribe un handler que siempre elija la primera y otro
que elija la última. ¿Cómo cambiaría la implementación si quisieras
un handler que explore **todas** las opciones (backtracking)?
Pista: necesitarías llamar a `resume` más de una vez. Eso es
*multi-shot* y vive bajo `resume_multishot`.

**12.6.** Toma un programa que tengas en otro lenguaje donde uses
inyección de dependencias para mockear servicios en tests. Anota
en pseudocódigo qué efectos declararías y cómo serían los
handlers de tests vs producción. ¿Cuánto código del programa
original sobrevive sin cambios?

**12.7.** Investiga la diferencia entre `resume` (one-shot) y
`resume_multishot` en la doc del lenguaje. ¿Por qué kaikai hace
que el caso común sea barato y obliga a marcar explícitamente el
caso caro?

**12.8.** Declara un efecto `MyLog` con una operación `info(msg:
String) : Unit` y un bloque `default { }` que puentee a un símbolo
C ficticio `my_log_info_to_stderr` vía `$extern_handler`. Después
escribe una función envoltorio `with_quiet_log` que silencie los
mensajes. Un `main` sin envoltorio dispara el default; un `main`
envuelto en `with_quiet_log` no. Compara con cómo harías lo mismo
en un lenguaje con inyección de dependencias clásica.

**12.9.** ¿Por qué el `Fail` de §12.5 no lleva bloque
`default { }`? Anota tres efectos hipotéticos (los tuyos o de
stdlib que imagines) y para cada uno decide si llevaría default.
Argumenta en una línea por qué sí o por qué no. Después toma el
argumento del retiro de `Fail` del stdlib (apéndice D §D.6) y
aplícalo a los tres: ¿cuál de ellos se expresaría mejor con
`Result[a, e]`?

**12.10.** Lee la declaración de `Stdout` en
`stdlib/io/console.kai` del repositorio del lenguaje. ¿Qué hace la
cláusula del default cuando el pipe está cerrado (`EPIPE`)? ¿Dónde
vive esa lógica: en kaikai o en el símbolo C al que puentea?

**12.11.** El capítulo 13 cubre fibras: tareas concurrentes
manejadas como efectos. Anota antes de leerlo: ¿qué operaciones
tendría que tener un efecto `Spawn`? ¿Qué decisión tomarías como
handler cuando una fibra hija aborta?
