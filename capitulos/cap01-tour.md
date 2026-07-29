# Capítulo 1 · Tour de kaikai

La mejor forma de conocer un lenguaje es leerlo y correrlo. Este
capítulo es un recorrido panorámico por kaikai en diez
programas cortos. Ninguno pasa de unas treinta líneas, todos
compilan, y juntos cubren las formas que vas a ver una y otra
vez en el resto del libro: declaraciones, tipos algebraicos,
pattern matching, efectos, fibras, protocolos, unidades de
medida, contratos, pruebas inline y holes tipados.

No vamos a explicar cada detalle todavía. La idea es que termines
el capítulo con el lenguaje mirado desde arriba y la sensación de
que ya puedes leer código kaikai aunque te falten precisiones.
Esas precisiones llegan en los capítulos siguientes.

Si quieres seguir los ejemplos en tu computador, los archivos
están en `ejemplos/cap01/` del repositorio del libro. La
instalación de `kai` viene al final del capítulo, en §1.12; si
te urge, salta ahí primero y vuelve.

## 1.1 Hola, kaikai

Empezamos por lo más viejo del repertorio.

```kai
fn main() {
  println("Hola, kaikai")
}
```

```
$ kai run ejemplos/cap01/01_hola.kai
Hola, kaikai
```

Cuatro cosas que mirar antes de seguir:

- Todo programa kaikai parte en `fn main()`. No hay archivo de
  configuración, no hay `package main`, no hay clase contenedora.
  Una función con ese nombre, en algún archivo, alcanza.
- `fn` declara funciones. Es una palabra clave corta a propósito;
  vas a escribirla mucho.
- Las llaves `{ ... }` agrupan un bloque de instrucciones, pero
  un bloque también es una expresión: el último valor que produce
  es el valor del bloque. Aquí no nos interesa, pero lo vas a usar.
- `println` no requiere `import`. Está disponible en todos los
  programas porque escribe a la salida estándar mediante un
  efecto que kaikai trae por defecto. En el capítulo 12 vamos a
  abrir esa caja; por ahora basta con que funciona.

No hay punto y coma al final de la línea. No hay `return` para
funciones que no devuelven nada. Tampoco hace falta declarar el
tipo de retorno de `main` cuando no devuelve un valor útil. Todo
eso es por diseño: kaikai trata de no pedirte que escribas lo
obvio.

## 1.2 Tipos algebraicos y `match`: FizzBuzz

El típico ejercicio de la entrevista, escrito en kaikai, se ve
así:

```kai
type Tag
  = Both
  | Fizz
  | Buzz
  | Other(Int)

fn classify(n: Int) : Tag {
  if n % 15 == 0     { Both }
  else if n % 3 == 0 { Fizz }
  else if n % 5 == 0 { Buzz }
  else               { Other(n) }
}

fn label(c: Tag) : String {
  match c {
    Both     -> "FizzBuzz"
    Fizz     -> "Fizz"
    Buzz     -> "Buzz"
    Other(n) -> int_to_string(n)
  }
}

fn loop(i: Int, n: Int) : Unit / Stdout {
  if i <= n {
    println(label(classify(i)))
    loop(i + 1, n)
  }
}

fn main() {
  loop(1, 15)
}
```

Lo interesante de esta versión no es la salida (`1, 2, Fizz,
4, Buzz, ...` la produce cualquier lenguaje), sino lo que
hicimos para llegar ahí.

Definimos un **tipo suma**: `Tag` es uno de cuatro
constructores. Tres son nombres pelados (`Both`, `Fizz`, `Buzz`)
y uno carga un dato (`Other(Int)`). Si vienes de un lenguaje
imperativo, esto se parece a un `enum` con datos. Si vienes de
un lenguaje OO, se parece a una jerarquía sellada de
subclases. La diferencia es que en kaikai esta declaración no
trae herencia, no trae métodos virtuales, no trae nada salvo lo
que ves: cuatro maneras de construir un valor de tipo `Tag`.

`classify` decide cuál de los cuatro construir. Fíjate en el
`if`: no tiene `then`, no tiene paréntesis alrededor de la
condición, y cada rama es un bloque que produce un valor. El
`if` mismo es una expresión que devuelve `Tag`, y el cuerpo de
la función es esa expresión, sin `return` ni asignación
intermedia. Esto es lo que en el capítulo 2 vamos a llamar
**expresión, no sentencia**, y es uno de los pocos cambios de
hábito que vas a tener que hacer.

`label` consume un `Tag` con `match`. Cada rama es un
**patrón** seguido de `->` y la expresión que devuelve. El
patrón `Other(n)` no solo dice "es del constructor `Other`",
también desempaca el dato y lo amarra al nombre `n`, listo
para usarse a la derecha. Es destructurar, comparar y declarar
una variable en un solo paso.

`loop` es recursivo. No hay `while`, no hay `for`. Bueno, no
para esto: en el capítulo 6 vamos a ver que kaikai sí tiene
formas más cómodas para iterar, pero la base es la recursión.
Y para que esa base no le cueste a tu programa, el lenguaje
garantiza **tail-call optimisation**: una llamada recursiva en
posición de cola no consume stack. `loop(1, 1_000_000)`
funciona sin reventar.

Una sola cosa que va a parecer rara y que dejamos para el
capítulo 12: la firma de `loop` dice `: Unit / Stdout`. La parte
después del `/` es el conjunto de **efectos** que la función usa.
`Stdout` significa "esta función escribe al terminal". Si no
estuviera ahí, el compilador no te dejaría llamar a `println`
adentro. Por ahora no te preocupes; el detalle viene completo
más adelante.

## 1.3 Una calculadora con AST recursivo

Pasemos a algo con un poco más de chicha. Una calculadora muy
simple, con expresiones aritméticas representadas como árbol.

```kai
type Expr
  = Lit(Int)
  | Add(Expr, Expr)
  | Mul(Expr, Expr)
  | Neg(Expr)

fn eval(e: Expr) : Int {
  match e {
    Lit(n)    -> n
    Add(l, r) -> eval(l) + eval(r)
    Mul(l, r) -> eval(l) * eval(r)
    Neg(x)    -> -eval(x)
  }
}

fn main() {
  let e = Add(Lit(2), Mul(Lit(3), Lit(4)))
  println(int_to_string(eval(e)))
}
```

```
$ kai run ejemplos/cap01/03_calculadora.kai
14
```

`Expr` es un tipo suma como el de FizzBuzz, con una diferencia:
**se menciona a sí mismo en sus propios constructores**. `Add`
recibe dos `Expr`. `Mul` también. `Neg` recibe uno. El resultado
es que un valor de tipo `Expr` puede ser un árbol de cualquier
profundidad.

Esa es la herramienta clave para representar lenguajes,
configuraciones, consultas, comandos, casi cualquier estructura
con anidamiento. La vas a ver mucho. En el capítulo 5 dedicamos
una sección entera a este patrón.

`eval` recorre el árbol con `match`. Cada caso recurre sobre
los hijos. La exhaustividad la verifica el compilador: si
agregas un constructor a `Expr` y se te olvida una rama en
`eval`, no compila. Esto es enorme y va a salvarte muchas
horas. El capítulo 5 lo explora con calma; por ahora confía.

`let` introduce un binding local. El tipo se infiere del lado
derecho. No hay `var`, no hay `mutable`, no hay reasignación:
`let e = ...` ata `e` a un valor y ese valor no cambia. Si
necesitas mutar algo, kaikai te lo permite, pero te pide
declararlo (capítulo 13). Esta es la otra mitad del cambio de
hábito: **inmutabilidad por defecto**.

## 1.4 Un efecto propio con su handler

Hasta ahora todo el "efecto" que vimos fue `println`, que
funciona porque kaikai trae un handler por defecto. Veamos
qué pasa cuando declaramos un efecto nuevo.

```kai
effect Log {
  log(msg: String) : Unit
}

fn greet(name: String) : Unit / Log {
  Log.log("hola, " ++ name)
}

fn main() {
  handle {
    greet("kaikai")
    greet("mundo")
  } with Log {
    log(msg, resume) -> {
      println("[INFO] " ++ msg)
      resume(())
    }
  }
}
```

```
$ kai run ejemplos/cap01/04_efecto.kai
[INFO] hola, kaikai
[INFO] hola, mundo
```

Este es el ejemplo que más probablemente te haga frenar la
lectura. Es deliberado. Los efectos algebraicos son la apuesta
distintiva de kaikai y queremos que los veas funcionando antes
de que te los expliquemos en serio.

Lo que está pasando es lo siguiente:

- `effect Log { log(msg: String) : Unit }` declara un nuevo
  efecto llamado `Log` con una operación, `log`, que recibe un
  string y devuelve nada.
- `greet` usa esa operación. Su firma, `: Unit / Log`,
  declara que la función tiene el efecto `Log`, sin decir cómo
  se realiza ese efecto. `greet` es agnóstica: no sabe si los
  mensajes van al terminal, a un archivo, a la nada.
- Quien decide es `handle ... with Log { ... }`. Ahí, en el
  cuerpo de `main`, decimos: "para este bloque, cuando alguien
  invoque `Log.log(msg)`, ejecuta este código". El handler
  imprime el mensaje con un prefijo `[INFO]` y le pasa la
  ejecución a `resume(())`, que continúa el programa donde
  había quedado.

Esto se parece a try/catch, a un dependency injection container,
a un middleware, a callbacks. Pero **es una sola idea** que
subsume a las cuatro. Si la primera vez te confunde, está bien.
Volvemos en el capítulo 12 con tiempo y con varios ejemplos antes
de pedirte que escribas un handler tuyo.

Lo que sí conviene retener desde ya: el tipo de `greet` te dice
que necesita `Log`. El compilador no te deja llamarla desde un
contexto donde `Log` no esté manejado. Los efectos son **visibles
en el tipo**, no escondidos. Esto resuelve una incomodidad vieja
de los lenguajes que tienen excepciones invisibles.

## 1.5 Dos fibras cooperativas

El quinto programa del tour usa concurrencia.

```kai
import spawn

fn worker(tag: String, n: Int) : Unit / Stdout + Spawn {
  if n > 0 {
    println(tag)
    spawn.yield()
    worker(tag, n - 1)
  }
}

fn main() {
  let f = spawn.spawn(() => worker("B", 3))
  worker("A", 3)
  spawn.await(f)
}
```

```
$ KAI_THREADS=1 kai run ejemplos/cap01/05_concurrente.kai
A
B
A
B
A
B
```

Una **fibra** es una unidad de ejecución cooperativa. Pesa
mucho menos que un thread del sistema operativo y vive dentro
del proceso. `spawn.spawn` agenda una fibra nueva pero no la
arranca de inmediato; el scheduler la levanta en el próximo
punto de cooperación. `spawn.yield` es justamente eso: un
punto donde la fibra actual dice "puedo esperar, dale paso a
otra".

Sin los `spawn.yield`, el `worker` "A" correría sus tres
iteraciones antes de soltarle el turno a "B". Con ellos, la
salida queda alternada.

El `KAI_THREADS=1` del comando merece una nota. Por defecto,
kaikai reparte las fibras sobre tantos hilos del sistema como
núcleos tenga tu máquina, y entonces el orden entre `A` y `B`
lo decide el scheduler: cambia de corrida en corrida. Con un
solo hilo, `spawn.yield` es lo único que reparte los turnos y
la alternancia queda visible. Es una muleta pedagógica para
este ejemplo, no cómo vas a correr tus programas; el capítulo
13 lo desarma en serio.

La firma de `worker` es `: Unit / Stdout + Spawn`. Dos
efectos: el que ya conocíamos para imprimir, y `Spawn` para
levantar y coordinar fibras. El operador `+` compone efectos:
una función puede tener varios al mismo tiempo, declarados en
su tipo.

`(() => worker("B", 3))` es una **lambda**: una función anónima
sin parámetros que llama a `worker`. La pasamos como argumento
a `spawn.spawn` para que la corra dentro de la fibra nueva.

Hay mucho que decir sobre el modelo de concurrencia de kaikai
(por qué las fibras son aisladas, cómo se cancelan, qué pasa
con la memoria), pero todo eso vive en el capítulo 13. Lo que
importa para el tour es que el lenguaje tiene concurrencia
estructurada de primera clase y que se trata, una vez más,
como un efecto.

## 1.6 Tipos a la medida con protocolos

A esta altura ya viste tipos primitivos y tipos suma. Falta una
construcción más: los **records**, que son lo que en la mayoría
de los lenguajes llamarías un *struct*: un agregado con campos
nombrados.

```kai
type Punto = { x: Int, y: Int }
```

Y con eso aparece la pregunta natural: ¿cómo se le "agregan
operaciones" a un tipo? Por ejemplo, ¿cómo le decimos al
compilador que mi `Punto` sabe imprimirse como string?

La respuesta de kaikai son los **protocolos**: un contrato con
nombre y un puñado de operaciones, que cualquier tipo puede
satisfacer. Es el equivalente conceptual a las interfaces de
Go, los traits de Rust o los protocols de Clojure y Elixir.

```kai
#[derive(Show)]
type Punto = { x: Int, y: Int }

fn main() {
  let p = Punto { x: 3, y: 4 }
  println(show(p))
}
```

```
$ kai run ejemplos/cap01/07_protocolos.kai
Punto { x: 3, y: 4 }
```

`Show` es uno de los protocolos del stdlib (`Eq`, `Ord`,
`Hash`, `Show`, `Serialize`). Su contrato es una sola
operación: dado un valor, devolver un `String`. La línea
`#[derive(Show)]` arriba del record le dice al compilador que
**genere automáticamente** una implementación de `Show` para
`Punto`, recorriendo los campos y delegando en el `Show` de
cada uno. Como `Int` ya implementa `Show` en el stdlib, el
record entero queda cubierto sin que tengamos que escribir
nada más.

Si quisieras una implementación a mano, en vez de `#derive`
escribirías:

```kai
impl Show for Punto {
  fn show(p: Punto) : String =
    "(" ++ show(p.x) ++ ", " ++ show(p.y) ++ ")"
}
```

Y `show(Punto { x: 3, y: 4 })` ahora devolvería `"(3, 4)"` en
vez del formato del record.

Lo importante para el tour: **kaikai elige single-dispatch
explícito**, no typeclasses al estilo Haskell. No hay
inferencia de constraints, no hay tipos de orden superior, no
hay polimorfismo paramétrico ad-hoc encadenado. Una sola
mecánica simple, igual que en Go o Clojure. El capítulo 9
desarrolla la idea.

## 1.7 Unidades de medida

kaikai trae una herramienta poco común en lenguajes
*mainstream*: las **unidades de medida**. F# las tiene desde
2010 y prácticamente ningún otro lenguaje las ofrece de
fábrica. La idea es marcar un número con una unidad
(`Real<USD>`, `Real<m/s>`, `Int<Seconds>`) y dejar que el
compilador rechace mezclas incompatibles.

```kai
unit USD
unit EUR

fn main() {
  let precio : Real<USD> = 1.50<USD>
  let total  : Real<USD> = precio + 2.00<USD>
  println("total = #{total}")
}
```

```
$ kai run ejemplos/cap01/08_unidades.kai
total = 3.5 USD
```

`unit USD` declara una unidad. `1.50<USD>` es un literal
anotado. `Real<USD>` es el tipo de un real con esa unidad. Y
si intentas:

```kai
let mezcla = precio + 1.00<EUR>     # error: USD ≠ EUR
```

el compilador se queja antes de que el programa corra. Esto
captura una clase entera de bugs que normalmente se descubren
en producción: el clásico de Mars Climate Orbiter[^mco], el
de sumar saldos en monedas distintas, el de pasar un timeout
en milisegundos donde se esperaban segundos.

[^mco]: La sonda Mars Climate Orbiter de la NASA se perdió en
    septiembre de 1999 al entrar en la atmósfera marciana. La
    causa raíz: un módulo de software calculaba el empuje en
    libras-fuerza por segundo (unidades imperiales) y el otro
    leía ese valor como newtons por segundo (unidades métricas).
    Nadie había anotado las unidades en la interfaz. La misión
    costó 327 millones de dólares.

Lo más bonito del esquema es que **las unidades se borran en
tiempo de compilación**. El binario que produce `kai build`
opera con `Real` plano, sin overhead. Es la misma promesa que
hacen los efectos: la información vive en el tipo y no cuesta
nada cuando el programa corre.

El tema da para mucho más: unidades genéricas, álgebra de
unidades (`m/s^2`, `kg * m / s^2`), conversiones explícitas, y
una variante muy útil llamada *branded types* que marca strings
y enteros con tags como `UserId` o `OrderId` para que el
compilador no te deje confundirlos. Todo eso aparece en el
capítulo 10. Por ahora basta saber que existe.

## 1.8 Programación por contrato

kaikai trae otra herramienta heredada de pocos lenguajes
(Eiffel en los ochenta, Ada 2012, D) para declarar lo que una
función espera de quien la llama y lo que garantiza a cambio:
las **precondiciones** y **postcondiciones**.

```kai
fn divide(a: Int, b: Int) : Int
  requires b != 0
  ensures  result * b + (a % b) == a
= a / b

fn main() {
  println("10 / 2 = #{divide(10, 2)}")
  println("17 / 3 = #{divide(17, 3)}")
}
```

```
$ kai run ejemplos/cap01/09_contratos.kai
10 / 2 = 5
17 / 3 = 5
```

`requires b != 0` dice "esta función exige que `b` no sea
cero al momento de llamarla". El compilador hace dos cosas
con esa precondición: si puede **probarla en tiempo de
compilación** (porque los argumentos son literales o porque
ya conoce los rangos posibles), rechaza la llamada antes de
emitir código: `divide(10, 0)` literal es un error de
compilación, no de ejecución. Si los argumentos son
dinámicos y el compilador no alcanza a decidir, inserta un
assert que se verifica **al entrar** a la función, y el
programa aborta si la precondición falla.

`ensures result * b + (a % b) == a` dice "esta función
garantiza que la identidad fundamental de la división entera
se cumple al salir". `result` es un nombre reservado dentro
del `ensures` que se refiere al valor de retorno. Esta
postcondición se verifica **al salir** del cuerpo: si por
algún bug interno la función devolviera algo que no cumple,
el programa también aborta.

Los contratos no son comentarios. Son código que el compilador
emite como verificaciones reales: estáticas cuando puede,
dinámicas cuando hace falta. El día que algo viole un
contrato, vas a saberlo en el lugar exacto.

¿En qué se diferencian de las pruebas que vienen en la próxima
sección? Una prueba dice "para esta entrada específica, espero
esta salida específica". Un contrato dice "para **toda**
entrada que cumpla esta precondición, la salida cumple esta
postcondición". Una es un caso fijo; el otro, una promesa
universal documentada en la firma.

Hay un mecanismo hermano que kaikai usa para extender la
misma idea a los **valores**, no a las operaciones: los
**refinement types**, que te dejan declarar tipos como `Int
where >= 0` o `Real where 0.0 <= self <= 1.0`. Son la
contraparte estructural de los contratos: el tipo describe qué
valores son válidos, el contrato describe qué hacen las
operaciones con ellos. Los dos viven juntos en el capítulo 11.

## 1.9 Pruebas en el mismo archivo

kaikai trata las pruebas como ciudadanas de primera: viven en
el mismo archivo que el código que prueban, con su propia
sintaxis al lado de las funciones.

```kai
fn cuadrado(n: Int) : Int = n * n

test "cuadrado de cero" {
  assert cuadrado(0) == 0
}

test "cuadrado preserva positivos" {
  assert cuadrado(7) == 49
}

test "cuadrado de negativos" {
  assert cuadrado(-5) == 25
}
```

```
$ kai test ejemplos/cap01/06_pruebas.kai
  ok   cuadrado de cero
  ok   cuadrado preserva positivos
  ok   cuadrado de negativos

3/3 tests passed
```

`test "..." { ... }` es un bloque top-level. Adentro usas
`assert` para escribir aserciones: si una falla, el test
falla y el runner sigue con los siguientes. En una build
normal (`kai run`, `kai build`) los bloques `test` se
ignoran: no agregan peso al binario que despliegas.

Hay dos parientes cercanos que usan la misma forma:

- **`check "..." with x: T { ... }`** declara una **propiedad**
  que el runner verifica con valores generados al azar. Es lo
  que en otros lenguajes se llama property-based testing.
- **`bench "..." { ... }`** es un benchmark: el runner ejecuta
  el bloque muchas veces y reporta nanosegundos por iteración.

Las tres formas se complementan: `test` para casos fijos,
`check` para invariantes que deben valer sobre cualquier
entrada, `bench` para medir rendimiento sin adivinar. El
capítulo 7 entra en cada una con tiempo.

## 1.10 Holes: agujeros que compilan

Hay una última construcción del lenguaje que vale la pena
ver en el tour, porque cambia un poco la forma de escribir
código. kaikai te permite dejar **agujeros** en lugares donde
todavía no sabes qué poner, y el programa compila igual.

```kai
fn area_circulo(r: Real) : Real = ?formula

fn perimetro_circulo(r: Real) : Real = ?

fn main() {
  println("compiló: el cuerpo está pendiente")
}
```

```
$ kai run ejemplos/cap01/10_holes.kai
compiló: el cuerpo está pendiente
```

`?` y `?nombre` son **expresiones tipadas**. El compilador
acepta el programa, infiere el tipo esperado en cada
agujero (en `?formula`, sabe que tienes que producir un
`Real`), y te deja el resto del archivo compilando. Si
alguien llama a `area_circulo` en runtime sin haber
rellenado el agujero, el programa aborta con
`panic: unfilled hole`. Como `main` no la llama, el
programa de arriba termina bien.

¿Para qué sirve esto? Para tres cosas:

- **Diseñar de arriba hacia abajo.** Escribes la firma de la
  función, dejas el cuerpo en `?`, y compilas. El compilador
  te dice qué tipo se espera ahí y qué valores tienes en
  alcance. Conversas con el compilador antes de escribir el
  cuerpo.
- **Avanzar con un programa parcial.** Tienes diez funciones
  por escribir, pero quieres que el programa compile para
  correr la primera y ver si la idea va. Las otras nueve
  quedan en `?`; el código compila; pruebas la primera; el
  resto espera.
- **Trabajar con un agente IA.** Le pasas la firma con holes
  al agente y le pides que los rellene. La doc del compilador
  se diseñó para que esa información (tipo esperado,
  bindings en alcance, candidatos posibles) se pueda emitir
  como JSON estructurado, listo para alimentar al agente.

Las dos primeras son útiles para el programador humano. La
tercera es la apuesta más estratégica del lenguaje: kaikai
quiere ser un lenguaje en el que un LLM pueda escribir bien
aun cuando su corpus de entrenamiento contenga poco kaikai,
porque el compilador hace gran parte del trabajo. El
capítulo 15 entra en esa apuesta con tiempo.

## 1.11 Dependencias y proyectos: `kai.toml`

Hasta aquí los ejemplos del tour fueron archivos sueltos. La
realidad de un proyecto es distinta: vas a tener varios
archivos, vas a depender de bibliotecas que otros publicaron,
y vas a querer que tu colega clone el repo y obtenga
exactamente la misma compilación que la tuya.

kaikai resuelve esto con un manifest mínimo, **`kai.toml`**:

```toml
name = "mi_app"
version = "0.1.0"

[dependencies]
manutara = "github.com/kaikailang-org/manutara@v0.1"
local    = { path = "../local-thing" }
```

El flujo del día a día son tres comandos:

```
$ kai init                                       # crea kai.toml en el directorio actual
$ kai add github.com/kaikailang-org/manutara@v0.1          # agrega una dependencia
$ kai run main.kai                               # compila y corre
```

`kai add` clona el repositorio de la dependencia, lo cachea
bajo `~/.cache/kai/pkg/` direccionado por SHA, y actualiza
dos archivos: `kai.toml` (qué se quería) y **`kai.lock`** (qué
versión exacta se resolvió). El lockfile es lo que garantiza
**builds reproducibles**: cuando tu colega clone el repo y
corra `kai install`, va a obtener bit-por-bit las mismas
dependencias que tú.

La resolución de dependencias es **git-first**: una URL puede
ser un tag (`@v0.1`), una rama (`@main`) o un commit
específico (`@abc123`). No hace falta registry centralizado,
no hace falta TLS, no hace falta autenticarse. Si el repo está
en GitHub, GitLab o tu servidor privado de git, kaikai sabe
ir a buscarlo.

El capítulo 8 cubre esto con detalle: cómo organizar un
proyecto en módulos, qué entra en `[dependencies]`, cómo
funciona la selección de versiones cuando dos dependencias
piden cosas distintas. Por ahora basta saber que existe y que
**no necesitas un sistema de build externo**: `kai` es el
único binario.

## 1.12 Cómo instalar y correr `kai`

Para correr cualquiera de los programas anteriores necesitas el
binario `kai`. La vía corta es el instalador:

```
$ curl -fsSL https://raw.githubusercontent.com/kaikailang-org/kaikai/main/install.sh | sh
```

Descarga el último release, verifica su SHA-256, lo deja bajo
`~/.kaikai/` y agrega `~/.kaikai/bin` al `PATH` de tu shell. Si
prefieres Homebrew, `brew install kaikailang-org/kaikai/kaikai`
llega al mismo lugar. El binario es autocontenido — trae su
propio LLVM adentro, no necesitas toolchain aparte —, aunque por
ahora los releases preconstruidos cubren macOS sobre Apple
Silicon.

En otras plataformas se compila desde el fuente, que vive en
[github.com/kaikailang-org/kaikai](https://github.com/kaikailang-org/kaikai)
y solo pide un compilador de C:

```
$ make tier0
$ ./bin/kai run examples/minimal/hello.kai
```

`make tier0` construye la cadena de bootstrap completa — stage 0
(escrito en C), stage 1 (kaikai-minimal) y stage 2, el compilador
auto-hosteado que usas en el día a día — y corre las baterías
rápidas para confirmar que quedó sana.

Instalado una vez, el compilador se actualiza solo:

```
$ kai upgrade
```

consulta el último release y, si es más nuevo que el que tienes,
lo descarga, lo verifica y lo reemplaza en su lugar. Si ya estás
al día, te lo dice y no toca nada.

A partir de ahí, los comandos que vas a usar a lo largo del
libro son tres:

```
$ kai run archivo.kai     # compila y ejecuta
$ kai build archivo.kai -o nombre   # produce un binario nativo
$ kai test archivo.kai    # ejecuta los bloques `test "..." { ... }` del archivo
```

`kai run` es el comando que más vas a teclear mientras lees el
libro. Edita un archivo, córrelo, mira la salida, vuelve a editar.

El capítulo 16 cubre el resto del tooling: `fmt`, `lsp`,
integración con editores, y los comandos de paquetes (`init`,
`add`, `install`, `update`). Por ahora con `run` te basta.

## 1.13 Cómo está organizado el resto del libro

Vimos en este capítulo, sin profundizar, prácticamente todo lo
que hace distinto a kaikai. El resto del libro toma cada cosa y
la trata en serio.

- **Parte II: El lenguaje** (capítulos 3 a 11) cubre los
  tipos básicos, los tipos compuestos, los tipos suma y
  `match`, las funciones, las pruebas y benchmarks, los
  módulos, los protocolos, las unidades de medida y la
  programación por contrato. Es la mitad sólida y predecible.
- **Parte III: Lo distintivo** (capítulos 12 a 15) toma los
  efectos algebraicos, la concurrencia con fibras, los actores
  y la apuesta del lenguaje en torno a los LLMs. Es la mitad
  donde kaikai paga su novedad.
- **Parte IV: Práctica** (capítulos 16 y 17) se ocupa del
  tooling y cierra con un caso de estudio integrador.
- Antes, el **capítulo 2** te ablanda algunas asunciones si
  vienes de un mundo imperativo: expresiones vs sentencias,
  inmutabilidad por defecto, `Option` en vez de `null`,
  efectos visibles. Es un capítulo corto pero útil.

Si vienes de Haskell, OCaml, Elixir o Scala, puedes saltarte
el capítulo 2 e incluso ojear rápido la Parte II; lo nuevo
para ti vive en la Parte III. Si vienes de Python, Go, Java,
JavaScript o C#, lee el capítulo 2 sin prisa y haz los
ejercicios de la Parte II.

En cualquier caso: el código de los ejemplos está en
`ejemplos/` del repositorio del libro. Compila todo. Corre
todo. La única forma de aprender un lenguaje es escribirlo.
