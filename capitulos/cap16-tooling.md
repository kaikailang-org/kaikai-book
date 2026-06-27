# Capítulo 16 · Tooling: el binario `kai`

Hasta aquí cada capítulo se concentró en el lenguaje: la
sintaxis, los tipos, los efectos, el modelo de memoria.
Pero un lenguaje sin tooling no se usa. Este capítulo cubre
el otro lado: el binario `kai`, que es la cara con la que
todo programador interactúa todos los días.

Es un capítulo corto y de referencia. No hay ejercicios. La
idea es que sepas qué comando usar cuándo, y que tengas a
mano la lista para volver a ella.

## 16.1 Compilar y correr: `kai run`, `kai build`

El comando con el que vas a vivir es `kai run`:

```
$ kai run hola.kai
hola, kaikai
```

`kai run` compila el archivo a un binario nativo, lo ejecuta,
y reenvía cualquier argumento adicional al programa. Es el
ciclo edit-save-run del día a día. Bajo la capa hay un
compilador (`kaic2`) que por defecto baja a un objeto nativo
con LLVM enlazado dentro del propio compilador —sin escribir
texto `.ll`, sin invocar un proceso aparte—, y al final corre
el ejecutable.

Si quieres el binario sin correrlo, usa `kai build`:

```
$ kai build hola.kai
$ ./hola
hola, kaikai

$ kai build hola.kai -o build/hola
$ ./build/hola
hola, kaikai
```

`kai build` no corre el programa: solo deja el ejecutable en
disco. Con `-o` especificas dónde. El binario es **estático
en lo esencial**: no depende del compilador kaikai, solo de
la libc del sistema. Lo puedes copiar a otra máquina con el
mismo sistema operativo y arquitectura y va a correr.

### Compilación rápida

`kai run` y `kai build` están diseñados para sentirse
inmediatos. Un programa de unos cientos de líneas compila en
menos de un segundo en una máquina razonable. Esa velocidad
no es accidental: el compilador es self-hosted (kaikai
compilado en kaikai), evita pases costosos como inferencia
global de tipos sin necesidad, y baja a LLVM en el mismo
proceso, sin escribir archivos intermedios ni lanzar un
linker externo en el camino común. Para programas grandes hay
un cache (cap. 8 §8.8 cubre el cache de paquetes; el cache de
compilación del propio archivo `.kai` es otra historia).

Si quieres un sentido del tiempo: un programa de Rust de
tamaño comparable puede tardar 30 segundos en compilar. Un
programa de kaikai del mismo tamaño tarda menos de un
segundo. La diferencia se nota.

## 16.2 Tests, propiedades y benchmarks

Tres subcomandos cubren las tres construcciones de
verificación del cap. 7:

- **`kai test`** corre los bloques `test "..." { ... }`.
- **`kai check`** corre los bloques `check "..." with x: T { ... }`
  (propiedades verificadas con valores generados al azar).
- **`kai bench`** corre los bloques `bench "..." { ... }` y
  reporta tiempos.

```
$ kai test calculadora.kai
  ok   suma de cero
  ok   producto unitario
  ok   evaluación de literal

3/3 tests passed
```

```
$ kai check calculadora.kai
  conmutatividad de la suma: 100 iter, OK
  asociatividad de la multiplicación: 100 iter, OK

2/2 checks passed
```

```
$ kai bench calculadora.kai
  evaluación de árbol pequeño: 1000 iter / median 12 ns / MAD 1 ns / mean 13 ns / range [10, 45]
  evaluación de árbol grande: 1000 iter / median 8.4 us / MAD 0.2 us / mean 8.5 us / range [8.0, 12.1]

2 benches
```

`kai bench` admite `--iters N` para fijar el número de
iteraciones (por defecto, 1000). Para benchmarks costosos
conviene bajar; para mediciones más estables, subir.

Los tres comandos comparten dos propiedades importantes:

- **Solo corren los bloques relevantes.** `kai test` ignora
  `check` y `bench`; `kai check` ignora `test` y `bench`.
- **Los bloques no llegan al binario de producción.** `kai run`
  y `kai build` los descartan completamente.

## 16.3 Formateo: `kai fmt`

`kai fmt` es el formateador canónico. Estilo `gofmt`:

- Una sola forma correcta de imprimir cualquier archivo.
- Sin opciones de configuración. El proyecto no quiere
  guerras de estilo.
- Idempotente: formatear un archivo ya formateado no lo
  cambia.

Tres formas de uso:

```
$ kai fmt archivo.kai                # reescribe el archivo in-place
$ kai fmt --check archivo.kai        # exit 0 si está formateado, 1 si no
$ cat archivo.kai | kai fmt --stdin  # lee stdin, escribe en stdout
```

La forma `--check` está pensada para CI: si el código no está
formateado, el job falla y te obliga a correr `kai fmt`
antes de mergear.

La forma `--stdin` está pensada para editores: tu editor pasa
el buffer al formateador antes de guardar, recibe el
resultado canónico, lo escribe.

## 16.4 Gestión de paquetes: `init`, `add`, `install`, `update`

El cap. 8 §8.5-8.8 cubrió el modelo de paquetes (manifest
`kai.toml`, lockfile `kai.lock`, cache compartido,
minimum-version selection). Acá listamos los subcomandos
que orquestan ese modelo:

```
$ kai init miapp
kai-pkg: wrote kai.toml for package 'miapp'

$ kai add github.com/kaikailang-org/manutara@v0.1.0
$ kai install
$ kai update                # refresca todas las deps
$ kai update manutara       # refresca solo manutara
$ kai show                  # imprime kai.toml parseado
```

`kai run` y `kai build` invocan `kai install` automáticamente
si detectan que hay dependencias declaradas en `kai.toml`
pero no resueltas en `kai.lock`. En la práctica, después de
clonar un proyecto kaikai, basta con `kai run` para que
descargue lo que falte.

## 16.5 Modo de desarrollo: `kai watch`

`kai watch` es útil cuando estás iterando sobre un programa
de forma intensa:

```
$ kai watch main.kai
[watching main.kai...]
```

Cada vez que guardas el archivo, el watcher detecta el cambio,
recompila, y corre. Te permite tener el resultado a la vista
sin tener que volver al terminal y teclear `kai run`. Es la
forma más rápida de explorar un cambio en un demo o un script.

## 16.6 Integración con editores: `kai lsp`

`kai lsp` es el Language Server que kaikai expone para
editores. Implementa el Language Server Protocol estándar,
así que cualquier editor con soporte LSP (VS Code, Neovim,
Emacs, IntelliJ con plugin) puede conectarse y obtener:

- Type-on-hover: pasas el cursor por una expresión y ves su
  tipo.
- Goto-definition: saltas al lugar donde un nombre fue
  declarado.
- Document symbols: el árbol de símbolos del archivo para el
  panel lateral del editor.
- Completion: lista de candidatos al teclear, con tipo y
  origen para cada uno.
- Signature help: al abrir paréntesis en una llamada, muestra
  la firma de la función y resalta el parámetro actual.
- Diagnósticos en vivo: los errores y warnings del compilador
  aparecen en el buffer mientras escribes. Los **holes sin
  rellenar** salen como warnings — el editor te recuerda lo
  que queda pendiente sin romperte el flujo.

La configuración exacta del editor varía. Para VS Code, hay
una extensión oficial que arranca `kai lsp` automáticamente.
Para Neovim, configurar `nvim-lspconfig` con `kai lsp` como
comando.

El LSP es la pieza que vuelve el desarrollo en kaikai
comparable, en ergonomía cotidiana, al de Rust o TypeScript:
la retroalimentación es instantánea, sin necesidad de ir al
terminal para descubrir un error.

## 16.7 Documentación interactiva: `kai info`

Al lado de `kai lsp`, que sirve al editor, vive `kai info`:
páginas de referencia del lenguaje, organizadas por tema,
accesibles desde la línea de comandos sin abrir un navegador.
Estilo `man` o `info` de Unix, pero el contenido es kaikai
mismo.

Sin argumentos te lista los temas que conoce:

```
$ kai info
kai info — language reference, organized by topic.

Topics:
  actors       Message-passing concurrency built on fibers
  effects      Algebraic effects and handlers
  ffi          Foreign function interface — calling C via `Ffi`.
  fibers       Structured concurrency via nursery, spawn, await, cancel
  holes        Typed holes for incremental development.
  loop         Control flow — `if`, `while`, `until`, and iteration via pipes.
  lsp          The kaikai Language Server (`kai lsp`).
  match        Pattern matching with exhaustiveness checking.
  packages     `kai.toml`, imports, visibility.
  pipes        Apply, map, flat-map, filter — four pipe operators.
  protocols    Single-dispatch protocols, Go/Clojure/Elixir-style.
  syntax       One-page reference of the forms kaikai actually has.
  testing      Test blocks, assertions, benchmarks, property checks.
  units        Units of measure on `Real`.
```

Pasando un tema, lo despliega:

```
$ kai info holes
# holes
...
```

Tres flags útiles:

- `kai info --list` — solo nombres de temas, uno por línea. Útil
  para shells y scripts.
- `kai info -k <keyword>` — busca en todos los temas. Devuelve
  los que mencionan la palabra.
- `kai info <topic> --json` — la página estructurada en JSON.

Esta última forma es deliberada: kaikai trata su propia
documentación como **datos**, no como prosa estática. Un
agente IA puede consumir `kai info effects --json` y
disponer de la doc completa del sistema de efectos sin
necesidad de scrapear markdown ni de tener el repo del
lenguaje a mano. Es el otro extremo del puente que el cap. 15
abre desde el lado de los holes: el lenguaje provee a quien
escribe código —humano o agente— la información que
necesita, en el formato que mejor le sirva.

La misma idea se extiende a `kai build`. Tres flags emiten
información estructurada en vez de prosa diagnóstica:

- `kai build --diags-json` — todos los errores y warnings del
  compilador como un array JSON, con campos `severity`,
  `file`, `line`, `col`, `message`, `code`. Lo que el editor
  vía LSP consume queda accesible también desde scripts y
  agentes que llaman a `kai build` directamente.
- `kai build --effects-json` — la fila de efectos inferida
  para cada función `pub` del archivo. Permite que un agente
  responda "¿esta función toca el disco?" sin parsear código.
- `kai build --library-mode` — compila sin requerir un
  `fn main`. Útil para analizar paquetes que se van a usar
  como librería.

Las tres formas comparten propósito: hacer que la
información que el compilador ya tiene viva fuera del
binario, en un formato que cualquier consumidor pueda
procesar sin reimplementar el typer.

## 16.8 La referencia del stdlib: `kai doc`

`kai info` documenta el **lenguaje** por tema. Su hermano
`kai doc` documenta el **stdlib** por módulo: lee los
atributos `#[doc("...")]` que cada función del stdlib lleva
escritos y los presenta en la terminal. Donde `kai info
effects` te explica el sistema de efectos, `kai doc effects`
te lista las capacidades atómicas que el runtime trae.

Sin argumentos, lista los módulos:

```
$ kai doc
kai doc — stdlib reference, by module.

Modules:
  array                Bridge helpers between `[T]` and `Array[T]`.
  collections/hashmap  Mutable, separately-chained `HashMap[k, v]`.
  core/string          Byte-indexed string helpers.
  date                 Civil calendar dates (proleptic Gregorian).
  encoding/json        JSON encoder + decoder.
  string_builder       Amortised text accumulator.
  ...
```

Con un módulo, te despliega su tabla de símbolos con el
resumen de cada uno:

```
$ kai doc date
# date   (date.kai)

  Civil calendar dates (proleptic Gregorian).

  add_days       Shift by `n` civil days (negative goes backwards).
  day_of_week    ISO-8601 weekday numbering: 1 = Monday … 7 = Sunday.
  make           Validating constructor. `None` when the month is …
  parse          Strict ISO-8601 `YYYY-MM-DD`.
  today          Today's civil date in UTC. The only effectful fn …
  ...
```

Y con `módulo.símbolo`, la firma y el doc completo de un
símbolo:

```
$ kai doc date.parse
```

`kai doc` resuelve los nombres contra el paquete actual, no
solo contra el stdlib: si tu proyecto tiene un módulo con
`#[doc("...")]`, también lo lee. Eso cierra el círculo —
documentas tu código con el mismo atributo que el stdlib, y
la misma herramienta lo muestra.

## 16.9 Dos backends: nativo y C

`kai build` y `kai run` tienen dos backends de generación de
código. El default es **`native`**: baja a LLVM enlazado
dentro del compilador, en el mismo proceso, y emite un objeto
nativo. No escribe texto `.ll` ni invoca `clang`. Como libLLVM
viene enlazado en `kaic2`, el binario que produces corre el
backend nativo sin LLVM del sistema.

El otro es **`--backend=c`**: el backend portable de texto C,
que emite C y lo enlaza con `cc`. Es el camino de bootstrap
del propio compilador y el fallback más portátil. Si te topas
con una construcción que el backend nativo todavía no cubre,
`--backend=c` suele compilarla.

```
$ kai build app.kai                  # backend nativo (default)
$ kai build --backend=c app.kai      # backend C portable
```

Unas cuantas variables de entorno controlan el comportamiento
del binario `kai` para casos especiales:

- **`KAI_BACKEND`** (`c` | `native`): el backend por defecto
  cuando no pasas `--backend`. Lo sobreescribe la flag.
- **`KAI_NATIVE_OPT`** (`0|1|2|3|s|z`, por defecto `2`): nivel
  de optimización del pipeline LLVM del backend nativo.
  `--debug` lo baja a `0`, `--release` lo deja en `2`.
- **`CC`** (por defecto `cc`) y **`CFLAGS`**: el compilador de
  C y sus flags, usados **solo por el backend `c`** para
  producir el ejecutable final (`CC=clang`, `CFLAGS=-O3`).
- **`KAI_NO_STDLIB=1`**: salta la carga automática del
  stdlib. Para casos avanzados: bootstrap del compilador,
  embebidos sin libc completa, experimentos.
- **`KAI_STDLIB`**: override de la raíz del stdlib. Por
  defecto, `kai` autodetecta dónde vive (instalado vs
  checkout de desarrollo). Si quieres usar una versión
  alternativa, apuntas aquí.
- **`KAI_INCLUDE`**: override de la raíz de los headers
  del runtime (`runtime.h`). Mismo principio que `KAI_STDLIB`.

Para uso normal no necesitas tocar nada de esto. El binario
viene preconfigurado para encontrar todo lo suyo.

## 16.10 Estructura típica de un proyecto

Un proyecto kaikai estándar se ve así:

```
miapp/
├── kai.toml              # manifest del paquete
├── kai.lock              # lockfile (commit junto al código)
├── main.kai              # entry point
├── lib/                  # módulos públicos (si es biblioteca)
│   ├── core.kai
│   └── parser.kai
├── tests/                # tests pesados que no caben en línea
│   └── integration.kai
└── examples/             # demos que usan la biblioteca
    └── basico/
        ├── kai.toml      # con `mibib = { path = ".." }`
        └── main.kai
```

Convenciones:

- **`main.kai`** en la raíz si el proyecto produce un
  ejecutable. La firma debe ser `fn main() : ... = ...`.
- **`lib/`** para el código importable de un proyecto que es
  biblioteca. Cuando alguien instala tu paquete con
  `kai add`, lo que verá vía import es lo que vive bajo
  `lib/`.
- **`tests/`** para tests que prefieres tener separados (por
  ejemplo, porque son lentos o usan IO). Los tests en línea
  en el archivo del código fuente siguen siendo el patrón
  primario.
- **`examples/<nombre>/`** para demos. Cada demo tiene su
  propio `kai.toml` que declara una dependencia local hacia
  el paquete principal. Eso te permite probar la biblioteca
  como si fueras un usuario externo.

No es obligatorio. `kai run archivo.kai` corre cualquier
archivo .kai sin importar dónde esté. Pero cuando el
proyecto crece, esta estructura paga.

## 16.11 Hablar con C: `extern "C"` y el efecto `Ffi`

Tarde o temprano vas a necesitar una librería que ya existe
en C: un driver de base de datos, un framework gráfico, un
paquete numérico. La interfaz de funciones foráneas
(**FFI**) de kaikai es cómo la llamas desde código kaikai
sin perder el sistema de tipos ni la fila de efectos.

### Declarar una función externa

El caso más simple es atarse a una función de libc directo:

```kai
extern "C" fn llabs(n: Int) : Int / Ffi

fn main() : Unit / Console + Ffi {
  print("|-7| = #{llabs(0 - 7)}")
}
```

```
$ kai run abs.kai
|-7| = 7
```

Línea por línea:

- **`extern "C" fn name(args) : T / Ffi`** declara un
  símbolo externo. El compilador emite una declaración
  forward para que el linker de C la resuelva. El cuerpo
  es implícito: el call site se compila a una llamada
  directa a función C.
- **`/ Ffi`** es el efecto. Cualquier función que llame a
  un `extern "C"` — directa o transitivamente — tiene
  `Ffi` en su fila. Misma disciplina que `Stdout` o
  `File`: una función que habla con C lo declara en su
  firma.

El compilador mapea los tipos primitivos de kaikai a sus
equivalentes en C en el cruce:

| kaikai | C |
|---|---|
| `Int` | `int64_t` |
| `Real` | `double` |
| `Bool` | `int8_t` (0 / 1) |
| `Char` | `int32_t` (codepoint) |
| `String` | `const char *` (terminado en NUL, lo posee kaikai) |
| `Unit` | `void` (solo retorno) |

Para anchos exactos en el borde hay anotaciones
**fixed-width**: `U8 U16 U32 U64 I8 I16 I32 I64 F32` fijan el
tipo C preciso (`uint8_t`, `int32_t`, `float`, …). Son
anotaciones *solo del borde*: del lado kaikai el valor sigue
siendo un `Int` (o `Real` para `F32`), así que se mezcla con
literales y aritmética normal. El shim hace el cast de C en la
llamada.

```kai
extern "C"("SetVolume") fn set_volume(level: U8) : Unit / Ffi
```

Las listas y los tipos suma no cruzan directo; los records
sí, como structs por valor, y eso lo vemos en un momento.

### Renombrar el símbolo de C

A veces el nombre del símbolo en C choca con un
identificador de kaikai o simplemente se lee mal en línea.
Usa el override entre paréntesis:

```kai
extern "C"("strlen") fn c_strlen(s: String) : Int / Ffi
```

El nombre del lado kaikai es `c_strlen`; el linker resuelve
contra `strlen`. Útil cuando el nombre C es palabra
reservada en kaikai, cuando quieres un nombre con sabor
kaikai sobre uno genérico de C, o cuando necesitas dos
bindings kaikai que apuntan al mismo símbolo C con firmas
distintas.

### Enlazar contra tu propio código C

Para librerías que no estén en libc, la forma típica es:
escribes un archivo C chico con las funciones que
necesitas, y dejas que `kai build` invoque a su compilador
C con ese archivo incluido. El gestor de paquetes no
automatiza la compilación de C, así que lo conectas vía la
variable de entorno `CFLAGS` que `kai` pasa al compilador C
anfitrión.

Un ejemplo mínimo. El lado C:

```c
// shim.h
#include <stdint.h>
int64_t my_double(int64_t x);
```

```c
// shim.c
#include "shim.h"
int64_t my_double(int64_t x) { return x * 2; }
```

El lado kaikai:

```kai
extern "C" fn my_double(x: Int) : Int / Ffi

fn main() : Unit / Console + Ffi {
  print("doble(21) = #{my_double(21)}")
}
```

Compilando:

```
$ CFLAGS="-include shim.h shim.c" kai build --backend=c app.kai -o app
$ ./app
doble(21) = 42
```

El valor de `CFLAGS` te deja inyectar cualquier cosa que
el compilador C acepte: `-include` para exponer
declaraciones, fuentes `.c` extra para compilar adentro,
`-l<lib>` para enlazar contra librerías instaladas,
`pkg-config --cflags --libs <paquete>` para usar la
información de una librería del sistema. Cuando crece más
allá de una línea, lo envuelves en un `Makefile`.

El flag `--backend=c` aquí es necesario porque el backend
nativo (§16.1, §16.9) no expone la misma plomería de
`CFLAGS`.

### Structs por valor

Un record kaikai puede cruzar el borde como un `struct` C
**por valor**, en ambas direcciones, declarándolo con
`extern "C" type`. Cada campo lleva un ancho exacto (un tipo
fixed-width o un `extern "C" type` anidado); `Int`, `Real` y
`String` se rechazan como campos de struct, porque romperían
el layout que el compilador C arma para structs chicos.

```kai
extern "C" type Color   = { r: U8, g: U8, b: U8, a: U8 }
extern "C" type Vector2 = { x: F32, y: F32 }

extern "C"("vec_add")
fn vec_add(a: Vector2, b: Vector2) : Vector2 / Ffi
```

El shim desempaqueta los campos del record en un struct C
local con los anchos reales, llama por valor, y re-empaqueta
el struct devuelto en un record fresco. La clasificación del
ABI (struct chico en registros vs memoria, según SysV o
AAPCS) la decide el compilador C, no kaikai.

> El struct-by-value compila en el backend C (`--backend=c`);
> el backend nativo enruta el FFI de structs por el backend C
> y, en un build nativo, te reporta el gap junto con la
> solución (`--backend=c`). El marshalling nativo de structs
> es un paso siguiente planeado.

### Handles opacos

Para un recurso que el lado kaikai pasa de mano en mano pero
nunca inspecciona —una conexión a base de datos, un socket—
está `extern "C" opaque`. El valor queda detrás de una caja
con reference counting que guarda el `void *` de C.

```kai
extern "C" opaque Conn

extern "C"("PQconnectdb") fn connect(s: String) : Conn / Ffi
extern "C"("PQexec")      fn exec(c: Conn, q: String) : Int / Ffi
extern "C"("PQfinish")    fn finish(c: Conn) : Unit / Ffi
```

El reference counting de kaikai administra la **caja** del
handle, pero nunca libera el recurso C que vive adentro: el
autor del binding llama al destructor C explícitamente
(`PQfinish` arriba). Pasar el handle a dos llamadas no lo
libera dos veces. Los handles opacos funcionan en ambos
backends.

### Lo que FFI todavía rechaza

Fuera de alcance, rechazado en tiempo de compilación:

- **Uniones, bitfields y funciones variádicas de C.** Sin
  binding directo a la familia de `printf`; las envuelves en
  un helper C de aridad fija.
- **Callbacks de C de vuelta a kaikai.** Un parámetro extern
  con tipo función no calza: una closure de kaikai es una
  caja en el heap con capturas, no un puntero a función C
  pelado.
- **Campos de struct que no sean fixed-width** ni un
  `extern "C" type` anidado.

### Cuándo agarrar FFI

La regla honesta: **solo cuando realmente necesites la
librería C**. Cada `extern "C"` es un hueco en las
garantías del lado kaikai. El compilador no puede chequear
qué hace la función C con sus argumentos, no puede probar
sus efectos, no puede razonar sobre su modelo de memoria.
El efecto `Ffi` al menos hace visible el hueco en la
firma, pero el peso de auditoría de esa firma es
"confiar en quien escribió la librería C" más "confiar
en el compilador C".

Para computación pura, prefiere una implementación kaikai.
Para IO y facilidades del SO, prefiere los efectos del
stdlib (`Stdout`, `File`, `NetTcp`, etc.) — esos ya están
conectados a C por dentro pero en una forma que los
diseñadores del lenguaje controlan. FFI es la herramienta
correcta para atar ecosistemas C existentes que no quieres
reescribir: drivers, toolkits nativos de UI, librerías
específicas de hardware.

Una pequeña heurística: si te encuentras escribiendo
muchos `extern "C"` para envolver algo, y la librería tiene
una API C estable, eso es candidato a empaquetar como un
binding kaikai reutilizable que el resto del ecosistema
pueda importar, en vez de repetir las declaraciones en cada
proyecto.

## 16.12 Ediciones: estabilidad sin estancamiento

Hay una decisión que el resto del libro asume sin
explicarla del todo: kaikai usa **ediciones** para separar
*qué prometemos que no cambia* de *qué nos reservamos el
derecho de mover*. La idea no es nueva — Rust la formalizó
en 2014 — pero kaikai la toma en serio desde temprano.

### Qué es una edición

Una edición es un nombre — `tongariki`, `hanga-roa`,
`orongo` — que fija una versión del **contrato del
lenguaje** entre kaikai y tu código. Dentro de una edición,
estas cosas no cambian de manera incompatible:

- la sintaxis y las palabras reservadas;
- la semántica del sistema de tipos y los efectos;
- las firmas `pub` del stdlib;
- los flags y el comportamiento del binario `kai`;
- el esquema de `kai.toml`.

Fuera del contrato — y por lo tanto libre de cambiar entre
versiones — está todo lo que no toca tu código fuente:
representación interna de variantes, layout de stacks de
fibras, formato del caché en disco, texto exacto de los
diagnósticos, fases del typer, internals del Perceus,
performance.

El compromiso para ti es simple: **subir el compilador es
indoloro**. Lees las notas de release, instalas la versión
nueva, recompilas. El compromiso para el equipo de kaikai
es también simple: podemos iterar fuerte por dentro mientras
no rompamos lo de afuera. Las dos partes ganan.

### Cómo se declara

En tu `kai.toml`:

```toml
name = "miapp"
version = "0.1.0"
edition = "hanga-roa"

[dependencies]
```

Y para verificar la edición activa de tu instalación:

```
$ kai --version
kaikai 0.91.2 - hanga-roa (stage 2, self-hosted)
```

Si el `kai.toml` omite el campo, el compilador asume la
edición default de la instalación. Recomendación: en cuanto
un paquete va a tener vida más allá de un fin de semana,
fíjala explícitamente. Es la diferencia entre "esto
compila hoy" y "esto va a seguir compilando".

### Multi-edición: viejo código, compilador nuevo

El compilador kaikai acepta **cualquier edición que conozca**.
Si tu paquete declara `edition = "tongariki"` y la instalación
está en `hanga-roa`, el compilador aplica las reglas de
tongariki para ese paquete, aunque otro paquete de la misma
máquina compile contra hanga-roa. Esa es la mecánica de
"estabilidad sin estancamiento": no tienes que migrar todo
tu mundo al mismo tiempo.

Cuando una edición se cierra (cuando todo el ecosistema ya
migró), las versiones siguientes de kaikai pueden dejar de
aceptarla. Hasta entonces, viejo y nuevo conviven.

### El escape hatch: `#[unstable]`

A veces un módulo quiere exponer un API nuevo *en serio*
pero todavía no se compromete con la firma exacta. La
anotación `#[unstable]` marca declaraciones que están
fuera del contrato de la edición:

```kai
#[unstable]
pub fn from_stdin() : Source[String, Stdin + Spawn] / Spawn =
  ?from_stdin

#[unstable]
pub type Source[t, e] = { pid: Pid[Demand] }
```

Quien consume un API `#[unstable]` tiene que decirlo en
**su propio** `kai.toml`:

```toml
[unstable]
ahu = true
```

La idea: nadie usa una API en evolución sin enterarse. El
contrato de la edición sigue cubriendo lo demás.

### Ediciones existentes

Al cierre de este libro, kaikai conoce tres:

| Edición | Estado | Notas |
|---|---|---|
| `tongariki` | cerrada | Fase de iteración rápida pre-2026. Solo paquetes que aún no migraron. |
| `hanga-roa` | activa (default) | La primera edición pública. El libro está escrito contra esta. |
| `orongo` | futura | Próxima edición. Lo que se difiera de Hanga Roa aterriza acá. |

Los nombres siguen la cantera rapanui del resto del
ecosistema: lugares de Rapa Nui en orden cronológico.
Cuando se cierre `hanga-roa`, llegará un anuncio, una
guía de migración, y `kai migrate` para automatizar los
cambios mecánicos. Mientras tanto, el código que escribiste
contra hanga-roa va a seguir compilando.

## 16.13 Filosofía: tres principios del tooling

Si quieres recordar el tono general del tooling, son tres
ideas:

1. **Velocidad primero.** Compilar y correr deben sentirse
   inmediatos. Si el ciclo edit-save-run es lento, el
   programador escribe menos código, prueba menos, y
   construye menos confianza. Todo el tooling de kaikai se
   diseña con ese reloj corriendo.

2. **Una forma correcta para cada cosa.** Un formateador
   canónico sin opciones. Un gestor de paquetes con MVS sin
   resolución compleja. Un sistema de tests integrado con el
   lenguaje. La filosofía es la misma que en Go: minimizar
   las decisiones que el programador tiene que tomar sobre
   cómo usar las herramientas, para liberar tiempo para
   decidir qué construir.

3. **Lo que vale es lo que sale del compilador.** Diagnósticos
   precisos, contraejemplos exactos, formatos estructurados
   (JSON para holes y tipos). El compilador es la interfaz
   real del lenguaje. Hacerlo claro y rápido es lo que
   vuelve a kaikai usable, antes que cualquier IDE
   sofisticada.

Estas no son palabras vacías. Cada vez que el lenguaje crece
una característica, la pregunta de "¿cómo se va a sentir en
el tooling?" se hace antes que la pregunta "¿es elegante
teóricamente?". A veces gana la elegancia (los efectos
algebraicos pagan algo de complejidad de tooling); a veces
gana el tooling (las reglas de exhaustividad y la inferencia
local se ajustan para que los mensajes sean buenos). El
balance es vivo, y este capítulo es la cara visible de él.
