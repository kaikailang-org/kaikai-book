# Capítulo 3 · Tipos básicos y expresiones

Vamos a las primitivas. Este capítulo describe los siete tipos
básicos de kaikai, la forma de los literales, los operadores que
los manipulan, y cómo se atan a nombres con `let`. También
introduce algo que ya viste de pasada y vamos a fijar bien:
**`if` y los bloques son expresiones**, no sentencias.

Si leíste el capítulo 2, lo que viene es el contenido concreto
de aquellas advertencias. Si no lo leíste y vienes de un mundo
imperativo, vuelve. Te ahorra fricción.

## 3.1 Los siete tipos primitivos

kaikai tiene exactamente siete tipos primitivos:

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

`Nothing` es el opuesto. **Cero habitantes.** Ninguna expresión
produce un `Nothing` que el programa pueda usar. ¿Para qué
sirve, entonces? Para describir el tipo de retorno de cosas que
**nunca terminan normalmente**: un `panic(...)` que aborta el
proceso, un loop infinito, una función `forever` cuyo cuerpo no
puede salir. Una función `fn loop_eterno() : Nothing` le dice al
sistema de tipos que cualquier código después de llamarla es
inalcanzable, y por eso una expresión de tipo `Nothing` calza en
cualquier contexto donde se espere otro tipo. Te vas a topar con
`Nothing` rara vez, pero conviene tener el nombre.

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
un detalle pequeño que evita un bug clásico.

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
espacios extra en la salida. Las secuencias de escape (`\n`,
`\t`, `\u{HHHH}`, etc.) funcionan igual que en los strings
normales.

Los `Char` se escriben con comilla simple: `'a'`, `'\n'`,
`'\u{2603}'`. Un `Char` no es un `String` de longitud uno, son
tipos distintos. Eso evita una colección de bugs típicos de
lenguajes que confunden los dos.

## 3.3 Operadores aritméticos, lógicos y de comparación

Los operadores aritméticos:

```
+   suma
-   resta (también negación unaria)
*   producto
/   división
//  división entera explícita
%   módulo
```

Hay un detalle del que conviene hablar de inmediato. Cuando los
dos operandos son `Int`, **`/` hace división entera**, igual que
`//`:

```kai
let a : Int = 7
let b : Int = 2
println("a / b  = #{a / b}")     # 3
println("a // b = #{a // b}")    # 3
```

Si quieres una división con parte fraccionaria, los operandos
tienen que ser `Real`:

```kai
println("7.0 / 2.0 = #{7.0 / 2.0}")    # 3.5
```

Esto va a parecer raro si vienes de Python 3, donde `/` siempre
devuelve flotante y `//` es el que trunca. La convención de
kaikai es la opuesta: el operador respeta el tipo de los
operandos. La razón es que en kaikai no hay coerciones implícitas
entre `Int` y `Real`. Si quieres pasar uno a otro, lo conviertes
explícitamente con `int_to_real(...)` o `real_to_int(...)`.

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
Eso lo veremos en el capítulo 8; por ahora, todos los tipos
primitivos los implementan.

## 3.4 `let` y la propagación local de tipos

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
interno**, lo que produce un *shadowing* — el nombre local
oculta al externo:

```kai
let x = 42
{
  let x = 7      # OK: shadowing dentro del bloque
  println("#{x}")    # 7
}
println("#{x}")      # 42 — el de afuera no cambió
```

Esto es ortogonal a la mutación. No estás "cambiando `x`":
estás introduciendo un `x` distinto en un ámbito anidado, que
deja de existir cuando el ámbito se cierra. El de afuera nunca
fue tocado.

Para los casos donde necesitas una celda mutable de verdad,
kaikai te da `var`, junto con `@nombre` y `nombre := v`. Lo
viste en §2.2 y volveremos a ello en el capítulo 9 cuando
hablemos de efectos.

## 3.5 `if` como expresión

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

Una variante que conviene fijar: si un `if` no tiene `else`, su
valor implícito en la rama "falsa" es `()` — el único habitante
de `Unit`. Por eso un `if` sin `else` solo tiene sentido cuando
el cuerpo produce `Unit`:

```kai
if i <= n {
  println(label(classify(i)))
  loop(i + 1, n)
}
```

Es la forma habitual de "haz algo o sigue". Si una rama produce
un valor que no usas y la otra no produce nada, el sistema de
tipos se queja: o agregas un `else`, o cambias el `if` por algo
que solo se ejecuta por su efecto.

## 3.6 Bloques y el valor de un bloque

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

## 3.7 La diferencia entre `=` y `{ ... }` en el cuerpo de una función

El cuerpo de una función puede tomar dos formas. Lo viste en el
capítulo 1; lo fijamos acá.

Forma corta, con `=` y una sola expresión:

```kai
fn doble(x: Int) : Int = x * 2

fn signo(n: Int) : String =
  if n < 0 { "negativo" }
  else if n == 0 { "cero" }
  else { "positivo" }
```

Forma larga, con `{ ... }`:

```kai
fn cuadrado_mas_uno(x: Int) : Int = {
  let cuadrado = x * x
  cuadrado + 1
}
```

El compilador acepta las dos. La diferencia es para quien lee:

- **Forma corta** cuando la función es una expresión directa,
  sin pasos intermedios. Lee como una definición matemática.
- **Forma larga** cuando hay bindings intermedios o varios pasos
  que ayuda separar visualmente.

No hay forma "preferida": elige la que comunica mejor la
intención de esa función en particular. La regla habitual es
que las funciones de una línea van con `=`, y las que necesitan
respirar van con `{ ... }`.

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
