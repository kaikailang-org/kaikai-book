# Capítulo 6 · Funciones y pipelines

Ya escribiste funciones en el tour, les diste tres formas de
cuerpo en el cap. 3 y las hiciste recursivas sobre tipos suma
en el cap. 5. Aquí aprendes a declararlas con cuidado, a
escribir lambdas, a pasar funciones como valores y a
encadenarlas con los cinco operadores pipe.

Los cinco pipes son lo que más discutí conmigo mismo: cinco
operadores es mucho para un lenguaje que presume de tener pocas
formas. En §6.4 explico por qué los dejé.

También conocerás la **eliminación de llamadas en posición de
cola**, una garantía que muy pocos lenguajes dan en serio y que
te deja escribir ciclos sin `for` ni `while` y dormir tranquilo.

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
fn cuadrado_mas_uno(x: Int) : Int {
  let cuadrado = x * x
  cuadrado + 1
}
```

La tercera son **arms con patrones**: la función decide qué
hacer según la forma de sus argumentos. Cada arm es `case`,
un patrón, una flecha `->` y la expresión que produce:

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
fn divide(a: Real, b: Real) : Result[Real, Error] {
  case _, 0.0 -> Err(DivCero)
  case a, b   -> Ok(a / b)
}
```

Dentro del bloque `{ ... }` de una función, **o todo son
`case` arms o todo son sentencias**. Mezclar es un error de
parseo. Si necesitas setup antes de discriminar, envuelve un
`match` en la forma corta o extrae un helper.

Para elegir entre las tres:

- **Cuerpo corto con `=`** cuando la función es una expresión
  directa, sin pasos intermedios.
- **Bloque con `{ ... }`** cuando hay `let`s intermedios o
  varios pasos visualmente separados.
- **Multi-clause con `case`** cuando la función decide
  principalmente por la forma de sus argumentos. Es la forma
  natural para muchas funciones recursivas y para
  dispatchers sobre tipos suma.

Al compilador le dan lo mismo; la elección es para quien lee.

Tres notas más:

- **Anotaciones de parámetros: obligatorias.** kaikai infiere
  tipos en bindings locales (`let x = 5`), pero no en firmas
  de función. Cada parámetro dice su tipo.
- **Tipo de retorno: obligatorio en funciones públicas y
  recomendado siempre.** El compilador puede inferirlo en
  funciones locales, pero la firma documenta el contrato y
  hace que los errores de tipo se reporten en el lugar
  correcto. Anota.
- **Funciones con efecto: el efecto va después del `/`.** Una
  función que escribe a stdout es `: Unit / Stdout`; el
  cap. 12 entra en eso con calma. Por ahora basta con que, si
  tu función llama a `println`, su firma lo declara.

```kai
fn anunciar(mensaje: String) : Unit / Stdout =
  println("[ANUNCIO] " ++ mensaje)
```

`main` es la única función donde el tipo de retorno es
opcional. Si lo omites, kaikai asume `Unit`.

Los dos cuerpos y una función con efecto, en un programa:

```kai
# ejemplos/cap06/01_funciones.kai
# Cuerpo corto: una expresión, separada por `=`.
fn doble(x: Int) : Int = x * 2

# Cuerpo largo: bloque con `let`s y expresión final.
fn cuadrado_mas_uno(x: Int) : Int {
  let cuadrado = x * x
  cuadrado + 1
}

# Función pura sin valor útil de retorno: sirve para efectos.
# Aunque devolver `Unit` es opcional en `main`, en una función
# auxiliar conviene anotarlo cuando hay efectos involucrados.
fn anunciar(mensaje: String) : Unit / Stdout =
  println("[ANUNCIO] " ++ mensaje)

fn main() {
  println("doble(7) = #{doble(7)}")
  println("f(3)     = #{cuadrado_mas_uno(3)}")
  anunciar("listo")
}
```

```
$ kai run ejemplos/cap06/01_funciones.kai
doble(7) = 14
f(3)     = 10
[ANUNCIO] listo
```

## 6.2 Lambdas

Una **lambda** es una función anónima: una expresión cuyo
valor es una función. Se escribe de tres formas:

```kai
# Forma 1: flecha con un argumento
let cuadrado = (x) => x * x

# Forma 2: flecha con varios argumentos
let suma = (a, b) => a + b

# Forma 3: placeholder, lambda implícita unaria
xs |> list.filter(. > 0)
```

Las dos primeras son intercambiables. La tercera es
**azúcar** que solo aplica cuando el contexto **espera una
función**: el segundo argumento de `list.filter` es de tipo
`(Int) -> Bool`, y el compilador convierte `. > 0` en
`(n) => n > 0`.

Reglas del placeholder:

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
  vez, o cuando el nombre documenta la intención.

### Secciones point-free: proyectar sin nombrar el parámetro

Más común todavía que el placeholder es la lambda que solo
**alcanza dentro del elemento** para sacarle un campo:
`(p) => p.nombre`, `(p) => p.dir.ciudad`. Sin cómputo ni
operador, solo una proyección. Para eso está la **sección
point-free**: un `.` inicial seguido del campo o de la ruta de
campos.

```kai
type Dir = { ciudad: String }
type Persona = { nombre: String, edad: Int, dir: Dir }

let personas = [Persona { nombre: "ana", edad: 30, dir: Dir { ciudad: "Hanga Roa" } }]
let nombres  = personas | .nombre          # (p) => p.nombre
let ciudades = personas | .dir.ciudad      # (p) => p.dir.ciudad
```

La sección se lee como la proyección misma, sin inventar un
nombre para el parámetro.

Cuando lo que quieres no es un campo sino el resultado de una
función, el `.` entra como **argumento**. Las funciones del
stdlib reciben el dato primero, así que `length(.)` es "el
largo del elemento" y `starts_with(., "a")` es "el elemento
empieza con a":

```kai
let largos = nombres | length(.)             # (s) => length(s)
let inicia = nombres |? starts_with(., "a")  # (s) => starts_with(s, "a")
let n      = Some("hi") | length(.)          # los pipes corren sobre Option
```

Dentro de una etapa de pipe la proyección no tiene que quedarse
sola. A la derecha de `|`, `||`, `|?` o `|!`, el `.` **es** el
elemento de esa etapa, y todos los `.` de la etapa son el mismo
elemento, así que puedes seguir operando sobre lo que proyectas:

```kai
let mayores = personas |? .edad > 18       # (p) => p.edad > 18
let diez    = [1, 2, 3] | . * 10           # (n) => n * 10
let topes   = [1, 2, 3] | max(., 2)        # (n) => max(n, 2)
```

Fíjate en la última: un `.` dentro de un argumento de llamada se
refiere al elemento de la etapa, no al argumento. `xs | f(g(.))`
significa `xs | (x) => f(g(x))`.

La flecha explícita corta ese alcance: si la escribes, el `.` de
adentro pertenece a la etapa que esté dentro de ella. Dos etapas
anidadas que ambas usan `.` no compilan, y el error te pide
nombrar uno de los dos elementos con `(x) => ...`.

Si la etapa se lee de un vistazo, déjala point-free; si tiene
varios pasos, o el elemento aparece en lugares no obvios, dale
un nombre con la flecha.

Las lambdas son **valores de primera clase**: las atas a
`let`, las pasas como argumento, las devuelves de funciones,
las guardas en records. Por eso las funciones de orden
superior resultan naturales.

Las tres formas, más una lambda atada a un `let` y pasada como
argumento:

```kai
# ejemplos/cap06/02_lambdas.kai
fn aplica(f: (Int) -> Int, x: Int) : Int = f(x)

fn main() {
  # Forma 1: flecha con un argumento.
  let cuadrado = x => x * x
  println("cuadrado(7)  = #{cuadrado(7)}")

  # Forma 2: flecha con varios argumentos.
  let suma = (a, b) => a + b
  println("suma(3, 4)   = #{suma(3, 4)}")

  # Forma 3: placeholder, lambda implícita unaria.
  # Solo válida en posición donde se espera una función.
  let xs = [1, 2, 3, 4, 5]
  let dobles = xs |> list.map(n => n * 2)
  println("dobles[0..4] = #{list.sum(dobles)}")

  # Las lambdas son valores de primera clase: se pasan como
  # argumento, se atan a `let`, se devuelven de funciones.
  println("aplica(cuadrado, 5) = #{aplica(cuadrado, 5)}")
}
```

```
$ kai run ejemplos/cap06/02_lambdas.kai
cuadrado(7)  = 49
suma(3, 4)   = 7
dobles[0..4] = 30
aplica(cuadrado, 5) = 25
```

## 6.3 Funciones de orden superior

Una **función de orden superior** recibe o devuelve otra
función. Esa es toda la definición; lo interesante es lo que
te deja hacer.

El caso más simple aplica otra función dos veces:

```kai
fn dos_veces[a](f: (a) -> a, x: a) : a = f(f(x))
```

El tipo de `f` es `(a) -> a`: cualquier función de `a` en
`a`. `dos_veces(mas_uno, 5)` calcula `mas_uno(mas_uno(5))` =
`7`. La función es **genérica** sobre `a`: funciona con
`Int`, con `String`, con cualquier tipo, mientras `f`
conserve el tipo de entrada en la salida. El `[a]` después del
nombre declara el parámetro de tipo.

Más interesante es una función que **devuelve** otra: un
*closure*.

```kai
fn sumar(n: Int) : (Int) -> Int = (x) => x + n
```

`sumar(10)` devuelve una función nueva que suma 10 a su
argumento. La lambda **captura** `n` del contexto donde se
creó, y se lleva una copia adentro:

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

`componer(f, g)` aplica primero `g` y después `f`. Lleva tres
parámetros de tipo (`a`, `b`, `c`) porque, en general, las
dos funciones encadenadas tocan tres tipos distintos.

Las funciones de orden superior abstraen **lo que hay que
hacer**. En vez de `para cada elemento, hacer X` y `para cada
elemento, hacer Y`, escribes `para cada elemento, hacer F`,
con `F` como parámetro. Así nacen `list.map`, `list.filter` y
`list.foldl`, las tres funciones que más vas a usar en
programación funcional.

Una función que recibe otra, una que devuelve una nueva, y la
composición de las dos:

```kai
# ejemplos/cap06/03_orden_superior.kai
# Acepta una función como argumento.
fn dos_veces[a](f: (a) -> a, x: a) : a = f(f(x))

# Devuelve una función nueva (closure que captura `n`).
fn sumar(n: Int) : (Int) -> Int = x => x + n

# Componer dos funciones es una función de orden superior
# que acepta dos funciones y devuelve una nueva.
fn componer[a, b, c](f: (b) -> c, g: (a) -> b) : (a) -> c = x => f(g(x))

fn main() {
  let mas_uno = x => x + 1
  println("dos_veces(+1, 5) = #{dos_veces(mas_uno, 5)}")

  let mas_diez = sumar(10)
  println("mas_diez(7) = #{mas_diez(7)}")

  let cuadrado = x => x * x
  let comp = componer(cuadrado, mas_uno)
  println("(cuadrado . +1)(4) = #{comp(4)}")
}
```

```
$ kai run ejemplos/cap06/03_orden_superior.kai
dos_veces(+1, 5) = 7
mas_diez(7) = 17
(cuadrado . +1)(4) = 25
```

## 6.4 Pipes: `|>`, `|`, `||`, `|?`, `|!`

kaikai trae cinco operadores para encadenar, y cada uno
comunica una intención distinta.

### `|>`: apply

`xs |> f` es exactamente `f(xs)`: el lado izquierdo pasa a
ser el **primer argumento** del llamado de la derecha. Si `f`
tiene más argumentos, van en los paréntesis:

```kai
xs |> list.sum                   # ≡ list.sum(xs)
xs |> list.filter(es_par)        # ≡ list.filter(xs, es_par)
xs |> list.map((n) => n * 2)     # ≡ list.map(xs, (n) => n * 2)
```

A veces el valor del pipe **no va como primer argumento**:
en una división, quizás lo que canalizas es el divisor y no
el dividendo. Indicas la posición exacta con un guión bajo
`_`:

```kai
fn divide(a: Int, b: Int) : Int = a / b

100 |> divide(_, 4)        # ≡ divide(100, 4) = 25
100 |> divide(1000, _)     # ≡ divide(1000, 100) = 10
```

El `_` es el **hueco** donde aterriza el lado izquierdo. Sin
él, el lado izquierdo va al primer argumento: es la forma
corta de `f(_, a, b)`. Con él, va donde lo pongas. Así
escribes pipelines naturales aunque la función no tenga el
"argumento principal" en la primera posición.

```kai
fn entre(low: Int, x: Int, high: Int) : Bool =
  x >= low and x <= high

50 |> entre(0, _, 100)     # ≡ entre(0, 50, 100) = true
```

Viene de Elixir y F#: un pipe **general** con control de
posición opcional.

Las tres posiciones en un programa, con la forma corta y la
explícita dando el mismo resultado:

```kai
# ejemplos/cap06/07_pipe_underscore.kai
fn divide(a: Int, b: Int) : Int = a / b

fn entre(low: Int, x: Int, high: Int) : Bool =
  x >= low and x <= high

fn main() {
  # Sin _: el valor va al primer argumento.
  let r1 = 100 |> divide(4)  # ≡ divide(100, 4) = 25
  println("100 / 4    = #{r1}")

  # Con _ en posición 1: explícito, mismo efecto.
  let r2 = 100 |> divide(_, 4)
  println("100 / 4    = #{r2}")

  # Con _ en posición 2: el valor va como divisor.
  let r3 = 100 |> divide(1000, _)
  println("1000 / 100 = #{r3}")

  # Con _ en una posición intermedia.
  let r4 = 50 |> entre(0, _, 100)
  println("entre 0 y 100: #{r4}")
}
```

```
$ kai run ejemplos/cap06/07_pipe_underscore.kai
100 / 4    = 25
100 / 4    = 25
1000 / 100 = 10
entre 0 y 100: true
```

### `|`: map

`xs | f` es exactamente `list.map(xs, f)`, un operador
**específico** para mapear listas:

```kai
let dobles = xs | (n) => n * 2     # ≡ list.map(xs, (n) => n * 2)
```

`|>` ya cubre el caso, pero `xs | f` se lee como "xs
procesado con f", que es justo lo que un map es. Con la forma
corta, un pipeline de transformaciones se lee como una
secuencia declarativa:

```kai
let total = xs | doble | restar_uno |> list.sum
```

vs.

```kai
let total = xs |> list.map(doble) |> list.map(restar_uno) |> list.sum
```

Son equivalentes, pero la primera tiene **menos ruido
sintáctico**. La regla práctica: `|` para mapear, `|>` cuando
el lado derecho es un llamado más complejo (con argumentos
extra, sumas, lookups).

### `||`: flat-map

`xs || f` es `list.flat_map(xs, f)`. Cada elemento `x` produce
una **lista** `f(x)`, y el resultado es la concatenación de
todas las listas:

```kai
fn vecinos(n: Int) : [Int] = [n - 1, n, n + 1]

[10, 20, 30] || vecinos
# = [9, 10, 11, 19, 20, 21, 29, 30, 31]
```

Igual que `|` con `list.map`, `||` desazucara directamente a
`list.flat_map(xs, f)`. Estas tres formas son equivalentes:

```kai
let extendido = [10, 20, 30] || vecinos                  # azúcar
let extendido = list.flat_map([10, 20, 30], vecinos)     # llamada directa
let extendido = [10, 20, 30] | vecinos |> list.concat    # map + concat
```

Las tres producen `[9, 10, 11, 19, 20, 21, 29, 30, 31]`. La
primera dice "expande cada elemento", la segunda es la
llamada con su nombre real y la tercera muestra la definición
de flat-map: mapear y aplanar. Dentro de un pipeline, `||`
hace evidente la operación; fuera de él, usa la llamada
directa.

### `|?`: filter

`xs |? p` es exactamente `list.filter(xs, p)`: se queda con
los elementos para los que el predicado es verdadero:

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

Con `|?` se completan las tres transformaciones canónicas de
secuencias: `|` es map, `||` es flat-map, `|?` es filter. Queda
uno, el que no transforma nada.

### `|!`: each

Los cuatro pipes anteriores producen un valor. `|!` no: corre
la etapa por su **efecto** sobre cada elemento y devuelve
`Unit`. `xs |! f` es exactamente `list.each(xs, f)`.

```kai
[1, 2, 3] |! println("n = #{.}")   # ≡ list.each(xs, (n) => println("n = #{n}"))
```

Ocupa el lugar del `for` de otros lenguajes. Cuando recorres
una colección para imprimir, escribir o mandar un mensaje, el
operador correcto es `|!` y no `|`: `|` arma una
lista de resultados que nadie va a usar, y sobre un `Stream` no
corre nada hasta que alguien consuma esa lista.

Como devuelve `Unit`, `|!` **cierra** el pipeline. Primero
filtras y transformas, al final consumes:

```kai
[1, 2, 3, 4, 5, 6] |? es_par | . * 10 |! println("#{.}")
```

Ningún pipe puede seguir a un `|!`, y el compilador lo dice con
esas palabras:

```kai
# no compila
[1, 2, 3] |! println("#{.}") | . * 2
```

```
error: `|!` ends a pipeline; it returns `Unit`
```

El chequeo corre también en la otra dirección: si la etapa
devuelve un valor en vez de `Unit`, el error apunta al operador
y te ofrece la salida, `|` para transformar o `|> ignore` para
descartar el resultado.

### Todo junto

Los cinco operadores se mezclan libremente:

```kai
let total =
  pedidos
  |? esta_pendiente
  | aplicar_descuento
  | monto_de
  |> list.sum
```

Cada paso hace una sola cosa y el resultado se entiende de
izquierda a derecha, sin variables temporales ni paréntesis
anidados. Por eso kaikai tiene cinco operadores y no uno.

Y cada operador por separado, con su equivalencia al lado:

```kai
# ejemplos/cap06/04_pipes.kai
fn doble(n: Int) : Int = n * 2

fn es_par(n: Int) : Bool = n % 2 == 0

# `|>` (apply): el lado izquierdo es el primer argumento del
# llamado de la derecha. `xs |> f` ≡ `f(xs)`.
fn ejemplo_apply() : Int {
  let xs = [1, 2, 3, 4, 5]
  xs |> list.sum  # ≡ list.sum(xs)
}

# `|` (map) sobre listas: `xs | f` ≡ `list.map(xs, f)`.
fn ejemplo_map() : Int {
  let xs = [1, 2, 3, 4, 5]
  let dobles = xs | doble
  list.sum(dobles)
}

# `||` (flat-map): `xs || f` ≡ `list.flat_map(xs, f)`.
# Cada elemento produce una lista, y todas se concatenan.
fn vecinos(n: Int) : [Int] = [n - 1, n, n + 1]

fn ejemplo_flat_map() : Int {
  let xs = [10, 20, 30]
  let extendido = xs || vecinos
  list.length(extendido)
}

# `|?` (filter) sobre listas: `xs |? p` ≡ `list.filter(xs, p)`.
fn ejemplo_filter() : Int {
  let xs = [1, 2, 3, 4, 5, 6]
  let pares = xs |? es_par
  list.sum(pares)
}

# `|!` (each): corre la etapa por su efecto en cada elemento y
# devuelve `Unit`, así que cierra el pipeline.
# `xs |! f` ≡ `list.each(xs, f)`.
fn ejemplo_each() : Unit / Stdout {
  let xs = [1, 2, 3]
  xs |! println("|!: elemento           = #{.}")
}

fn main() {
  println("|>: total              = #{ejemplo_apply()}")
  println("|:  suma de dobles     = #{ejemplo_map()}")
  println("||: longitud extendido = #{ejemplo_flat_map()}")
  println("|?: suma de pares      = #{ejemplo_filter()}")
  ejemplo_each()
}
```

```
$ kai run ejemplos/cap06/04_pipes.kai
|>: total              = 15
|:  suma de dobles     = 30
||: longitud extendido = 9
|?: suma de pares      = 12
|!: elemento           = 1
|!: elemento           = 2
|!: elemento           = 3
```

### Los mismos pipes, pero lazy: `Stream`

Sobre listas, cada paso de un pipe **materializa** una lista
nueva: `xs | f` construye la lista completa de resultados
antes de pasarla al paso siguiente. Con diez elementos da
igual; con diez millones, son diez millones de celdas
intermedias por cada `|` del pipeline.

El módulo `stream` te da los mismos cuatro operadores (`|`,
`|?`, `||`, `|!`) sobre un `Stream`: un pipeline **lazy** que
corre en memoria constante. Escribir el `map` o el `filter` no
computa nada; el trabajo ocurre recién cuando un *sink*
(`foldl`, `to_list`, `count`, `each`) recorre el stream y lo
fuerza. `|!` es ese `each` escrito como pipe, la forma más
corta de consumir un stream. Entre paso y paso no hay lista
intermedia: cada elemento atraviesa todo el pipeline antes de
que empiece el siguiente.

```kai
import stream

let total = stream.from_list([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
  |  (x) => x * x          # map lazy
  |? (x) => x % 2 == 0     # filter lazy
  |> stream.foldl(0, (acc, x) => acc + x)
# total = 220
```

Si vienes de Python, son los generadores e iteradores lazy; de
Java, los `Stream`; de Rust, los iterators. Describes la
transformación sin ejecutarla y el consumidor decide cuánto
material pedir.

Ahí brilla `stream.read_lines(path)`: te entrega las líneas de
un archivo, leído en memoria constante. Puedes filtrar, mapear
y plegar un archivo de gigabytes sin cargarlo entero: cada
línea entra, atraviesa el pipeline y se descarta antes de leer
la siguiente. Un `Stream`
no es un cursor que avanza una vez; es una **receta
re-ejecutable**. El catálogo completo está en `kai doc
stream`.

Un pipeline lazy de punta a punta: dos etapas que no producen
nada y un sink que recorre el stream una sola vez.

```kai
# ejemplos/cap06/09_stream.kai
import stream

fn main() : Unit / Stdout {
  # map y filter son lazy: ninguno produce una lista intermedia.
  # `stream.foldl` es el sink que recorre el stream una vez y
  # acumula el resultado.
  let total = stream.from_list([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    | (x => x * x)
    # map lazy: eleva al cuadrado
    |? (x => x % 2 == 0)
    # filter lazy: deja los pares
    |> stream.foldl(0, (acc, x) => acc + x)

  Stdout.print("suma de cuadrados pares = #{total}")
}
```

```
$ kai run ejemplos/cap06/09_stream.kai
suma de cuadrados pares = 220
```

### Perezoso y además compartido: `Seq`

Un `Stream` es una receta: cada vez que lo recorres, vuelve a
correr. Es lo que quieres para un archivo de gigabytes, y lo que
no quieres cuando computar un elemento cuesta caro y lo vas a
leer dos veces.

`Seq[t]` es la otra opción: una lista perezosa cuyas celdas se
computan al leerlas y **a lo más una vez**. La primera lectura
corre el cómputo; las que vienen después devuelven lo que quedó
guardado. La escribes poniendo `lazy` delante de un literal de
lista, y dentro de `lazy` un rango puede no tener fin:

```kai
lazy []                # vacía
lazy [1, 2, 3]         # tres celdas
lazy [2..]             # los enteros desde 2, sin cota
lazy [0, 5..]          # 0, 5, 10, 15, ... sin cota
lazy [p, ...resto]     # una celda y el resto de la secuencia
```

Los patrones de lista también la leen: `[]` y
`[primero, ...resto]` calzan sobre una `Seq` igual que sobre una
lista, y el `match` fuerza solo la celda que está mirando. Un
rango sin fin fuera de `lazy` no compila, y el error te dice que
le falta: una lista tiene final, una secuencia perezosa no.

Que cada celda se compute una vez y se comparta tiene una
consecuencia que no salta a la vista: una secuencia puede
definirse **en términos de sí misma**.

```kai
import seq

# Los naturales: el cero, seguido de los naturales más uno.
const nat: Seq[Int] = lazy [0, ...seq.map(nat, (x) => x + 1)]

# La criba sin cota: una etapa de filtro por cada primo encontrado.
fn criba(xs: Seq[Int]) : Seq[Int] = match xs {
  []            -> lazy []
  [p, ...resto] -> lazy [p, ...criba(resto |? (x) => x % p != 0)]
}
```

```
$ kai run ejemplos/cap06/11_seq.kai
naturales: [0, 1, 2, 3, 4, 5, 6, 7]
primos hasta 30: [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
el primo 1000: 7919
```

`nat` aparece dentro de su propia definición sin problema:
cuando `map` pide la celda siguiente, la anterior ya está
computada y guardada. La criba es la misma idea trabajando. Por
cada primo que encuentra agrega una etapa de filtro sobre el
resto, así que la cadena de filtros crece a medida que avanza, y
nadie decidió de antemano cuántos primos iban a hacer falta. Las
celdas que llevan al primo 1000, una vez computadas, quedan ahí:
pedirlo de nuevo no vuelve a cribar nada. Con una receta
re-ejecutable, cada lectura cribaría otra vez desde el dos.

Las tres formas perezosas del lenguaje se reparten por quién
produce y por lo que pasa al leerlas de nuevo:

| | quién produce | al leer de nuevo |
|---|---|---|
| `Stream` | algo que ya existe, incluso un recurso | vuelve a correr |
| `Seq` | lo escribes tú, y es puro | ya está computado |
| `Gen` | lo escribes tú, y puede hacer efectos | avanza, no vuelve |

Las etapas de una `Seq` no pueden hacer efectos: corren cuando
alguien lee una celda, y ese momento no lo decide quien las
escribió. Los sinks sí (`each` y `foldl` corren en el consumidor y
llevan su fila). Y una `Seq` se queda en la fibra que la creó: si
otra fibra necesita un trozo, le mandas `to_list` de ese trozo. El
catálogo completo está en `kai doc seq`.

El `Gen` de la tabla lo conoces en el capítulo 12, y difiere del
`yield` de Python: el productor lo escribes tú, con recursión
corriente, y lo que lo convierte en secuencia perezosa es un
handler de efectos.
Un `Stream` consume algo que ya existe; un generador produce. Los
dos salen del mismo mecanismo.

## 6.5 Trailing lambdas y otros azúcares

Estos azúcares sintácticos aparecen a cada rato en código
real, sobre todo junto a funciones de orden superior.

### Trailing lambdas

Cuando una función toma una lambda como **último**
argumento, puedes sacarla de los paréntesis y ponerla en
llaves al final, con la sintaxis `{ param -> body }`:

```kai
list.map(xs) { n -> n * 2 }
list.filter(xs) { n -> n > 0 }
```

Equivale a `list.map(xs, (n) => n * 2)`; la forma trailing se
agradece cuando el cuerpo de la lambda es largo.

Dentro de un pipeline con `|`, el bloque-lambda es aún más
compacto. `|` ya espera una función como segundo argumento,
así que escribes el cuerpo directamente:

```kai
xs | { n -> n * 2 }              # equivalente a xs | ((n) => n * 2)
xs | { n -> n * n + 1 }
```

Se lee casi como prosa: "los xs, cada uno transformado a n
por dos". Vale para `|` y para `||`, que también esperan una
función, y se mezcla con el resto del pipeline sin ruido.

Al anidar hay un detalle que muerde. Una lambda-etapa no abre
un scope para las etapas que vienen después, así que la
siguiente lambda queda como hermana suya, al mismo nivel del
pipe.

```kai
# no compila
[0..2] | (r) => [0..2] | (c) => r * 10 + c
```

```
error: cannot find `r` in this scope
```

`(c) => …` quedó como una etapa del pipe de afuera, así que
`r` nunca estuvo a la vista. Los paréntesis meten el pipe
interno dentro de la lambda:

```kai
[0..2] | (r) => ([0..2] | (c) => r * 10 + c)
# [[0, 1, 2], [10, 11, 12], [20, 21, 22]]
```

### Doble trailing lambda

Si los **dos** últimos argumentos son lambdas, los dos van en
llaves:

```kai
fn while(pred: () -> Bool, body: () -> Unit) : Unit / e = ...

while { i < 10 } { i := i + 1 }
```

Así el control de flujo lo puede definir el usuario. `while`
es una función ordinaria del módulo `loop` del stdlib; solo
parece un keyword. Su hermana `until` corre hasta que la
condición se vuelve cierta, con una diferencia que importa:
chequea **después** del cuerpo, así que `until` siempre
ejecuta al menos una vez, mientras que un `while` con la
condición falsa de entrada no ejecuta ninguna.

### Block como lambda

`{ x -> body }` encaja mejor que la flecha cuando el cuerpo
abarca varias líneas:

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
tupla**. Si por el pipe fluyen pares, como los que dan
`list.zip` o `list.enumerate`, destructuras en el acto, sin un
`let` intermedio:

```kai
let pares = list.zip(xs, ys)
let sumas = pares | { (a, b) -> a + b }

list.foreach(list.enumerate(filas)) { (i, fila) ->
  println("#{i}: #{fila}")
}
```

El patrón tiene que ser **irrefutable**: `(a, b)` sobre un par
siempre calza. Un patrón que puede fallar, `(Some(n))` digamos,
se rechaza con un diagnóstico de match no exhaustivo; para
esos casos está `match`. Y ojo con una asimetría deliberada: la
destructuración es exclusiva del bloque-lambda. La forma con
flecha `(a, b) => ...` sigue siendo una lambda de **dos
parámetros**, no una que recibe un par.

Ninguno de estos azúcares agrega semántica: el compilador los
desazucara antes de la inferencia de tipos. Úsalos cuando la
lectura mejore, ignóralos cuando no.

Las formas una tras otra: las tres primeras dan el mismo
resultado, y las dos últimas muestran para qué sirven las
llaves cuando el cuerpo crece o el parámetro es un par.

```kai
# ejemplos/cap06/08_trailing_y_bloques.kai
fn main() {
  let xs = [1, 2, 3, 4, 5]

  # 1. Forma con paréntesis y flecha clásica.
  let a = list.map(xs, n => n * 2)
  println("a sum=#{list.sum(a)}")

  # 2. Trailing lambda: el cuerpo va en llaves al final.
  let b = list.map(xs) { n -> n * 2 }
  println("b sum=#{list.sum(b)}")

  # 3. Bloque-lambda en pipe: la forma más compacta.
  let c = xs | { n -> n * 2 }
  println("c sum=#{list.sum(c)}")

  # Cuerpos de varias líneas: la forma con llaves se lee mejor.
  let d = xs
    | { n ->
      let cuadrado = n * n
      cuadrado + 1
    }
  println("d sum=#{list.sum(d)}")

  # 4. El parámetro puede ser un patrón de tupla: destructura
  #    el par en el acto, sin `let` intermedio.
  let pares = list.zip(xs, [10, 20, 30, 40, 50])
  let e = pares | { (a, b) -> a + b }
  println("e sum=#{list.sum(e)}")
}
```

```
$ kai run ejemplos/cap06/08_trailing_y_bloques.kai
a sum=30
b sum=30
c sum=30
d sum=60
e sum=165
```

## 6.6 Recursión y TCO obligatoria

kaikai promete que **toda llamada recursiva en posición de
cola se compila a un loop**. No consume stack, así que una
recursión larga no lo revienta.

Una llamada está en **posición de cola** si es lo último que
la función hace antes de devolver. Compara estas dos
versiones de `suma`:

```kai
# NO en posición de cola: la llamada deja pendiente `h + ...`
fn suma_naive(xs: [Int]) : Int {
  case []         -> 0
  case [h, ...t]  -> h + suma_naive(t)
}
```

Cuando `suma_naive(t)` devuelve, todavía hay que sumar `h`: la
llamada **no** es lo último. Cada llamada consume un frame del
stack.

```kai
# En posición de cola: la última cosa que hace cada rama es
# **solo** la llamada, sin operación pendiente.
fn suma_tco_loop(xs: [Int], acc: Int) : Int {
  case [], a         -> a
  case [h, ...t], a  -> suma_tco_loop(t, a + h)
}

fn suma(xs: [Int]) : Int = suma_tco_loop(xs, 0)
```

Aquí `suma_tco_loop(t, acc + h)` es **lo último** de cada rama
recursiva. La suma `acc + h` se evalúa antes y viaja como
argumento; cuando la llamada devuelve, la función actual
devuelve también, sin nada pendiente. El compilador detecta
este patrón y lo compila a un loop, sin frame nuevo.

```kai
# Esto funciona sin reventar el stack:
let muchos = [1..100_000]
suma(muchos)        # 5_000_050_000
```

El **acumulador** de `suma_tco_loop` es la forma estándar de
llevar una recursión naive a posición de cola: un parámetro
extra va cargando el resultado parcial, y al terminar lo
devuelves.

Esto importa por varias razones:

- **Sin TCO obligatoria, no podrías reemplazar `for` y
  `while`.** Con stack limitado, iterar sobre un millón de
  elementos te dejaría sin stack. Solo con TCO garantizada
  puedes programar con recursión.
- **Es una garantía del lenguaje.** Algunos lenguajes
  optimizan las llamadas de cola cuando se acuerdan; kaikai
  te lo promete. Una función cuya última expresión se llama a
  sí misma usa stack constante, siempre, sin heurísticas.
- **La recursión mutua también entra en la promesa, con una
  condición.** Si `es_par` termina llamando a `es_impar` y
  viceversa, el ciclo corre en stack constante en los dos
  backends: el compilador funde al grupo en una sola función
  auto-recursiva, y el ciclo se vuelve el mismo loop. Vale
  para ciclos de dos y más largos. La condición es que los
  miembros compartan
  **una sola firma**: mismos tipos de parámetro, mismo tipo de
  retorno, misma fila de efectos, y sin parámetros de tipo. Un
  ciclo donde discrepan gasta un frame por salto, y a suficiente
  profundidad muere con `kai: fiber stack overflow`.
- **Una llamada de cola que no cierra ciclo sí conserva su
  frame.** `f` llamando a `g`, donde `g` nunca vuelve a `f`, es
  una llamada ordinaria. La garantía es sobre ciclos, no sobre
  cualquier cosa escrita en posición de cola.
- **Nadie te avisa antes de tiempo.** El compilador no marca
  la recursión que creías en cola y no lo está: te enteras
  cuando el programa revienta el stack. Por eso la forma con
  acumulador se escribe desde el principio y no cuando duele.

El par clásico, más un ciclo de tres:

```kai
# Ciclo de dos.
fn par(n: Int) : Bool = if n == 0 { true } else { impar(n - 1) }

fn impar(n: Int) : Bool = if n == 0 { false } else { par(n - 1) }

# Ciclo de tres: la garantía no se limita a pares de funciones.
fn a(n: Int) : Bool = if n == 0 { true } else { b(n - 1) }

fn b(n: Int) : Bool = if n == 0 { false } else { c(n - 1) }

fn c(n: Int) : Bool = if n == 0 { true } else { a(n - 1) }

fn main() : Unit / Stdout {
  println("par(5000000)   = #{par(5000000)}")
  println("impar(5000000) = #{impar(5000000)}")
  println("a(5000000)     = #{a(5000000)}")
}
```

```
$ kai run ejemplos/cap06/10_recursion_mutua.kai
par(5000000)   = true
impar(5000000) = false
a(5000000)     = true
```

Cinco millones de saltos en cada ciclo, y ninguno crece el stack.
Sin la garantía, esto no llegaría al primer `println`.

Casi todas las funciones recursivas que escribas sobre listas
o árboles tendrán la forma `match xs { [] -> base; [h, ...t]
-> recursión }`. La versión naive (con operación pendiente) es
la primera que escribes; la versión con acumulador es la que
dejas. Para operaciones más complejas, las funciones de orden
superior (`list.foldl`, `reduce`) ya están escritas con TCO y
son casi siempre lo que querías.

Las dos versiones en un programa, y la lista de cien mil
elementos que solo la segunda recorre sin crecer en stack:

```kai
# ejemplos/cap06/05_recursion_tco.kai
# Recursión lineal NO en posición de cola: cada llamada deja
# pendiente la suma `h + ...`. Funciona pero crece en stack.
fn suma_naive(xs: [Int]) : Int {
  case [] -> 0
  case [h, ...t] -> h + suma_naive(t)
}

# Recursión en posición de cola: la última cosa que hace cada
# rama recursiva es **solo** la llamada, sin operación
# pendiente. kaikai la convierte a un loop.
fn suma_tco_loop(xs: [Int], acc: Int) : Int {
  case [], a -> a
  case [h, ...t], a -> suma_tco_loop(t, a + h)
}

fn suma(xs: [Int]) : Int = suma_tco_loop(xs, 0)

fn main() {
  let mil = [1..1000]
  println("suma 1..1000 (naive) = #{suma_naive(mil)}")
  println("suma 1..1000 (tco)   = #{suma(mil)}")

  # Con TCO podemos sumar listas mucho más grandes sin
  # preocuparnos por el stack:
  let cien_mil = [1..100_000]
  println("suma 1..100_000 (tco) = #{suma(cien_mil)}")
}
```

```
$ kai run ejemplos/cap06/05_recursion_tco.kai
suma 1..1000 (naive) = 500500
suma 1..1000 (tco)   = 500500
suma 1..100_000 (tco) = 5000050000
```

## 6.7 Caso de estudio: pipeline de transformación

Cerramos con un caso integrador. Tienes los pedidos de una
tienda, cada uno con id, monto y estado, y quieres el total a
cobrar **solo de los pendientes**, **con 10% de descuento en
los montos altos**:

```kai
# ejemplos/cap06/06_pipeline.kai
type Estado = Pendiente | Pagado | Cancelado

type Pedido = {
  id: Int,
  monto: Int,
  estado: Estado
}

# Funciones pequeñas, cada una hace una sola cosa.
fn esta_pendiente(p: Pedido) : Bool =
  match p.estado {
    Pendiente -> true
    Pagado -> false
    Cancelado -> false
  }

# Descuento: 10% sobre montos >= 1000, 0% en el resto.
fn aplicar_descuento(p: Pedido) : Pedido =
  if p.monto >= 1000 {
    Pedido { ...p, monto: p.monto - p.monto / 10 }
  } else {
    p
  }

fn monto_de(p: Pedido) : Int = p.monto
```

Cada función hace **una sola cosa**: una decide si un pedido
está pendiente, otra le aplica descuento si corresponde, otra
extrae el monto. Ninguna sabe del pipeline; todas sirven por
separado.

Y el pipeline las compone:

```kai
fn main() {
  let pedidos = [
    Pedido { id: 1, monto: 500, estado: Pendiente },
    Pedido { id: 2, monto: 2000, estado: Pendiente },
    Pedido { id: 3, monto: 1500, estado: Pagado },
    Pedido { id: 4, monto: 800, estado: Cancelado },
    Pedido { id: 5, monto: 1200, estado: Pendiente }
  ]

  # Pipeline: filtrar pendientes, aplicar descuento, sumar.
  let total =
    pedidos
      |? esta_pendiente
      | aplicar_descuento
      | monto_de
      |> list.sum

  println("total a cobrar: #{total}")
}
```

```
$ kai run ejemplos/cap06/06_pipeline.kai
total a cobrar: 3380
```

Cinco líneas, cuatro pasos: filtra los pendientes, aplica el
descuento, extrae el monto, suma. Si el cliente pide después
"agreguemos un cargo fijo de 100 a los pedidos > 5000",
escribes una función chica más y la metes en el pipeline:

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
de lectura lineal**. La complejidad vive en cada función; la
composición es trivial.

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
mecánica del ciclo. Reordenar, agregar o sacar un paso es una
línea en el pipeline y un refactor en la versión imperativa.

Si vienes de Java, JavaScript, C# o Kotlin, conoces algo
parecido en sus APIs de stream o iterator. En kaikai el
pipeline es sintaxis del lenguaje, no una API encima: no
envuelves la lista en un objeto especial ni llamas
`.collect()` al final; los pipes son tan ordinarios como `+`
o `*`.

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
`string.to_int : String -> Option[Int]`. Pista: una función
`Option[a] -> [a]` te ayuda: si es `Some(x)` devuelve `[x]`,
si es `None` devuelve `[]`. Ese paso es el flat-map natural.
