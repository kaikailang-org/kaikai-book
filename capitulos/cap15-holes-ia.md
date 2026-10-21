# Capítulo 15 · Holes y kaikai con agentes IA

Este capítulo trata de una herramienta pequeña con una idea
grande detrás. La herramienta es el **hole**: un agujero que
dejas en el código en lugar de una expresión, con un `?` o un
`?nombre`. La idea grande es que el compilador puede **hablarte**
mientras escribes: decirte qué tipo se espera ahí, qué nombres
están en alcance, qué expresiones podrían encajar. El programa
sigue compilando con holes adentro; solo aborta si la ejecución
llega a uno.

El título del capítulo puede confundir: los holes te sirven
aunque nunca uses un LLM. Te permiten diseñar de arriba hacia
abajo (escribir la firma primero, completar el cuerpo después)
y avanzar en partes sin que el archivo entero deje de compilar.

Pero los holes son también la pieza con la que kaikai se
diseña para **agentes IA**. El compilador puede emitir su
reporte como JSON, y un LLM lee ese JSON para entender qué se
le está pidiendo. Esta es la apuesta estratégica del lenguaje
(`design.md` la llama Tier 3): un lenguaje nuevo, sin corpus
de entrenamiento grande, puede ser autoreable por un agente
si las herramientas están bien diseñadas.

Primero, los humanos.

## 15.1 Holes tipados: `?` y `?nombre`

Un hole es una expresión legal en kaikai. Se escribe con `?`
solo, o con `?nombre` si quieres darle identidad:

```kai
fn area_circulo(r: Real) : Real = ?formula
```

Esto compila. La función `area_circulo` existe, tiene la firma
correcta y puedes llamarla desde otras partes del programa.
Cuando la ejecución llega al `?formula`, el programa aborta
con un mensaje claro:

```
$ kai run ejemplos/cap15/01_hole_basico.kai
panic: unfilled hole: ?formula at line 6 col 35
```

Un hole es una **promesa diferida**: te dejaste un agujero que
vas a llenar después, y el sistema te acompaña hasta entonces. El panic te da lo justo para ubicarlo:
el nombre del hole y su posición exacta.

El tipo que el compilador infirió no viaja en el panic, y es lo
primero que vas a querer. Vive en el reporte estructurado, que
usas en serio en el §15.7: `kai build --holes-json` sobre este mismo
archivo devuelve `"expected_type": "Real"` junto con lo que hay
en scope y una lista de candidatos. El panic es para cuando el
programa te sorprende corriendo; el reporte, para cuando te
sientas a llenar el agujero.

El nombre de `?nombre` identifica el hole en los mensajes y,
sobre todo, hace que **dos holes con el mismo nombre dentro de
la misma función compartan tipo**:

```kai
fn clasificar(n: Int) : String {
  if n < 0 {
    ?palabra
  } else {
    ?palabra
  }
}
```

Los dos `?palabra` se unifican: si decides que uno es `String`,
el otro también lo es. Eso reduce la tentación de escribir
implementaciones inconsistentes entre brazos de un `if` o de un
`match`.

Los anónimos (`?` sin nombre) son independientes entre sí.

El mismo `?palabra` en las dos ramas, y lo que pasa cuando el
programa llega a él:

```kai
# ejemplos/cap15/03_hole_compartido.kai
fn clasificar(n: Int) : String {
  if n < 0 {
    ?palabra
  } else {
    ?palabra
  }
}

fn main() : Unit / Stdout {
  # Ambas ramas son `?palabra`, así que el compilador sabe
  # que cualquier valor que escojas para una vale para la
  # otra.
  println(clasificar(-5))
}
```

```
$ kai run ejemplos/cap15/03_hole_compartido.kai
panic: unfilled hole: ?palabra at line 9 col 5
```

## 15.2 La conversación con el compilador

La gracia de los holes está en lo que el compilador te dice de
ellos, más que en abortar bonito. Para cada hole, emite un
**reporte**:

<!-- transcripto: el reporte imprime la ruta completa del archivo; aquí va relativa -->
```
$ kai build ejemplos/cap15/01_hole_basico.kai --holes
ejemplos/cap15/01_hole_basico.kai:6:35: type hole ?formula

  expected: Real

  in scope (local):
    r : Real

  candidates that fit:
    r
    real_sqrt(r)
    real_cbrt(r)
    real_exp(r)
    real_log(r)
    real_log2(r)
    real_log10(r)
    real_sin(r)

  571 more bindings in scope (--holes-scope lists them)
```

Cuatro piezas de información:

- **La cabecera** da la posición y el nombre: `?formula`. Con
  varios holes abiertos a la vez, que es lo normal trabajando
  así, es lo que te dice de cuál habla el bloque.
- **`expected`**: el tipo que la posición del hole exige. El
  compilador lo deduce del contexto: aquí, la función devuelve
  `Real`, el cuerpo es una expresión sola, entonces el hole
  tiene que ser `Real`.
- **`in scope (local)`**: los nombres locales alcanzables desde
  el punto del hole, con su tipo. Aquí solo `r : Real`, el
  parámetro. El `(local)` importa: el reporte te muestra lo
  tuyo y cuenta el resto en la última línea, porque listar las
  casi trescientas cosas que trae el prelude no le sirve a
  nadie. Cuando las quieras, `--holes-scope`.
- **`candidates that fit`**: expresiones que el compilador puede
  sintetizar y que tienen el tipo esperado. La síntesis es
  **bounded**: una sola aplicación de función, con los argumentos
  tomados de lo que hay en alcance, y un tope de ocho propuestas.

Esos ocho candidatos enseñan algo fácil de malentender:
**ninguno es la respuesta**. El área de un círculo es
`3.14 * r * r`, y eso son dos multiplicaciones, o sea dos
aplicaciones, así que la búsqueda no llega. Los candidatos son
una lista de lo que calza en el hueco: te dicen qué tienes a
mano y con qué forma, sin intentar escribir tu función.

Esa es la conversación: mientras la firma es lo único que
sabes, el compilador te ayuda a ver qué se puede poner adentro.
Y cuesta poco: corres `kai build --holes` y lees, sin adivinar.

### La fila de efectos también filtra

Un ejemplo puro esconde una pieza: los candidatos se buscan
contra la fila de efectos **de la posición del hole**, no
contra el programa entero. Dos holes que esperan lo mismo y ven lo
mismo en alcance reciben listas distintas si sus filas difieren:

```kai
# ejemplos/cap15/06_hole_con_efectos.kai
effect Ask {
  pregunta() : String
}

fn saludo(nombre: String) : String = ?texto

fn saludo_interactivo(nombre: String) : String / Ask = ?texto_con_ask
```

El primero no tiene `Ask`, así que `Ask.pregunta()` no calza,
pero el compilador no lo esconde: lo pone aparte con el costo
anotado:

```
  candidates that fit:
    nombre
    to_lower_unicode(nombre)
    ...

  fits if you add `/ Ask`:
    saludo_interactivo(nombre)
    Ask.pregunta()
```

El segundo declara `Ask`, y la misma operación aparece entre los
que calzan sin más:

```
  candidates that fit:
    nombre
    saludo(nombre)
    Ask.pregunta()
    ...
```

Ese "fits if you add" es la parte que más me gusta del reporte:
además de lo que puedes escribir ahí, te dice qué podrías
escribir si estuvieras dispuesto a agregar un efecto más a la
firma. La decisión sigue siendo tuya, pero ahora la tomas
viendo el costo.

## 15.3 Diseño top-down: empieza por la firma

El uso más natural de los holes es el **diseño de arriba hacia
abajo**. Empiezas escribiendo la firma de lo que quieres, sin
saber cómo se va a implementar. Pones un `?` en el cuerpo. El
programa compila. Pasas a la siguiente función.

```kai
fn tokenizar(s: String) : [Token] = ?tokens

fn parsear(ts: [Token]) : Expr = ?ast

fn evaluar(e: Expr) : Int {
  match e {
    Lit(n)        -> n
    Suma(a, b)    -> evaluar(a) + evaluar(b)
    Mul(a, b)     -> evaluar(a) * evaluar(b)
  }
}

fn calcular(s: String) : Int = evaluar(parsear(tokenizar(s)))
```

Tres firmas, una sola función completa (`evaluar`). El archivo
compila. Puedes correr tests sobre `evaluar` con ASTs hechos a
mano, antes de implementar `parsear` o `tokenizar`:

```kai
fn main() : Unit / Stdout {
  let ast = Suma(Lit(3), Mul(Lit(4), Lit(5)))
  println("3 + 4*5 = #{evaluar(ast)}")
}
```

Salida:

```
$ kai run ejemplos/cap15/05_diseno_top_down.kai
3 + 4*5 = 23
```

El programa corre y la evaluación funciona. Ahora llenas los
dos holes uno a uno: implementas `parsear` (toma `[Token]`, da
`Expr`), después `tokenizar` (toma `String`, da `[Token]`).
Cuando llenes el último, el `main` puede llamar a
`calcular("3 + 4*5")` directamente.

Esto contrasta con dos formas de trabajo más comunes:

- **Bottom-up:** implementas las piezas más pequeñas primero, las
  combinas. Funciona, pero a veces descubres que las piezas no
  encajan al final.
- **Big bang:** escribes todo de una vez, no compila hasta el
  final. Funciona si tienes el problema clarísimo. Si no, es
  doloroso.

Top-down con holes es un punto intermedio: la estructura existe
desde el principio y verificas cada pieza conforme la rellenas.

## 15.4 Programas parciales: avanzar con el resto compilando

Con holes, **siempre puedes correr lo que ya tienes**. Si una
función está completa, la pruebas sin esperar a que el archivo
entero esté listo:

```kai
fn duplicar(x: Int) : Int = x * 2

fn promedio(a: Int, b: Int) : Int = ?formula

fn main() : Unit / Stdout {
  println("duplicar(5) = #{duplicar(5)}")
  # promedio no está, pero el archivo compila.
}
```

`duplicar` funciona y `kai run` la imprime. `promedio` espera
ser implementada; mientras no la llames, el programa no se
topa con el hole y corre limpio.

Esto reduce mucho la fricción de mantener un programa "casi
compilando" mientras lo desarrollas. Donde otros lenguajes te
dan un stub cualquiera (`unimplemented()`, `return null`), en
kaikai el `?` es una primitiva del idioma y el compilador sabe
qué tipo tiene.

El archivo completo: lo que está listo corre; el hole espera:

```kai
# ejemplos/cap15/02_programa_parcial.kai
fn duplicar(x: Int) : Int = x * 2

fn promedio(a: Int, b: Int) : Int = ?formula

fn main() : Unit / Stdout {
  # duplicar funciona, podemos probarlo:
  println("duplicar(5) = #{duplicar(5)}")
  # promedio todavía no, pero el archivo compila igual.
  # Si descomentas la línea siguiente, el programa aborta:
  # println("promedio(4, 8) = #{promedio(4, 8)}")
}
```

```
$ kai run ejemplos/cap15/02_programa_parcial.kai
duplicar(5) = 10
```

### `todo!`: el otro stub, y cuándo usarlo

Hay una segunda forma que conviene no confundir con el `?`:

```kai
fn parsear(s: String) : Config = todo!("falta el parser")
```

`todo!` compila a cualquier tipo y revienta si lo alcanzas:

```
$ kai run app.kai
panic: todo: falta el parser
```

Hasta aquí se parece al `?`, que también compila y también
revienta:

```
panic: unfilled hole: ?formula at line 6 col 35
```

La diferencia está en el compilador, no en el runtime. Un `?`
es una **pregunta abierta**: `kai build --holes` lo reporta con
su tipo esperado, los bindings en alcance y los candidatos que
calzan. Un `todo!` no aparece en ese reporte: es una
**decisión tomada** de no escribir eso todavía.

La regla práctica sale sola. Usa `?` cuando no sabes qué va
ahí y quieres que el compilador te ayude a averiguarlo. Usa
`todo!` cuando sí sabes, pero todavía no toca: la rama de error
que vas a llenar después, el caso que no aplica a esta versión.
Si dejas `todo!` en algo que no sabes resolver, el compilador
deja de ofrecerte ayuda que sí tenía.

Un detalle: el mensaje de `todo!` es un literal de string sin
interpolación. `todo!("falta #{n}")` no compila.

## 15.5 Holes en un match: brazo y patrón pendientes

Un hole puede ser el cuerpo de un brazo de `match`:

```kai
type Forma
  = Circulo(Real)
  | Cuadrado(Real)
  | Triangulo(Real, Real)

fn area(f: Forma) : Real {
  match f {
    Circulo(r)       -> 3.14 * r * r
    Cuadrado(l)      -> l * l
    Triangulo(b, h)  -> ?formula_triangulo
  }
}
```

Aquí el `match` ya cubre los tres constructores; solo falta la
expresión del último brazo. El compilador verifica
exhaustividad (cap. 5 §5.4), da el `match` por completo y
reporta el hole con `Real` como tipo esperado y `b`, `h` en
alcance.

Si en vez de dejar el brazo con un hole lo borras, el
compilador te avisa que el `match` ya no es exhaustivo y te
nombra la variante que falta. Los holes son ortogonales a la
verificación de patrones; cada uno hace su trabajo.

Si lo que te falta es el patrón, el hole va a la izquierda de
la flecha:

```kai
fn area(f: Forma) : Real {
  match f {
    Circulo(r)  -> 3.14 * r * r
    Cuadrado(l) -> l * l
    ?           -> 0.0
  }
}
```

`kai build --holes` lo reporta como **pattern hole** y te
lista lo que el `match` todavía no cubre:

```
forma.kai:10:5: pattern hole

  expected: a pattern matching Forma

  remaining inhabitants (exhaustiveness):
    Triangulo(_, _)
```

El `match` con un brazo pendiente: los dos casos resueltos
corren sin ruido, y el hole se queda esperando a que alguien
llame con un `Triangulo`.

```kai
# ejemplos/cap15/04_hole_en_patron.kai
type Forma
  = Circulo(Real)
  | Cuadrado(Real)
  | Triangulo(Real, Real)

fn area(f: Forma) : Real {
  match f {
    Circulo(r) -> 3.14 * r * r
    Cuadrado(l) -> l * l
    Triangulo(b, h) -> ?formula_triangulo
  }
}

fn main() : Unit / Stdout {
  println("círculo 3 -> #{area(Circulo(3.0))}")
  println("cuadrado 4 -> #{area(Cuadrado(4.0))}")
}
```

```
$ kai run ejemplos/cap15/04_hole_en_patron.kai
círculo 3 -> 28.259999999999998
cuadrado 4 -> 16
```

## 15.6 La apuesta LLM: lenguaje diseñado para agentes

Hasta aquí usaste los holes como herramienta para humanos. Lo
más estratégico del capítulo es que **los holes son también la
puerta de entrada para que un agente IA escriba kaikai**.

El razonamiento es simple. Un LLM aprende un lenguaje del
**corpus** disponible en su entrenamiento. Lenguajes con mucho
corpus (Python, JavaScript) son fáciles de generar para los
modelos; lenguajes nuevos, con poco código público, son
difíciles. Si kaikai esperara a tener un corpus grande, perdería
el experimento.

La alternativa es diseñar el lenguaje para que quien le enseñe
al agente sea el compilador y no el corpus. Si el compilador
dice con precisión qué falta y dónde cada vez que el LLM
produce código incorrecto, el LLM puede iterar hasta el
programa correcto en pocos pasos.

La pieza clave es la **salida estructurada**: el compilador
emite JSON que el agente lee directamente, sin parseo
heurístico. Tres canales son relevantes:

1. **`kai typecheck --holes-json`**: el reporte de holes en
   formato JSON.
2. **`kai typecheck --library-mode`**: el tipo de la expresión
   en una línea y columna, entre otras consultas.
3. **`kai typecheck --diags-json`**: los diagnósticos del
   compilador (errores de tipo, matches no exhaustivos,
   efectos no manejados) en JSON.

En el cap. 5 §5.4 viste cómo se ve un mensaje de match no
exhaustivo en formato humano. La versión JSON trae el mismo
diagnóstico como datos: severidad, archivo, línea, columna y
mensaje, y en la lista `related` cada nota (la variante que
falta, las cubiertas, la sugerencia) con su propia ubicación.
Un agente lo recorre sin heurísticas de parseo y sabe dónde
agregar el brazo que falta.

## 15.7 La salida JSON de los holes

El reporte JSON lleva los mismos datos que el reporte humano,
sin el formateo:

```json
[
  {
    "file": "ejemplos/cap15/01_hole_basico.kai",
    "line": 6, "col": 35,
    "kind": "hole",
    "name": "formula",
    "message": null,
    "expected_type": "Real",
    "in_scope": [
      {"name": "r", "type": "Real"}
    ],
    "scope_elided": 567,
    "candidates": [
      {"expr": "r", "kind": "synth"},
      {"expr": "real_sqrt(r)", "kind": "synth"},
      {"expr": "real_cbrt(r)", "kind": "synth"},
      {"expr": "real_exp(r)", "kind": "synth"},
      {"expr": "real_log(r)", "kind": "synth"},
      {"expr": "real_log2(r)", "kind": "synth"},
      {"expr": "real_log10(r)", "kind": "synth"},
      {"expr": "real_sin(r)", "kind": "synth"}
    ],
    "candidates_needing_effects": [],
    "doc": null
  }
]
```

Cada hole es un objeto y el array tiene tantos elementos como
holes haya en el archivo. Cuatro campos no tienen equivalente
impreso en el reporte humano, y para un agente valen oro:
`kind` separa un `?` (`"hole"`) de un `todo!` (`"todo"`), con el
texto del `todo!` en `message`; `scope_elided` dice cuántos
bindings quedaron fuera de `in_scope`; `candidates_needing_effects`
trae los candidatos del "fits if you add" con la fila que les
falta; y `doc` el docstring de la función que contiene el hole.

Para un humano esto es ruidoso; para un agente es exactamente
lo que necesita. Esa exactitud tiene un efecto práctico: que
el agente acierte al primer intento en vez de al tercero es
lo que separa una herramienta usable de una que solo estorba.

## 15.8 Más allá de holes: información rica como interfaz

Los holes son la primera pieza del patrón general. Otras
herramientas del compilador siguen el mismo principio: emitir
información estructurada que un agente puede consumir.

- **`kai typecheck --library-mode`** responde consultas que
  el archivo trae en comentarios `# @probe <tipo> L:C`. Con
  `# @probe type 4:14`, devuelve un objeto JSON con el campo
  `type` de la expresión en esa posición; `def` dice dónde
  está declarado un nombre, y `sig` la firma de la llamada
  que lo encierra.
- **`kai test --json`** corre los tests y emite una línea JSON
  por test, con `id`, `file`, `line`, `status` y
  `duration_ms`, más un `message` cuando falla, y al final una
  línea `summary` con los totales.
- **`kai typecheck --effects-json`** entrega, por función, la
  fila de efectos inferida y los handlers que instala.

La regla común: el agente nunca tiene que parsear texto. La
información llega ya estructurada.

## 15.9 Un loop de trabajo con un agente

Cuando trabajas con un agente IA sobre kaikai, el flujo
razonable es este:

1. **El humano escribe la firma y los tests.** Define qué se
   espera del programa. Pone holes en los cuerpos.
2. **El agente lee la salida `kai typecheck --holes-json`.**
   Sabe qué tipo se espera, qué bindings están en alcance, qué
   candidatos son razonables. Genera una propuesta de
   implementación. Usa `typecheck` y no `build` a propósito: el
   reporte es el mismo, pero cada consulta cuesta solo el
   front-end (cap. 16 §16.1), y en un loop esa diferencia se
   multiplica.
3. **El agente corre `kai test`**, y `kai check` si hay
   propiedades. Si todo pasa, sigue adelante. Si no, el test
   que falla o el contraejemplo de la propiedad le dice qué
   está mal.
4. **El agente itera.** Lee el fallo, ajusta, propone otra
   implementación.

De este flujo, tres cosas:

- **El humano decide el qué.** La firma, los tests, las
  propiedades son las que dicen qué debe hacer el programa.
- **El agente decide el cómo.** El cuerpo de las funciones,
  las estructuras intermedias, los detalles de
  implementación.
- **El compilador media.** Es el árbitro: dice si la propuesta
  cumple con los tipos, con los tests, con las propiedades.
  El agente nunca acepta nada sin que el compilador haya
  dicho que pasa.

Es lo opuesto al patrón "el LLM escribe el código y el humano
revisa": la especificación es del humano, el cuerpo es del
agente, y el compilador es quien concilia a los dos.

## 15.10 Lo que el lenguaje no automatiza

Los holes son una herramienta de comunicación con el
compilador, y el juicio del programador queda fuera de su
alcance. Hay cosas que el compilador no puede decir, y que
ningún `--holes-json` va a entregarte:

- **Qué función necesita tu programa.** Si decides que
  `area_circulo` debe existir, eso es decisión tuya. El
  compilador no va a inventar la firma por ti.
- **Cómo se llaman las cosas.** Si nombras tu función
  `process_data` en vez de `transform_records`, ningún hole
  te va a corregir. El gusto y la legibilidad son tuyos.
- **Si la arquitectura tiene sentido.** Que el compilador
  acepte una pieza no significa que la pieza esté en el lugar
  correcto. Decidir qué pertenece a cada módulo, qué efectos
  expone cada función, cuándo extraer una abstracción: eso es
  diseño, y el diseño es humano.

Hay una idea recurrente en mi blog sobre esto: las
herramientas no reemplazan el juicio, lo apalancan cuando
están bien diseñadas. El compilador con holes y agentes lleva
una parte mecánica del trabajo (los detalles que satisfacen
las restricciones de tipo). La otra parte (qué construir, qué
abstraer, qué priorizar) sigue siendo del programador.

## 15.11 Caso de estudio: completar una función no trivial

Cerramos con un ejercicio realista. Imagina que quieres
escribir una función que toma una lista de pares
`[(String, Int)]` representando notas de estudiantes, y
devuelve los nombres de quienes aprobaron (nota >= 4) en
orden alfabético.

El humano escribe la firma y dos tests:

```kai
fn aprobados(notas: [(String, Int)]) : [String] = ?cuerpo

test "lista vacía" {
  assert aprobados([]) == []
}

test "filtra y ordena" {
  let r = aprobados([("Carmen", 5), ("Ana", 3), ("Berta", 6)])
  assert r == ["Berta", "Carmen"]
}
```

El agente corre `kai typecheck --holes-json` y recibe:

```json
[
  {
    "file": "notas.kai",
    "line": 1, "col": 51,
    "kind": "hole",
    "name": "cuerpo",
    "message": null,
    "expected_type": "[String]",
    "in_scope": [
      {"name": "notas", "type": "[Pair[String, Int]]"}
    ],
    "scope_elided": 566,
    "candidates": [],
    "candidates_needing_effects": [
      {"expr": "Env.args()", "kind": "synth", "effects": ["Env"]},
      {"expr": "args()", "kind": "synth", "effects": ["Env"]}
    ],
    "doc": null
  }
]
```

El agente sabe: tipo esperado `[String]`, una entrada `notas` de
tipo `[Pair[String, Int]]`, que es la forma con que el compilador
imprime `[(String, Int)]`, como viste en §4.6. Y sabe algo más
útil todavía: `candidates` viene **vacío**. La síntesis es bounded y
aquí no alcanza para nada; los dos que aparecen detrás de un
efecto son `Env.args()`, que no tiene nada que ver con el
problema. El compilador fue honesto: de esta no te salvo. El
agente tiene que proponer algo sustantivo. Una primera propuesta:

```kai
fn aprobados(notas: [(String, Int)]) : [String] =
  notas
    |? (.snd >= 4)
    | .fst
    |> list.sort
```

El agente corre `kai test`. Los dos tests pasan: el filtro deja
a Carmen y Berta (notas 5 y 6) y descarta a Ana (nota 3), y
`list.sort` sobre `[String]` las deja en orden lexicográfico
ascendente. Con los dos tests en verde, el agente termina.

El humano nunca tocó el cuerpo. El compilador validó tipos y
tests. El agente iteró si hizo falta.

¿Es siempre así de limpio? No. Hay funciones donde el agente
falla tres veces antes de acertar. Hay funciones donde el
contraejemplo del test es ambiguo y el agente no sabe qué
ajustar. Pero el costo de cada iteración es bajo (segundos), y
el costo de equivocarse es transparente (el compilador o el
test reporta exactamente qué está mal).

## 15.12 Filosofía: tres ideas que vale recordar

1. **Holes son una primitiva de diálogo.** A diferencia de
   `null` o `unimplemented()`, son una forma legal de expresión
   que compila, que el compilador entiende y para la que emite
   información estructurada. El humano la usa para diseñar
   top-down; el agente la usa como punto de entrada.

2. **El compilador es la interfaz del lenguaje.** Lo que el
   compilador dice (tipos esperados, errores, contraejemplos,
   candidatos) es lo que define qué se puede hacer en kaikai.
   Diseñar bien esa salida (humana y JSON) es lo que vuelve
   al lenguaje accesible a humanos y a agentes por igual.

3. **El humano dice el qué; el agente dice el cómo; el
   compilador verifica.** Es el reparto que kaikai propone
   para el trabajo asistido por IA. Cada parte hace lo que
   mejor sabe hacer. Ninguna reemplaza a las otras.

## Ejercicios

**15.1.** Toma una función simple que conozcas (digamos
`fn sumar_pares(xs: [Int]) : Int`). Escribe la firma con un
`?cuerpo` y los tests que esperarías. Sin mirar la
implementación, escribe tres propuestas de cuerpo a mano y
córrelas. ¿Cuántos intentos te toma encontrar la versión
correcta?

**15.2.** Escribe una función con dos brazos de un `if`, donde
cada brazo es un `?nombre` con el mismo nombre. Verifica que
el compilador unifica el tipo de los dos. Después cambia uno
de los nombres y observa: ahora cada brazo tiene tipo
independiente. ¿En qué casos te conviene cada forma?

**15.3.** Lee `kai build --holes-json` sobre un archivo con
tres holes en posiciones distintas. ¿Qué información comparten
todos los holes? ¿Qué información es específica de cada uno?

**15.4.** (Requiere acceso a un agente IA.) Toma una función
del cap. 5 (digamos el evaluador de expresiones del §5.7) y
borra el cuerpo de una de las ramas del `match`, reemplazándolo
por un `?nombre`. Pídele al agente que la complete usando solo
la salida JSON del compilador como entrada. ¿Qué tan rápido lo
resuelve?

**15.5.** Discute con un colega: ¿qué partes del trabajo que
haces hoy programando son las que un agente podría hacer si
le das suficiente información estructurada del compilador? ¿Qué
partes seguro que no? ¿Por qué?
