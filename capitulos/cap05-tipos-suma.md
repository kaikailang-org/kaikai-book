# Capítulo 5 · Sum types, uniones y `match`

Este es el capítulo donde, si vienes de un lenguaje
imperativo, cambias la forma de modelar datos. Los tipos suma
y el `match` que los acompaña no son una construcción exótica:
son la herramienta que reemplaza a la mitad de las jerarquías
de clases, los `enum` con flags, los `instanceof` y los
visitor patterns que probablemente has venido escribiendo. Una
vez que los manejas, no quieres soltarlos. A mí me pasó
exactamente eso: llegué a la familia funcional tarde, con la
cabeza ya hecha a las jerarquías de clases, y después de los sum
types volver atrás se me hizo cuesta arriba.

El capítulo va de menos a más. Empezamos por los sum types
básicos, pasamos por la recursión en tipos, vemos `match` con
todas sus formas, llegamos a las uniones de tipos existentes
(una idea poco común en lenguajes mainstream) y cerramos
con un evaluador completo de expresiones aritméticas con
errores tipados.

## 5.1 Tipos suma con `|`

Un **tipo suma** declara que un valor puede ser uno de varios
constructores distintos. La sintaxis es directa:

```kai
type Color = Rojo | Verde | Azul
```

`Color` es un tipo. `Rojo`, `Verde`, `Azul` son sus tres
**constructores**. Un valor de tipo `Color` es exactamente uno
de los tres. No hay un cuarto valor escondido ni un `null`
acechando ni un "color desconocido": el tipo enumera sus
habitantes y ahí se acaba la historia.

Si vienes de un lenguaje con `enum`, esto se le parece, pero
con dos diferencias: los constructores **pueden cargar datos**,
y el compilador **verifica que los uses todos** cuando
decides según el constructor.

Empecemos por la primera. Un constructor puede recibir
parámetros posicionales, igual que un record con campos
numerados:

```kai
type Forma
  = Circulo(Real)
  | Rectangulo(Real, Real)
  | Triangulo(Real, Real, Real)
```

`Circulo(2.0)` es un valor de tipo `Forma` con un dato real
adentro. `Rectangulo(3.0, 4.0)` es otro valor de `Forma` con
dos datos. `Triangulo(3.0, 4.0, 5.0)` es un tercero. Los tres
caen bajo el mismo tipo `Forma`, pero el compilador sabe cuál
es cuál y nos obliga a manejarlos por separado cuando los
consumimos.

```kai
fn area(f: Forma) : Real =
  match f {
    Circulo(r)         -> 3.14159 * r * r
    Rectangulo(w, h)   -> w * h
    Triangulo(a, b, c) -> {
      let s = (a + b + c) / 2.0
      s
    }
  }
```

`match` es una expresión que decide según el constructor. Cada
rama es un patrón seguido de `->` y la expresión que esa rama
produce. Los patrones desempacan los datos al mismo tiempo: en
`Circulo(r)`, la `r` es la variable que ata el `Real` que
venía adentro del constructor. No hay un `cast` aparte ni un
acceso por índice; el patrón hace el trabajo.

Tres detalles que vas a usar siempre:

- **El compilador verifica exhaustividad.** Si quitas la rama
  `Triangulo(...)` y el compilador sabe que `f : Forma` puede
  ser un triángulo, no compila. Esto te salva de bugs sutiles
  cuando agregas un constructor nuevo: todos los `match` que no
  lo cubren se vuelven errores que apuntan exactamente a dónde
  falta atención.

- **Los constructores son nombres como cualquier otro.** Cuando
  declaras `type Color = Rojo | Verde | Azul`, kaikai crea
  cuatro símbolos: `Color` es el tipo, y `Rojo`, `Verde`,
  `Azul` son tres tipos a la vez (cada uno con un solo
  habitante, equivalente al de un valor). En el capítulo 9
  vamos a ver cómo este detalle te deja extender un sum type
  con protocolos definidos para sus constructores
  individualmente.

- **El operador `|` siempre significa unión de tipos.** Lo
  vamos a ver más en §5.5: `Color = Rojo | Verde | Azul`,
  `ErrorEval = ErrorAritmetico | ErrorAmbiente` y
  `Resultado = Ok(Int) | Err(String)` son la misma
  construcción. La diferencia entre "declarar tipos nuevos" y
  "componer tipos existentes" la decide el compilador
  inspeccionando si los nombres del lado derecho ya están
  declarados.

## 5.2 Constructores con y sin payload

Lo viste arriba pero conviene fijarlo. Un constructor puede:

- **No cargar datos** (`Rojo`, `Verde`, `Azul`). Es un valor
  único del tipo, sin parámetros.
- **Cargar uno o más datos posicionales** (`Circulo(Real)`,
  `Rectangulo(Real, Real)`). El constructor se aplica como una
  función a los datos para producir el valor.

No hay límite en cuántos datos puede cargar un constructor: la
gramática los acepta todos, pero por ergonomía, si pasas de
tres o cuatro datos posicionales conviene declarar un record y
ponerlo en el payload. La diferencia entre

```kai
type Evento
  = Login(String, String, Int, Bool)
  | Logout(String, Int)
```

y

```kai
type DatosLogin = { usuario: String, ip: String, timestamp: Int, exitoso: Bool }
type DatosLogout = { usuario: String, timestamp: Int }
type Evento = Login(DatosLogin) | Logout(DatosLogout)
```

es que el segundo se lee mejor en cualquier lugar donde
construyas o destructures un evento. Como lo veo yo: si los
datos se nombran solos por su posición (un punto es `(Real,
Real)`), quedan posicionales. Si los datos requieren que el
lector recuerde el orden, conviene un record.

## 5.3 Recursión en tipos

Aquí empieza lo poderoso. Un constructor de un tipo suma puede
mencionar al tipo en sus campos. Eso te da árboles, listas,
grafos pequeños y la representación de cualquier estructura
con anidamiento.

Un árbol binario:

```kai
type Arbol
  = Hoja
  | Nodo(Int, Arbol, Arbol)
```

`Arbol` es `Hoja` (sin datos) o `Nodo` con un entero y dos
subárboles. Los subárboles son del mismo tipo `Arbol`, así que
pueden ser a su vez `Hoja` o `Nodo`, recursivamente, hasta la
profundidad que quieras.

Una función sobre un árbol también es recursiva: el caso base
es `Hoja`, el caso recursivo desciende por los hijos.

```kai
fn altura(t: Arbol) : Int =
  match t {
    Hoja              -> 0
    Nodo(_, izq, der) -> 1 + max_int(altura(izq), altura(der))
  }
```

El patrón `Nodo(_, izq, der)` ignora el dato del nodo (no nos
interesa para calcular altura) y ata los dos subárboles a las
variables `izq` y `der`. Después se recurre sobre cada uno y se
toma el máximo más uno.

Lo mismo aplica a un AST de expresiones aritméticas:

```kai
type Expr
  = Lit(Int)
  | Suma(Expr, Expr)
  | Mul(Expr, Expr)
  | Neg(Expr)

fn eval(e: Expr) : Int =
  match e {
    Lit(n)       -> n
    Suma(a, b)   -> eval(a) + eval(b)
    Mul(a, b)    -> eval(a) * eval(b)
    Neg(x)       -> -eval(x)
  }
```

Construir una expresión es transparente: `Mul(Neg(Suma(Lit(2),
Lit(3))), Lit(4))` es la representación literal de `-(2 + 3) *
4`, que evaluada da `-20`. El árbol y el código que lo recorre
se escriben prácticamente solos, una vez que sabes mirarlo
así.

Esto reemplaza a las jerarquías de clases con visitor patterns
en lenguajes OO. La diferencia clave: en kaikai, agregar un
nodo nuevo a `Expr` se hace en una línea, y todos los `match`
sobre `Expr` en el código se vuelven errores de compilación que
apuntan a los lugares que necesitan atención. En un visitor
pattern, agregas un método nuevo en cada subclase y el
compilador no te ayuda a no olvidar ninguno.

## 5.4 `match`: patrones, guardas, exhaustividad

Ya viste `match` en acción. Aquí lo formalizamos.

Un `match` toma una **expresión escrutinio** (lo que se está
inspeccionando) y una serie de **arms**, cada uno con un
**patrón** seguido de `->` y la expresión que esa rama
produce. La rama cuyo patrón calza con el valor del escrutinio
es la que se ejecuta; su valor es el valor del `match`.

Los patrones que kaikai acepta:

- **Literales**: `0`, `"hola"`, `true`. Calzan con el valor
  exacto.
- **Constructores**: `Some(x)`, `Lit(n)`, `Suma(a, b)`. Calzan
  con el constructor y atan los datos a las variables.
- **Records**: `Punto { x, y }`, `Punto { x: 0, y: _ }`.
- **Listas**: `[]`, `[h, ...t]`, `[unico]`, `[primero, segundo, ...]`.
- **Wildcard**: `_`. Calza con cualquier cosa, no ata nada.
- **Variable**: cualquier identificador no declarado. Calza
  con cualquier cosa y ata el valor a esa variable.

Los patrones se anidan: `Some(Punto { x, y })` calza con un
`Some` que contiene un `Punto`, y desempaca `x` e `y` en una
sola pasada.

### Guardas

Un patrón puede ir seguido de `if` y una condición, una
**guarda**, que se evalúa después del match estructural. Si
la guarda es falsa, la rama no se considera y se sigue con la
siguiente:

```kai
fn signo(n: Int) : String =
  match n {
    0           -> "cero"
    k if k > 0  -> "positivo"
    _           -> "negativo"
  }
```

El patrón `k if k > 0` calza con cualquier entero, lo ata a
`k`, y entonces evalúa `k > 0`. Si es verdad, ejecuta la rama;
si no, sigue. La rama final con `_` no tiene guarda y calza
con todo lo restante: los enteros que no son cero ni
positivos.

Las guardas son convenientes pero no participan en la
verificación de exhaustividad: el compilador no puede saber que
`k > 0` y `k < 0` se complementan, así que necesita un patrón
final sin guarda que cubra el caso "todo lo demás". Si lo
omites, no compila.

### Exhaustividad

El compilador verifica que **todos los habitantes posibles**
del tipo del escrutinio estén cubiertos. Si tu `Expr` tiene
cuatro constructores y tu `match` cubre tres, no compila, y
el mensaje no se queda en "falta algo": te dice qué falta,
qué cubriste y cómo arreglarlo:

```
error: non-exhaustive match on Expr: missing Neg
  --> evaluador.kai:12:3
    |
 12 |   match e {
    |   ^
  = note: missing variant: `Neg`
  = note: covered: Lit, Suma, Mul
  = help: add an arm `Neg -> ...` or a wildcard `_ -> ...`
```

El wildcard `_` cubre todo lo que las ramas anteriores no
hayan cubierto, así que un `match` con un `_` final es
trivialmente exhaustivo. Pero usar `_` como rama final en
lugar de enumerar los casos es una forma de **silenciar** la
ayuda del compilador: cuando agregues un constructor nuevo a
`Expr`, los `match` con `_` final lo absorberán sin
quejarse, y vas a perder el aviso.

Mi regla: usa `_` solo cuando de verdad no te
interesa distinguir el resto. Si los casos son tres y los tres
te importan, escribe los tres.

## 5.5 Uniones de tipos existentes

Hasta ahora todos los `|` que hemos visto tenían **nombres
nuevos** del lado derecho (`Rojo`, `Verde`, `Lit`,
`Circulo`) que kaikai auto-declara como constructores. Pero
el operador `|` no exige nombres nuevos. Si los nombres del
lado derecho **ya están declarados como tipos**, kaikai
construye una **unión** que puede llevar cualquier valor de
esos tipos.

Esto es la herramienta clave para componer errores entre
capas:

```kai
type ErrorIdentidad = CuentaNoExiste | KycVencido | Congelada
type ErrorAuth      = SaldoInsuficiente | LimiteDiario

type ErrorConsulta = ErrorIdentidad | ErrorAuth
```

`ErrorConsulta` es la unión de los dos tipos previos. Un valor
de `ErrorConsulta` es **cualquier** valor de `ErrorIdentidad`
o **cualquier** valor de `ErrorAuth`. No hay envoltorio nuevo:
`CuentaNoExiste` ya era un valor válido, y ahora es también un
valor válido de `ErrorConsulta`.

Ese paso se llama **upcast implícito**: una variable tipada
`ErrorIdentidad` calza donde se espera `ErrorConsulta`, sin
conversión:

```kai
let id_err : ErrorIdentidad = CuentaNoExiste
let qb_err : ErrorConsulta  = id_err     # OK, sin ceremonia
```

Esto es lo que en otros lenguajes te obliga a escribir
constructores wrapper (`QBIdentity(IdentityError)`),
implementaciones de `From` o conversiones manuales con
`map_err`. En kaikai no hay ninguna de esas tres cosas: el
compilador sabe que `ErrorIdentidad` es un componente de
`ErrorConsulta` y reescribe el upcast por ti.

### Pattern matching sobre uniones

Un `match` sobre un valor de unión tiene dos sabores que
kaikai te deja **mezclar libremente**.

El primero, ya conocido, es enumerar todos los constructores
individualmente:

```kai
fn describir(e: ErrorConsulta) : String =
  match e {
    CuentaNoExiste     -> "id: cuenta no existe"
    KycVencido         -> "id: KYC vencido"
    Congelada          -> "id: cuenta congelada"
    SaldoInsuficiente  -> "auth: saldo insuficiente"
    LimiteDiario       -> "auth: límite diario"
  }
```

Esto funciona, pero es tedioso para uniones grandes. Y peor,
si un componente crece (agregas `RegulatoryHold` a
`ErrorAuth`), el `match` se vuelve un error de compilación
en cinco lugares en vez de uno.

El segundo sabor es el **patrón de narrowing** `bind :
ComponentType`, que calza cuando el valor pertenece al
componente nombrado y lo amarra bajo ese tipo más estrecho:

```kai
fn describir(e: ErrorConsulta) : String =
  match e {
    ie : ErrorIdentidad -> "id: " ++ id_str(ie)
    ae : ErrorAuth      -> "auth: " ++ auth_str(ae)
  }
```

Cada rama delega en una función que conoce ese componente
específico. Si `ErrorAuth` crece, solo cambia `auth_str`. El
`match` sobre `ErrorConsulta` ni se entera.

Las dos formas también se mezclan en un mismo `match` cuando
quieres extraer un caso específico y delegar el resto:

```kai
match e {
  CuentaNoExiste      -> "id: específicamente, cuenta no existe"
  ie : ErrorIdentidad -> "id: " ++ id_str(ie)        # KycVencido, Congelada
  ae : ErrorAuth      -> "auth: " ++ auth_str(ae)
}
```

El compilador trata las ramas de narrowing como si cubrieran
todos los constructores de su componente, así que la
exhaustividad cierra correctamente.

### Una limitación deliberada: el upcast no encadena

Hay una regla de kaikai que es importante conocer. El upcast
implícito **vale solo un paso**. Imagina tres tipos
encadenados, cada uno conteniendo al anterior:

```kai
type ErrorIdentidad = CuentaNoExiste | KycVencido
type ErrorAuth      = SaldoInsuficiente | LimiteDiario
type ErrorConsulta  = ErrorIdentidad | ErrorAuth
type ErrorRuteo     = NoEncontrado | ServidorCaido
type ErrorApp       = ErrorConsulta | ErrorRuteo

fn manejar_app(e: ErrorApp) : String = "..."
```

Y un valor del tipo más interno:

```kai
let id : ErrorIdentidad = CuentaNoExiste
manejar_app(id)        # ERROR: ErrorIdentidad no es componente directo
                       # de ErrorApp.
```

Aunque lógicamente todo `ErrorIdentidad` es un `ErrorApp` (vía
`ErrorConsulta`), el compilador no busca esa cadena. Para
pasar de `ErrorIdentidad` a `ErrorApp` tienes que escribir el
salto intermedio explícito:

```kai
let q : ErrorConsulta = id           # un paso: ErrorIdentidad → ErrorConsulta
manejar_app(q)                        # otro paso: ErrorConsulta → ErrorApp
```

Lo dejé así a propósito. Subtipado encadenado vuelve la
inferencia de tipos frágil y los mensajes de error confusos. La regla
"un paso" mantiene a kaikai con un sistema de tipos
predecible y con mensajes que apuntan al lugar correcto.

## 5.6 Errores como uniones, sin wrappers

Las uniones son tan útiles para errores que vale la pena
detenerse en el patrón. Cuando una función puede fallar de
varias maneras y esas maneras se descomponen en categorías
claras, el patrón natural es:

1. Cada categoría es un sum type pequeño.
2. El error compuesto es la unión de las categorías.
3. Cada función devuelve `Result[T, ErrorCompuesto]`.
4. El operador `!` propaga el error de cualquier capa hasta
   el `Result` compuesto, vía el upcast implícito.

```kai
fn check_identidad(req: Req) : Result[Cuenta, ErrorIdentidad] = ...
fn check_auth(c: Cuenta) : Result[Aprobado, ErrorAuth] = ...

fn consultar_saldo(req: Req) : Result[Saldo, ErrorConsulta] = {
  let cuenta = check_identidad(req)!     # ErrorIdentidad <: ErrorConsulta
  let app    = check_auth(cuenta)!       # ErrorAuth     <: ErrorConsulta
  Ok(cargar_saldo(app))
}
```

Cada `!` desempaca el `Ok` y propaga el `Err` con el upcast
correcto al `Result[_, ErrorConsulta]` que devuelve la función
externa. Cero wrappers, cero `map_err`, cero `From`. La firma
de `consultar_saldo` documenta exactamente qué errores puede
emitir, y el compilador se asegura de que todos estén
cubiertos cuando alguien la consume.

### Lo que `!` hace por dentro

Vale la pena mirar el operador con un poco más de cuidado,
porque la primera vez parece mágico. **`!` es un `return`
temprano disfrazado de operador.** La línea

```kai
let cuenta = check_identidad(req)!
```

es exactamente equivalente a:

```kai
let cuenta = match check_identidad(req) {
  Ok(x)  -> x                  # desempaca y sigue
  Err(e) -> return Err(e)      # sale de consultar_saldo con ese error
}
```

Sobre `Option[A]` el desugar es análogo: `Some(x)` desempaca,
`None` provoca `return None`.

Tres cosas que conviene fijar:

- **No es un `panic` ni una excepción.** El programa no aborta;
  la función actual termina normalmente devolviendo el `Err` o
  el `None` a quien la llamó. El control sale **un solo
  nivel**, no más allá.
- **Solo funciona si la función actual devuelve un tipo
  compatible.** Si tu función devuelve `Int`, no puedes usar
  `!` sobre un `Result` adentro: el `return Err(e)` no
  tendría dónde aterrizar. El compilador te lo dice claro.
- **El upcast sucede en el `return`.** Cuando
  `check_identidad(req)` devuelve `Result[_, ErrorIdentidad]`
  pero `consultar_saldo` declara `Result[_, ErrorConsulta]`,
  el `return Err(e)` aplica el upcast `ErrorIdentidad <:
  ErrorConsulta` al pasar. Por eso `!` y las uniones de
  errores se llevan tan bien: cada nivel de la cascada absorbe
  el error de la capa inferior sin escribir conversiones.

Si vienes de Rust, este es exactamente el operador `?`. Si
vienes de Swift, es lo que `try` con `throws` hace. Si vienes
de Haskell, es la `do`-notation sobre `Either` colapsada en un
solo símbolo.

Compáralo con la versión imperativa típica:

```python
# Python: nada en el tipo de retorno te dice qué puede fallar
def consultar_saldo(req):
    cuenta = check_identidad(req)   # puede tirar AccountNotFound, KycExpired...
    app    = check_auth(cuenta)     # puede tirar InsufficientBalance...
    return cargar_saldo(app)
```

El que llama a `consultar_saldo` en Python tiene que leer el
código de las funciones internas (o la doc, si la hay) para
saber qué excepciones esperar. En kaikai, la firma se lo dice.

## 5.7 Caso de estudio: evaluador con errores tipados

Cerramos el capítulo con un caso integrador. Vamos a construir
un evaluador de expresiones aritméticas con tres categorías de
error:

- **Aritméticos**: división por cero, raíz de un número
  negativo.
- **De ambiente**: variable no definida.

Los dos forman una unión, `ErrorEval`, y el evaluador devuelve
`Result[Real, ErrorEval]`. El código completo está en
`ejemplos/cap05/05_evaluador.kai`; aquí vamos paso a paso por
las partes interesantes.

### El AST

```kai
type Expr
  = Lit(Real)
  | Var(String)
  | Suma(Expr, Expr)
  | Mul(Expr, Expr)
  | Div(Expr, Expr)
  | Raiz(Expr)
```

Cinco constructores, dos de ellos recursivos. `Var(String)`
introduce una novedad respecto al evaluador del cap. 1: ahora
las expresiones pueden referenciar variables, así que el
evaluador necesita un **ambiente** que asocie nombres a
valores.

### Los errores

```kai
type ErrorAritmetico = DivCero | RaizNegativa(Real)
type ErrorAmbiente   = NoDefinida(String)
type ErrorEval       = ErrorAritmetico | ErrorAmbiente
```

Tres tipos: dos categorías y la unión. Cuatro constructores
en total, pero distribuidos en categorías que tienen sentido
por sí mismas. `RaizNegativa(Real)` carga el valor que se
intentó pasar a la raíz: es información útil para el
mensaje de error final. `NoDefinida(String)` carga el nombre
de la variable que faltaba.

### El ambiente

```kai
type Env = [(String, Real)]

fn lookup(env: Env, nombre: String) : Result[Real, ErrorEval] {
  case [], _                          -> Err(NoDefinida(nombre))
  case [(k, v), ...], n when k == n   -> Ok(v)
  case [_, ...resto], n               -> lookup(resto, n)
}
```

`Env` es un alias para una lista de pares: recorrido lineal,
suficiente para un evaluador de juguete. `lookup` está escrito
en la **forma multi-clause** del cap. 6: cada `case` lista un
patrón por argumento separado por coma (aquí `env` y `nombre`),
con un `when` opcional para guardas. Tres casos:

- Lista vacía: la variable no estaba; devolvemos un error.
- Cabeza con la clave que buscamos: éxito.
- Cualquier otra cabeza: seguimos en la cola.

Fíjate que el `Err` es del tipo `ErrorEval`, no
`ErrorAmbiente`, pero `NoDefinida(nombre)` se construye como
`ErrorAmbiente` y el upcast implícito lo promueve a
`ErrorEval` en el sitio del retorno, sin conversión explícita.

`eval` (a continuación) usa la forma con `match` envoltorio
porque dispatcha sobre un tipo suma con muchos constructores
y la forma `match e { ... }` se lee mejor cuando el discrimen
es sobre un solo argumento de tipo bien marcado. Las dos
formas conviven en el mismo archivo sin tensión.

### El evaluador

```kai
fn eval(env: Env, e: Expr) : Result[Real, ErrorEval] =
  match e {
    Lit(n)      -> Ok(n)
    Var(nombre) -> lookup(env, nombre)
    Suma(a, b)  -> {
      let va = eval(env, a)!
      let vb = eval(env, b)!
      Ok(va + vb)
    }
    Mul(a, b)   -> {
      let va = eval(env, a)!
      let vb = eval(env, b)!
      Ok(va * vb)
    }
    Div(a, b)   -> {
      let va = eval(env, a)!
      let vb = eval(env, b)!
      if vb == 0.0 { Err(DivCero) } else { Ok(va / vb) }
    }
    Raiz(x)     -> {
      let v = eval(env, x)!
      if v < 0.0 { Err(RaizNegativa(v)) } else { Ok(raiz(v)) }
    }
  }
```

Cada caso de `match` corresponde a un constructor de `Expr`.
Los casos recursivos usan `!` para evaluar los subárboles y
propagar cualquier error que aparezca; los casos que pueden
fallar localmente (división por cero, raíz negativa)
construyen un `Err` del tipo apropiado y dejan que el upcast
los promueva.

El operador `!` aparece varias veces y vale la pena leerlo con
calma. `eval(env, a)!` significa: si `eval(env, a)` devuelve
`Ok(v)`, ata `va` a `v`; si devuelve `Err(e)`, **sale
inmediatamente** de la función actual devolviendo ese `Err`.
En este caso particular, el `Err` que se propaga es
`Result[_, ErrorEval]`, y como `eval` devuelve exactamente
ese tipo, el upcast es trivial. Pero la misma forma funciona
cuando los tipos de error de las llamadas internas son
componentes distintos de la unión.

### Imprimiendo el resultado

```kai
fn describir(e: ErrorEval) : String =
  match e {
    DivCero            -> "división por cero"
    RaizNegativa(v)    -> "raíz de número negativo (" ++ real_to_string(v) ++ ")"
    NoDefinida(nombre) -> "variable no definida: " ++ nombre
  }

fn imprimir(r: Result[Real, ErrorEval]) : Unit =
  match r {
    Ok(v)  -> println("ok: " ++ real_to_string(v))
    Err(e) -> println("error: " ++ describir(e))
  }
```

`describir` consume un `ErrorEval` enumerando sus tres
constructores. Aquí el `match` enumera porque queremos
mensajes específicos por constructor; en otros casos,
cuando la lógica para cada categoría difiere, usaríamos
narrowing.

El programa principal arma el ambiente, evalúa varias
expresiones y las imprime:

```kai
fn main() {
  let env : Env = [("x", 9.0), ("y", 4.0)]

  imprimir(eval(env, Suma(Var("x"), Var("y"))))    # ok: 13
  imprimir(eval(env, Raiz(Var("x"))))              # ok: 3
  imprimir(eval(env, Div(Lit(10.0), Lit(0.0))))    # error: división por cero
  imprimir(eval(env, Raiz(Lit(0.0 - 1.0))))        # error: raíz de negativo
  imprimir(eval(env, Var("z")))                     # error: variable no definida: z
}
```

Lo bonito de este caso: cada error está documentado en el
tipo del evaluador. Si más adelante quieres agregar un
**ErrorTipo** (por ejemplo, intentar sumar dos cosas que no
son números), declaras la categoría nueva, la incluyes en
`ErrorEval`, y el compilador te lleva a todos los lugares que
necesitan adaptarse.

## Ejercicios

**5.1.** Define `type Maybe[a] = Just(a) | Nothing` (que es
otra forma de `Option`) y escribe `fn or_else[a](m: Maybe[a],
default: a) : a` que devuelva el valor si es `Just`, o el
default si es `Nothing`. Nota: el nombre `Nothing` también es
un tipo primitivo de kaikai (el bottom type del cap. 3); usa
`Vacio` u otro nombre si te molesta el shadowing.

**5.2.** Extiende el evaluador del §5.7 para que admita
restas: agrega `Resta(Expr, Expr)` al AST, agrégalo al `match`
de `eval`, y verifica que `2 - 3` evalúe a `-1`. ¿Cuántas
líneas tuviste que cambiar? ¿Cuántos lugares tocó el
compilador?

**5.3.** Define un árbol de decisión binario:

```kai
type Decision[a]
  = Hoja(a)
  | Pregunta(String, Decision[a], Decision[a])
```

donde una `Pregunta` tiene un texto, una rama `sí` y una rama
`no`. Escribe `fn aplicar[a](d: Decision[a], respuestas: [(String, Bool)]) : Option[a]`
que recorra el árbol siguiendo las respuestas a cada
pregunta, y devuelva `Some` con la decisión final si llega a
una hoja, o `None` si en alguna pregunta no hay respuesta.

**5.4.** Tomas el ejemplo de uniones con `ErrorIdentidad` y
`ErrorAuth`. Agrega un tercer componente `ErrorRedAdministrativa`
con dos constructores. Reescribe el `match` con narrowing
para que el código quede igual de corto. Luego agrega un
constructor nuevo a `ErrorAuth` (digamos `Bloqueado`): ¿qué
pasa con tu código? ¿En cuántos lugares interviene el
compilador?

**5.5.** Crea un sum type para representar un mensaje de
chat: `type Mensaje = Texto(String) | Imagen(String, Int, Int) |
Audio(String, Int)` (ruta, dimensiones o duración). Escribe
una función `fn descripcion(m: Mensaje) : String` que
devuelva una descripción humana, y una función
`fn pesado(m: Mensaje) : Bool` que devuelva `true` si el
mensaje es de imagen o audio. La segunda función debería
usar narrowing en el `match`, no enumerar.

**5.6.** En un papel, dibuja el árbol de evaluación que
construye el evaluador del §5.7 cuando procesa la expresión
`Mul(Suma(Var("x"), Lit(2.0)), Var("y"))` con el ambiente
`[("x", 9.0), ("y", 4.0)]`. ¿Cuántas llamadas a `eval` hace?
¿Cuántas a `lookup`? ¿En qué orden? Esto te ayuda a entender
por qué el operador `!` corta la ejecución apenas algo falla:
tres llamadas en cascada, una sola línea por nivel.
