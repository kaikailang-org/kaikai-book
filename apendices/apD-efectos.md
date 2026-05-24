# Apéndice D · Catálogo de efectos del stdlib

Este apéndice resume los efectos que el stdlib expone. Es
material de referencia: ante una firma `: Unit / X` en la
documentación de una función, vienes acá a confirmar qué
provee `X`.

La especificación completa vive en
`github.com/kaikailang-org/kaikai/docs/effects-stdlib.md`. Acá
mostramos la declaración del efecto y para qué sirve.

## D.1 IO básico

### `Console`

```kai
effect Console {
  print(s: String)  : Unit
  eprint(s: String) : Unit
}
```

Imprimir a stdout y stderr. Cada operación agrega un newline.
El handler por defecto del runtime escribe al descriptor de
archivo correspondiente.

### `Stdin`

```kai
effect Stdin {
  read_line() : Result[String, String]
}
```

Leer una línea de entrada estándar. Devuelve `Err(motivo)` en
caso de EOF o error de lectura.

### `Env`

```kai
effect Env {
  get(name: String) : Option[String]
  args()            : [String]
}
```

Acceso a variables de entorno (`PATH`, `HOME`, etc.) y a los
argumentos de línea de comando (`argv`).

### `File`

```kai
effect File {
  read_file(path: String)                  : Result[String, String]
  write_file(path: String, content: String): Result[Unit, String]
  append(path: String, content: String)    : Result[Unit, String]
  exists(path: String)                     : Bool
  delete(path: String)                     : Result[String, Unit]
  rename(from: String, to: String)         : Result[String, Unit]
}
```

Operaciones sobre archivos. Para todo lo que sea no-trivial
(streams, directorios, permisos), ver `fs.dir` y los módulos
auxiliares.

## D.2 Tiempo y aleatoriedad

### `Clock`

```kai
effect Clock {
  now()              : Int          # nanosegundos desde epoch
  sleep(ms: Int)     : Unit / Cancel
}
```

Reloj y sleep. `sleep` es punto de yield (carga `Cancel`).

### `Random`

```kai
effect Random {
  int(min: Int, max: Int)   : Int
  real()                    : Real
  shuffle[a](xs: [a])       : [a]
}
```

Generación pseudo-aleatoria, no apta para criptografía. Para
secretos, ver `SecureRandom`.

### `SecureRandom`

```kai
effect SecureRandom {
  bytes(n: Int) : [Byte]
}
```

Bytes aleatorios criptográficamente seguros (vía
`/dev/urandom` o equivalente del sistema).

## D.3 Red

### `NetTcp`

```kai
effect NetTcp {
  connect(host: String, port: Int)   : Result[Conn, String]
  listen(host: String, port: Int)    : Result[Listener, String]
  accept(l: Listener)                : Result[Conn, String]
  send(c: Conn, data: [Byte])        : Result[Int, String]
  recv(c: Conn, max: Int)            : Result[[Byte], String]
  close(c: Conn)                     : Unit
}
```

Sockets TCP byte-level. Las operaciones bloqueantes (`connect`,
`accept`, `send`, `recv`) suspenden la fibra vía el reactor
del runtime cuando aterrice (v1 las hace bloqueantes al OS
thread).

### `NetUdp` y `NetDns`

UDP (`bind`/`send`/`recv`/`close`) y DNS (`resolve`). Mismo
estilo que `NetTcp`. El alias `Net = NetTcp + NetUdp + NetDns`
es útil cuando una función usa los tres.

## D.4 Procesos y señales

### `Process`

```kai
effect Process {
  run(cmd: String, args: [String]) : Result[ProcessResult, String]
  pid()                            : Int
}
```

Ejecutar comandos externos como subprocesos.
`ProcessResult` contiene `exit_code`, `stdout` y `stderr`.

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
Útil para limpieza ordenada al apagar el proceso —
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
  ref_make[T](init: T)      : Ref[T]
  ref_get[T](r: Ref[T])     : T
  ref_set[T](r: Ref[T], v: T): Unit
  array_make[T](n: Int, init: T) : Array[T]
  array_length[T](a: Array[T])   : Int
  array_get[T](a: Array[T], i: Int)        : T
  array_set[T](a: Array[T], i: Int, v: T)  : Unit
  array_grow[T](a: Array[T], n: Int, init: T): Unit
}
```

El efecto detrás de `Ref[T]` y `Array[T]`. Sigue la
disciplina de **efectos observables** (cap. 12 §12.7): un
`array_set` requiere `Mutable` en la fila solo cuando la
mutación es visible para quien llama. Un array creado local y
devuelto no requiere `Mutable`.

## D.6 Errores y control

### `Fail`

```kai
effect Fail {
  fail(msg: String) : Nothing
}
```

Abortar con un mensaje. La operación devuelve `Nothing` (el
tipo vacío), así que el sistema de tipos garantiza que no se
puede llamar a `resume` después de `Fail.fail`. Es el patrón
canónico para "excepción ligera" en kaikai.

### `Cancel`

```kai
effect Cancel {
  raise() : Nothing
}
```

Cancelación cooperativa. El scheduler inyecta `Cancel.raise()`
en una fibra cancelada en el próximo punto de yield. La fibra
puede instalar un handler de `Cancel` para limpieza (cap. 13).

## D.7 Concurrencia

### `Spawn`

```kai
effect Spawn {
  spawn[T, e](f: () -> T / e) : Fiber[T]
  await[T](f: Fiber[T])       : T
  select[T](fs: [Fiber[T]])   : T
  yield()                     : Unit
  cancel[T](f: Fiber[T])      : Unit
}
```

Crear fibras, esperarlas, racear, ceder, cancelar.
`nursery { n -> ... }` del cap. 13 es azúcar sobre
`handle ... with Spawn as n { ... }`.

### `Actor[Msg]`

```kai
effect Actor[Msg] {
  self()                         : Pid[Msg]
  send(pid: Pid[Msg], msg: Msg)  : Unit / Cancel
  receive()                      : Msg / Cancel
}
```

El efecto que da forma al modelo de actores del cap. 14.
`with_mailbox { ... }` y `spawn_actor(...)` son los wrappers
del stdlib que instalan este handler.

### `Link` y `Monitor`

```kai
effect Link {
  link(pid: Pid[_]) : Unit
}

effect Monitor {
  monitor(pid: Pid[_])         : MonitorRef
  demonitor(ref: MonitorRef)   : Unit
}
```

Supervisión al estilo BEAM (cap. 14 §14.6). Links son
bidireccionales: si uno cae, el otro recibe `Cancel.raise()`.
Monitores son unidireccionales: el observador recibe un
mensaje `MonitorDown` cuando el observado termina.

## D.8 Interoperabilidad

### `Ffi`

```kai
effect Ffi
```

El efecto que cargan todas las funciones declaradas con
`extern "C" fn`. Sin operaciones propias: es un marcador
para que el sistema de tipos sepa qué funciones tocan
código no auditado por kaikai. El capítulo 16 §16.9
cubre la sintaxis de declaración, el mapeo de tipos en el
borde, el enlazado con shims C, y qué soporta y qué no
FFI v1.

## D.9 Composición: el alias `Io`

```kai
type Io = Console + Stdin + Env + File
```

Bundle de los efectos más comunes para IO al sistema
operativo. Una función que dice `/ Io` está declarando que
puede tocar consola, leer stdin, leer variables de entorno y
manipular archivos. Es el equivalente a "esta función no es
pura, hace cosas con el sistema".

## D.10 Handlers por defecto

Cuando `main` declara uno de estos efectos en su fila, el
runtime instala automáticamente un handler por defecto:

- `Console`, `Stdin`, `Env`, `File` → IO al sistema.
- `Clock`, `Random`, `SecureRandom` → reloj y RNG del sistema.
- `NetTcp`, `NetUdp`, `NetDns` → POSIX sockets.
- `Process`, `Signal` → llamadas POSIX.
- `Mutable` → asignaciones reales en heap.
- `Spawn`, `Cancel` → el scheduler de fibras del runtime.

Estos handlers se pueden interceptar: cualquier `handle ...
with X { ... }` que el usuario instale gana sobre el handler
del runtime para todo el bloque del `body`. Eso es lo que
permite mocking en tests, capturar la salida, simular el
reloj, etc.
