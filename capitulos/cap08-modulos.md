# Capítulo 8 · Módulos, imports, organización del código

Hasta ahora todo tu código ha vivido en un archivo. Es la forma
correcta de partir, pero apenas el programa crece, un archivo
único se vuelve un problema: los lectores se pierden, los
cambios chocan, las búsquedas confunden módulos lógicos que
están físicamente revueltos. Hay que partir el código en
pedazos con nombres.

kaikai resuelve esto con un sistema deliberadamente simple. **Un
archivo es un módulo.** No hay declaraciones `module Foo`. No
hay archivos especiales que reabran un módulo desde otro lado.
El nombre del módulo se deriva de la ruta del archivo y eso es
todo. Por encima de los módulos viene una segunda escala: un
**proyecto**, descrito por un `kai.toml`, que organiza sus
módulos y sus dependencias externas. Y por encima del proyecto,
un **package manager** que resuelve dependencias entre proyectos.

Este capítulo recorre las tres escalas, de menos a más.

## 8.1 Un archivo, un módulo

Crea un archivo `aritmetica.kai` con algunas funciones:

```kai
pub fn duplicar(x: Int) : Int = x * 2

fn helper(x: Int) : Int = x + 1

pub fn doble_mas_uno(x: Int) : Int = helper(duplicar(x))
```

Tres decisiones de diseño aparecen en estas tres líneas:

- **`pub` marca lo que el módulo exporta.** Por defecto, una
  declaración es privada al archivo. Solo las cosas marcadas
  con `pub` son visibles desde otro módulo que importe este.
  Es exactamente al revés de Java o C++, donde lo público es
  el default y hay que recordar marcar lo privado.
- **Los nombres del módulo no necesitan declararse.** El
  archivo `aritmetica.kai` es el módulo `aritmetica`. Si lo
  pones bajo un subdirectorio como `util/aritmetica.kai`,
  pasa a ser el módulo `util.aritmetica`. El nombre se deriva
  de la ruta relativa a la raíz del proyecto.
- **Cualquier `fn`, `type`, `effect` o `let` puede llevar
  `pub`.** No hay diferencia en visibilidad entre tipos y
  funciones: una construcción es visible afuera si y solo si
  está marcada `pub`.

Las funciones privadas son útiles para descomponer una pública
sin contaminar el namespace del consumidor. En `aritmetica`,
`helper` solo existe dentro del archivo; quien importa el
módulo no la ve.

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

El prefijo es deliberado. Cuando un proyecto crece a quince o
veinte módulos, ver `aritmetica.doble_mas_uno` en una
expresión te dice de inmediato de dónde sale. La alternativa,
importar todos los nombres sueltos al namespace del
consumidor, ahorra teclas pero pierde esa pista.

El mismo prefijo se usa para los tipos que el módulo exporta y
para construirlos:

```kai
import geometria

fn main() {
  let a : geometria.Punto = geometria.Punto { x: 0.0, y: 0.0 }
  let b : geometria.Punto = geometria.Punto { x: 3.0, y: 4.0 }
  println("distancia = #{geometria.distancia(a, b)}")
}
```

Tres usos del prefijo, los tres coherentes: en la anotación
de tipo (`: geometria.Punto`), en la construcción del record
(`geometria.Punto { ... }`), y en la llamada a la función
(`geometria.distancia(a, b)`). Un único patrón mental.

Si el módulo está bajo un subdirectorio, el import usa el
mismo nombre punteado que el módulo:

```kai
import util.matematica

fn main() {
  println("3^4 = #{matematica.pow(3, 4)}")
}
```

Fíjate en dos detalles: el archivo está en `util/matematica.kai`,
el módulo se llama `util.matematica`, pero al usarlo, el
prefijo es solo `matematica` (el último segmento). Eso evita
prefijos largos sin perder el origen estructural.

### Tres formas de importar

kaikai admite tres formas que cubren el espacio:

```kai
import math.vector                      # use qualified: vector.dot(a, b)
import math.vector as V                 # alias: V.dot(a, b)
import math.vector.{dot, cross}         # nombres específicos en alcance
```

La primera es la más común y la que debería ser tu opción por defecto: el
prefijo `vector.` deja claro de dónde sale cada nombre. La
segunda es útil cuando el nombre del módulo es largo o aparece
muchas veces y un alias corto te gana legibilidad sin perder
la pista. La tercera es la **importación selectiva**: una lista
explícita de nombres que se traen al namespace local. Te conviene
solo cuando los nombres son los protagonistas del archivo y el
prefijo se vuelve ruido (un `Punto` que aparece cuarenta veces,
por ejemplo). El precio es que el lector ya no sabe de dónde
salió `Punto` sin mirar arriba.

**No hay wildcard import.** Es decir, no existe
`import math.vector.*` o equivalente que traiga "todo lo que el
módulo exporta" al namespace local. Es una decisión
deliberada: el wildcard parece cómodo al escribir pero hace que
el lector futuro no sepa de dónde vino un nombre.

## 8.3 Visibilidad: el contrato del módulo

`pub` es el contrato que tu módulo le hace al mundo. Todo lo
no marcado es privado, y al marcar algo `pub` estás diciendo
"voy a sostener este nombre, esta firma, este tipo".

Una regla que el lenguaje no impone pero que conviene aplicar:
**lo público debe ser estrecho.** Cada nombre `pub` es un
contrato que vas a tener que mantener. Si exportas una
función auxiliar útil hoy pero específica de tu
implementación, mañana cuando refactorices vas a tener que
elegir entre romper a quien la usa o cargar con código que
ya no quieres. Lo público se mide en lo que prometes; lo
privado, en lo que puedes cambiar sin avisar.

En la práctica, esto se traduce a:

- **Tipos exportados:** sí, suelen ser parte del contrato.
- **Funciones helper:** rara vez. Si las necesitas exportar,
  pregúntate si está en el lugar correcto.
- **Constantes:** sí, si forman parte del API. Si son
  detalles de implementación, no.

La mayoría de los lenguajes con visibilidad pública por
defecto acaban con módulos cuyo "API real" se mezcla con
todo el resto. kaikai invierte eso: lo público es lo que
nombraste explícitamente.

## 8.4 El stdlib que ya tienes

Hay un módulo especial que **no necesitas importar**: el
stdlib core. Funciones como `println`, `assert`, `string_concat`,
`real_sqrt` viven en el namespace global y están disponibles en
todo archivo .kai sin trámite. Es lo que en otros lenguajes se
conoce como **prelude**.

Lo que vive en core es deliberadamente pequeño: los tipos
primitivos, las operaciones aritméticas, los `Option` y `Result`,
algunas funciones de lista, IO básica con `println`. El resto del
stdlib (encoding, redes, archivos, criptografía) vive en módulos
separados que se importan como cualquier otro:

```kai
import list                  # operaciones de lista no-prelude
import string                # operaciones de string
import encoding.json         # parseo de JSON
```

El criterio para core es severo: solo entra ahí lo que casi todo
programa usa.

## 8.5 Proyectos: `kai.toml`

Hasta acá hablamos de **módulos** dentro de un mismo árbol de
archivos. Cuando esos módulos se convierten en una unidad que
quieres versionar, distribuir, o que depende de otras unidades
similares, pasas a una segunda escala: el **proyecto**.

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
necesita el tuyo. Vacío si tu proyecto no depende de nadie más
fuera del stdlib.

### Crear un proyecto nuevo

```sh
$ mkdir miapp && cd miapp
$ kai init miapp
kai-pkg: wrote kai.toml for package 'miapp'
```

`kai init` escribe el `kai.toml` esqueleto. Después agregas
archivos `.kai` y los importas como vimos en §8.2.

## 8.6 Dependencias: git, path, lock

Cuando declaras una dependencia, tienes tres formas:

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

La segunda (string `"<source>@<ref>"`) es la misma cosa pero
abreviada. El `@` separa source de ref.

La tercera (`{ path = "..." }`) es la **dependencia local**.
Apunta a otro proyecto en tu disco, normalmente porque lo estás
desarrollando en paralelo. Edita el código de la dependencia,
vuelve a correr tu app, los cambios se ven al instante sin
republicar.

### Agregar una dependencia

```sh
$ kai add github.com/kaikailang-org/manutara@v0.1.0
```

`kai add` hace dos cosas atómicamente: clona la dependencia y
escribe la entrada en `kai.toml`. Si el clone falla (URL mala,
ref que no existe, error de red), ni el manifest ni el lockfile
cambian. Esto es importante: el árbol de trabajo nunca queda
en un estado inconsistente.

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

El lockfile cierra el contrato. Si dos programadores corren
`kai install` con el mismo `kai.toml` y el mismo `kai.lock`,
**bajan exactamente la misma SHA**, exactamente el mismo árbol
de archivos, exactamente el mismo binario al final. La
reproducibilidad es la promesa central del lockfile.

Por eso `kai.lock` se commitea junto al código: es parte del
contrato del proyecto. `kai.toml` declara qué quieres; `kai.lock`
declara qué obtuviste.

### Cuándo se actualiza el lock

- `kai install` lo crea si no existe; si existe, lo respeta.
- `kai update` lo regenera con la última versión de cada
  dependencia que cumpla la ref declarada.
- `kai add` lo refresca cuando agregas una dependencia nueva.
- `kai run` y `kai build` lo refrescan automáticamente si
  detectan deps en `kai.toml` que no están en el lock (la
  primera vez después de un `git clone`, por ejemplo).

## 8.7 Selección de versiones: MVS

Cuando un proyecto depende transitivamente del mismo otro
proyecto por dos rutas distintas con versiones distintas
declaradas, ¿qué versión gana?

kaikai resuelve esto con **minimum-version selection (MVS)**,
el algoritmo que usa Go modules. La regla es brutal pero
clara: del conjunto de versiones declaradas por la cadena
transitiva entera, gana la **máxima**.

Si tu app declara `manutara@v0.1.0` y una dependencia tuya
declara `manutara@v0.2.0`, todo el proyecto usa `v0.2.0`. La
suposición subyacente es que las versiones son
*backwards-compatible* dentro de un major: si todo el mundo
respeta semver, subir al mayor número no debería romper a
nadie.

MVS contrasta con el algoritmo de Cargo o npm, que resuelve
restricciones complejas y a veces baja a una versión menor
para satisfacer a alguien. MVS es **predecible**: dado el
mismo árbol, el resultado es el mismo. No hay "resolver
fallido", no hay diamond-dependency hell.

El precio es que la responsabilidad de mantener compatibilidad
queda en los autores de bibliotecas. Si subes a una versión que
rompe, todo el mundo que dependa transitivamente de ti se
rompe. Eso te obliga a tomar el versionado en serio.

## 8.8 Cache y `kai install`

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

Cada entrada se identifica por su SHA, no por la ref que el
usuario ve. Esto significa que tres proyectos distintos que
piden `manutara@v0.1.0` comparten el mismo árbol en disco. Y
si en algún momento `v0.1.0` se actualiza upstream (movimiento
de tag, que no debería pasar pero pasa), el cache fijado al
SHA original sigue intacto.

`kai install` se puede correr explícitamente, pero **`kai run`
y `kai build` lo invocan automáticamente** cuando detectan
deps no resueltas. En la práctica, después de `git clone` de un
proyecto, basta con `kai run main.kai`: el driver baja lo que
falta y corre.

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

Repasa cada `pub`. Pregunta para cada uno: ¿es de verdad parte
del contrato del módulo, o es un helper que dejé exportado por
inercia? Cada `pub` extra es un compromiso futuro.

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

`kai install` baja la versión fijada por el lockfile. El
código de `main.kai` y `negocio.kai` no cambia: los imports
siguen siendo los mismos.

Esa es la trayectoria completa: de archivo único a módulos, de
módulos a proyectos, de proyecto local a dependencia
distribuida. Cada paso es reversible. Cada paso es opcional.

## 8.10 Filosofía: simple y previsible

Las decisiones de este capítulo no son las más expresivas que
existen. Hay lenguajes con sistemas de módulos más potentes:
re-exports automáticos, alias dinámicos, módulos parametrizados
por valores. kaikai elige una variante austera y se queda ahí.

La razón es la misma que en el resto del lenguaje: lo que
ahorra dolores de cabeza vale más que lo que agrega potencia.
Un sistema de módulos donde nada se importa sin que aparezca
en una lista visible, donde el nombre de un módulo se deriva
de su ruta, y donde las dependencias se fijan a un SHA exacto
es un sistema que se entiende leyéndolo, sin tener que
ejecutarlo mentalmente.

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
