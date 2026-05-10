# Capítulo 11 · Programación por contrato y refinement types

Este capítulo cierra la Parte II y completa el hilo
"información en el tipo, costo cero en runtime" que arrancan
los efectos algebraicos (cap. 12), continúan las unidades de
medida (cap. 10) y rematan acá con dos mecanismos que
provienen de Eiffel (1986) y Ada 2012: los **contratos**
(precondiciones y postcondiciones que viven en la firma de
una función) y los **refinement types** (restricciones
sobre los valores que un tipo admite).

Los dos mecanismos comparten la misma idea: **enunciar
restricciones en el tipo, hacer que el compilador las
verifique cuando puede, y diferirlas a runtime cuando no
puede**. Donde difieren es en el alcance: los contratos
hablan de **operaciones** (qué espera y qué garantiza una
función); los refinements hablan de **valores** (qué números
o strings son válidos). Las dos cubren áreas distintas y se
complementan.

## 11.1 Por qué contratos y refinements van juntos

Imagina que quieres modelar una cuenta bancaria. La regla
natural es "el saldo nunca puede ser negativo". Hay dos
formas de expresar esa regla:

- **En el valor**: declarar `type SaldoValido = Int where
  self >= 0`. Cualquier valor de tipo `SaldoValido` cumple la
  regla por construcción. El compilador rechaza cualquier
  intento de meter un negativo.
- **En la operación**: declarar `fn retirar(c: Cuenta, monto:
  Int) : Cuenta requires c.saldo >= monto ensures
  result.saldo >= 0`. La función exige una condición sobre
  los argumentos y promete una sobre el resultado.

Las dos formas dicen lo mismo y la una sin la otra es
incompleta. Los refinements describen **qué valores son
legales**; los contratos describen **qué hacen las operaciones
con esos valores**. Una cuenta bancaria robusta usa los dos:
saldo refinado a no negativo, operaciones con
precondiciones que aseguran que la regla se mantiene.

kaikai trata las dos como un solo proyecto. La doc del
lenguaje (`refinements-and-contracts.md`) dice:

> Together they form a single coherent mechanism — types
> describe what values are valid, contracts describe what
> operations guarantee — and the two share most of the
> implementation machinery.

Es por eso que viven en el mismo capítulo.

## 11.2 `requires` y `ensures` en una firma

Un contrato se escribe como anotaciones en la firma de una
función, antes del `=` que abre el cuerpo:

```kai
fn divide(a: Int, b: Int) : Int
  requires b != 0
  ensures  result * b + (a % b) == a
= a / b
```

Tres componentes:

- **`requires <expr>`**: una **precondición**. La expresión
  tiene que ser `true` al **entrar** a la función. El caller
  es responsable. Si se viola, el bug es del caller.
- **`ensures <expr>`**: una **postcondición**. La expresión
  tiene que ser `true` al **salir** de la función. Tu cuerpo
  es responsable. Si se viola, el bug es interno.
- **`result`**: un nombre reservado dentro del `ensures`
  que se refiere al valor de retorno.

Una función puede tener múltiples `requires` y múltiples
`ensures`. El compilador los acumula:

```kai
fn retirar(c: Cuenta, monto: Int) : Cuenta
  requires monto > 0
  requires c.saldo >= monto
  ensures  result.saldo == c.saldo - monto
=
  Cuenta { ...c, saldo: c.saldo - monto }
```

Dos precondiciones (el monto positivo, y que haya saldo
suficiente), una postcondición (la cuenta resultante tiene
exactamente `c.saldo - monto`). Las precondiciones se
verifican en orden al entrar; la postcondición al salir.

Tres detalles que vale fijar:

- **`requires` y `ensures` no son comentarios**. Son código
  que el compilador emite como verificaciones reales. Si una
  precondición se viola en runtime, el programa aborta con
  un mensaje claro:

  ```
  panic: requires violated in `divide`
  required: b != 0
  declared at line 9, col 14
  ```

- **El compilador prueba estáticamente lo que puede**. Si
  llamas a `divide(10, 0)` con literales, el compilador ve
  que `b == 0` y rechaza la llamada en compile time: no
  esperas a runtime. Si llamas con valores dinámicos, inserta
  el assert.

- **Los contratos no se ejecutan en builds de release**, según
  un flag de compilación. En ese modo, los `requires` y
  `ensures` desaparecen del binario; el costo es cero. Para
  desarrollo y para tests, los contratos se evalúan.

## 11.3 `result` y los nombres en alcance dentro del `ensures`

Dentro de una postcondición tienes a disposición:

- **`result`**: el valor de retorno.
- **Los nombres de los parámetros**: sus valores de entrada.
- **Cualquier función pura** que el módulo provea.

Esto te deja escribir relaciones entre la entrada y la salida:

```kai
fn duplicar(n: Int) : Int
  ensures result == n * 2
= n + n

fn ordenar(xs: [Int]) : [Int]
  ensures list.length(result) == list.length(xs)
= ...
```

La primera dice "la salida es el doble de la entrada". La
segunda dice "la lista resultante tiene el mismo largo que
la entrada": un invariante razonable de cualquier
ordenamiento. Notar que **no** estamos diciendo que `result`
está ordenado, solo que conserva el largo. Las
postcondiciones documentan lo que vale la pena documentar; no
tienen que ser exhaustivas.

A diferencia de Eiffel, **no hay `old`**. En Eiffel necesitas
`ensures balance = old balance + amount` porque los records
son mutables y el `balance` que ves en el `ensures` ya cambió.
En kaikai los records son inmutables: el `c` que entra y el
`result` que sale son **valores distintos**, los dos en
alcance, sin necesidad de un mecanismo para "el valor antes
de la llamada".

## 11.4 Refinement types

Mientras que los contratos hablan de operaciones, los
**refinement types** hablan de valores. Un refinement type es
un tipo base más un predicado:

```kai
type NoNeg = Int where self >= 0
type Probabilidad = Real where self >= 0.0 and self <= 1.0
type Edad = Int where self >= 0 and self <= 130
type Puerto = Int where self >= 1 and self <= 65535
```

El predicado se refiere a `self`, el valor que estamos
restringiendo. Cualquier valor de tipo `NoNeg` cumple `self
>= 0` por construcción; cualquier `Probabilidad` cae en el
intervalo unitario; cualquier `Puerto` está dentro del rango
TCP.

Construir un valor del tipo refinado requiere que el predicado
se cumpla. Si lo cumples con un literal, el compilador lo
verifica en compile time:

```kai
let x : NoNeg = 16        # OK: 16 >= 0
let y : NoNeg = 0 - 5     # ERROR: -5 no satisface self >= 0
```

Si lo cumples con un valor dinámico, el compilador inserta un
chequeo en runtime: igual que con un `requires` cuyo argumento
no se puede deducir estáticamente.

Las funciones que aceptan tipos refinados **se benefician de
la garantía sin chequearla**. Si tu firma dice `n: NoNeg`,
adentro puedes asumir `n >= 0` sin escribir un `if`. Eso es
exactamente lo que un contrato `requires n >= 0` hace, pero
codificado en el tipo en vez de en la firma.

¿Cuándo usas uno y cuándo el otro? La regla simple:

- **Refinement type** cuando la restricción **define qué es
  un valor válido** del dominio. `Edad`, `Probabilidad`,
  `Puerto` son ejemplos clásicos: el tipo no tiene sentido
  fuera de la restricción.
- **Contrato** cuando la restricción es **sobre la operación**,
  no sobre el valor. "no dividir por cero" es del operando de
  división; "el monto a retirar tiene que ser positivo" es de
  la operación retirar; "la lista resultante mantiene el
  largo" es del comportamiento de la función.

A veces los dos aplican y eliges según legibilidad. La cuenta
bancaria del §11.7 usa contratos porque "el saldo no se
puede dejar negativo" es una propiedad del **comportamiento de
las operaciones**, no del valor del saldo.

## 11.5 Cuándo se prueba estáticamente, cuándo en runtime

kaikai trata los contratos y los refinements como un
**continuo entre estático y dinámico**, decidido por lo que el
compilador puede demostrar. Tres niveles:

**Compile time, completamente probado.** Cuando los argumentos
son literales o el compilador conoce sus rangos:

```kai
divide(10, 0)              # ERROR de compilación: 0 != 0 es falso
let x : NoNeg = 0 - 5      # ERROR de compilación: -5 < 0
```

El programa no llega a generar binario. Es la garantía más
fuerte que existe.

**Compile time, parcialmente probado.** Cuando los rangos se
pueden inferir de un análisis acotado, kaikai prueba lo
prudente sin invocar un solver SMT pesado. El alcance es
limitado: comparadores con literales sobre `Int`, `Bool`. Si
el predicado pasa por aritmética compleja o por
funciones que el compilador no puede inspeccionar, se difiere.

**Runtime.** Cuando lo anterior no es decidible, el compilador
emite un assert en el código generado. El programa compila;
el chequeo se hace al ejecutar la función. Si falla, aborta
con `panic: requires violated`.

Lo que kaikai **no hace**, deliberadamente, es **invocar un
solver SMT como Z3 o CVC5** para probar contratos
arbitrariamente complejos. Esa es la frontera con SPARK (el
subset verificable de Ada). kaikai prefiere un evaluador de
intervalos pequeño, decidible, lineal (y diferir el resto a
runtime), sobre tener compilación impredecible y dependencias
externas pesadas.

La regla mental: **lo que el compilador puede probar barato, lo
prueba; lo demás se prueba al ejecutarse**. El binario lleva
ambos casos sin que tengas que distinguir cuál de los dos
aplicó.

## 11.6 Tres formas de garantía

Llevamos tres mecanismos para "garantizar que el código hace
lo correcto" repartidos en tres capítulos:

| Mecanismo | Cap. | Qué garantiza | Cuándo se verifica |
|---|---|---|---|
| **`test`** | 7 | Para una entrada específica, la salida es esta | Bajo `kai test` |
| **`check`** | 7 | Para **toda** entrada, vale esta invariante | Bajo `kai check`, con valores generados |
| **Tipos suma + `match`** | 5 | Cubrir todos los casos posibles del tipo | Compile time |
| **Contratos + refinements** | 11 | Restricciones sobre entrada/salida y valores válidos | Compile time cuando se puede, runtime cuando no |

Las tres son herramientas distintas con áreas que se solapan.
Una función bien escrita probablemente las use todas:

- **Tipos** que son lo más estrechos posibles para el dominio
  (sum types, refinements, units of measure).
- **Contratos** que documentan lo que la función exige y
  garantiza, en términos relacionales.
- **Tests** que cubren los casos contractuales puntuales que
  el cliente pide.
- **Checks** que verifican las invariantes algebraicas
  ("invertir dos veces es identidad", "ordenar preserva
  el largo").

No son redundantes: cada uno atrapa una clase distinta de
bugs y los tres juntos forman una red de seguridad mucho más
densa que cualquiera por separado. Y los cuatro tienen costo
cero en runtime cuando no fallan: un `test` que pasa no se
ejecuta en producción; un contrato que se puede probar
estáticamente no genera assert; un refinement legal no genera
chequeo dinámico.

## 11.7 La familia Design by Contract

Los contratos no son invención de kaikai. Son una idea con
historia, y vale la pena ubicar a kaikai en esa historia.

**Eiffel (Bertrand Meyer, 1986)** introdujo el término "Design
by Contract" y la mayoría de las ideas: `require`/`ensure`
sobre métodos, invariantes de clase, herencia con
debilitamiento de precondiciones y fortalecimiento de
postcondiciones. La sintaxis canónica vive dentro del cuerpo:

```eiffel
deposit (amount: REAL)
  require
    positive_amount: amount > 0
  do
    balance := balance + amount
  ensure
    balance_increased: balance = old balance + amount
end
```

kaikai toma la idea pero pone los contratos en la **firma**,
no en el cuerpo, y elimina `old` porque los records son
inmutables.

**Ada 2012** agregó "aspect specifications" a Ada con la
sintaxis `with Pre =>`, `with Post =>`. Esto es lo más
parecido a kaikai estilísticamente:

```ada
function Divide (A, B : Integer) return Integer
  with Pre  => B /= 0,
       Post => Divide'Result * B = A;
```

El `with Pre => / Post =>` de Ada y el `requires / ensures` de
kaikai son la misma idea anotacional. Ada también introdujo
**subtypes con predicados** (`subtype Positive is Integer
range 1 .. Integer'Last`), que son los antepasados directos de
los refinement types de kaikai.

**SPARK** es el subset verificable de Ada, que usa un solver
SMT para probar contratos arbitrarios estáticamente. Kaikai
**no adopta esto a propósito**: SPARK requiere instalar Z3 o
similar, y los tiempos de compilación se vuelven impredecibles.
La doc del lenguaje (`refinements-and-contracts.md`) lo dice
explícito: el evaluador de intervalos es de unas pocas
centenas de líneas, decidible, lineal; lo que no entra ahí se
posterga a runtime sin remordimiento.

**D** tiene contratos similares a kaikai con la sintaxis
`in { ... } / out (result) { ... }`. **Cobra**, **Kotlin**
(con `require/check`), **Clojure** (con `:pre/:post`) son
otras versiones más livianas de la misma idea.

Lo que **distingue** a kaikai en esta familia:

1. **Sin SMT**. La línea de SPARK queda fuera. La consecuencia
   es que los contratos complejos se chequean en runtime; el
   beneficio es compilación rápida y sin dependencias
   externas.

2. **Pureza por defecto**. Eiffel y Ada manejan mutabilidad
   rampante; los contratos tienen que lidiar con `old` y
   aliasing. kaikai parte de inmutabilidad: la postcondición
   habla del input y del output como dos valores que coexisten,
   sin máquina extra.

3. **Continuidad con el resto del sistema de tipos**.
   Contratos y refinements son la **tercera pata** de
   "información en el tipo, costo cero en runtime", junto a
   efectos algebraicos y unidades de medida. Las tres usan el
   mismo patrón: declarar en la firma o en el tipo, chequear
   estáticamente cuando se puede, runtime cuando hace falta.
   Eiffel y Ada no tienen efectos algebraicos ni UoM, así que
   sus contratos viven más solos.

## 11.8 Lo que kaikai no hace, y por qué

Vale enumerar lo que kaikai **deliberadamente** no soporta:

- **No SMT solving**. Si tu contrato es `ensures result.entries
  == sort(c.entries)`, kaikai no va a probar estáticamente
  que tu cuerpo en efecto ordena la lista. Lo va a chequear
  en runtime.
- **No refinements arbitrarios sobre estructuras complejas**.
  `Real where 0.0 <= self <= 1.0` es legal. `[Int] where
  list.length(self) > 0` no está implementado en la versión
  inicial. La restricción se puede expresar con un sum type
  (`type ListaNoVacia = ...`) o un wrapper, pero no con un
  refinement directo.
- **No herencia de contratos** al estilo Eiffel. kaikai no
  tiene clases ni herencia; los contratos viven en la firma
  de cada función individual.

¿Por qué estas restricciones? El argumento es el mismo de
todo el lenguaje: **simplicidad y predecibilidad**. Un sistema
de tipos que invoca un solver es opaco: el programador no
sabe por qué su programa compila o no, y los mensajes de
error se vuelven incomprensibles. Un sistema acotado, que
prueba lo obvio y difiere lo demás, da garantías más débiles
pero **comprensibles**, y deja al runtime del programa
saludable como red de seguridad.

## 11.9 Caso de estudio: cuenta bancaria

Cerramos con una cuenta bancaria mínima, donde los contratos
documentan y aseguran el comportamiento.

```kai
type Cuenta = {
  titular: String,
  saldo: Int,
}

fn abrir(titular: String, deposito_inicial: Int) : Cuenta
  requires deposito_inicial >= 0
  ensures  result.saldo == deposito_inicial
=
  Cuenta { titular: titular, saldo: deposito_inicial }

fn depositar(c: Cuenta, monto: Int) : Cuenta
  requires monto > 0
  ensures  result.saldo == c.saldo + monto
=
  Cuenta { ...c, saldo: c.saldo + monto }

fn retirar(c: Cuenta, monto: Int) : Cuenta
  requires monto > 0
  requires c.saldo >= monto
  ensures  result.saldo == c.saldo - monto
=
  Cuenta { ...c, saldo: c.saldo - monto }
```

Tres operaciones, cinco precondiciones, tres postcondiciones.
Lectura humana:

- **`abrir`** abre una cuenta con saldo inicial no negativo.
  La postcondición confirma que el saldo de la cuenta nueva es
  exactamente lo depositado.
- **`depositar`** exige que el monto sea positivo (no
  acepta depósitos de cero o negativos), y promete que el
  saldo final es el inicial más el monto.
- **`retirar`** exige monto positivo y suficiente saldo, y
  promete que el saldo final es el inicial menos el monto.

¿Qué pasa si alguien (tú, en seis meses, con prisa)
escribe `retirar(cuenta, 0 - 50)` (pasando un negativo)? El
contrato `requires monto > 0` se viola y el programa aborta
con un mensaje que apunta a la línea exacta del `requires`.
No silencio, no comportamiento extraño, no saldo
inconsistente: aborto inmediato y diagnóstico.

¿Y si el cuerpo de `retirar` tuviera un bug (alguien cambia
`c.saldo - monto` por `c.saldo + monto` accidentalmente)? El
`ensures result.saldo == c.saldo - monto` se viola al salir
y aborta también. La postcondición es tu seguro contra bugs
internos, así como el `requires` es tu seguro contra abusos
del caller.

Con cuatro líneas de contratos, esta cuenta bancaria mínima
documenta sus reglas, las verifica al ejecutarse, y deja un
diagnóstico claro cuando se rompen. Compáralo con la versión
sin contratos:

```kai
fn retirar(c: Cuenta, monto: Int) : Cuenta =
  Cuenta { ...c, saldo: c.saldo - monto }
```

Funciona en el caso feliz. Pero un caller que pasa un negativo
acaba con una cuenta cuyo saldo creció (porque `c.saldo - (-50)
== c.saldo + 50`), y nadie se entera. Un caller que pasa más
monto que saldo termina con una cuenta de saldo negativo, y
nadie se entera. Los bugs que en kaikai con contratos son
abortos inmediatos, en kaikai sin contratos son saldos
silenciosamente incorrectos en producción.

## Ejercicios

**11.1.** Define `type Edad = Int where self >= 0 and self
<= 130`. Escribe `fn promedio_edades(a: Edad, b: Edad) :
Edad`. ¿En qué línea va a aparecer la verificación cuando
construyes una `Edad` desde un valor dinámico?

**11.2.** Toma la función `divide` del §11.2. Agrega una
postcondición que asegure que cuando `b > 0` y `a > 0`, el
resultado es no negativo. ¿Cómo se ve la postcondición?
¿Qué pasa si tu cuerpo tuviera un bug que devolviera un
negativo en algún caso?

**11.3.** Reescribe la cuenta bancaria del §11.9 usando un
**refinement type** para el saldo (`type SaldoValido = Int
where self >= 0`), y `Cuenta = { titular: String, saldo:
SaldoValido }`. ¿Qué precondiciones y postcondiciones se
vuelven redundantes con este cambio? ¿Qué información
pierde la firma?

**11.4.** Imagina una función `fn percentil(p: Probabilidad,
xs: [Real]) : Real`. ¿Qué precondiciones agregarías sobre
`xs`? ¿Qué postcondiciones documentan el comportamiento
correcto? ¿Cuál de las dos formas (refinement type o
contrato) usarías para cada restricción?

**11.5.** Lee `docs/refinements-and-contracts.md` del repo
de kaikai. Identifica una restricción que la doc menciona
como "post-MVP". Discute con un colega o con un agente IA
qué consecuencias tendría implementarla: qué clase de
errores nuevos atraparía, qué clase de programas se
volverían más cargados de chequeos.
