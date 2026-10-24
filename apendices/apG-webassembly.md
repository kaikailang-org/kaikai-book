# Apéndice G · WebAssembly

Todo el libro compila a un binario nativo: `kai run` arma un
ejecutable para tu máquina y lo corre. Pero un programa kaikai
también puede terminar como un módulo WebAssembly, ya sea para
correr en una consola bajo un runtime como `wasmtime` o dentro de
una página web. El lenguaje es el mismo; lo que cambia es el mundo
al que el programa le pide cosas.

Ese "mundo" no es una metáfora. En kaikai cada efecto que un
programa necesita está escrito en su tipo, y `main` no es la
excepción: su fila de efectos es la lista de lo que el programa le
pide al entorno. Cuando cambias de destino, el compilador compara
esa lista contra lo que el destino puede dar, y te dice qué falta
**antes** de generar nada. Este apéndice recorre los dos destinos
con esa idea a mano.

## G.1 Dos destinos

`kai build` y `kai run` aceptan una bandera `--target`:

| Destino | Para qué | Qué produce |
|---|---|---|
| `wasm32-wasi` | programas de consola en un runtime WASI | un único `.wasm` |
| `wasm32-browser` | programas que viven en una página | el `.wasm`, la página que lo carga y el código que lo hospeda |

El módulo lo emite el backend nativo, con el LLVM que `kai` trae
adentro, cuando tu `kai` fue armado con el target de WebAssembly;
si no, lo emite el backend C (el capítulo 16 cuenta por qué hay
dos). Los archivos que salen son los mismos, y `--backend` o
`KAI_BACKEND` elige si quieres mirarlo de cerca.

Los dos destinos comparten un toolchain fijo: la primera vez que
usas cualquiera de ellos, `kai` descarga el wasi-sdk 34 a tu caché,
verifica su SHA-256 contra el valor que trae grabado y lo reutiliza
de ahí en adelante. Si la descarga falla o el checksum no calza, la
compilación se detiene; `kai` nunca cae en silencio a otro
compilador que encuentre en el `PATH`. Si ya tienes ese wasi-sdk
instalado, `KAI_WASI_SDK=<dir>` lo usa en vez de bajarlo.

## G.2 La consola: `wasm32-wasi`

WASI es la interfaz con la que un módulo WebAssembly habla con el
sistema operativo: archivos, variables de entorno, reloj, números
al azar, la entrada estándar y el código de salida. Un programa que
solo calcula e imprime no nota la diferencia:

```kaikai
# ejemplos/apG/01_collatz.kai
# Cuántos pasos le toma a cada número llegar a 1.

fn pasos(n: Int, k: Int) : Int =
  if n == 1 { k }
  else if n % 2 == 0 { pasos(n / 2, k + 1) }
  else { pasos(3 * n + 1, k + 1) }

fn main() {
  [6, 7, 27, 97] |! println("#{.} llega a 1 en #{pasos(., 0)} pasos")
}
```

```
$ kai run --target=wasm32-wasi ejemplos/apG/01_collatz.kai
6 llega a 1 en 8 pasos
7 llega a 1 en 16 pasos
27 llega a 1 en 111 pasos
97 llega a 1 en 118 pasos
```

`kai run` compila el módulo en un directorio temporal y lo ejecuta
con `wasmtime`, que tiene que estar en tu `PATH` y ser una versión
reciente (la 49 o posterior, que trae activado el manejo de
excepciones de WebAssembly). Los argumentos que pongas después del
archivo van al programa, el entorno se hereda completo y el código
de salida del programa es el de `kai`.

Si lo que quieres es el módulo para llevártelo a otra parte, usa
`build`:

```
$ kai build --target=wasm32-wasi ejemplos/apG/01_collatz.kai -o collatz.wasm
$ wasmtime collatz.wasm
```

El `.wasm` no depende de tu sistema operativo ni de tu
procesador: es el mismo archivo en tu Mac o en un servidor Linux
que nunca vio un compilador de kaikai, con tal de que tenga
`wasmtime`.

### Archivos: lo que el runtime te deja ver

Un módulo WASI no ve tu disco. Ve solo los directorios que el
runtime le **preabre**. `kai run` preabre el directorio actual, así
que un programa que trabaja con rutas relativas funciona sin más:

```kaikai
# ejemplos/apG/02_bitacora.kai
import fs.file

fn main() : Unit / Stdout + File {
  let ruta = "bitacora.txt"
  file.write(ruta, "lunes: compilé a wasm\n")
  file.append(ruta, "martes: lo corrí en wasmtime\n")
  println(file.read(ruta) |> trim())
  let _ = file.delete(ruta)
  println("¿quedó el archivo? #{file.exists(ruta)}")
}
```

```
$ kai run --target=wasm32-wasi ejemplos/apG/02_bitacora.kai
lunes: compilé a wasm
martes: lo corrí en wasmtime
¿quedó el archivo? false
```

Cambia `ruta` por `/tmp/bitacora.txt` y el mismo programa se cae
con `panic: file.write: write failed`. No es un error de permisos
del sistema operativo: `/tmp` simplemente no existe para el módulo.
Para abrirle otros directorios, `KAI_WASI_DIRS` recibe una lista
separada por `:` que reemplaza al directorio actual:

```
$ KAI_WASI_DIRS=/tmp kai run --target=wasm32-wasi bitacora_en_tmp.kai
```

Fíjate en que el tipo de `main` ya avisaba que el programa toca
archivos: dice `File`. WASI agrega la otra mitad, *cuáles*
archivos. Entre los dos, quien corre el módulo sabe exactamente qué
le está entregando.

### Lo que no corre en WASI: fibras

En este destino no hay fibras. Una fibra necesita suspender su
pila y retomarla después, y en `wasmtime` eso espera la propuesta
de *stack switching* de WebAssembly, que todavía no está
disponible. Y como `Spawn` es un efecto como cualquier otro, el
compilador lo ve en la fila de `main`:

```kaikai
# ejemplos/apG/03_fibras.kai
import spawn

fn main() : Unit / Stdout + Spawn {
  let f = spawn.spawn { println("desde otra fibra") }
  spawn.await(f)
}
```

```
$ kai run --target=wasm32-wasi ejemplos/apG/03_fibras.kai
error: `main` performs effect `Spawn`, which the `wasm32-wasi` target cannot run
  --> ejemplos/apG/03_fibras.kai:3:1
    |
  3 | fn main() : Unit / Stdout + Spawn {
    | ^
  = help: fibers are not available on wasm32-wasi; handle `Spawn` in `main` with a handler of your own, or remove it from `main`'s row
```

Este es el momento del apéndice que más me gusta. En la mayoría de
los lenguajes, un programa que usa hilos compila sin problemas para
un destino sin hilos y revienta al correr, en el peor lugar
posible. Aquí el error llega en compilación y apunta a la línea
exacta, porque la información ya estaba en el tipo. Nadie tuvo que
escribir un chequeo especial para WebAssembly: es la misma fila de
efectos que leíste en el capítulo 12, comparada contra otra lista.

Lo mismo pasa con `Actor`, `Cancel`, `Link`, `Monitor`, `Signal` y
los efectos de red (`NetTcp`, `NetUdp`, `NetUnix`, `NetDns`): WASI
preview 1 no tiene sockets. Lo que sí corre es todo el resto del
lenguaje, más `File`, `Env`, `Stdin`, `Stdout`, `Clock` (un
`sleep` bloquea la instancia entera), `Random`, `SecureRandom` y
`Process.exit`.

Hay un caso que el tipo no alcanza a ver: un handler que se guarda
la continuación para retomarla después, como un generador. Ese se
detiene al correr, con un mensaje que nombra el destino. El
capítulo 12 explica qué significa guardar `resume`; aquí basta con
saber que es la misma maquinaria que las fibras y que, por lo
tanto, tampoco está.

## G.3 La página: `wasm32-browser`

El otro destino lleva el programa al navegador:

```kaikai
# ejemplos/apG/04_pagina.kai
type Figura = Circulo(Int) | Rectangulo(Int, Int)

fn area(f: Figura) : Int = match f {
  Circulo(r) -> 3 * r * r
  Rectangulo(a, b) -> a * b
}

fn main() {
  println("hola desde la página")
  [Circulo(2), Rectangulo(3, 4)] |! println("área #{area(.)}")
}
```

```
$ kai build --target=wasm32-browser ejemplos/apG/04_pagina.kai -o web/pagina
```

El `-o` nombra un prefijo, no un archivo, porque salen cuatro:

```
web/pagina.wasm    el módulo
web/pagina.mjs     arranca pagina.wasm en el host
web/pagina.html    un <pre id="kai-stdout"> y un script de módulo
web/kai_host.mjs   el host: lo que el programa le pide a la página
```

Sirve el directorio con cualquier servidor estático y abre
`pagina.html`. Lo que el programa imprime aparece en el `<pre>` y
en la consola del navegador:

```
hola desde la página
área 12
área 12
```

El mismo host corre bajo Node, que es cómodo para probar sin abrir
un navegador: `node web/pagina.mjs` imprime lo mismo en la
terminal.

`kai run` no acepta este destino: una página se sirve, no se
corre desde la consola. Y el navegador tiene sus propios límites,
que el compilador aplica igual que en WASI: un `main` que pide
archivos del disco, la entrada estándar, señales o sockets se
rechaza al compilar.

### La página como efectos

Imprimir en un `<pre>` sirve para empezar, pero una página está
hecha de nodos, eventos, timers y pedidos HTTP. El stdlib los
modela como cuatro efectos: `Dom` (`web.dom`), `Timer`
(`web.timer`), `Fetch` (`web.fetch`) y `Storage` (`web.storage`).
`web.run { ... }` es el handler que los conecta con la página real.

Un contador de clics:

```kaikai
# ejemplos/apG/05_contador.kai
import web.dom
import web.run

fn contar(boton: Node, n: Int) : Unit / Dom {
  let e = Dom.next_event()
  if e.kind == "click" {
    Dom.set_text(boton, "clics: #{n + 1}")
    contar(boton, n + 1)
  } else {
    contar(boton, n)
  }
}

fn main() : Unit / Js + Ffi + Clock =
  run.run(() => {
    let boton = Dom.create("button")
    Dom.set_text(boton, "clics: 0")
    Dom.append(Dom.query("body") ?? boton, boton)
    Dom.listen(boton, "click")
    contar(boton, 0)
  })
```

Si vienes de JavaScript, lo raro aquí es que no hay callbacks. No
registras una función para que la llamen cuando ocurra un clic:
`Dom.listen` le pide al host que encole los clics de ese botón, y
`Dom.next_event()` **espera** el siguiente, como si leyeras una
línea de la entrada estándar. El estado del contador no vive en una
variable que alguien muta desde afuera; es el argumento `n` de una
función recursiva. Es el mismo estilo de los actores del capítulo
14, donde un proceso es un bucle que recibe mensajes, aplicado a la
interfaz.

La firma de `contar` dice `Dom` y nada más: esa función toca la
página y no puede hacer otra cosa. La de `main` dice `Js`, y eso la
amarra a este destino. Si intentas `kai run ejemplos/apG/05_contador.kai`,
el compilador te dice que el destino nativo no puede correr `Js`.

### Fibras en la página

A diferencia de WASI, en el navegador sí hay fibras, actores,
`Clock.sleep` y `receive_timeout`. Este programa es una versión con
reloj de las dos fibras del tour:

```kaikai
# ejemplos/apG/06_relojes.kai
import spawn
import time
import loop

fn reloj(nombre: String, ms: Int, veces: Int) : Unit / Stdout + Clock {
  loop.repeat(veces) {
    time.sleep(time.millis(ms))
    println("#{nombre}: tic")
  }
}

fn main() : Unit / Stdout + Clock + Spawn {
  let lento = spawn.spawn { reloj("lento", 250, 2) }
  reloj("rápido", 100, 4)
  spawn.await(lento)
  println("listo")
}
```

Compilado con `--target=wasm32-browser` y abierto en la página,
imprime lo mismo que con `kai run` en tu máquina:

```
rápido: tic
rápido: tic
lento: tic
rápido: tic
rápido: tic
lento: tic
listo
```

La diferencia está en cómo espera. Un `sleep` en la página no
bloquea nada: la fibra se estaciona en el event loop del
navegador y la página sigue respondiendo mientras tanto. Por
debajo, la suspensión usa JavaScript Promise Integration (JSPI),
una extensión reciente de WebAssembly.

## G.4 Requisitos y límites

Lo que necesita cada destino, en un solo lugar:

- **`wasm32-wasi`:** `wasmtime` 49 o posterior en el `PATH` para
  `kai run`. El `.wasm` es un módulo WASI preview 1 que usa el
  manejo de excepciones de WebAssembly.
- **`wasm32-browser`:** un navegador con manejo de excepciones de
  WebAssembly (Chrome y Edge 137, Firefox 131, Safari 18.4). Si el
  programa suspende (una fibra, un `sleep`, un handler que guarda
  la continuación) necesita además JSPI: Chrome y Edge 137,
  Firefox 153, Safari 27. El host se niega a cargar el programa en
  un navegador que no lo tenga, en vez de fallar a medio camino.
- **En los dos:** la recursión que no es de cola queda limitada
  por la pila del motor, del orden de 6.000 llamadas en Chrome:
  menos de lo que te da tu máquina, así que una función recursiva
  que procesa una lista larga conviene escribirla con recursión de
  cola o con pipes.
- **`kai test`** no tiene `--target`: las pruebas corren siempre en
  tu máquina.

Para lo que este apéndice no cubre (llamar a JavaScript con
`extern "js"`, declarar módulos JavaScript en `[js]` dentro de
`kai.toml`, o pintar un frame completo con `Dom.put_pixels`), la
referencia está a un comando de distancia:

```
$ kai info wasm
```

WebAssembly no es un lenguaje nuevo que tengas que aprender. Es un
lugar más donde corre el que ya sabes, y la fila de efectos de
`main` te dice, antes de compilar, si el programa cabe en él.
