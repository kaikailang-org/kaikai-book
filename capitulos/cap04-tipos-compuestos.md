# Capítulo 4 · Tipos compuestos

Los siete primitivos del capítulo anterior te dan piezas
sueltas. Para construir programas de verdad, las pegas en
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
  tengan la misma forma. Esto es deliberado: si quieres una
  posición, di posición.

- **El spread tiene reglas.** Solo un spread por literal, y
  tiene que ir primero: `Punto { x: 7, ...p }` es un error
  de parseo. Los inicializadores que sigan al spread tienen
  que ser nombrados (`x: expr`), no abreviados ni
  posicionales. Estas restricciones son a propósito: hacen
  obvio quién gana cuando hay duplicados.

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

## 4.2 Acceso a campos y destructuring

Acceder con `.` está bien para uno o dos campos. Cuando
necesitas varios campos a la vez, **destructuring** es más
limpio:

```kai
fn distancia_cuadrada(a: Punto, b: Punto) : Int = {
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
fn describir(p: Punto) : String = {
  let Punto { x, y } = p
  "(" ++ int_to_string(x) ++ ", " ++ int_to_string(y) ++ ")"
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

## 4.3 Listas

Una lista es una secuencia inmutable y enlazada de valores del
mismo tipo. El tipo se escribe con corchetes alrededor del
tipo del elemento: `[Int]`, `[String]`, `[Punto]`,
`[[String]]` (lista de listas).

Construir literales:

```kai
let primos = [2, 3, 5, 7, 11]
let vacia : [Int] = []
```

kaikai trae también **literales de rango**, que son azúcar
sintáctica que produce una lista:

```kai
let r1 = [1..10]        # [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
let r2 = [1..10..2]     # [1, 3, 5, 7, 9]
let r3 = [10..1..-1]    # [10, 9, 8, ..., 1]
```

Para extender una lista existente, usas `...` (spread):

```kai
let xs = [1, 2, 3]
let ys = [0, ...xs, 99]      # [0, 1, 2, 3, 99]
```

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
con `Option` y `Result` que vimos en §4.5: kaikai prefiere
encerrar la posibilidad de fallar en el tipo antes que
abortar en runtime.

Hay dos cosas más que conviene saber sobre el acceso por
índice. Una es que es **`O(n)`**: las listas son enlazadas, no
indexadas; recorrer hasta la posición `i` cuesta `i` pasos.
Para acceso aleatorio rápido kaikai tiene `Array[T]`, que
veremos en el capítulo 13.

La otra es que la sintaxis `xs[i]` que algunos lenguajes usan
para listas, en kaikai está reservada para `Array[T]`. Si la
escribes sobre una lista te la rechaza el typer. La razón es
la misma de antes: la sintaxis `xs[i]` sugiere acceso barato y
con resultado garantizado, lo que sería mentir sobre una lista
enlazada.

Para la mayoría del código, tampoco vas a querer indexar a
mano. Recursión sobre `[h, ...t]` o las funciones de orden
superior del capítulo 6 (`map`, `filter`, `reduce`) son la
forma natural de procesar listas.

Las listas son **inmutables**. No hay `xs[0] = 99`. Si
necesitas una lista modificada, construyes una nueva.

## 4.4 Strings, no listas de chars

Vale la pena detenerse un momento en algo que muchos lenguajes
mezclan: en kaikai, **un `String` no es una lista de `Char`**.
Son tipos distintos:

```kai
let s : String = "hola"
let cs : [Char] = ['h', 'o', 'l', 'a']
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

- `length(s)` (y su sinónimo explícito `byte_length(s)`) cuenta
  **bytes**, en O(1). Para `"á"` devuelve 2, porque "á" ocupa dos
  bytes en UTF-8; para `"☃"` devuelve 3.
- `char_count(s)` cuenta **codepoints Unicode**: el largo honesto
  en caracteres. Para `"á"` devuelve 1; para `"☃"`, 1 también.
- `chars(s)` decodifica el buffer y devuelve los **codepoints**
  como `[Char]`. `bytes(s)` devuelve los **bytes** como `[Char]`,
  uno por byte (un codepoint multibyte se parte en sus bytes).

```kai
import core.string
import core.list

fn main() {
  let s = "café"
  println("bytes:      #{string.length(s)}")              # 5
  println("codepoints: #{string.char_count(s)}")          # 4
  println("chars:      #{list.length(string.chars(s))}")  # 4
  println("bytes list: #{list.length(string.bytes(s))}")  # 5
}
```

```
$ kai run ejemplos/cap04/07_strings.kai
bytes:      5
codepoints: 4
chars:      4
bytes list: 5
```

La regla mental es corta: **`length` y `slice` razonan en bytes;
`char_count` y `chars` razonan en codepoints.** Que `length` sea
barato y por byte es una elección consciente. La representación
es UTF-8 y el indexado de `slice` y `char_at` es por byte, así que
`length` devuelve la unidad que esos cortes usan. Cuando lo que te
importa es el conteo de caracteres y no el de bytes, pides
`char_count` o `chars` y kaikai paga el costo de decodificar.
(Grafemas como "é" compuesta de `e` + tilde combinante son otra
capa todavía; ahí ni los codepoints alcanzan, pero rara vez los
necesitas.)

Para concatenar, ya lo viste en el capítulo 3, usas `++`:

```kai
let saludo = "hola, " ++ nombre
```

Y para interpolar, `#{...}` dentro de un literal `"..."`.

`++` está bien para juntar dos o tres pedazos. Pero cuidado con
armar un string grande pegando trozos en un loop: como un `String`
es inmutable, cada `++` copia todo lo acumulado para producir uno
nuevo, y eso te lleva a O(n²), el clásico cuadrático de la
concatenación. Para eso está `StringBuilder`: un acumulador de
texto que guarda los fragmentos a medida que los agregas y recién
al final los une en una sola pasada con `build`. El costo de
agregar es amortizado O(1), y todo el armado es O(n).

```kai
import string_builder
import core.list

fn unir(nombres: [String]) : String = {
  let sb = list.foldl(nombres, string_builder.new(),
                      (b, n) => string_builder.append(b, "#{n}, "))
  string_builder.build(sb)
}
```

```
$ kai run ejemplos/cap04/09_string_builder.kai
ana, ben, cleo,
```

`append` rinde el efecto `Mutable` (por dentro escribe en el
arreglo de fragmentos del builder), mientras que `build` es puro:
solo lee y junta. Fíjate que `unir` no declara `/ Mutable` en su
firma aunque maneje `append`: como el builder nace y muere adentro,
sin escapar, kaikai *enmascara* el efecto en el borde de la
función. Los detalles de la API (`new`, `with_capacity`,
`append_char`, `len`, `is_empty`) están en `kai doc string_builder`.

## 4.5 `Option` y `Result`: el día a día

Ya viste estos dos en el capítulo 2:

```kai
type Option[a] = None | Some(a)
type Result[e, a] = Err(e) | Ok(a)
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

fn parsear_edad(s: String) : Result[ErrorEdad, Int] =
  match string_to_int(s) {
    None -> Err(NoNumerica)
    Some(n) ->
      if n < 0 or n > 130 { Err(FueraDeRango) }
      else { Ok(n) }
  }
```

`Result[ErrorEdad, Int]` se lee como "un `Int` o un error de
tipo `ErrorEdad`". El error está en el primer parámetro y el
valor exitoso en el segundo, al revés de la convención que
usan algunos lenguajes; kaikai sigue la tradición de Haskell
en este punto.

Tres patrones que vas a ver mucho:

- **Encadenar una falla con `!`.** Si tienes una expresión que
  devuelve `Result[E, A]` y quieres "si falla, propaga el
  error; si no, sigue con el valor", escribes `expr!`. Esto
  lo viste en §2.3.
- **Funciones de orden superior**: `option.map`, `option.and_then`,
  `result.map_err`. Las cubrimos en el capítulo 6.
- **Convertir entre los dos**: `option.ok_or(error)` toma un
  `Option[a]` y un error de tipo `e` y devuelve un
  `Result[e, a]`. Útil cuando la pérdida de información del
  `None` ya no te alcanza.

`Option` y `Result` son tipos suma como cualquier otro. Los
hemos separado del capítulo 5 porque su rol en el diseño
cotidiano es central: los vas a usar antes de empezar a
declarar tus propios tipos suma.

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

Todo lo que vimos hasta aquí es inmutable: un record nuevo no
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

Un ejemplo completo: contar la frecuencia de cada palabra de
una lista, primero con un `HashMap`, y de paso usar un
`HashSet` para contar cuántas palabras distintas hay.

```kai
import collections.hashmap as hashmap
import collections.hashset as hashset

fn frecuencias(palabras: [String]) : hashmap.HashMap[String, Int] / Mutable = {
  let m = hashmap.empty()
  contar(m, palabras)
  m
}

fn contar(m: hashmap.HashMap[String, Int], palabras: [String]) : Unit / Mutable = match palabras {
  []           -> ()
  [p, ...rest] -> {
    let actual = match m[p] { Some(n) -> n  None -> 0 }
    hashmap.put(m, p, actual + 1)
    contar(m, rest)
  }
}

fn main() : Unit / Stdout + Mutable = {
  let texto = ["sol", "mar", "sol", "viento", "mar", "sol"]
  let m = frecuencias(texto)
  match m["sol"] {
    Some(n) -> Stdout.print("sol aparece #{int_to_string(n)} veces")
    None    -> Stdout.print("sol no aparece")
  }
  Stdout.print("palabras distintas: #{int_to_string(hashmap.size(m))}")

  # Un HashSet descarta duplicados al insertar.
  let vistas = hashset.empty()
  marcar(vistas, texto)
  Stdout.print("únicas vía set: #{int_to_string(hashset.size(vistas))}")
}

fn marcar(s: hashset.HashSet[String], palabras: [String]) : Unit / Mutable = match palabras {
  []           -> ()
  [p, ...rest] -> { hashset.add(s, p); marcar(s, rest) }
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
