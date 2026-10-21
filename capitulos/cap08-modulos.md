# Capítulo 8 · Módulos, imports, organización del código

Hasta ahora todo tu código ha vivido en un archivo. Es la forma
correcta de partir, pero cuando el programa crece el archivo
único estorba: quien lo lee se pierde y los cambios chocan.
Toca partir el código en pedazos con nombre.

kaikai lo resuelve con un sistema simple, y esa simpleza la
elegí a propósito. **Un archivo es un módulo.** No hay
declaraciones `module Foo`, ni archivos especiales que reabran
un módulo desde otro lado; el nombre del módulo sale de la ruta
del archivo. Por encima viene el **proyecto**, descrito por un
`kai.toml`, que organiza sus módulos y dependencias externas. Y
por encima del proyecto, un **package manager** que resuelve
dependencias entre proyectos. Recorres las tres escalas de
menos a más.

## 8.1 Un archivo, un módulo

Crea un archivo `aritmetica.kai` con algunas funciones:

```kai
pub fn duplicar(x: Int) : Int = x * 2

fn helper(x: Int) : Int = x + 1

pub fn doble_mas_uno(x: Int) : Int = helper(duplicar(x))
```

Tres decisiones de diseño aparecen en estas tres líneas:

- **`pub` marca lo que el módulo exporta.** Una declaración es
  privada al archivo salvo que lleve `pub`; solo lo marcado es
  visible desde otro módulo que importe este. Es al revés de
  Kotlin o Scala, donde lo público es el default y hay que
  recordar marcar lo privado.
- **Los nombres del módulo no necesitan declararse.** El
  archivo `aritmetica.kai` es el módulo `aritmetica`. Si lo
  pones bajo un subdirectorio como `util/aritmetica.kai`,
  pasa a ser el módulo `util.aritmetica`. El nombre se deriva
  de la ruta relativa a la raíz del proyecto.
- **Cualquier `fn`, `type`, `effect` o `let` puede llevar
  `pub`.** No hay diferencia en visibilidad entre tipos y
  funciones: una construcción es visible afuera solo si está
  marcada `pub` (o `pub(pkg)`, que aparece en la sección 8.5).

Las funciones privadas te dejan descomponer una pública sin
contaminar el namespace de quien importa: `helper` solo existe
dentro de `aritmetica`.

El ejemplo que corre es ese mismo archivo con un `main` que
usa las dos funciones públicas:

```kai
# ejemplos/cap08/01_un_archivo/main.kai
pub fn duplicar(x: Int) : Int = x * 2

fn helper(x: Int) : Int = x + 1

pub fn doble_mas_uno(x: Int) : Int = helper(duplicar(x))

fn main() {
  println("doble_mas_uno(5) = #{doble_mas_uno(5)}")
}
```

```
$ kai run ejemplos/cap08/01_un_archivo/main.kai
doble_mas_uno(5) = 11
```

## 8.2 `import` y nombres calificados

Para usar `aritmetica` desde otro archivo:

```kai
import aritmetica

fn main() {
  println("doble_mas_uno(5) = #{aritmetica.doble_mas_uno(5)}")
}
```

`import aritmetica` deja accesibles las cosas `pub` de ese
módulo bajo el prefijo `aritmetica.`. La función
`doble_mas_uno` se llama como `aritmetica.doble_mas_uno`.

El prefijo es a propósito, y sé que a alguna gente le molesta.
Cuando un proyecto crece a quince o veinte módulos, ver
`aritmetica.doble_mas_uno` en una expresión te dice de
inmediato de dónde sale. Importar todos los nombres sueltos
ahorra teclas pero pierde esa pista.

El mismo prefijo se usa para los tipos que el módulo exporta y
para construirlos:

```kai
# ejemplos/cap08/02_dos_archivos/geometria.kai
pub type Punto = { x: Real, y: Real }

pub fn distancia(a: Punto, b: Punto) : Real {
  let dx = a.x - b.x
  let dy = a.y - b.y
  real_sqrt(dx * dx + dy * dy)
}

fn cuadrado(x: Real) : Real = x * x

# ejemplos/cap08/02_dos_archivos/main.kai
import geometria

fn main() {
  let a: geometria.Punto = geometria.Punto { x: 0.0, y: 0.0 }
  let b: geometria.Punto = geometria.Punto { x: 3.0, y: 4.0 }
  println("distancia = #{geometria.distancia(a, b)}")
}
```

```
$ kai run ejemplos/cap08/02_dos_archivos/main.kai
distancia = 5
```

El prefijo va en la anotación de tipo (`: geometria.Punto`),
en la construcción del record (`geometria.Punto { ... }`) y en
la llamada (`geometria.distancia(a, b)`). Un único patrón
mental.

Si el módulo está bajo un subdirectorio, el import usa el
mismo nombre punteado que el módulo:

```kai
# ejemplos/cap08/05_proyecto/util/matematica.kai
pub fn pow(base: Int, exp: Int) : Int {
  if exp == 0 {
    1
  } else {
    base * pow(base, exp - 1)
  }
}

# ejemplos/cap08/05_proyecto/main.kai
import util.matematica

fn main() {
  println("3^4 = #{matematica.pow(3, 4)}")
}
```

```
$ kai run ejemplos/cap08/05_proyecto/main.kai
3^4 = 81
```

El archivo está en `util/matematica.kai` y el módulo se llama
`util.matematica`, pero al usarlo el prefijo es solo
`matematica`, el último segmento. Así evitas prefijos largos
sin perder el origen estructural.

### Tres formas de importar

kaikai admite tres formas:

```kai
import math.vector                      # use qualified: vector.dot(a, b)
import math.vector as V                 # alias: V.dot(a, b)
import math.vector.{dot, cross}         # nombres específicos en alcance
```

La primera es la más común y la opción por omisión: el prefijo
`vector.` deja claro de dónde sale cada nombre. La segunda
sirve cuando el nombre del módulo es largo o aparece muchas
veces, y un alias corto gana legibilidad sin perder la pista.
La tercera es la **importación selectiva**: una lista explícita
de nombres que se traen al namespace local. Conviene solo
cuando esos nombres son los protagonistas del archivo y el
prefijo se vuelve ruido (un `Punto` que aparece cuarenta veces,
por ejemplo). A cambio, quien lee ya no sabe de dónde salió
`Punto` sin mirar arriba.

**No hay wildcard import**: no existe `import math.vector.*` ni
nada equivalente que traiga "todo lo que el módulo exporta" al
namespace local. Lo decidí así porque el wildcard es cómodo al
escribir, pero deja al lector futuro sin saber de dónde vino un
nombre.

Las tres formas como tres proyectos que corren. Cada uno trae
su propio `geometria.kai`; lo que cambia es la línea del
`import` y, con ella, cómo se escribe la llamada:

```kai
# ejemplos/cap08/03_qualified/main.kai
import geometria

fn main() {
  let d = geometria.distancia_origen(3.0, 4.0)
  println("distancia al origen = #{d}")
}

# ejemplos/cap08/04_alias/main.kai
import geometria as G

fn main() {
  let d = G.distancia_origen(3.0, 4.0)
  println("distancia al origen = #{d}")
}

# ejemplos/cap08/02b_selectivo/main.kai
import geometria.{Punto, distancia}

fn main() {
  let a: Punto = Punto { x: 0.0, y: 0.0 }
  let b: Punto = Punto { x: 3.0, y: 4.0 }
  println("distancia = #{distancia(a, b)}")
}
```

```
$ kai run ejemplos/cap08/03_qualified/main.kai
distancia al origen = 5
```

```
$ kai run ejemplos/cap08/04_alias/main.kai
distancia al origen = 5
```

```
$ kai run ejemplos/cap08/02b_selectivo/main.kai
distancia = 5
```

### Cuando dos módulos exportan el mismo nombre

Tarde o temprano dos dependencias tuyas le ponen la misma
palabra a cosas distintas. No es que una esté mal: cada dominio
nombra lo suyo con el término que le corresponde, y `Lectura`
es tan buen nombre para un sensor como para una alarma.

```kai
# ejemplos/cap08/07_colisiones/sensores.kai
pub type Lectura = { celsius: Real }
pub const MAX: Int = 100

# ejemplos/cap08/07_colisiones/alarmas.kai
pub type Lectura = { severidad: Int }
pub const MAX: Int = 5
```

Si importas los dos y escribes `MAX` a secas, el compilador no
elige por ti:

```
error: bare name 'MAX' is exported by multiple modules: sensores, alarmas
  --> main.kai:5:26
    |
  5 |   Stdout.print("tope = #{MAX}")
    |                          ^
  = note: constant candidates: sensores.MAX, alarmas.MAX
  = help: qualify the constant, e.g. `sensores.MAX`
```

Elegir por ti sería peor que el error. Con cualquier regla de
desempate, el orden de los imports digamos, *cuál* de los dos
`MAX` obtienes dependería de cómo quedaron ordenadas las
líneas, y el día que alguien las ordene alfabéticamente el
programa cambia de significado sin que nadie toque una
expresión.

Un tipo, un efecto o un protocolo en disputa dan el mismo
reporte que la constante, con los candidatos nombrados y la
palabra que corresponde: `type candidates`, `effect
candidates`.

La salida es el calificador, y funciona en todas partes donde
aparece un nombre: tipos, constructores (en expresión y en
patrón), funciones, constantes, protocolos en la cabeza de un
`impl` y dentro de `#[derive(...)]`, y efectos tanto en la fila
como en la cabeza de un `handle` y en sus operaciones.

```kai
# ejemplos/cap08/07_colisiones/main.kai
import sensores
import alarmas

fn main() : Unit / Stdout {
  let t: sensores.Lectura = sensores.Lectura { celsius: 21.5 }
  let a: alarmas.Lectura = alarmas.Lectura { severidad: 3 }

  Stdout.print("#{t.celsius} grados (tope #{sensores.MAX})")
  Stdout.print("severidad #{a.severidad} (tope #{alarmas.MAX})")
}
```

```
$ kai run ejemplos/cap08/07_colisiones/main.kai
21.5 grados (tope 100)
severidad 3 (tope 5)
```

El calificador es solo un desempate: `sensores.MAX` y `MAX`
nombran la misma constante cuando no hay colisión, así que no
tienes que calificar por si acaso. Y cada módulo se queda con
su propia declaración: dos dependencias pueden declarar cada
una su `effect Emit` sin pisarse, y `with ea.Emit` alcanza solo
al de `ea`.

Hay un caso que no llega a disputa: el homónimo de algo que ya
venía puesto. Si importas un módulo que declara su propio
`effect Log`, en ese archivo `Log` a secas es el del módulo: lo
que importaste le gana a lo que venía puesto, y el del stdlib
queda a un calificador de distancia, como `effects.Log`.

La regla vale igual para las funciones, y ahí es más fácil
tropezar, porque los nombres del core son los más obvios del
oficio: `map`, `filter`, `each`, `reduce`. Un archivo que
importa `gen` (los generadores del §12.13, que traen sus propias
etapas con esos nombres) cambia a quién llama `map` a secas:

```kai
import gen

let xs = [1, 2, 3]
map(xs, doble)       # ERROR: este `map` es el de gen, no el de list
```

```
error: type mismatch in function call
  = note: expected: (Gen[?t2, _], (?t2) -> ?t3) -> Gen[?t3, _]
  = note: found:    ([Int], (Int) -> Int) -> ?t4
```

No hay que adivinar: el error te muestra la firma que
encontró. Las salidas son las de siempre, calificar o usar el
pipe:

```kai
list.map(xs, doble)  # [2, 4, 6]
xs | doble           # [2, 4, 6]
```

Es la consecuencia de que el import gane, y vale la pena: la
alternativa es que un nombre del core sea intocable y que el
autor de un módulo no pueda llamar `map` a su `map`.

La otra salida es el import selectivo, que desempata para todo
el archivo en vez de hacerlo en cada uso:

```kai
import sensores.{MAX}    # `MAX` a secas es la de sensores
import alarmas

# MAX        -> 100
# sensores.MAX -> 100
# alarmas.MAX  ->   5
```

Nombrar `MAX` en el import selectivo lo saca de la disputa: el
nombre pelado pasa a ser el de `sensores`, y el otro sigue
disponible calificado. Nada se esconde.

Elige según qué tan parejo sea el reparto. Si el archivo es
noventa por ciento sensores y toca alarmas dos veces, el import
selectivo saca ruido. Si los usa por igual, calificar los dos en
el punto de uso deja el texto más honesto: el lector ve de dónde
sale cada nombre sin subir a mirar los imports.

### Un import que no usas

Un `import` que el archivo nunca menciona, ni como calificador
ni a través de ningún nombre que el módulo exporte, es una
advertencia:

```
warning: unused import `actor`
```

Hoy es advertencia y en la edición Orongo pasa a ser error,
como en Go. La migración es mecánica: borrar la línea.

Una excepción, para que no la confundas con un falso negativo:
un módulo que solo trae `impl` al scope se usa **por estar
cargado**, no por nombrarse, y ese import no se reporta aunque
no aparezca en ninguna línea.

Antes de borrar, eso sí, mira dos veces: puede que el import
sobre, o que el nombre que ibas a usar lo estés sacando de otra
parte sin darte cuenta. En los dos casos te conviene saberlo.

## 8.3 Visibilidad: el contrato del módulo

`pub` es el contrato que tu módulo le hace al mundo. Todo lo
no marcado es privado, y al marcar algo `pub` estás diciendo
"voy a sostener este nombre, esta firma, este tipo".

Una regla que el lenguaje no impone pero que conviene aplicar:
**lo público debe ser estrecho.** Si exportas una función
auxiliar útil hoy pero específica de tu implementación, el día
que refactorices tendrás que elegir entre romper a quien la usa
o cargar con código que ya no quieres. Lo público se mide en lo
que prometes; lo privado, en lo que puedes cambiar sin avisar.

En la práctica:

- **Tipos exportados:** sí, suelen ser parte del contrato.
- **Funciones helper:** rara vez. Si las necesitas exportar,
  pregúntate si está en el lugar correcto.
- **Constantes:** sí, si forman parte del API. Si son
  detalles de implementación, no. `pub` va delante igual que
  en todo lo demás, y quien importa la usa calificada:

  ```kai
  # limites.kai
  pub const PUERTO_MAX: Int = 65535

  # main.kai
  import limites
  println("max = #{limites.PUERTO_MAX}")
  ```

Entre `pub` y privado hay un grado intermedio: `pub(pkg)`.
Una declaración marcada así la ven todos los módulos de su
propio paquete, y no existe para quien lo use como
dependencia. Es lo que quieres para el helper que dos de tus
módulos comparten y que no es parte del contrato:

```kai
# util/interno.kai
pub(pkg) fn secreto() : Int = 42
pub fn publico() : Int = 1
```

Desde otro módulo del mismo paquete los dos nombres están ahí.
Desde un paquete que te declara como dependencia solo está
`publico`, y pedir el otro es un error que nombra lo que sí
hay:

```
error: module 'interno' does not export 'secreto'; available exports: publico
```

La mayoría de los lenguajes con visibilidad pública por
defecto acaban con módulos cuyo "API real" se mezcla con
todo el resto. kaikai invierte eso: lo público es lo que
nombraste explícitamente.

### Campos privados dentro de un tipo público

Cuando declaras `pub type T = { ... }`, los campos del record
son **públicos por defecto**: si el tipo está en el contrato,
sus campos también, y casi siempre es lo que quieres. Pero a
veces algún campo es detalle de implementación. La palabra
`priv` antes del nombre del campo lo oculta a otros módulos:

```kai
pub type Cuenta = {
  nombre:     String,
  priv saldo: Real,
}
```

Desde fuera del módulo que declara `Cuenta`, `c.saldo` no
compila y un literal `Cuenta { nombre: "x", saldo: 100.0 }`
tampoco. Solo el módulo declarante puede leer el campo y
mencionarlo al construir. El detalle del patrón lo conociste
en §4.1.1; aquí importa que `priv` opera a **granularidad de
campo** y complementa a `pub`, que opera por declaración.
Juntos cubren un caso muy común: "el tipo se exporta, su
interior no".

Un proyecto de dos archivos lo muestra desde el otro lado del
límite del módulo. El cliente construye y lee la cuenta solo
por las funciones del módulo; las dos líneas comentadas son los
rechazos:

```kai
# ejemplos/cap08/06_priv/caja.kai
pub type Cuenta = {
  nombre: String,
  priv saldo: Real
}

pub fn abrir(nombre: String) : Cuenta =
  Cuenta { nombre: nombre, saldo: 0.0 }

pub fn depositar(c: Cuenta, monto: Real) : Cuenta =
  Cuenta { ...c, saldo: c.saldo + monto }

pub fn saldo_de(c: Cuenta) : Real = c.saldo

# ejemplos/cap08/06_priv/main.kai
import caja

fn main() {
  let c0 = caja.abrir("ahorros")
  let c1 = caja.depositar(c0, 100.0)
  let c2 = caja.depositar(c1, 50.0)
  println("#{c2.nombre}: #{caja.saldo_de(c2)}")

  # println("#{c2.saldo}")
  # let _ = caja.Cuenta { nombre: "x", saldo: 999.0 }
}
```

```
$ kai run ejemplos/cap08/06_priv/main.kai
ahorros: 150
```

## 8.4 El stdlib que ya tienes

Hay un módulo especial que **no necesitas importar**: el
**core**. Funciones como `println`, `assert`, `string_concat`,
`real_sqrt` viven en el namespace global, disponibles sin
trámite en todo archivo .kai. En otros lenguajes esto se llama
*prelude* (Haskell) o *built-ins* (Python); kaikai lo llama
core, y vive bajo `stdlib/core/` en el árbol del compilador.

Lo que vive en core es deliberadamente pequeño: los tipos
primitivos, las operaciones aritméticas, los `Option` y `Result`,
los módulos `list` y `string` (por eso escribes `list.map(xs, f)`
sin importar nada), y builtins como `println`, `length` y
`reduce`. El resto del stdlib (encoding, redes, archivos,
criptografía) vive en módulos separados que se importan como
cualquier otro:

```kai
import stream                # pipelines lazy sobre streams
import fs.path               # manipulación de rutas
import encoding.json         # parseo de JSON
```

El criterio para core es severo: solo entra ahí lo que casi todo
programa usa.

## 8.5 Proyectos: `kai.toml`

Hasta aquí trabajaste con **módulos** dentro de un mismo árbol
de archivos. Cuando esos módulos forman una unidad que quieres
versionar o distribuir, o que depende de otras, pasas a la
segunda escala: el **proyecto**.

Un proyecto kaikai se describe con un archivo `kai.toml` en su
raíz. La forma mínima es esta:

```toml
name = "miapp"
version = "0.1.0"

[dependencies]
```

`name` es el nombre del proyecto. Tiene que ajustarse a una
gramática simple: minúsculas, dígitos, guion bajo y guion, sin
empezar con dígito. Es la misma forma que usan Cargo, Go y
Hex.pm, y evita problemas de path traversal, colisiones con
flags y otros sustos.

`version` es la versión del proyecto. Antes de 1.0,
`0.MINOR.PATCH` con cambios incompatibles subiendo MINOR
(convención cz). Después de 1.0, semver estándar.

`[dependencies]` es la tabla donde declaras qué otros proyectos
necesita el tuyo. Queda vacía si solo dependes del stdlib.

### El paquete como frontera

El `kai.toml` también marca una frontera de visibilidad. El
árbol de archivos bajo él es un **paquete**, y entre lo privado
y `pub` cabe un tercer nivel: `pub(pkg)` exporta una
declaración a los módulos del mismo paquete, sus tests
incluidos, y a nadie más.

```kai
# fragmento: util.kai dentro de un proyecto
pub(pkg) fn auxiliar(n: Int) : Int = n * 2   # todo módulo bajo este kai.toml

pub fn api(n: Int) : Int = auxiliar(n)        # lo que ven otros paquetes
```

Un módulo de otro paquete que lea `auxiliar` recibe un error
que nombra la declaración, y `kai doc` la deja fuera. Ahí va lo
que tus módulos comparten entre sí sin comprometerlo como API.

Dentro de un paquete, los módulos también pueden importarse en
ciclo: `par.kai` importa `impar` e `impar.kai` importa `par`.
Como toda firma de primer nivel es explícita, el compilador
recoge las de todo el ciclo antes de leer un cuerpo. Un ciclo
que cruza paquetes, que pasa por el stdlib o que une archivos
sin `kai.toml` es un error.

### `edition`

Hay un campo opcional más que conviene fijar en cuanto un
proyecto deja de ser un experimento:

```toml
name = "miapp"
version = "0.1.0"
edition = "hanga-roa"

[dependencies]
```

`edition` amarra el código fuente a una versión del **contrato
del lenguaje**: sintaxis, semántica del sistema de tipos,
firma del stdlib, API del binario `kai`. Mientras una edición
esté activa, kaikai garantiza que tu proyecto seguirá
compilando al subir el compilador. Cuando una edición se
cierra y entra una nueva, kaikai sigue aceptando la anterior:
solo tienes que decir cuál usas.

Si omites el campo, el compilador asume la edición
predeterminada de la instalación. Para un borrador basta; en
un proyecto que va a vivir, fijar la edición evita que una
actualización silenciosa te cambie el suelo. El resto lo
encuentras en el cap. 16: cómo se eligen las ediciones, cómo
migrar entre ellas y qué pasa con las APIs marcadas como
`#[unstable]`.

### Crear un proyecto nuevo

```sh
$ mkdir miapp && cd miapp
$ kai init miapp
kai-pkg: wrote kai.toml for package 'miapp'
```

`kai init` escribe el `kai.toml` esqueleto. Después agregas
archivos `.kai` y los importas como en §8.2.

## 8.6 Dependencias: git, path, lock

Una dependencia se declara de tres formas:

```toml
[dependencies]
manutara = { source = "github.com/kaikailang-org/manutara", ref = "v0.1.0" }
kohau = "github.com/kaikailang-org/kohau@v0.2.0"
local = { path = "../mi-otra-lib" }
```

La primera (tabla con `source` y `ref`) es la forma canónica
para dependencias de git. `source` es la URL del repo. `ref`
es lo que git entiende como referencia: una tag (`v0.1.0`),
una branch (`main`), o un commit (`abc1234`). Las tags son la
convención; branches y commits son escapes para casos puntuales.

La segunda (string `"<source>@<ref>"`) es lo mismo abreviado,
con `@` separando source de ref.

La tercera (`{ path = "..." }`) es la **dependencia local**.
Apunta a otro proyecto en tu disco, normalmente porque lo estás
desarrollando en paralelo. Editas la dependencia, vuelves a
correr tu app y los cambios se ven al instante, sin republicar.

### Agregar una dependencia

```sh
$ kai add github.com/kaikailang-org/manutara@v0.1.0
```

`kai add` hace dos cosas atómicamente: clona la dependencia y
escribe la entrada en `kai.toml`. Si el clone falla (URL mala,
ref que no existe, error de red), ni el manifest ni el lockfile
cambian: el árbol de trabajo nunca queda inconsistente.

### El lockfile

Cuando resuelves dependencias por primera vez, `kai` clona los
repos, captura el commit exacto (la SHA), y escribe un archivo
`kai.lock`:

```toml
# kai.lock — generated by kai-pkg. Do not edit by hand.

[[package]]
name = "manutara"
source = "github.com/kaikailang-org/manutara"
ref = "v0.1.0"
sha = "abc123def456..."
```

Si dos programadores corren `kai fetch` con el mismo
`kai.toml` y el mismo `kai.lock`, **bajan exactamente la misma
SHA**, el mismo árbol de archivos, y terminan con el mismo
binario. Esa reproducibilidad es la promesa central del
lockfile.

Por eso `kai.lock` se commitea junto al código: es parte del
contrato del proyecto. `kai.toml` declara qué quieres; `kai.lock`
declara qué obtuviste.

### Cuándo se actualiza el lock

- `kai fetch` lo crea si no existe; si existe, lo respeta.
- `kai update` lo regenera con la última versión de cada
  dependencia que cumpla la ref declarada.
- `kai add` lo refresca cuando agregas una dependencia nueva.
- `kai run` y `kai build` lo refrescan automáticamente si
  detectan deps en `kai.toml` que no están en el lock (la
  primera vez después de un `git clone`, por ejemplo).

## 8.7 Selección de versiones: MVS

Un proyecto puede depender transitivamente de otro por dos
rutas, con versiones distintas declaradas en cada una. kaikai
decide cuál gana con **minimum-version selection (MVS)**, el
algoritmo que usa Go modules. La regla es brutal pero clara:
de las versiones declaradas en toda la cadena transitiva, gana
la **máxima**.

Si tu app declara `manutara@v0.1.0` y una dependencia tuya
declara `manutara@v0.2.0`, todo el proyecto usa `v0.2.0`. MVS
supone que las versiones son *backwards-compatible* dentro de
un major: si todo el mundo respeta semver, subir al mayor
número no debería romper a nadie.

MVS contrasta con el algoritmo de Cargo o npm, que resuelve
restricciones complejas y a veces baja a una versión menor
para satisfacer a alguien. MVS es **predecible**: dado el
mismo árbol, el resultado es el mismo, sin resolvedor fallido
ni diamond-dependency hell.

A cambio, la responsabilidad de mantener compatibilidad queda
en los autores de bibliotecas. Si subes a una versión que
rompe, todo el mundo que dependa transitivamente de ti se
rompe. Eso te obliga a tomar el versionado en serio.

## 8.8 Cache y `kai fetch`

Cuando bajas una dependencia, no se queda en tu proyecto: se
queda en un **cache compartido entre proyectos**, por defecto
en `~/Library/Caches/kai/pkg` (macOS) o
`~/.cache/kai/pkg` (Linux).

La estructura del cache es:

```
~/Library/Caches/kai/pkg/
  github.com/kaikailang-org/manutara/
    abc123def456.../              # contenido fijado a esa SHA
    789abc012def.../              # otra SHA del mismo repo
```

Cada entrada se identifica por su SHA, no por la ref que tú
ves. Así, tres proyectos que piden `manutara@v0.1.0` comparten
el mismo árbol en disco, y si `v0.1.0` cambia upstream (mover
una tag no debería pasar, pero pasa), el cache fijado al SHA
original sigue intacto.

Puedes correr `kai fetch` a mano, pero **`kai run` y
`kai build` lo invocan automáticamente** cuando detectan deps
no resueltas. Después de clonar un proyecto, basta con
`kai run main.kai`: el driver baja lo que falta y corre.

El cache no crece sin límite. Una entrada que ningún build usa
en cinco días se borra sola, y si la vuelves a necesitar, el
siguiente `kai run` la baja de nuevo. `KAI_CACHE_TRIM=0` apaga
ese recorte y `KAI_CACHE_TRIM_DAYS` cambia el plazo. Para liberar
espacio de inmediato, `kai clean --cache` borra los caches
compartidos, y `kai clean` a secas, el `.kai-cache` del proyecto.

## 8.9 Caso de estudio: refactor de un proyecto monolítico

Imagina un proyecto que partió como un solo archivo `main.kai`
de 800 líneas. Adentro hay tres responsabilidades mezcladas:
parseo de un formato de configuración, lógica de negocio, e IO
con archivos. La velocidad de cambio cayó: cualquier
modificación obliga a leer demasiado.

El refactor procede en cuatro pasos.

### Paso 1: separar en módulos del mismo proyecto

Identificas las tres responsabilidades y las separas en
archivos:

```
miapp/
├── kai.toml
├── main.kai            # solo el flujo principal
├── config.kai          # parseo del formato
└── negocio.kai         # lógica de dominio
```

En `main.kai`:

```kai
import config
import negocio

fn main() {
  let cfg = config.cargar("./config.toml")
  let resultado = negocio.procesar(cfg)
  println("resultado: #{resultado}")
}
```

`config.kai` y `negocio.kai` exportan solo las funciones que
`main` necesita. Todo lo demás (helpers, tipos internos) queda
privado.

### Paso 2: revisar `pub`

Repasa cada `pub` y pregúntate si de verdad es parte del
contrato del módulo o un helper que quedó exportado por
inercia. Cada `pub` extra es un compromiso futuro.

### Paso 3: extraer una dependencia local

`config.kai` resulta útil más allá de este proyecto. La
extraes a su propio repositorio:

```
config-lib/
├── kai.toml            # name = "config_lib"
└── config.kai

miapp/
├── kai.toml            # ahora depende de config_lib
├── main.kai
└── negocio.kai
```

En `miapp/kai.toml`:

```toml
name = "miapp"
version = "0.1.0"

[dependencies]
config_lib = { path = "../config-lib" }
```

Mientras desarrollas, `config_lib` queda como dependencia
local. `main.kai` cambia su import a `import config_lib.config`
(o un alias, si el nombre largo molesta).

### Paso 4: publicar

Cuando `config_lib` está estable, le pones una tag:

```sh
$ cd ../config-lib
$ git tag v0.1.0
$ git push origin v0.1.0
```

Y en `miapp` cambias el path a git:

```toml
[dependencies]
config_lib = { source = "github.com/tuusuario/config-lib", ref = "v0.1.0" }
```

`kai fetch` baja la versión fijada por el lockfile. El
código de `main.kai` y `negocio.kai` no cambia: los imports
siguen siendo los mismos.

Esa es la trayectoria completa: de archivo único a módulos, de
módulos a proyectos, de proyecto local a dependencia
distribuida. Cada paso es reversible, y ninguno te obliga al
siguiente.

## 8.10 Filosofía: simple y previsible

Hay lenguajes con sistemas de módulos más expresivos:
re-exports automáticos, alias dinámicos, módulos parametrizados
por valores. kaikai elige una variante austera y se queda ahí.

La razón es la misma que en el resto del lenguaje: lo que
ahorra dolores de cabeza vale más que lo que agrega potencia.
Un sistema de módulos donde nada se importa sin que aparezca
en una lista visible, donde el nombre de un módulo se deriva
de su ruta, y donde las dependencias se fijan a un SHA exacto
se entiende leyéndolo, sin tener que ejecutarlo mentalmente.

Es el mismo principio que en pattern matching exhaustivo: si
el compilador te puede llevar al lugar exacto donde tienes que
hacer algo, no necesitas otra herramienta más sofisticada.

## Ejercicios

**8.1.** Toma un programa que hayas escrito en los capítulos
anteriores y pártelo en dos archivos. Identifica qué declaraciones
necesitan ser `pub` y cuáles pueden quedarse privadas. ¿Sentiste
la tentación de marcar algo `pub` "por si acaso"?

**8.2.** Crea un proyecto con `kai init`. Agrégale un archivo
auxiliar bajo un subdirectorio (por ejemplo, `util/strings.kai`).
Importa una función desde `main.kai`. ¿Cómo se llama el módulo
desde el punto de vista del import?

**8.3.** Escribe dos proyectos hermanos en disco: una biblioteca
`mi_lib` con una función pública, y una app `mi_app` que la usa
con `{ path = "../mi_lib" }`. Edita `mi_lib`, vuelve a correr
`mi_app`. ¿Cuánto demora el ciclo edit-run?

**8.4.** Mira un proyecto en `github.com/kaikailang-org/kaikai` (el
compilador mismo) y abre su `kai.toml` si lo tiene. ¿Qué
dependencias declara? ¿Reconoces el patrón de versionado?

**8.5.** Si `mi_app` declara `manutara@v0.1.0` y una
dependencia transitiva declara `manutara@v0.2.0`, ¿qué versión
usa el proyecto? ¿Por qué ese diseño descarta el "diamond
dependency hell"? Da un escenario donde la regla de MVS te
puede sorprender.

**8.6.** Una biblioteca tuya tenía una función `pub fn
parse_legacy(s: String)` que ya nadie usa. ¿Bajo qué
condiciones podrías removerla sin liberar una versión `1.0`?
¿Qué tipo de comunicación con tus usuarios necesitas antes?
