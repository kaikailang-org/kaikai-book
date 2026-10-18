# Capítulo 7 · Pruebas, propiedades y benchmarks

Hasta aquí escribiste funciones y miraste la salida. Ese ciclo
sirve mientras el programa te cabe en la cabeza, pero no escala:
apenas pasas de unas decenas de líneas, o de tres funciones que
se llaman entre sí, ya no puedes verificar a ojo que cada cambio
mantiene el comportamiento.

Para eso están las pruebas. kaikai trae **tres construcciones
top-level** dedicadas: `test`, `check` y `bench`. Las tres se
ejecutan con el driver `kai` y se ignoran cuando construyes un
binario para producción.

Lo habitual es escribirlas en el mismo archivo del código que
prueban, pero no es obligatorio: un `aritmetica_test.kai` que
importe `aritmetica` y declare sus `test` compila y corre igual,
y el driver lo encuentra solo: `kai test ./...`
recorre los `*_test.kai` del paquete aunque nadie los importe,
los corre como unidad aparte, y si alguno falla el proceso sale
con código distinto de cero. Eso vale también para una
**biblioteca**, un paquete que por definición no declara punto
de entrada.

Aquí aprendes las tres y cuándo usar cuál, y cierras con un
mini-evaluador que tiene tests contractuales, propiedades
verificadas y benchmarks que miden cuánto cuesta cada
operación.

## 7.1 `test "..." { ... }` y `assert`

La forma más simple es un test con un nombre y un cuerpo:

```kai
fn factorial(n: Int) : Int =
  if n <= 1 { 1 } else { n * factorial(n - 1) }

test "caso base" {
  assert factorial(0) == 1
  assert factorial(1) == 1
}

test "casos pequeños" {
  assert factorial(3) == 6
  assert factorial(5) == 120
}

test "caso significativo" {
  assert factorial(10) == 3628800
}
```

`test` es un **bloque top-level**: convive con `fn` en el
mismo archivo y no se anida en otra función. Su nombre es un
literal de string que el runner reporta tal cual. Adentro
escribes aserciones con `assert`: una expresión `Bool` que
debe ser `true`. Si todas las aserciones del bloque pasan, el
test pasa. Si **una** falla, el test falla y el runner sigue
con los siguientes.

El nombre del test dice **qué se prueba**. "caso base" sirve;
"test 1" no.

`assert` también acepta un mensaje opcional con coma:

```kai
test "rangos válidos" {
  let n = clasificar(42)
  assert n > 0, "se esperaba positivo, no #{n}"
}
```

El mensaje aparece cuando la aserción falla, y sirve cuando la
expresión por sí sola no dice qué fue lo inesperado.

### Lo que el runner imprime

```
$ kai test ejemplos/cap07/01_test_basico.kai
  ok   caso base
  ok   casos pequeños
  ok   caso significativo

3/3 tests passed
```

Si un test falla, la salida lo muestra:

```
$ kai test ejemplos/cap07/02_assert_falla.kai
  ok   doble preserva positivos
  FAIL test roto: el assert va a fallar : assertion failed
  ok   este test sigue corriendo

2/3 tests passed
```

Tres detalles:

- **Los tests se ejecutan en orden de declaración**, de arriba
  a abajo. No hay paralelismo dentro de un mismo archivo.
- **Un test que falla no detiene a los demás.** El runner sigue
  y reporta el conteo final.
- **Los bloques `test` no terminan en el binario de producción.**
  `kai run` y `kai build` los descartan. Solo se compilan y se
  ejecutan bajo `kai test`.

### Qué efectos puede cargar un test

Un cuerpo de `test`, igual que uno de `bench` o de `check`, no
lleva fila de efectos ni puede declararla. Adentro puede hacer lo
mismo que una entrada de programa: absorbe los efectos builtin
que traen handler por defecto (`Stdout`, `File`, `Clock`…) más la
capacidad `Ffi` que el compilador sintetiza. Por eso un test puede
llamar a un `extern "C"` sin envolverlo en nada:

```kai
# ejemplos/cap07/06_efectos_en_test.kai
extern "C" fn llabs(x: Int) : Int / Ffi

test "un test puede llamar un extern C directo" {
  assert llabs(-5) == 5
}
```

Con un efecto **tuyo** se tropieza. La entrada del runner no
tiene handler para él, así que invocarlo suelto no compila:

```
error: effect not handled: Reloj
  --> x.kai:6:21
    |
  6 |   assert Reloj.ahora() == 1234
    |                     ^
  = note: enclosing row: (empty)
```

La última nota es la pista: la fila que rodea al test está
vacía, y no hay dónde declarar una. La salida es instalar el
handler dentro del cuerpo, que suele ser lo que querías: el test
decide qué devuelve el reloj en vez de depender del de verdad:

```kai
test "un efecto propio se maneja dentro del cuerpo" {
  let t = handle { Reloj.ahora() } with Reloj {
    ahora(resume) -> resume(1234)
  }
  assert t == 1234
}
```

La restricción trabaja a favor: un test que necesita un efecto
tuyo te obliga a decir con qué lo reemplazas, ahí mismo donde se
lee.

## 7.2 `kai test` y el ciclo corto de retroalimentación

```
$ kai test mi_archivo.kai
```

Compila el archivo en modo `--test` (que activa los bloques
`test`), produce un binario, lo ejecuta y reporta. El ciclo
edición → prueba toma uno o dos segundos en archivos chicos.

Dentro de un proyecto (un directorio con `kai.toml`),
`kai test .` corre los tests del paquete principal y descubre
cualquier `.kai` bajo `tests/`. Cada archivo de `tests/` es su
propio programa de prueba, fuera del paquete, y corre por
separado. Eso sí, se compilan juntos en un solo binario:
`kai test` revisa cada uno solo y después los construye en
conjunto, así que dos archivos que pasan por separado pero no
compilan juntos hacen fallar la corrida. Lo que compartan va a
un módulo que ambos importen. Para ejercer una función `pub`
del paquete desde `tests/`, impórtala como cualquier
dependencia: `import mi_paquete`.

Las compilaciones corren en paralelo, hasta una por CPU por defecto;
`-j <n>` fija el tope. Los tests se siguen ejecutando de a un
archivo, en orden.

Con `kai test mi_archivo.kai` sobre un archivo suelto, el
runner corre los bloques `test` de ese archivo y nada más. Cada archivo que declara bloques es la raíz de su
propia corrida, así que los bloques de un módulo corren una
sola vez, cuando el módulo es el que apuntas, por muchos
archivos que lo importen. Los del stdlib y de las dependencias
tampoco entran: la cuenta que ves es la de tu código. No hay
descubrimiento estilo `pytest` en archivos sueltos; el modelo
descubre solo cuando hay un `kai.toml` que defina el paquete.

Tres hábitos que internalizas en pocas semanas:

- **Tests al lado del código, en el mismo archivo.** No los
  separes en `tests/` o en archivos paralelos. Cuando tocas
  una función, los tests de esa función están al ojo.
- **Un test por aspecto, no por línea.** Si tu función tiene
  un caso base, casos pequeños y un caso límite, escribe
  tres `test`. Si dentro de "casos pequeños" hay tres
  ejemplos, agrégalos como tres `assert` en el mismo bloque.
- **Nombres descriptivos.** El nombre aparece en la salida
  del runner cada vez que corres los tests.
  `"validar email rechaza espacios"` se entiende; `"test_3"`
  no.

### Resultados para máquinas: `--json`

La salida con colores y palomitas es para ti. Cuando quien lee
es otro programa (un runner de CI que anota el commit, un
dashboard, un script que compara dos corridas), usas `--json`:

```
$ kai test --json mi_archivo.kai
{"type":"test","id":"mi_archivo.kai:uno","file":"mi_archivo.kai","line":3,"status":"pass","duration_ms":0}
{"type":"summary","passed":1,"failed":0,"duration_ms":0}
```

Es NDJSON: un objeto JSON por línea, uno por bloque `test`, y
un `summary` al final. Sin el flag la salida humana no cambia.

Tres detalles para quien lo consuma. Un bloque que falla trae
además un `message` con el texto del assert, y el código de
salida sigue siendo 1. El `id`, `archivo:nombre del test`, es
la forma canónica de nombrar un bloque, estable entre corridas
mientras el nombre y el archivo no cambien. Y si el cuerpo de
un test imprime, esa salida va a stderr: por stdout salen solo
los registros, y un parser los lee línea a línea sin filtrar
nada.

### Correr uno solo: `--only`

Ese `id` no es solo para leer. `--only` lo toma y corre
exactamente ese bloque:

```
$ kai test --only "mi_archivo.kai:uno" mi_archivo.kai
  ok   uno

1/1 tests passed
```

El flag se repite para nombrar varios. Cuando un test falla en
medio de una suite lenta, en vez de esperar los otros cien
corres el que te importa.

Si el `id` no calza con ningún bloque, es **error**, con código
de salida 1, y no un "cero tests, todo bien". Apenas automatizas
algo, eso importa: un script que pasa ids generados y lee un
cero como éxito creería que el test pasó, cuando no corrió
ninguno. Ese falso verde es peor que un rojo.

## 7.3 `check "..."`: propiedades

Los tests que escribiste hasta aquí comprueban **casos
fijos**: "para esta entrada, espero esta salida". En otros
lenguajes se llama "example-based testing". Es lo más común,
pero tiene un límite obvio: solo prueba lo que escribes.

Las **propiedades** lo invierten. En vez de "para `cuadrado(7)`
espero `49`", escribes "para todo `n` entero, `cuadrado(n)`
debe ser `>= 0`". El runner genera valores de `n` al azar y
verifica la propiedad sobre cada uno. Si encuentra un
contraejemplo, te lo muestra; si pasan cien iteraciones sin
falla, da la propiedad por probada.

```kai
fn doble(n: Int) : Int = n * 2

check "doble es par" with n: Int {
  doble(n) % 2 == 0
}

check "suma conmutativa" with a: Int, b: Int {
  a + b == b + a
}

check "suma asociativa" with a: Int, b: Int, c: Int {
  (a + b) + c == a + (b + c)
}

check "reverse de reverse" with xs: [Int] {
  list.reverse(list.reverse(xs)) == xs
}
```

`check "..." with name: Type { body }` declara una propiedad.
La cláusula `with` lista los parámetros que el runner genera
al azar; el `body` es una expresión `Bool` que tiene que ser
`true`.

```
$ kai check ejemplos/cap07/03_check_propiedades.kai
  doble es par: 100 iter, OK
  suma conmutativa: 100 iter, OK
  suma asociativa: 100 iter, OK
  reverse de reverse: 100 iter, OK

4/4 checks passed
```

Cien iteraciones por propiedad es lo predeterminado; cada iteración
genera valores nuevos. Para `Int`, el rango por defecto es
`[-50, 50]`. Para `[Int]`, listas pequeñas. Para records y
sum types, el generador estructura recursivamente sus
componentes.

### Cuando una propiedad falla

```kai
check "todos los Int son positivos" with n: Int {
  n > 0
}
```

```
$ kai check propiedad_falsa.kai
  todos los Int son positivos: counterexample at iter 1: n=-32

0/1 checks passed
```

El runner te entrega el **contraejemplo exacto** (`n = -32`)
de la primera iteración que falló. Con eso sabes tres cosas:

- La propiedad es falsa para algún valor de `n`.
- El valor concreto.
- En qué iteración falló (útil para reproducir con la misma
  semilla si quieres depurar).

En un `test` con caso fijo, el nombre del test diagnostica el
fallo. Un `check` te entrega el caso de prueba **junto con** el
reporte, sin que tengas que escribirlo.

### Cuándo escribir un `check`

Las propiedades sirven cuando puedes **enunciar una verdad
universal** sobre tu código. Algunas comunes:

- **Inversas**: `parse(format(x)) == x`,
  `descomprimir(comprimir(x)) == x`. La ida y vuelta de bytes
  que genera `#[derive(Layout)]` (cap. 19) es exactamente esta
  forma.
- **Idempotencia**: `normalize(normalize(s)) == normalize(s)`.
- **Invariantes algebraicas**: conmutatividad, asociatividad,
  identidad.
- **Conservación**: el `length` de la salida es el mismo que
  el de la entrada, la suma se mantiene, etc.
- **Monotonía**: si `a < b`, entonces `f(a) < f(b)`.

"Para la entrada 7, sale 14" es un `test`. "Para cualquier
entrada, lo que sale duplica el valor" es un `check`.

## 7.4 `bench "..." { ... }`: medir, no adivinar

La tercera construcción mide **rendimiento**. `bench` toma un
bloque y mide cuánto tarda, repitiéndolo muchas veces:

```kai
fn fib(n: Int) : Int =
  if n < 2 { n } else { fib(n - 1) + fib(n - 2) }

bench "aritmética: 2 + 3 * 4" {
  2 + 3 * 4
}

bench "fib(10)" {
  fib(10)
}

bench "fib(15)" {
  fib(15)
}
```

<!-- transcripto: tiempos, cambian en cada corrida -->
```
$ kai bench ejemplos/cap07/04_bench_basico.kai
  aritmética: 2 + 3 * 4: 1000 iter / median 0 ns / MAD 0 ns / mean 30 ns / range [0, 1000]
  fib(10): recursión sin memo: 1000 iter / median 0 ns / MAD 0 ns / mean 211 ns / range [0, 1000]
  fib(15): el costo crece exponencial: 1000 iter / median 2000 ns / MAD 0 ns / mean 2466 ns / range [2000, 4000]
  list.sum [1..100]: 1000 iter / median 2000 ns / MAD 0 ns / mean 2362 ns / range [2000, 7000]

4 benches
```

Cada bench corre 1000 iteraciones (configurable con `--iters N`)
y reporta cuatro números: la mediana, la MAD (desviación
absoluta mediana), la media y el rango.

Las dos primeras líneas te enseñan a leer el reporte: la
mediana y la MAD salen en 0. Eso no significa que la operación
sea gratis, sino que **no la mediste**: cada
iteración cuesta menos que la resolución del reloj, así que el
reloj devolvió cero todas las veces.

Entonces la media tampoco sirve. Lo único que la separa de
cero es el ruido del scheduler, de donde salen rangos como
`[0, 1000]`. Dos filas con `median 0 / MAD 0` pueden
mostrar medias muy distintas sin que haya ninguna diferencia de
trabajo entre ellas; compararlas es leer ruido.

`median 0 / MAD 0` es un aviso de que hay que medir de otra
forma: haz que cada iteración trabaje
más, o escribe un programa que repita la operación en un loop,
consuma el resultado para que el optimizador no pueda borrarlo,
y cronometra el programa completo. Una medición sólida se ve
como la de `fib(15)`: mediana y media en el mismo orden, y la
MAD chica al lado de ambas.

En un benchmark lo que vale es la **comparación**; el número
absoluto depende de la máquina y de qué más esté corriendo.
Cuando refactorizas una función crítica, corres el bench antes
y después. Cuando tu pipeline se siente lento, comparas las
versiones candidatas. La regla:

> **Optimizar sin medir es adivinar.**

No tiene sentido medir código que no te molesta; pero cuando
algo se arrastra, medir antes de tocarlo te ahorra optimizar lo
que no era el problema.

Tres consejos prácticos:

- **El cuerpo del `bench` es lo que se mide.** Si tu setup es
  caro y no quieres incluirlo, hazlo afuera del bloque y deja
  solo la operación a medir adentro.
- **kaikai no descarta llamadas "puras" sin efecto observable.**
  `bench "fib(10)" { fib(10) }` realmente computa `fib(10)`
  cada iteración. En otros lenguajes con optimizaciones más
  agresivas hay que usar trucos para evitar dead-code
  elimination; aquí no.
- **El número absoluto es solo indicativo.** Para comparar,
  mide en la misma máquina, en la misma sesión, sin otras
  cargas pesadas en paralelo.

## 7.5 Cuándo usar cuál

Elegir entre las tres se reduce a una pregunta:

| Pregunta | Herramienta |
|---|---|
| ¿Para esta entrada concreta, sale lo que espero? | `test` |
| ¿Para **toda** entrada, vale esta invariante? | `check` |
| ¿Cuánto cuesta esta operación? | `bench` |

La parte concurrente queda para §14.9: los actores y las
fibras se prueban con estas mismas tres construcciones, porque
el mailbox es un handler que puedes reemplazar por un guion,
incluido el momento en que vence un plazo, sin esperar.

Las tres se complementan. Un proyecto serio las tiene en el
mismo archivo: tests para los casos contractuales (los del
cliente, los de borde, los que históricamente fallaron), checks
para las invariantes algebraicas que el código preserva, y
benchmarks para las pocas funciones críticas donde el
rendimiento importa.

El orden natural de escritura suele ser:

1. **Empieza con un `test`**: el caso concreto del feature
   que estás desarrollando. Es la más fácil de escribir y de
   mirar cuando algo falla.
2. **Agrega `test`s** para casos límite a medida que
   aparecen.
3. **Pasa a `check`s** cuando ves un patrón en los tests:
   todos comprueban la misma invariante con datos distintos.
   Esa regla general es una propiedad.
4. **Agrega un `bench`** cuando empieces a notar lentitud, o
   antes de un refactor de optimización para tener una línea
   base.

No al revés. Empezar con un `check` cuando todavía no sabes
qué propiedades vas a preservar te lleva a propiedades vagas
que pasan por accidente. Empezar con un `bench` antes de que
el rendimiento importe es optimización prematura. Tests
primero.

## 7.6 Caso de estudio: pruebas para un mini-evaluador

Cerramos con un evaluador chico de expresiones aritméticas
con manejo de errores, probado con las tres herramientas. El código completo está en
`ejemplos/cap07/05_evaluador_pruebas.kai`; aquí lo recorres
por partes.

### El AST y el evaluador

```kai
type Expr
  = Lit(Int)
  | Suma(Expr, Expr)
  | Mul(Expr, Expr)
  | Div(Expr, Expr)

type ErrorEval = DivCero(Int)

fn eval(e: Expr) : Result[Int, ErrorEval] =
  match e {
    Lit(n)     -> Ok(n)
    Suma(a, b) -> {
      let va = eval(a)!
      let vb = eval(b)!
      Ok(va + vb)
    }
    Mul(a, b)  -> { ... }
    Div(a, b)  -> {
      let va = eval(a)!
      let vb = eval(b)!
      if vb == 0 { Err(DivCero(va)) } else { Ok(va / vb) }
    }
  }
```

Es un primo chico del evaluador del cap. 5: cuatro
constructores y una sola categoría de error (división por
cero). Basta para mostrar el flujo.

### Tests para los casos contractuales

```kai
test "literal" {
  assert debe_dar(Lit(42), 42)
}

test "expresión combinada: 2 + 3 * 4 = 14" {
  assert debe_dar(Suma(Lit(2), Mul(Lit(3), Lit(4))), 14)
}

test "división por cero da error" {
  assert debe_fallar(Div(Lit(10), Lit(0)))
}
```

Tres tests, tres comportamientos. `debe_dar` y
`debe_fallar` son helpers que envuelven el `match` sobre
`Result` y devuelven `Bool`, para que el `assert` se mantenga
legible.

```
4/4 tests passed
```

### Checks para las invariantes

```kai
check "Lit(n) evalúa a n" with n: Int {
  debe_dar(Lit(n), n)
}

check "Suma(a, b) == Suma(b, a)" with a: Int, b: Int {
  debe_dar(Suma(Lit(a), Lit(b)), a + b) and
    debe_dar(Suma(Lit(b), Lit(a)), a + b)
}
```

La primera propiedad dice que un literal evalúa a sí mismo:
trivial pero importante, porque si fallara algo está muy mal en
el evaluador. La segunda comprueba que la suma es conmutativa
**a través del evaluador**, no solo en la aritmética entera.

```
2/2 checks passed
```

Cien iteraciones por cada una, con valores al azar, y ninguna
falló. Si alguien rompe la conmutatividad (por ejemplo, con un
efecto secundario al evaluar `Suma` que dependa del orden), los
`check`s detectan el contraejemplo de inmediato.

### Benchmarks para las decisiones de rendimiento

```kai
bench "literal" {
  eval(Lit(42))
}

bench "expresión profunda (3 niveles)" {
  eval(Suma(Mul(Lit(2), Lit(3)), Suma(Lit(4), Mul(Lit(5), Lit(6)))))
}
```

Dos benchmarks: el caso barato (un literal) y un caso más
complejo (tres niveles de anidamiento). En mi máquina:

```
  literal: 1000 iter / median 0 ns / MAD 0 ns / mean 59 ns / range [0, 1000]
  expresión profunda (3 niveles): 1000 iter / median 1000 ns / MAD 0 ns / mean 608 ns / range [0, 2000]
```

Lee esas dos filas con la regla de arriba. La del
literal trae `median 0 / MAD 0`: evaluar `Lit(42)` es más barato
que el reloj, así que esa fila no midió nada y su media es
ruido. La de la expresión profunda sí midió: mediana y media en
el mismo orden.

Este par **no** te autoriza a decir "el segundo cuesta N veces
el primero": para eso necesitas dos cosas medibles, y una no lo
es. Te dice otra cosa, igual de útil: el caso barato está por
debajo de lo que el bench resuelve, y el caro es el que conviene
vigilar si el evaluador empieza a pesar. Si de verdad necesitas la razón
entre ambos, saca el `bench` del medio y cronometra un programa
que repita la operación y consuma el resultado.

### ¿Quién prueba las pruebas?

Todo está verde: cuatro tests, dos checks, cero fallas. Pero
una corrida verde prueba solo que las pruebas pasaron, no que
habrían fallado con el código malo, y eso es lo que de verdad le
pides a una suite.

`kai mutate` lo mide de frente. Rompe el código a propósito, una
construcción a la vez (un brazo de `match` que desaparece, un
`>=` que se vuelve `>`, un `false` que se vuelve `true`), y corre
tus pruebas contra cada versión rota. Si alguna prueba falla, el
mutante muere: algo lo notó. Si todas pasan, el mutante
sobrevive, y eso es un hueco.

```
$ kai mutate --module ejemplos/cap07/05_evaluador_pruebas.kai \
             --oracle 'kai test ejemplos/cap07/05_evaluador_pruebas.kai'
```

El `--oracle` es el comando que decide si el código está sano:
cualquiera que salga con 0 cuando todo anda bien. Por defecto es
`kai test` sobre el paquete; aquí lo apunto a este archivo porque
en `ejemplos/cap07` vive también `02_assert_falla.kai`, que falla
a propósito, y con él en la cuenta todo mutante moriría sin que
nada lo hubiera notado de verdad.

La corrida entera cabe en pantalla:

```
killed    ejemplos/cap07/05_evaluador_pruebas.kai:42  negate
killed    ejemplos/cap07/05_evaluador_pruebas.kai:42  literal
SURVIVED  ejemplos/cap07/05_evaluador_pruebas.kai:50  literal
SURVIVED  ejemplos/cap07/05_evaluador_pruebas.kai:56  literal
killed    ejemplos/cap07/05_evaluador_pruebas.kai:57  literal

survivors — the suite did not notice these:

ejemplos/cap07/05_evaluador_pruebas.kai	50	15	literal
    50c50
    <     Err(_) -> false
    ---
    >     Err(_) -> true
ejemplos/cap07/05_evaluador_pruebas.kai	56	14	literal
    56c56
    <     Ok(_) -> false
    ---
    >     Ok(_) -> true

24 mutants in 18s: 3 killed, 19 did not compile, 2 survived
```

Veinticuatro mutantes y sólo cinco llegaron a las pruebas. Los
otros diecinueve ni siquiera compilaron: el sistema de tipos
trabajó antes que la suite. Cinco vienen de borrar un brazo de un `match`, que lo deja
no exhaustivo, y catorce de elidir una llamada, que deja un `!`
sobre algo que no es un `Result`. Las dos cosas son errores de
compilación en kaikai, así que esos mutantes mueren sin que
ninguna prueba alcance a opinar. `kai mutate` los cuenta en un
casillero aparte porque un mutante que no compila no dice nada
sobre lo que miran tus pruebas. Con match exhaustivo y tipos
fuertes ese casillero se llena harto, así que la mutación mide
un blanco más chico del que esperarías.

Los cinco que sí compilaron son los que hablan. Tres murieron y
dos sobrevivieron, ambos en el mismo lugar incómodo: los helpers
de las pruebas, no el evaluador. La línea 50 es la rama `Err` de `debe_dar`. Ningún
test le pasa a `debe_dar` una expresión que falla, así que nadie
se entera si esa rama dice `true`. Y un `debe_dar` que acepta
errores deja pasar cualquier regresión de `eval` que empiece a
devolver `Err` donde no debe. La línea 56 es el mismo hueco al
revés: nadie le pasa a `debe_fallar` una expresión que evalúa
bien.

Cerrarlos cuesta dos tests de una línea:

```kai
test "debe_dar no acepta un error" {
  assert not debe_dar(Div(Lit(10), Lit(0)), 0)
}

test "debe_fallar no acepta un resultado" {
  assert not debe_fallar(Lit(1))
}
```

Con ellos (el mismo evaluador, en
`ejemplos/cap07/07_mutantes.kai`), la corrida termina así:

```
24 mutants in 18s: 5 killed, 19 did not compile, 0 survived
```

Los cinco mutantes que compilan, ahora todos detectados. Más
no se puede pedir.

Fíjate en lo que no reporta: un porcentaje. `kai mutate` entrega
sobrevivientes, cada uno con archivo, línea y diff, porque un
sobreviviente es algo que puedes arreglar esta tarde y un "92% de
cobertura de mutación" es un número que nadie arregla. Tampoco es
algo para correr en cada commit: cada mutante cuesta una corrida
de tus pruebas. Lo corres cuando te preguntas si esa suite
tan verde está mirando algo.

Una prueba verde dice que tu código pasó. Un mutante que
sobrevive dice qué dejaron de mirar tus pruebas.

### Lo que el archivo no muestra

El archivo declara funciones, tests, checks y benches, todo en
el mismo lugar. Tres comandos lo procesan:

```
$ kai test  ejemplos/cap07/05_evaluador_pruebas.kai
$ kai check ejemplos/cap07/05_evaluador_pruebas.kai
$ kai bench ejemplos/cap07/05_evaluador_pruebas.kai
```

`kai run` y `kai build` ignoran las tres construcciones: el
binario que despliegas carga solo el código de producción.

Esa unificación hace cómodo al modelo. No hay proyecto de tests
aparte ni frameworks que importar ni decisiones sobre dónde
poner cada cosa. La pregunta
"¿dónde están las pruebas de esta función?" tiene una sola
respuesta posible: al lado de la función.

## Ejercicios

**7.1.** Toma una función simple que ya hayas escrito
(puede ser de los capítulos anteriores o algo nuevo) y
escribe tres tests para ella: uno con un caso típico, uno
con un caso límite, y uno con una entrada inválida (si el
tipo lo admite). Corre `kai test` y verifica que pasen los
tres.

**7.2.** Escribe `fn esta_ordenada(xs: [Int]) : Bool` que
devuelva `true` si la lista está ordenada de menor a mayor.
Después escribe un `check` que verifique
`esta_ordenada(list.sort(xs))` para todo `xs : [Int]`. ¿Qué
pasa si tu `esta_ordenada` tiene un bug (por ejemplo,
acepta listas que tienen un elemento "saltado")? El runner
te debería entregar un contraejemplo.

**7.3.** Vuelve al evaluador del §7.6. Agrega un constructor
nuevo `Resta(Expr, Expr)` al `Expr` y la rama
correspondiente en `eval`. ¿Qué tests rompen? ¿Cuáles
tests deberías agregar para cubrir el nuevo caso? ¿Hay
alguna **propiedad nueva** que valga la pena escribir como
`check` (por ejemplo, `Resta(Lit(a), Lit(0)) == Lit(a)`)?

**7.4.** Para una operación de tu elección, escribe dos
implementaciones: una "naive" y una "optimizada". Escribe
un `bench` para cada una. ¿Cuántas veces más rápida es la
optimizada? ¿La diferencia justifica la complejidad
agregada?

**7.5.** Observa atentamente este `check` aparentemente
inocente:

```kai
check "concatenar listas preserva el largo" with xs: [Int], ys: [Int] {
  list.length(list.concat([xs, ys])) == list.length(xs) + list.length(ys)
}
```

¿Qué propiedad expresa? ¿Por qué es trivial pero útil? ¿Qué
debería pasar si alguien (tú, en seis meses, con prisa)
"optimiza" `list.concat` y rompe la propiedad? Escribe el
check, córrelo, y luego prueba romper `list.concat`
mentalmente: ¿en qué iteración crees que el contraejemplo
aparecería?
