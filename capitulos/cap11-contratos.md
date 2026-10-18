# Capítulo 11 · Programación por contrato y refinement types

Con este capítulo cierras la Parte II y el hilo "información
en el tipo, costo cero en runtime" que abrieron las unidades de
medida (cap. 10). Lo rematan dos mecanismos que vienen de Eiffel
(1986) y Ada 2012: los **contratos** (precondiciones y
postcondiciones en la firma de una función) y los **refinement
types** (restricciones sobre los valores que un tipo admite).

Son ideas de hace cuarenta años, y sigo pensando que la industria
les hizo mucho menos caso del que merecían.

Los dos mecanismos comparten una idea: **enunciar restricciones
en el tipo, que el compilador las verifique cuando puede y las
difiera a runtime cuando no**. Difieren en el alcance: los
contratos hablan de **operaciones** (qué espera y qué garantiza
una función); los refinements, de **valores** (qué números o
strings son válidos). Se complementan.

## 11.1 Por qué contratos y refinements van juntos

Imagina que modelas una cuenta bancaria. La regla natural es
"el saldo nunca puede ser negativo", y puedes expresarla de dos
formas:

- **En el valor**: declarar `type SaldoValido = Int where
  self >= 0`. Cualquier valor de tipo `SaldoValido` cumple la
  regla por construcción; el compilador rechaza cualquier
  negativo.
- **En la operación**: declarar `fn retirar(c: Cuenta, monto:
  Int) : Cuenta requires c.saldo >= monto ensures
  result.saldo >= 0`. La función exige una condición sobre
  los argumentos y promete una sobre el resultado.

Las dos dicen lo mismo, y una sin la otra queda incompleta.
Los refinements describen **qué valores son legales**; los
contratos, **qué hacen las operaciones con esos valores**. Una
cuenta bancaria robusta usa los dos: saldo refinado a no
negativo y operaciones con precondiciones que mantienen la
regla.

kaikai los trata como un solo proyecto. La doc del lenguaje
(`refinements-and-contracts.md`) dice:

> Together they form a single coherent mechanism — types
> describe what values are valid, contracts describe what
> operations guarantee — and the two share most of the
> implementation machinery.

Por eso viven en el mismo capítulo.

## 11.2 `requires` y `ensures` en una firma

Un contrato se escribe como anotaciones en la firma de una
función, entre el tipo de retorno y el cuerpo:

```kai
fn divide(a: Int, b: Int) : Int
  requires b != 0
  ensures  result * b + (a % b) == a
= a / b
```

Las dos formas de cuerpo aceptan contratos. Cuando el cuerpo va
entre llaves, las cláusulas se escriben igual y la llave abre
después:

```kai
fn retirar(saldo: Int, monto: Int) : Int
  requires monto > 0
  requires saldo >= monto
  ensures  result == saldo - monto
{
  let restante = saldo - monto
  restante
}
```

Tres componentes:

- **`requires <expr>`**: una **precondición**. La expresión
  tiene que ser `true` al **entrar** a la función. Responde
  quien llama: si se viola, el bug está afuera.
- **`ensures <expr>`**: una **postcondición**. La expresión
  tiene que ser `true` al **salir** de la función. Responde el
  cuerpo: si se viola, el bug es interno.
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

Dos precondiciones (monto positivo y saldo suficiente) y una
postcondición (la cuenta resultante tiene exactamente
`c.saldo - monto`). Las precondiciones se verifican en orden al
entrar; la postcondición, al salir.

Tres detalles:

- **`requires` y `ensures` son código**: el compilador los
  emite como verificaciones reales. Si una precondición se
  viola en runtime, el programa aborta con un mensaje que
  incluye el valor que rompió el contrato y una pista de cómo
  descartarlo:

  ```
  panic: requires violated in `divide`
  required: b != 0
  declared at line 2, col 14
    = help: narrow `b` to `Int where != 0`
  argument b was: 0
  ```

  La línea `argument b was:` te muestra el valor ofensor sin
  reproducir el caso, y `help: narrow` apunta
  al refinement que habría convertido este abort de runtime en
  un error de compilación.

- **El compilador prueba estáticamente lo que puede**. Si
  llamas a `divide(10, 0)` con literales, ve que `b == 0` y
  rechaza la llamada en compile time. Con valores dinámicos,
  inserta el assert.

- **Los contratos se verifican también en `--release`**. El
  build optimizado no los apaga: un `requires` que depende de
  valores de runtime se sigue revisando ahí. Nadie demostró ese
  invariante, y sacarlo sería cambiar una garantía por un `if`.

## 11.3 `result` y los nombres en alcance dentro del `ensures`

Dentro de una postcondición tienes:

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

La primera dice "la salida es el doble de la entrada"; la
segunda, "la lista resultante tiene el mismo largo que la
entrada", una invariante razonable de cualquier ordenamiento.
Fíjate que **no** dice que `result` está ordenado. Las
postcondiciones documentan lo que vale la pena documentar; no
tienen que ser exhaustivas.

A diferencia de Eiffel, **no hay `old`**. En Eiffel necesitas
`ensures balance = old balance + amount` porque los records
son mutables y el `balance` que ves en el `ensures` ya cambió.
En kaikai los records son inmutables: el `c` que entra y el
`result` que sale son **valores distintos**, los dos en
alcance, y no hace falta nombrar "el valor antes de la
llamada".

Las dos cláusulas en firmas que corren, con `result` nombrando
el valor de retorno:

```kai
# ejemplos/cap11/01_contratos_basicos.kai
fn divide(a: Int, b: Int) : Int
  requires b != 0
  ensures result * b + a % b == a
= a / b

fn factorial(n: Int) : Int
  requires n >= 0
= if n <= 1 { 1 } else { n * factorial(n - 1) }

fn main() {
  println("10 / 3 = #{divide(10, 3)}")
  println("17 / 5 = #{divide(17, 5)}")
  println("5! = #{factorial(5)}")
  println("10! = #{factorial(10)}")
}
```

```
$ kai run ejemplos/cap11/01_contratos_basicos.kai
10 / 3 = 3
17 / 5 = 3
5! = 120
10! = 3628800
```

## 11.4 Refinement types

Los **refinement types** hablan de valores. Un refinement type
es un tipo base más un predicado:

```kai
type NoNeg = Int where self >= 0
type Probabilidad = Real where self >= 0.0 and self <= 1.0
type Edad = Int where self >= 0 and self <= 130
type Puerto = Int where self >= 1 and self <= 65535
```

El predicado se refiere a `self`, el valor restringido.
Cualquier valor de tipo `NoNeg` cumple `self
>= 0` por construcción; cualquier `Probabilidad` cae en el
intervalo unitario; cualquier `Puerto` está dentro del rango
TCP.

Para construir un valor del tipo refinado, el predicado tiene
que cumplirse. Con un literal, el compilador lo verifica en
compile time:

```kai
let x: NoNeg = 16        # OK: 16 >= 0
let y: NoNeg = -5     # ERROR: -5 no satisface self >= 0
```

Con un valor dinámico, inserta una verificación en runtime,
igual que con un `requires` cuyo argumento no se puede deducir
estáticamente.

Dos refinements declarados y usados, con las dos líneas que el
compilador rechaza comentadas al final:

```kai
# ejemplos/cap11/04_refinements.kai
type NoNeg = Int where self >= 0

type Probabilidad = Real where self >= 0.0 and self <= 1.0

fn doblar(n: NoNeg) : NoNeg = n + n

fn evento(p: Probabilidad, descripcion: String) : Unit / Stdout =
  println("#{descripcion} con prob #{p}")

fn main() {
  let x: NoNeg = 16
  println("doblar(16) = #{doblar(x)}")

  let pr: Probabilidad = 0.3
  evento(pr, "lluvia mañana")

  # Lo siguiente NO compila: -5 no satisface NoNeg.
  # let y : NoNeg = -5

  # Y esto tampoco: 1.5 no satisface 0.0 <= self <= 1.0.
  # let pr2 : Probabilidad = 1.5
}
```

```
$ kai run ejemplos/cap11/04_refinements.kai
doblar(16) = 32
lluvia mañana con prob 0.3
```

### Dónde se chequea: no solo en un `let`

El `let` es el caso fácil de ver, pero el chequeo va donde sea
que un valor **entre** a un tipo refinado: un campo de record,
el payload de un constructor, un elemento de lista, un `var`.
Cada uno es una construcción, y cada uno se verifica.

```kai
type Servicio = { nombre: String, puerto: Puerto }

let s = Servicio { nombre: "http", puerto: 0 }
```

```
error: record field 'puerto': literal 0 violates `self >= 1 and self <= 65535`
```

Con un literal que refuta, no compila. Con un valor que el
compilador no puede decidir, el chequeo baja a runtime y el
programa aborta mostrando el predicado:

```
panic: refinement violated in `main`
predicate: self >= 1 and self <= 65535
```

Esto importa más de lo que parece: no puedes contrabandear un
valor inválido metiéndolo dentro de una estructura. La frontera
del refinamiento es el tipo, en cualquier lugar donde aparezca.

### El refinamiento no entra solo a un genérico

Conoce este límite antes de chocar con él: una `[Int]` no se
vuelve `[Puerto]` por su cuenta:

```kai
fn abrir_todos(ps: [Puerto]) : Int = length(ps)

let crudos: [Int] = [80, 443]
abrir_todos(crudos)             # ERROR
```

```
error: argument 1 of `abrir_todos`: `[Int]` does not narrow to
`[Int where self >= 1 and self <= 65535]`: inside a generic type
nothing checks `self >= 1 and self <= 65535`; map the value
through a function that checks it
```

El error dice por qué: dentro de `[t]` no hay dónde poner el
chequeo. Verificar la lista entera sería un costo que no
pediste; dejarla pasar sería mentir. Así que lo haces
explícito: pasas los elementos por una función que devuelva
`Puerto`, y cada uno se verifica al entrar.

Con un tipo mutable la regla es más estricta, y en las dos
direcciones:

```
error: argument 1 of `cero`: `Array[Int where self >= 1 and self
<= 65535]` does not fit `Array[Int]`: a mutable type keeps its
refinements exactly
```

Tiene que ser así: si un `Array[Puerto]` pasara por
`Array[Int]`, quien lo recibe podría escribirle un cero y el
refinamiento quedaría roto a espaldas del dueño.

Las funciones que aceptan tipos refinados **aprovechan la
garantía sin verificarla**. Si tu firma dice `n: NoNeg`, adentro
supones `n >= 0` sin escribir un `if`: lo mismo que un
`requires n >= 0`, pero codificado en el tipo.

Cuándo usar uno u otro:

- **Refinement type** cuando la restricción **define qué es
  un valor válido** del dominio. `Edad`, `Probabilidad`,
  `Puerto`: el tipo no tiene sentido fuera de la restricción.
- **Contrato** cuando la restricción es **sobre la operación**.
  "no dividir por cero" es del operando de
  división; "el monto a retirar tiene que ser positivo" es de
  la operación retirar; "la lista resultante mantiene el
  largo" es del comportamiento de la función.

Cuando los dos aplican, eliges por legibilidad. La cuenta
bancaria del §11.9 usa contratos porque "el saldo no se puede
dejar negativo" es una propiedad del **comportamiento de las
operaciones**.

## 11.5 Cuándo se prueba estáticamente, cuándo en runtime

kaikai trata los contratos y los refinements como un
**continuo entre estático y dinámico**, decidido por lo que el
compilador puede demostrar. Tres niveles:

**Compile time, completamente probado.** Cuando los argumentos
son literales o el compilador conoce sus rangos:

```kai
divide(10, 0)              # ERROR de compilación: 0 != 0 es falso
let x: NoNeg = -5      # ERROR de compilación: -5 < 0
```

El programa ni siquiera genera binario: la garantía más fuerte
que puedes pedir.

**Compile time, parcialmente probado.** Cuando los rangos se
pueden inferir de un análisis acotado, kaikai prueba lo
prudente sin un solver SMT. El alcance es limitado:
comparadores con literales sobre `Int`, `Bool`. Si el predicado
pasa por aritmética compleja o por funciones que el compilador
no puede inspeccionar, se difiere.

**Runtime.** Cuando nada de lo anterior decide, el compilador
emite un assert. El programa compila y la verificación ocurre
al ejecutar la función; si falla, aborta con
`panic: requires violated`.

Lo que kaikai **no hace**, deliberadamente, es **invocar un
solver SMT como Z3 o CVC5** para probar contratos
arbitrariamente complejos. Esa es la frontera con SPARK (el
subset verificable de Ada). kaikai prefiere un evaluador de
intervalos pequeño, decidible, lineal, y diferir el resto a
runtime, antes que una compilación impredecible con
dependencias externas pesadas.

La regla mental: **lo que el compilador puede probar barato, lo
prueba; lo demás se prueba al ejecutarse**. No necesitas
distinguir cuál de los dos casos aplicó.

En este programa la línea comentada no compila porque el cero
es literal; la que queda compila y aborta al llegar al cero por
cálculo.

```kai
# ejemplos/cap11/02_violacion.kai
fn divide(a: Int, b: Int) : Int
  requires b != 0
= a / b

fn main() {
  println("antes")
  # Esto NO compila: el compilador detecta b == 0 con literal:
  # let bad = divide(10, 0)

  # Pero esto sí compila, y aborta en runtime:
  let cero_dinamico = 10 - 10
  let r = divide(10, cero_dinamico)
  println("nunca llegamos aquí: #{r}")
}
```

```
$ kai run ejemplos/cap11/02_violacion.kai
antes
panic: requires violated in `divide`
required: b != 0
declared at line 9, col 14
  = help: narrow `b` to `Int where != 0`
argument b was: 0
```

## 11.6 Cuatro formas de garantía

Ya conoces cuatro mecanismos para "garantizar que el código hace
lo correcto", repartidos en tres capítulos:

| Mecanismo | Cap. | Qué garantiza | Cuándo se verifica |
|---|---|---|---|
| **`test`** | 7 | Para una entrada específica, la salida es esta | Bajo `kai test` |
| **`check`** | 7 | Para **toda** entrada, vale esta invariante | Bajo `kai check`, con valores generados |
| **Tipos suma + `match`** | 5 | Cubrir todos los casos posibles del tipo | Compile time |
| **Contratos + refinements** | 11 | Restricciones sobre entrada/salida y valores válidos | Compile time cuando se puede, runtime cuando no |

Las cuatro se solapan en parte. Una función bien escrita
probablemente las use todas:

- **Tipos** que son lo más estrechos posibles para el dominio
  (sum types, refinements, units of measure).
- **Contratos** que documentan lo que la función exige y
  garantiza, en términos relacionales.
- **Tests** que cubren los casos contractuales puntuales que
  el cliente pide.
- **Checks** que verifican las invariantes algebraicas
  ("invertir dos veces es identidad", "ordenar preserva
  el largo").

Cada uno atrapa una clase distinta de bugs, y juntos protegen
mucho más que cualquiera por separado. En producción cuestan
poco: los `test` y los `check` no se ejecutan, el `match`
exhaustivo se verifica al compilar, y un contrato o refinement
que el compilador prueba no genera assert. Lo que no puede
probar queda como una comparación que se evalúa en runtime.

## 11.7 La familia Design by Contract

Los contratos tienen historia, y kaikai tiene un lugar en ella.

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

kaikai toma la idea, pero pone los contratos en la **firma** y
elimina `old` porque los records son inmutables.

**Ada 2012** agregó "aspect specifications" con la sintaxis
`with Pre =>`, `with Post =>`, lo más parecido a kaikai en
estilo:

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

**SPARK**, el subset verificable de Ada, usa un solver SMT para
probar contratos arbitrarios estáticamente. Kaikai **no lo
adopta a propósito**: SPARK requiere instalar Z3 o similar, y
los tiempos de compilación se vuelven impredecibles. La doc del
lenguaje (`refinements-and-contracts.md`) lo dice: el evaluador de intervalos es de unas pocas
centenas de líneas, decidible, lineal; lo que no entra ahí se
posterga a runtime sin remordimiento.

**D** tiene contratos similares a kaikai con la sintaxis
`in { ... } / out (result) { ... }`. **Cobra**, **Kotlin**
(con `require/check`), **Clojure** (con `:pre/:post`) son
otras versiones más livianas de la misma idea.

Lo que **distingue** a kaikai en esta familia:

1. **Sin SMT**. La línea de SPARK queda fuera. La consecuencia
   es que los contratos complejos se verifican en runtime; el
   beneficio es compilación rápida y sin dependencias
   externas.

2. **Pureza por defecto**. Eiffel y Ada manejan mutabilidad
   rampante; sus contratos lidian con `old` y aliasing. kaikai
   parte de la inmutabilidad: la postcondición habla de la
   entrada y la salida como dos valores que coexisten.

3. **Continuidad con el resto del sistema de tipos**.
   Contratos y refinements son la **tercera pata** de
   "información en el tipo, costo cero en runtime", junto a
   efectos algebraicos y unidades de medida. Las tres usan el
   mismo patrón: declarar en la firma o en el tipo, verificar
   estáticamente cuando se puede, runtime cuando hace falta.
   Eiffel y Ada no tienen efectos algebraicos ni UoM, así que
   sus contratos viven más solos.

## 11.8 Lo que kaikai no hace, y por qué

Esto es lo que decidí **no** implementar:

- **No SMT solving**. Si tu contrato es `ensures result.entries
  == sort(c.entries)`, kaikai no prueba estáticamente que tu
  cuerpo ordena la lista; lo verifica en runtime.
- **No refinements arbitrarios sobre estructuras complejas**.
  `Real where 0.0 <= self <= 1.0` es legal. `[Int] where
  list.length(self) > 0` no lo es: el refinement directo se
  acota a predicados sobre escalares. La restricción se expresa
  con un sum type (`type ListaNoVacia = ...`) o un wrapper.
- **No herencia de contratos** al estilo Eiffel. kaikai no
  tiene clases ni herencia; los contratos viven en la firma
  de cada función individual.

El argumento es el de todo el lenguaje: **simplicidad y
predecibilidad**. Un sistema de tipos que invoca un solver es
opaco: no sabes por qué tu programa compila o no, y los
mensajes de error se vuelven incomprensibles. Un sistema
acotado, que prueba lo obvio y difiere lo demás, da garantías
más débiles pero **comprensibles**, con el runtime como red de
seguridad.

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

Tres operaciones, cuatro precondiciones, tres postcondiciones.
En palabras:

- **`abrir`** abre una cuenta con saldo inicial no negativo.
  La postcondición confirma que el saldo de la cuenta nueva es
  exactamente lo depositado.
- **`depositar`** exige monto positivo y promete que el saldo
  final es el inicial más el monto.
- **`retirar`** exige monto positivo y suficiente saldo, y
  promete que el saldo final es el inicial menos el monto.

¿Qué pasa si alguien (tú, en seis meses, con prisa) escribe
`retirar(cuenta, -50)`? El programa no compila. La llamada está comentada al final de
`ejemplos/cap11/03_cuenta_bancaria.kai`; si la descomentas, el
compilador responde:

```
ejemplos/cap11/03_cuenta_bancaria.kai:49:17: error: call to `retirar`: literal args violate `monto > 0`
```

El argumento es una constante y el compilador la evalúa contra
el `requires`. Cuando el monto negativo llega desde afuera, de
un formulario o un archivo, el contrato se revisa al entrar y
el programa aborta apuntando a la línea exacta del `requires`.
Nada de fallar en silencio ni de arrastrar un saldo
inconsistente.

¿Y si alguien cambia por accidente `c.saldo - monto` por
`c.saldo + monto` en el cuerpo de `retirar`? El
`ensures result.saldo == c.saldo - monto` se viola al salir y
también aborta. La postcondición es tu seguro contra bugs
internos, así como el `requires` es tu seguro contra abusos
de quien llama.

Con siete líneas de contratos, esta cuenta documenta sus
reglas, las verifica al ejecutarse y deja un diagnóstico claro
cuando se rompen. Compárala con la versión sin contratos:

```kai
fn retirar(c: Cuenta, monto: Int) : Cuenta =
  Cuenta { ...c, saldo: c.saldo - monto }
```

Funciona en el caso feliz. Pero quien llama con un monto
negativo acaba con una cuenta cuyo saldo creció (porque
`c.saldo - (-50) == c.saldo + 50`), y quien retira más que el
saldo deja la cuenta en negativo. Nadie se entera. Los bugs que
con contratos son abortos inmediatos, sin contratos son saldos
incorrectos en producción.

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
volverían más cargados de verificaciones.
