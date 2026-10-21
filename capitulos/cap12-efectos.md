# Capítulo 12 · Efectos algebraicos

Aquí kaikai paga su novedad. Hasta ahora usaste tipos, pattern
matching, protocolos, unidades de medida, contratos: piezas
elegantes, pero las encontrarías parecidas en Haskell, en Rust,
en F#. Los **efectos algebraicos** distinguen a kaikai de casi
cualquier lenguaje de uso real hoy.

También son la razón por la que este proyecto existe, como
conté en el prólogo.

La idea es simple de enunciar y rara al principio: **una función
declara en su firma qué efectos usa, pero no cómo se realizan**.
Imprimir a pantalla, leer un archivo, fallar con un error,
suspender la ejecución, generar un número aleatorio: todos son
efectos. La función dice "necesito esta capacidad"; otro código
más arriba decide qué significa en este contexto. La separación
entre **qué** y **cómo** es el corazón del sistema.

Si esto te suena a *dependency injection*, a excepciones o a
generadores, mantén la idea cerca. Un solo mecanismo se parece a
tantas cosas porque, en la teoría detrás, todas son lo mismo. Los
efectos algebraicos son la generalización.

Ve despacio. La primera lectura es para que cada idea aparezca;
la intuición sólida llega cuando vuelvas un mes después y todo se
sienta obvio.

## 12.1 La fricción que los efectos resuelven

Antes de la sintaxis, piensa en los problemas concretos que los
efectos resuelven. Si reconoces el patrón en tu trabajo, sabrás
por qué vale la pena una herramienta nueva.

### Excepciones invisibles

En Java o Python, cualquier llamada a una función puede lanzar una
excepción y nada en la firma te lo dice. Lees el código y no sabes
qué puede fallar. Lo descubres en producción.

```python
def cargar_usuario(id):
    return db.get(id)   # ¿puede fallar? ¿con qué excepciones?
```

Java, con sus excepciones verificadas, intentó arreglarlo
obligándote a declarar `throws`. La gente escribió
`throws Exception` para callarlo, y volvimos al inicio. Los
lenguajes funcionales modernos (Rust, OCaml, kaikai con el
cap. 5) empujan a usar `Result` u `Option`: el costo de fallar
aparece en el tipo, y quien llama decide. Bien para fallas
locales, pero pesado cuando muchas funciones fallan: la firma se
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

Bob Nystrom le puso nombre en 2015, en un ensayo famoso:
**"What Color is Your Function?"**. `async` divide las funciones
en dos colores: rojas (`async`) y azules (no-async). Una roja
puede llamar a una azul, pero no al revés. Si tu función azul
necesita usar una roja, tienes que repintarla, y también a la que
la llamaba, y así hasta arriba. La infección no se queda local.

El ensayo no acusa a `async` de malo. Su punto es que estos
marcadores en la firma, cuando son específicos a un solo tipo de
efecto, crean sistemas paralelos que no componen. `async` no
compone con generadores: necesitas `async function*`. Tampoco
compone igual con excepciones (dentro de una función async se
vuelven rejected promises). Cada combinación nueva pide su propia
sintaxis.

Los efectos algebraicos atacan la raíz: **no hay colores
especiales**, hay una sola dimensión, la fila de efectos. `async`
deja de ser una propiedad sintáctica de la función y pasa a ser
un efecto entre otros. Y la fila crece sin sintaxis nueva:
`/ Async + Fail` no es más raro que `/ Async`.

### Inyección de dependencias

Para hacer testeable una función, le pasas como parámetro las
"cosas externas" que usa: el reloj, el logger, la base de datos.
Mocks en los tests, las reales en producción.

```java
class Procesador {
  public Procesador(Clock clock, Logger logger, DbClient db) { ... }
  public void run() { ... }
}
```

Funciona, pero ensucia las firmas y obliga a wiring manual. Y
cuando una función nueva necesita uno de los servicios, tienes que
agregarlo a los constructores de arriba en la jerarquía.

### El patrón común

Las tres frustraciones tienen la misma forma:

- Una función necesita una **capacidad** (la capacidad de fallar,
  la capacidad de suspenderse, la capacidad de loggear).
- La capacidad debe ser **explícita** (visible en el tipo) para no
  sorprender.
- La capacidad debe ser **provista por el contexto** (quien llama, test,
  framework) sin que la función se entere.
- Múltiples capacidades deben **componerse limpio**.

Los efectos algebraicos cubren los cuatro puntos con **una sola
construcción**. Lo que las excepciones, `async`/`await` y la
inyección de dependencias hacen por separado, y con frecuencia
mal, los efectos lo hacen con un mecanismo.

## 12.2 Declarar un `effect`

Un efecto es una **interfaz**: declara qué operaciones existen y
con qué firma, pero no cómo se implementan.

```kai
effect Log {
  log(msg: String) : Unit
}
```

Esto introduce un efecto `Log` con una operación `log` que recibe
un string y no devuelve nada útil. Cualquier función que llame a
`Log.log(...)` usa el efecto `Log`.

Fíjate en lo que falta: implementación. No hay cuerpo, no hay
`if`, no hay print; solo la firma. Esa es la diferencia
fundamental con un protocolo o una interfaz tradicional: el
efecto no decide nada, solo declara lo que se puede pedir.

Las operaciones se declaran sin `fn` y sin cuerpo: nombre,
parámetros y tipo de retorno. Un efecto puede tener varias:

```kai
effect Io {
  print(s: String) : Unit
  read_line()      : String
}
```

Dos dependencias pueden declarar cada una un efecto con el mismo
nombre sin pisarse: son efectos distintos que comparten una
palabra. Si importas los dos, eliges con un calificador, que va
en todos los lugares donde va el nombre: en la fila
(`/ trazas.Trace`), en la cabeza del handler
(`handle { ... } with trazas.Trace`) y en la operación misma
(`trazas.Trace.log(msg)`). Así `with ea.Emit` alcanza solo al de
`ea` y el de `eb` queda intacto. La regla general está en §8.2;
el nombre pelado sirve mientras nada colisione.

## 12.3 Llamar a una operación: la firma cambia

Para usar una operación, la llamas sobre el efecto:

```kai
fn greet(name: String) : Unit / Log {
  Log.log("hola, " ++ name)
}
```

Dos cosas nuevas:

- **`Log.log(...)`** es la sintaxis de invocación. El efecto da
  el namespace y la operación va después del punto.
- **`: Unit / Log`** en la firma. La barra introduce la **fila de
  efectos** (effect row): los efectos que la función necesita para
  correr. Sin ese `/ Log`, la función no compila: usa una
  capacidad que no declaró.

El sistema de tipos garantiza que **toda función que usa un efecto
lo declara**. Si llamas `Log.log(...)` desde una función sin
`/ Log`, el compilador la rechaza con un mensaje claro. Los
efectos son visibles en la firma, siempre.

Y vale recursivamente. Si `greet` usa `Log` y `main` llama a
`greet`, `main` también necesita `Log` en su firma, a menos que
**maneje** el efecto antes (eso es §12.4).

```kai
fn main() : Unit / Log {       # propaga el efecto
  greet("kaikai")
}
```

Es el contagio que conoces de `async`/`await`, pero sin colores:
la llamada no lleva sintaxis especial para "anunciar el efecto".
`Log.log(...)` es una llamada como cualquier otra. La disciplina
vive en la fila de la firma, y un efecto nuevo no introduce un
color incompatible con el resto: solo extiende la fila.

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

`Log + Fail` es la **fila** de efectos. La fila es un conjunto:
el orden no importa, y `Log + Fail` y `Fail + Log` son la misma
fila para el compilador. El `+` es solo sintaxis para
construirla.

(`Fail` no viene del stdlib: lo declaras en §12.5, igual que
`Log` en §12.2. Lo uso desde ya porque el nombre se explica
solo.)

Si esto te recuerda el capítulo 10, donde `m * s` y `s * m` eran
la misma unidad, no es coincidencia. Los efectos son otra de las
familias de etiquetas del §2.6: habitan su propio kind, con su
propia álgebra (la fila, donde el orden no cuenta y los
duplicados colapsan), y el compilador la aplica al unificar
firmas igual que el álgebra de unidades. En el capítulo 19
encuentras las dos como entradas del mismo catálogo.

## 12.4 Manejar un efecto con `handle ... with`

La parte interesante: **decidir qué significa un efecto** en un
punto del programa. Eso hace `handle ... with`.

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

Léelo así: "ejecuta este bloque, y cuando alguien dentro invoque
`Log.log`, hazlo de esta forma". El handler intercepta cada
llamada a `log`, decide qué pasa y reanuda con `resume(...)`.

Tres detalles:

- **`handle { body } with Effect { clauses }`** es una construcción
  de control, de la familia de `if` y `match`, y no una llamada a
  función. `handle` y `with` son palabras reservadas.
- **`body` es donde `Effect` queda manejado.** Adentro, llamar a
  `Log.log(...)` es legal sin tener `Log` en la fila de la función
  que envuelve, porque el handler la provee. Afuera del `with`, el
  efecto vuelve a ser exigido por el sistema de tipos.
- **`resume(())` continúa la ejecución del body** desde el punto
  donde se llamó `log`, con el valor que pasaste como argumento.

Lo notable: **`main` no declara `Log` en su firma**. El `handle`
lo "consume": el bloque de adentro lo usa, el `with` lo provee, y
la fila de `main` queda sin `Log`. El sistema de tipos sigue
estricto; el handler es la puerta por la que un efecto sale del
scope.

El efecto, su operación y su handler, en un programa completo:

```kai
# ejemplos/cap12/01_log_basico.kai
effect Log {
  log(msg: String) : Unit
}

# `greet` usa `Log.log` y por eso su firma lleva `/ Log`.
# La función no sabe si los mensajes van a la consola, a un
# archivo o a la nada: solo sabe que el efecto está disponible.

fn greet(name: String) : Unit / Log {
  Log.log("hola, " ++ name)
}

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

```
$ kai run ejemplos/cap12/01_log_basico.kai
[INFO] hola, kaikai
[INFO] hola, Eduardo
```

### El mismo body con dos handlers

Lo poderoso aparece cuando notas que `greet` no cambia. Con un
handler obtienes logs verbosos; con otro, silencio:

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

`greet` no se entera de la diferencia, ni se enteraría con un
handler que escribe a archivo, acumula en una lista o manda por
red. Es **agnóstica al handler**.

Esto reemplaza la inyección de dependencias. No hay constructor
que pasar ni servicio que mockear; el handler es la
implementación.

El mismo cuerpo bajo dos handlers, uno que imprime y otro que
calla:

```kai
# ejemplos/cap12/02_dos_handlers.kai
effect Log {
  log(msg: String) : Unit
}

fn greet(name: String) : Unit / Log {
  Log.log("hola, " ++ name)
}

fn main() {
  # Handler 1: imprime con prefijo.
  handle {
    greet("modo verboso")
  } with Log {
    log(msg, resume) -> {
      println("[INFO] " ++ msg)
      resume(())
    }
  }

  # Handler 2: descarta los mensajes.
  handle {
    greet("modo silencioso")
  } with Log {
    log(msg, resume) -> {
      resume(())
    }
  }

  println("(fin)")
}
```

```
$ kai run ejemplos/cap12/02_dos_handlers.kai
[INFO] hola, modo verboso
(fin)
```

## 12.5 `resume`: el handler decide qué pasa después

`resume` es la pieza que más confunde al inicio y la que más rinde
después. Es la **continuation** del body desde el punto de la
operación.

Cuando el body invoca `Log.log("hola")`, el control salta al
handler, que recibe dos cosas:

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

`Log.log` no devuelve nada útil, pero un efecto puede
**proveer** un valor:

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

Otro uso de la inyección de dependencias que desaparece: en vez de
pasar `nombre` como parámetro hasta el fondo del árbol de
llamadas, lo "preguntas" vía efecto, y el handler en `main` decide
qué responder. En tests, otro handler responde otra cosa.

La operación que devuelve un valor, y el `resume` que lo entrega:

```kai
# ejemplos/cap12/03_ask.kai
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
  println(mensaje)
}
```

```
$ kai run ejemplos/cap12/03_ask.kai
hola, mundo
```

### Handlers que NO llaman a `resume`

Si el handler **no** llama a `resume`, el body se descarta y el
valor del handler pasa a ser el de todo el `handle`. Así se
construyen las excepciones:

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
type del cap. 3): no tiene habitantes. No hay nada que pasar a
`resume`, así que el sistema de tipos garantiza que el body no
continúa después de `Fail.fail`. Si lo intentas, el compilador no
te deja escribir el código.

Las "excepciones" de kaikai son un caso particular del mecanismo
general. No hay sintaxis especial para `try/catch`; hay `handle`
y un efecto cuya operación devuelve `Nothing`.

El handler que no llama a `resume`: la operación corta el cuerpo
y el `handle` entero devuelve otro valor.

```kai
# ejemplos/cap12/04_fail.kai
effect Fail {
  fail(motivo: String) : Nothing
}

fn dividir(a: Int, b: Int) : Int / Fail {
  if b == 0 {
    Fail.fail("división por cero")
  } else {
    a / b
  }
}

fn main() : Unit / Stdout {
  let r = handle {
    let x = dividir(10, 2)
    let y = dividir(20, 0)  # aquí `Fail.fail` se invoca
    x + y  # nunca se evalúa
  } with Fail {
    fail(motivo, resume) -> {
      println("falló: " ++ motivo)
      0  # valor de reemplazo
    }
  }
  println("resultado: #{r}")
}
```

```
$ kai run ejemplos/cap12/04_fail.kai
falló: división por cero
resultado: 0
```

### Código después de `resume`

Hasta aquí `resume` fue siempre lo último de la cláusula. Eso es
**posición de cola**, y es lo que escribes el noventa y nueve por
ciento del tiempo: el handler decide algo, reanuda y se va.

Pero nada te obliga. Si pones código **después** del `resume`,
corre cuando el body ya terminó, y `resume` te devuelve el
resultado del `handle`:

```kai
# ejemplos/cap12/14_resume_no_tail.kai (fragmento)
log(msg, resume) -> {
  println("antes:   #{msg}")
  let v = resume(())
  println("después: #{msg} (handle = #{v})")
  v
}
```

```
$ kai run ejemplos/cap12/14_resume_no_tail.kai
antes:   empiezo
antes:   termino
después: termino (handle = 42)
después: empiezo (handle = 42)
resultado = 42
```

Lee el orden con calma, porque sorprende. Los dos "antes" salen
en el orden en que el body invocó `log`. Los dos "después" salen
**al revés**: primero el de `termino`, que fue el último en
suspenderse. Es el desarme de una pila, justo lo que esperarías
si piensas en `resume` como lo que es: el resto del cómputo.

Y fíjate en qué devolvió `resume`: `42`, el valor del body, y no
el `()` que `log` declara devolver. Fuera de posición de cola,
`resume` te da lo que salió del `handle` completo; el valor de
retorno de la operación lo recibe el body allá abajo. Confundir
los dos es el error clásico.

Una restricción acompaña: en un mismo camino de ejecución
`resume` se llama **una vez**. Dos llamadas son un error de
compilación:

```
error: `resume` may be called twice on one path
  = help: the continuation is one-shot
```

Reanudar dos veces el mismo cómputo es *multi-shot*, cuesta
copiar los frames de la fibra, y vive aparte bajo
`resume_multishot`.

¿Para qué sirve? Para todo lo que tenga que pasar *alrededor* del
resto del programa: cronometrar un tramo, cerrar un recurso,
contar lo que pasó adentro. En §12.8 conoces `initially` y
`finally`, el azúcar para el caso común.
## 12.6 Handlers con estado: el patrón `State`

Hasta aquí los handlers no tenían estado: decidían y reanudaban.
Pero un handler puede llevar **su propio estado** sin que el body
se entere. Esto reemplaza la mutación global.

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

Lo nuevo:

- **`State[T]` es paramétrico.** `T` es lo que el estado guarda;
  aquí, `Int`.
- **`with State[Int](0)`** instala el handler con estado inicial
  `0`. El argumento entre paréntesis es el valor inicial.
- **`state`** es un identificador especial disponible dentro de
  las cláusulas del handler. Se refiere al valor actual del estado.
- **`resume(value, new_state)`** tiene dos argumentos cuando el
  handler tiene estado: el valor de retorno de la operación, y el
  estado nuevo. `resume(value)` sin segundo argumento deja el
  estado igual.
- **`return(x) -> x`** se ejecuta cuando el body termina
  normalmente, con `x` como su resultado. Aquí se descarta el
  estado final y se devuelve solo `x`; si quisieras ambos,
  escribirías `return(x) -> (x, state)`.

El body no ve mutación: solo invoca las operaciones `get` y
`set` del efecto, sin saber dónde se guarda el valor. La
mutación vive entera dentro del handler, y desde afuera del
`handle` no se ve.

Con la misma forma se construyen `Reader` (entorno de lectura),
`Writer` (acumulación de salida), contadores, caches, sesiones.
Sin variables globales y sin propagar parámetros.

Un acumulador que vive en el handler, no en el cuerpo:

```kai
# ejemplos/cap12/05_state.kai
effect State[T] {
  get() : T
  set(v: T) : Unit
}

# Suma los elementos de una lista usando un acumulador "mutable"
# encapsulado en el handler.

fn suma(xs: [Int]) : Int {
  handle {
    list.foreach(xs, x => State.set(State.get() + x))
    State.get()
  } with State[Int](0) {
    get(resume) -> resume(state)  # devuelve el estado, sin cambios
    set(v, resume) -> resume((), v)  # devuelve (), estado nuevo = v
    return(x) -> x
  }
}  # descarta el estado final

fn main() : Unit / Stdout {
  println("suma([1,2,3,4,5]) = #{suma([1,2,3,4,5])}")
  println("suma([]) = #{suma([])}")
}
```

```
$ kai run ejemplos/cap12/05_state.kai
suma([1,2,3,4,5]) = 15
suma([]) = 0
```

## 12.7 `var`, `Ref[T]` y `Array[T]`: dos mecanismos distintos

`State[T]` es la herramienta general para llevar un valor que
cambia, pero escribir `handle ... with State[Int](0)` para cada
contador local sería tedioso. Por eso kaikai trae azúcar
sintáctica y, aparte, un efecto del stdlib para la memoria que
sobrevive al bloque. No los confundas.

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

Como el `handle` insertado queda **dentro del mismo bloque** que
el `var`, el efecto `State[Int]` se cierra ahí y no escapa a la
firma. Para quien la llama, `contar_pares` es `: Int`, sin
efectos.

El efecto no se enmascara: el `handle` está literalmente al lado
del `var`, y la fila se cierra donde la celda se declara.

Tampoco es caro: el compilador detecta el patrón "celda local con
`resume` de un disparo" y lo especializa a una posición del stack
frame, como una variable mutable de C. Costo cero frente al
código imperativo equivalente.

Un contador con `var`: el mismo `State[T]`, escrito como en un
lenguaje imperativo:

```kai
# ejemplos/cap12/10_var_local.kai
fn contar_pares(xs: [Int]) : Int {
  var n := 0
  list.foreach(xs, x => {
    if x % 2 == 0 {
      n := n + 1
    }
  })
  n
}

fn main() : Unit / Stdout {
  println("pares en [1..10] = #{contar_pares([1,2,3,4,5,6,7,8,9,10])}")
  println("pares en [] = #{contar_pares([])}")
}
```

```
$ kai run ejemplos/cap12/10_var_local.kai
pares en [1..10] = 5
pares en [] = 0
```

### `Mutable`: el efecto detrás de `Ref[T]` y `Array[T]`

`var` cubre celdas locales. A veces la memoria tiene que
**sobrevivir al bloque**: un arreglo que vas a devolver, una
celda que pasas entre funciones, una estructura que comparten
varias rutinas. Para eso kaikai trae dos tipos del stdlib,
`Ref[T]` y `Array[T]`, ambos bajo el efecto **`Mutable`**.

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
de indexación, pero el resto es paralelo a `Array[T]`. Para el
día a día tiene tres signos propios: `&v` arma la celda, `@r` la
lee y `r := v` la escribe.

Mira la firma de `rellenar`: `: Array[Int]`, **sin `Mutable`**,
aunque la función claramente muta.

`Mutable` sigue la disciplina de **efectos observables**: aparece
en la firma solo cuando la mutación es **visible para quien
llama**. Aquí no lo es. El arreglo se crea adentro, se llena
adentro y sale ya listo; quien lo recibe obtiene un valor armado
y no observa ninguna mutación.

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

Aquí `a` llega de afuera, y quien llama tiene una referencia al
mismo arreglo que la función modifica. La mutación es visible
para el caller, y la firma tiene que declararla.

Rige la regla de §12.3, como con cualquier efecto: toda función
que produce un efecto observable lo declara. No hay
"asignaciones secretas".

### `Mutable` versus `State[T]`

Ambos representan estado mutable:

- **`var` (que es `State[T]`)**: la celda vive dentro del
  bloque. No sobrevive a la función ni se pasa a otras rutinas;
  es un acumulador o contador local. La firma queda limpia.
- **`Mutable` con `Ref[T]` o `Array[T]`**: la memoria sobrevive
  al bloque o se comparte entre funciones. Aparece en la
  firma cuando la mutación es observable para quien llama.

Si pasas un `Ref[T]` o un `Array[T]` como argumento, o lo
devuelves después de mutarlo, estás en territorio de
`Mutable`. Si solo necesitas un contador local, es `var`.

## 12.8 Componer efectos: handlers anidados

Las funciones reales usan más de un efecto. Una que loguea y
acumula declara `/ Log + State[Int]`, y en `main` la manejas con
dos `handle` anidados:

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
Aquí no: `State` solo lee y escribe su estado, `Log` solo
imprime, y cualquier orden funciona. Pero con `Fail` adentro de
`State`, el orden decide si el estado sobrevive a una falla (Fail
externo) o se descarta (Fail interno). Cada combinación tiene una
semántica explícita y verificable.

Con `try/catch` y variables globales el orden es implícito y
depende del runtime. Aquí lo decides tú, en la forma en que
anidas los `handle`.

Dos efectos en el mismo cuerpo y dos handlers anidados que los
sirven:

```kai
# ejemplos/cap12/06_composicion.kai
effect Log {
  log(msg: String) : Unit
}

effect State[T] {
  get() : T
  set(v: T) : Unit
}

# `acumular` usa dos efectos: lee y escribe estado, y registra
# cada paso. La firma lo declara con `Log + State[Int]`.

fn acumular(xs: [Int]) : Int / Log + State[Int] {
  list.foreach(xs, x => {
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
      get(resume) -> resume(state)
      set(v, resume) -> resume((), v)
      return(x) -> x
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

```
$ kai run ejemplos/cap12/06_composicion.kai
[LOG] sumando 10
[LOG] sumando 20
[LOG] sumando 30
total = 60
```

### Limpieza garantizada: `initially` y `finally`

El anidamiento trae un problema que las excepciones también
tienen y resuelven a medias. Si un handler externo abandona el
`resume`, como el `Fail` de §12.5, el body interior nunca vuelve.
La línea que escribiste *después* del `handle` para cerrar un
archivo, soltar un lock o devolver una conexión al pool no corre.
El salto no local se la comió.

Dos cláusulas más cierran ese hueco:

- `initially { }` corre una vez, cuando el handler se instala,
  antes del body. Su valor es el estado del handler, legible como
  `state` en las cláusulas. Ocupa el mismo espacio que la forma
  `with Eff(init)`: se escribe una o la otra, nunca las dos.
- `finally { }` corre cuando el scope se desarma, **por cualquier
  camino**: retorno normal, una cláusula que abandona `resume`
  (incluida una instalada más afuera, cuyo salto se brinca este
  scope), y cancelación cooperativa (cap. 13). No corre en
  `panic`, que aborta el proceso en vez de desarmarlo.

Juntas son el *bracket* de adquirir/liberar, por construcción y
no por convención: la adquisición vive **dentro** de la
construcción que garantiza la liberación, así que no hay ventana
en la que el recurso esté abierto y sin protección.

```kai
# ejemplos/cap12/12_limpieza.kai
effect Fail {
  fail(motivo: String) : Nothing
}

effect Conexion {
  consultar(sql: String) : String
}

fn reporte() : String / Conexion + Fail {
  let _ = Conexion.consultar("SELECT total FROM ventas")
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
nunca terminó. Aun así la conexión se cerró, y *antes* de que el
valor de reemplazo llegara a `main`: el desarme del scope interior
ocurre en el camino del salto, no después.

Ten presente esta regla: **la limpieza corre en el contexto de
evidencia del momento en que se instaló**. Si el `finally`
realiza un efecto, este se despacha a los handlers vivos cuando
el handler se instaló, no a los del punto de salto, cuyos marcos
ya no existen. En la práctica, un `finally` no puede realizar el
efecto que su propio handler descarga. Te lo dice el compilador
("effect not handled"), y nunca se convierte en un ciclo en
tiempo de ejecución.

`finally` no recibe parámetros y su valor se descarta: corre por
su efecto. Para transformar el resultado del `handle` está
`return(x)`.

Dos detalles de convivencia. `initially` y la forma
`with Eff(init)` ocupan el mismo espacio, así que escribir las
dos es un error de parseo. Y ninguna de las dos palabras es
reservada: son contextuales, así que un efecto tuyo puede
declarar una operación llamada `finally` sin que nada se rompa.

## 12.9 Instancias nombradas: el handler como valor

Hasta aquí, cada operación encuentra su handler por el nombre del
efecto: `Log.log(...)` sube hasta el `handle ... with Log` más
cercano. ¿Y si necesitas **dos** handlers del mismo efecto, vivos
a la vez, y quieres elegir a cuál le hablas?

Le das un nombre a cada instancia:

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

Lo interesante empieza cuando el capability viaja: una instancia
nombrada **se puede pasar como argumento**:

```kai
fn add(c1: Cell, c2: Cell, dst: Cell) : Unit =
  dst.set(c1.get() + c2.get())
```

Mira esa firma con calma. `Cell` aparece como **tipo de
parámetro**, no en la fila de efectos. Son dos modos de pedir lo
mismo:

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

`add` suma las celdas que le den, sin saber cuál es cuál. Sin
instancias nombradas tendrías que declarar tres efectos idénticos
(`CellA`, `CellB`, `CellDst`) y manejar cada uno por separado.
Ceremonia pura, y no escala.

Una restricción importante: el capability es **de segunda
clase**. Puede bajar por la pila, como argumento o como receptor
de operaciones, pero no puede *escapar*: no lo guardas en un
record, no lo devuelves, no lo capturas en una closure que
sobreviva al `handle`, no lo cruzas a una fibra con `spawn`. Un
handler es una promesa con alcance léxico; lo que necesita vivir
más que su `handle` es un `Ref[T]` bajo `Mutable` (§12.7) o un
actor (capítulo 14).

Si vienes de la inyección de dependencias, esto te suena: pasar
el capability como parámetro **es** inyectar la dependencia, con
la diferencia de que el tipo la rastrea y el compilador rechaza
los usos que la harían escapar de su vida útil. Y si el wiring
explícito te estorba, la fila de efectos sigue ahí: son los dos
extremos del mismo mecanismo, y eliges en cada llamada.

## 12.10 Alias de filas de efectos

Cuando una combinación aparece muchas veces, le das un nombre con
`type`:

```kai
effect Log    { log(msg: String) : Unit }
effect Audit  { audit(usuario: String, accion: String) : Unit }

type Tracing = Log + Audit
```

Desde ahí, `: Unit / Tracing` equivale a `: Unit / Log + Audit`.
El alias es **transparente**: no
introduce un efecto nuevo, solo abrevia la fila.

```kai
fn realizar_compra(usuario: String, monto: Int) : Unit / Tracing {
  Log.log("inicio compra")
  Audit.audit(usuario, "compra($#{monto})")
  Log.log("fin compra")
}
```

Una restricción: los alias son **cerrados**. No puedes escribir
`type WithIo[e] = Io + e` (con variable de fila), lo que le
ahorra al compilador complicaciones en la unificación.

Un alias usado en varias firmas, donde se nota lo que ahorra:

```kai
# ejemplos/cap12/07_alias.kai
effect Log {
  log(msg: String) : Unit
}

effect Audit {
  audit(usuario: String, accion: String) : Unit
}

# `Tracing` agrupa los dos efectos de instrumentación.
type Tracing = Log + Audit

fn realizar_compra(usuario: String, monto: Int) : Unit / Tracing {
  Log.log("inicio: compra de #{usuario} por #{monto}")
  Audit.audit(usuario, "compra($#{monto})")
  Log.log("fin: compra de #{usuario}")
}

fn main() : Unit / Stdout {
  handle {
    handle {
      realizar_compra("ada", 100)
      realizar_compra("turing", 250)
    } with Audit {
      audit(usuario, accion, resume) -> {
        println("[AUDIT] #{usuario}: #{accion}")
        resume(())
      }
    }
  } with Log {
    log(msg, resume) -> {
      println("[LOG] " ++ msg)
      resume(())
    }
  }
}
```

```
$ kai run ejemplos/cap12/07_alias.kai
[LOG] inicio: compra de ada por 100
[AUDIT] ada: compra($100)
[LOG] fin: compra de ada
[LOG] inicio: compra de turing por 250
[AUDIT] turing: compra($250)
[LOG] fin: compra de turing
```

## 12.11 Default handlers: el efecto trae el suyo

Hasta aquí escribiste a mano cada `handle`. Pero en algunos
efectos una implementación es tan obvia que escribirla cada vez
es ceremonia pura: si tu efecto es `Log` y lo "razonable" es
escribir en stderr con timestamp, querrías que esa
implementación venga con el efecto.

Para eso declaras un **bloque `default { }`** dentro del efecto.
Es lo mismo que un `handle ... with`, pero vive al lado de las
operaciones, y el compilador lo instala alrededor de `main`
cuando nadie maneja el efecto a mano.

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

Las cláusulas del `default` tienen la **misma forma** que las de
un `handle`: nombre de operación, parámetros, `resume`, flecha,
cuerpo. Cambia dónde viven y quién las dispara.
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

Ese wrapping no lo escribes tú: el compilador lo deriva del bloque
`default` y lo emite al entrar al programa.

### `$extern_handler`: el sigil y el puente a C

El cuerpo de cada cláusula del ejemplo anterior es
`$extern_handler("kai_default_log_info")`.

`$` es un **sigil**: un carácter que marca una forma sintáctica
especial. En kaikai introduce un **compiler intrinsic**, una
construcción que el compilador resuelve directamente en vez de
buscar una función definida en código kaikai. La forma general es
`$nombre(args)`. El conjunto de intrinsics es cerrado, y el único
que aparece en código fuente, tuyo o del stdlib, es
`$extern_handler`.

`$extern_handler("kai_default_log_info")` significa: "el cuerpo
de esta cláusula es una llamada al símbolo C `kai_default_log_info`".
El compilador no busca una función kaikai con ese nombre; emite
directo una llamada al runtime de C enlazado al programa.

Es el puente entre los efectos algebraicos y el mundo concreto:
archivos, sockets, syscalls. Las primitivas del
sistema operativo viven en C; los efectos viven en kaikai;
`$extern_handler` los conecta.

### Cuándo dispara el default y cuándo no

La regla de búsqueda es la de §12.4, con un escalón extra al
final:

1. El `handle ... with Eff` más cercano que cubre la operación gana.
2. Si no hay handle envolvente y la operación está en la fila de
   `main`, el compilador instala el default del efecto.
3. Si ni siquiera el default cubre la operación, el compilador
   rechaza el programa al typecheckar `main`.

El default **solo** se instala cuando la operación escaparía a
`main`. Si tu función está dentro de un `handle`, gana el handle.
Sin ambigüedad ni precedencias sorpresivas: lo más cercano
siempre gana.

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

Para controlar la salida (silenciar en tests, redirigir a
archivo, capturarla para asertar contra ella), pones tu propio
`handle ... with Stdout`, y dentro del bloque el default no
participa. **Lo más cercano gana**: tu `handle` está más cerca
que el wrapping implícito de `main`.

### Tu propio default: el ejemplo completo

Si equipas tu propio efecto con un default, los programas que
solo usan `main` se ven igual de simples:

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

fn main() : Unit / Stdout + MyLog {
  greet("kaikai")  # sin handle: dispara el default
  let r = handle {
    greet("ada")
    7
  } with MyLog {
    info(msg, resume) -> resume(())  # silencia adentro del handle
  }
  println("result: #{r}")
}
```

La primera llamada a `greet` no tiene un `handle` alrededor, así
que dispara el default: el runtime de C escribe en stderr una
línea con timestamp, `[2026-10-18T01:54:44Z] INFO  hola, kaikai`.
Adentro del `handle ... with MyLog` ganan las cláusulas
explícitas y el saludo a `ada` queda silenciado. Por stdout sale
solo `result: 7`. `greet` no se entera: para ella, `MyLog` es lo
que el contexto decida.

### Cuándo no hay default: el efecto sin red

No todos los efectos traen `default`. El `Fail` que declaraste en
§12.5 es el contraejemplo claro: si una operación puede abortar
el programa, no quieres que olvidarte de manejarla sea legal.
Como no lleva bloque `default`, una función que produce `/ Fail`
tiene que ser manejada en algún lado antes de `main`, o el
compilador la rechaza con un mensaje claro.

¿Por qué `Fail` vive aquí, declarado en el propio archivo, y no
en el stdlib? Un efecto de falla no aporta nada que
`Result[a, e]` con `!` postfijo no dé mejor: no hay una sola fila
`/ Fail` en todo el stdlib. Y su forma, una operación que
devuelve `Nothing`, es justamente la que *no* puede expresar la
falla interesante, aquella en la que el consumidor elige si
saltar o abortar. Para eso el efecto tiene que devolver `Unit` y dejar que
el handler decida si llama a `resume`. El apéndice D tiene la
tabla completa.

Como ejemplo, en cambio, es inmejorable: la forma más corta de
mostrar una operación que no vuelve.

Lo mismo vale para `State[T]`, `Reader[T]`, `Writer[W]`: efectos
genéricos sin una implementación razonable fuera de contexto, así
que pedirte que la escribas es disciplina y no ceremonia.

La regla mental: un efecto trae `default` cuando hay **una sola**
implementación obvia (escribir a `stdout`, leer del reloj del
sistema, generar números pseudo-aleatorios). Si "razonable"
depende del programa, no hay default y lo provees tú.

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

El stdlib lo usa para `with_reader(env) { body }`,
`with_writer { body }` y `with_mailbox { body }`. A diferencia de
un default, que vive en la declaración del efecto, la envoltura
es **explícita en el código**: quien lee `main` ve la línea, abre
la función y sabe qué hace.

Si tu efecto tiene un default razonable para producción y otro
para tests, expón los dos como funciones envoltorio
(`with_test_log`, `with_quiet_log`) y deja que `main` use el
default. Los tests llaman a la envoltorio.

La envoltorio en un programa: el cuerpo no nombra ningún handler
y la función decide cuál se instala.

```kai
# ejemplos/cap12/09_wrapper_default.kai
effect Log {
  log(msg: String) : Unit
}

fn greet(name: String) : Unit / Log {
  Log.log("hola, " ++ name)
}

# El "default" del usuario: una función que toma un body y lo
# corre con el handler estándar para Log.
fn with_default_log[A](body: () -> A / Log) : A / Stdout {
  handle {
    body()
  } with Log {
    log(msg, resume) -> {
      println("[LOG] " ++ msg)
      resume(())
    }
  }
}

fn main() {
  # Uso 1: con el default. greet no sabe nada del handler.
  with_default_log(() => {
    greet("kaikai")
    greet("ada")
  })

  # Uso 2: el caller decide otro handler. with_default_log no
  # participa.
  handle {
    greet("modo silencioso")
  } with Log {
    log(msg, resume) -> resume(())
  }

  println("(fin)")
}
```

```
$ kai run ejemplos/cap12/09_wrapper_default.kai
[LOG] hola, kaikai
[LOG] hola, ada
(fin)
```

## 12.12 Los handlers del stdlib son código kaikai

Cuando `println("hola")` simplemente funciona, es fácil imaginar
que el compilador trae un caso especial para `Stdout`. No lo
trae. Los handlers que el runtime instala alrededor de `main`
para `Stdout`, `Stdin`, `Random`, `Clock`, `File`, `Env`, `NetTcp`
y los demás están escritos en **stdlib kaikai normal**: cada uno
es un `effect ... { ops; default { ... } }` con el mismo sigil
`$extern_handler` que usarías para conectar tu efecto con C.

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

El motivo es práctico: el AST es la única fuente de verdad, sin
tablas internas que mantener en paralelo, y tus efectos obtienen
las mismas garantías que los del stdlib. Si tu efecto declara `default { }` con
`$extern_handler`, el compilador lo instala como builtin.

La consecuencia práctica: **puedes leer cómo está implementado
`Stdout`**. `kai doc effects.Stdout` te muestra su firma y su
default; el efecto es código kaikai como el tuyo. Si dudas de la
semántica del default (¿qué pasa si el pipe está cerrado?, ¿quién
captura `EPIPE`?), la respuesta vive en la cláusula
`print(s, resume) -> ...` o en el símbolo C al que puentea. El
runtime no tiene comportamiento secreto aparte del código que
puedes leer.

La regla otra vez, para amarrar el modelo: el compilador resuelve
un efecto buscando, en orden, (1) el `handle ... with` más cercano,
(2) el `default { }` block del efecto si la operación escapa a
`main`, (3) error de compilación. Los handlers del stdlib no son
una cuarta categoría; son instancias de (2).

### Por qué el sigil tiene un nombre raro

`$extern_handler` puede sonar largo porque el sigil abre un
sistema: `$` reserva el espacio de nombres de una **familia
cerrada** de intrinsics, operaciones que implementa el
compilador y que ningún código kaikai puede definir. El
compilador usa otros miembros de la familia por dentro, al
transformar un `var` o un `resume` fuera de cola; en código
fuente solo aparece `$extern_handler`. Un nombre que no está en
la familia, como `$os_name()`, es un error de compilación. El
sigil garantiza que un intrinsic nunca se confunda con una
llamada a función.

Si nunca conectas un efecto a C, nunca escribirás
`$extern_handler`. Pero cuando lo veas en el stdlib sabrás qué
es: una cláusula que cede el cuerpo a un símbolo del runtime,
con la misma sintaxis que cualquier otro handler.

## 12.13 Generadores: la continuación como valor

En la apertura te pedí que, si esto te sonaba a generadores,
mantuvieras la idea cerca. La promesa se paga con una pieza que
ya conoces.

En §12.5 aprendiste qué puede hacer un handler con `resume`:
llamarlo, en posición de cola o no, y el body sigue; o no
llamarlo, y el body se descarta. Falta la más interesante:
**guardarlo**.

Un `resume` guardado es un valor como cualquier otro. Lo metes en
un constructor, lo devuelves y lo llamas más tarde desde otro
lugar del programa. Eso es un generador.

```kai
# stdlib/gen.kai
pub effect Yield[t] { yield(v: t) : Unit }

pub type Gen[t, e] = Done | Next(t, Cont[Unit, Gen[t, e], e])

pub fn generate[t, e](body: () -> Unit / Yield[t] + e) : Gen[t, e] / e =
  handle { body(); Done } with Yield[t] { yield(v, resume) -> Next(v, resume) }
```

Lee la cláusula despacio, porque ahí está todo: `yield(v, resume)
-> Next(v, resume)`. El handler no reanuda nada: empaqueta el
elemento con el resto del cómputo y lo devuelve. Quien recibe ese
`Next(v, k)` tiene en la mano el primer elemento y una función
que, cuando él decida, produce el siguiente.

El `e` de las tres firmas lo retomas más abajo; por ahora léelo
como «los efectos que el productor haga además de `Yield`».

### El productor no sabe que es un generador

```kai
# ejemplos/cap12/13_generadores.kai (fragmento)
fn naturales(desde: Int) : Unit / Yield[Int] = {
  Yield.yield(desde)
  naturales(desde + 1)
}
```

Es recursión corriente, como la que escribiste en el capítulo 6.
Sin palabra clave especial, sin máquina de estados, sin tipo de
retorno raro. La función no termina nunca, y está bien: corre en
su propio segmento de stack y avanza solo cuando alguien le pide
el elemento siguiente.

Pedir los elementos a mano deja ver la máquina:

```kai
let g = generate { naturales(10) }
match g {
  Done -> println("generador vacío")
  Next(a, k) -> {
    println("primero: #{a}")
    match k(()) {
      Done       -> println("se acabó")
      Next(b, _) -> println("segundo: #{b}")
    }
  }
}
```

Ese `k(())` corre `naturales` desde donde se había quedado hasta
su `Yield.yield` siguiente. Si nunca llamas a `k`, el productor no
vuelve a correr: descartar un `Gen` descontinúa a su productor y
libera su segmento.

### En la práctica, los pipes

Nadie escribe `match` sobre `Next` en código de todos los días.
`gen` trae las etapas con las firmas canónicas, así que los pipes
del §6.4 funcionan igual que sobre listas y streams:

```kai
let suma = generate { naturales(1) }
  |  (n => n * n)              # map lazy: cuadrados
  |? (n => n % 2 == 1)         # filter lazy: los impares
  |> take_until(n => n > 100)  # corta en el primero que pasa 100
  |> reduce((a, b) => a + b)
```

```
$ kai run ejemplos/cap12/13_generadores.kai
primero: 10
segundo: 11
suma de cuadrados impares hasta 100: Some(286)
```

`naturales(1)` no termina; `take_until` corta. Entre los dos no
hay lista intermedia, y el productor nunca generó un elemento que
nadie iba a mirar. El `Some` está porque `reduce` devuelve
`Option`: un generador puede estar vacío, y el tipo lo dice en vez
de inventar un cero.

Si en el capítulo 6 te quedó la duda de cuándo usar `stream` y
cuándo esto, depende de qué lado estás. `stream` consume algo que
ya existe, una lista o un archivo, y es una receta re-ejecutable.
`gen` es para cuando el productor lo escribes tú.

Y si lo escribes tú pero es puro, no usas ninguno de los dos:
usas una `Seq`, la secuencia perezosa del §6.4, cuyas celdas se
computan una vez y quedan compartidas. `gen` se distingue porque
su productor puede hacer efectos: es el único de los tres que los
lleva en la fila. Las etapas de una `Seq` tienen que ser puras,
así que una `Seq` no lee un archivo ni le pregunta nada a nadie.

### Los efectos del productor, y quién los sirve

Mira otra vez las tres firmas: el `e` de todas es la fila del
productor. Un generador no le exige a su body que sea puro. Lo
que el productor haga además de `Yield` viaja en el tipo, y se
realiza **donde alguien avanza el generador**, no donde se
creó: los handlers que lo sirven son los que rodean al consumidor.

```kai
# ejemplos/cap12/15_productor_con_efectos.kai (fragmento)
fn ruidoso(n: Int) : Unit / Yield[Int] + Stdout = {
  println("  produzco #{n}")
  Yield.yield(n)
  ruidoso(n + 1)
}
```

```
$ kai run ejemplos/cap12/15_productor_con_efectos.kai
los efectos del productor corren al avanzarlo
  produzco 1
  produzco 2
  produzco 3
suma = Some(6)
```

`ruidoso` no termina nunca y el `println` es suyo, pero las tres
líneas salen porque el consumidor pidió tres elementos. No hay una
cuarta: `take_until` cortó en el `3` y el productor no alcanzó a
dar un paso más.

Queda una pregunta incómoda. Si el consumidor para cuando quiere
y el productor tenía un archivo abierto, ¿quién lo cierra? El
consumidor no: solo deja de llamar a `k`. La respuesta es la de
§12.8, y llega sin que el consumidor sepa que existe.

```kai
# ejemplos/cap12/16_soltar_el_generador.kai (fragmento)
fn con_recurso() : Unit / Yield[String] + Stdout =
  handle {
    leer_todo()
  } with Bitacora {
    initially { println("  abriendo el archivo"); 1 }
    finally   { println("  cerrando el archivo") }
    linea(resume) -> resume("línea #{state}", state + 1)
    return(x)     -> x
  }
```

```
$ kai run ejemplos/cap12/16_soltar_el_generador.kai
soltar el generador corre la limpieza
  abriendo el archivo
  cerrando el archivo
  leí 'línea 1' y no pido más
el productor ya no existe
```

El `finally` corrió solo, cuando el `Gen` quedó sin dueño y antes
de que `main` siguiera. Fíjate en el orden: el archivo se cierra
antes de que el consumidor imprima lo que leyó. El patrón
`Next(l, _)` no liga la continuación, así que el generador queda
sin dueño en el `match` mismo. Descartar un generador lo desarma.

Esa es la división del trabajo que propone la fila. No te prohíbe
hacer I/O en un productor, una regla cómoda de implementar y
molesta de usar; te dice en el tipo qué efectos tienes que servir
para avanzarlo, y te garantiza que soltarlo a mitad de camino es
una operación limpia.

### Por qué esto importa más de lo que parece

Python necesitó una palabra clave para los generadores y después
descubrió que no componía con `async`: por eso existen
`async def` y `async function*`. Cada capacidad nueva pidió
sintaxis nueva, y las combinaciones, más sintaxis todavía. Es la
queja del §12.1 con otro disfraz.

Aquí el mecanismo completo cabe en un centenar de líneas de
stdlib. El compilador no conoce `Yield`: no hay palabra clave
`yield`, hay una operación que se llama así. Y compone con todo
lo demás porque no es un caso especial de nada.

Eso compras cuando la continuación es un valor de primera clase:
generadores que nadie tuvo que agregarle al lenguaje.

## 12.14 Caso de estudio: procesador de configuración

Cerramos con un ejemplo que mezcla los tres patrones que ya usaste:
logueo, estado, fallo. El programa recibe líneas `clave=valor`,
las parsea, registra cada paso, cuenta cuántas pasaron y aborta
si alguna no tiene el formato esperado.

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

`procesar` declara los tres efectos y los usa libremente: parsea
(puede fallar), registra (loguea), acumula (estado). Pero no
decide nada sobre el contexto en que corre.

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
      -1
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

Si una línea es inválida, el `Fail` exterior la atrapa, imprime el
motivo y `n` queda en `-1`. El `Log` y el `State` interiores ya
emitieron lo que alcanzaron antes del fallo.

Los tres patrones cooperan, cada uno con su parte, y `procesar`
es **directamente testeable**: sin archivos, sin IO, sin mocks.
En un test, los tres handlers cambian de implementación: el `Log`
acumula en una lista en vez de imprimir, el `Fail` propaga en un
`Result`, el `State` parte del valor que el test quiera.

## 12.15 Filosofía: tres ideas que vale recordar

Si te parecen muchas piezas, quédate con las tres ideas que
sostienen todo lo demás:

1. **Los efectos son visibles en el tipo.** Si una función puede
   fallar, suspenderse, mutar, o llamar a IO, su firma lo dice.
   Sin excepciones invisibles, sin `async` infeccioso, sin
   dependencias ocultas.

2. **El handler decide qué pasa.** El cuerpo de una función
   declara que necesita una capacidad; el handler del contexto
   decide cómo materializarla. Ese desacople reemplaza la
   inyección de dependencias, el mocking y la configuración
   global.

3. **Costo cero cuando no se usa.** El compilador resuelve los
   handlers en tiempo de compilación cuando puede (la mayoría de
   los casos), y el código generado es tan rápido como si hubieras
   escrito un `if` directo, sin sobrecarga estructural por tener
   efectos en el tipo. Es la misma promesa de las unidades
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

Si todavía no estás cómodo, no te preocupes. Los efectos son la
pieza que más tarda en asentarse. Volverás a este capítulo varias
veces, y cada lectura agarra una capa más.

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

**12.3.** El caso de estudio §12.14 imprime con `[LOG]` cada
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
argumento por el que el stdlib no declara un efecto `Fail`
(apéndice D §D.6) y aplícalo a los tres: ¿cuál de ellos se
expresaría mejor con `Result[a, e]`?

**12.10.** Lee la declaración de `Stdout` en
`stdlib/io/console.kai` del repositorio del lenguaje. ¿Qué hace la
cláusula del default cuando el pipe está cerrado (`EPIPE`)? ¿Dónde
vive esa lógica: en kaikai o en el símbolo C al que puentea?

**12.11.** El capítulo 13 cubre fibras: tareas concurrentes
manejadas como efectos. Anota antes de leerlo: ¿qué operaciones
tendría que tener un efecto `Spawn`? ¿Qué decisión tomarías como
handler cuando una fibra hija aborta?
