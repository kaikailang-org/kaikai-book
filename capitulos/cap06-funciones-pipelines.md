# Capítulo 6 · Funciones y pipelines

Hasta acá fuiste viendo funciones a medida que las
necesitábamos: las primeras en el tour, las del cap. 3 con
sus dos formas de cuerpo, las recursivas del cap. 5 que
descomponen tipos suma. Este capítulo pone todo junto y
agrega lo que faltaba: cómo declarar funciones con cuidado,
cómo escribir lambdas, qué son las funciones de orden
superior, y los tres operadores pipe que kaikai usa para
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

El cuerpo puede ser una sola expresión, como arriba, o un
bloque `{ ... }` con `let`s intermedios y la expresión final
implícita:

```kai
fn cuadrado_mas_uno(x: Int) : Int = {
  let cuadrado = x * x
  cuadrado + 1
}
```

La regla práctica que ya viste en §3.7: cuerpo corto cuando
la función es directa, bloque cuando hay pasos intermedios.
El compilador acepta los dos.

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
# Forma 1 — flecha con un argumento
let cuadrado = (x) => x * x

# Forma 2 — flecha con varios argumentos
let suma = (a, b) => a + b

# Forma 3 — placeholder, lambda implícita unaria
xs |> list.filter(. > 0)
```

Las dos primeras son intercambiables; la elección es de
estilo. La tercera es **azúcar** que solo aplica cuando el
contexto **espera una función** — el segundo argumento de
`list.filter`, por ejemplo, es de tipo `(Int) -> Bool`, y el
compilador convierte `. > 0` en `(n) => n > 0`.

Las reglas del placeholder son cuatro:

- `.` solo funciona en posición donde se espera una función.
  Fuera de ahí es un error de compilación.
- Funciones unarias solamente. Para dos o más argumentos,
  flecha explícita.
- Múltiples ocurrencias del mismo `.` se refieren al **mismo
  valor**. Por ejemplo, `xs |> list.map(. * .)` eleva al
  cuadrado.
- El acceso a campo funciona: `personas |> list.map(.nombre)`
  proyecta el campo `nombre` de cada elemento.

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

Las lambdas son **valores de primera clase**: las atas a
`let`, las pasas como argumento, las devuelves de funciones,
las guardas en records. Eso es lo que hace que las funciones
de orden superior sean naturales.

## 6.3 Funciones de orden superior

Una **función de orden superior** es una que recibe o
devuelve otra función. Esa es toda la definición. Lo
interesante no es el nombre: es lo que te deja hacer.

El caso más simple es una función que aplica otra dos veces:

```kai
fn dos_veces[a](f: (a) -> a, x: a) : a = f(f(x))
```

`f` es el primer parámetro y su tipo es `(a) -> a` —
cualquier función que vaya de `a` a `a`. `dos_veces(mas_uno,
5)` calcula `mas_uno(mas_uno(5))` = `7`. La función es
**genérica** sobre el tipo `a`: funciona con `Int`, con
`String`, con cualquier tipo, mientras `f` mantenga el mismo
tipo de entrada que de salida. Las anotaciones `[a]` después
del nombre declaran el parámetro de tipo.

Un caso más interesante es una función que **devuelve** otra
función — un *closure*:

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
para abstraer **sobre el qué hacer**. En vez de escribir
`para cada elemento, hacer X` y `para cada elemento, hacer
Y`, escribes `para cada elemento, hacer F`, donde `F` es un
parámetro. Así nacen `list.map`, `list.filter`,
`list.fold`, todos los caballos de batalla de la programación
funcional.

## 6.4 Pipes: `|>`, `|`, `||`

kaikai trae tres operadores para encadenar. Los tres son
distintos y cada uno comunica una intención específica.

### `|>` — apply

`xs |> f` es exactamente `f(xs)`. El operador toma el lado
izquierdo y lo pone como **primer argumento** del llamado de
la derecha. Si `f` tiene varios argumentos, los demás van en
los paréntesis:

```kai
xs |> list.sum                   # ≡ list.sum(xs)
xs |> list.filter(es_par)        # ≡ list.filter(xs, es_par)
xs |> list.map((n) => n * 2)     # ≡ list.map(xs, (n) => n * 2)
```

Es un operador **general**: el lado derecho puede ser
cualquier llamada. Es lo que viene de Elixir y de F#.

### `|` — map

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

### `||` — flat-map

`xs || f` es `list.flat_map(xs, f)`. Cada elemento `x` produce
una **lista** `f(x)`, y el resultado es la concatenación de
todas las listas:

```kai
fn vecinos(n: Int) : [Int] = [n - 1, n, n + 1]

[10, 20, 30] || vecinos
# = [9, 10, 11, 19, 20, 21, 29, 30, 31]
```

`||` aparece menos que los otros dos en código del día a día,
pero cuando lo necesitas — expandir cada elemento a múltiples,
encadenar transformaciones que producen listas — la
alternativa es `xs |> list.map(f) |> list.concat`, que es
peor de leer.

### Todo junto

Los tres operadores se mezclan libremente:

```kai
let total =
  pedidos
  |> list.filter(esta_pendiente)
  | aplicar_descuento
  | monto_de
  |> list.sum
```

Cada paso del pipeline hace una sola cosa. La firma del
resultado se entiende de izquierda a derecha. No hay
variables temporales, no hay anidamiento de paréntesis. Esto
es la principal razón de que kaikai tenga tres operadores y
no uno.

## 6.5 Trailing lambdas y otros azúcares

kaikai trae varios azúcares sintácticos que vas a ver en
código real, sobre todo cuando uses funciones de orden
superior. Los principales:

### Trailing lambdas

Cuando una función toma una lambda como **último**
argumento, puedes sacarla de los paréntesis y ponerla en
llaves al final:

```kai
xs |> list.map { (n) => n * 2 }
xs |> list.filter { (n) => n > 0 }
```

Es equivalente a `xs |> list.map((n) => n * 2)`, solo más
amigable de leer cuando el cuerpo de la lambda es largo.

### Doble trailing lambda

Si los **dos** últimos argumentos son lambdas, los dos van en
llaves:

```kai
fn while(cond: () -> Bool, body: () -> Unit) : Unit / e = ...

while { @i < 10 } { i := @i + 1 }
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
fn suma_naive(xs: [Int]) : Int =
  match xs {
    []        -> 0
    [h, ...t] -> h + suma_naive(t)
  }
```

Acá, después de que `suma_naive(t)` devuelve, todavía hay que
sumar `h`. La llamada **no** es lo último; queda una operación
pendiente. Cada llamada consume un frame del stack.

```kai
# En posición de cola: la última cosa que hace cada rama es
# **solo** la llamada, sin operación pendiente.
fn suma_tco_loop(xs: [Int], acc: Int) : Int =
  match xs {
    []        -> acc
    [h, ...t] -> suma_tco_loop(t, acc + h)
  }

fn suma(xs: [Int]) : Int = suma_tco_loop(xs, 0)
```

Acá, en cada rama recursiva, `suma_tco_loop(t, acc + h)` es
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
(`list.fold`, `list.reduce`) ya están escritas con TCO y son
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
  |> list.filter(esta_pendiente)
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
  |> list.filter(esta_pendiente)
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
transformaciones, agregar un paso, sacar un paso — todas
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
`x`. Pista: `list.fold` con `aplicar` invertido es un buen
camino.

**6.5.** Tienes una lista de strings con números:
`["10", "abc", "20", "", "30"]`. Quieres la suma de los que
**sí son números válidos**, ignorando los demás. Construye
un pipeline usando `list.flat_map` (o `||`) y la función
`string_to_int : String -> Option[Int]`. Pista: una función
`Option[a] -> [a]` te ayuda — si es `Some(x)` devuelve `[x]`,
si es `None` devuelve `[]`. Ese paso es el flat-map natural.
