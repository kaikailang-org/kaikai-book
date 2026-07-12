# Capítulo 6 · Funciones y pipelines

Hasta aquí fuiste viendo funciones a medida que las
necesitábamos: las primeras en el tour, las del cap. 3 con
sus dos formas de cuerpo, las recursivas del cap. 5 que
descomponen tipos suma. Este capítulo pone todo junto y
agrega lo que faltaba: cómo declarar funciones con cuidado,
cómo escribir lambdas, qué son las funciones de orden
superior, y los cuatro operadores pipe que kaikai usa para
encadenar transformaciones.

Vamos también a ver con detalle algo que kaikai promete y que
muy pocos lenguajes garantizan en serio: la **eliminación de
llamadas en posición de cola**. Esa garantía es lo que te
deja escribir loops sin `for` ni `while` y dormir tranquilo.

## 6.1 Declaración

Una función se declara con `fn`, los parámetros tipados, el
tipo de retorno, y un cuerpo separado por `=`:

```kai
fn doble(x: Int) : Int = x * 2
```

El cuerpo puede tomar **tres formas**. La primera es la que
acabas de ver: una sola expresión.

La segunda es un bloque `{ ... }` con `let`s intermedios y la
expresión final implícita:

```kai
fn cuadrado_mas_uno(x: Int) : Int = {
  let cuadrado = x * x
  cuadrado + 1
}
```

La tercera son **arms con patrones**, donde la función decide
qué hacer según la forma de sus argumentos. Cada arm empieza
con `case`, va seguido de un patrón, una flecha `->` y la
expresión que ese caso produce:

```kai
fn signo(n: Int) : String {
  case 0          -> "cero"
  case k when k > 0 -> "positivo"
  case _          -> "negativo"
}
```

Es exactamente equivalente a:

```kai
fn signo(n: Int) : String =
  match n {
    0          -> "cero"
    k if k > 0 -> "positivo"
    _          -> "negativo"
  }
```

solo que sin el `match` envoltorio. Cuando la función tiene
**varios parámetros**, los patrones se listan separados por
comas, uno por argumento:

```kai
fn divide(a: Real, b: Real) : Result[Error, Real] {
  case _, 0.0 -> Err(DivCero)
  case a, b   -> Ok(a / b)
}
```

Una regla del lenguaje: dentro del bloque `{ ... }` de una
función, **o todo son `case` arms o todo son sentencias**.
Mezclar es un error de parseo. Si necesitas setup antes de
discriminar, envuelve un `match` en la forma corta o extrae
un helper.

La regla práctica para elegir entre las tres:

- **Cuerpo corto con `=`** cuando la función es una expresión
  directa, sin pasos intermedios.
- **Bloque con `{ ... }`** cuando hay `let`s intermedios o
  varios pasos visualmente separados.
- **Multi-clause con `case`** cuando la función decide
  principalmente por la forma de sus argumentos. Es la forma
  natural para muchas funciones recursivas y para
  dispatchers sobre tipos suma.

Las tres son aceptadas por el compilador; la elección es
para quien lee.

Algunas notas que conviene fijar:

- **Anotaciones de parámetros: obligatorias.** kaikai infiere
  tipos en bindings locales (`let x = 5`), pero no en firmas
  de función. Cada parámetro tiene que decir su tipo.
- **Tipo de retorno: obligatorio en funciones públicas y
  recomendado siempre.** El compilador puede inferirlo en
  funciones locales, pero la firma documenta el contrato y
  hace que los errores de tipo se reporten en el lugar
  correcto. Anota.
- **Funciones con efecto: el efecto va después del `/`.** Una
  función que escribe a stdout es `: Unit / Stdout`, y el
  cap. 12 entra en eso con calma. Por ahora basta con saber
  que si tu función llama a `println`, su firma lo declara.

```kai
fn anunciar(mensaje: String) : Unit / Stdout =
  println("[ANUNCIO] " ++ mensaje)
```

`main` es la única función donde el tipo de retorno es
opcional. Si lo omites, kaikai asume `Unit`.

## 6.2 Lambdas

Una **lambda** es una función anónima, una expresión que se
evalúa a un valor de tipo función. kaikai te da tres formas
para escribirlas:

```kai
# Forma 1: flecha con un argumento
let cuadrado = (x) => x * x

# Forma 2: flecha con varios argumentos
let suma = (a, b) => a + b

# Forma 3: placeholder, lambda implícita unaria
xs |> list.filter(. > 0)
```

Las dos primeras son intercambiables; la elección es de
estilo. La tercera es **azúcar** que solo aplica cuando el
contexto **espera una función**: el segundo argumento de
`list.filter`, por ejemplo, es de tipo `(Int) -> Bool`, y el
compilador convierte `. > 0` en `(n) => n > 0`.

Las reglas del placeholder son tres:

- `.` solo funciona en posición donde se espera una función.
  Fuera de ahí es un error de compilación.
- Funciones unarias solamente. Para dos o más argumentos,
  flecha explícita.
- Múltiples ocurrencias del mismo `.` se refieren al **mismo
  valor**. Por ejemplo, `xs |> list.map(. * .)` eleva al
  cuadrado.

¿Cuándo usar cuál? Mi sugerencia:

- **Placeholder** cuando la lambda es trivial y está dentro
  de un pipe. `xs |> list.filter(. > 0)` se lee de un
  vistazo.
- **Flecha** cuando la lambda tiene varios pasos, o cuando el
  argumento aparece en lugares no obvios. `(p) => p.edad +
  bonus * 2` no gana nada con placeholder.
- **Función con nombre** cuando la lambda se usa más de una
  vez, o cuando el nombre documenta la intención. Si la misma
  lambda aparece en tres lugares, dale un nombre.

### Secciones point-free: cuando la lambda solo proyecta

Hay un caso todavía más común que el placeholder: la lambda que
no hace más que **alcanzar dentro del elemento** para sacarle un
campo o llamarle un método. `(p) => p.nombre`, `(s) =>
s.length()`. No hay cómputo, no hay operador, solo una
proyección. Para eso kaikai tiene una forma aún más corta, la
**sección point-free**: un `.` inicial seguido del campo, la
ruta de campos o la llamada al método.

```kai
type Dir = { ciudad: String }
type Persona = { nombre: String, dir: Dir }

let personas = [Persona { nombre: "ana", dir: Dir { ciudad: "Hanga Roa" } }]
let nombres  = personas | .nombre          # (p) => p.nombre
let ciudades = personas | .dir.ciudad      # (p) => p.dir.ciudad
let largos   = nombres   | .length()       # (s) => s.length()
```

La sección se lee como la proyección misma, sin tener que
inventar un nombre para el parámetro. El receptor se entrega de
forma implícita (es el primer argumento por UFCS), así que
`.starts_with("a")` lee su argumento escrito *después* del
receptor. Funciona como la función de `|`, `||`, `|?` y como
argumento de un combinador (`.map`, `.and_then`, `.filter`):

```kai
let inicia = nombres |? .starts_with("a")  # (s) => s.starts_with("a")
let n      = Some("hi").map(.length())     # en posición de argumento
```

Hay un límite que conviene tener claro desde el principio: la
sección point-free **solo proyecta**. En cuanto el cuerpo hace
algo más (un operador, una comparación, dos usos del
parámetro), deja de ser point-free y vuelves a la flecha. Esto
**no** compila:

```kai
let mayores = personas |? .edad > 18       # ERROR: mezcla proyección con `>`
```

Lo que ahí quieres es la flecha explícita, `(p) => p.edad > 18`.
La regla práctica: si la lambda *solo* saca un campo o llama un
método, escríbela point-free; si hace cualquier otra cosa, flecha.

Las lambdas son **valores de primera clase**: las atas a
`let`, las pasas como argumento, las devuelves de funciones,
las guardas en records. Eso es lo que hace que las funciones
de orden superior sean naturales.

## 6.3 Funciones de orden superior

Una **función de orden superior** es una que recibe o
devuelve otra función. Esa es toda la definición, y lo
interesante no es el nombre sino lo que te deja hacer.

El caso más simple es una función que aplica otra dos veces:

```kai
fn dos_veces[a](f: (a) -> a, x: a) : a = f(f(x))
```

`f` es el primer parámetro y su tipo es `(a) -> a`:
cualquier función que vaya de `a` a `a`. `dos_veces(mas_uno,
5)` calcula `mas_uno(mas_uno(5))` = `7`. La función es
**genérica** sobre el tipo `a`: funciona con `Int`, con
`String`, con cualquier tipo, mientras `f` mantenga el mismo
tipo de entrada que de salida. Las anotaciones `[a]` después
del nombre declaran el parámetro de tipo.

Un caso más interesante es una función que **devuelve** otra
función: un *closure*.

```kai
fn sumar(n: Int) : (Int) -> Int = (x) => x + n
```

`sumar(10)` devuelve una nueva función que suma 10 a su
argumento. El truco es que la lambda **captura** `n` del
contexto donde se creó. Una vez devuelta, esa función tiene
una copia de `n` adentro:

```kai
let mas_diez = sumar(10)
mas_diez(7)        # 17
mas_diez(100)      # 110
```

Y la composición clásica:

```kai
fn componer[a, b, c](f: (b) -> c, g: (a) -> b) : (a) -> c =
  (x) => f(g(x))
```

`componer(f, g)` es la función que primero aplica `g` y
después `f`. Tres parámetros de tipo (`a`, `b`, `c`) porque
las funciones encadenadas tocan tres tipos distintos en
general.

Las funciones de orden superior son la herramienta principal
para abstraer **lo que hay que hacer**. En vez de escribir
`para cada elemento, hacer X` y `para cada elemento, hacer
Y`, escribes `para cada elemento, hacer F`, donde `F` es un
parámetro. Así nacen `list.map`, `list.filter`,
`list.foldl`, las tres funciones que más vas a usar en
programación funcional.

## 6.4 Pipes: `|>`, `|`, `||`

kaikai trae cuatro operadores para encadenar. Los cuatro son
distintos y cada uno comunica una intención específica.

### `|>`: apply

`xs |> f` es exactamente `f(xs)`. El operador toma el lado
izquierdo y lo pone como **primer argumento** del llamado de
la derecha. Si `f` tiene varios argumentos, los demás van en
los paréntesis:

```kai
xs |> list.sum                   # ≡ list.sum(xs)
xs |> list.filter(es_par)        # ≡ list.filter(xs, es_par)
xs |> list.map((n) => n * 2)     # ≡ list.map(xs, (n) => n * 2)
```

Pero hay un detalle útil: a veces el valor del pipe **no
quiere ir como primer argumento**. Por ejemplo, una función
de división donde lo que estás canalizando es el divisor, no
el dividendo. kaikai te deja indicar la posición exacta con
un guión bajo `_`:

```kai
fn divide(a: Int, b: Int) : Int = a / b

100 |> divide(_, 4)        # ≡ divide(100, 4) = 25
100 |> divide(1000, _)     # ≡ divide(1000, 100) = 10
```

El `_` es el **hueco** donde aterriza el lado izquierdo. Sin
guión bajo, el lado izquierdo va al primer argumento: es la
forma corta de `f(_, a, b)`. Con guión bajo, va donde lo
pongas. Esto te deja escribir pipelines naturales aun cuando
las funciones del stdlib no estén diseñadas con el "argumento
principal" en la primera posición.

```kai
fn entre(low: Int, x: Int, high: Int) : Bool =
  x >= low and x <= high

50 |> entre(0, _, 100)     # ≡ entre(0, 50, 100) = true
```

Es lo que viene de Elixir y F#: un pipe **general** con
control de posición opcional.

### `|`: map

`xs | f` es exactamente `list.map(xs, f)`. Es un operador
**específico** para mapear listas:

```kai
let dobles = xs | (n) => n * 2     # ≡ list.map(xs, (n) => n * 2)
```

¿Por qué tener `|` si `|>` ya cubre el caso? Porque
`xs | f` se lee como "xs procesado con f", que es
exactamente lo que un map es. La forma más corta hace que
los pipelines de transformación de listas se lean como
secuencias declarativas:

```kai
let total = xs | doble | restar_uno |> list.sum
```

vs.

```kai
let total = xs |> list.map(doble) |> list.map(restar_uno) |> list.sum
```

Las dos son equivalentes. La primera tiene **menos ruido
sintáctico** porque las dos transformaciones unitarias usan
`|`. La regla práctica: `|` para mapear, `|>` cuando el lado
derecho es un llamado más complejo (con argumentos extra,
sumas, lookups).

### `||`: flat-map

`xs || f` es `list.flat_map(xs, f)`. Cada elemento `x` produce
una **lista** `f(x)`, y el resultado es la concatenación de
todas las listas:

```kai
fn vecinos(n: Int) : [Int] = [n - 1, n, n + 1]

[10, 20, 30] || vecinos
# = [9, 10, 11, 19, 20, 21, 29, 30, 31]
```

`||` desazucara directamente a `list.flat_map(xs, f)`, igual
que `|` desazucara a `list.map(xs, f)`. Las tres formas
siguientes son equivalentes:

```kai
let extendido = [10, 20, 30] || vecinos                  # azúcar
let extendido = list.flat_map([10, 20, 30], vecinos)     # llamada directa
let extendido = [10, 20, 30] | vecinos |> list.concat    # map + concat
```

Las tres producen `[9, 10, 11, 19, 20, 21, 29, 30, 31]`. La
primera dice "expande cada elemento". La segunda es la
llamada con su nombre real. La tercera muestra cómo flat-map
se define: mapear y aplanar. Usa `||` cuando quieras hacer
evidente la operación dentro de un pipeline, y la llamada
directa cuando no estés en pipeline.

### `|?`: filter

`xs |? p` es exactamente `list.filter(xs, p)`. El operador
**filtra** la lista quedándose con los elementos para los que
el predicado es verdadero:

```kai
fn es_par(n: Int) : Bool = n % 2 == 0

[1, 2, 3, 4, 5, 6] |? es_par      # ≡ list.filter(xs, es_par) = [2, 4, 6]
```

El predicado es cualquier expresión que el contexto admita
como `(a) -> Bool`: un nombre de función, una flecha, una
lambda en bloque:

```kai
xs |? es_par                       # nombre
xs |? (n) => n > 3                 # flecha
xs |? { n -> n % 3 == 0 }          # bloque
```

`|?` cierra la familia de pipes específicos para listas: `|`
es map, `||` es flat-map, `|?` es filter. Las tres
operaciones canónicas de transformación de secuencias tienen
su propio operador.

### Todo junto

Los cuatro operadores se mezclan libremente:

```kai
let total =
  pedidos
  |? esta_pendiente
  | aplicar_descuento
  | monto_de
  |> list.sum
```

Cada paso del pipeline hace una sola cosa. La firma del
resultado se entiende de izquierda a derecha. No hay
variables temporales, no hay anidamiento de paréntesis. Esto
es la principal razón de que kaikai tenga cuatro operadores
y no uno.

### Los mismos pipes, pero lazy: `Stream`

Hay un detalle de los pipes sobre listas que conviene tener
presente: cada paso **materializa** una lista nueva. `xs | f`
construye la lista completa de resultados antes de pasarla al
paso siguiente. Para una lista de diez elementos da igual;
para una de diez millones, son diez millones de celdas
intermedias por cada `|` del pipeline.

El módulo `stream` te da los mismos tres operadores (`|`,
`|?`, `||`) sobre un `Stream`: un pipeline **lazy** que corre
en memoria constante. Nada se computa cuando escribes el
`map` o el `filter`; el trabajo ocurre recién cuando un
*sink* (`foldl`, `to_list`, `count`, `each`) recorre el stream
y lo fuerza. Y entre paso y paso no hay lista intermedia: cada
elemento atraviesa todo el pipeline antes de que el siguiente
empiece.

```kai
import stream

let total = stream.from_list([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
  |  (x) => x * x          # map lazy
  |? (x) => x % 2 == 0     # filter lazy
  |> stream.foldl(0, (acc, x) => acc + x)
# total = 220
```

Si vienes de Python esto son los generadores e iteradores
lazy; de Java, los `Stream`; de Rust, los iterators. La idea
es la misma: describir la transformación sin ejecutarla, y
dejar que el consumidor decida cuánto material pedir.

Eso es lo que hace brillar a `stream.read_lines(path)`: te
entrega un stream de las líneas de un archivo leído en memoria
constante. Puedes filtrar, mapear y plegar un archivo de
gigabytes sin cargarlo entero: cada línea entra, atraviesa el
pipeline y se descarta antes de leer la siguiente. Un `Stream`
no es un cursor que avanza una vez; es una **receta
re-ejecutable**. El catálogo completo está en `kai doc
stream`.

## 6.5 Trailing lambdas y otros azúcares

kaikai trae varios azúcares sintácticos que vas a ver en
código real, sobre todo cuando uses funciones de orden
superior. Los principales:

### Trailing lambdas

Cuando una función toma una lambda como **último**
argumento, puedes sacarla de los paréntesis y ponerla en
llaves al final, con la sintaxis `{ param -> body }`:

```kai
list.map(xs) { n -> n * 2 }
list.filter(xs) { n -> n > 0 }
```

Es equivalente a `list.map(xs, (n) => n * 2)`. Las dos formas
son aceptadas; la trailing es más amigable cuando el cuerpo
de la lambda es largo.

Cuando estás dentro de un pipeline con `|`, el bloque-lambda
es aún más compacto. `|` ya espera una función como segundo
argumento, así que puedes escribir el cuerpo directamente:

```kai
xs | { n -> n * 2 }              # equivalente a xs | ((n) => n * 2)
xs | { n -> n * n + 1 }
```

Esto se lee casi como prosa: "los xs, cada uno transformado a
n por dos". La forma vale tanto para `|` como para `||` (que
también esperan una función), y se mezcla con el resto del
pipeline sin ruido.

### Doble trailing lambda

Si los **dos** últimos argumentos son lambdas, los dos van en
llaves:

```kai
fn while(cond: () -> Bool, body: () -> Unit) : Unit / e = ...

while { i < 10 } { i := i + 1 }
```

Esto le da a kaikai control de flujo definible por el
usuario. `while` es una función ordinaria del stdlib; solo
parece un keyword.

### Block como lambda

`{ x -> body }` es una forma alternativa para una lambda que
encaja mejor cuando el cuerpo abarca varias líneas:

```kai
xs | { n ->
  let cuadrado = n * n
  cuadrado + 1
}
```

Es lo mismo que `(n) => { let cuadrado = n * n; cuadrado + 1
}` pero menos cargado visualmente.

### Patrones de tupla como parámetro

El parámetro de un bloque-lambda puede ser un **patrón de
tupla**. Si lo que fluye por el pipe son pares — el resultado de
`list.zip` o `list.enumerate`, por ejemplo —, destructuras en el
acto, sin un `let` intermedio:

```kai
let pares = list.zip(xs, ys)
let sumas = pares | { (a, b) -> a + b }

list.foreach(list.enumerate(filas)) { (i, fila) ->
  println("#{i}: #{fila}")
}
```

El patrón tiene que ser **irrefutable**: `(a, b)` sobre un par
siempre calza. Un patrón que puede fallar — `(Some(n))`, digamos
— se rechaza con un diagnóstico de match no exhaustivo; para
esos casos está `match`. Y ojo con una asimetría deliberada: la
destructuración es exclusiva del bloque-lambda. La forma con
flecha `(a, b) => ...` sigue siendo una lambda de **dos
parámetros**, no una que recibe un par.

Ninguno de estos azúcares introduce semántica nueva. Son
formas alternativas de escribir lambdas que el compilador
desazucara antes de la inferencia de tipos. Úsalos cuando la
lectura mejore, ignóralos cuando no.

## 6.6 Recursión y TCO obligatoria

Una promesa importante de kaikai: **toda llamada recursiva
en posición de cola se compila a un loop**. No consume stack.
No hay riesgo de stack overflow por una recursión larga.

Veamos qué significa "posición de cola". Una llamada está en
**posición de cola** si es lo último que la función va a
hacer antes de devolver. Compara estas dos versiones de
`suma`:

```kai
# NO en posición de cola: la llamada deja pendiente `h + ...`
fn suma_naive(xs: [Int]) : Int {
  case []         -> 0
  case [h, ...t]  -> h + suma_naive(t)
}
```

Aquí, después de que `suma_naive(t)` devuelve, todavía hay que
sumar `h`. La llamada **no** es lo último; queda una operación
pendiente. Cada llamada consume un frame del stack.

```kai
# En posición de cola: la última cosa que hace cada rama es
# **solo** la llamada, sin operación pendiente.
fn suma_tco_loop(xs: [Int], acc: Int) : Int {
  case [], a         -> a
  case [h, ...t], a  -> suma_tco_loop(t, a + h)
}

fn suma(xs: [Int]) : Int = suma_tco_loop(xs, 0)
```

Aquí, en cada rama recursiva, `suma_tco_loop(t, acc + h)` es
**lo último**. La suma `acc + h` se evalúa primero, se pasa
como argumento, y entonces la llamada ocurre. Cuando la
llamada devuelve, la función actual también devuelve
inmediatamente: no queda nada por hacer. El compilador
detecta este patrón y lo compila a un loop, sin frame nuevo.

```kai
# Esto funciona sin reventar el stack:
let muchos = [1..100_000]
suma(muchos)        # 5_000_050_000
```

La técnica del **acumulador** que ves en `suma_tco_loop` es la
forma estándar de convertir una recursión naive en una
recursiva en cola: agregas un parámetro extra que va llevando
el resultado parcial, y al terminar lo devuelves.

¿Por qué importa esto en serio?

- **Sin TCO obligatoria, no podrías reemplazar `for` y
  `while`.** Con stack limitado, una iteración sobre un
  millón de elementos te dejaría sin stack. Solo con TCO
  garantizada puedes dar el paso a programar con recursión.
- **Es una garantía del lenguaje, no una optimización
  oportunista.** Algunos lenguajes optimizan TCO cuando se
  acuerdan; kaikai te lo promete. Si una llamada recursiva
  está en cola, el compilador la convierte. Punto.
- **El compilador te avisa si crees que escribiste TCO pero
  no.** Hay un flag para verificar esto, así no te enteras
  por sorpresa cuando tu programa muere en producción.

En la práctica, la mayoría de las funciones recursivas que
escribas para procesar listas o árboles van a ser de la
forma `match xs { [] -> base; [h, ...t] -> recursión }`. La
versión naive (con operación pendiente) es la primera que
escribes; la versión con acumulador es la que dejas. Para
operaciones más complejas, las funciones de orden superior
(`list.foldl`, `reduce`) ya están escritas con TCO y son
casi siempre lo que querías.

## 6.7 Caso de estudio: pipeline de transformación

Cerramos con un caso integrador. Tienes una lista de
pedidos de una tienda, con un id, un monto y un estado.
Quieres calcular el total a cobrar **considerando solo los
pedidos pendientes** y **aplicando un 10% de descuento a los
montos altos**:

```kai
type Estado = Pendiente | Pagado | Cancelado

type Pedido = {
  id: Int,
  monto: Int,
  estado: Estado,
}

fn esta_pendiente(p: Pedido) : Bool =
  match p.estado {
    Pendiente -> true
    Pagado    -> false
    Cancelado -> false
  }

fn aplicar_descuento(p: Pedido) : Pedido =
  if p.monto >= 1000 {
    Pedido { ...p, monto: p.monto - p.monto / 10 }
  } else {
    p
  }

fn monto_de(p: Pedido) : Int = p.monto
```

Cada función chica hace **una sola cosa**: una decide si un
pedido está pendiente, otra le aplica descuento si
corresponde, otra extrae el monto. Ninguna sabe del
pipeline; todas son útiles por separado.

Y el pipeline las compone:

```kai
let total =
  pedidos
  |? esta_pendiente
  | aplicar_descuento
  | monto_de
  |> list.sum
```

Cinco líneas, cuatro pasos. Filtra los pendientes, aplica
descuento a cada uno, extrae el monto de cada uno, suma
todo. Si el cliente pide después "agreguemos un cargo fijo
de 100 a los pedidos > 5000", agregas una función chica más
y la metes en el pipeline:

```kai
fn cargo_si_grande(p: Pedido) : Pedido =
  if p.monto > 5000 {
    Pedido { ...p, monto: p.monto + 100 }
  } else {
    p
  }

let total =
  pedidos
  |? esta_pendiente
  | aplicar_descuento
  | cargo_si_grande
  | monto_de
  |> list.sum
```

Una línea más, cero acoplamiento. Ese es el punto del estilo
funcional: **funciones chicas que se componen en pipelines
de lectura lineal**. La complejidad vive en cada función
individual; la composición es trivial.

Compáralo con la versión imperativa típica:

```python
total = 0
for p in pedidos:
    if p.estado != "pendiente":
        continue
    monto = p.monto
    if monto >= 1000:
        monto -= monto // 10
    if monto > 5000:
        monto += 100
    total += monto
```

Funciona, pero la lógica del cálculo está enredada con la
mecánica del bucle. Cambiar el orden de las
transformaciones, agregar un paso, sacar un paso: todas
operaciones que en el pipeline son una línea, en la versión
imperativa son un refactor.

Si vienes de Java, JavaScript, C# o Kotlin, has visto algo
parecido con sus respectivos stream/iterator APIs. La
diferencia es que en kaikai el pipeline es una construcción
sintáctica del lenguaje, no una API encima del lenguaje. No
necesitas envolver la lista en un objeto especial, no hay
métodos `.collect()` ni terminadores; los pipes son tan
ordinarios como `+` o `*`.

## Ejercicios

**6.1.** Escribe una función `fn aplicar_n(f: (Int) -> Int,
x: Int, n: Int) : Int` que aplique `f` a `x` exactamente `n`
veces. Por ejemplo, `aplicar_n(mas_uno, 5, 3)` debería ser
`8`. Hazlo con recursión en posición de cola.

**6.2.** Define `fn componer3[a, b, c, d](f: (c) -> d,
g: (b) -> c, h: (a) -> b) : (a) -> d` que componga tres
funciones. Comprueba con `componer3(cuadrado, mas_uno,
doble)(2)`.

**6.3.** Reescribe el pipeline del §6.7 usando solo `|>` (sin
`|` ni `||`). ¿Cuántos caracteres más tiene? ¿Cómo cambia la
legibilidad?

**6.4.** Define un sum type `type Operacion = Sumar(Int) |
Multiplicar(Int) | Negar`. Escribe una función `fn aplicar(op:
Operacion, x: Int) : Int` que ejecute la operación sobre `x`,
y una función `fn ejecutar_todas(ops: [Operacion], x: Int) :
Int` que ejecute una secuencia de operaciones empezando con
`x`. Pista: `list.foldl` con `aplicar` invertido es un buen
camino.

**6.5.** Tienes una lista de strings con números:
`["10", "abc", "20", "", "30"]`. Quieres la suma de los que
**sí son números válidos**, ignorando los demás. Construye
un pipeline usando `list.flat_map` (o `||`) y la función
`string_to_int : String -> Option[Int]`. Pista: una función
`Option[a] -> [a]` te ayuda: si es `Some(x)` devuelve `[x]`,
si es `None` devuelve `[]`. Ese paso es el flat-map natural.
