# Capítulo 2 · Pensar en kaikai

El capítulo 1 te mostró el lenguaje desde arriba. Antes de bajar
al detalle de tipos, funciones y módulos, conviene detenerse un
momento en algunos hábitos que kaikai pide y que probablemente
no traigas si vienes de Python, Java, Go, JavaScript o C#.

Este es el capítulo más corto del libro, y se puede saltar. Si
ya programaste en Haskell, OCaml, Elixir o Scala, esto te va a
sonar familiar; pasa a la Parte II y nos vemos en el capítulo
3. Si vienes de un mundo imperativo, dedícale los veinte minutos
que pide. Te van a ahorrar incomodidades en las siguientes
ciento cincuenta páginas.

No vamos a abrir la teoría de cada idea: eso es trabajo de los
capítulos siguientes. Lo que quiero aquí es nombrar el cambio de
hábito, mostrarlo, y darte las palabras para reconocerlo cuando
aparezca. A mí me tomó años hacer estos hábitos míos, y sospecho
que buena parte de ese tiempo se fue en no tener a nadie que me
los nombrara.

## 2.1 Expresiones, no sentencias

En la mayoría de los lenguajes que probablemente conoces, el
código se construye con dos tipos distintos de pieza:

- **Expresiones**, que producen un valor: `x + 1`, `f(2)`, `a == b`.
- **Sentencias**, que no producen valor sino que ejecutan algo: un
  `if` con dos ramas, un `for`, un `return`, una asignación.

Las sentencias necesitan armarse en una secuencia. Las
expresiones, no: se componen anidándose.

kaikai borra esa frontera. **Casi todo es expresión.** Un `if`
produce un valor. Un `match` produce un valor. Un bloque
`{ ... }` produce un valor: el de la última expresión adentro.
Una función no necesita `return` porque su cuerpo *es* la
expresión que devuelve.

Compara dos formas de escribir lo mismo. En el estilo imperativo
clásico:

```
String s;
if (x > 0) {
  s = "positivo";
} else {
  s = "no positivo";
}
print(s);
```

En kaikai:

```kai
let s = if x > 0 { "positivo" } else { "no positivo" }
println(s)
```

La diferencia no es de líneas sino de pensamiento. En la versión
imperativa hay que **declarar `s` primero**, porque el `if` no
sabe devolver nada; después hay que **mutar `s` en cada rama**.
En kaikai, el `if` *es* el valor, y `s` se ata directo al
resultado: no hay una declaración separada de la asignación,
no hay asignación en absoluto. `s` se ata una vez y no cambia.

Esto tiene consecuencias prácticas que vas a notar pronto:

- **Menos líneas, sin perder claridad.** Lo que antes eran tres
  pasos (declarar, decidir, asignar) se convierte en uno.
- **Menos variables temporales.** Si solo necesitas un valor
  para pasarlo a la siguiente función, lo armas inline.
- **Menos errores de "olvidé inicializar".** No hay variables
  declaradas-pero-sin-valor.
- **Refactor más fluido.** Una expresión se puede extraer a una
  función o reemplazar por otra expresión sin tocar el contexto
  alrededor; una sentencia, no tanto.

Este fue el primer punto que fijé cuando empecé a diseñar kaikai,
antes que los efectos y antes que los kinds. Todo lo demás se
acomodó alrededor.

Vas a ver lo mismo en `match`. En la mayoría de los lenguajes con
`switch`, cada `case` es una sentencia que ejecuta un bloque y
después rompe (o sigue, según las reglas del lenguaje). En
kaikai, `match` es una expresión que devuelve un valor, y cada
rama es la expresión que ese valor podría ser. Lo viste en el
capítulo 1, en `label` y en `eval`. Volverás a verlo
constantemente.

Una pieza relacionada: el cuerpo de una función puede tomar dos
formas, y la elección entre ellas comunica intención.

```kai
fn doble(x: Int) : Int = x * 2

fn clasificar(x: Int) : String {
  if x < 0 { "negativo" }
  else if x == 0 { "cero" }
  else { "positivo" }
}
```

Con `=` y una sola expresión, cuando la función es directa.
Con `{ ... }` cuando hay varios pasos o conviene visualmente
separar. El compilador acepta ambas; la diferencia es para quien
lee.

Una consecuencia útil de tener todo como expresión es que las
**transformaciones encadenadas** se vuelven cómodas. kaikai trae
del mundo Elixir el operador pipe `|>`:

```kai
xs |> filter(es_par) |> map(doble) |> list.length
```

equivale a `list.length(map(filter(xs, es_par), doble))`. La
versión con pipe se lee de izquierda a derecha, en el orden en
que ocurren las transformaciones, y no requiere variables
intermedias. Solo es posible porque cada paso es una expresión
que se puede componer con la siguiente.

`|>` es el más general de cuatro operadores que kaikai ofrece
para encadenar. Los otros tres (`|` map sobre listas, `||`
flat-map y `|?` filter) son atajos para los casos que
aparecen una y otra vez. Los vemos en detalle en el capítulo 6.

## 2.2 Inmutabilidad por defecto

`let x = 5` ata `x` al valor `5`. Eso es todo. No hay forma de
escribir `x = 6` después. Si tu código necesita "cambiar `x`",
en kaikai eso significa una de dos cosas:

- En realidad necesitas un valor nuevo, derivado del primero. La
  forma correcta es atar otro nombre, o redefinir `x` en un
  ámbito interno.
- En realidad necesitas mutación visible. Eso es un caso real
  pero pequeño, y kaikai te lo da, pero te pide declararlo. La
  mutación de un array, por ejemplo, vive bajo el efecto
  `Mutable`, que aparece en la firma de cualquier función que la
  use. Lo veremos con calma en el capítulo 13.

¿Por qué tomar este camino? Porque la mayoría de las veces
"cambiar una variable" es una limitación heredada del modelo
imperativo, no una necesidad real. Cuando programas con valores
que no cambian:

- **El razonamiento se vuelve local.** Si `x` se ató a `5` en la
  línea 12, sigue siendo `5` en la línea 30. Punto. No hay que
  buscar quién lo modificó en el medio.
- **La concurrencia se simplifica.** Dos fibras pueden mirar el
  mismo valor sin sincronización; nadie va a sobrescribirlo.
- **Los bugs disminuyen.** Una clase entera de errores
  ("esperaba X, pero al final del método era Y") simplemente no
  existe.
- **Los tests son más simples.** Una función pura (entrada,
  salida, sin estado escondido) se prueba dándole entradas y
  comparando salidas. Eso es todo.

Una nota sobre vocabulario. La forma habitual de atar un nombre
es `let`, que es inmutable. Para los casos en que de verdad
necesitas una celda mutable local (un contador, un acumulador,
un cursor), kaikai te da `var`. El `:=` es la única marca de
mutabilidad: declara la celda, la escribe, y un nombre desnudo
la lee.

```kai
var n := 0
n := n + 1
println(int_to_string(n))   # 1
```

Aquí está la cosa interesante: `var` no es realmente una
construcción nueva del lenguaje, es **azúcar sintáctico** sobre
el efecto `State`. La línea `var n := 0` se reescribe a un
`handle ... with State[Int](0) as n { ... }` que abarca el
resto del bloque. Leer `n` se reescribe a `n.get()`, y `n := v` a
`n.set(v)`. El lenguaje base es el mismo de los efectos
algebraicos del capítulo 12; lo que cambia es la cara que muestra
para los casos comunes.

Lo importante para tu modelo mental es que esa traducción ocurre
**dentro del bloque**: el `handle` se abre y se cierra ahí
mismo, así que el efecto `State` no se asoma a la firma de la
función. Una función con `var` adentro tiene la misma firma que
si no lo tuviera.

Mutaciones más visibles (escribir un array que vive más allá
del bloque, enviar a la mailbox de otro actor, modificar memoria
que se observa desde fuera) sí aparecen en la firma, bajo
efectos como `Mutable`, `Actor` o los que correspondan. Esa
distinción la veremos en el capítulo 13.

La regla práctica es simple: usa `let` por defecto; si
necesitas una variable local que cambia, `var` con `:=`;
si lo que quieres mutar es algo visible desde afuera, ya
estamos en territorio de efectos y vas a tener que declararlos.

## 2.3 `Option` y `Result` en vez de `null` y excepciones

La pregunta más vieja al diseñar un lenguaje: ¿qué hace una
función cuando no puede devolver lo que prometió?

La respuesta de C, Java, Python, JavaScript y un largo etcétera
es **mentir**: la función dice que devuelve un `Usuario`, pero
en algunos casos devuelve una variable mágica llamada `null` (o
`None`, o `nil`) que **no es un usuario** y que el sistema de
tipos no distingue del valor real. El que llama tiene que
recordar comprobarlo. Tony Hoare, que inventó la referencia
nula en 1965, llamó a esa decisión su "error de mil millones de
dólares".

La otra respuesta tradicional es lanzar una excepción. La
función no devuelve nada y, sin avisar al sistema de tipos,
desvía el control a algún `catch` lejano. Cuál `catch`, eso
depende. A veces no hay ninguno y el programa muere.

kaikai elige una tercera vía, vieja en la familia ML pero todavía
poco común fuera de ella: **codificar la posibilidad de fallar
en el tipo de retorno**.

```kai
type Option[a] = None | Some(a)
type Result[a, e] = Ok(a) | Err(e)
```

Una función que puede no encontrar el resultado devuelve
`Option[Usuario]`: o `Some(usr)` cuando lo encuentra, o `None`
cuando no. Una función que puede fallar de varias maneras
devuelve `Result[Usuario, Error]`: o `Ok(usr)`, o
`Err(razón)`. En ambos casos, el tipo te obliga a considerar
las dos posibilidades.

Compara:

```python
# Python: el que llama tiene que recordar
def buscar(id: int) -> Usuario:
    ...   # a veces devuelve None, a veces no, mira la doc

usr = buscar(7)
print(usr.nombre)   # crash si usr es None
```

```kai
# kaikai: el tipo lo dice
fn buscar(id: Int) : Option[Usuario] = ...

let r = buscar(7)
match r {
  Some(usr) -> println(usr.nombre)
  None      -> println("no encontrado")
}
```

En la versión kaikai, el `match` es exhaustivo: si te olvidas
del caso `None`, no compila. El compilador te recuerda lo que
en Python depende de tu memoria.

¿Y las excepciones? kaikai tiene un mecanismo equivalente, los
efectos algebraicos del capítulo 12, con los que se declara en
tres líneas un efecto que aborta. Pero también ahí lo que puede
fallar aparece en el tipo. Las "excepciones invisibles" que en
Java o Python pueden brotar de cualquier llamada, en kaikai no
existen. Si una función puede saltar a otro lado, su firma lo
declara.

Esto cambia la sensación de programar. En vez de envolver cada
llamada externa en un `try` por las dudas, lees la firma, ves
qué puede fallar, y decides ahí mismo qué hacer.

### Una nota sobre `!`

En kaikai, el operador postfix `!` aplica a un `Option` o un
`Result` y propaga el caso negativo: si el valor es `Ok(v)` o
`Some(v)`, la expresión vale `v` y el programa sigue; si es
`Err(e)` o `None`, la función actual termina ahí mismo
devolviendo ese `Err` o `None` a quien llama.

```kai
fn cargar() : Result[Usuario, Error] {
  let id = parsear_id(input)!        # si falla, propaga
  let datos = leer_archivo(id)!      # idem
  Ok(armar_usuario(id, datos))
}
```

Es lo mismo que el `?` de Rust. Y conviene mencionar lo que
**no** es: en Elixir hay una convención de nombrar `File.read!`
a la versión que lanza excepción en vez de devolver un tuple
`{:ok, _} | {:error, _}`. En kaikai la convención es la
inversa: `!` no es parte de un nombre, es un operador, y
**nunca lanza una excepción**. Solo desempaca el caso feliz y
propaga el caso negativo a través del tipo de retorno. Si
viste muchos `File.read!` en código Elixir y te pone
nervioso, puedes relajarte: en kaikai esa misma sintaxis está
del lado seguro.

## 2.4 Pattern matching como herramienta de control de flujo

En un lenguaje imperativo, decidir qué hacer según la forma de
un dato suele tomar tres pasos:

1. **Comprobar la forma** con `if`, `instanceof`, `is`,
   `typeof`, o un campo discriminador.
2. **Acceder a los datos** que vienen con esa forma, con casts,
   `as`, o accesos por nombre que asumen lo del paso 1.
3. **Hacer algo** con esos datos.

kaikai junta los tres en una sola construcción: `match`.

```kai
match expr {
  Lit(n)    -> n
  Add(l, r) -> eval(l) + eval(r)
  Mul(l, r) -> eval(l) * eval(r)
  Neg(x)    -> -eval(x)
}
```

Cada rama es un **patrón** seguido de la expresión que ese
patrón produce. `Lit(n)` no solo dice "esto fue construido con
`Lit`", también declara que `n` es el `Int` que vino adentro,
listo para usarse a la derecha. Comprobar, desempacar y nombrar
en una sola pieza.

Los patrones se anidan. Si tienes una `Option[Result[Int, Error]]`
y quieres distinguir las tres formas posibles, lo escribes así:

```kai
match x {
  None              -> "no había"
  Some(Err(razón))  -> "falló: " ++ razón
  Some(Ok(valor))   -> "ok: " ++ int_to_string(valor)
}
```

Los patrones también pueden traer **guardas** (condiciones
adicionales que se evalúan después del match estructural) y
caracteres comodín (`_`) cuando no te interesa el dato.

Lo importante: el compilador verifica **exhaustividad**. Si
`Tag` tiene cuatro constructores y tu `match` cubre tres, no
compila. Si agregas un quinto constructor a un tipo y existen
treinta `match` en el código, los treinta se vuelven errores
de compilación que te indican exactamente dónde tienes que
volver. Esto convierte una refactorización temida en una
tediosa pero segura.

Sin pattern matching, los lenguajes resuelven este escenario
con visitor patterns, jerarquías de clases, o cadenas de `if /
else if / else`. Cada una de esas soluciones funciona, pero
todas pierden la conexión que tiene `match` entre el tipo del
dato y la forma de decidir sobre él.

Cuando llevas algunas semanas con kaikai, el `match` se vuelve
una de esas herramientas que no quieres soltar.

## 2.5 Funciones puras y efectos visibles

Las cuatro ideas anteriores convergen en una más grande, que es
la apuesta central del lenguaje: **separar lo puro de lo que
toca el mundo**, y tener al sistema de tipos cuidando esa
distinción.

Una función *pura* es una función cuyo resultado depende solo de
sus argumentos. Llamarla con los mismos argumentos siempre
devuelve el mismo valor. No imprime. No lee del disco. No
manda mensajes. No mira un reloj. No lanza un dado.

Las funciones puras son fáciles de probar, fáciles de razonar,
fáciles de paralelizar, fáciles de cachear. El problema es que
un programa que solo tiene funciones puras no hace nada útil:
nunca habla con el mundo.

kaikai pone los efectos en el sistema de tipos. Lo viste en el
capítulo 1: una función que escribe a stdout dice
`: Unit / Stdout` en su firma. Una función que usa `Log` dice
`: ... / Log`. Una función que puede fallar y abortar dice
`: ... / Fail`. Y una función pura, que no toca el mundo, no
dice nada después del `/`. Su firma es `fn f(x: Int) : Int`,
sin más.

El efecto del lado derecho del `/` no es decoración sino una
restricción: el compilador no te deja llamar a una función con
efectos desde un contexto donde esos efectos no estén siendo
manejados. Un handler en algún lado de la pila tiene que tomarse
el problema. Esto resuelve, de una vez y a nivel del lenguaje,
varias incomodidades viejas:

- Las **excepciones invisibles** que Java y Python permiten
  porque ninguna firma las declara.
- El **manejo de cancelación** que en lenguajes con `async`/`await`
  se vuelve un hilo por dentro de la lógica de negocio, en vez
  de un mecanismo aparte.
- La **inyección de dependencias** que en lenguajes OO requiere
  contenedores enteros para hacer lo que un handler de efecto
  hace en cinco líneas.
- El **logging**, el **acceso a configuración**, el **reloj**,
  la **base de datos**: todo lo que tradicionalmente se cuela
  como dependencia escondida puede ser un efecto, declararse en
  el tipo, y la elige quien llama.

Si nunca has visto esto, suena demasiado ambicioso para ser
cierto. Lo es y no lo es. El capítulo 12 le dedica todo el
espacio que merece. Por ahora basta con saber que las firmas que
ves con `/ algo` no son ruido: son información sobre lo que esa
función puede hacerle a tu programa.

## 2.6 El tipo no es la única etiqueta

Hay un último hábito que conviene instalar temprano, porque
reordena cómo lees todo lo que viene. En los lenguajes que
traes, el compilador razona sobre una sola clase de etiqueta:
el tipo. Todo lo demás que importa de un valor (en qué unidad
está, qué puede fallar al calcularlo, quién es dueño de su
memoria) vive en comentarios, en convenciones de nombres, o
en tu cabeza.

En kaikai, el tipo es una etiqueta entre varias. La sección
anterior te acaba de mostrar la segunda: los **efectos**, que
viven en la firma después del `/` y que el compilador combina
y verifica con reglas propias. Más adelante vas a encontrar
otras: **unidades de medida** que multiplican y se cancelan
como en física (cap. 10), **monedas** que se suman pero se
niegan a multiplicarse entre sí, **regiones de memoria** que
nunca se confunden una con otra (cap. 13). Cada familia tiene
su propia álgebra, sus propias reglas de qué combina con qué,
y el compilador la aplica con el mismo rigor con que
verifica tipos. A cada una de estas familias el lenguaje la
llama un **kind**.

No necesitas el mecanismo todavía; el capítulo 19 lo recorre
completo, con nombre y apellido. Lo que sí conviene llevarse
de aquí es el hábito de lectura: cuando kaikai rechace un
programa que "se veía bien", la pregunta no es solo *qué tipo
esperaba*, sino *qué familia de etiquetas está en juego*. La
mitad de las veces el compilador no te está corrigiendo un
tipo: te está diciendo que mezclaste metros con segundos,
dólares con euros, o memoria de una región con otra. Esa es
información que en otros lenguajes no existía en ninguna
parte.

## 2.7 Una breve genealogía

kaikai no salió de la nada. Hereda decisiones de varias familias
de lenguajes, y conviene saber cuáles para entender por qué se
ven como se ven. Ninguna de estas ideas es mía; lo que elegí fue
cuáles poner juntas.

- **De ML (1973), OCaml y Haskell** vienen los tipos
  algebraicos, el pattern matching, la inferencia de tipos
  estilo Hindley-Milner, e `Option`/`Result`. Son ideas viejas,
  buenas, y hoy se redescubren en lenguajes "modernos" como Rust
  y Swift sin reconocer del todo a sus abuelos.
- **De Erlang (1986) y Elixir** vienen los procesos aislados con
  memoria privada, la idea de que la concurrencia se basa en
  pasar mensajes y no en compartir memoria, y el modelo de
  supervisión con `link` y `monitor`. En kaikai esos procesos se
  llaman fibras y actores.
- **De Elixir** además, el operador pipe `|>` que vimos arriba.
- **De Koka (Daan Leijen, Microsoft Research)** y **Effekt
  (Andreas Rossberg, Jonathan Brachthäuser)** vienen los efectos
  algebraicos con filas de efectos en el sistema de tipos.
  kaikai sigue de cerca a Effekt en cómo los handlers se
  expresan, y a Koka en algunas decisiones internas.
- **De Koka** también viene **Perceus**, el esquema de
  reference counting optimizado en compilación que kaikai usa
  para administrar memoria sin garbage collector ni borrow
  checker.
- **De Go** se rescata la decisión de tener un solo binario
  como compilador, formateador y test runner; la primacía de
  programas que se construyen y corren rápido; y la disciplina
  de mantener pocas formas en el lenguaje.
- **De Rust** kaikai aprende qué *no* hacer: los tipos suma y
  el pattern matching son lecciones que Rust enseña bien. El
  borrow checker, en cambio, kaikai prefiere evitarlo:
  Perceus + fibras aisladas resuelven el problema sin pedirle
  al programador que entienda lifetimes.

Ninguna de estas decisiones es nueva. Lo que kaikai intenta es
una combinación coherente: tipos algebraicos + efectos
algebraicos + Perceus + fibras BEAM, en un lenguaje que se
compila rápido a código nativo y que un programador con
experiencia puede leer sin un curso previo.

El resto del libro entra en detalle en cada una de esas
decisiones. Si llegaste hasta aquí, ya tienes el mapa.

## Ejercicios

**2.1.** Vuelve al programa `02_fizzbuzz.kai` del capítulo 1.
Identifica todas las **expresiones** que devuelven un valor.
¿Cuántas hay? ¿Hay alguna **sentencia** estricta (algo que se
ejecute por su efecto sin producir nada útil) fuera de las
llamadas a `println`?

**2.2.** En tu lenguaje habitual, escribe una versión corta del
siguiente caso: una función `clasificar_edad(n)` que devuelve
un string `"niño"`, `"joven"`, `"adulto"` o `"mayor"` según
rangos. ¿Cuántas variables locales usaste? ¿Cuántas
asignaciones? Reescríbelo después en pseudo-kaikai (no hace
falta que compile) usando `if` como expresión.

**2.3.** Encuentra en el código de tu trabajo una función que
devuelva `null` o lance una excepción para señalar "no hay
resultado". Escribe en un comentario cuál sería su firma en
kaikai usando `Option` o `Result`. ¿Qué información ganas? ¿Qué
información pierdes?
