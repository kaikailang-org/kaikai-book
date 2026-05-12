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
compilador (`kaic2`) que produce C, después invoca `cc` para
compilar a un ejecutable, y al final corre el ejecutable.

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
global de tipos sin necesidad, y emite C directo en vez de
pasar por LLVM. Para programas grandes hay un cache (cap. 8
§8.8 cubre el cache de paquetes; el cache de compilación
del propio archivo `.kai` es otra historia).

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

$ kai add github.com/lnds/manutara@v0.1.0
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
- Diagnósticos en vivo: los errores y warnings del compilador
  aparecen en el buffer mientras escribes.

La configuración exacta del editor varía. Para VS Code, hay
una extensión oficial que arranca `kai lsp` automáticamente.
Para Neovim, configurar `nvim-lspconfig` con `kai lsp` como
comando.

El LSP es la pieza que vuelve el desarrollo en kaikai
comparable, en ergonomía cotidiana, al de Rust o TypeScript:
la retroalimentación es instantánea, sin necesidad de ir al
terminal para descubrir un error.

## 16.7 Variables de entorno

Unas cuantas variables de entorno controlan el comportamiento
del binario `kai` para casos especiales:

- **`CC`** (valor por defecto: `cc`): el compilador de C que
  `kai` invoca para producir el ejecutable final. Si tienes
  varias versiones de C en el sistema, o quieres usar `clang`
  específicamente, lo defines aquí: `CC=clang kai run
  archivo.kai`.
- **`CFLAGS`** (valor por defecto: vacío): flags adicionales para el
  compilador C. Útil para optimización (`CFLAGS=-O3`) o
  warnings (`CFLAGS=-Wall`).
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

## 16.8 Estructura típica de un proyecto

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

## 16.9 Hablar con C: `extern "C"` y el efecto `Ffi`

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

Cualquier cosa más estructurada — records, listas, tipos
suma — **no** cruza directo en FFI v1. Volvemos sobre eso
en un momento.

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
automatiza la compilación de C en v1, así que lo conectas
vía la variable de entorno `CFLAGS` que `kai` pasa al
compilador C anfitrión.

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
LLVM (capítulo 16 §16.1) no expone la misma plomería de
`CFLAGS` en v1.

### Lo que FFI v1 no hace

La lista es corta pero importante:

- **Records / structs por valor cruzando el borde.** No
  puedes declarar `extern "C" fn dibujar(c: Color)` donde
  `Color` sea un record kaikai que calza con un `struct`
  C. v1 pasa solo primitivos.
- **Parámetros de salida y argumentos puntero.** Nada de
  `int *out`: todo cruza por valor.
- **Funciones variádicas de C.** Sin binding directo a la
  familia de `printf`; las envuelves en un helper C de
  aridad fija.
- **Callbacks de C de vuelta a kaikai.** Una función C que
  recibe un puntero a función no puede llamar de vuelta a
  una función kaikai. Pospuesto para FFI v2.

El workaround canónico para el caso de structs es un
**shim C**: una función C delgada que aplana el struct en
primitivos en el borde kaikai y lo reconstruye antes de
llamar a la librería real. El costo es una función C por
cada entrada de la librería que use struct. Vale la pena
para v1; FFI v2 quitará la capa de shim para el caso común.

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

Una pequeña heurística: si te encuentras escribiendo más
de diez `extern "C"` para envolver algo, y la librería
tiene una API C estable, eso es candidato a un paquete
kaikai propio cuando aterrice `kai bindgen`. Mientras
tanto, el enfoque manual (un `extern "C"` por función, un
shim C por cada entrada que use struct) funciona bien.

## 16.10 Filosofía: tres principios del tooling

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
