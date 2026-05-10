# Capítulo 7 · Pruebas, propiedades y benchmarks

Hasta acá estuviste escribiendo funciones y mirando la salida.
Es un ciclo razonable mientras tu programa cabe en la cabeza,
pero no escala. Apenas tu código pasa de unas decenas de
líneas — apenas hay más de tres funciones que se llaman entre
sí —, dejas de poder verificar a ojo que cada cambio
mantiene el comportamiento.

Para eso están las pruebas. kaikai trae **tres construcciones
top-level** dedicadas: `test`, `check` y `bench`. Las tres
viven en el mismo archivo del código que prueban, las tres se
ejecutan vía el driver `kai`, y las tres se ignoran cuando
construyes un binario para producción.

Este capítulo recorre las tres, explica cuándo usar cuál, y
cierra con un caso de estudio: un mini-evaluador con tests
contractuales, propiedades verificadas, y benchmarks que
miden cuánto cuesta cada operación.

## 7.1 `test "..." { ... }` y `assert`

La forma más simple es un test con un nombre y un cuerpo:

```kai
fn cuadrado(n: Int) : Int = n * n

test "cuadrado de cero" {
  assert cuadrado(0) == 0
}

test "casos pequeños" {
  assert cuadrado(3) == 9
  assert cuadrado(7) == 49
}
```

`test` es un **bloque top-level** — convive con `fn` en el
mismo archivo, no se anida en otra función. Su nombre es un
literal de string que el runner reporta tal cual. Adentro vas
escribiendo aserciones con `assert`: una expresión `Bool` que
debe ser `true`. Si todas las aserciones del bloque pasan, el
test pasa. Si **una** falla, el test falla y el runner sigue
con los siguientes.

El nombre del test debería decir **qué se está probando**, no
cómo. "cuadrado de cero" es bueno; "test 1" no.

`assert` también acepta un mensaje opcional con coma:

```kai
test "rangos válidos" {
  let n = clasificar(42)
  assert n > 0, "se esperaba positivo, no #{n}"
}
```

El mensaje aparece cuando la aserción falla. Es útil cuando
la expresión que evaluaste no transmite por sí sola qué fue
lo inesperado.

### Lo que el runner imprime

```
$ kai test ejemplos/cap07/01_test_basico.kai
  ok   caso base
  ok   casos pequeños
  ok   caso significativo

3/3 tests passed
```

Si un test falla, el output cambia para mostrarlo:

```
$ kai test ejemplos/cap07/02_assert_falla.kai
  ok   doble preserva positivos
  FAIL test roto: el assert va a fallar : assertion failed
  ok   este test sigue corriendo

2/3 tests passed
```

Tres detalles que vale recordar:

- **Los tests se ejecutan en orden de declaración.** Tu archivo
  los lista de arriba a abajo y el runner los corre en ese
  orden. No hay paralelismo dentro de un mismo archivo.
- **Un test que falla no detiene a los demás.** El runner sigue
  con los tests siguientes y reporta el conteo final.
- **Los bloques `test` no terminan en el binario de producción.**
  `kai run` y `kai build` los descartan. Solo se compilan y se
  ejecutan bajo `kai test`.

## 7.2 `kai test` y el ciclo de feedback corto

El comando es directo:

```
$ kai test mi_archivo.kai
```

Compila el archivo en modo `--test` (que activa los bloques
`test`), produce un binario, lo ejecuta, y reporta. El ciclo
edición → prueba toma uno o dos segundos en archivos chicos.

Si llamas a `kai test` sin nombre de archivo, no hay un
descubrimiento automático estilo `pytest` o `cargo test`. Eso
es deliberado — kaikai todavía no tiene un layout de proyecto
estándar — pero conviene saber el flujo: tú apuntas al archivo,
el runner corre todo lo que ese archivo y sus imports declaren
con `test`.

Hay tres recomendaciones prácticas que vas a internalizar a
las pocas semanas:

- **Tests al lado del código, en el mismo archivo.** No los
  separes en `tests/` o en archivos paralelos. Cuando tocas
  una función, los tests de esa función están al ojo.
- **Un test por aspecto, no por línea.** Si tu función tiene
  un caso base, casos pequeños y un caso de borde, escribe
  tres `test`. Si dentro de "casos pequeños" hay tres
  ejemplos, agrégalos como tres `assert` en el mismo bloque.
- **Nombres descriptivos.** El nombre va a aparecer en la
  salida del runner cada vez que corras los tests.
  `"validar email rechaza espacios"` se entiende; `"test_3"`
  no.

## 7.3 `check "..."` — propiedades

Los tests que viste hasta acá comprueban **casos fijos**:
"para esta entrada, espero esta salida". Es lo que en otros
lenguajes se conoce como "example-based testing". Es lo más
común, pero tiene un límite obvio: solo prueba lo que escribes.

Las **propiedades** invierten la cosa. En vez de "para `cuadrado(7)`
espero `49`", escribes "para todo `n` entero, `cuadrado(n)`
debe ser `>= 0`". El runner genera valores de `n` al azar y
verifica la propiedad sobre cada uno. Si encuentra un
contraejemplo, te lo muestra; si pasa cien iteraciones sin
falla, considera la propiedad probada.

```kai
fn doble(n: Int) : Int = n * 2

check "doble es par" with n: Int {
  doble(n) % 2 == 0
}

check "suma conmutativa" with a: Int, b: Int {
  a + b == b + a
}

check "reverse de reverse" with xs: [Int] {
  list.reverse(list.reverse(xs)) == xs
}
```

`check "..." with name: Type { body }` declara una propiedad.
La cláusula `with` lista los parámetros que el runner va a
generar al azar; el `body` es una expresión `Bool` que tiene
que ser `true`.

```
$ kai check ejemplos/cap07/03_check_propiedades.kai
  doble es par: 100 iter, OK
  suma conmutativa: 100 iter, OK
  suma asociativa: 100 iter, OK
  reverse de reverse: 100 iter, OK

4/4 checks passed
```

Cien iteraciones por propiedad es el default; cada iteración
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
en la primera iteración que falló. Eso te dice tres cosas:

- La propiedad es falsa para algún valor de `n`.
- El valor concreto.
- En qué iteración falló (útil para reproducir con la misma
  semilla si quieres depurar).

A diferencia de un `test` con un caso fijo, donde el nombre
del test es lo que diagnostica el fallo, un `check` te
entrega el caso de prueba **junto con** el reporte. No tienes
que escribirlo: lo tienes.

### Cuándo escribir un `check`

Las propiedades son útiles cuando puedes **enunciar una
verdad universal** sobre tu código. Algunos ejemplos
comunes:

- **Inversas**: `decode(encode(x)) == x`,
  `parse(format(x)) == x`.
- **Idempotencia**: `normalize(normalize(s)) == normalize(s)`.
- **Invariantes algebraicas**: conmutatividad, asociatividad,
  identidad.
- **Conservación**: el `length` de la salida es el mismo que
  el de la entrada, la suma se mantiene, etc.
- **Monotonía**: si `a < b`, entonces `f(a) < f(b)`.

Si lo que quieres comprobar es "para la entrada 7, sale 14",
eso es un `test`. Si es "para cualquier entrada, lo que sale
duplica el valor", es un `check`.

## 7.4 `bench "..." { ... }` — medir, no adivinar

La tercera construcción es para **performance**. `bench` toma
un bloque y mide cuánto tarda en ejecutarse, repetido muchas
veces para sacar promedio:

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

```
$ kai bench ejemplos/cap07/04_bench_basico.kai
  aritmética: 2 + 3 * 4: 1000 iter / 7 ns/iter
  fib(10): recursión sin memo: 1000 iter / 92 ns/iter
  fib(15): el costo crece exponencial: 1000 iter / 1063 ns/iter
  list.sum [1..100]: 1000 iter / 4305 ns/iter

4 benches
```

Cada bench corre 1000 iteraciones (configurable con
`KAI_BENCH_ITERS`) y reporta nanosegundos por iteración.

Lo importante de los benchmarks no es el número absoluto —
depende de la máquina y de qué más esté corriendo —, sino la
**comparación**. Cuando refactorizas una función crítica,
corres el bench antes y después. Cuando tu pipeline empieza
a sentirse lento, comparas las versiones de funciones
candidatas. La regla:

> **Optimizar sin medir es adivinar.**

Si tu código no anda lento, no lo benchees. Si anda lento, no
lo optimices sin medirlo primero. Los `bench` son la
herramienta que cierra ese ciclo.

Tres consejos prácticos:

- **El cuerpo del `bench` es lo que se mide.** Si tu setup es
  caro y no quieres incluirlo, hazlo afuera del bloque y deja
  solo la operación a medir adentro.
- **kaikai no descarta llamadas "puras" sin efecto observable.**
  `bench "fib(10)" { fib(10) }` realmente computa `fib(10)`
  cada iteración. En otros lenguajes con optimizaciones más
  agresivas hay que usar trucos para evitar dead-code
  elimination; aquí no.
- **El número absoluto es indicativo, no autoridad.** Para
  comparar, mide siempre en la misma máquina, en la misma
  sesión, sin otras cargas pesadas corriendo en paralelo.

## 7.5 Cuándo usar cuál

Ya tienes las tres herramientas. La decisión se reduce a una
pregunta simple:

| Pregunta | Herramienta |
|---|---|
| ¿Para esta entrada concreta, sale lo que espero? | `test` |
| ¿Para **toda** entrada, vale esta invariante? | `check` |
| ¿Cuánto cuesta esta operación? | `bench` |

Las tres se complementan. Un proyecto serio va a tener las
tres en el mismo archivo: tests para los casos
contractuales (los del cliente, los de borde, los que
históricamente fallaron), checks para las invariantes
algebraicas que el código preserva, y benchmarks para las
pocas funciones críticas donde la performance importa.

Una nota sobre el orden de escritura. La secuencia natural
suele ser:

1. **Empieza con un `test`** — el caso concreto del feature
   que estás desarrollando. Es la prueba más fácil de
   escribir y la más fácil de mirar cuando algo falla.
2. **Agrega `test`s** para casos de borde a medida que
   aparecen.
3. **Pasa a `check`s** cuando ves un patrón en los tests:
   "todos estos casos están comprobando la misma invariante,
   pero con datos distintos". Eso es señal de que una
   propiedad debería capturar la regla general.
4. **Agrega un `bench`** cuando empieces a notar lentitud, o
   antes de un refactor de optimización para tener una línea
   base.

No al revés. Empezar con un `check` cuando todavía no sabes
qué propiedades vas a preservar te lleva a propiedades vagas
que pasan por accidente. Empezar con un `bench` antes de que
la performance importe es optimización prematura. Tests
primero.

## 7.6 Caso de estudio: pruebas para un mini-evaluador

Cerramos con un ejemplo integrador: un evaluador chico de
expresiones aritméticas con manejo de errores, probado con
las tres herramientas. El código completo está en
`ejemplos/cap07/05_evaluador_pruebas.kai`; acá lo recorremos
por partes.

### El AST y el evaluador

```kai
type Expr
  = Lit(Int)
  | Suma(Expr, Expr)
  | Mul(Expr, Expr)
  | Div(Expr, Expr)

type ErrorEval = DivCero(Int)

fn eval(e: Expr) : Result[ErrorEval, Int] =
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

Es un primo más chico del evaluador del cap. 5: cuatro
constructores, una sola categoría de error (división por
cero). Suficiente para mostrar el flujo.

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

Tres tests que documentan tres comportamientos. `debe_dar` y
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

Dos propiedades. La primera dice que un literal evalúa a sí
mismo — una invariante trivial pero importante: si fallara,
algo está muy mal en el evaluador. La segunda comprueba que
la suma es conmutativa **a través del evaluador**, no solo
a nivel de aritmética entera.

```
2/2 checks passed
```

Cien iteraciones por cada una con valores generados al azar.
Ninguna falló. Si en el futuro alguien rompe la
conmutatividad — por ejemplo, agregando un efecto secundario
al evaluar `Suma` que dependa del orden — los `check`s
detectan el contraejemplo de inmediato.

### Benchmarks para las decisiones de performance

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
literal:                       1000 iter / 15  ns/iter
expresión profunda (3 niveles): 1000 iter / 134 ns/iter
```

El segundo es ~9 veces más caro que el primero. Esa es la
información que necesitas si más adelante decides que el
evaluador es un cuello de botella: sabes contra qué línea
base estás midiendo.

### Lo que el archivo no muestra

No hay magia. El archivo declara funciones, declara tests,
declara checks, declara benches, todo en el mismo lugar.
Tres comandos lo procesan:

```
$ kai test  ejemplos/cap07/05_evaluador_pruebas.kai
$ kai check ejemplos/cap07/05_evaluador_pruebas.kai
$ kai bench ejemplos/cap07/05_evaluador_pruebas.kai
```

Y `kai run` y `kai build` ignoran las tres construcciones.
El binario que despliegas no carga ni los tests ni los
checks ni los benches — solo el código de producción.

Esa unificación es lo que hace al modelo cómodo. No hay
proyecto de tests aparte, no hay frameworks que importar, no
hay decisiones sobre dónde poner cada cosa. La pregunta
"¿dónde están las pruebas de esta función?" tiene una sola
respuesta posible: al lado de la función.

## Ejercicios

**7.1.** Toma una función simple que ya hayas escrito —
puede ser de los capítulos anteriores o algo nuevo —, y
escribe tres tests para ella: uno con un caso típico, uno
con un caso de borde, y uno con un input inválido (si el
tipo lo admite). Corre `kai test` y verifica que pasen los
tres.

**7.2.** Escribe `fn esta_ordenada(xs: [Int]) : Bool` que
devuelva `true` si la lista está ordenada de menor a mayor.
Después escribe un `check` que verifique
`esta_ordenada(list.sort(xs))` para todo `xs : [Int]`. ¿Qué
pasa si tu `esta_ordenada` tiene un bug — por ejemplo,
acepta listas que tienen un elemento "saltado"? El runner
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
mentalmente — ¿en qué iteración crees que el contraejemplo
aparecería?
