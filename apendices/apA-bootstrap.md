# Apéndice A · Bootstrap de tres etapas

Este apéndice cuenta cómo se construye el compilador de kaikai
desde cero, partiendo de un compilador de C corriente. No es
parte del lenguaje que el lector necesita conocer para
programar; es parte del relato del proyecto, una decisión de
ingeniería con consecuencias durables.

Si te preguntas "¿por qué importa cómo se compila el compilador?",
la respuesta corta: porque define a quién le crees y por qué.
Un lenguaje cuyo compilador se construye desde una `cc` y nada
más es un lenguaje que cualquiera puede auditar, reproducir, y
mantener. Eso es libertad técnica de la que pocos lenguajes
modernos gozan.

## A.1 El problema del bootstrap

Un compilador es un programa. Como cualquier programa,
necesita ser compilado para correr. Los compiladores nuevos
tropiezan con una paradoja inmediata: ¿qué compila al
compilador la primera vez?

Tres respuestas históricas:

- **Escribirlo en C (o ensamblador) la primera vez.** Es la
  ruta clásica. GCC, MRI Ruby, CPython, V8 nacieron así. El
  costo: el compilador del lenguaje nuevo carga con la
  superficie de C para siempre, o se reescribe en sí mismo
  más tarde con una migración costosa.
- **Escribirlo en un lenguaje existente que ya tenga
  compilador.** Es lo que hizo Rust con OCaml al principio, lo
  que hizo Swift con C++. Hereda las dependencias del lenguaje
  huésped: compilar Rust requiere instalar OCaml, hasta que
  Rust se reescribió en sí mismo.
- **Self-hosting incremental.** Empezar con un compilador
  chico (de un subconjunto del lenguaje), escrito en algo
  portable, usarlo para compilar un compilador más grande
  (escrito en el lenguaje), y así sucesivamente. Es lo que
  hace kaikai con sus tres etapas.

## A.2 Stage 0: el compilador en C

`stage0` es un compilador escrito en C estándar. Su única
dependencia es un compilador de C cualquiera:

```sh
$ cc stage0/*.c -o kaic0
```

Sin frameworks, sin generadores, sin librerías exóticas. C
plano. El archivo `stage0/runtime.h` es el runtime de los
programas compilados: contadores de referencia, primitivas de
listas y strings, panic. Todo eso entra en unos pocos miles de
líneas.

¿Qué compila `kaic0`? **kaikai-minimal**, un subconjunto
deliberado del lenguaje. La gramática y las construcciones que
caben en kaikai-minimal están documentadas en
`docs/kaikai-minimal.md`. Lo que **no** está en
kaikai-minimal: efectos algebraicos, fibras, protocolos,
contratos, unidades de medida. Lo mínimo para escribir un
compilador.

Stage 0 está hecho para ser auditable. Un programador que
quiera entender qué es lo que está pasando puede leer el
código C línea por línea: lexer, parser recursive-descent,
chequeo de tipos simple, emisor de C. Cinco archivos.

## A.3 Stage 1: el compilador en kaikai-minimal

Una vez que `kaic0` funciona, escribimos un compilador nuevo
**en kaikai-minimal**. Este compilador, `stage1`, hace algo
que `kaic0` no puede: compila el lenguaje **completo**.
Efectos, fibras, protocolos, contratos, todo.

```sh
$ kaic0 stage1/main.kai -o kaic1
```

`kaic0` compila `stage1` produciendo un ejecutable `kaic1`. A
partir de ahí, el compilador de C ya no participa: `kaic1` es
suficiente para procesar programas que usan todo kaikai.

Es la primera "auto-validación": el compilador escrito en
kaikai-minimal demuestra que kaikai-minimal es lo bastante
expresivo como para implementar un compilador completo. Si no
lo fuera, este paso no terminaría.

## A.4 Stage 2: kaikai completo, self-hosted

`stage2` es la versión definitiva. Está escrito en **kaikai
completo** (no en el subset minimal), usando efectos, fibras,
y todo lo que el lenguaje ofrece. Es código kaikai idiomático
de extremo a extremo.

```sh
$ kaic1 stage2/main.kai -o kaic2
```

`kaic1` compila `stage2`, produciendo `kaic2`. Este es el
compilador que se distribuye. El usuario que instala kaikai
recibe `kaic2`, no `kaic0` ni `kaic1`.

## A.5 El punto fijo: validación del bootstrap

Hay una verificación crítica que hace al final del proceso:

```sh
$ kaic2 stage2/main.kai -o kaic2-self
$ diff kaic2 kaic2-self
```

Tienen que ser **bit-por-bit idénticos**. Esto significa que
`kaic2` compilado por `kaic1` produce exactamente lo mismo que
`kaic2` compilado por sí mismo. En otras palabras: `kaic2` es
un punto fijo del proceso de compilación.

¿Por qué importa esto? Por dos razones:

- **Detección de errores sutiles en el compilador.** Si dos
  versiones del compilador (`kaic1` y `kaic2`) producen
  binarios distintos a partir del mismo código fuente, una de
  las dos tiene un bug. El punto fijo confirma que la cadena
  entera converge a la misma respuesta.
- **Resistencia al ataque de Thompson.** Ken Thompson publicó
  en 1984 un ensayo famoso ("Reflections on Trusting Trust")
  donde mostraba que un compilador malicioso puede insertar
  backdoors invisibles que sobreviven a recompilaciones. La
  defensa clásica es **diverse double-compiling**: compilar
  con dos cadenas distintas y comparar. El punto fijo es la
  versión moderna de esa idea: si la cadena entera converge a
  un mismo binario, y ese binario es reproducible desde
  fuentes auditables, la confianza está justificada.

## A.6 Reproducible desde una `cc`

La consecuencia práctica del bootstrap de tres etapas es esta:
**con solo un compilador de C, puedes reconstruir kaikai
entero desde el código fuente**. No hace falta tener kaikai
previamente instalado. No hace falta confiar en un binario
descargado de una página web. No hace falta `curl | bash`.

```sh
$ git clone https://github.com/lnds/kaikai
$ cd kaikai
$ make
```

Por dentro, `make` ejecuta los tres pasos: stage 0 con cc,
stage 1 con stage 0, stage 2 con stage 1. Termina con un
`kaic2` en el directorio `bin/`, y la verificación de punto
fijo asegura que es el correcto.

Esto es libertad técnica que pocos lenguajes modernos te dan.
Rust requiere un Rust previo (descargado como blob). Go
requiere un Go previo. Swift requiere un Swift previo. kaikai
no: tu compilador de C es el punto de entrada.

## A.7 Costos y trade-offs

El bootstrap de tres etapas tiene costos. Vale enumerarlos
porque toda decisión de ingeniería los tiene:

- **Hay que mantener stage 0 cada vez que cambia
  kaikai-minimal.** Si una característica nueva del lenguaje
  cae dentro del subset minimal, stage 0 tiene que aprenderla.
  Eso significa código C nuevo, escrito a mano.
- **Cuesta agregar dependencias al compilador.** Stage 2 podría
  beneficiarse de una biblioteca externa (parser combinator,
  estructura de datos exótica). Pero esa biblioteca tendría que
  estar disponible en stage 1, que solo entiende
  kaikai-minimal. La presión es hacia mantener stage 2
  autosuficiente.
- **Compilar todo desde cero toma tiempo.** No mucho (los
  tres pasos juntos toman menos de un minuto en una máquina
  razonable), pero más que un solo `cargo build`. Para CI
  contínuo, importa.

¿Vale la pena? La respuesta del proyecto es sí, y la razón es
filosófica: el compilador es la pieza de software más confiada
del ecosistema. Si la cadena de confianza se puede auditar de
extremo a extremo, partiendo de C plano, entonces el resto
sigue.

## A.8 Para profundizar

Las decisiones de diseño viven en `docs/design.md` de
`github.com/lnds/kaikai`. Los archivos físicos están bajo
`stage0/`, `stage1/`, `stage2/` del repositorio. Hay un
ensayo de Ken Thompson, *Reflections on Trusting Trust* (CACM
1984), que vale la pena leer si te interesa la justificación
filosófica de este enfoque.
