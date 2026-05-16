# Capítulo 9 · Protocolos

Hasta acá viste cómo agrupar datos (records, tipos suma) y
cómo definir funciones que operan sobre esos datos. Lo que
falta es responder una pregunta concreta: **¿cómo le agregas
operaciones a un tipo desde fuera de su declaración?**

Por ejemplo: `Punto` es un record con dos campos. Quieres que
se imprima como `(3, 4)` cuando aparece en una interpolación.
¿Modificas el tipo? ¿Pasas una función al `println`? ¿Defines
una variante de `println` solo para `Punto`? Ninguna escala.

La respuesta de kaikai son los **protocolos**: un contrato con
nombre y un puñado de operaciones, que cualquier tipo puede
satisfacer. Conceptualmente, los protocolos hacen lo que las
**interfaces** de Go, los **traits** de Rust, los **protocols**
de Clojure y Elixir, y la parte fácil de las **typeclasses**
de Haskell. Pero kaikai elige un punto preciso del espacio de
diseño: **single-dispatch explícito, sin propagación de
constraints, sin tipos de orden superior**. Eso le saca
complejidad al sistema de tipos a cambio de algunas cosas que
no se pueden expresar, y este capítulo cubre las dos caras.

## 9.1 Por qué hay protocolos

Tres dolores concretos que los protocolos resuelven.

**Imprimir tus tipos sin escribir cada vez.** Cuando declaras
un record, querer imprimirlo en logs, en respuestas, en
errores, no debería costarte una función `usuario_a_string`
por cada tipo. Con `Show` implementado una vez, la
interpolación `"#{usuario}"` lo usa automáticamente.

**Igualdad estructural sin esfuerzo.** Cualquier tipo nuevo
necesita "esto es igual a aquello" en algún momento. Sin
protocolos, escribes `eq_punto`, `eq_cuenta`, `eq_factura`,
y vives el resto del proyecto recordando cuál nombre usaste
en cuál archivo. Con `Eq` implementado, la operación se llama
`eq` para todos.

**Comparación, hashing, serialización.** El mismo argumento
del párrafo anterior, multiplicado por las tres operaciones
estándar que casi todo tipo necesita en algún momento.

Sin protocolos, cada uno de los tres se resuelve con
convenciones de nombres caso por caso, o con `match` enormes
que enumeran cada tipo posible. Con un solo mecanismo, los
tres y los que vengan después se resuelven en una línea por
tipo.

## 9.2 Declarar un `protocol` y `impl`

La sintaxis es directa. Un protocolo declara un nombre y una
o más operaciones:

```kai
protocol Show {
  show(x: Self) : String
}
```

`Self` es un nombre reservado que se refiere al tipo que más
adelante implemente el protocolo. Cada operación menciona
`Self` al menos una vez: por eso se llama **single-dispatch**,
la operación se decide a partir de un único tipo, el de
`Self`.

Para implementarlo, escribes un `impl ... for ...`:

```kai
type Punto = { x: Int, y: Int }

impl Show for Punto {
  fn show(p: Punto) : String =
    "(" ++ int_to_string(p.x) ++ ", " ++ int_to_string(p.y) ++ ")"
}
```

Y a partir de ese momento, `show(p)` llama a tu
implementación cuando `p : Punto`:

```kai
fn main() {
  let p = Punto { x: 3, y: 4 }
  println(show(p))                # imprime "(3, 4)"
  println("p está en #{p}")       # interpolación: usa Show
}
```

Tres detalles que conviene fijar:

- **El cuerpo del `impl` lista las funciones del protocolo, una por una**, con la sintaxis estándar de `fn`. Cada `fn` en el bloque tiene que coincidir con la firma declarada en el `protocol`, sustituyendo `Self` por el tipo concreto.

- **Una sola implementación por par `(protocolo, tipo)`**. Si hay dos `impl Show for Punto` en la misma compilación, el compilador rechaza con "duplicate impl". No hay sobreescritura ni resolución contextual.

- **La regla orphan**: solo puedes implementar un protocolo `P` para un tipo `T` si `P` se declara en tu módulo **o** `T` se declara en tu módulo. Esto evita que dos paquetes externos definan implementaciones conflictivas para tipos que ambos importan. Es una limitación práctica, no del sistema de tipos.

## 9.3 Los cinco protocolos del stdlib

kaikai trae cinco protocolos en `stdlib/protocols.kai` que
vas a usar todo el tiempo. La tabla siguiente los lista con
sus operaciones:

| Protocolo | Operaciones | Para qué |
|---|---|---|
| `Show` | `show(x: Self) : String` | Convertir a string para imprimir |
| `Eq` | `eq(a: Self, b: Self) : Bool` | Igualdad |
| `Ord` | `cmp(a: Self, b: Self) : Int`, `min`, `max` | Orden total |
| `Hash` | `hash(x: Self) : Int` | Para tablas hash y conjuntos |
| `Serialize` | `to_string`, `from_string` | Conversión texto ↔ valor |

Los tipos primitivos (`Int`, `Real`, `Bool`, `String`, `Char`)
ya tienen implementaciones para los cinco protocolos. Cuando
declaras un tipo nuevo, eliges qué protocolos vale la pena
implementar para él.

`Ord` merece una nota: tiene **tres operaciones**, no una.
`cmp(a, b) : Int` devuelve un entero negativo si `a < b`, cero
si son iguales, positivo si `a > b`. Las otras dos,
`min(a, b)` y `max(a, b)`, devuelven uno de los dos
argumentos según el orden. Las tres se implementan juntas en
el mismo bloque:

```kai
impl Ord for Cuenta {
  fn cmp(a: Cuenta, b: Cuenta) : Int =
    if a.saldo < b.saldo { 0 - 1 }
    else if a.saldo > b.saldo { 1 }
    else { 0 }

  fn min(a: Cuenta, b: Cuenta) : Cuenta =
    if a.saldo < b.saldo { a } else { b }

  fn max(a: Cuenta, b: Cuenta) : Cuenta =
    if a.saldo > b.saldo { a } else { b }
}
```

Si `Ord` te da pereza implementar tres operaciones, espera a
§9.4: en muchos casos, el compilador las deriva por ti.

## 9.4 `#[derive(...)]` y cuándo usarlo

Para records donde la implementación obvia "delega en cada
campo" basta, kaikai te ofrece un atajo: la directiva
`#[derive(...)]` antes de la declaración de tipo.

```kai
#[derive(Show)]
type Persona = {
  nombre: String,
  edad: Int,
}

#[derive(Show, Eq)]
type Punto = {
  x: Int,
  y: Int,
}
```

`#[derive(Show)]` le dice al compilador "genérame un `Show` para
este record, recorriendo los campos y delegando en el `Show`
de cada tipo de campo". El resultado para `Persona`:

```
$ kai run ejemplo.kai
Persona { nombre: Ada, edad: 30 }
```

El formato canónico, `TipoNombre { campo: valor, ... }`,
es lo que el `#[derive(Show)]` produce, y es razonable para
debugging y logs. Si quieres otro formato (por ejemplo, el
clásico `(3, 4)` para un punto), escribes el `impl` a mano,
como en §9.1.

`#derive` funciona para los cinco protocolos del stdlib,
siempre que **cada campo del record también implemente** el
protocolo que estás derivando. Si tu record tiene un campo
cuyo tipo no tiene `Show`, `#[derive(Show)]` falla en compilación
con un mensaje que apunta al campo problemático.

La regla práctica:

- **Empieza con `#derive`**: es la forma más rápida y casi
  siempre correcta para records.
- **Cambia a `impl` manual** cuando la implementación derivada
  no te sirve: formato distinto, igualdad solo por algunos
  campos, comparación según un campo específico (no el orden
  natural).

Ya viste `#[derive(Show)]` sobre `Punto` en el tour (§1.6); acá
mostramos también la implementación manual y cuándo conviene
una sobre la otra.

## 9.5 Protocolos propios

Los cinco del stdlib son los más comunes, pero nada te impide
declarar los tuyos. Es exactamente la misma sintaxis que usa
el stdlib, pero en tu código:

```kai
protocol Drawable {
  dibujar(x: Self) : String
}

type Circulo = { radio: Int }
type Cuadrado = { lado: Int }
type Triangulo = { base: Int, altura: Int }

impl Drawable for Circulo {
  fn dibujar(c: Circulo) : String =
    "Círculo de radio " ++ int_to_string(c.radio)
}

impl Drawable for Cuadrado {
  fn dibujar(c: Cuadrado) : String =
    "Cuadrado de lado " ++ int_to_string(c.lado)
}

impl Drawable for Triangulo {
  fn dibujar(t: Triangulo) : String =
    "Triángulo " ++ int_to_string(t.base) ++ "x" ++ int_to_string(t.altura)
}
```

A partir de ese momento, tres tipos distintos comparten la
operación `dibujar`. La función polimórfica `dibujar` se
resuelve estáticamente: el compilador sabe en cada llamada
qué `impl` usar a partir del tipo del argumento.

`Drawable` es un ejemplo de juguete; los casos reales que
verás en código kaikai incluyen `Encodable` para distintos
formatos, `Loggable` para que el sistema de logging sepa
representar tu tipo, `Validable` para reglas de validación,
etc. Cualquier "comportamiento que comparten varios tipos"
es candidato.

## 9.6 Por qué no hay typeclasses al estilo Haskell

Los protocolos de kaikai pueden parecerse a las typeclasses
de Haskell (y se inspiran en ellas), pero son **deliberadamente
más simples**. Tres cosas que kaikai no hace y que Haskell sí:

**Sin constraints en firmas de funciones.** Esta es la
diferencia más visible. En Haskell, una función que ordena
una lista declara que el tipo del elemento tiene que tener
`Ord`:

```haskell
sort :: Ord a => [a] -> [a]
```

El `Ord a =>` es la **constraint**. Cuando llamas a `sort
xs`, el compilador busca por su cuenta el `Ord` para el tipo
de `xs` y se lo "inyecta" a la función sin que tú escribas
nada. La constraint viaja escondida.

En kaikai eso no existe. No puedes escribir:

```kai
fn ordenar[T : Ord](xs: [T]) : [T] = ...    # ERROR: kaikai no admite constraints
```

¿Cómo se ordena entonces una lista? La función recibe el
**comparador como un argumento explícito**:

```kai
fn sort_by[T](xs: [T], cmp: (T, T) -> Int) : [T] = ...
```

Y el call site **nombra** el comparador. Si `Transaccion`
implementa `Ord`, su `cmp` está disponible como una función
ordinaria, y la pasas:

```kai
list.sort_by(transacciones, cmp)   # cmp viene de impl Ord for Transaccion
```

La diferencia es chica de escribir pero grande conceptualmente:
en Haskell el `Ord` está implícito, en kaikai está explícito.
La función `sort_by` no "exige" que `T` tenga `Ord`: solo
exige que **alguien le pase una función de comparación**. Que
esa función venga de un `impl Ord for T` es decisión del que
llama, no de la firma de `sort_by`.

**Sin tipos de orden superior** (HKT). `protocol Functor[F[_]]`
no parsea. Los parámetros de tipo son siempre de primer
orden. Esto descarta una familia de abstracciones (Functor,
Monad, Applicative, etc.) que en Haskell son centrales y
que en kaikai se resuelven con efectos algebraicos (cap. 12)
y combinadores explícitos.

**Sin propagación de constraints**. Una función polimórfica
no "lleva" el `Ord` consigo a las funciones que llama. Si
llamas a algo que requiere `Ord`, le pasas el comparador.

¿Qué se gana con estas restricciones? Tres cosas:

- **Compilación rápida**. La inferencia de tipos sigue siendo
  Hindley-Milner extendido con efectos, sin el costo del
  resolver de constraints de Haskell.
- **Errores claros**. Si una función necesita `Ord` y no lo
  recibe, el error apunta al sitio donde te falta pasar el
  comparador. No hay cadenas de "no instance for
  `Ord (Maybe a)` because of `Ord a`".
- **El call site dice qué hace**. Cuando ves `list.sort_by(xs,
  cmp)`, sabes que se ordena con `cmp`. Cuando ves `sort xs`
  en Haskell, tienes que mirar la firma de `sort` para saber
  qué `Ord` se está usando.

¿Qué se pierde? Algunas abstracciones que en Haskell son
elegantes, particularmente todo lo que vive sobre Functor y
amigos. Ese trade-off es deliberado: las abstracciones que
kaikai prioriza viven en el sistema de efectos (cap. 12), no
en el sistema de tipos.

## 9.7 Operadores: `+`, `==`, `<` como protocolos

Una nota práctica: los operadores estándar **son** protocolos.
`==` es `Eq.eq`, `<` es comparación basada en `Ord.cmp`, `+`
es `Add.add`. Cuando declaras `impl Eq for Cuenta`,
automáticamente `c1 == c2` (con `c1, c2 : Cuenta`) llama a tu
implementación.

```kai
#[derive(Eq)]
type Punto = { x: Int, y: Int }

fn main() {
  let p = Punto { x: 3, y: 4 }
  let q = Punto { x: 3, y: 4 }
  if p == q { println("iguales") }   # usa Eq.eq derivado
}
```

Esto unifica la sintaxis: `+` para `Int`, `Real`, vectores,
matrices, monedas, todos los que tengan `impl Add for ...`.
`==` para todo lo que tenga `Eq`. La uniformidad no es
casualidad; es el primer beneficio de tener un mecanismo
único para "operaciones dispatched por tipo".

Los operadores que kaikai trata como protocolos:

| Operador | Protocolo | Op |
|---|---|---|
| `==`, `!=` | `Eq` | `eq` |
| `<`, `<=`, `>`, `>=` | `Ord` | `cmp` |
| `+`, `-`, `*`, `/` | `Add`, `Sub`, `Mul`, `Div` | `add`, `sub`, `mul`, `div` |
| `++` | `Concat` | `concat` |

Los tipos primitivos los implementan todos. Los tipos tuyos
los implementan cuando los declaras. Y cuando algún operador
no tiene sentido para un tipo, simplemente no lo implementas,
y el compilador rechaza esa expresión.

## Ejercicios

**9.1.** Define `type Distancia = { metros: Int }` y dale un
`impl Show` para que `show(d)` produzca `"42 m"`. Luego
prueba `println("la distancia es #{d}")`. Cuidado: la
interpolación funciona, pero recuerda el workaround del cap.
9 si llamas a otro protocolo dentro.

**9.2.** Define `type Carta = { palo: String, valor: Int }` y
dale `impl Ord` que ordene por `valor`. Verifica con tres
cartas que `cmp(c1, c2)` devuelve los números esperados.

**9.3.** Toma cualquier record que hayas escrito en capítulos
anteriores y agrégale `#[derive(Show, Eq)]` arriba de la
declaración. Verifica que `show` y `eq` funcionan sin que
hayas escrito nada más.

**9.4.** Declara un protocolo propio `Validable` con una
operación `validar(x: Self) : Result[String, Self]` que
devuelva `Ok(x)` si el valor es válido o `Err("razón")` si
no. Implementa `Validable` para `type Edad = { años: Int }`
de manera que rechace edades negativas o mayores a 130.

**9.5.** Lee el código del stdlib en
`stdlib/protocols.kai`. ¿Cuántas operaciones tiene `Hash`?
¿Cómo se usaría para implementar una tabla de hash de
`Cuenta`? Diseña la firma de la función que harías para
"buscar una cuenta por id" en una tabla de hash hipotética:
¿qué tendría que estar implementado en `Cuenta` para que
funcionara?
