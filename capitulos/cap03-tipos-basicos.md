# Capítulo 3 · Tipos básicos y expresiones

Vamos a las primitivas. Este capítulo describe los siete tipos
básicos de kaikai, la forma de los literales, los operadores que
los manipulan, y cómo se atan a nombres con `let`. También
introduce algo que ya viste de pasada y vamos a fijar bien:
**`if` y los bloques son expresiones**, no sentencias.

Siete me pareció el número correcto: suficientes para no pelear
con el lenguaje en el día a día, pocos para tenerlos todos en la
cabeza. Si leíste el capítulo 2, lo que viene es el contenido
concreto de aquellas advertencias. Si no lo leíste y vienes de un mundo
imperativo, vuelve. Te ahorra fricción.

## 3.1 Los siete tipos primitivos

El día a día de kaikai se apoya en siete tipos básicos:

| Tipo | Para qué sirve | Literal de ejemplo |
|---|---|---|
| `Int` | Enteros con signo, 64 bits | `42`, `-7`, `1_000_000` |
| `Real` | Reales de doble precisión, IEEE 754 | `3.14`, `-0.5`, `1e10` |
| `Bool` | Verdadero / falso | `true`, `false` |
| `String` | Cadenas de texto Unicode | `"hola"`, `"α + β"` |
| `Char` | Un único carácter Unicode | `'a'`, `'\n'`, `'\u{2603}'` |
| `Unit` | El tipo con un solo valor | `()` |
| `Nothing` | El tipo vacío, sin habitantes | (no tiene literal) |

Los primeros cinco son lo que esperarías de cualquier lenguaje.
Los últimos dos merecen una explicación.

`Unit` es el tipo del valor `()`. Tiene un solo habitante. Es lo
que devuelve una función que "no devuelve nada útil": el
equivalente al `void` de C, pero es un tipo de verdad, con un
valor de verdad, que se puede pasar como argumento o guardar en
una variable. Un `println(...)` devuelve `Unit`. Un bloque que
termina sin un valor explícito devuelve `Unit`.

`Nothing` es el opuesto: cero habitantes. Ninguna expresión
produce un `Nothing` que el programa pueda usar. ¿Para qué
sirve, entonces? Para describir el tipo de retorno de cosas que
**nunca terminan normalmente**: un `panic(...)` que aborta el
proceso, un loop infinito, una función `forever` cuyo cuerpo no
puede salir. Una función `fn loop_eterno() : Nothing` le dice al
sistema de tipos que cualquier código después de llamarla es
inalcanzable, y por eso una expresión de tipo `Nothing` calza en
cualquier contexto donde se espere otro tipo. Te vas a topar con
`Nothing` rara vez, pero conviene tener el nombre.

Estos siete no son los únicos números del lenguaje. Hay enteros
de ancho fijo y tipos de precisión arbitraria, que veremos en la
sección 3.4, pero estos son los que vas a teclear el 95% del
tiempo.

## 3.2 Literales e interpolación de strings

Los literales numéricos admiten guion bajo como separador
visual:

```kai
let poblacion = 19_000_000
let pi        = 3.141_592
let escala    = 1e6
```

Los `String` se escriben con comillas dobles. La sintaxis más
útil del día a día es la **interpolación**:

```kai
let nombre = "kaikai"
let edad   = 1
println("Hola, #{nombre}. El lenguaje tiene #{edad} año.")
```

Salida:

```
Hola, kaikai. El lenguaje tiene 1 año.
```

Cualquier expresión cabe dentro de `#{...}`, no solo nombres.
Su valor se convierte a `String` automáticamente:

```kai
let a = 7
let b = 2
println("La suma de #{a} y #{b} es #{a + b}.")
```

Para concatenar strings sin interpolación se usa `++`:

```kai
let saludo = "Hola, " ++ nombre
```

El operador es `++`, no `+`, para no confundirlo con suma. Es
un detalle pequeño que evita un bug habitual.

Para mensajes que ocupan varias líneas, kaikai tiene **strings
con triple comilla**:

```kai
let mensaje = """
  Esto es un mensaje
  de varias líneas, que mantiene
  la indentación relativa al cierre.
  """
```

La indentación de cada línea se mide respecto al cierre `"""`,
así que puedes formatear el string visualmente sin que aparezcan
espacios extra en la salida. Las secuencias de escape funcionan
igual que en los strings normales.

El juego de escapes es corto y **cerrado**: `\n`, `\t`, `\r`,
`\0`, `\\`, `\"`, `\'`, más `\xHH` (exactamente dos dígitos
hexadecimales, un byte) y `\u{H..H}` (un codepoint, que kaikai
codifica en UTF-8). Cualquier otra cosa es error de
compilación, no un backslash que se evapora en silencio:

```
error: unknown escape sequence '\q'; write '\\q' for a literal backslash
  --> bad.kai:2:9
    |
  2 |   print("ruta: C:\qtemp")
    |         ^
```

Que esa lista sea corta y explícita es reciente. Hasta la
versión 0.110 el compilador no decodificaba nada: le pasaba el
texto crudo al backend y dejaba que el compilador de C
decidiera, así que el juego de escapes era el de C99 por
herencia accidental — un `\q` perdía el backslash sin decir
nada. Hoy la decodificación vive en un solo lugar del
compilador, con las mismas reglas para strings, `Char`, triple
comilla e interpolación.

Los `Char` se escriben con comilla simple: `'a'`, `'\n'`,
`'\u{2603}'`. Un `Char` no es un `String` de longitud uno, son
tipos distintos. Eso evita una familia de errores propios de
los lenguajes que confunden ambos.

## 3.3 Operadores aritméticos, lógicos y de comparación

Los operadores aritméticos:

```
+   suma                  (Int o Real)
-   resta / negación      (Int o Real)
*   producto              (Int o Real)
/   división              (Int o Real)
%   módulo                (Int o Real)
```

Los cinco están **sobrecargados por tipo**: funcionan tanto
con `Int` como con `Real`, y el resultado tiene el tipo de
los operandos. Lo que **no** existe es coerción implícita
entre `Int` y `Real`: no puedes mezclarlos en una misma
expresión. Si lo necesitas, conviertes explícitamente con
`int_to_real(...)` o `real_to_int(...)`.

El detalle que conviene fijar: `/` con dos `Int` ya trunca el
resto. Para obtener un cociente con parte fraccionaria, los
dos operandos tienen que ser `Real`.

```kai
let a : Int = 7
let b : Int = 2
println("a / b  = #{a / b}")     # 3: sobre Int, / trunca

let x : Real = 7.0
let y : Real = 2.0
println("x / y = #{x / y}")      # 3.5: sobre Real, hay parte
                                 #       fraccionaria
```

Si vienes de Python 3, hay un cambio de hábito. Allá `/`
siempre devuelve flotante; en kaikai el tipo manda: `Int /
Int` es `Int`, y si quieres parte fraccionaria conviertes
explícitamente o trabajas con `Real` desde el principio.

Y con negativos hay un segundo cambio de hábito, más
traicionero porque no da error: **`/` trunca hacia cero, y el
resto de `%` lleva el signo del dividendo.**

```kai
println("#{-17 / 5}")      # -3, no -4
println("#{-17 % 5}")      # -2, no 3
println("#{17 % -5}")      #  2: el signo lo pone el 17
```

Python decide al revés: usa división hacia abajo, así que
`-17 // 5` es `-4` y `-17 % 5` es `3`. Si vienes de C, Go,
Java o Rust, en cambio, kaikai hace lo que ya esperabas. La
identidad que se mantiene en todos los casos es
`(a / b) * b + a % b == a`.

La consecuencia práctica: si usas `%` para saber si algo es
par, para rotar un índice en un buffer circular o para
repartir en cubetas, y el valor puede ser negativo, vas a
recibir un resto negativo. `x % 2 == 1` es falso para todo `x`
negativo impar; lo que quieres preguntar es `x % 2 != 0`.

Los operadores lógicos son palabras, no símbolos:

```
and   or   not
```

```kai
if x > 0 and x < 10 { ... }
if not vacio { ... }
```

A la mayoría de los lenguajes que conoces les da por usar `&&`,
`||` y `!`. kaikai eligió palabras porque son más legibles, y
porque los símbolos están reservados para otras cosas (`||` es
flat-map en pipes, capítulo 6).

Los operadores de comparación son los habituales:

```
==  !=  <  >  <=  >=
```

Devuelven `Bool`. Funcionan sobre cualquier tipo que implemente
los protocolos `Eq` (para `==`/`!=`) y `Ord` (para los demás).
Eso lo veremos en el capítulo 9; por ahora, todos los tipos
primitivos los implementan.

## 3.4 Más números: anchos fijos y precisión arbitraria

`Int` y `Real` cubren casi todo el código que vas a escribir. El
resto tiene requisitos duros: hablar con C usando el ancho exacto
que la ABI espera, contar más allá de 2⁶³, o llevar cantidades
donde un redondeo binario es inaceptable. Para esos casos kaikai
trae dos familias más. No las vas a necesitar pronto, pero
conviene saber que existen y dónde terminan las garantías de
cada una.

### Enteros de ancho fijo

Cuatro tipos con ancho exacto: `Int32`, `UInt32`, `UInt64` e
`Int128`. El literal los nombra con un sufijo pegado a los
dígitos:

```kai
let w = 42i32 + 7i32
let grande : Int128 = 9223372036854775808i128   # 2⁶³: fuera del
                                                # alcance de Int
let mascara = 0xFFi32                           # el sufijo vale en
let bits    = 0b1010u8                          # cualquier base
```

Dos reglas los gobiernan. La primera: **no se mezclan con
`Int`**. Un `Int32` no unifica con un `Int`; sumarlos es error de
tipos, igual que mezclar `Int` con `Real`. Se convierte con
nombre y apellido: `int_to_int32(...)`, `int32_to_int(...)` y
los análogos para `u32`, `u64` e `i128`. Nada de coerciones
silenciosas, tampoco aquí.

La segunda: **la aritmética envuelve**. Sumar `1i32` al máximo
de `Int32` no promueve ni lanza excepción: da la vuelta en
complemento a dos, como en C.

```kai
let tope = 2147483647i32 + 1i32   # -2147483648
```

El ejemplo `ejemplos/cap03/05_ancho_fijo.kai` recorre las dos
reglas:

```
$ kai run ejemplos/cap03/05_ancho_fijo.kai
w = 49
tope = -2147483648
grande = 9223372036854775808
n32 + 1 = 11
de vuelta = 11
```

¿Cuándo los usas? Sobre todo en la frontera con C: en una firma
`extern "C"`, un `Int32` cruza como `int32_t`, un `UInt64` como
`uint64_t`: el ancho que declaras es el ancho que viaja
(capítulo 16). `Int128` además sirve solo: alcanza ~38 dígitos
donde `Int` se queda en ~19, con la misma aritmética de siempre.

### Precisión arbitraria: `BigInt`, `DecimalBig`, `Rational`

Cuando ningún ancho fijo basta, el stdlib ofrece tres tipos que
crecen lo que haga falta. Son opt-in, se importan y no vienen
cargados por defecto, porque su costo es real: valores en heap,
aritmética por software. kaikai te lo cobra solo cuando lo pides.

- **`BigInt`** (`import math.bigint`): entero de precisión
  arbitraria, nunca desborda. El sufijo `n` construye uno desde
  un literal de cualquier tamaño: `99n`, y también
  `18446744073709551616n`, que ya no cabe en `Int`. Cuando los
  dígitos llegan en runtime y no en el fuente, `bigint.from_literal("…")`
  los toma desde un string, con `_` permitido como separador.
- **`DecimalBig`** (`import decimal_big`): punto fijo sobre
  `BigInt`, pensado para cantidades decimales exactas. `add`,
  `sub` y `mul` son totales; `div` pide la escala destino de
  forma explícita, porque truncar es una decisión, no un
  accidente. Comparar `1.5` con `1.50` da igualdad: la escala no
  es parte del valor. Su hermano `Decimal` (`import decimal`)
  usa `Int128` como soporte: más liviano, con techo cerca de
  los 38 dígitos. También tiene sufijo: `12.0d` es un `Decimal`.
- **`Rational`** (`import rational`): fracción exacta, un par
  `num/den` sobre `BigInt` siempre reducido a términos mínimos.
  `1/2 + 1/3` es exactamente `5/6`, sin redondeo en ninguna
  parte.

Estos tipos son records con invariantes (un `Rational` siempre
está reducido, un `Decimal` lleva su escala), así que no se
construyen con el literal de record crudo, que se saltaría esa
lógica. La forma corta es el **constructor posicional**: un tipo
marcado con el atributo `#[constructor]` deja que `Tipo(args)`
llame a la función que lo construye de verdad. `Rational(1, 2)`
es `rational.make(1, 2)`, con la reducción incluida; `Complex(1.5,
2.0)` es `complex.mk(...)`. Es azúcar, no magia: la aridad tiene
que calzar con la función marcada: `Rational(5)`, con un solo
argumento, no existe (para eso está `rational.from_int(5)`).

El ejemplo `ejemplos/cap03/06_numeros_grandes.kai` muestra los
tres en acción:

```
$ kai run ejemplos/cap03/06_numeros_grandes.kai
a² = 1000000014000000049
d × 2 = 246913578024691357802469135780.246913578
1/2 + 1/3 = 5/6
```

Si vienes de Python, `BigInt` es lo que allá llaman simplemente
`int`: la diferencia es que en kaikai el entero de 64 bits es el
caso común y rápido, y la precisión arbitraria es la excepción
que se pide por su nombre. Y si tu problema es dinero, la
respuesta completa combina estos tipos con las unidades de
medida del capítulo 10: los decimales exactos ponen la
aritmética; las unidades, la disciplina de no sumar pesos con
dólares.

## 3.5 `let` y la propagación local de tipos

`let` ata un nombre a un valor. El tipo se infiere del lado
derecho:

```kai
let x = 42                 # x : Int
let y = 3.14               # y : Real
let nombre = "kaikai"      # nombre : String
```

Si quieres dejar el tipo explícito, lo anotas con `:`:

```kai
let x : Int  = 42
let y : Real = 3.14
```

La anotación no es solo decoración. Sirve para dos cosas:
documentar la intención cuando el tipo no es obvio, y guiar al
inferidor en los pocos casos en que la inferencia local no
alcanza. La regla práctica es **anotar los argumentos y el
retorno de las funciones públicas, dejar los `let` locales sin
anotación**. Así el tipo viaja por las firmas y el cuerpo se
queda limpio.

Una vez que un nombre se ata, no se puede volver a atar al mismo
nombre en el mismo bloque. La línea siguiente daría un error:

```kai
let x = 42
let x = 7        # error: nombre ya definido en este ámbito
```

Lo que sí puedes hacer es atar el mismo nombre **en un ámbito
interno**, lo que produce un *shadowing*: el nombre local
oculta al externo:

```kai
let x = 42
{
  let x = 7      # OK: shadowing dentro del bloque
  println("#{x}")    # 7
}
println("#{x}")      # 42: el de afuera no cambió
```

Esto es ortogonal a la mutación. No estás "cambiando `x`":
estás introduciendo un `x` distinto en un ámbito anidado, que
deja de existir cuando el ámbito se cierra. El de afuera nunca
fue tocado.

Para los casos donde necesitas una celda mutable de verdad,
kaikai te da `var`: `nombre := v` declara y escribe, y un
nombre desnudo lee. Lo viste en §2.2 y volveremos a ello en el
capítulo 12 cuando hablemos de efectos.

## 3.6 `if` como expresión

Un `if` en kaikai produce un valor:

```kai
let s = if x > 0 { "positivo" } else { "no positivo" }
```

Las dos ramas tienen que producir valores del mismo tipo, y ese
tipo es el del `if`. La sintaxis no usa `then`, no usa
paréntesis alrededor de la condición, y cada rama es un bloque.

Si la condición tiene varias ramas, se encadenan con `else if`:

```kai
fn signo(n: Int) : String =
  if n < 0 { "negativo" }
  else if n == 0 { "cero" }
  else { "positivo" }
```

Cada llave abre un bloque cuyo valor es el resultado de la rama.
La función entera es una sola expresión, atada a la firma con
`=`. No hay `return`.

Una variante que conviene fijar: **un `if` sin `else` siempre
tiene tipo `Unit`**. El compilador no completa la rama faltante
con un valor sintetizado; toma la decisión más simple posible y
dice "el tipo del `if` es `Unit`, y si la condición es falsa, el
valor es `()`".

Por eso la forma usual de un `if` sin `else` es un cuerpo que
se ejecuta por sus efectos:

```kai
if i <= n {
  println(label(classify(i)))
  loop(i + 1, n)
}
```

Es la forma habitual de "haz algo o sigue". Y si la rama del
`then` produce un valor de otro tipo, ese valor **se descarta
en silencio**: el `if` sigue siendo `Unit`:

```kai
if x > 0 {
  x + 1     # Int, pero se tira a la basura
}
```

Esto compila, no produce advertencia, y rara vez es lo que
querías. El error suele aparecer un poco más allá, cuando
intentas usar el resultado del `if`:

```kai
let r = if x > 0 { 42 }
println(int_to_string(r))   # error: r es Unit, no Int
```

La regla práctica es simple: si **te interesa el valor**, escribe
un `if/else` exhaustivo; si **te interesa el efecto**, escribe
un `if` solo, sin atarlo a nada.

## 3.7 Bloques y el valor de un bloque

Un bloque `{ ... }` es una **expresión** cuyo valor es el de la
última expresión adentro. Las líneas anteriores se ejecutan en
orden y sus valores se descartan, salvo cuando los atas con
`let`.

```kai
fn cuadrado_mas_uno(x: Int) : Int = {
  let cuadrado = x * x
  cuadrado + 1
}
```

`cuadrado` es un binding local. La última línea, `cuadrado + 1`,
es la expresión de retorno. No hay `return`; el valor del bloque
es el valor de la función.

Esto se compone con todo lo demás: una rama de `if` puede ser un
bloque, una rama de `match` también, el cuerpo de una lambda
también. Todo el lenguaje se reduce a expresiones que devuelven
valores.

## 3.8 Tres formas de cuerpo de función

El cuerpo de una función puede tomar **tres formas**. Lo viste
en el capítulo 1 y lo fijamos aquí; el cap. 6 vuelve sobre ellas
con más profundidad.

Forma corta, con `=` y una sola expresión:

```kai
fn doble(x: Int) : Int = x * 2

fn signo(n: Int) : String =
  if n < 0 { "negativo" }
  else if n == 0 { "cero" }
  else { "positivo" }
```

Forma larga, con `{ ... }` y bindings intermedios:

```kai
fn cuadrado_mas_uno(x: Int) : Int = {
  let cuadrado = x * x
  cuadrado + 1
}
```

Forma multi-clause, con `case` arms cuando la función decide
por la forma de sus argumentos:

```kai
fn signo(n: Int) : String {
  case 0            -> "cero"
  case k when k > 0 -> "positivo"
  case _            -> "negativo"
}
```

El compilador acepta las tres. La diferencia es para quien lee:

- **Forma corta** cuando la función es una expresión directa,
  sin pasos intermedios. Lee como una definición matemática.
- **Forma larga** cuando hay bindings intermedios o varios pasos
  que ayuda separar visualmente.
- **Multi-clause** cuando la función dispatcha por patrones
  sobre sus argumentos. Es lo natural para muchas funciones
  recursivas y para deciders sobre tipos suma.

No hay forma "preferida": elige la que comunica mejor la
intención de esa función en particular.

## Ejercicios

**3.1.** Escribe una función `fn fahrenheit_a_celsius(f: Real) :
Real` usando solo lo de este capítulo. Verifica que
`fahrenheit_a_celsius(32.0)` da `0.0` y que
`fahrenheit_a_celsius(212.0)` da `100.0`. Hazlo con `=` y una
sola expresión.

**3.2.** Escribe `fn es_par(n: Int) : Bool` y
`fn paridad(n: Int) : String`, donde `paridad` devuelve `"par"`
o `"impar"` según el caso. La segunda función debería usar la
primera, no repetir la lógica.

**3.3.** Dada la función:

```kai
fn precio_total(unidades: Int, precio_unitario: Int) : Int = {
  let subtotal = unidades * precio_unitario
  let iva = subtotal * 19 / 100
  subtotal + iva
}
```

¿Qué imprime `precio_total(3, 100)`? Modifica la función para
que el IVA se calcule correctamente como un porcentaje real
(con parte fraccionaria), no entero. ¿Qué tipos cambias?

**3.4.** Escribe `fn maximo(a: Int, b: Int, c: Int) : Int` que
devuelve el mayor de los tres argumentos, usando `if` como
expresión y sin `match` ni funciones del stdlib. ¿Cuántos
`else if` necesitas?

**3.5.** Lee la documentación del operador `++` y averigua qué
pasa si intentas escribir `"hola, " ++ 42`. ¿Compila? Si no,
¿cómo lo arreglas? Razona la respuesta antes de probar.
