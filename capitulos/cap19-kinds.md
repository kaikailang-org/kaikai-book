# Capítulo 19 · Kinds: un catálogo de álgebras

Este capítulo paga una promesa que el §2.6 dejó abierta: en
kaikai el tipo no es la única etiqueta, y las familias de
etiquetas, los **kinds**, tienen un mecanismo común que
alguien te debía mostrar completo. Lo has venido tocando por
partes. Cuando en el capítulo 10 escribiste
`fn promedio[u: Measure](...)`, esa anotación `u: Measure` no era
un parámetro de tipo común: `u` no podía ser `Int` ni `String` ni
ningún tipo, solo podía ser una *unidad*. Estabas cuantificando
sobre otra familia de cosas, con otras reglas.

Y no hay uno solo. Los tipos que unifica el inferidor, las filas
de efectos que se componen en cada firma, las unidades que
multiplican y cancelan, las monedas del stdlib, las regiones de
memoria del runtime: cada una es un kind distinto, con su propia
álgebra. kaikai los declara a todos en un mismo lugar y con el
mismo mecanismo, y este capítulo recorre ese catálogo completo.

Es el capítulo más abstracto del libro, y por eso viene al final:
no necesitas nada de esto para escribir kaikai productivo. Pero si
llegaste hasta aquí, apuesto a que la pregunta ya te apareció
sola: ¿qué tienen en común las unidades del capítulo 10, los
efectos del 12 y la memoria del 13? La respuesta es corta y creo
que elegante. Vamos a verla.

## 19.1 Qué es un kind

Un tipo clasifica valores: `42` habita `Int`, `"hola"` habita
`String`. Un **kind** clasifica un peldaño más arriba: sus
habitantes son símbolos que participan en los tipos. `Int` habita el kind `Type`. La unidad `m` habita el kind
`Measure`. El efecto `Stdout` habita el kind `Effect`.

La consecuencia práctica la viste en el capítulo 10: un parámetro
`[u: Measure]` solo acepta unidades, y el compilador razona sobre
`u` con las reglas de las unidades: `u^2` tiene sentido, `u` y
`kg` unifican solo si son la misma. Compara con un parámetro
`[t]` corriente, que acepta tipos y se razona con las reglas de
los tipos. La anotación de kind le dice al compilador **qué
álgebra usar** cuando le toque decidir si dos cosas son iguales.

Eso es todo el concepto: un kind es una familia de habitantes,
más el álgebra con que el compilador los unifica. A esa álgebra
kaikai la llama **theory**.

## 19.2 Las theories: álgebras de unificación

Cuando el compilador ve `Real<m * s>` y `Real<s * m>`, ¿son el
mismo tipo? Para responder necesita saber que el producto de
unidades conmuta. Cuando ve dos filas de efectos `Stdout + Fail`
y `Fail + Stdout`, necesita saber que el orden de una fila no
importa. Cuando ve dos regiones `r1` y `r2`, necesita saber que
jamás son iguales salvo que sean literalmente la misma.

Cada una de esas preguntas se responde con una **theory**: un
conjunto de reglas de ecuación que el compilador aplica al
unificar habitantes de un kind. Tres cosas la definen:

- **Es decidible.** El algoritmo de unificación termina siempre,
  y rápido. No hay solver SMT ni búsqueda: son álgebras elegidas
  precisamente porque su unificación es un cálculo directo.
- **Se borra en runtime.** Igual que las unidades del capítulo
  10: la theory decide *en compilación* qué programas son
  legales, y desaparece del binario.
- **El catálogo es cerrado.** Puedes declarar habitantes nuevos
  (`unit parsec`) y hasta kinds nuevos (§19.5), pero no puedes
  declarar una theory nueva. Si lo intentas, el compilador
  responde `unknown theory`. El §19.12 defiende por qué es una
  decisión de diseño permanente y no una limitación transitoria.

## 19.3 El catálogo completo

El catálogo vive en `stdlib/core/kinds.kai`, y es corto. Este es
un extracto (el archivo real trae un comentario por entrada):

```kai
# fragmento de stdlib/core/kinds.kai
theory HindleyMilner  = builtin
theory EffectRow      = builtin
theory AbelianGroup   = { assoc, commut, inverse, identity }
theory Module         = { assoc, commut, inverse, identity }
theory Nominal        = builtin
theory ConstructorApp = builtin
theory Semilattice    = { assoc, commut, idempotent }
theory Composition    = { assoc, measure }

kind Type     : HindleyMilner  with type
kind Effect   : EffectRow      with effect
kind Measure  : AbelianGroup   with unit
kind Currency : Module over T  with currency
kind Region   : Nominal        with region
kind Perm     : Semilattice    with perm
kind Layout   : Composition over Int with layout { be le }
kind Dim      : HindleyMilner  with Int
kind Shape    : ConstructorApp
```

Cada `kind` nombra su theory y, tras el `with`, su **palabra
introductora**: la declaración que acuña habitantes. `type` acuña
habitantes de `Type`. `effect` acuña habitantes de `Effect`.
`unit` acuña habitantes de `Measure`. Dos kinds no siguen ese
molde: `Shape` no lleva `with` porque sus habitantes no se
declaran, se *derivan* (cada `type T[a]` de un solo parámetro ya
es uno), y `Dim` escribe `with Int`, lo que significa que sus
habitantes son *valores* de `Int` (`<3>`, `<128>`), no símbolos
acuñados. Llevas todo el libro acuñando habitantes de kinds; solo
faltaba el organigrama:

| Kind | Theory | Introductor | Habitantes | Qué decide la theory |
|---|---|---|---|---|
| `Type` | `HindleyMilner` | `type` | `Int`, `String`, los tuyos | igualdad e inferencia de tipos |
| `Effect` | `EffectRow` | `effect` | `Stdout`, `Cancel`, los tuyos | filas: orden irrelevante, duplicados colapsan |
| `Measure` | `AbelianGroup` | `unit` | `m`, `s`, `USD` si quieres | producto, cociente y potencia de unidades |
| `Currency` | `Module` | `currency` | `USD`, `EUR`, … (`stdlib/money.kai`) | suma y escala; **sin** producto |
| `Region` | `Nominal` | `region` | uno fresco por bloque `region` | identidad: cada arena es solo ella misma |
| `Perm` | `Semilattice` | `perm` | `read`, `write`, los tuyos | unión idempotente; subsunción por el orden del retículo |
| `Layout` | `Composition` | `layout` | `be`, `le` | orden de bytes; asociativa, **no** conmutativa |
| `Dim` | `HindleyMilner` | `with Int` | `<3>`, `<128>`: valores `Int` | igualdad de índices: `<3> ~ <3>`, nunca `<4>` |
| `Shape` | `ConstructorApp` | (derivados) | `List`, `Vec`, `Option`, `Tree[a]` | aridad-1: `List ~ List`, nunca `List ~ Vec` |

Cuatro theories dicen `builtin`: su motor es el compilador mismo.
`HindleyMilner` es el inferidor de tipos que te acompaña desde el
capítulo 3, y notarás que sirve a **dos** kinds, `Type` y `Dim`:
una theory nombra un motor de unificación, y nada obliga a que un
motor clasifique un solo kind. `EffectRow` es la unificación de
filas del capítulo 12; `Nominal` es igualdad de símbolo, que el
núcleo ya sabía hacer; `ConstructorApp` liga constructores de un
argumento, y lo vemos en §19.11. Las otras cuatro se describen por
propiedades algebraicas. Dos se ven casi idénticas,
`AbelianGroup` y `Module`, y la diferencia es *sobre qué
operación* rigen sus propiedades. En `AbelianGroup`, los
habitantes mismos forman un grupo bajo el producto: `m * s`, `m^2`,
`1/s` son habitantes nuevos derivados. En `Module`, la estructura
es solo aditiva: las *cantidades* de un habitante se suman y se
escalan por un número, pero los habitantes no se multiplican entre
sí. `USD^2` no es un habitante de `Currency`; no existe. Esa
asimetría es deliberada y el §19.7 la explota. `Semilattice` es una
unión idempotente sin inverso: los habitantes se juntan con `+`
(`read + write`, y `read + read = read`), y nada se resta; unificar
es subsunción por el orden del retículo, así que un permiso con más
capacidades fluye donde se piden menos, nunca al revés. Y
`Composition` es asociativa pero **no** conmutativa, porque el
orden carga significado, y suma una medida por elemento (§19.8).

Nota lo que **no** está en la tabla: nada tuyo. El catálogo
completo del lenguaje cabe en una pantalla. Nueve kinds, ocho
theories, y todo el libro que llevas leído está construido sobre
ellos.

## 19.4 Cuantificar sobre cualquier kind

Lo que hace que esto sea un *sistema*, en vez de cinco features
apiladas, es que la cuantificación funciona igual sobre cualquier
kind. Compara estas tres firmas:

```kai
fn area_de[u: Measure](ancho: Real<u>, alto: Real<u>) : Real<u^2>
fn insertar[r: Region](t: Arbol<r>, k: Int) : Arbol<r>
pub fn convert[a: Currency, b: Currency](m: Money[dec.Decimal]<a>, rate: dec.Decimal) : Money[dec.Decimal]<b>
```

La primera la escribiste en el capítulo 10. La segunda la vas a
ver en el §19.6. La tercera viene tal cual de `stdlib/money.kai`.
Las tres dicen lo mismo: "para cualquier habitante de este kind".
Y en las tres, el compilador aplica la theory del kind al
verificar el cuerpo: en `area_de` puede formar `u^2` porque
`AbelianGroup` tiene producto; en `insertar` exige que el árbol
que entra y el que sale vivan en la *misma* región porque
`Nominal` no unifica regiones distintas; en `convert` permite
que `a` y `b` difieran porque son dos parámetros: la puerta
explícita entre monedas del capítulo 10, ahora con su mecanismo a
la vista.

El listado 19.1 es la primera firma, completa y corriendo:

```kai
# Listado 19.1 — ejemplos/cap19/01_generica_sobre_unidades.kai
unit m
unit s

fn area_de[u: Measure](ancho: Real<u>, alto: Real<u>) : Real<u^2> =
  ancho * alto

fn main() : Unit / Stdout = {
  let a1 = area_de(3.0<m>, 4.0<m>)      # Real<m^2>
  let a2 = area_de(3.0<s>, 4.0<s>)      # Real<s^2>
  println("#{a1}")
  println("#{a2}")
}
```

```
$ kai run ejemplos/cap19/01_generica_sobre_unidades.kai
12 m^2
12 s^2
```

Fíjate en la salida: el `Show` de un `Real` con unidad imprime la
unidad, potencia incluida. "Segundos al cuadrado" es una unidad
rara en la física de este mundo, pero el álgebra no opina de
física: opina de consistencia.

## 19.5 Kinds propios

`Measure` no es especial. La declaración `kind` está disponible
para ti, con las tres theories no-builtin como opciones. Un caso
donde esto paga: separar sistemas de unidades que jamás deben
mezclarse, ni siquiera con una conversión accidental.

```kai
# Listado 19.2 — ejemplos/cap19/02_kind_propio.kai
kind Metrica  : AbelianGroup with metrica
kind Imperial : AbelianGroup with imperial

metrica m
metrica s
imperial ft

fn velocidad(d: Real<m>, t: Real<s>) : Real<m/s> = d / t

fn main() : Unit / Stdout = {
  let v = velocidad(100.0<m>, 9.58<s>)
  println("#{v}")

  # Esto no compila: m vive en Metrica, ft vive en Imperial.
  #   fn mala(a: Real<m>, b: Real<ft>) : Real<m> = a + b
}
```

```
$ kai run ejemplos/cap19/02_kind_propio.kai
10.4384 m/s
```

Cada `kind ... with palabra` acuña también su propia palabra
introductora: aquí `metrica` y `imperial` declaran habitantes
igual que `unit` lo hace para `Measure`. Dos habitantes de kinds
distintos **nunca** unifican, aunque ambos midan longitud. Dentro
del capítulo 10, `m + ft` era un error de unidades; aquí es un
error más profundo: ni siquiera hay un álgebra común donde
plantear la pregunta. Es la clase de bug del Mars Climate
Orbiter, libras-fuerza leídas como newtons, y aquí la cierra una
frontera de kinds en vez de una convención de nombres.

Los kinds aditivos también se pueden declarar
(`kind Puntos : Module with puntos`): sirven para cantidades que
se suman y escalan pero donde "puntos al cuadrado" sería un
sinsentido: puntos de un juego, millas de viajero, créditos
académicos. Las cuatro theories `builtin` restantes no aceptan
kinds de usuario: si escribes `kind Zona : Nominal`, el compilador
te dirá que una theory builtin no puede clasificar un kind tuyo.
Las regiones, los tipos, los efectos y las formas tienen
exactamente un kind cada uno, y es del lenguaje.

## 19.6 Region: memoria como habitante

El capítulo 13 te debe una. Cuando dijimos que Perceus inserta
increments y decrements en los puntos exactos donde los valores
mueren, quedó una pregunta abierta: ¿y si un cálculo construye un
millón de valores efímeros solo para plegarlos a un número? Cada
celda paga su alta y su baja en el contador, y todo ese
contabilismo es trabajo que un humano mirando el programa sabría
innecesario: *nada de esto sobrevive al cálculo*.

El bloque `region` es la forma de decírselo al compilador:

```kai
# Listado 19.3 — ejemplos/cap19/03_region_scratch.kai
fn suma(xs: [Int]) : Int = match xs {
  []        -> 0
  [h, ...t] -> h + suma(t)
}

fn main() : Unit / Stdout = {
  let total = region {
    let a = [1, 2, 3, 4, 5]        # construida en la arena
    let b = [10, 20, 30]           # construida en la arena
    suma(a) + suma(b)              # resultado escalar
  }                                # la arena se libera aquí, de un golpe
  println("#{total}")
}
```

```
$ kai run ejemplos/cap19/03_region_scratch.kai
75
```

Todo constructor escrito léxicamente dentro del bloque asigna en
una **arena**: un bloque de memoria que crece por bump (un
puntero que avanza, sin contador alguno) y se libera entero al
cerrar la llave. Las dos listas de arriba no pagan ni un
increment ni un decrement. El escalar que sale cruza la frontera
gratis.

¿Y si necesitas que la estructura cruce *funciones* antes de
plegarse? Ahí aparece el kind. La forma `region { r -> ... }`
liga un nombre para la región, y ese `r` es un habitante fresco
de `Region` que los tipos pueden cargar:

```kai
# Listado 19.4 — ejemplos/cap19/04_arbol_en_arena.kai
type Arbol = Hoja | Nodo(Arbol, Int, Arbol)

fn insertar[r: Region](t: Arbol<r>, k: Int) : Arbol<r> =
  match t {
    Hoja -> Nodo(Hoja, k, Hoja)
    Nodo(izq, v, der) ->
      if k < v { Nodo(insertar(izq, k), v, der) }
      else if k > v { Nodo(izq, v, insertar(der, k)) }
      else { Nodo(izq, v, der) }
  }

fn sumar[r: Region](t: Arbol<r>) : Int =
  match t {
    Hoja -> 0
    Nodo(izq, v, der) -> sumar(izq) + v + sumar(der)
  }

fn construir[r: Region](t: Arbol<r>, n: Int) : Arbol<r> =
  if n == 0 { t } else { construir(insertar(t, n), n - 1) }

fn main() : Unit / Stdout = {
  let total = region { r ->
    let arbol = construir(Hoja, 100)
    sumar(arbol)
  }                                # 100 nodos liberados de un golpe
  println("#{total}")
}
```

```
$ kai run ejemplos/cap19/04_arbol_en_arena.kai
5050
```

Mira las firmas con los ojos del §19.4: `insertar` es genérica
sobre la región exactamente como `area_de` es genérica sobre la
unidad. `Arbol<r>` marca en el tipo que estos nodos viven en la
arena `r`; el tipo `Arbol` se declara una sola vez, sin saber
nada de regiones, y cualquier función puede volverse
region-polimórfica anotando `[r: Region]`. Cien nodos, cero
operaciones de contador, una liberación.

La theory `Nominal` es la más simple del catálogo y aquí está
el porqué: cada bloque `region { r -> }` acuña un habitante
*fresco*, distinto de todos los demás. Dos regiones no unifican
jamás. Eso es lo que impide que un `Arbol<r1>` se cuele en una
arena `r2` que se libera en otro momento: el error es de tipos,
en compilación, con el mismo mecanismo que rechaza `m + ft`.

Dos letras chicas, las dos importantes:

- **Lo que escapa se copia.** El valor del bloque cruza la
  frontera: si es un escalar, gratis; si es una estructura, se
  copia en profundidad a la memoria normal con RC antes de
  liberar la arena. Una región cuyo resultado es la estructura
  entera es *más lenta* que no usar región. El nicho es scratch
  que se pliega a poco.
- **La arena es léxica en la forma sin nombre.** En
  `region { ... }` sin binder, solo los constructores escritos
  dentro del bloque asignan en la arena; un helper llamado desde
  el bloque asigna en la memoria normal. Para cruzar funciones,
  usa el binder y firmas `[r: Region]`, como en el listado 19.4.

`region` es opt-in: el compilador nunca lo infiere por ti. El
default del lenguaje sigue siendo el del capítulo 13: Perceus,
exacto y sin pausas. `region` es la palanca que tiras cuando el
perfil te muestra un cálculo que construye y descarta a paladas.

## 19.7 Dinero: el álgebra que falta a propósito

El capítulo 10 modeló monedas con `unit USD`, y funciona. Pero
deja abierta una puerta curiosa: en `Measure`, los habitantes
forman grupo bajo producto, así que `USD^2` y `USD*EUR` son
unidades perfectamente formables. Ningún programa contable sensato
las produce a propósito, pero un bug sí puede, y el sistema de
tipos las aceptaría con la solemnidad con que acepta `m/s^2`.

Para dinero, el stdlib usa el kind `Currency`, cuya theory
`Module` simplemente **no tiene** producto de habitantes. El tipo
es `Money[t]<c>`: un **carrier** `t` (el tipo que guarda el monto)
etiquetado con la moneda `c` en la ranura `<>`. Para dinero de
verdad el carrier es `Decimal`, aritmética exacta de punto fijo y
no punto flotante, que es lo único defendible. El tipo que vas a
escribir casi siempre es `Money[Decimal]<USD>`:

```kai
# Listado 19.5 — ejemplos/cap19/05_dinero.kai
import money
import decimal as dec
import decimal_proto

fn main() : Unit / Stdout = {
  let a: Money[dec.Decimal]<USD> = 10.50<USD>
  let b: Money[dec.Decimal]<USD> = 4.50<USD>
  let total = a + b                       # misma moneda: Money[Decimal]<USD>

  let k: dec.Decimal = 3
  let triple = total * k                  # escalar: sigue en USD

  let tasa: dec.Decimal = 0.92
  let en_euros: Money[dec.Decimal]<EUR> = money.convert(total, tasa)

  println("total  = #{money.to_string(total)} USD")
  println("triple = #{money.to_string(triple)} USD")
  println("euros  = #{money.to_string(en_euros)} EUR")
}
```

```
$ kai run ejemplos/cap19/05_dinero.kai
total  = 15.0 USD
triple = 45.0 USD
euros  = 13.800 EUR
```

Sumar la misma moneda, sí. Escalar por un número, sí: el escalado
vive en la firma de la operación (`Money[t]<c> * t` conserva la
moneda) y no en el álgebra del kind. Convertir, solo por la puerta
explícita de `money.convert`, con la moneda destino fijada por la
anotación. ¿Y multiplicar dos dineros?

```kai
# Listado 19.6 — ejemplos/cap19/06_usd_por_eur.kai (no compila)
let u: Money[dec.Decimal]<USD> = 10.00<USD>
let e: Money[dec.Decimal]<EUR> = 5.00<EUR>
let sinsentido = u * e          # error: `EUR USD` no existe
```

```
$ kai build ejemplos/cap19/06_usd_por_eur.kai
error: operator `*` cannot combine `Currency` quantities: the
result unit `EUR USD` does not exist
  = note: `Currency` habitants stand alone: a quantity is either
    scalar or carries exactly one habitant with exponent 1 —
    habitant products and powers are not expressible
```

Vale la pena leer ese error dos veces. No dice "operación
prohibida por una regla especial para dinero". Dice que el tipo
resultado **no se puede formar**: en el álgebra de `Currency` no
existe ningún habitante que sea "euros por dólares". Es la
diferencia entre un guardia en la puerta y un edificio sin esa
puerta. El mismo mecanismo que le da al físico su `kg·m/s^2` le
niega al contador su `USD*EUR`. Son dos theories del mismo
catálogo, y basta con eso.

Y esta es la respuesta a la pregunta que quedó flotando en el
capítulo 10: ¿cuándo `unit USD` y cuándo `Money[USD]`? Si estás
aprendiendo la mecánica de unidades o modelando magnitudes que sí
multiplican (precio por energía: `USD/kWh` por `kWh` da `USD`),
el kind `Measure` es tu herramienta. Si estás escribiendo el
sistema contable, `Currency` te quita de encima una familia de
tipos sin sentido y te regala `Decimal` de paso.

## 19.8 Layout: el orden de los bytes

Cuando serializas un entero a bytes, sea para un protocolo de
red, un formato de archivo o un registro binario, tienes que
decidir el orden: ¿el byte más significativo primero
(*big-endian*, el orden de red) o al revés (*little-endian*)?
Elegir mal no da un error de tipos en la mayoría de los
lenguajes: da un número corrupto que descubres tres capas más
abajo. El kind `Layout` sube esa decisión
al tipo.

Un campo de ancho fijo lleva dos cosas: su ancho, que viene del
tipo base (`U32` mide cuatro bytes, `U16` dos), y su orden, que es
el habitante. `U32<be>` y `U32<le>` son el mismo `U32` con
representaciones distintas, así que **nunca unifican**: pasar uno
donde se espera el otro no compila. Los dos habitantes, `be` y
`le`, los trae el stdlib (`layout be`, `layout le`) y son un set
cerrado; no hay un tercer orden que declarar.

La anotación `#[derive(Layout)]` sobre un record genera su
`to_bytes` y un shim `<tipo>_from_bytes` que reconstruye el valor
desde un buffer:

```kai
# Listado 19.7 — ejemplos/cap19/07_layout.kai
#[derive(Layout)]
type Paquete = { magia: U32<be>, puerto: U16<be> }

fn main() : Unit / Stdout = {
  let bytes = Paquete { magia: 0<be>, puerto: 0<be> }.to_bytes()
  match paquete_from_bytes(bytes, 0) {
    Ok(p)  -> println("puerto #{p.value.puerto}")
    Err(m) -> println(m)
  }
}
```

```
$ kai run ejemplos/cap19/07_layout.kai
puerto 0
```

Aquí entra la theory. `Composition` compone los campos **en el
orden en que los escribiste**, y por eso es asociativa pero no
conmutativa: mover un campo cambia el layout. También suma la
medida de cada uno, su byte size, para dar el tamaño del record. Ese `over
Int` que viste en el catálogo (`kind Layout : Composition over
Int`) nombra justamente esa medida: un tamaño es un entero y la
suma tiene que ser exacta. El resultado es un formato binario
posicional y byte-exacto, con el orden verificado en compilación
y, como todo kind, borrado del binario.

## 19.9 Perm: permisos que el tipo persigue

Los kinds que vimos hasta aquí clasifican *cantidades*: metros,
dólares, bytes. `Perm` clasifica otra cosa: **capacidades**. Su
theory, `Semilattice`, es la más rara del catálogo, y vale
entenderla porque abre una puerta que los demás kinds no.

El caso concreto vive en la API de archivos del stdlib. Un
`FileHandle` lleva en su tipo lo que el código puede hacer con
él. `open_read` devuelve
`FileHandle<read>`; `open_write` devuelve `FileHandle<read +
write>`. Y cada operación pide exactamente lo que usa:
`read_chunk` exige `<read>`, `write_chunk` exige `<write>`.

```kai
# Listado 19.9 — ejemplos/cap19/09_perm.kai
fn primera_linea(h: FileHandle<read>) : String / File =
  match File.read_chunk(h, 64) {
    Ok(s)  -> s
    Err(e) -> e
  }

fn main() : Unit / Stdout + File = {
  let ruta = "/tmp/kai_perm_demo.txt"
  match File.open_write(ruta) {
    Ok(h) -> {
      let _ = File.write_chunk(h, "hola, kaikai")
      File.close_file(h)
      match File.open_read(ruta) {
        Ok(r) -> {
          println(primera_linea(r))
          File.close_file(r)
        }
        Err(e) -> println(e)
      }
    }
    Err(e) -> println(e)
  }
}
```

```
$ kai run ejemplos/cap19/09_perm.kai
hola, kaikai
```

Fíjate en `primera_linea`: pide un `FileHandle<read>`, pero el
handle que abrió `open_write` es un `FileHandle<read + write>`, y
aun así el programa compila. Eso es lo distintivo de
`Semilattice`. En los demás kinds, dos habitantes unifican solo si
son *iguales*: `U32<be>` jamás pasa donde se espera `U32<le>`. En
`Perm`, unifican por **subsunción**: un handle con más capacidades
sirve donde se piden menos, nunca al revés. `read + write` incluye
`read`, así que fluye hacia `<read>`. La dirección importa: un
`FileHandle<read>` puro **no** compila donde se exige `<write>`.

```kai
fn escribe(h: FileHandle<read>) : Unit / File = {
  let _ = File.write_chunk(h, "x")   # no compila: <read> no
  ()                                 # subsume a <write>
}
```

```
error: type mismatch in op call File.write_chunk
  --> escribe.kai:2:27
    |
  2 |   let _ = File.write_chunk(h, "x")
    |                           ^
  = note: expected: (FileHandle<write>, String) -> Result[Unit, String]
  = note: found:    (FileHandle<read>, String) -> ?t0
```

El `+` de `Semilattice` es una unión idempotente: `read + read` es
`read`, el orden no importa (`read + write` = `write + read`), y
nada se resta. Son las tres leyes que la theory verifica,
asociativa, conmutativa e idempotente, y de ahí sale el orden
parcial que define la subsunción. Los habitantes `read` y `write`
los trae la API de archivos (`perm read`, `perm write`), y como
cualquier kind con palabra introductora, puedes acuñar los tuyos:
`perm admin`, `perm audit`, lo que tu dominio necesite.

Vale una precisión honesta: la capacidad es la que tu código
**declaró** al abrir, no el permiso que el sistema operativo tenga
en ese instante. Un archivo que desaparece, un `chmod` a
destiempo, siguen apareciendo por el `Result` de cada operación.
`Perm` te protege de un error de programa, escribir por un handle
que abriste para leer. De la realidad del disco no te protege.

## 19.10 Dim: la forma como índice

`Dim` es el kind más nuevo y el más distinto de todos. Sus
habitantes son **valores de `Int` escritos directamente en
`<>`**, sin palabra introductora que los acuñe. `<3>` es un
habitante porque `3 : Int`. Y su theory es `HindleyMilner`, la
misma que clasifica los tipos ordinarios: la unificación es la
igualdad de primer orden que ya conoces desde el capítulo 3.
`<3>` unifica con `<3>` y nunca con `<4>`.

¿Para qué? Para meter la **forma** de una estructura en su tipo.
El caso canónico es `Vec[t]<n>`: un vector cuyo largo, `n`, es
parte del tipo. Un literal con un largo distinto al que anuncia la
anotación no compila.

```kai
# Listado 19.10 — ejemplos/cap19/10_dim.kai
fn punto[n: Dim](v: Vec[Real]<n>) : Real = v[0]

fn dot[n: Dim](a: Vec[Real]<n>, b: Vec[Real]<n>, i: Int, acc: Real) : Real =
  if i < 0 { acc } else { dot(a, b, i - 1, acc + a[i] * b[i]) }

fn main() : Unit / Stdout = {
  let u : Vec[Real]<3> = [1.0, 2.0, 3.0]
  let w : Vec[Real]<3> = [4.0, 5.0, 6.0]
  println(real_to_string(punto(u)))
  println(real_to_string(dot(u, w, 2, 0.0)))
}
```

```
$ kai run ejemplos/cap19/10_dim.kai
1
32
```

`punto` es genérica sobre el largo: `[n: Dim]` dice "para cualquier
largo", igual que `[u: Measure]` decía "para cualquier unidad".
Pero `dot` va más lejos: sus dos argumentos son `Vec[Real]<n>` con
el **mismo** `n`. El tipo obliga a que los vectores midan lo mismo;
sumar un `<2>` con un `<3>` no es un error de runtime que descubres
con un índice fuera de rango, es un tipo que no se puede formar.

Y el índice equivocado se atrapa donde se escribe:

```kai
let a : Vec[Real]<3> = [1.0, 2.0]   # no compila
```

```
error: vector literal has 2 elements, but its type fixes the length to 3
  --> largos.kai:4:26
    |
  4 |   let a : Vec[Real]<3> = [1.0, 2.0]
    |                          ^
```

Como todo kind, `Dim` se borra en runtime: `<3>` no ocupa un byte
en el binario: es puro andamiaje de compilación. Y como `Int` es
un dominio infinito, `Dim` es también la demostración de algo que
el §19.3 adelantó: una theory puede clasificar más de un kind.
`HindleyMilner` es el motor de `Type` y de `Dim` a la vez:
igualdad de primer orden sobre dos dominios distintos, tipos en
uno, enteros en el otro.

Un límite del álgebra, deliberado: `Dim` es atómico. Un índice no
tiene productos ni potencias: `<3*4>` y `<3^2>` no existen. La
aritmética a nivel de tipo (concatenar dos vectores para obtener
uno de largo `n+k`) queda fuera de la theory a propósito; sumar
esa maquinaria cambiaría el motor de unificación, y `Dim` prefiere
mantenerse en la igualdad simple que hereda de `HindleyMilner`.

## 19.11 Shape: el contenedor como habitante

Los kinds con palabra introductora acuñan habitantes de a uno:
`unit m`, `currency USD`, `perm read`. `Shape` no tiene palabra, y
esa es su gracia: sus habitantes ya existen. Cada `type T[a]` de un
solo parámetro (`List`, `Vec`, `Option`, tu `Caja[a]`) es
automáticamente un habitante de `Shape`, su constructor pelado `T`,
igual que cada `type` es un habitante de `Type`. No declaras nada
nuevo; nombras lo que ya tienes.

Con eso puedes cuantificar sobre el contenedor además del
contenido. Un parámetro `[s: Shape]` acepta cualquier constructor
de un argumento, y `s[Int]` lo aplica a un tipo:

```kai
# Listado 19.8 — ejemplos/cap19/08_shape.kai
protocol Contenedor[s: Shape] {
  primero(xs: s[Int]) : Int
}

type Caja[a] = Caja(a)

impl Contenedor for Caja {
  fn primero(xs: Caja[Int]) : Int = match xs {
    Caja(v) -> v
  }
}

impl Contenedor for List {
  fn primero(xs: [Int]) : Int = match xs {
    []         -> 0
    [h, ..._t] -> h
  }
}

fn main() : Unit / Stdout = {
  println("caja:  #{primero(Caja(7))}")
  println("lista: #{primero([3, 4, 5])}")
}
```

```
$ kai run ejemplos/cap19/08_shape.kai
caja:  7
lista: 3
```

`primero` sirve sobre `Caja[Int]` y sobre `[Int]` con una sola
firma, `s[Int] -> Int`. La theory `ConstructorApp` es la que lo
permite: al unificar `s[Int]` con `Caja[Int]` liga `s` a `Caja`, y
con `[Int]` liga `s` a `List`; dos shapes unifican solo si son el
mismo constructor: `List` con `List`, jamás `List` con `Vec`. Un
shape es atómico, no se compone ni se aplica a medias, así que
`s[t[Int]]` ni siquiera llega a formarse como tipo. Es la
expresividad de un functor, abstraer sobre el contenedor, sin los
tipos de orden superior que la traen en Haskell: después de
monomorfizar, cada llamada es un despacho estático y directo.

## 19.12 Theory cerrada, modelos abiertos

Cierro con la pregunta de diseño, porque sé que el lector que
viene de Haskell la trae cargada: ¿por qué un catálogo cerrado?
¿Por qué no typeclasses, o higher-kinded types, o theories
definibles por el usuario, y que cada quien arme su álgebra?

Porque cada entrada del catálogo compra su decidibilidad por
separado. La unificación de `AbelianGroup` es aritmética de
exponentes; la de `Module`, un chequeo de habitante y exponente
1; la de `Nominal`, igualdad de símbolo. Cada una es un
algoritmo pequeño, rápido, sin casos patológicos. Una theory
arbitraria definida por el usuario sería un problema de
unificación arbitrario, y la historia de los sistemas de tipos
está llena de álgebras inocentes con unificación indecidible. El
precio se pagaría donde kaikai no está dispuesto a pagarlo: en el
tiempo de compilación y en la calidad de los errores, las dos
cosas que este libro lleva dieciocho capítulos defendiendo.

La apuesta de kaikai es **theory cerrada, modelos abiertos**: el
lenguaje trae las álgebras y garantiza que unifican rápido; tú
traes los habitantes (`unit parsec`, `currency CLP`) y los kinds
que esas álgebras admiten (`kind Puntos : Module`). Es la misma
silueta de los protocolos del capítulo 9, single-dispatch
cerrado sobre un mecanismo simple en vez de typeclasses abiertas
sobre uno complejo, aplicada un piso más arriba.

Lo que el catálogo te da hoy ya lo viste: dimensiones para el
físico, monedas para el contador, arenas para el que persigue
microsegundos, y un solo modelo mental para los tres. Y el
catálogo está diseñado para crecer: una entrada nueva es una
theory con unificación decidible más una palabra introductora,
y el resto del lenguaje (la cuantificación, la sintaxis `<...>`,
el borrado en runtime) la recibe gratis. Qué entradas se ganan
el lugar es una conversación de diseño. El
mecanismo, como acabas de ver, cabe en una pantalla.

## Ejercicios

**19.1.** Declara `kind Millas : Module with millas` y un
habitante `millas aereas`. Escribe una función que sume millas de
viajero y otra que las escale por un multiplicador de categoría.
Verifica que `Int<aereas> * Int<aereas>` no compila. ¿Qué dice el
error, y en qué se parece al del listado 19.6?

**19.2.** Toma la cartera multi-moneda del §10.7 y reescríbela
con `Money[c: Currency]` en vez de `Real<USD>`. ¿Qué cambia en
las firmas? ¿Qué error nuevo detecta el compilador que la versión
con `Measure` dejaba pasar?

**19.3.** En el listado 19.4, cambia `sumar(arbol)` por `arbol`
como valor del bloque `region`. Sigue compilando, pero mide con
`kai bench` la versión original contra la nueva construyendo
árboles de 10.000 nodos. Explica la diferencia con la letra chica
del §19.6.

**19.4.** El listado 19.3 usa `region { ... }` sin binder.
Extrae la construcción de las dos listas a una función auxiliar
`fn armar() : ([Int], [Int])` llamada desde dentro del bloque.
¿El programa sigue compilando? ¿Las listas siguen viviendo en la
arena? Justifica con la letra chica del §19.6.

**19.5.** El capítulo 12 mostró que las filas de efectos ignoran
el orden: `Stdout + Fail` unifica con `Fail + Stdout`. Escribe
esa regla como propiedades algebraicas al estilo del catálogo
(`{ assoc, commut, ... }`). ¿Qué propiedad *no* debe tener la
theory de filas para que `Fail + Fail` colapse a `Fail`? ¿Por qué
crees que `EffectRow` es `builtin` en vez de declararse por
propiedades?
