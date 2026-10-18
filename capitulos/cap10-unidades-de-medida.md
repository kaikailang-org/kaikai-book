# Capítulo 10 · Unidades de medida: tu primer kind

En 1999, la NASA perdió la sonda Mars Climate Orbiter (327
millones de dólares de proyecto) porque dos módulos de
software se intercambiaban valores numéricos sin acuerdo
sobre las unidades. Uno producía el impulso en
libras-fuerza·segundo, otro lo leía en newtons·segundo. Nadie
había escrito las unidades en la interfaz. La sonda entró
demasiado bajo y se perdió en la atmósfera de Marte.

Es un ejemplo extremo, pero la familia es enorme: dos
componentes que comparten el mismo tipo numérico pero no la
misma interpretación. Pasar segundos donde se esperan
milisegundos. Sumar saldos en monedas distintas. Mezclar un
`UserId` con un `OrderId` porque ambos son enteros. En todos
los casos el sistema de tipos ve dos números o dos strings y
no tiene cómo distinguirlos.

kaikai resuelve esta familia entera con una sola
construcción: las **unidades de medida**. La idea, heredada
de F#, es que puedes anotar un número con una unidad
(`Real<USD>`, `Int<Seconds>`) y el compilador rechaza
cualquier operación que mezcle unidades incompatibles. La
unidad **vive en el tipo**, **se borra en runtime**, y queda
documentada en cada firma que la toca.

Si el §2.6 te dejó la idea de que en kaikai el tipo no es la
única etiqueta, aquí esa idea se vuelve tangible: las unidades
son tu primer encuentro de cuerpo entero con un **kind**, una
familia de etiquetas con su propia álgebra, distinta de los
tipos. Ya usaste otra sin mirarla de frente (la fila de
efectos); esta es la primera que declaras y manipulas tú.

Aprendes las unidades clásicas (física, finanzas, tiempo) y
su uso menos obvio pero más frecuente en el código del día a
día: los **branded types**, donde la unidad es solo una
etiqueta que distingue tipos que, sin ella, el lenguaje
trataría como iguales.

## 10.1 `unit` y literales anotados

Una unidad se declara anteponiendo `unit` a un nombre:

```kai
unit USD
unit EUR
unit m
unit sec
unit kg
```

`unit USD` introduce un símbolo `USD` que el sistema de tipos
puede usar como anotación. No hay implementación ni valor en
runtime: `unit` solo declara que el símbolo existe.

Para anotar un número con una unidad, usas paréntesis
angulares en el literal:

```kai
let precio: Real<USD> = 1.50<USD>
let velocidad: Real<m / sec> = 9.81<m / sec>
let timeout: Int<sec> = 30<sec>
```

Tres cosas que vale fijar:

- **Las unidades se escriben con `<...>`**, no con `[...]`. Los
  corchetes son para parámetros de tipo (`List[Int]`,
  `Option[String]`); los paréntesis angulares son para
  unidades.
- **El literal y el tipo se anotan los dos.** `1.50<USD>` es
  un literal `Real` con unidad `USD`. `Real<USD>` es el tipo.
  Coinciden, pero cumplen roles distintos.
- **El compilador permite cualquier identificador como
  unidad.** Por convención, las unidades SI van en minúscula
  (`m`, `s`, `kg`), las nombradas por personas en titlecase
  (`Newton`, `Pascal`), y las monedas en mayúsculas según ISO
  4217 (`USD`, `EUR`, `CLP`). Son convenciones de la
  comunidad; el compilador no las fuerza.

## 10.2 Aritmética con unidades

La aritmética entre valores con la misma unidad funciona
como esperarías. Sumar dos `Real<USD>` da otro `Real<USD>`:

```kai
# ejemplos/cap10/01_unidades_basicas.kai
unit USD

unit EUR

fn main() {
  let precio: Real<USD> = 1.50<USD>
  let propina: Real<USD> = 0.30<USD>
  let total: Real<USD> = precio + propina
  println("total = #{total}")

  # Las unidades se preservan en el tipo de retorno.
  let valor_eur: Real<EUR> = 1.20<EUR>
  println("valor_eur = #{valor_eur}")

  # Lo siguiente NO compila: USD + EUR es error de tipo.
  # let mezcla = precio + valor_eur
}
```

```
$ kai run ejemplos/cap10/01_unidades_basicas.kai
total = 1.8 USD
valor_eur = 1.2 EUR
```

Pero **mezclar unidades incompatibles es un error de
compilación**. Si intentas:

```kai
let mezcla = precio + 1.20<EUR>     # error de tipo
```

el compilador rechaza con un error que dice "esperaba `USD`,
encontré `EUR`". El programa nunca corre con valores mezclados:
el bug se detecta antes de que exista.

La regla general:

- **`+`, `-`** entre dos valores de la misma unidad: legal,
  preserva la unidad.
- **`*`, `/`** entre valores con unidades: legal, **componen
  las unidades**. Lo pruebas en §10.3.
- **`+`, `-`** entre unidades distintas: error de tipo.
- **Comparaciones (`<`, `==`)** entre unidades distintas:
  error de tipo.

La aritmética con un valor sin unidad y uno con unidad es
asimétrica. Multiplicar por un escalar (`2.0 * precio`) es
legal: el escalar se trata como adimensional. Sumar un
escalar (`precio + 1.0`) es error: no hay cómo saber en qué
unidad está el `1.0`.

## 10.3 Álgebra de unidades: producto, cociente, potencia

Multiplicar dos unidades produce una unidad compuesta. El
ejemplo canónico es la fuerza:

```kai
let masa: Real<kg> = 70.0<kg>
let aceleracion: Real<m / sec^2> = 9.81<m / sec^2>
let fuerza: Real<kg * m / sec^2> = masa * aceleracion
```

`kg * m / sec^2` es la unidad compuesta de fuerza. El
compilador la deduce automáticamente de los operandos: `kg *
(m / sec^2)` se simplifica a `kg * m / sec^2`. Si después
divides la fuerza por el área para obtener presión, la unidad
final es `kg / (m * sec^2)`, todo derivado mecánicamente:

```kai
let area: Real<m^2> = 4.0<m^2>
let presion: Real<kg / (m * sec^2)> = fuerza / area
```

El sistema de tipos hace **álgebra de unidades**. `m * m` se
simplifica a `m^2`, `sec / sec` se cancela a sin-unidad,
`(m / sec) * (sec)` se cancela a `m`. Es álgebra abeliana
sobre los símbolos de unidad, y cualquier expresión legal en
matemática elemental sobre unidades es legal en kaikai.

En un programa, la unidad viaja con el valor hasta la
impresión, incluido el `sec^2` que nadie declaró:

```kai
# ejemplos/cap10/02_algebra_unidades.kai
unit m

unit sec

unit kg

fn main() {
  let velocidad: Real<m / sec> = 9.81<m/sec>
  println("v = #{velocidad}")

  # Unidad compuesta: aceleración.
  let g: Real<m / sec^2> = 9.81<m/sec^2>
  println("g = #{g}")

  # Producto de unidades: F = m * a tiene unidad kg*m/sec^2.
  let masa: Real<kg> = 70.0<kg>
  let fuerza: Real<kg * m / sec^2> = masa * g
  println("F = m * g = #{fuerza}")

  # Producto de la misma unidad consigo misma: tiempo cuadrado.
  let t: Real<sec> = 3.0<sec>
  let t2: Real<sec^2> = t * t
  println("t² = #{t2}")
}
```

```
$ kai run ejemplos/cap10/02_algebra_unidades.kai
v = 9.81 m/sec
g = 9.81 m/sec^2
F = m * g = 686.7 kg m/sec^2
t² = 9 sec^2
```

### Alias para unidades derivadas

Cuando una composición aparece a menudo, puedes darle un
nombre con un `unit` con cuerpo:

```kai
unit Newton = kg * m / sec^2
unit Pascal = Newton / m^2
unit Hertz  = 1 / sec
```

Desde ahí, `Real<Newton>` es exactamente lo mismo que
`Real<kg * m / sec^2>`: el compilador los acepta
intercambiables. La diferencia es para quien lee:
`Real<Newton>` comunica intención; `Real<kg * m / sec^2>`
comunica derivación.

`Newton` en uso, junto con la prueba de que las dos escrituras
son la misma unidad para el compilador:

```kai
# ejemplos/cap10/03_alias.kai
unit m

unit sec

unit kg

unit Newton = kg*m/sec^2

fn main() {
  let g: Real<m / sec^2> = 9.81<m/sec^2>
  let masa: Real<kg> = 70.0<kg>
  let fuerza: Real<Newton> = masa * g
  println("F = #{fuerza}")

  # Newton y kg*m/sec^2 son la misma unidad: el compilador las
  # acepta intercambiables.
  let fuerza_explicita: Real<kg * m / sec^2> = fuerza
  println("misma unidad: #{fuerza_explicita}")
}
```

```
$ kai run ejemplos/cap10/03_alias.kai
F = 686.7 kg m/sec^2
misma unidad: 686.7 kg m/sec^2
```

### Redondear sin perder la unidad

Dividir dos medidas rara vez da un número redondo. Cien metros
en 9.58 segundos son 10.438413361169102 m/sec, y eso es lo que
imprime un `Real`: los dígitos que hacen falta para releerlo
como el mismo número. Para un informe quieres dos decimales, y
la duda natural es si redondear te deja un número pelado.

No te lo deja. La familia de redondeo de `math.real` (`trunc`,
`floor`, `ceil`, `round`, `round_half_even`, `round_to`) es
genérica sobre `Measure`, de la misma forma que el `promedio`
que escribes en el §10.4. Entra un `Real<u>` y sale un
`Real<u>`.

```kai
# ejemplos/cap10/07_redondeo.kai
import math.real

unit m

unit sec

fn main() : Unit / Stdout {
  let v: Real<m / sec> = 100.0<m> / 9.58<sec>
  let vr: Real<m / sec> = real.round_to(v, 2)

  println("#{v}")
  println("#{vr}")
  println("#{real.round_to(v, 1)}")
  println("#{real.round(v)}")
}
```

```
$ kai run ejemplos/cap10/07_redondeo.kai
10.438413361169102 m/sec
10.44 m/sec
10.4 m/sec
10 m/sec
```

La anotación de `vr` es la parte que importa. Que la unidad
aparezca impresa prueba poco; que `Real<m / sec>` acepte el
resultado prueba que la unidad sobrevivió en el tipo, que es
donde el compilador la revisa.

## 10.4 Unidades genéricas

Hasta aquí cada función opera sobre una unidad concreta, pero
muchas operaciones son **agnósticas a la unidad**: promediar,
sumar, ordenar, encontrar el máximo. Esas se escriben
**genéricas sobre la unidad**, igual que una función puede ser
genérica sobre el tipo de los elementos de una lista.

```kai
fn promedio[u: Measure](a: Real<u>, b: Real<u>) : Real<u> =
  (a + b) / 2.0
```

`u : Measure` declara `u` como un parámetro de tipo en el
**kind** `Measure`. Lo único que `u` admite es ser una
unidad. `Measure` no es un caso aislado: es una entrada del
catálogo de kinds del lenguaje (`stdlib/core/kinds.kai`), el
mismo mecanismo que clasifica tipos, efectos, monedas y
regiones de memoria, y lo recorres completo en el capítulo
19. La función `promedio` acepta dos `Real<u>` y devuelve
un `Real<u>`: el "para cualquier u" es lo que permite usarla
con `USD`, `kg`, `m/sec`, lo que sea, **siempre y cuando los
dos argumentos tengan la misma unidad**.

El archivo completo, con la función y sus dos usos:

```kai
# ejemplos/cap10/04_genericas.kai
fn promedio[u: Measure](a: Real<u>, b: Real<u>) : Real<u> =
  (a + b) / 2.0

unit USD

unit kg

fn main() {
  let p1: Real<USD> = 10.0<USD>
  let p2: Real<USD> = 20.0<USD>
  let pp: Real<USD> = promedio(p1, p2)
  println("promedio precios = #{pp}")

  let m1: Real<kg> = 70.0<kg>
  let m2: Real<kg> = 80.0<kg>
  let pm: Real<kg> = promedio(m1, m2)
  println("promedio masas = #{pm}")

  # promedio(p1, m1) sería un error de tipo: USD ≠ kg.
}
```

```
$ kai run ejemplos/cap10/04_genericas.kai
promedio precios = 15 USD
promedio masas = 75 kg
```

Pero esto es error de tipo:

```kai
let mezcla = promedio(10.0<USD>, 70.0<kg>)   # u no puede ser USD y kg
```

El compilador instancia `u = USD` para el primer argumento, y
exige que el segundo también use `u = USD`. `kg` no calza, y
el programa no compila.

Las unidades genéricas son lo que hace al sistema **escalable**.
Las funciones del stdlib (`list.sum`, `list.max`, `list.min`)
son polimórficas sobre la unidad: si pasas una `[Real<USD>]`,
devuelven `Real<USD>`; si pasas una `[Real<kg>]`, `Real<kg>`.
La unidad se preserva sin que la nombres.

## 10.5 Conversiones explícitas

A veces **sí** quieres mezclar dos unidades distintas, por
ejemplo sumar un saldo en USD con uno en EUR. El compilador no
te lo deja hacer por accidente, pero sí con una **conversión
explícita**.

La técnica es un factor de conversión que lleva la unidad
cociente `destino/origen`. Multiplicar por él cancela la
unidad origen y deja la unidad destino:

```kai
let monto_eur: Real<EUR> = 80.0<EUR>
let tasa: Real<USD / EUR> = 1.10<USD / EUR>
let monto_usd: Real<USD> = monto_eur * tasa    # 88 USD
```

La aritmética se sigue: `EUR * (USD / EUR)` cancela `EUR` y
deja `USD`. El compilador verifica que la cancelación sea
correcta: si pones la tasa al revés (`Real<EUR / USD>`), la
multiplicación produce `Real<EUR^2 / USD>`, que no calza con
el tipo `Real<USD>` esperado en el `let`.

La regla mental: **la conversión es una multiplicación por un
factor cuyas unidades cancelan a la salida**. Es lo mismo que
haces a mano en física cuando escribes "10 km × 1000 m/km =
10000 m"; kaikai te obliga a escribir esa multiplicación.

Lo hice a propósito, y creo que además libera. Una conversión
visible te obliga a pensar qué tasa usas, cuándo se aplica y de
dónde salió; y una vez escrita, el compilador garantiza que no
la olvidaste en ningún lugar.

## 10.6 Branded types

Las unidades son útiles cuando el valor "tiene una dimensión
física": metros, kilogramos, dólares. Pero la misma maquinaria
se aplica a un caso más cotidiano: **distinguir
valores que tienen el mismo tipo subyacente pero significan
cosas distintas**.

El ejemplo clásico son los identificadores. Un `UserId` es un
entero. Un `OrderId` también. Sin unidades, el compilador no
puede distinguirlos:

```kai
fn cancelar_orden(id: Int) : Unit / Stdout = ...
fn enviar_email(uid: Int) : Unit / Stdout = ...

let user_id = 42
let order_id = 99
cancelar_orden(user_id)   # bug: pasamos un id de usuario
                          # a una función que espera un id
                          # de orden, pero compila igual.
```

Con unidades, los dos identificadores son tipos distintos:

```kai
unit UserId
unit OrderId

fn cancelar_orden(id: Int<OrderId>) : Unit / Stdout = ...
fn enviar_email(uid: Int<UserId>) : Unit / Stdout = ...

let user_id: Int<UserId>  = 42<UserId>
let order_id: Int<OrderId> = 99<OrderId>

cancelar_orden(user_id)   # ERROR de tipo: UserId ≠ OrderId
```

Usar una unidad como **etiqueta** sobre un tipo numérico se
llama **branded type**, y es de los usos que más rinden en el
código del día a día. Casos típicos:

- `Int<UserId>` vs `Int<OrderId>`: identificadores que
  comparten tipo subyacente.
- `Int<Cents>` vs `Int<Quantity>`: un dinero en centavos vs
  una cantidad de unidades.
- `Int<Seconds>` vs `Int<Milliseconds>`: los timeouts mal
  expresados son responsables de un porcentaje no menor de
  bugs intermitentes.

Las unidades etiquetan tipos numéricos: `Int`, `Real` y
`Decimal`. Una cadena no tiene cómo recibir una:
`"ada@x.cl"<Email>` no es un literal válido. Para separar un email validado de un
nombre de usuario, usas un record con un campo privado (§4.1):
el módulo expone la función que valida y construye, y nadie
más fabrica el valor.

Dos de esos casos en un programa que corre. Las líneas
comentadas son justamente las que el compilador rechaza:

```kai
# ejemplos/cap10/05_branded.kai
unit UserId

unit OrderId

unit Seconds

unit Milliseconds

fn cancelar_orden(id: Int<OrderId>) : Unit / Stdout =
  println("cancelando orden #{id}")

fn timeout_ms(t: Int<Milliseconds>) : Unit / Stdout =
  println("timeout = #{t}")

fn main() {
  let _uid: Int<UserId> = 42<UserId>
  let oid: Int<OrderId> = 99<OrderId>

  cancelar_orden(oid)

  # Lo siguiente NO compila: el compilador no deja pasar un
  # UserId donde se espera un OrderId, aunque ambos son Int.
  # cancelar_orden(_uid)

  let _espera_seg: Int<Seconds> = 30<Seconds>
  let espera_ms: Int<Milliseconds> = 30<Milliseconds>

  timeout_ms(espera_ms)

  # Y esto tampoco: pasar segundos donde se esperaban milisegundos.
  # timeout_ms(_espera_seg)
}
```

```
$ kai run ejemplos/cap10/05_branded.kai
cancelando orden 99
timeout = 30
```

### Costo cero en runtime

Las unidades se borran después de la verificación de tipos. El
binario que produce `kai build` opera con `Int`, `Real` y
`Decimal` planos. La unidad **no existe** en runtime: ni tag, ni
verificación dinámica, ni overhead. La promesa es la misma de
los efectos algebraicos y de los contratos: información en el
tipo, costo cero en runtime.

## 10.7 Caso de estudio: cartera multi-moneda

Cerramos con un ejemplo integrador. Una cartera contiene
saldos en distintas monedas. Sumar saldos de la misma moneda
es trivial; combinarlos en un total exige convertir.

```kai
# ejemplos/cap10/06_cartera.kai
unit USD

unit EUR

unit CLP

fn sumar[c: Measure](a: Real<c>, b: Real<c>) : Real<c> = a + b

# Conversión explícita: el factor lleva la unidad cociente
# `destino/origen` y multiplicar por él cancela la unidad
# origen y deja la destino.
fn convertir[origen: Measure, destino: Measure](
  monto: Real<origen>,
  tasa: Real<destino / origen>
) : Real<destino> = monto * tasa
```

Tres declaraciones. `sumar` es genérica sobre la moneda y
preserva la unidad de los argumentos: la misma técnica del
§10.4. `convertir` recibe un monto y una tasa, y devuelve el
monto en la unidad destino, gracias a la cancelación de
unidades.

Y el cálculo principal:

```kai
fn main() {
  let saldo_usd_1: Real<USD> = 100.0<USD>
  let saldo_usd_2: Real<USD> = 50.0<USD>
  let total_usd: Real<USD> = sumar(saldo_usd_1, saldo_usd_2)
  println("total USD = #{total_usd}")

  let saldo_eur: Real<EUR> = 80.0<EUR>

  # Para combinar USD y EUR hay que convertir explícito:
  let tasa_eur_usd: Real<USD / EUR> = 1.10<USD/EUR>
  let eur_en_usd: Real<USD> = convertir(saldo_eur, tasa_eur_usd)
  let total_global: Real<USD> = sumar(total_usd, eur_en_usd)
  println("total convertido a USD = #{total_global}")

  # Convertir CLP a USD con su propia tasa.
  let saldo_clp: Real<CLP> = 100000.0<CLP>
  let tasa_clp_usd: Real<USD / CLP> = 0.0011<USD/CLP>
  let clp_en_usd: Real<USD> = convertir(saldo_clp, tasa_clp_usd)
  let total_final: Real<USD> = sumar(total_global, clp_en_usd)
  println("total final = #{total_final}")
}
```

```
$ kai run ejemplos/cap10/06_cartera.kai
total USD = 150 USD
total convertido a USD = 238 USD
total final = 348 USD
```

Tres conversiones, tres aplicaciones de `sumar`. Cada una
verificada por el compilador: si en algún paso hubieras
intentado sumar `Real<EUR>` con `Real<USD>` sin convertir, no
compilaría. Si la tasa estuviera invertida (`<EUR / USD>` en
vez de `<USD / EUR>`), tampoco. La cartera completa es **un
mini-sistema de tipos sobre dinero** que el compilador
sostiene.

El día que un colega agrega una nueva moneda, declara un
`unit JPY`, agrega su tasa, y el resto del código sigue
compilando o no según corresponda. Ningún
cálculo viejo se rompe (los tipos son ortogonales), y los
cálculos que necesitan considerar JPY tienen que decirlo
explícito. Es el principio que conociste en el cap. 5 con las
uniones de errores: agregar un componente nuevo es seguro
porque el compilador te lleva al lugar exacto donde necesitas
hacer algo.

Compáralo con la versión sin unidades:

```kai
fn sumar(a: Real, b: Real) : Real = a + b

let total = sumar(saldo_usd, saldo_eur)   # compila, suma valores
                                          # en monedas distintas
                                          # sin convertir.
```

Funciona, devuelve un número y produce un total que **no
significa nada**. Con unidades, ese programa no compila: el
bug que en otros lenguajes se descubre en producción (o nunca,
según la suerte) aquí no existe.

Una nota para código de producción: el stdlib trae un módulo
`money` con las monedas ISO ya declaradas y un tipo `Money[c:
Currency]` montado sobre `Decimal` (aritmética exacta, no punto
flotante). Usa un kind propio, `Currency`, más restrictivo que
`Measure`: permite sumar y escalar, pero `USD^2` o `USD*EUR` ni
siquiera se pueden escribir. Esa diferencia la encuentras en el
capítulo 19; para aprender la mecánica de unidades, el
`Real<USD>` de este capítulo es el camino.

## Ejercicios

**10.1.** Define `unit Celsius` y `unit Fahrenheit`. Escribe
una función `fn celsius_a_fahrenheit(c: Real<Celsius>) :
Real<Fahrenheit>` que aplique la fórmula correcta. ¿Cuál es
el factor de conversión? ¿Tiene unidad?

**10.2.** Define `unit Cents` (centavos) y escribe
`fn pagar(monto: Int<Cents>) : Unit / Stdout`. Construye un
ejemplo donde el lenguaje detecte un bug de "pasar un monto
en pesos donde se esperaban centavos".

**10.3.** Toma el caso de estudio del §10.7 y agrega una
nueva moneda `JPY` con su tasa. ¿Cuántas líneas tienes que
cambiar? ¿Hay alguna línea del código existente que se rompa
solo porque agregaste la unidad?

**10.4.** Escribe una función genérica
`fn rango[u: Measure](xs: [Real<u>]) : Option[Real<u>]` que
devuelva la diferencia entre el máximo y el mínimo de una
lista, o `None` si la lista está vacía. ¿Qué unidad tiene el
resultado?

**10.5.** En tu trabajo o en un proyecto personal, identifica
**dos** lugares donde dos enteros distintos significan cosas
distintas (identificadores, índices, contadores, timeouts).
Escribe en pseudo-kaikai cómo serían las firmas de las
funciones afectadas si usaras branded types. ¿Cuántos bugs
históricos podrían haberse evitado?
