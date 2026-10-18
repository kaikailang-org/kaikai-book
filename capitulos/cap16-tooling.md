# Capítulo 16 · Tooling: el binario `kai`

Hasta aquí aprendiste el lenguaje: la sintaxis, los tipos, los
efectos, el modelo de memoria. Pero un lenguaje sin tooling no
se usa, y creo que ahí se han quedado varios lenguajes mejores
que este. Este capítulo cubre el otro lado: el binario `kai`,
con el que trabajas todos los días.

Es un capítulo de referencia, sin ejercicios. Aprendes qué
comando usar cuándo y te queda la lista a mano para volver a
ella.

## 16.1 Compilar y correr: `kai run`, `kai build`

El comando con el que vas a vivir es `kai run`:

```
$ kai run hola.kai
hola, kaikai
```

`kai run` compila el archivo a un binario nativo, lo ejecuta y
le reenvía cualquier argumento adicional. Es el ciclo
edit-save-run del día a día. Debajo, el compilador (`kaic2`)
baja por omisión a un objeto nativo con LLVM enlazado dentro de
sí mismo (sin escribir texto `.ll`, sin invocar un proceso
aparte), y al final corre el ejecutable.

Si quieres el binario sin correrlo, usa `kai build`:

```
$ kai build hola.kai
$ ./hola
hola, kaikai

$ kai build hola.kai -o build/hola
$ ./build/hola
hola, kaikai
```

`kai build` solo deja el ejecutable en disco; `-o` dice dónde.
El binario es **estático en lo esencial**: no depende del
compilador kaikai, solo de la libc del sistema. Lo copias a
otra máquina con el mismo sistema operativo y arquitectura, y
corre.

Para distribuir o depurar hay dos perfiles:

```
$ kai build --release app.kai    # -O2 y símbolos fuera: más
                                 # chico, listo para enviar
$ kai build --debug app.kai      # -O0 con tablas DWARF
```

Con `--debug`, `lldb` o `gdb` ponen breakpoints sobre líneas
`.kai` y un panic imprime el stack trace con `archivo.kai:línea`.
Las tablas DWARF las arma el backend nativo; con `--backend=c`
el flag no aporta. Sin flag queda el punto medio: compilación
rápida, símbolos presentes.

### Lo que tu programa le devuelve al shell

Un binario le habla al shell con su **código de salida**. En
kaikai eso no pide una llamada al sistema operativo: si `main`
devuelve un `Int`, ese entero *es* el estado del proceso. Con
cualquier otro tipo de retorno el programa sale con 0.

```kai
# ejemplos/cap16/01_estado_de_salida.kai
fn validar(puerto: Int) : Result[Int, String] =
  if puerto > 0 and puerto < 65536 { Ok(puerto) }
  else { Err("puerto fuera de rango: #{puerto}") }

fn main() : Int / Stdout {
  match validar(70000) {
    Ok(p)    -> { println("escuchando en #{p}"); 0 }
    Err(msg) -> { println("error: #{msg}"); 1 }
  }
}
```

```
$ kai run ejemplos/cap16/01_estado_de_salida.kai
error: puerto fuera de rango: 70000
$ echo $?
1
```

Es la convención de C, Go y Rust: el `Result` que ya usas
adentro decide, en el `match` final, con qué número sale el
proceso. Sin eso, un `set -e`, un gate de CI o un `make` leen
como éxito lo que tu programa considera una falla.

Dos detalles:

- **POSIX se queda con los 8 bits bajos.** Devolver `256` sale
  con 0 y `-1` sale con 255. Lo trunca el sistema operativo, no
  kaikai, igual que en cualquier otro lenguaje.
- **La salida buffereada se vacía igual.** El retorno de `main`
  usa el camino de salida completo de la libc, así que lo que
  imprimiste alcanza a llegar. `os.process.exit`, en cambio,
  corta por `_exit(2)` y puede dejarte sin las últimas líneas.

### Compilación rápida

`kai run` y `kai build` están diseñados para sentirse
inmediatos: un programa de unos cientos de líneas compila en
menos de un segundo en una máquina razonable. No es accidental.
El compilador es self-hosted (kaikai compilado en kaikai) y
baja a LLVM en el mismo proceso: arma el módulo con la API de
LLVM y emite el objeto nativo directamente, sin texto `.ll`
intermedio ni un `clang` aparte. Solo el enlace final contra
el runtime pasa por `cc`. Para programas grandes hay un cache
(cap. 8 §8.8 cubre el cache de paquetes; el cache de
compilación del propio archivo `.kai` es otra historia).

Ese "menos de un segundo" es el estado estacionario, el que vas
a vivir: el caso de estudio del cap. 17, unas 440 líneas en cinco
módulos, compila en unos 0,6 segundos. Con el cache frío cuesta
varias veces eso; en mi máquina, 4,1 segundos para ese mismo
proyecto. Tenlo presente antes de cronometrar una compilación
en frío y sacar la conclusión equivocada.

Como referencia, un programa de Rust de tamaño comparable puede
tardar 30 segundos en compilar. La diferencia se nota.

### Solo verificar: `kai typecheck`

Cuando solo quieres saber si el programa está bien tipado, sin
binario ni ejecución, `kai typecheck` es la respuesta más
rápida a "¿esto compila?":

```
$ kai typecheck app.kai
$ echo $?
0
```

En éxito no imprime nada y sale con código `0`. Ante un error,
imprime el diagnóstico y sale con `1`:

```
$ kai typecheck app.kai
error: type mismatch in function call
  --> app.kai:5:16
    |
  5 |   let n = doble(s)
    |                ^
  = note: expected: (Int) -> Int
  = note: found:    (String) -> ?t0
  = note: in argument 1 of `doble`
```

El cursor cae sobre el argumento que no calza, y las notas
nombran cuál es (`in argument 1 of `doble``) y qué se esperaba
ahí.

La clave es lo que `typecheck` **no** hace. Corre el front-end
completo del compilador (lexer, parser, resolución de nombres,
inferencia HM y de filas de efectos, la maquinaria de kinds y
unidades, la validación de dispatch de protocolos), monomorfiza
y se detiene. No genera código, no enlaza, no escribe un
binario. Se salta todo lo que un `build` gasta *después* de
saber que el programa es correcto, y por eso termina en una
fracción del tiempo.

La verificación es la misma en ambos; `typecheck` apenas se
baja del tren antes. Si calla, el front-end está limpio.

El código de salida también coincide, y eso importa si vas a
automatizar: 0 cuando el programa está sano, 1 ante cualquier
error del front-end, sea de tipos, de parseo o de nombres.
`typecheck` no inventa códigos propios: lo que sale por consola
y el número con que termina son los que `kai build` habría dado.

Un límite honesto, porque el nombre promete un poco de más:
`typecheck` cubre el front-end, no el pipeline entero. No ve
los huecos de cobertura de un backend, una forma que el
front-end acepta y el generador de código no sabe emitir. Un
archivo que pasa `typecheck` casi siempre compila, pero "casi
siempre" no es "siempre". Para la certeza total, el juez sigue
siendo `kai build`.

Los flags de reporte estructurado (`--diags-json`,
`--holes-json`) funcionan sobre `typecheck` igual que sobre
`build`: el mismo reporte, sin generación de código. Eso lo
vuelve la herramienta natural del loop con holes del cap. 15,
donde cada iteración cuesta solo el front-end.

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
iteraciones (por omisión, 1000): menos para benchmarks
costosos, más para mediciones estables.

Los tres comandos comparten dos propiedades:

- **Solo corren los bloques relevantes.** `kai test` ignora
  `check` y `bench`; `kai check` ignora `test` y `bench`.
- **Los bloques no llegan al binario de producción.** `kai run`
  y `kai build` los descartan completamente.

Un cuarto comando no corre ninguno de esos bloques: los pone a
prueba. `kai mutate` rompe el código a propósito, una
construcción a la vez, corre tus tests contra cada versión rota y
te reporta los **sobrevivientes**, los mutantes que ninguna
prueba notó:

```
$ kai mutate                                # módulos del paquete, contra `kai test`
$ kai mutate --module src/parser.kai        # un solo archivo
$ kai mutate --limit 20 --operator arm      # un primer vistazo, lo más barato primero
$ kai mutate --oracle './correr-pruebas.sh' # cualquier comando que salga con 0 si todo anda bien
$ kai mutate --list                         # los sitios, sin correr nada
```

Los operadores son seis: `arm` saca un brazo de `match`,
`compare` mueve el borde de una comparación (`>=` a `>`),
`connect` cambia `and` por `or`, `negate` invierte una condición,
`literal` perturba un literal y `call` elide una llamada. Cada
mutante cuesta una corrida del oráculo, así que empieza con
`--module` y `--limit`. En §7.6 lo corriste sobre el evaluador
y encontraste dos huecos.

## 16.3 Formateo: `kai fmt`

`kai fmt` es el formateador canónico. Estilo `gofmt`:

- Una sola forma correcta de imprimir cualquier archivo.
- Una sola perilla, y no es de estilo: el ancho de línea. El
  proyecto no quiere guerras de estilo.
- Idempotente: formatear un archivo ya formateado no lo
  cambia.

El ancho manda la maqueta. Un constructo que cabe en su línea
se queda ahí; uno que no cabe se corta en sus propios puntos
(después del `=`, un argumento por línea, una etapa de pipe por
línea). Un corte que ya escribiste en uno de esos puntos se
respeta, así que tu cadena de pipes maquetada a mano sobrevive
al formateador. El default son 100 columnas;
`--width N` lo cambia para una corrida, y la clave `width` de
la tabla `[fmt]` de `kai.toml` lo fija para el paquete:

```toml
[fmt]
width = 80
```

Cuatro formas de uso:

```
$ kai fmt archivo.kai                # reescribe el archivo in-place
$ kai fmt .                          # formatea el paquete completo
$ kai fmt --check archivo.kai        # exit 0 si está formateado, 1 si no
$ cat archivo.kai | kai fmt --stdin  # lee stdin, escribe en stdout
```

`--check` es para CI: si el código no está formateado, el job
falla y te obliga a correr `kai fmt` antes de mergear.

`--stdin` es para editores: tu editor le pasa el buffer al
formateador antes de guardar y escribe el resultado canónico.

## 16.4 El linter: `kai lint`

Donde `kai fmt` es dictatorial, `kai lint` es opinante.
Señala código que **compila pero se lee como un error**, al
estilo del Clippy de Rust: el compilador se queda estricto en
corrección y mudo en estilo; las opiniones viven en el linter.

```
$ kai lint archivo.kai           # warnings legibles
$ kai lint --json archivo.kai    # los hallazgos como JSON
```

Dos propiedades definen su carácter:

- **Opt-in y no bloqueante.** Solo warnings, siempre sale con
  exit 0, jamás cambia qué compila. Lo corres cuando quieres
  una segunda mirada, no como peaje.
- **Consciente de tipos y efectos.** No es un grep con
  ínfulas: reusa el AST tipado y las filas de efectos que el
  compilador ya produjo, así que distingue lo que un scanner
  textual no puede.

El ejemplo más claro es la regla `non_tail_list_recursion`.
Una función que se llama a sí misma
sobre la cola de una lista, fuera de posición de cola, gasta un
marco de pila por elemento, y la pila de una fibra es chica:

```kai
pub fn intercalar(xs: [String], sep: String) : [String] = match xs {
  []           -> []
  [x, ...rest] -> [sep, x, ...intercalar(rest, sep)]   # warning
}
```

Pero con una sola cabeza, `[x * 2, ...duplicar(rest)]`, el
compilador convierte la recursión en un ciclo cuando la fila de
efectos de la función está vacía, y la regla se queda callada.
Si esa misma función hace `println`, la fila ya no está vacía,
el ciclo no ocurre y la regla avisa. Esa distinción requiere la
fila de efectos; un linter textual no la tiene.

La regla que más vas a ver es `discard_pure_value`. Un bloque
descarta el valor de toda sentencia que no sea su cola; si ese
valor no es `Unit`, es un uso olvidado, haga o no efectos la
llamada que lo produjo:

```kai
fn run() : Unit / Stdout {
  area(3, 4)        # warning: el Int se descarta
  parse("42")       # warning: el Result se descarta
  println("listo")
}
```

Para descartar a propósito, lo dices: `parse("42") |> ignore`
o `let _ = parse("42")`. Ninguna de las dos genera
advertencia.

Otras reglas del catálogo empujan hacia el kaikai idiomático.
`point_free_nudge` sugiere la sección point-free (§6.2) cuando
una lambda unaria solo proyecta sobre su parámetro.
`and_then_to_map_nudge` avisa cuando un `and_then` es en
realidad un `map`, y `match_option_to_combinator` hace lo
propio con un `match` sobre `Option` que ya tiene combinador.
`list_concat_literal_to_spread` pilla el `[h] ++ t`, que arma
una lista de un elemento solo para concatenarla y tirarla,
mientras el spread `[h, ...t]` emite el cons directo y no pide
memoria. El resto barre residuos: `redundant_if_bool`,
`redundant_match_catchall`, `dead_code_unused_priv`,
`effect_over_declared` y `effect_ffi_without_extern`.

Son once al día de hoy, y el número va a subir. Cada regla
entra cuando se puede demostrar que las dos formas son
equivalentes, porque un linter ruidoso es peor que ninguno.
`kai info lint` lista el estado actual.

## 16.5 Gestión de paquetes: `init`, `add`, `fetch`, `update`

El modelo de paquetes (manifest `kai.toml`, lockfile
`kai.lock`, cache compartido, minimum-version selection) lo
conociste en el cap. 8 §8.5-8.8. Estos son los subcomandos que
lo orquestan:

```
$ kai init miapp
kai-pkg: wrote kai.toml for package 'miapp'

$ kai add github.com/kaikailang-org/manutara@v0.1.0
$ kai fetch                 # resuelve las deps y escribe kai.lock
$ kai update                # refresca todas las deps
$ kai update manutara       # refresca solo manutara
$ kai show                  # imprime kai.toml parseado
```

`kai run` y `kai build` invocan `kai fetch` solos si hay
dependencias declaradas en `kai.toml` y no resueltas en
`kai.lock`. Después de clonar un proyecto kaikai, basta con
`kai run` para que descargue lo que falte.

Los nombres reparten el trabajo como lo espera un usuario de
Rust o de Go: `fetch` resuelve dependencias, e `install` hace
lo que su nombre dice en esos ecosistemas, **poner un binario
en el PATH**, y no lo que significa en npm:

```
$ kai install .                        # compila el paquete del cwd e instala su binario
$ kai install github.com/x/pepito      # desde una fuente git
$ kai install github.com/x/pepito@v1   # fijado a un tag, branch o SHA
$ kai install --list                   # qué instaló este prefijo
```

El binario se nombra desde el campo `name` del manifest, no
desde la URL de origen, y aterriza en `$KAIKAI_HOME/bin`, que
el instalador ya dejó en tu PATH. Reemplazar uno existente
exige `--force`. La forma sin argumento sigue resolviendo
dependencias, pero avisa que su nombre ahora es `fetch`:

```
$ kai install
kai: warning: 'kai install' with no argument resolves dependencies; that is now 'kai fetch'.
  'kai install <spec>' installs a package's binary. The no-argument form changes at the next edition.
```

Cuando `hanga-roa` se cierre, esa forma desaparece.

### Repartir completions junto al binario

La mitad de lo que hace grato un CLI es que el shell complete
subcomandos y flags. Un paquete declara los scripts que trae y
`kai install` deja cada uno donde su shell ya lo busca:

```toml
[completions]
zsh  = "completions/_foo"
bash = "completions/foo.bash"
fish = "completions/foo.fish"
```

Las rutas son relativas al paquete; el nombre del archivo de
destino sale del campo `name` del manifiesto, no de la ruta de
origen, así que aterriza con el nombre que el shell busca. Los
tres directorios viven bajo `$KAIKAI_HOME/share`, e
`install.sh` los engancha una sola vez a la ruta de búsqueda
del shell; después, cualquier `kai install` funciona sin paso
adicional. Si falta ese enganche, `kai install` imprime la
línea que hay que agregar; nunca edita un archivo de arranque a
tus espaldas.

Un detalle con historia detrás: a zsh el directorio se le
**antepone** al `fpath`, no se le agrega al final. Agregado,
una función de fábrica con el mismo nombre le gana igual: zsh
trae un `_mh` que se apropia de `mark` y después suprime hasta
la completación de nombres de archivo cuando MH no está
instalado.

Como `[native]`, es declarativo y acotado: tres shells, un
destino fijo cada uno, sin hooks. Una ruta que se escapa del
paquete o que nombra un archivo inexistente se salta con una
advertencia y el binario se instala igual.

No confundas `kai update` con `kai upgrade`: `update` refresca
las **dependencias** de tu paquete; `upgrade` actualiza el
**compilador mismo** al último release (descarga, verifica el
SHA-256 y reemplaza el binario en su lugar, como hiciste en el
capítulo 1). Sobre una instalación de Homebrew, `upgrade` no
toca el Cellar: te apunta a `brew upgrade kaikai` y sale.

## 16.6 Modo de desarrollo: `kai watch`

`kai watch` sirve cuando iteras intensamente sobre un programa:

```
$ kai watch main.kai
[watching main.kai...]
```

Cada vez que guardas el archivo, el watcher recompila y corre.
Tienes el resultado a la vista sin volver al terminal a teclear
`kai run`: es la forma más rápida de explorar un cambio en un
demo o un script.

## 16.7 Integración con editores: `kai lsp`

`kai lsp` es el Language Server de kaikai. Implementa el
Language Server Protocol estándar, así que cualquier editor con
soporte LSP (VS Code, Neovim, Emacs, IntelliJ con plugin) se
conecta y obtiene:

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
  rellenar** salen como warnings: el editor te recuerda lo
  que queda pendiente sin romperte el flujo.

La configuración varía por editor. Para VS Code hay una
extensión oficial que arranca `kai lsp` sola. En Neovim,
configuras `nvim-lspconfig` con `kai lsp` como comando.

El LSP vuelve el desarrollo en kaikai comparable, en ergonomía
cotidiana, al de Rust o TypeScript: la retroalimentación es
instantánea, sin ir al terminal para descubrir un error.

## 16.8 Documentación interactiva: `kai info`

Al lado de `kai lsp`, que sirve al editor, vive `kai info`:
páginas de referencia del lenguaje, organizadas por tema, en la
línea de comandos y sin navegador. Estilo `man` o `info` de
Unix, pero el contenido es kaikai mismo.

Sin argumentos lista los temas que conoce:

```
$ kai info
kai info — language reference, organized by topic.

Topics:
  actors       Message-passing concurrency built on fibers — `Actor[Msg]` effect
  contracts    Design-by-Contract — `requires` / `ensures` on a function, and
  deltas       Where kaikai deliberately differs from Rust/Go/Python/JS/Haskell
  effects      Algebraic effects and handlers — kaikai's first-class mechanism for
  ffi          Foreign function interface — calling C via the `Ffi` capability.
  fibers       Structured concurrency via nursery, spawn, await, cancel — BEAM-style
  holes        Typed holes for incremental development.
  idiomatic    How to write kaikai the way kaikai wants to be written — the idioms,
  install      Install and self-update the kaikai compiler.
  kinds        Kinds classify types the way types classify values — one closed
  lint         A Clippy-style linter for suspect-but-valid code, beside the compiler.
  llm          Bootstrap guide for an agentic AI pointed at a kaikai repo — what
  loop         Control flow — `if`, `while`, `until`, and iteration via pipes.
  lsp          The kaikai Language Server (`kai lsp`) for editor integration.
  match        Pattern matching with exhaustiveness checking.
  mutate       Break the code on purpose and ask whether anything notices.
  net          Byte-level networking — TCP, UDP, DNS, and Unix-domain sockets.
  packages     `kai.toml`, imports, visibility.
  pipes        Apply (`|>`), map (`|`), flat-map (`||`), filter (`|?`), each (`|!`) —
  protocols    Single-dispatch protocols, Go/Clojure/Elixir-style.
  seq          `Seq[t]` — the lazy sequence: pure, shared, possibly endless. Written
  syntax       One-page reference of the forms kaikai actually has. Every form on
  testing      Test blocks, assertions, benchmarks, property checks.
  units        Units of measure on `Real` — phantom-type discipline, zero runtime
  vec          `Vec[T]` — the pure value vector: flat contiguous storage with
...
```

Pasando un tema, lo despliega:

```
$ kai info holes
# holes
...
```

Tres flags útiles:

- `kai info --list`: solo nombres de temas, uno por línea. Útil
  para shells y scripts.
- `kai info -k <keyword>`: busca en todos los temas. Devuelve
  los que mencionan la palabra.
- `kai info <topic> --json`: la página estructurada en JSON.

Esta última forma la agregué a propósito: kaikai trata su
propia documentación como **datos**. Un agente IA consume
`kai info effects --json` y dispone de la doc completa del
sistema de efectos sin scrapear markdown ni tener el repo del
lenguaje a mano. Es el otro extremo del puente que el cap. 15
abre desde los holes: el lenguaje le da a quien escribe código
(humano o agente) la información que necesita, en el formato
que mejor le sirva.

La idea se extiende a `kai build`. Tres flags emiten
información estructurada en vez de prosa diagnóstica:

- `kai build --diags-json`: los diagnósticos del compilador
  como JSON, un objeto con el archivo, un `status` (el código
  de salida que daría el build) y un array `diagnostics`. Cada
  entrada trae `severity`, `file`, `line`, `col`, `message` y
  un `related` con las notas. Lo que el editor consume vía LSP
  queda al alcance de scripts y agentes que llaman a
  `kai build` directo. El array no lo cubre todo: un error
  de kinds o una violación de contrato dejan `status` en 1 y
  el array vacío, con el texto en stderr. La señal confiable
  de que el build falla es `status`.
- `kai build --effects-json`: la fila de efectos de cada
  función, una entrada por función con `file`, `fn`, `line`,
  `col`, `effects`, `row_open` y `handlers_installed`. El
  reporte incluye las funciones del prelude, así que el
  consumidor filtra por `file`. Permite que un agente responda
  "¿esta función toca el disco?" sin parsear código.
- `kai build --library-mode`: corre el front-end sin exigir un
  `fn main` y responde los comentarios `# @probe <kind> L:C`
  que encuentre en el fuente: tipo, definición, completado,
  firma. Es lo que `kai lsp` usa por debajo para el hover y el
  ir-a-definición.

Las tres sacan del compilador la información que ya tiene, en
un formato que cualquier consumidor procesa sin reimplementar
el typer.

## 16.9 La referencia del stdlib: `kai doc`

`kai info` documenta el **lenguaje** por tema. Su hermano
`kai doc` documenta el **stdlib** por módulo: lee los
atributos `#[doc("...")]` de cada función del stdlib y los
presenta en la terminal. Donde `kai info effects` te explica el
sistema de efectos, `kai doc effects` te lista las capacidades
atómicas que trae el runtime.

Sin argumentos, lista los módulos:

```
$ kai doc
kai doc — stdlib reference, by module.

Modules:
  collections/queue    Amortised-O(1) two-list FIFO queue (Okasaki).
  collections/stack    LIFO stack, a wrapper over `[a]`.
  date                 Civil calendar dates (proleptic Gregorian).
  encoding/base64      Base64 encoder/decoder.
  encoding/hex         Hexadecimal encoding/decoding.
  path                 POSIX path manipulation.
  string_builder       `StringBuilder` — an amortised text accumulator.
  uuid                 RFC 4122 UUID v4 generator + parser.
  ...
```

Con un módulo, despliega su tabla de símbolos con el resumen de
cada uno:

```
$ kai doc date
# date   (date.kai)

  Civil calendar dates (proleptic Gregorian).

  add_days               Shift by `n` civil days (negative goes backwards).
  day_of_week            ISO-8601 weekday numbering: 1 = Monday … 7 = Sunday.
  days_in_month          Days in `m` of year `y`.
  make                   Validating constructor.
  to_string              `YYYY-MM-DD`, zero-padded (year to 4 digits, month/day to 2).
  today                  Today's civil date in UTC.
  ...

Run 'kai doc date.<symbol>' for a symbol's signature and full doc.
```

Y con `módulo.símbolo`, la firma y el doc completo de un
símbolo:

```
$ kai doc date.parse
# date.parse   (date.kai)

  parse(s: String) -> Option[Date]

  Strict ISO-8601 `YYYY-MM-DD`: exactly 10 chars, ASCII digits in the
  three fields, `-` separators. Anything else — wrong length, signs,
  spaces, `2026/01/02`, `2026-1-2` — is `None`, as is a well-formed
  string naming an invalid date (`2026-02-30`, `2026-13-01`).
```

`kai doc` resuelve los nombres también contra el paquete
actual. Documentas tu código con el mismo `#[doc("...")]` que
el stdlib, y la misma herramienta lo muestra.

## 16.10 Dos backends: nativo y C

`kai build` y `kai run` tienen dos backends de generación de
código. El default es **`native`**: baja a LLVM enlazado
dentro del compilador, en el mismo proceso, y emite un objeto
nativo, sin escribir texto `.ll` ni invocar `clang`. Como
libLLVM viene enlazado en `kaic2`, el backend nativo no
necesita LLVM del sistema.

El otro es **`--backend=c`**: emite C y lo enlaza con `cc`. Es
el camino de bootstrap del propio compilador y el fallback más
portátil. Si te topas con una construcción que el backend
nativo todavía no cubre, `--backend=c` suele compilarla.

```
$ kai build app.kai                  # backend nativo (default)
$ kai build --backend=c app.kai      # backend C portable
```

Unas cuantas variables de entorno ajustan `kai` para casos
especiales:

- **`KAI_THREADS`** (entero): cuántos hilos del sistema usa el
  scheduler M:N del programa que corres. Sin la variable, el
  runtime toma la cantidad de núcleos del host (con tope en 32).
  `KAI_THREADS=1` vuelve al scheduler cooperativo de un solo
  hilo, byte a byte, para cuando quieres una salida
  reproducible. Es la única de esta lista que afecta al
  ejecutable y no a la compilación.
- **`KAI_BACKEND`** (`c` | `native`, por defecto `native`): el
  backend que se usa cuando no pasas `--backend`. Lo sobreescribe
  la flag.
- **`KAI_NATIVE_OPT`** (`0|1|2|3|s|z`): nivel de optimización del pipeline LLVM
  del backend nativo. `kai build` usa `2` y `kai run` usa `1`,
  porque un programa que se compila para correr una vez no
  recupera el tiempo de `-O2`. `--debug` lo baja a `0` y
  `--release` lo deja en `2`.
- **`CC`** (por defecto `cc`) y **`CFLAGS`**: el compilador de
  C y sus flags, usados **solo por el backend `c`** para
  producir el ejecutable final (`CC=clang`, `CFLAGS=-O3`).
- **`KAI_NO_STDLIB=1`**: salta la carga automática del
  stdlib. Para casos avanzados: bootstrap del compilador,
  embebidos sin libc completa, experimentos.
- **`KAI_STDLIB`**: override de la raíz del stdlib. Por
  defecto, `kai` autodetecta dónde vive (instalado vs
  checkout de desarrollo). Para usar una versión alternativa,
  apuntas aquí.
- **`KAI_INCLUDE`**: override de la raíz de los headers
  del runtime (`runtime.h`). Mismo principio que `KAI_STDLIB`.

Para uso normal no tocas nada de esto: el binario encuentra
todo lo suyo, y `kai env` te muestra **qué** encontró, ya
resuelto:

<!-- transcripto: rutas y toolchain id propios de cada máquina -->
```
$ kai env
KAIKAI_HOME=/Users/tuusuario/.kaikai
KAI_STDLIB=/Users/tuusuario/.kaikai/share/kaikai/stdlib
KAI_TOOLCHAIN_ID=1791118538-57238280
KAI_KAIC2=/Users/tuusuario/.kaikai/libexec/kaikai/kaic2
```

Es lo primero que revisas cuando algo compila en una máquina y
no en otra: rara vez es el código, casi siempre es
`KAI_STDLIB` apuntando a otra parte. Con un nombre como
argumento imprime solo ese valor, cómodo para un script.

## 16.11 Estructura típica de un proyecto

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
- **`lib/`** para el código importable de una biblioteca.
  Quien agrega tu paquete con `kai add` ve vía import lo que
  vive bajo `lib/`.
- **`tests/`** para tests que prefieres separados (por
  ejemplo, porque son lentos o usan IO). Los tests en línea,
  junto al código, siguen siendo el patrón primario.
- **`examples/<nombre>/`** para demos. Cada demo tiene su
  propio `kai.toml` con una dependencia local hacia el paquete
  principal, así pruebas la biblioteca como un usuario externo.

No es obligatorio: `kai run archivo.kai` corre cualquier
archivo .kai donde esté. Pero cuando el proyecto crece, esta
estructura rinde.

## 16.12 Hablar con C: `extern "C"` y el efecto `Ffi`

Tarde o temprano vas a necesitar una biblioteca que ya existe
en C: un driver de base de datos, un framework gráfico, un
paquete numérico. Con la interfaz de funciones foráneas
(**FFI**) la llamas desde kaikai sin perder el sistema de tipos
ni la fila de efectos.

### Declarar una función externa

El caso más simple es atarse directo a una función de libc:

```kai
# ejemplos/cap16/ffi/01_libc_abs.kai
extern "C" fn llabs(n: Int) : Int / Ffi

fn main() : Unit / Stdout + Ffi {
  print("|-7| = #{llabs(-7)}")
}
```

```
$ kai run ejemplos/cap16/ffi/01_libc_abs.kai
|-7| = 7
```

Línea por línea:

- **`extern "C" fn name(args) : T / Ffi`** declara un
  símbolo externo. El compilador emite una declaración
  forward para que el linker de C la resuelva. El cuerpo
  es implícito: el call site se compila a una llamada
  directa a función C.
- **`/ Ffi`** es el efecto. Cualquier función que llame a
  un `extern "C"` (directa o transitivamente) tiene `Ffi` en
  su fila. Es la disciplina de `Stdout` o `File`: una función
  que habla con C lo declara en su firma.

En el cruce, el compilador mapea los primitivos de kaikai a sus
equivalentes en C:

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

Las listas y los tipos suma no cruzan directo; los records sí,
como structs por valor, que encuentras más abajo.

### Renombrar el símbolo de C

Cuando el nombre del símbolo en C choca con un identificador
de kaikai o se lee mal en línea, usa el override entre
paréntesis:

```kai
extern "C"("abs") fn c_abs(n: I32) : I32 / Ffi
```

El nombre del lado kaikai es `c_abs`; el linker resuelve
contra `abs`. Sirve cuando el nombre C es palabra reservada en
kaikai, cuando quieres un nombre con sabor kaikai, o cuando
necesitas dos bindings que apuntan al mismo símbolo C con
firmas distintas.

Fíjate en el `I32`. La declaración que el compilador emite
**es** el contrato del binding, y para un símbolo que los
headers del sistema ya declaran (como toda libc) tiene que
calzar con el tipo C exacto: `abs` es `int abs(int)`, así
que el binding dice `I32`, no `Int`. Si no, `cc` rechaza la
redeclaración en conflicto. Un símbolo cuyo tipo C no tiene
mapeo kaikai (`size_t`, un struct de libc) no se ata directo:
lo envuelves en un `.c` chico, como en la sección siguiente.

El binding completo, con su llamada:

```kai
# ejemplos/cap16/ffi/02_renombre.kai
extern "C"("abs") fn c_abs(n: I32) : I32 / Ffi

fn main() : Unit / Stdout + Ffi {
  print("|-7| = #{c_abs(-7)}")
}
```

```
$ kai run ejemplos/cap16/ffi/02_renombre.kai
|-7| = 7
```

### Enlazar contra tu propio código C

Para bibliotecas que no están en libc, escribes un archivo C
chico con las funciones que necesitas y dejas que `kai build`
lo compile con su compilador C. Hay dos maneras de conectarlo,
según sea un programa suelto o algo que otra gente va a usar.

Un ejemplo mínimo. El lado C:

```c
// ejemplos/cap16/ffi/03_shim/shim.h
#include <stdint.h>
int64_t my_double(int64_t x);
```

```c
// ejemplos/cap16/ffi/03_shim/shim.c
#include "shim.h"

int64_t my_double(int64_t x) {
  return x * 2;
}
```

El lado kaikai:

```kai
# ejemplos/cap16/ffi/03_shim/app.kai
extern "C" fn my_double(x: Int) : Int / Ffi

fn main() : Unit / Stdout + Ffi {
  print("doble(21) = #{my_double(21)}")
}
```

Para un programa suelto, lo conectas a mano vía la variable
de entorno `CFLAGS`, que `kai` pasa al compilador C
anfitrión:

```
$ cd ejemplos/cap16/ffi/03_shim
$ CFLAGS="shim.c" kai build app.kai -o app
$ ./app
doble(21) = 42
```

`CFLAGS` te deja inyectar cualquier cosa que el compilador C
acepte: `-include` para exponer
declaraciones, fuentes `.c` extra para compilar adentro,
`-l<lib>` para enlazar contra bibliotecas instaladas,
`pkg-config --cflags --libs <paquete>` para usar la
información de una biblioteca del sistema. Es la escotilla de
escape, y mantiene precedencia sobre todo lo demás.

Pero `CFLAGS` no viaja. Si tu binding es un paquete, quien lo
use no tiene por qué saber que adentro hay un `.c`, ni adivinar
la variable de entorno correcta. Para eso el manifiesto tiene
la tabla `[native]`:

```toml
[native]
sources = ["c/shim.c"]   # C vendorizado, relativo al paquete
include = ["c"]          # directorios -I para compilar esas fuentes
libs = ["sqlite3"]       # bibliotecas del sistema, -l<nombre> al enlazar
```

Con eso declarado, el consumidor escribe `kai build` a secas.
Todos los verbos (`build`, `run`, `test`, `install`) honran la
tabla, en los dos backends, y se propaga transitivamente: si A
y B dependen del mismo paquete con shim, el shim se compila y
se enlaza una sola vez.

Es solo declarativo: `sources`, `include`, `libs`, sin build
scripts ni flags libres. Un build script es código
ajeno corriendo en la máquina de quien instala, o sea superficie
de ataque y un agujero de reproducibilidad, y los flags libres
convertirían el manifiesto en un sistema de construcción. La
distinción que sí importa es entre `sources` y `libs`: una
fuente vendorizada siempre funciona, porque el `.c` viaja con
el paquete y compila en la máquina de destino; una biblioteca
del sistema puede no estar ahí sin culpa de nadie, y cuando
el enlace falla el driver nombra el paquete y la biblioteca que
faltó.

Funciona igual en los dos backends: el nativo también enlaza
el objeto final con `cc`, así que tus fuentes C extra entran
por la misma puerta.

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

Del lado C, el shim incluye el `kai_ffi.h` que kaikai genera
junto al build, con un `typedef` por cada `extern "C" type`, y
nombra esos mismos tipos. Así hay una sola definición de cada
struct, y un layout que no calza es un error de compilación de
C, no un borde corrupto en silencio:

```c
#include "kai_ffi.h"        /* trae Color, Vector2 */

Vector2 vec_add(Vector2 a, Vector2 b) {
    Vector2 r = { a.x + b.x, a.y + b.y };
    return r;
}
```

El ejemplo canónico vive en
`examples/ffi/v2_struct_by_value.kai` del repositorio del
lenguaje; `kai info ffi` trae la referencia.

El struct-by-value funciona en **ambos backends**. En el
nativo, el emitter clasifica el struct según la ABI de C
(registros vs memoria) directamente; en el backend C esa
clasificación la hereda `cc`. Aplica la salvedad de siempre:
si el struct que atas ya lo declaran los headers del sistema
(un `div_t` de libc), el nombre kaikai del tipo no coincide con
el de C y conviene envolver la llamada en un shim propio.

### Handles opacos

Para un recurso que el lado kaikai pasa de mano en mano pero
nunca inspecciona (una conexión a base de datos, un socket)
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
biblioteca C**. Cada `extern "C"` es un hueco en las garantías
del lado kaikai. El compilador no puede verificar qué hace la
función C con sus argumentos, ni probar sus efectos, ni
razonar sobre su modelo de memoria. El efecto `Ffi` al menos
hace visible el hueco en la firma, pero auditarla es "confiar
en quien escribió la biblioteca C" más "confiar en el
compilador C".

Para computación pura, prefiere una implementación kaikai.
Para IO y facilidades del SO, prefiere los efectos del stdlib
(`Stdout`, `File`, `NetTcp`, etc.): ya están conectados a C
por dentro, en una forma que controlan los diseñadores del
lenguaje. FFI es la herramienta para atar ecosistemas C que no
quieres reescribir: drivers, toolkits nativos de UI,
bibliotecas específicas de hardware.

Una heurística: si te encuentras escribiendo muchos
`extern "C"` para envolver una biblioteca con API C estable,
empaquétalos como un binding kaikai reutilizable que el resto
del ecosistema pueda importar, en vez de repetir las
declaraciones en cada proyecto.

## 16.13 Ediciones: estabilidad sin estancamiento

El resto del libro asume una decisión sin explicarla del todo:
kaikai usa **ediciones** para separar *qué prometemos que no
cambia* de *qué nos reservamos el derecho de mover*. La idea
no es nueva (Rust la formalizó en 2014), pero kaikai la toma
en serio desde temprano.

### Qué es una edición

Una edición es un nombre (`tongariki`, `hanga-roa`,
`orongo`) que delimita el **contrato del lenguaje** entre
kaikai y tu código. El contrato cubre lo que tocas al
escribir:

- la sintaxis y las palabras reservadas;
- la semántica del sistema de tipos y los efectos;
- las firmas `pub` del stdlib;
- los flags y el comportamiento del binario `kai`;
- el esquema de `kai.toml`.

Fuera del contrato, y por lo tanto libre de cambiar entre
versiones, está todo lo que no toca tu código fuente:
representación interna de variantes, layout de stacks de
fibras, formato del caché en disco, texto exacto de los
diagnósticos, fases del typer, internals del Perceus,
rendimiento.

Lo que necesitas tener claro hoy: **el contrato se sella
cuando la edición se cierra, no antes.** En `hanga-roa` esa
superficie todavía se está decidiendo. Un cambio incompatible
en la lista de arriba es parte del trabajo de construir la
promesa, y no la rompe. Una firma `pub` se pone a prueba, y si
no se gana su lugar, sale.

Esos cambios no quedan enterrados en el historial de git. Se
anotan a medida que ocurren en `docs/editions.md` del
repositorio del lenguaje, bajo *Breaking changes accumulated
for the Orongo cut*, cada uno con su migración al lado. Esa
lista va a alimentar las notas de release y las reglas de
`kai migrate` cuando `orongo` cierre la edición. Mientras
tanto es tu changelog: lo que lees antes de subir de versión.

El compromiso tiene dos tiempos. Hoy, bajo `hanga-roa`, los
cambios rompedores son pocos, están anotados y traen
migración. Bajo `orongo`, la superficie queda fija y subir el
compilador deja de pedir lectura previa. La edición es el
mecanismo que decide cuándo la superficie deja de moverse.

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
kaikai 0.164.0 - hanga-roa (stage 2, self-hosted)
demos baseline: 37
native p2:      active
home:           https://kaikai-lang.org
```

La primera línea te da versión y edición. Las otras tres son
diagnóstico del build (cuántas demos cubre la baseline, qué
backend nativo quedó activo) y las vas a querer cuando
reportes un problema.

Si el `kai.toml` omite el campo, el compilador asume la
edición default de la instalación. En cuanto un paquete va a
vivir más allá de un fin de semana, fíjala explícitamente: es
la diferencia entre "esto compila hoy" y "esto va a seguir
compilando".

### Multi-edición: viejo código, compilador nuevo

El compilador acepta **cualquier edición que conozca**. Si tu
paquete declara `edition = "tongariki"` y la instalación está
en `hanga-roa`, el compilador aplica las reglas de tongariki a
ese paquete, aunque otro de la misma máquina compile contra
hanga-roa. Esa es la mecánica de "estabilidad sin
estancamiento": no tienes que migrar todo tu mundo a la vez.

Cuando una edición se cierra (cuando todo el ecosistema ya
migró), las versiones siguientes de kaikai pueden dejar de
aceptarla. Hasta entonces, viejo y nuevo conviven.

### El escape hatch: `#[unstable]`

A veces un módulo quiere exponer un API nuevo *en serio* sin
comprometerse todavía con la firma exacta. La anotación
`#[unstable]` marca declaraciones fuera del contrato de la
edición:

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

Así nadie usa una API en evolución sin enterarse, y el contrato
de la edición sigue cubriendo lo demás.

### Ediciones existentes

Al cierre de este libro, kaikai conoce tres:

| Edición | Estado | Notas |
|---|---|---|
| `tongariki` | cerrada | Fase de iteración rápida pre-2026. Solo paquetes que aún no migraron. |
| `hanga-roa` | activa (default) | La primera edición pública. El libro está escrito contra esta. |
| `orongo` | futura | La edición de estabilización. Todavía no tiene número de versión asignado: una edición abarca muchas versiones del compilador, porque el compromiso vive en la edición y no en un número. El rótulo "1.0" está postergado indefinidamente. |

Los nombres siguen la cantera rapanui del resto del
ecosistema: lugares de Rapa Nui en orden cronológico.
Tongariki, Hanga Roa, Orongo, y Anakena como el horizonte que
viene después. Los hitos del lenguaje se definen por edición,
nunca por un número de versión con aura. Cuando se cierre
`hanga-roa` habrá un anuncio, una guía de migración, y
`kai migrate` automatizará los cambios mecánicos. La
herramienta ya existe: reescribe el AST de un archivo entre
ediciones, por omisión en modo dry-run (imprime sin tocar
nada), y con `--write` aplica, de forma idempotente. Mientras
tanto, el código que escribiste contra hanga-roa va a seguir
compilando.

## 16.14 Filosofía: tres principios del tooling

El tooling se resume en tres ideas:

1. **Velocidad primero.** Compilar y correr deben sentirse
   inmediatos. Si el ciclo edit-save-run es lento, escribes
   menos código, pruebas menos y confías menos en lo que
   tienes. Todo el tooling de kaikai se diseña con ese reloj
   corriendo.

2. **Una forma correcta para cada cosa.** Un formateador
   canónico sin opciones de estilo. Un gestor de paquetes con
   MVS sin resolución compleja. Un sistema de tests integrado con el
   lenguaje. La filosofía es la de Go: minimizar las
   decisiones sobre cómo usar las herramientas, para que tu
   tiempo vaya a decidir qué construir.

3. **Lo que vale es lo que sale del compilador.** Diagnósticos
   precisos, contraejemplos exactos, formatos estructurados
   (JSON para holes y tipos). El compilador es la interfaz
   real del lenguaje. Hacerlo claro y rápido es lo que vuelve
   a kaikai usable, antes que cualquier IDE sofisticada.

Cada vez que el lenguaje crece una característica, la pregunta
"¿cómo se va a sentir en el tooling?" va antes que "¿es
elegante teóricamente?". A veces gana la elegancia (los
efectos algebraicos le cargan complejidad al tooling); a veces
gana el tooling (las reglas de exhaustividad y la inferencia
local se ajustan para que los mensajes sean buenos). El
balance es vivo, y este capítulo es su cara visible.
