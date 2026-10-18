# Capítulo 17 · Caso de estudio: servidor HTTP

Este es el primero de dos casos de estudio que cierran el
libro. En él ves cómo las piezas de los capítulos anteriores
encajan en algo que se parece a software real. Desconfío de los
libros de lenguajes que nunca salen del ejemplo de juguete, así
que quise cerrar este con dos programas que podrían estar en
producción.

Este capítulo cubre **un servidor HTTP**, la familia de
problemas donde pesan la concurrencia, la modularidad y la
separación entre lógica de dominio e IO. El capítulo 18 cubre
el otro extremo de la industria, **un libro mayor contable**,
donde pesan los tipos precisos (monedas con unidades), las
invariantes de negocio (contratos `requires`/`ensures`) y la
inmutabilidad estricta.

El programa es un **servidor HTTP de notas**. Tiene una
interfaz HTTP simple (`GET /notas`, `POST /notas`,
`GET /notas/<id>`, `DELETE /notas/<id>`), mantiene las notas
en memoria y escribe cada cambio a un archivo de log. La
lógica es simple; lo interesante es cómo se arma: efectos en
las firmas, actores para encapsular estado, fibras para servir
conexiones concurrentes, módulos para separar dominio, parser
HTTP, almacenamiento, persistencia.

Son unas 250 líneas, repartidas en cinco archivos.

## 17.1 La forma del programa

Antes de leer el código, ubica las piezas y sus responsabilidades:

```
notas/
├── kai.toml             # manifest del proyecto
├── main.kai             # punto de entrada y bucle de accept
├── dominio.kai          # tipos: Nota, Comando, Respuesta
├── almacen.kai          # actor que guarda las notas
├── persistencia.kai     # actor que escribe el log a disco
└── web.kai              # parser y serializador HTTP mínimos
```

Cada archivo carga con una preocupación distinta:

- **`dominio.kai`** es el centro. Tipos puros, sin efectos, sin
  IO: qué es una nota, qué comandos se pueden ejecutar, qué
  respuestas se pueden producir.
- **`almacen.kai`** es un actor. Recibe comandos, mantiene la
  lista de notas como estado interno y responde al que
  pregunta. Por dentro la lógica es pura (función `procesar`),
  envuelta en un bucle `Actor.receive()` que la conecta al
  mundo.
- **`persistencia.kai`** es otro actor. Recibe eventos
  (creación, borrado) y los escribe a un archivo de log. Con el
  disco aislado en un actor, el almacén sigue respondiendo
  aunque la escritura sea lenta.
- **`web.kai`** son funciones puras: parsear bytes HTTP en una
  estructura `ReqHttp`, traducir requests en comandos de
  dominio, serializar respuestas a bytes. Sin actores, sin IO.
- **`main.kai`** arma todo: arranca los actores, levanta el
  socket TCP, abre un nursery, y por cada conexión nueva lanza
  una fibra que la maneja.

Esta separación es la forma natural en kaikai. Pruebas la
lógica del dominio sin arrancar fibras, el parser HTTP sin
abrir sockets, el almacén sin tocar el disco. El `main` solo
conecta las piezas.

![Figura 17.1](../figuras/fig17-1-notes-server-es.png)

Figura 17.1 · *Arquitectura del servidor de notas. Cinco
módulos, dos actores (almacén y persistencia), una fibra
por conexión entrante. Los módulos puros (`dominio.kai`,
`web.kai`, cluster verde) no tienen efectos; los módulos
con estado (`almacen.kai`, `persistencia.kai`, cluster
rojo) esconden su mutación detrás de un mailbox; `main.kai`
es pegamento.*

## 17.2 El dominio: tipos puros

Empezamos por el centro. `dominio.kai`:

```kai
#[derive(Show)]
pub type Nota = { id: Int, cuerpo: String }

pub type Comando
  = Listar
  | Obtener(Int)
  | Crear(String)
  | Borrar(Int)

pub type Respuesta
  = Guardado(String)
  | Creado(Nota)
  | NoEncontrado
  | ErrorCliente(String)
  | ErrorServidor(String)
```

Tres declaraciones. Una nota tiene id y cuerpo. Hay cuatro
comandos contra el dominio (listar, obtener uno, crear,
borrar) y cinco respuestas posibles, que mapean
conceptualmente a los códigos HTTP 200, 201, 404, 400 y 500.

En este archivo **no** hay HTTP, ni fibras, ni archivos. Si un
día expones la API por gRPC en vez de HTTP, o cambias el
almacenamiento de memoria a SQLite, este archivo no cambia. Es
el invariante del programa.

El `#[derive(Show)]` sobre `Nota` te deja interpolar `#{nota}`
en un string (cap. 9). Sin él, escribirías un
`impl Show for Nota` a mano.

## 17.3 El almacén: actor con estado

`almacen.kai` define un actor que mantiene la lista de notas y
responde comandos. Su tipo de mensaje es el comando más el
`Pid` para responder:

```kai
import dominio

pub type AlmacenMsg = Pregunta(dominio.Comando, Pid[AlmacenResp])
pub type AlmacenResp = Respondido(dominio.Respuesta)
```

`AlmacenMsg` es lo que el almacén recibe; `AlmacenResp` es lo
que devuelve. El cliente abre su propio mailbox con
`with_mailbox`, mete el `Pid` en el mensaje y espera la
respuesta: el patrón request/reply del §14.5.

El corazón del módulo es la **lógica pura** de procesamiento:

```kai
pub fn procesar(c: dominio.Comando, notas: [dominio.Nota], next_id: Int)
    : (dominio.Respuesta, [dominio.Nota], Int) {
  match c {
    Listar -> {
      let cuerpos = list.map(notas, .cuerpo)
      (dominio.Guardado(serializar_lista(cuerpos)), notas, next_id)
    }
    Obtener(id) ->
      match buscar(notas, id) {
        Some(n) -> (dominio.Guardado(n.cuerpo), notas, next_id)
        None    -> (dominio.NoEncontrado, notas, next_id)
      }
    Crear(cuerpo) -> {
      let nueva = dominio.Nota { id: next_id, cuerpo: cuerpo }
      (dominio.Creado(nueva), [nueva, ...notas], next_id + 1)
    }
    Borrar(id) ->
      match buscar(notas, id) {
        Some(_) -> {
          let restantes = list.filter(notas, (n) => n.id != id)
          (dominio.Guardado("borrada"), restantes, next_id)
        }
        None -> (dominio.NoEncontrado, notas, next_id)
      }
  }
}
```

Una sola función, sin efectos en su firma. Recibe el comando,
las notas actuales y el próximo id; devuelve la respuesta, la
nueva lista de notas y el nuevo próximo id. Pattern match
exhaustivo sobre las cuatro variantes de `Comando`, listas
construidas con `[h, ...tail]`, `list.map` y `list.filter`:
nada nuevo, son las construcciones de los caps. 5 (sum types y
match) y 6 (funciones y pipelines) puestas a trabajar.

Como `procesar` es pura, la pruebas **directamente**:

```kai
test "crear y obtener" {
  let (r1, n1, id1) = procesar(dominio.Crear("primera"), [], 1)
  let creado_ok = match r1 {
    dominio.Creado(_) -> true
    _                  -> false
  }
  assert creado_ok
  assert id1 == 2

  let (r2, _, _) = procesar(dominio.Obtener(1), n1, id1)
  let obtener_ok = match r2 {
    dominio.Guardado(c) -> c == "primera"
    _              -> false
  }
  assert obtener_ok
}
```

No hay fibras ni IO ni sockets: solo lógica. Si mañana quieres
paralelizar la creación de notas, agregar índices o cambiar el
algoritmo de búsqueda, el cambio pasa por esta función pura y
se prueba aquí.

Encima de `procesar` viene el **bucle del actor**, que la
conecta a `Actor.receive()`:

```kai
pub fn almacen_loop(notas: [dominio.Nota], next_id: Int) : Unit / Actor[AlmacenMsg] + Actor[AlmacenResp] {
  match Actor.receive() {
    Pregunta(comando, cliente) -> {
      let (resp, notas_nuevas, id_nuevo) = procesar(comando, notas, next_id)
      Actor.send(cliente, Respondido(resp))
      almacen_loop(notas_nuevas, id_nuevo)
    }
  }
}
```

Tres líneas de trabajo:

1. Recibe una pregunta.
2. Procesa (lógica pura).
3. Responde y recursa con el estado nuevo.

La recursión por cola se compila a un loop (cap. 6), así que el
actor puede correr indefinidamente. La firma declara los dos
efectos del actor: `Actor[AlmacenMsg]` para recibir,
`Actor[AlmacenResp]` para responder.

El módulo no trae un helper que arranque el actor; de eso se
encarga el `main` con `spawn_actor` (§17.6). Lo que sí exporta
es un wrapper sincrónico para clientes:

```kai
pub fn preguntar(almacen: Pid[AlmacenMsg], c: dominio.Comando)
    : dominio.Respuesta / Actor[AlmacenMsg] + Actor[AlmacenResp] + Cancel {
  Actor.send(almacen, Pregunta(c, Actor.self()))
  match Actor.receive() {
    Respondido(r) -> r
  }
}
```

Los handlers HTTP del `main` llaman a `preguntar`: "hazle esta
pregunta al almacén y dame la respuesta". Por adentro es un
send seguido de un receive, expuesto como una función simple y
no como un protocolo abierto.

## 17.4 Persistencia: actor de escritura

`persistencia.kai` es más simple: un actor que recibe líneas de
log y las agrega a un archivo:

```kai
import fs.file

pub type Evento = Linea(String)

pub fn persistencia_loop(path: String) : Unit / Actor[Evento] + File {
  match Actor.receive() {
    Linea(s) -> {
      file.append(path, s ++ "\n")
      persistencia_loop(path)
    }
  }
}

pub fn reset_log(path: String) : Unit / File {
  file.write(path, "")
}
```

Aislar la escritura en su propio actor tiene dos beneficios:

- **El almacén no espera al disco.** Al procesar un `Crear`,
  manda un mensaje al actor de persistencia y vuelve a su
  trabajo. La escritura ocurre en otra fibra.
- **El orden de las escrituras está garantizado.** Todos los
  eventos pasan por el mismo mailbox, que se procesa en orden
  FIFO. No hay races aunque varios handlers escriban al log a
  la vez.

En un sistema real, este actor tendría un mailbox `Bounded(N,
DropOldest)` para protegerse de inundación. Aquí uso el
mailbox predeterminado (Unbounded) para simplificar el demo.
La decisión es explícita y vive en una sola línea, fácil de
cambiar.

## 17.5 Parser HTTP

`web.kai` es código puro de string manipulation. La pieza
central es `enrutar`, que traduce un request HTTP en un
comando del dominio:

```kai
pub fn enrutar(req: ReqHttp) : Result[dominio.Comando, dominio.Respuesta] {
  if req.metodo == "GET" {
    if req.path == "/notas" {
      Ok(dominio.Listar)
    } else {
      enrutar_id(req.path, (id) => dominio.Obtener(id))
    }
  } else if req.metodo == "POST" {
    if req.path == "/notas" {
      Ok(dominio.Crear(req.cuerpo))
    } else {
      Err(dominio.NoEncontrado)
    }
  } else if req.metodo == "DELETE" {
    enrutar_id(req.path, (id) => dominio.Borrar(id))
  } else {
    Err(dominio.NoEncontrado)
  }
}
```

El tipo de retorno usa `Result` de forma poco ortodoxa: `Ok`
contiene un comando para ejecutar; `Err`, una respuesta
inmediata (404, 400). La firma queda compacta: o el request se
traduce a un comando válido, o ya tienes la respuesta.

Completan el módulo un parser de la primera línea HTTP
(`GET /path HTTP/1.1`) y un serializador que produce los bytes
de respuesta. Son funciones puras, que pruebas con strings de
entrada y comparación de salida.

## 17.6 El main: armar todas las piezas

`main.kai` es el pegamento:

```kai
import actor
import spawn
import loop
import net.tcp
import dominio
import almacen
import persistencia
import web

const PUERTO: Int = 8080
const PATH_LOG: String = "notas.log"

fn main() : Int / Stdout + NetTcp + File + Spawn + Cancel {
  with_mailbox {
    with_mailbox {
      persistencia.reset_log(PATH_LOG)
      nursery { n ->
        let almacen_body: () -> Unit / Actor[almacen.AlmacenMsg] + Actor[almacen.AlmacenResp] = () => almacen.almacen_loop([], 1)
        let log_body:     () -> Unit / Actor[persistencia.Evento] + File = () => persistencia.persistencia_loop(PATH_LOG)
        let almacen_pid = spawn_actor(almacen_body)
        let log_pid     = spawn_actor(log_body)
        match NetTcp.listen("0.0.0.0", PUERTO) {
          Err(msg) -> println("error al arrancar el servidor: " ++ msg)
          Ok(listener) -> {
            println("servidor escuchando en puerto #{PUERTO}")
            forever(() => match NetTcp.accept(listener) {
              Err(_)   -> ()
              Ok(conn) -> {
                let _ = n.spawn(() => with_mailbox(() => atender_conexion(conn, almacen_pid, log_pid)))
                ()
              }
            })
          }
        }
      }
    }
  }
  0
}
```

Leído de afuera hacia adentro:

1. Los dos `with_mailbox` anidados le dan a `main` los buzones
   que necesita para hablarle al almacén y al persistor. De paso
   son la razón de que la firma no liste ningún `Actor[X]`: un
   efecto manejado deja de estar en la fila.
2. `reset_log` deja el archivo de auditoría en blanco.
3. El `nursery` abre el scope donde van a vivir las fibras hijas.
4. `spawn_actor` levanta los dos actores, cada uno con su cuerpo
   declarado con tipo explícito.
5. `NetTcp.listen` abre el socket y `forever` entra al bucle de
   aceptación.

La fila de efectos del `main` lista lo que el programa deja
vivo al salir: `Stdout` para imprimir, `NetTcp` para sockets,
`File` para escribir, `Spawn + Cancel` para fibras. Si el
`main` hiciera más cosas, su fila crecería.

El bucle de aceptación lanza una fibra por cada conexión
nueva. Ojo: `n` no es un valor de tipo `Nursery` que pueda
viajar a otra función: el compilador
reescribe cada `n.spawn(...)` en `Spawn.spawn(...)`
etiquetado con el brand de *este* nursery, así que el `spawn`
tiene que aparecer léxicamente dentro del bloque. Por eso el
bucle accept va inline:

```kai
nursery { n ->
  forever(() => match NetTcp.accept(listener) {
    Err(_)   -> ()
    Ok(conn) -> {
      let _ = n.spawn(() => with_mailbox(() => atender_conexion(conn, almacen_pid, log_pid)))
      ()
    }
  })
}
```

Cada conexión vive en su propia fibra. El nursery garantiza
que cuando el bucle termine (porque alguien cancela el
listener, o el programa recibe SIGINT), las fibras hijas
también terminan. No hay handlers de conexión zombies.

### Apagado ordenado: atrapar la señal

Ese "o el programa recibe SIGINT" separa un servidor de
juguete de uno que puedes dejar corriendo. Por omisión, un
Ctrl-C mata el proceso donde esté: a medio escribir un
archivo, con conexiones a medio responder.

El efecto `Signal` convierte esa interrupción en algo que tu
programa decide cuándo atender:

```kai
# ejemplos/cap17/01_senal.kai
import effects.os

fn main() : Unit / Stdout + Signal = {
  Signal.on(SigInt)
  println("esperando Ctrl-C...")
  let _s = Signal.await()
  println("señal recibida, salgo ordenado")
}
```

Córrelo y manda un Ctrl-C: queda esperando hasta que la señal
llegue, así que antes no hay salida que mostrar.

`Signal.on(SigInt)` se suscribe; `Signal.await()` suspende la
fibra hasta que llegue. Es un punto de yield como cualquier
otro: el resto del programa sigue corriendo mientras esta
fibra espera.

En un servidor, una fibra dedicada espera la señal y, al
recibirla, cancela el listener. La cancelación
desciende por el nursery, cada fibra de conexión corre su
handler de `Cancel`, y el `finally` del almacén alcanza a
escribir a disco. Es el mismo mecanismo del cap. 13, con la
señal del sistema operativo como disparador.

Y por cada conexión, el handler:

```kai
fn atender_conexion(conn: Conn, almacen_pid: Pid[almacen.AlmacenMsg], log_pid: Pid[persistencia.Evento]) : Unit / NetTcp + Actor[almacen.AlmacenMsg] + Actor[almacen.AlmacenResp] + Actor[persistencia.Evento] + Cancel {
  let raw  = leer_request(conn)
  let wire = manejar_request(raw, almacen_pid, log_pid)
  let _    = NetTcp.send(conn, web.string_to_bytes(wire))
  NetTcp.close(conn)
}
```

Son cuatro líneas porque el trabajo vive en `manejar_request`:
parsea HTTP, enruta a un comando, registra en el log, consulta
al almacén y serializa la respuesta. Aquí quedan las dos puntas
que tocan el socket, leer y escribir, más el cierre. Cada paso
es una función pura o un mensaje a un actor. No hay memoria
compartida en ninguna parte, ni un solo lock.

## 17.7 Lo que está ocurriendo, en términos del libro

Estas son las piezas del libro que usaste, una a una:

- **Cap. 2** (pensar en kaikai): las funciones son
  expresiones; `procesar` devuelve una tupla en una sola
  expresión.
- **Cap. 4** (tipos compuestos): tuplas de retorno
  (`(Respuesta, [Nota], Int)`), records (`Nota`), listas con
  pattern de cabeza y cola.
- **Cap. 5** (sum types y match): `Comando`, `Respuesta`,
  `Evento` son sum types; los match cubren todas las
  variantes; la exhaustividad la verifica el compilador.
- **Cap. 6** (funciones y pipelines): `list.map`,
  `list.filter` sobre la lista de notas; closures pasadas a
  esas funciones.
- **Cap. 7** (pruebas): tests sobre `procesar` que verifican
  la lógica sin arrancar fibras.
- **Cap. 8** (módulos): cinco archivos cada uno con su `pub`,
  imports entre ellos.
- **Cap. 9** (protocolos): `#[derive(Show)]` para interpolar
  notas.
- **Cap. 12** (efectos): cada función declara su fila;
  `handle` no aparece directamente porque los `handle`s viven
  dentro de `with_mailbox` y `spawn_actor` del stdlib.
- **Cap. 13** (fibras): `nursery` para estructurar el bucle de
  aceptación; cada conexión es una fibra.
- **Cap. 14** (actores): el almacén y la persistencia son
  actores; `with_mailbox` en cada cliente; `spawn_actor` para
  arrancarlos; mensajes tipados.
- **Cap. 16** (tooling): `kai run main.kai` lo arranca; `kai
  test` corre los tests del módulo `almacen`.

No hay sintaxis nueva. Lo nuevo es la combinación: piezas
pequeñas y ortogonales encajando en un programa con
responsabilidades reales.

## 17.8 Cómo extenderlo

Puedes llevar este programa en varias direcciones para
profundizar lo que aprendiste:

- **Persistencia con recovery.** Hoy el log es write-only. Si
  el servidor se reinicia, las notas se pierden. Una extensión
  natural: al arrancar, leer el log y reconstruir el estado.
- **Búsqueda por contenido.** El comando `Obtener` busca por
  id. Agregar un `Buscar(String)` que filtre por substring del
  cuerpo. La lógica pura va en `procesar`; el `match` del
  `enrutar` HTTP gana un brazo.
- **TTL por nota.** Cada nota tiene una expiración. El
  almacén, en cada `Obtener`, verifica si la nota expiró y la
  borra si sí. El campo `created_at` se agrega a `Nota`; el
  efecto `Time` aparece en la fila del `bucle`.
- **Múltiples instancias.** Hoy hay un solo almacén. Para un
  servicio más grande, particionar las notas en varios actores
  por hash del id. El `main` arranca N almacenes y enruta cada
  request al actor que corresponda.
- **Métricas.** Un cuarto actor que recibe eventos
  (`request_recibido`, `nota_creada`, `error_emitido`) y
  acumula contadores. El `main` lo arranca, los handlers le
  mandan eventos, un endpoint `GET /metricas` lee.
- **Test de integración.** Un programa cliente que abre una
  conexión TCP al servidor, manda un request, lee la
  respuesta, verifica que sea lo esperado. Pone el servidor en
  un nursery, corre el cliente, cierra.

Cada una es una sesión de tarde, y ninguna cambia la
estructura básica: un dominio puro, actores con estado, fibras
para concurrencia, módulos para separación.

## 17.9 Lo que muestra este caso

Lo que armaste sigue un patrón claro:

- **El dominio es puro.** `Comando`, `Respuesta`, `procesar`:
  tipos y funciones sin efectos. Se testean con entradas y
  salidas, sin arrancar nada.
- **Los actores envuelven el estado mutable.** El almacén
  mantiene la lista de notas; el persistor mantiene el archivo
  de log. La mutación queda encerrada dentro de cada actor,
  invisible para el resto del programa.
- **Las fibras paralelizan el trabajo concurrente
  (cooperativamente).** Una fibra por conexión. El nursery
  garantiza que ninguna sobreviva al servidor.
- **Los módulos separan responsabilidades.** Cinco archivos
  para cinco temas, y cualquiera se puede reemplazar sin tocar
  los otros tres.

En el cap. 18 aplicas el mismo patrón a un dominio muy
distinto, la contabilidad financiera, y la estructura se
mantiene aunque el problema cambie. El cierre del libro viene
allá.
