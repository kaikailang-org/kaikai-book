# Capítulo 4 · Tipos compuestos

Los tipos primitivos del capítulo anterior te dan piezas
sueltas. Para construir programas de verdad, los juntas en
estructuras: agregados con campos nombrados, listas, tuplas y
las dos joyas del stdlib que vas a ver más que cualquier otro
tipo, `Option` y `Result`.

Este capítulo cubre todo eso. Los **sum types** (`type Tag =
Foo | Bar(Int)`) que viste en el tour merecen su propio
capítulo y los tratamos en el 5.

## 4.1 Records

Un **record** es un agregado con campos nombrados. Lo declaras
con `type` y llaves:

```kai
type Punto = { x: Int, y: Int }

type Empleado = {
  nombre: String,
  edad: Int,
  sueldo: Int,
}
```

La coma final del último campo es opcional pero idiomática:
hace que agregar un campo nuevo no toque la línea anterior, lo
que mantiene los diffs de git limpios.

Para construir un valor del record, escribes el nombre del tipo
seguido de las llaves con los campos:

```kai
let origen = Punto { x: 0, y: 0 }
let p      = Punto { x: 3, y: 4 }
let ada    = Empleado { nombre: "Ada", edad: 30, sueldo: 1500 }
```

Y para leer un campo, usas `.`:

```kai
println("p está en (#{p.x}, #{p.y})")
println("#{ada.nombre} tiene #{ada.edad} años")
```

Eso es lo que necesitas para el día a día. Hay tres detalles
que conviene tener presentes:

- **Los records son inmutables.** No existe `p.x = 7`. Si
  necesitas un punto con un campo distinto, construyes uno
  nuevo a partir del original con la sintaxis de **spread**:

  ```kai
  let p  = Punto { x: 3, y: 4 }
  let p2 = Punto { ...p, x: 7 }    # Punto { x: 7, y: 4 }
  ```

  El `...p` copia todos los campos de `p`, y los inicializadores
  que vienen después (aquí `x: 7`) reemplazan los que se
  repiten. Es la misma idea del spread sobre listas que verás
  en §4.3, aplicada a records.

- **Los records son nominales.** `Punto { x: Int, y: Int }` y
  otro tipo `Posicion { x: Int, y: Int }` con los mismos
  campos son distintos. El compilador no los confunde aunque
  tengan la misma forma. Lo quise así: si quieres una
  posición, di posición.

- **El spread tiene reglas.** Solo un spread por literal, y
  tiene que ir primero: `Punto { x: 7, ...p }` es un error
  de parseo. Los inicializadores que sigan al spread tienen
  que ser nombrados (`x: expr`), no abreviados ni
  posicionales. Estas restricciones son a propósito: hacen
  obvio quién gana cuando hay duplicados.

Declaración, construcción, acceso y actualización funcional en
un programa:

```kai
# ejemplos/cap04/01_records.kai
type Punto = { x: Int, y: Int }

type Empleado = {
  nombre: String,
  edad: Int,
  sueldo: Int
}

fn distancia(a: Punto, b: Punto) : Int {
  let dx = a.x - b.x
  let dy = a.y - b.y
  dx * dx + dy * dy
}

fn main() {
  let origen = Punto { x: 0, y: 0 }
  let p = Punto { x: 3, y: 4 }

  println("origen.x = #{origen.x}, origen.y = #{origen.y}")
  println("p en (#{p.x}, #{p.y})")
  println("distancia² = #{distancia(origen, p)}")

  # Update funcional con `...`: copia todos los campos y
  # reemplaza los que se nombran después.
  let p2 = Punto { ...p, x: 7 }
  println("p2 en (#{p2.x}, #{p2.y})")

  let ada = Empleado { nombre: "Ada", edad: 30, sueldo: 1500 }
  println("#{ada.nombre} tiene #{ada.edad} años, sueldo #{ada.sueldo}")

  # Promoción: mismo empleado, sueldo nuevo.
  let ada_post = Empleado { ...ada, sueldo: 2200 }
  println("#{ada_post.nombre} ahora gana #{ada_post.sueldo}")
}
```

```
$ kai run ejemplos/cap04/01_records.kai
origen.x = 0, origen.y = 0
p en (3, 4)
distancia² = 25
p2 en (7, 4)
Ada tiene 30 años, sueldo 1500
Ada ahora gana 2200
```

### 4.1.1 Campos privados

Por defecto los campos de un record son públicos: cualquier
módulo que importe el tipo los puede leer y mencionar al
construir el record. La palabra `priv` antes del nombre del
campo invierte ese default:

```kai
# módulo `caja`
pub type Cuenta = {
  nombre:    String,      # público por defecto
  priv saldo: Real,       # privado al módulo `caja`
}

pub fn abrir(nombre: String) : Cuenta =
  Cuenta { nombre: nombre, saldo: 0.0 }

pub fn depositar(c: Cuenta, monto: Real) : Cuenta =
  Cuenta { ...c, saldo: c.saldo + monto }

pub fn saldo_de(c: Cuenta) : Real = c.saldo
```

Desde el módulo `caja` el campo `saldo` se lee y escribe
como cualquier otro. Desde fuera, no:

```kai
import caja

fn main() {
  let c = caja.abrir("ahorros")
  println("#{c.nombre}")          # OK, `nombre` es pública
  println("#{caja.saldo_de(c)}")  # OK, paso por el getter

  # Las dos líneas siguientes no compilan:
  # println("#{c.saldo}")             # ← field `saldo` is private to module `caja`
  # let d = caja.Cuenta {              # ← cannot construct `Cuenta` from outside …
  #   nombre: "x",
  #   saldo: 1000.0,
  # }
}
```

La regla es estricta: ni lectura desde afuera, ni mención
dentro de un literal de construcción. Si el módulo `caja`
quiere que un consumidor pueda crear cuentas, expone
constructores (`abrir`) y operaciones (`depositar`) que
mantengan los invariantes; el campo crudo queda escondido.

Esto convierte el record en un tipo abstracto liviano:
forma pública, interior bajo control del autor. Lo usaremos
así en el cap. 17 para esconder el estado del actor del
almacén, y en el cap. 18 para que los saldos del libro mayor
no se construyan por fuera del módulo de dominio.

El tipo con un campo privado, su constructor y la línea que el
compilador no deja pasar:

```kai
# ejemplos/cap04/06_priv.kai
type Cuenta = {
  nombre: String,
  priv saldo: Real
}

fn abrir(nombre: String) : Cuenta =
  Cuenta { nombre: nombre, saldo: 0.0 }

fn depositar(c: Cuenta, monto: Real) : Cuenta =
  Cuenta { ...c, saldo: c.saldo + monto }

fn saldo_de(c: Cuenta) : Real = c.saldo

fn main() {
  let c0 = abrir("ahorros")
  let c1 = depositar(c0, 100.0)
  let c2 = depositar(c1, 50.0)
  println("#{c2.nombre}: #{saldo_de(c2)}")
}
```

```
$ kai run ejemplos/cap04/06_priv.kai
ahorros: 150
```

## 4.2 Acceso a campos y destructuring

Acceder con `.` está bien para uno o dos campos. Cuando
necesitas varios campos a la vez, **destructuring** es más
limpio:

```kai
fn distancia_cuadrada(a: Punto, b: Punto) : Int {
  let Punto { x: ax, y: ay } = a
  let Punto { x: bx, y: by } = b
  let dx = ax - bx
  let dy = ay - by
  dx * dx + dy * dy
}
```

Cuando los nombres de los campos te sirven tal cual, puedes
omitir el `:` y dejar solo el nombre, atando el campo a una
variable del mismo nombre:

```kai
fn describir(p: Punto) : String {
  let Punto { x, y } = p
  "(#{x}, #{y})"
}
```

`let Punto { x, y } = p` es equivalente a
`let Punto { x: x, y: y } = p`, solo que más conciso.

El destructuring también funciona en `match`. Esa es su forma
más útil: decidir qué hacer **según los valores específicos
de los campos**.

```kai
fn clasificar(p: Punto) : String =
  match p {
    Punto { x: 0, y: 0 } -> "origen"
    Punto { x: 0, y: _ } -> "eje Y"
    Punto { x: _, y: 0 } -> "eje X"
    Punto { x, y }       -> "punto en (#{x}, #{y})"
  }
```

El compilador verifica exhaustividad, igual que con sum types:
si quitas la última rama, no compila. La exhaustividad sobre
campos `Int` la cubre el patrón final `Punto { x, y }`, que
calza con cualquier `Punto`. Sin esa rama, el `match` no es
total.

Las tres formas de abrir un record, una después de la otra:

```kai
# ejemplos/cap04/02_destructuring.kai
type Punto = { x: Int, y: Int }

fn describir(p: Punto) : String {
  let Punto { x, y } = p
  "(#{x}, #{y})"
}

fn clasificar(p: Punto) : String =
  match p {
    Punto { x: 0, y: 0 } -> "origen"
    Punto { x: 0, y: _ } -> "eje Y"
    Punto { x: _, y: 0 } -> "eje X"
    Punto { x, y } -> "punto en (#{x}, #{y})"
  }

fn main() {
  println(describir(Punto { x: 3, y: 4 }))
  println(clasificar(Punto { x: 0, y: 0 }))
  println(clasificar(Punto { x: 0, y: 7 }))
  println(clasificar(Punto { x: 5, y: 0 }))
  println(clasificar(Punto { x: 2, y: 9 }))
}
```

```
$ kai run ejemplos/cap04/02_destructuring.kai
(3, 4)
origen
eje Y
eje X
punto en (2, 9)
```

## 4.3 Listas

Una lista es una secuencia inmutable y enlazada de valores del
mismo tipo. El tipo se escribe con corchetes alrededor del
tipo del elemento: `[Int]`, `[String]`, `[Punto]`,
`[[String]]` (lista de listas).

Construir literales:

```kai
let primos = [2, 3, 5, 7, 11]
let vacia: [Int] = []
```

kaikai trae también **literales de rango**, que para el sistema
de tipos son una lista más:

```kai
let r1 = [1..10]        # [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
let r2 = [1, 3..10]     # [1, 3, 5, 7, 9]
let r3 = [10, 9..1]     # [10, 9, 8, ..., 1]
```

Los dos últimos llevan paso, y el paso no se escribe: se deduce
de los dos primeros elementos. `[1, 3..10]` avanza de dos en dos
porque `3 - 1` es dos, y `[10, 9..1]` baja porque la resta sale
negativa. Es la forma de Haskell, y tiene una ventaja sobre
anotar el paso aparte: lo que lees es lo que vas a obtener,
empezando por los dos primeros elementos de la lista.

Un detalle de costo que conviene saber: el rango es **lazy**. El
runtime lo guarda como tres números (inicio, fin, paso), no como
diez celdas, y los elementos se generan recién cuando algo los
consume. `[1..1_000_000] |> list.sum` no materializa un millón
de celdas; para tu código es indistinguible de la lista escrita
a mano.

Para extender una lista existente, usas `...` (spread):

```kai
let xs = [1, 2, 3]
let ys = [0, ...xs, 99]      # [0, 1, 2, 3, 99]
```

A diferencia del spread de records, el de listas admite los que
quieras y en cualquier posición del literal: `[...a, ...b]`
funciona, y `[...a, 9, ...b, 10]` también.

Échale mano cuando estés poniendo un elemento adelante. De
`[h] ++ t` sale exactamente la misma lista:

```kai
fn anteponer(h: Int, t: [Int]) : [Int] = [h, ...t]
fn anteponer_concat(h: Int, t: [Int]) : [Int] = [h] ++ t
```

La diferencia no es solo de lectura. `[h, ...t]` dice "una lista
que empieza con `h` y sigue con `t`", que es la misma forma del
patrón con que la vas a descomponer después, y emite el cons
directo. `[h] ++ t` dice "pega estas dos listas", y para eso
construye una lista de un elemento que existe solo para ser
pegada, y eso pide memoria una vez por llamada.

Medir eso tiene su truco, y vale la pena saberlo antes de
intentarlo. Si pones las dos formas en un `bench` cuyo cuerpo
descarta el resultado, cada iteración cuesta menos que la
resolución del reloj y el reporte te devuelve ruido (§7.4
explica cómo se reconoce). Con el resultado consumido, compilado
con `--release`, tres millones de iteraciones sobre una cola de
ocho elementos, en mi máquina: **0,05 s para el spread contra
0,11 s para el concat**.

`kai lint` marca la segunda forma como
`list_concat_literal_to_spread`.

Nada de esto es un argumento contra `++`. Concatenar dos listas
que ya existen es exactamente para lo que está.

Y para descomponerlas, los patrones de `match`:

```kai
fn suma(xs: [Int]) : Int =
  match xs {
    [] -> 0
    [h, ...t] -> h + suma(t)
  }
```

`[]` calza con la lista vacía. `[h, ...t]` calza con cualquier
lista no vacía, atando `h` al primer elemento (la "cabeza") y
`t` al resto (la "cola"). Estos dos patrones cubren todos los
casos posibles, lo que hace al `match` exhaustivo.

Patrones más específicos también son legales:

```kai
match xs {
  []                       -> "vacía"
  [unico]                  -> "uno: #{unico}"
  [primero, segundo, ...]  -> "al menos dos"
}
```

El compilador requiere que cubras todos los casos, así que si
escribes solo `[]` y `[h, ...t]` te alcanza para cualquier
lista; pero si quieres distinguir el caso de "exactamente un
elemento", escribes `[unico]` antes del catch-all.

Una convención del lenguaje: si la cola **te interesa**, le
das un nombre, `[h, ...t]`, y después usas `t`. Si **no te
interesa**, escribes `...` solo, sin nombre: `[h, ...]`. Es
la diferencia entre "tomo la cabeza, el resto lo guardo para
después" y "tomo la cabeza, el resto lo descarto". Un nombre
inventado que no se usa es ruido visual; la forma corta
comunica la intención sin pedirte un nombre que no aporta.

Para acceder por índice, el stdlib expone `list.nth`:

```kai
let primero = list.nth(xs, 0)    # Option[Int]
let tercero = list.nth(xs, 2)    # Option[Int]
```

Fíjate en el tipo de retorno: **`Option[a]`**, no `a`. Una
lista enlazada no garantiza que un índice exista: si pides
el elemento número 99 de una lista de tres, no hay valor que
devolver. El tipo te obliga a considerarlo. Esto es coherente
con `Option` y `Result` que conociste en §4.5: kaikai prefiere
encerrar la posibilidad de fallar en el tipo antes que
abortar en runtime.

Hay dos cosas más que conviene saber sobre el acceso por
índice. Una es que es **`O(n)`**: las listas son enlazadas, no
indexadas; recorrer hasta la posición `i` cuesta `i` pasos.
Para acceso aleatorio hay otros dos tipos: `Vec[T]`, que viene
en un momento, y `Array[T]`, que conocerás en el capítulo 12.

La otra es que la sintaxis `xs[i]` que algunos lenguajes usan
para listas, sobre una lista te la rechaza el typer: indexar
es para `Vec` y `Array`. La razón es la misma de antes: `xs[i]`
sugiere acceso barato y con resultado garantizado, lo que sería
mentir sobre una lista enlazada.

Para la mayoría del código, tampoco vas a querer indexar a
mano. Recursión sobre `[h, ...t]` o las funciones de orden
superior del capítulo 6 (`map`, `filter`, `reduce`) son la
forma natural de procesar listas.

Las listas son **inmutables**. No hay `xs[0] = 99`. Si
necesitas una lista modificada, construyes una nueva.

Construcción, rangos, recorrido recursivo y patrones en un solo
programa:

```kai
# ejemplos/cap04/03_listas.kai
fn suma(xs: [Int]) : Int =
  match xs {
    [] -> 0
    [h, ...t] -> h + suma(t)
  }

fn longitud[a](xs: [a]) : Int =
  match xs {
    [] -> 0
    [_, ...t] -> 1 + longitud(t)
  }

fn main() {
  let primos = [2, 3, 5, 7, 11]
  let rango = [1..10]  # [1, ..., 10]
  let pares = [2, 4..20]  # [2, 4, ..., 20]
  let combinada = [0, ...primos, 13]  # spread

  println("primos: longitud=#{longitud(primos)}, suma=#{suma(primos)}")
  println("rango : longitud=#{longitud(rango)}, suma=#{suma(rango)}")
  println("pares : longitud=#{longitud(pares)}, suma=#{suma(pares)}")
  println("combo : longitud=#{longitud(combinada)}, suma=#{suma(combinada)}")
}
```

```
$ kai run ejemplos/cap04/03_listas.kai
primos: longitud=5, suma=28
rango : longitud=10, suma=55
pares : longitud=10, suma=110
combo : longitud=7, suma=41
```

### `Vec[T]`: indexar sin renunciar a los valores

Cuando de verdad necesitas indexar, la respuesta por defecto
es `Vec[T]`: un buffer plano y contiguo, con acceso `O(1)`,
que **se comporta como un valor**. Nada de efectos, ninguna
operación es mutable.

Las operaciones viven en `collections.vec` y se usan
calificadas. Son las que esperas: `vec.get`, `vec.set`,
`vec.push`, `vec.length`, `vec.slice`, `vec.map`,
`vec.flat_map`, `vec.filter`, `vec.foldl`, `vec.from_list` y
`vec.to_list`. El `a[1]` del ejemplo es la forma corta de
`vec.get(a, 1)`. Los pipes del capítulo 6 corren sobre un
`Vec` igual que sobre una lista: `|` va a `vec.map`, `||` a
`vec.flat_map`, `|?` a `vec.filter` y `|!` a `vec.each`.

Un literal de lista en posición `Vec` construye el vector
directo, sin pasar por una lista enlazada. Y lo interesante está
en cómo escriben: `set` y `push` **devuelven** el vector
resultante en vez de modificar el que reciben.

```kai
# ejemplos/cap04/11_vec.kai
import collections.vec

fn main() : Unit / Stdout = {
  let a: Vec[Int] = [10, 20, 30]
  println("a[1] = #{a[1]}, igual que vec.get(a, 1) = #{vec.get(a, 1)}")

  # `set` y `push` devuelven el vector resultante; `a` no se toca.
  let b = vec.push(vec.set(a, 1, 99), 40)
  println("a = #{vec.to_list(a)}")
  println("b = #{vec.to_list(b)}")
}
```

```
$ kai run ejemplos/cap04/11_vec.kai
a[1] = 20, igual que vec.get(a, 1) = 20
a = [10, 20, 30]
b = [10, 99, 30, 40]
```

La anotación es la que manda: ese mismo `[10, 20, 30]` pelado,
sin el `: Vec[Int]`, sigue siendo una lista enlazada.

Fíjate en que `a` no cambió. Esa es la garantía y no tiene
excepciones: ningún nombre que apunte a un `Vec` ve nunca lo que
otro escribe.

Eso no quiere decir que cada escritura copie el buffer. Por
debajo el runtime mira si el buffer está compartido, con el mismo
conteo de referencias del cap. 13, y escribe en el lugar cuando
tiene un solo dueño. En el ejemplo `a` se usa *después* del
`set`, porque la línea siguiente lo imprime, así que en el
momento de escribir está compartido y la escritura copia. Si en
cambio enhebras el vector de forma lineal, al estilo acumulador,
donde cada paso es el único dueño del que recibe, no se copia
nada: construirlo pide memoria una sola vez.

Un slice es una vista de costo constante: `a[1..2]` no copia
elementos, comparte el buffer. Los extremos van incluidos, igual
que en un literal de rango.

Y `Array[T]`, que aparece en el capítulo 12, es la otra cara:
la referencia **mutable**, donde las escrituras sí se observan
desde todos los alias y cada una exige `/ Mutable`. La regla es
corta: `Vec` cuando quieras una colección que se comporte como
un valor, `Array` cuando quieras mutación compartida de verdad.

## 4.4 Strings, no listas de chars

Vale la pena detenerse un momento en algo que muchos lenguajes
mezclan: en kaikai, **un `String` no es una lista de `Char`**.
Son tipos distintos:

```kai
let s: String = "hola"
let cs: [Char] = ['h', 'o', 'l', 'a']
```

`s` y `cs` no son intercambiables. No puedes escribir
`s[0]` esperando un `Char`, y no puedes pasar un `String`
donde se espera `[Char]`.

¿Por qué? Porque en Unicode no hay una correspondencia simple
entre "carácter" e "índice". Un emoji puede ocupar varios
codepoints; una letra acentuada puede tener una o dos
representaciones; un grafema puede saltar bytes y codepoints
arbitrariamente. Tratar a un string como lista de chars te
obliga a tomar una decisión sobre qué cuenta como
"carácter", y todas las decisiones son malas para algún caso.

Por dentro, un `String` es un buffer UTF-8. Las operaciones que
tienen sentido viven en el módulo `string` del stdlib, y ahí kaikai
es deliberado con una distinción que muchos lenguajes esconden: la
diferencia entre **bytes** y **codepoints Unicode**. No son lo
mismo apenas sales del ASCII, y el nombre de cada función te dice
en qué unidad trabaja.

Tomemos `"café"` y midámoslo de las cuatro maneras.

- `length(s)` cuenta **bytes**, en O(1). Para `"café"` devuelve 5,
  no 4: la `é` ocupa dos bytes en UTF-8. `byte_length(s)` es el
  mismo número con el nombre dicho en voz alta, para cuando el
  código quede más claro si la unidad no se sobreentiende.
- `char_count(s)` cuenta **codepoints Unicode**. Para `"café"`
  devuelve 4, que es el largo que un lector diría en voz alta.
- `chars(s)` decodifica el buffer y entrega los codepoints como
  `[Char]`; `from_chars` los vuelve a armar.
- `bytes(s)` entrega los octetos crudos como `[Byte]`, uno por
  byte, partiendo en pedazos cualquier codepoint multibyte;
  `from_bytes` es su inverso.

Fíjate en que las dos vistas tienen **tipos distintos**: `[Char]`
son caracteres, `[Byte]` son octetos. No es un detalle cosmético.
Significa que no puedes cruzarlas por descuido: pasarle a
`from_chars` el resultado de `bytes(s)` no compila, porque un
octeto no es un carácter y el compilador lo sabe.

```kai
import core.string
import core.list

fn main() {
  let s = "café"
  println("bytes:      #{string.length(s)}")              # 5
  println("codepoints: #{string.char_count(s)}")          # 4
  println("chars:      #{list.length(string.chars(s))}")  # 4
  println("bytes list: #{list.length(string.bytes(s))}")  # 5
  println("de vuelta:  #{string.from_bytes(string.bytes(s))}")
}
```

```
$ kai run ejemplos/cap04/07_strings.kai
bytes:      5
codepoints: 4
chars:      4
bytes list: 5
de vuelta:  café
slice(2,2):      fé
byte_slice(2,3): Some(fé)
byte_slice(2,2): None
```

Esas últimas tres líneas son las dos maneras de sacar un pedazo de
un string. La diferencia entre ellas es la unidad:

```
slice(s: String, desde: Int, largo: Int) : String
byte_slice(s: String, desde: Int, largo: Int) : Option[String]
```

`slice` cuenta **codepoints**. Sacar `"fé"` de `"café"` es pedir dos
caracteres a partir del segundo: `slice(s, 2, 2)`. Si te pasas del
largo recorta en vez de fallar (`slice(s, 1, 9)` devuelve `"afé"`)
y nunca te puede entregar un string roto, porque no sabe cortar por
la mitad de un carácter.

`byte_slice` cuenta **bytes**, que es lo que necesitas cuando los
offsets vienen de otra parte: de un `index_of`, de un parser, de un
protocolo que mide en octetos. Como un byte cualquiera puede caer
dentro de un carácter, devuelve `Option`: `byte_slice(s, 2, 3)` da
`Some("fé")` porque 2 y 5 son bordes de codepoint, y
`byte_slice(s, 2, 2)` da `None` porque el 4 cae en medio de la `é`.
Si prefieres ajustar el offset en vez de que te lo rechacen, ahí
están `is_char_boundary`, `floor_char_boundary` y
`ceil_char_boundary`.

La regla mental es corta: **el nombre te dice la unidad.**
`length`, `byte_length`, `bytes` y `byte_slice` hablan de bytes;
`char_count`, `chars` y `slice` hablan de codepoints. La búsqueda
sigue el mismo par: `index_of` devuelve un offset de byte, que
alimenta a `byte_slice`, y `char_index_of` devuelve un índice de
codepoint, que alimenta a `slice`.

Que `length` cuente bytes y `slice` cuente codepoints no es un
descuido de coherencia. `length` es O(1) y no puede romper nada; un
corte por byte sí. Cada operación se queda con la unidad que no te
va a salir cara. (Grafemas como "é" compuesta de `e` + tilde
combinante son otra capa todavía; ahí ni los codepoints alcanzan,
pero rara vez los necesitas.)

El mismo cuidado aparece al pasar de minúsculas a mayúsculas y de
vuelta. `core.char` trae `to_upper`, `to_lower`, `is_upper` e
`is_lower` para ASCII. Su hermano `core.char_unicode` extiende los
cuatro a los alfabetos cuyo mapeo es un desplazamiento uniforme de
codepoint: Latin-1, Latin Extended-A, griego y cirílico. Lo que
cae fuera de esa regla pasa sin cambios, y kaikai prefiere
decírtelo con el nombre del módulo antes que fingir cobertura
completa de Unicode:

```kai
import core.char
import core.char_unicode
import core.list
import core.string

fn arriba(s: String) : String =
  string.from_chars(list.map(string.chars(s), char_unicode.to_upper))

fn main() : Unit / Stdout {
  Stdout.print(arriba("café"))
  Stdout.print(arriba("привет"))
  Stdout.print(arriba("omega"))
  Stdout.print(arriba("ωμεγα"))
  Stdout.print(arriba("ωμέγα"))
  Stdout.print(arriba("☃ 42"))
  Stdout.print("#{char.to_upper('k')}")
}
```

`arriba` es todo lo que hace falta: decodifica el string a
codepoints con `chars`, aplica `to_upper` a cada uno con `map`, y
vuelve a armar el string con `from_chars`. La última línea usa
`core.char` en vez de `core.char_unicode`, porque para ASCII basta.

```
$ kai run ejemplos/cap04/10_mayusculas.kai
CAFÉ
ПРИВЕТ
OMEGA
ΩΜΕΓΑ
ΩΜέΓΑ
☃ 42
K
```

La línea `ΩΜέΓΑ` marca el borde: `ωμεγα` se pliega entero, pero en
`ωμέγα` la `έ` se queda abajo porque su mayúscula no está a un
desplazamiento fijo. Para cubrir Unicode entero necesitas tablas
de conversión, y esas todavía no viven en el stdlib.

Para concatenar, ya lo viste en el capítulo 3, usas `++`:

```kai
let saludo = "hola, " ++ nombre
```

Y para interpolar, `#{...}` dentro de un literal `"..."`.

`++` está bien para juntar dos o tres pedazos. Pero cuidado con
armar un string grande pegando trozos en un loop: como un `String`
es inmutable, cada `++` copia todo lo acumulado para producir uno
nuevo, y eso te lleva a O(n²), el clásico cuadrático de la
concatenación.

Si lo que tienes es una lista de strings y un separador, ya está
resuelto: `string.join` recorre la lista una sola vez y no deja
separador colgando al final.

```kai
string.join(["ana", "ben", "cleo"], ", ")    # "ana, ben, cleo"
```

`StringBuilder` es para lo otro: cuando el resultado se arma de
pedazos que no son una lista uniforme. Es un acumulador de texto
que guarda los fragmentos a medida que los agregas y recién al
final los une en una sola pasada con `build`. Agregar cuesta O(1)
amortizado, y todo el armado es O(n).

```kai
import string_builder as sb
import core.list
import core.string

type Fila = { nombre: String, puntos: Int }

fn linea(f: Fila) : String =
  "\n#{string.pad_right(f.nombre, 8, ' ')}#{f.puntos}"

fn informe(filas: [Fila]) : String {
  let total = list.foldl(filas, 0, (acc, f) => acc + f.puntos)
  let cabecera = sb.append(sb.new(),
                           "#{list.length(filas)} filas, #{total} puntos")
  let cuerpo = list.foldl(filas, cabecera, (b, f) => sb.append(b, linea(f)))
  sb.build(cuerpo)
}
```

```
$ kai run ejemplos/cap04/09_string_builder.kai
3 filas, 40 puntos
ana     12
ben     7
cleo    21
```

La cabecera sale de un cálculo aparte y cada línea de una fila:
son fuentes distintas, y `join` no las cubre. El builder las
acumula sin volver a copiar lo ya juntado. El salto de línea va al
principio de cada fila, para que el resultado no termine en uno.

`append` rinde el efecto `Mutable` (por dentro escribe en el
arreglo de fragmentos del builder), mientras que `build` es puro:
solo lee y junta. Fíjate que `informe` no declara `/ Mutable` en
su firma aunque maneje `append`: como el builder nace y muere
adentro, sin escapar, kaikai *enmascara* el efecto en el borde de
la función. Los detalles de la API (`new`, `with_capacity`,
`append_char`, `length`, `is_empty`) están en
`kai doc string_builder`.

## 4.5 `Option` y `Result`: el día a día

Ya viste estos dos en el capítulo 2:

```kai
type Option[a] = None | Some(a)
type Result[a, e] = Ok(a) | Err(e)
```

Aquí los miramos en uso. Los dos son tipos suma genéricos del
stdlib que vas a usar **constantemente**. La idea, recordando:
`Option` representa "puede no haber valor"; `Result`,
"puede no haber valor o haber un error".

Una función que busca el primer elemento par de una lista:

```kai
fn primer_par(xs: [Int]) : Option[Int] =
  match xs {
    [] -> None
    [h, ...t] -> if h % 2 == 0 { Some(h) } else { primer_par(t) }
  }
```

Y quien la llama tiene que considerar los dos casos
explícitamente:

```kai
match primer_par(xs) {
  Some(n) -> println("encontré: #{n}")
  None    -> println("no había pares")
}
```

Una función que parsea una edad de un string puede fallar de
dos formas distintas, y eso es exactamente para lo que sirve
`Result`:

```kai
type ErrorEdad = NoNumerica | FueraDeRango

fn parsear_edad(s: String) : Result[Int, ErrorEdad] =
  match string_to_int(s) {
    None -> Err(NoNumerica)
    Some(n) ->
      if n < 0 or n > 130 { Err(FueraDeRango) }
      else { Ok(n) }
  }
```

`Result[Int, ErrorEdad]` se lee como "un `Int` o un error de
tipo `ErrorEdad`". El valor exitoso está en el primer parámetro
y el error en el segundo, como en Rust y la mayoría de los
lenguajes modernos.

Tres patrones que vas a ver mucho:

- **Encadenar una falla con `!`.** Si tienes una expresión que
  devuelve `Result[A, E]` y quieres "si falla, propaga el
  error; si no, sigue con el valor", escribes `expr!`. Esto
  lo viste en §2.3.
- **Funciones de orden superior**: `option.map`, `option.and_then`,
  `result.map_err`. Las cubrimos en el capítulo 6.
- **Convertir entre los dos**: `option.ok_or(error)` toma un
  `Option[a]` y un error de tipo `e` y devuelve un
  `Result[a, e]`. Útil cuando la pérdida de información del
  `None` ya no te alcanza.

`Option` y `Result` son tipos suma como cualquier otro. Los
saqué del capítulo 5 porque su rol en el diseño
cotidiano es central: los vas a usar antes de empezar a
declarar tus propios tipos suma.

Los dos tipos trabajando juntos: una búsqueda que puede no
encontrar nada y una validación que explica por qué falló:

```kai
# ejemplos/cap04/04_option_result.kai
type ErrorEdad = NoNumerica | FueraDeRango

fn primer_par(xs: [Int]) : Option[Int] =
  match xs {
    [] -> None
    [h, ...t] -> if h % 2 == 0 { Some(h) } else { primer_par(t) }
  }

fn parsear_edad(s: String) : Result[Int, ErrorEdad] =
  match string_to_int(s) {
    None -> Err(NoNumerica)
    Some(n) ->
      if n < 0 or n > 130 {
        Err(FueraDeRango)
      } else {
        Ok(n)
      }
  }

fn describir_edad(s: String) : String =
  match parsear_edad(s) {
    Ok(n) -> "edad válida: #{n}"
    Err(NoNumerica) -> "no es un número"
    Err(FueraDeRango) -> "fuera de rango"
  }

fn main() {
  let xs = [1, 3, 5, 6, 7]
  match primer_par(xs) {
    Some(n) -> println("primer par: #{n}")
    None -> println("no hay pares")
  }

  println(describir_edad("42"))
  println(describir_edad("hola"))
  println(describir_edad("999"))
}
```

```
$ kai run ejemplos/cap04/04_option_result.kai
primer par: 6
edad válida: 42
no es un número
fuera de rango
```

## 4.6 Tuplas

Una tupla es un agregado **posicional**: como un record, pero
sin nombres de campo. La sintaxis es paréntesis con elementos:

```kai
let punto2d = (3, 4)
let trio    = ("Ada", 30, true)
```

Su tipo se escribe igual: `(Int, Int)`, `(String, Int, Bool)`.

kaikai admite tuplas de **arity 2 a 4**. No hay tuplas de un
elemento: un paréntesis solo, `(e)`, es agrupación, no
tupla. Y `(a, b, c, d, e)` es un error de parseo.

¿Por qué la cota? Porque las tuplas largas son ilegibles. Si
estás llegando a 5 elementos, casi siempre lo que querías era
un record con campos nombrados.

Para descomponer una tupla, destructuring:

```kai
fn divmod(a: Int, b: Int) : (Int, Int) = (a / b, a % b)

fn main() {
  let (cociente, resto) = divmod(17, 5)
  println("17/5 = #{cociente}, resto #{resto}")
}
```

Por dentro, las tuplas son azúcar sobre tres records del
stdlib: `Pair[A, B]` para arity 2, `Triple[A, B, C]` para 3,
`Quad[A, B, C, D]` para 4. La declaración

```kai
let p = (1, 2)
```

es exactamente equivalente a

```kai
let p = Pair { fst: 1, snd: 2 }
```

Esto es útil saberlo cuando ves un tipo `Pair[Int, String]`
en una firma de stdlib: ahora sabes que es lo mismo que
`(Int, String)`, y que puedes destructurarlo con
`let (a, b) = p`.

Una función que devuelve dos valores y quien la llama los
separa en el `let`:

```kai
# ejemplos/cap04/05_tuplas.kai
fn divmod(a: Int, b: Int) : (Int, Int) = (a / b, a % b)

fn main() {
  let (cociente, resto) = divmod(17, 5)
  println("17 / 5 = #{cociente}, resto = #{resto}")

  # Una tupla de tres
  let punto3d = (1, 2, 3)
  let (x, y, z) = punto3d
  println("(#{x}, #{y}, #{z})")
}
```

```
$ kai run ejemplos/cap04/05_tuplas.kai
17 / 5 = 3, resto = 2
(1, 2, 3)
```

### ¿Tupla o record?

Cuando dudes, **usa un record**. Las tuplas son cómodas para
casos donde los nombres no aportan: el resultado de
`divmod`, donde "el primer valor es el cociente y el segundo
el resto" es información que el lector ya tiene del nombre de
la función. O cuando el agregado vive un solo paso:

```kai
xs |> map((e) => (e.nombre, e.edad))
```

Pero apenas el mismo agregado aparece más de una vez, o cruza
una frontera de módulo, o su forma es algo que el lector no
tiene cómo deducir, conviene un record. Un `Empleado` es
mucho más fácil de leer que un `(String, Int, Bool, String,
Int)`.

## 4.7 Mapas y conjuntos hash

Todo lo que usaste hasta aquí es inmutable: un record nuevo no
muta al viejo, una lista con un elemento más es una lista
nueva. Para la mayoría del código eso es lo que quieres. Pero
a veces necesitas una tabla asociativa de verdad (insertar
y buscar por clave en tiempo casi constante) y construir un
record nuevo en cada inserción no sirve. Para eso el stdlib
trae dos estructuras **mutables**: `HashMap[k, v]`, que asocia
claves a valores, y `HashSet[a]`, un conjunto sin duplicados.

Que sean mutables se nota en la fila de efectos: sus
operaciones rinden `Mutable`. Si vienes de Python o Java, un
diccionario que cambia en el lugar te suena obvio; lo nuevo
aquí es que el lenguaje lo dice en el tipo. Una función que
toca un `HashMap` lleva `/ Mutable` en su firma, y el
compilador te obliga a declararlo. No es burocracia gratuita;
es la misma honestidad con la que kaikai trata el resto de los
efectos. La inmutabilidad sigue siendo el default, y la mutación
queda marcada donde ocurre.

El acceso por clave usa la indexación `m[clave]`, que devuelve
un `Option` (`Some(v)` si la clave está, `None` si no), así
que la ausencia nunca te explota en la cara:

```kai
import collections.hashmap as hashmap

let actual = match m[p] {
  Some(n) -> n
  None    -> 0
}
hashmap.put(m, p, actual + 1)
```

El `match` sobre el `Option` tiene atajo: `m[p].unwrap_or(0)`
hace lo mismo en una expresión, y es lo que usa el ejemplo.

Un ejemplo completo: contar la frecuencia de cada palabra de
una lista, primero con un `HashMap`, y de paso usar un
`HashSet` para contar cuántas palabras distintas hay.

```kai
import collections.hashmap as hashmap
import collections.hashset as hashset

fn frecuencias(palabras: [String]) : hashmap.HashMap[String, Int] / Mutable {
  let m = hashmap.empty()
  palabras |! hashmap.put(m, ., m[.].unwrap_or(0) + 1)
  m
}

fn main() : Unit / Stdout + Mutable {
  let texto = ["sol", "mar", "sol", "viento", "mar", "sol"]
  let m = frecuencias(texto)
  match m["sol"] {
    Some(n) -> Stdout.print("sol aparece #{n} veces")
    None    -> Stdout.print("sol no aparece")
  }
  Stdout.print("palabras distintas: #{hashmap.size(m)}")

  # Un HashSet descarta duplicados al insertar.
  let vistas = hashset.empty()
  texto |! hashset.add(vistas, .)
  Stdout.print("únicas vía set: #{hashset.size(vistas)}")
}
```

```
$ kai run ejemplos/cap04/08_mapas.kai
sol aparece 3 veces
palabras distintas: 3
únicas vía set: 3
```

`hashmap.put` inserta o reemplaza en el lugar; `hashmap.get`
es la forma con nombre de `m[clave]`; `size`, `keys`,
`values`, `remove` y `contains` completan lo del día a día.
El `HashSet` es la cara sin valores: `add`, `contains`,
`size`, más las operaciones de conjunto `union`,
`intersection` y `difference`. La lista completa, con firmas,
sale de `kai doc collections/hashmap` y `kai doc
collections/hashset` (cap. 16 cubre `kai doc`).

Una nota de orden: ni el `HashMap` ni el `HashSet` prometen
un orden de recorrido. `keys`, `values` y `to_pairs` te
devuelven los elementos en el orden interno de los buckets,
que no es el de inserción. Si necesitas orden, ordena al
final o usa la estructura ordenada del stdlib (`Map`, sobre
árbol AVL).

`Map` además compara por contenido: dos mapas con los mismos
pares son iguales aunque se hayan construido insertando en
orden distinto. Por eso es la estructura correcta cuando el
resultado sale de la función y alguien lo va a comparar
contra una expectativa. El puente entre las dos familias vive
en `collections/convert`: `convert.to_map(h)` congela un
`HashMap` una vez que terminó la construcción rápida, y
`convert.to_hashmap(m)` hace el camino inverso.

## Ejercicios

**4.1.** Define un record `Libro` con campos `titulo`,
`autor` y `paginas`. Escribe una función `fn corto(b: Libro)
: Bool` que devuelva `true` si el libro tiene menos de 200
páginas. Construye dos libros y prueba la función.

**4.2.** Escribe una función `fn maximo(xs: [Int]) :
Option[Int]` que devuelva el mayor elemento de la lista, o
`None` si la lista está vacía. Hazlo con recursión y `match`.

**4.3.** Reescribe `fn parsear_edad` de §4.5 para que
distinga entre **tres** errores: no numérico, edad negativa,
edad > 130. Usa un tipo suma con tres constructores y un
`Result`.

**4.4.** Define una función
`fn separar(xs: [Int]) : ([Int], [Int])` que devuelva una
tupla con los pares y los impares de `xs`, en su orden
original. ¿Por qué tupla y no dos parámetros separados? ¿Y
por qué tupla y no un record?

**4.5.** Dado un `[Punto]` (con `Punto = { x: Int, y: Int }`),
escribe `fn centro(ps: [Punto]) : Option[Punto]` que devuelva
el promedio de coordenadas, o `None` si la lista está vacía.
Pista: vas a necesitar dos pasadas o un acumulador, y
`int_to_real` para promediar, pero nota que el resultado
final tiene que volver a ser `Punto` con campos `Int`, así
que también necesitas `real_to_int` (o conformarte con la
parte entera).

**4.6.** En un papel, sin escribir código, dibuja qué pasa en
memoria cuando ejecutas estas tres líneas:

```kai
let xs = [1, 2, 3]
let ys = [0, ...xs]
let zs = [99, ...xs]
```

¿Cuántas listas se crearon? ¿Cuántos elementos se copiaron?
¿Hay alguna celda que comparten `xs`, `ys`, `zs`? La respuesta
te ayuda a entender por qué la inmutabilidad no es cara
cuando las estructuras son enlazadas.
