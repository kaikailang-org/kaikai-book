# Capítulo 12 · Efectos algebraicos

Este es el capítulo donde kaikai paga su novedad. Hasta ahora
hemos visto tipos, pattern matching, protocolos, unidades de
medida, contratos. Todas son piezas elegantes pero no únicas: las
encontrarías parecidas en Haskell, en Rust, en F#. Los **efectos
algebraicos** son lo que distingue a kaikai de casi cualquier
lenguaje de uso real hoy.

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
las funciones en dos colores. Las rojas (`async`) y las azules
(no-async). Una roja puede llamar a una azul, pero una azul no
puede llamar a una roja. Si tienes una función azul y necesitas
usar una roja adentro, tienes que repintar la azul. Y la que la
llamaba. Y así hasta arriba. Es una infección que no se queda
local.

El punto del ensayo no es que `async` sea malo. Es que esta clase
de marcadores en la firma, cuando son específicos a un solo tipo
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
constructor que pasar, no hay servicio que mockear: el handler ES
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
    let y = dividir(20, 0)    # acá se invoca Fail.fail
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

Hasta acá los handlers fueron sin estado: solo decidían qué hacer
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

## 12.7 Componer efectos: handlers anidados

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
globales`: ahí el orden es implícito y depende del runtime. Acá es
explícito y lo decides en la firma de los `handle`.

## 12.8 Alias de filas de efectos

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

## 12.9 Tu propio handler por defecto: el patrón envoltorio

¿Y si quieres que **tu** efecto venga con un handler "preinstalado",
como `println` viene con `Stdout`? La respuesta corta es que en
v1 no se puede: el runtime instala handlers por defecto solo para
los efectos del stdlib (`Stdout`, `Stdin`, `Env`, `File`,
`Random`, `Time`, etc.), y la capacidad de registrar handlers
automáticos para efectos propios está fuera del alcance.

El patrón idiomático para acercarse es escribir una **función
envoltorio** que aplica el handler estándar:

```kai
effect Log {
  log(msg: String) : Unit
}

fn with_default_log[A](body: () -> A / Log) : A {
  handle {
    body()
  } with Log {
    log(msg, resume) -> {
      println("[LOG] " ++ msg)
      resume(())
    }
  }
}
```

`with_default_log` toma un body que necesita `Log` y devuelve
**el mismo tipo del body**, ya manejado. Quien lo use, recibe el
handler estándar sin escribirlo:

```kai
fn main() {
  with_default_log(() => {
    greet("kaikai")
    greet("ada")
  })
}
```

Quien quiera otro comportamiento, simplemente no llama a
`with_default_log` y escribe su propio `handle`. La diferencia
con un handler "automático" es la línea extra que envuelve al
body, pero a cambio el comportamiento por defecto es **explícito
y opcional**, no oculto en el runtime. Es lo que el stdlib mismo
hace para construcciones como `try { body }` o `with_state(0)
{ body }`: la sintaxis de trailing lambda lo deja casi tan
limpio como un handler implícito:

```kai
fn main() {
  with_default_log { ->
    greet("kaikai")
    greet("ada")
  }
}
```

Hay un valor pedagógico además del práctico: cuando el handler
por defecto vive en una función nombrada del módulo del efecto,
el lector que se topa con `with_default_log` puede ir a leerla y
ver exactamente qué hace. El runtime no tiene esa transparencia
para sus propios defaults.

Si tu efecto tiene un default razonable para producción y otro
distinto para tests, expón los dos como `with_default_log` y
`with_test_log`, ambas con la misma firma. Quien escribe tests
elige el segundo; quien escribe `main`, el primero. El módulo
del efecto se vuelve el catálogo de "configuraciones canónicas".

## 12.10 Handlers por defecto del runtime

Hay efectos que un programa usa tanto que `kai` los maneja sin que
los declares. El caso más claro es `println`: imprime a la salida
estándar, lo cual es un efecto. ¿Por qué no aparece en cada firma?

```kai
fn hola() {
  println("hola")
}

fn main() {
  hola()
}
```

Esto compila. La razón: `println` está respaldado por un handler
de `Stdout` que kaikai instala automáticamente alrededor de
`main`. Para programas simples, no tienes que pensar en el
efecto. Cuando quieras controlarlo (silenciar en tests, redirigir
a archivo, capturar la salida), instalas tu propio handler de
`Stdout`, y dentro del `handle` el de kaikai no participa.

La regla: **los handlers más cercanos al uso ganan**. El handler
implícito del runtime es el más lejano, así que es el último
recurso. Cualquier `handle` que pongas más cerca interceptará
primero.

Otros efectos con handlers por defecto en `main`: `Stdin`,
`Random`, `Time`, `Env`. Esto es para tener programas
"hola-mundo" sin firmas pesadas. La doc del cap. 12 del manual
del lenguaje detalla cuáles son.

## 12.11 Caso de estudio: procesador de configuración

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

## 12.12 Filosofía: tres ideas que cargan el sistema

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
lenguaje (filas en vez de listas, alias), y handlers por defecto
para que los programas simples no carguen ceremonia. Pero la idea
de base es vieja y sólida.

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

**12.3.** El caso de estudio §12.11 imprime con `[LOG]` cada
entrada. Cambia el handler de `Log` para que en vez de imprimir,
acumule los mensajes en una lista y los devuelva como parte del
resultado final, junto con `n`. Pista: necesitas otro `State`.

**12.4.** Construye un efecto `Choice` con una operación
`choose(opciones: [Int]) : Int` que entrega "alguna" de las
opciones. Escribe un handler que siempre elija la primera y otro
que elija la última. ¿Cómo cambiaría la implementación si quisieras
un handler que explore **todas** las opciones (backtracking)?
Pista: necesitarías llamar a `resume` más de una vez. Eso es
*multi-shot* y vive bajo `resume_multishot`.

**12.5.** Toma un programa que tengas en otro lenguaje donde uses
inyección de dependencias para mockear servicios en tests. Anota
en pseudocódigo qué efectos declararías y cómo serían los
handlers de tests vs producción. ¿Cuánto código del programa
original sobrevive sin cambios?

**12.6.** Investiga la diferencia entre `resume` (one-shot) y
`resume_multishot` en la doc del lenguaje. ¿Por qué kaikai hace
que el caso common sea cheap y obliga a marcar explícitamente el
caso caro?

**12.7.** Toma `Log` de §12.9 y agrega un segundo "default":
`with_silent_log`, que descarta los mensajes. Después escribe una
función que use `Log` y pruébala con los dos handlers sin
modificar la función. Compara con cómo harías lo mismo en un
lenguaje con inyección de dependencias clásica.

**12.8.** El capítulo 13 cubre fibras: tareas concurrentes
manejadas como efectos. Anota antes de leerlo: ¿qué operaciones
tendría que tener un efecto `Spawn`? ¿Qué decisión tomarías como
handler cuando una fibra hija aborta?
