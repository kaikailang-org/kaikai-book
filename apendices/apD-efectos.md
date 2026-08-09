# Apéndice D · Catálogo de efectos del stdlib

Este apéndice resume los efectos que el stdlib expone. Es
material de referencia: ante una firma `: Unit / X` en la
documentación de una función, vienes acá a confirmar qué
provee `X`.

La especificación completa vive en
`github.com/kaikailang-org/kaikai/docs/effects-stdlib.md`. Acá
mostramos la declaración del efecto y para qué sirve.

## D.1 IO básico

### `Stdout`, `Stderr` y `Stdin`

Los tres flujos estándar son efectos separados, uno por
descriptor. Esa granularidad es lo que le permite a un arnés de
tests capturar stdout sin tocar lo que se escribe a stderr.

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
entero de una vez, que es lo que quieres la mayoría de las
veces. El resto es la ruta por chunks para archivos que no
caben o que no quieres cargar completos.

Fíjate en el `<...>` de los handles: `FileHandle<read>` y
`FileHandle<read + write>` llevan la capacidad **en el tipo**.
Un handle abierto para lectura no tipa donde se espera
`FileHandle<write>`, y eso lo decide el compilador, no un
chequeo en runtime. Es el kind `Perm` del cap. 19 §19.9
haciendo su trabajo. Lo que el tipo declara es lo que el código
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

Una nota para quien venga del capítulo 12: ahí declaramos un
`effect Log { log(msg: String) : Unit }` propio, más chico,
para enseñar el mecanismo. No hay conflicto: una declaración
local hace *shadowing* del nombre del stdlib dentro de su
archivo. Si quieres el de cuatro niveles, no lo declares.

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
handler por defecto**. Sin uno instalado el programa ni
siquiera compila, porque el nombre no está en alcance. El
módulo trae dos:

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
reloj y el pid del proceso. Los helpers de más alto nivel viven
en el módulo `Random`, construidos sobre esta op. No sirve para
criptografía.

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
agrupe a los tres: los únicos que declara son `Console` e `Io`
(§D.9). Una función que use los tres los suma en su fila,
`/ NetTcp + NetUdp + NetDns`, o defines el alias tú, que es una
línea una vez importados los tres módulos:

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
              pipe_stdin: Bool, pipe_stdout: Bool) : Result[Child, String]
  write_stdin(c: Child, data: String) : Result[Unit, String]
  close_stdin(c: Child)               : Result[Unit, String]
  read_stdout(c: Child)               : Result[String, String]
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

`start_piped` es la forma `popen`: conecta pipes al stdin y/o al
stdout del hijo, y desde ahí `write_stdin`, `close_stdin` y
`read_stdout` manejan la conversación.

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
`on(sig)` subscribe el proceso a `sig`; el runtime bloquea
la señal a nivel del proceso y el kernel encola la entrega
en vez de aplicar la disposición por defecto. `await()`
parkea la fibra que llama hasta que llegue cualquiera de
las señales subscritas y devuelve la variante `Sig`
correspondiente. `off(sig)` desuscribe.

El handler default vive alrededor de `main` cuando `Signal`
está en la fila. Solo una fibra puede estar en `await()` a
la vez; un segundo llamado concurrente entra en pánico.
Útil para limpieza ordenada al apagar el proceso:
`Signal.on(SigInt); match Signal.await() { ... }` reemplaza
el típico handler de SIGINT escrito a mano.

## D.5 Estado

### `State[T]`

```kai
effect State[T] {
  get() : T
  set(v: T) : Unit
}
```

El efecto canónico para llevar estado mutable de forma
encapsulada. La sintaxis `var nombre = init` es azúcar sobre
un `handle` de `State[T]` (cap. 12 §12.7).

### `Reader[T]` y `Writer[W]`

```kai
effect Reader[T] {
  ask() : T
}

effect Writer[W] {
  tell(w: W) : Unit
}
```

Entorno de lectura (configuración inmutable) y acumulación de
salida (logging, traza). Patrones clásicos del cálculo de
efectos.

### `Mutable`

```kai
effect Mutable {
  array_make[T](n: Int, init: T)             : Array[T]
  array_length[T](a: Array[T])               : Int
  array_get[T](a: Array[T], i: Int)          : T
  array_set[T](a: Array[T], i: Int, v: T)    : Array[T]
  array_grow[T](a: Array[T], n: Int, init: T) : Array[T]
  ref_make[T](init: T)                       : Ref[T]
  ref_get[T](r: Ref[T])                      : T
  ref_set[T](r: Ref[T], v: T)                : Unit
}
```

El efecto detrás de `Ref[T]` y `Array[T]`. Sigue la
disciplina de **efectos observables** (cap. 12 §12.7): un
`array_set` requiere `Mutable` en la fila solo cuando la
mutación es visible para quien llama. Un array creado local y
devuelto no requiere `Mutable`.

`array_set` y `array_grow` devuelven el `Array[T]` en vez de
`Unit`. No es que copien: devuelven el mismo arreglo para que
Perceus (apéndice B) pueda razonar sobre el último uso y decidir
si mutar en el lugar. Encadenar la operación es idiomático.

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

### `Fail`: retirado del stdlib

`Fail` fue un efecto del stdlib (`fail(msg: String) : Nothing`)
con handler por defecto que imprimía un banner y salía con
código 1. **Desde kaikai 0.106 ya no está.** El retiro ratifica
lo que el stdlib ya practicaba: toda API que puede fallar
devuelve `Result` y propaga con `!` postfijo. No quedaba una
sola fila `/ Fail` en el stdlib.

Qué usar en su lugar, según qué necesitas:

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
compilación (`effect not handled: Fail`) y no un aborto en
tiempo de ejecución. Esa es toda la diferencia práctica.

## D.7 Concurrencia

### `Spawn`

```kai
effect Spawn {
  yield()                       : Unit
  spawn[T](thunk: () -> T / e)  : Fiber[T]
  await[T](fiber: Fiber[T])     : T
  select[T](fibers: [Fiber[T]]) : T
  cancel[T](fiber: Fiber[T])    : Unit
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

### `Actor[Msg]`

```kai
effect Actor[Msg] {
  self()                        : Pid[Msg]
  send(pid: Pid[Msg], msg: Msg) : Unit
  receive()                     : Msg
  receive_timeout(nanos: Int)   : Option[Msg]
}
```

El efecto que da forma al modelo de actores del cap. 14.
`with_mailbox { ... }` y `spawn_actor(...)` son los wrappers
del stdlib que instalan este handler. `receive_timeout`
devuelve `None` si no llegó nada en el plazo, que es lo que
evita que un actor quede colgado esperando un mensaje que no
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

## D.9 Composición: los alias `Console` e `Io`

```kai
type Console = Stdout + Stderr + Stdin
type Io      = Console + Env + File
```

Dos niveles de agrupación. `Console` junta los tres flujos
estándar; `Io` le suma el entorno y los archivos. Una función
que dice `/ Io` está declarando que puede tocar consola, leer
variables de entorno y manipular archivos: el equivalente a
"esta función no es pura, hace cosas con el sistema".

Fíjate en quiénes **no** están en `Io`: `Clock`, `Random`,
`SecureRandom`, los tres efectos de red y `Process` quedan fuera a
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
- `NetTcp`, `NetUdp`, `NetDns` → POSIX sockets.
- `Process`, `Signal` → llamadas POSIX.
- `Log` → cada mensaje a stderr como `[ISO8601Z] NIVEL mensaje`.
- `Mutable` → asignaciones reales en heap.
- `Spawn`, `Cancel` → el scheduler de fibras del runtime.

Estos handlers se pueden interceptar: cualquier `handle ...
with X { ... }` que el usuario instale gana sobre el handler
del runtime para todo el bloque del `body`. Eso es lo que
permite mocking en tests, capturar la salida, simular el
reloj, etc.
