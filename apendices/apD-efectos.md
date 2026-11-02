# Apéndice D · Catálogo de efectos del stdlib

Los efectos que expone el stdlib, como referencia: ante una
firma `: Unit / X` en la documentación de una función, vienes
aquí a confirmar qué provee `X`.

La especificación completa vive en
`github.com/kaikailang-org/kaikai/docs/effects-stdlib.md`. Aquí
tienes la declaración de cada efecto y para qué sirve.

## D.1 IO básico

### `Stdout`, `Stderr` y `Stdin`

Los tres flujos estándar son efectos separados, uno por
descriptor. Esa granularidad le permite a un arnés de tests
capturar stdout sin tocar lo que se escribe a stderr.

```kai
effect Stdout {
  print(s: String) : Unit
  is_tty()         : Bool
}

effect Stderr {
  eprint(s: String) : Unit
  is_tty()          : Bool
}

effect Stdin {
  read_line()        : Option[String]
  read_bytes(n: Int) : String
  is_tty()           : Bool
}
```

`print` y `eprint` agregan un newline. Ninguna de las dos lleva
tipo de falla: bajo el handler por defecto, el fallo recuperable
común (el pipe cerrado del otro lado, `EPIPE`) se absorbe en
silencio, y lo que quede es lo bastante catastrófico como para
entrar en pánico. `read_line` devuelve `None` en EOF.

`is_tty()` responde si el flujo es una terminal, según
`isatty(3)` sobre su propio descriptor. Es la compuerta estándar
para color ANSI: emites escapes cuando `Stdout.is_tty()`, texto
plano bajo un pipe o una redirección. La otra mitad de esa
convención la cubre `Env.get("NO_COLOR")`.

El alias `Console = Stdout + Stderr + Stdin` agrupa a los tres
cuando la distinción no aporta.

### `Env`

```kai
effect Env {
  args()                               : [String]
  get(name: String)                    : Option[String]
  set_var(name: String, value: String) : Result[Unit, String]
  unset_var(name: String)              : Result[Unit, String]
  vars()                               : [Pair[String, String]]
}
```

Acceso a los argumentos de línea de comando (`argv`) y a las
variables de entorno, tanto de lectura como de escritura.

### `File`

```kai
perm read
perm write

effect File {
  read_file(path: String)                    : Result[String, String]
  write_file(path: String, contents: String) : Result[Unit, String]
  open_read(path: String)                    : Result[FileHandle<read>, String]
  read_chunk(h: FileHandle<read>, max: Int)  : Result[String, String]
  open_write(path: String)                   : Result[FileHandle<read + write>, String]
  write_chunk(h: FileHandle<write>, data: String) : Result[Unit, String]
  close_file(h: FileHandle)                  : Unit
}
```

Dos niveles. `read_file` / `write_file` mueven el archivo
entero de una vez, que es lo que quieres casi siempre. El
resto es la ruta por chunks para archivos que no caben o que
no quieres cargar completos.

Fíjate en el `<...>` de los handles: `FileHandle<read>` y
`FileHandle<read + write>` llevan la capacidad **en el tipo**.
Un handle abierto para lectura no tipa donde se espera
`FileHandle<write>`, y eso lo decide el compilador, no un
chequeo en runtime: es el kind `Perm` del cap. 19 §19.9. Lo
que el tipo declara es lo que el código
pidió al abrir, no el permiso que el sistema operativo tenga
sobre el archivo: esa falla sigue viajando por el `Result` de
cada operación.

Para directorios y metadata, ver los módulos de `fs`.

### `Log`

```kai
effect Log {
  debug(msg: String) : Unit
  info(msg: String)  : Unit
  warn(msg: String)  : Unit
  error(msg: String) : Unit
}
```

Logging con niveles. El handler por defecto escribe cada
mensaje a stderr con el formato `[ISO8601Z] NIVEL mensaje`;
instalar un handler propio te deja capturarlo o filtrarlo.

En el capítulo 12 declaraste un `effect Log { log(msg:
String) : Unit }` propio, más chico, para aprender el
mecanismo. No hay conflicto: una declaración local hace
*shadowing* del nombre del stdlib dentro de su archivo. Si
quieres el de cuatro niveles, no lo declares.

### `Trace`

```kai
effect Trace {
  log(msg: String)         : Unit
  checkpoint(name: String) : Unit
}
```

Trazas ad-hoc, más chico que `Log` y con otro propósito:
`log` emite una línea suelta, `checkpoint` marca un punto con
nombre. Se importa desde `trace`.

A diferencia del resto de esta sección, **`Trace` no trae
handler por defecto**: sin uno instalado el programa no
compila, porque el nombre no está en alcance. El módulo trae
dos:

- `trace.with_trace_default(body)` escribe cada operación a
  stdout como `[trace] mensaje`, y los checkpoints como
  `[trace] checkpoint: nombre`.
- `trace.with_log_prefix(prefijo, body)` antepone
  `prefijo ++ ": "` a cada operación y la reemite vía
  `Trace.log` al siguiente handler de la pila, así que se
  encadena con el anterior.

## D.2 Tiempo y aleatoriedad

### `Clock`

```kai
effect Clock {
  wall_now()        : WallTime
  monotonic_now()   : Instant
  sleep_ns(ns: Int) : Unit
}
```

Dos relojes distintos a propósito. `wall_now` da la hora del
calendario (`WallTime` es `{ secs, nanos }` desde epoch), que
salta cuando alguien ajusta el reloj del sistema. `monotonic_now`
da un `Instant` que solo avanza: es el que quieres para medir
cuánto tardó algo. `sleep_ns` parkea la fibra, no el hilo.

### `Random`

```kai
effect Random {
  int_range(lo: Int, hi: Int) : Int
}
```

Una sola operación, uniforme en `[lo, hi]` con ambos extremos
incluidos. El handler por defecto siembra un PCG64 desde el
reloj y el pid del proceso. Los helpers de más alto nivel,
construidos sobre esta op, viven en el módulo `Random`. No
sirve para criptografía.

### `SecureRandom`

```kai
effect SecureRandom {
  int_range(min: Int, max: Int) : Int
  bytes(n: Int)                 : [Int]
}
```

Aleatoriedad criptográficamente segura, deliberadamente separada
de `Random` para que un handler de tests que stubea `Random` no
pueda debilitar sin querer una ruta sensible. `bytes(n)` entrega
`n` bytes como enteros en `[0, 255]`. El handler por defecto
puentea al CSPRNG del sistema (`getrandom` / `arc4random`).

## D.3 Red

### `NetTcp`

```kai
effect NetTcp {
  connect(host: String, port: Int) : Result[Conn, String]
  listen(host: String, port: Int)  : Result[Listener, String]
  accept(l: Listener)              : Result[Conn, String]
  send(c: Conn, data: [Int])       : Result[Int, String]
  recv(c: Conn, max: Int)          : Result[[Int], String]
  recv_timeout(c: Conn, max: Int, nanos: Int) : Option[Result[[Int], String]]
  close(c: Conn)                   : Unit
}
```

Sockets TCP a nivel de bytes; los bytes viajan como `[Int]` en
`[0, 255]`. Las operaciones bloqueantes (`connect`, `accept`,
`send`, `recv`) parkean la fibra vía el reactor del runtime, no
el hilo del sistema. `recv_timeout` devuelve `None` si se vence
el plazo.

### `NetUnix`

```kai
effect NetUnix {
  listen(path: String, mode: Int)  : Result[Listener, String]
  connect(path: String)            : Result[Conn, String]
  accept(l: Listener)              : Result[Conn, String]
  send(c: Conn, data: [Int])       : Result[Int, String]
  recv(c: Conn, max: Int)          : Result[[Int], String]
  recv_timeout(c: Conn, max: Int, nanos: Int) : Option[Result[[Int], String]]
  peer_uid(c: Conn)                : Result[Int, String]
  close(c: Conn)                   : Unit
  close_listener(l: Listener)      : Unit
}
```

Sockets de dominio Unix: el hermano local de `NetTcp`, con un
archivo en el lugar del par host y puerto. Se importa desde
`net.unix`. `send`, `recv`, `recv_timeout` y `close` se comportan
igual que en TCP. `listen` crea el archivo del socket con los
permisos de `mode`; como kaikai no tiene literales octales, el
módulo exporta `owner_only` para el `0600` de siempre.
`close_listener` cierra el listener y borra el archivo.

`peer_uid` devuelve el uid efectivo del proceso al otro lado, tal
como lo registró el kernel al conectar. Nada de lo que el par
envíe puede falsificarlo.

### `NetUdp` y `NetDns`

```kai
effect NetUdp {
  bind(host: String, port: Int)                    : Result[UdpSocket, String]
  send(s: UdpSocket, dst: SocketAddr, data: [Int]) : Result[Int, String]
  recv(s: UdpSocket, max: Int) : Result[Pair[SocketAddr, [Int]], String]
  close(s: UdpSocket)                              : Unit
}

effect NetDns {
  resolve(host: String) : Result[[IpAddr], String]
}
```

Mismo estilo que `NetTcp`. El stdlib **no** trae un alias que
agrupe a los efectos de red: solo declara `Console` e `Io`
(§D.9). Si una función usa varios, los sumas en su fila,
`/ NetTcp + NetUdp + NetDns`, o defines el alias tú, en una
línea una vez importados los módulos:

```kai
import net.tcp
import net.udp
import net.dns

type Net = NetTcp + NetUdp + NetDns
```

## D.4 Procesos y señales

### `Process`

```kai
type Child = { pid: Int }
type Exit  = Exited(Int) | Signaled(Int)

effect Process {
  start(cmd: String, args: [String]) : Child
  wait(c: Child)                     : Result[Exit, String]
  kill(c: Child, sig: Int)           : Result[Unit, String]
  exit(code: Int)                    : Nothing
  start_piped(cmd: String, args: [String],
              pipe_stdin: Bool, pipe_stdout: Bool,
              pipe_stderr: Bool)      : Result[Child, String]
  write_stdin(c: Child, data: String) : Result[Unit, String]
  close_stdin(c: Child)               : Result[Unit, String]
  read_stdout(c: Child)               : Result[String, String]
  read_stderr(c: Child)               : Result[String, String]
  start_group(cmd: String, args: [String],
              pipe_stdin: Bool, pipe_stdout: Bool,
              pipe_stderr: Bool)      : Result[Child, String]
  kill_group(c: Child, sig: Int)      : Result[Unit, String]
  uid()                               : Int
}
```

Lanzar y controlar subprocesos. `start` hace fork/exec y
devuelve un `Child` (un handle opaco con el pid); `wait` lo
cosecha y entrega un `Exit`, que distingue explícitamente entre
terminar con un código y morir por una señal. `kill` manda un
signo POSIX crudo.

`exit(code)` termina el **proceso actual** vía `_exit(2)`, así
que los buffers de stdio **no** se vacían: imprime todo lo que
quieras imprimir antes de llamarlo. La operación no resume
(devuelve `Nothing`) y los handlers de `Cancel` no corren. Para
el caso normal, terminar con un código de salida, basta con
devolver un `Int` desde `main` (cap. 16 §16.1), que sí usa el
camino de salida completo de la libc.

`start_piped` es la forma `popen`: conecta pipes al stdin, al
stdout y/o al stderr del hijo, con un flag para cada uno, y desde
ahí `write_stdin`, `close_stdin`, `read_stdout` y `read_stderr`
manejan la conversación. Con stderr en un pipe aparte puedes
distinguir un diagnóstico de la salida; fusionar los dos flujos
no se ofrece, porque una vez fusionados ya no se separan.

`kill` alcanza solo al hijo, no a los procesos que ese hijo lanzó.
Para eso está `start_group`: es `start_piped` con el hijo como
líder de un grupo de procesos nuevo, y `kill_group` le manda la
señal al grupo completo, de modo que una cadena como
`sh -> lanzador -> programa` muere junta. `kill_group` sobre un
hijo que arrancó de otra forma devuelve `Err`. El grupo es
optativo porque un hijo fuera del grupo en primer plano de la
terminal no recibe Ctrl-C y queda detenido si intenta leer de
ella: un paginador o un editor siguen yendo por `start` o
`start_piped`.

`uid()` devuelve el uid efectivo del proceso actual.

### `Signal`

```kai
type Sig = SigInt | SigTerm | SigHup | SigUsr1 | SigUsr2

effect Signal {
  on(sig: Sig)  : Unit
  off(sig: Sig) : Unit
  await()       : Sig
}
```

Esperar a una señal POSIX sin bloquear las demás fibras.
`on(sig)` suscribe el proceso a `sig`; el runtime bloquea
la señal a nivel del proceso y el kernel encola la entrega
en vez de aplicar la disposición por defecto. `await()`
parkea la fibra que llama hasta que llegue cualquiera de
las señales suscritas y devuelve la variante `Sig`
correspondiente. `off(sig)` desuscribe.

El handler default vive alrededor de `main` cuando `Signal`
está en la fila. Solo una fibra puede estar en `await()` a
la vez; un segundo llamado concurrente entra en pánico.
Útil para limpieza ordenada al apagar el proceso:
`Signal.on(SigInt); match Signal.await() { ... }` reemplaza
el típico handler de SIGINT escrito a mano.

## D.5 Estado

### `State[t]`

```kai
effect State[t] {
  get() : t
  set(v: t) : Unit
}
```

El efecto canónico para llevar estado mutable de forma
encapsulada. La sintaxis `var nombre = init` es azúcar sobre
un `handle` de `State[t]` (cap. 12 §12.7).

### `Reader[t]` y `Writer[w]`

```kai
effect Reader[t] {
  ask() : t
}

effect Writer[w] {
  tell(w: w) : Unit
}
```

Entorno de lectura (configuración inmutable) y acumulación de
salida (logging, traza). Patrones clásicos del cálculo de
efectos.

### `Mutable`

```kai
effect Mutable {
  array_make[t](n: Int, init: t)             : Array[t]
  array_length[t](a: Array[t])               : Int
  array_get[t](a: Array[t], i: Int)          : t
  array_set[t](a: Array[t], i: Int, v: t)    : Array[t]
  array_grow[t](a: Array[t], n: Int, init: t) : Array[t]
  ref_make[t](init: t)                       : Ref[t]
  ref_get[t](r: Ref[t])                      : t
  ref_set[t](r: Ref[t], v: t)                : Unit
}
```

El efecto detrás de `Ref[t]` y `Array[t]`. Sigue la
disciplina de **efectos observables** (cap. 12 §12.7): un
`array_set` requiere `Mutable` en la fila solo cuando la
mutación es visible para quien llama. Un array creado local y
devuelto no requiere `Mutable`.

`array_set` y `array_grow` devuelven el `Array[t]` en vez de
`Unit`, sin copiar: devuelven el mismo arreglo para que Perceus
(apéndice B) pueda razonar sobre el último uso y decidir si
mutar en el lugar. Encadenar la operación es idiomático.

## D.6 Errores y control

### `ReadFault`

```kai
effect ReadFault {
  bad_chunk(msg: String)  : Unit      # reanudable: saltar y seguir
  open_fault(msg: String) : Nothing   # solo abortar
}
```

La falla recuperable de las lecturas por streaming, declarada
en `stdlib/stream.kai`. Es el único efecto con forma de falla
que el stdlib declara, y su diseño explica por qué: `bad_chunk`
devuelve `Unit`, así que un handler que reanuda descarta el
chunk malo y continúa (política de salteo), y uno que abandona
la continuación aborta. `open_fault` devuelve `Nothing`: un
stream cuyo origen no abre no tiene a dónde reanudar.

`ReadFault` no trae handler por defecto. Un consumidor que
fuerza el stream tiene que elegir política con `handle ... with
ReadFault`, o el typer reporta `effect not handled: ReadFault`.
El camino de aborto igual libera el handle del productor:
`read_lines` y `write_lines` encierran el archivo en un handler
con `initially` / `finally` (cap. 12 §12.8), así que
`close_file` corre en el desarme aunque la falla salte limpio
sobre el loop de lectura.

### `Cancel`

```kai
effect Cancel {
  raise() : Nothing
}
```

Cancelación cooperativa. El scheduler inyecta `Cancel.raise()`
en una fibra cancelada en el próximo punto de yield. La fibra
puede instalar un handler de `Cancel` para limpieza (cap. 13).

### No hay un efecto `Fail`

kaikai no trae un efecto `Fail`. Toda API que puede fallar
devuelve `Result` y propaga con `!` postfijo: no hay una sola
fila `/ Fail` en el stdlib.

Qué usar, según lo que necesites:

| Necesitas | Usa |
|---|---|
| Falla inspeccionable | `Result[a, e]` con `!` postfijo |
| Falla cuya política elige el consumidor | un efecto de dominio cuya op devuelva `Unit`, para que el handler pueda reanudar y saltear |
| Salida no local profunda | `Cancel.raise() : Nothing` |
| Error de programación | `panic` |

`Fail` sigue siendo un buen ejemplo didáctico de operación que
devuelve `Nothing`, y por eso el capítulo 12 lo declara **local**
en varios ejemplos. Un `effect Fail` declarado por ti no trae
default, así que un `fail` sin manejar es un error de
compilación (`effect not handled: Fail`), no un aborto en
tiempo de ejecución.

### `Emit[t]` y `Yield[t]`

```kai
effect Emit[t] {
  emit(v: t) : Unit
}

effect Yield[t] {
  yield(v: t) : Unit
}
```

Generadores sobre un efecto. Un productor llama `emit` o `yield`
por cada elemento y el handler decide qué hacer con él.
`Emit[t]` es la base de `Stream`: los streams del stdlib son
productores perezosos que recorren un archivo línea por línea
con memoria constante. `Yield[t]` es la base de `gen.generate`,
que convierte al productor en un `Gen` que el consumidor avanza
de a un elemento.

## D.7 Concurrencia

### `Spawn`

```kai
effect Spawn {
  yield()                       : Unit
  spawn[t](thunk: () -> t / e)  : Fiber[t]
  await[t](fiber: Fiber[t])     : t
  select[t](fibers: [Fiber[t]]) : t
  cancel[t](fiber: Fiber[t])    : Unit
  set_trap_exit(on: Bool)       : Unit
  scope_enter()                 : Unit
  scope_exit()                  : Unit
}
```

Crear fibras, esperarlas, racear, ceder, cancelar.
`nursery { n -> ... }` del cap. 13 es azúcar sobre
`handle ... with Spawn as n { ... }`, y las dos últimas
operaciones son la maquinaria detrás de esa azúcar:
`scope_enter` y `scope_exit` delimitan el alcance que hace el
*join* de las hijas. `set_trap_exit` decide si la fibra recibe
la caída de un peer enlazado como mensaje en vez de morir con
él (cap. 14 §14.6).

### `Actor[msg]`

```kai
effect Actor[msg] {
  self()                       : Pid[msg]
  send[t](pid: Pid[t], msg: t) : Unit
  receive()                    : msg
  receive_timeout(nanos: Int)  : Option[msg]
}
```

El efecto que da forma al modelo de actores del cap. 14.
`with_mailbox { ... }` y `spawn_actor(...)` son los wrappers
del stdlib que instalan este handler. `send` toma el tipo del
mensaje del `Pid` de destino, no del buzón propio: con un
buzón de `Resp` puedes enviarle un `Req` a un `Pid[Req]`.
`receive_timeout`
devuelve `None` si no llegó nada en el plazo, y así evita que
un actor quede colgado esperando un mensaje que no
va a llegar.

### `Link` y `Monitor`

```kai
effect Link {
  link(peer: Pid[Nothing]) : Unit
}

effect Monitor {
  monitor(target: Pid[Nothing]) : Pid[Nothing]
  demonitor(ref: Pid[Nothing])  : Unit
}
```

Supervisión al estilo BEAM (cap. 14 §14.6). Links son
bidireccionales: si uno cae, el otro recibe `Cancel.raise()`.
Monitores son unidireccionales: el observador recibe un
mensaje `MonitorDown` cuando el observado termina.

## D.8 Interoperabilidad

### `Ffi`

```kai
effect Ffi {}
```

El efecto que cargan todas las funciones declaradas con
`extern "C" fn`. Sin operaciones propias: es un marcador
para que el sistema de tipos sepa qué funciones tocan
código no auditado por kaikai. El capítulo 16 §16.12
cubre la sintaxis de declaración, el mapeo de tipos en el
borde, el enlazado con shims C, y qué soporta y qué no
FFI v1.

### `Js`

```kai
effect Js {}
```

El marcador que cargan las firmas `extern "js"`, como `Ffi` para
`extern "C"`. No tiene operaciones ni handler por defecto: un
programa cuyo `main` lo alcanza solo compila para un target con
un host JavaScript (apéndice G).

### `Dom`, `Fetch`, `Storage` y `Timer`

```kai
effect Dom {
  query(selector: String) : Option[Node]
  create(tag: String) : Node
  append(parent: Node, child: Node) : Unit
  remove(n: Node) : Unit
  set_text(n: Node, text: String) : Unit
  set_attr(n: Node, name: String, value: String) : Unit
  set_style(n: Node, name: String, value: String) : Unit
  listen(n: Node, kind: String) : Unit
  next_event() : Event
  poll_event() : Option[Event]
  context_2d(canvas: Node) : Ctx2d
  set_fill_style(c: Ctx2d, css: String) : Unit
  set_stroke_style(c: Ctx2d, css: String) : Unit
  set_font(c: Ctx2d, css: String) : Unit
  fill_rect(c: Ctx2d, x: Int, y: Int, w: Int, h: Int) : Unit
  clear_rect(c: Ctx2d, x: Int, y: Int, w: Int, h: Int) : Unit
  begin_path(c: Ctx2d) : Unit
  arc(c: Ctx2d, x: Real, y: Real, r: Real, from: Real, to: Real) : Unit
  fill(c: Ctx2d) : Unit
  stroke(c: Ctx2d) : Unit
  fill_text(c: Ctx2d, text: String, x: Int, y: Int) : Unit
  new_image(w: Int, h: Int) : Image
  set_pixel(img: Image, index: Int, pixel: Int) : Unit
  put_image_data(c: Ctx2d, img: Image, x: Int, y: Int) : Unit
  put_pixels(c: Ctx2d, rgba: Array[Byte], w: Int, h: Int, x: Int, y: Int) : Unit
  get_image_data(c: Ctx2d, x: Int, y: Int, w: Int, h: Int) : Image
  get_pixel(img: Image, index: Int) : Int
}

effect Fetch {
  get(url: String) : Response
}

effect Storage {
  get(key: String) : Option[String]
  set(key: String, value: String) : Unit
  remove(key: String) : Unit
}

effect Timer {
  now_ms() : Int
  sleep_ms(ms: Int) : Unit
  animation_frame() : Real
  every(ms: Int, kind: String) : Unit
}
```

La página web vista como efectos, para el target WebAssembly.
`Dom` consulta y construye nodos, dibuja en un canvas 2D y
entrega los eventos como valores: `listen` le pide al host que
encole eventos de un tipo y `next_event` estaciona la fibra
hasta que llega uno, así que nada en JavaScript llama de vuelta
al programa. `Fetch` hace requests HTTP desde la página,
`Storage` es el `localStorage` y `Timer` da el reloj, las
esperas, los cuadros de animación y los ticks periódicos.
Ninguno tiene handler por defecto: los instala `web.run`
(apéndice G).

## D.9 Composición: los alias `Console` e `Io`

```kai
type Console = Stdout + Stderr + Stdin
type Io      = Console + Env + File
```

Dos niveles de agrupación. `Console` junta los tres flujos
estándar; `Io` le suma el entorno y los archivos. Una función
que dice `/ Io` declara que puede tocar consola, leer variables
de entorno y manipular archivos: el equivalente a "esta función
no es pura, hace cosas con el sistema".

Fíjate en quiénes **no** están en `Io`: `Clock`, `Random`,
`SecureRandom`, los efectos de red y `Process` quedan fuera a
propósito. Una función que "logguea y lee configuración" no
debería ganar en silencio la capacidad de salir a la red o de
lanzar subprocesos solo porque ambas cosas viven bajo un nombre
cómodo. Esos efectos aparecen explícitos en la firma o no
aparecen.

## D.10 Handlers por defecto

Cuando `main` declara uno de estos efectos en su fila, el
runtime instala automáticamente un handler por defecto:

- `Stdout`, `Stderr`, `Stdin`, `Env`, `File` → IO al sistema.
- `Clock`, `Random`, `SecureRandom` → reloj y RNG del sistema.
- `NetTcp`, `NetUnix`, `NetUdp`, `NetDns` → POSIX sockets.
- `Process`, `Signal` → llamadas POSIX.
- `Log` → cada mensaje a stderr como `[ISO8601Z] NIVEL mensaje`.
- `Mutable` → asignaciones reales en heap.
- `Spawn`, `Cancel` → el scheduler de fibras del runtime.

Los efectos de la página (`Dom`, `Fetch`, `Storage`, `Timer`) no
están en esta lista: los instala `web.run`, no el runtime.

Estos handlers se pueden interceptar: cualquier `handle ...
with X { ... }` que instales gana sobre el handler del runtime
en todo el bloque del `body`. Así haces mocking en tests,
capturas la salida o simulas el reloj.
