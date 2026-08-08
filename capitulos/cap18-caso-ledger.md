# Capítulo 18 · Caso de estudio: ledger contable

El capítulo 17 mostró un servidor HTTP: muchos clientes, una
fibra por conexión, actores para encapsular estado. Es la
familia de problemas donde lo que pesa es la concurrencia.

Este capítulo cierra el libro con un caso muy distinto: **un
libro mayor contable**, donde lo que pesa es la precisión y no
la concurrencia. Un débito que no calza con su crédito es un
bug que tu auditor va a encontrar antes que tú, y aquí
"funciona y pasa los tests" no alcanza: hay que poder mostrar
**por qué** funciona. Elegí este caso porque es el terreno en
que más he trabajado, y porque es donde un error de tipos deja
de ser una molestia y se convierte en plata. El sistema de tipos
tiene mucho que
decir al respecto.

Por qué fintech merece su propio capítulo: es uno de los
dominios donde más caro sale equivocarse y donde más rinde
tener garantías en el tipo. Mezclar USD con EUR cuesta plata;
también sumar débitos con créditos, o permitir un retiro
sin verificar saldo. Las herramientas del
lenguaje (unidades de medida, contratos, branding) están
hechas para que estas equivocaciones no compilen, no para que
las descubras en producción.

El programa: un ledger de doble entrada que mantiene cuentas
con saldo, registra transacciones (cada una con débitos y
créditos), valida que las transacciones cuadren, y persiste
un log de auditoría inmutable. Tamaño: unas 280 líneas en cinco
módulos.

## 18.1 La forma del programa

Cinco archivos:

```
ledger/
├── kai.toml             # manifest
├── main.kai             # entry point, ejecuta operaciones de ejemplo
├── dominio.kai          # tipos: Cuenta, Movimiento, Transaccion
├── cuadre.kai           # validación de la invariante débito = crédito
├── almacen.kai          # actor que guarda cuentas y transacciones
└── persistencia.kai     # actor que escribe el log de auditoría
```

La estructura es deliberadamente similar al cap. 17. Lo que
cambia es el énfasis:

- **`dominio.kai`** es más rico que el del cap. 17. Aparecen
  unidades de medida (`Real<USD>`), branded types
  (`Int<CuentaId>`, `Int<TransaccionId>`), y un sum type
  `Movimiento` que distingue débitos de créditos.
- **`cuadre.kai`** es nuevo. Es un módulo dedicado a una
  invariante: la suma de débitos en una transacción debe
  igualar la suma de créditos. Aparece como función pura
  testeable Y como **contrato** (`requires`) sobre la
  operación de registrar.
- **`almacen.kai`** es el actor de siempre, pero ahora valida
  cuadre antes de aceptar una transacción y mantiene saldos
  por cuenta. Las transacciones son **inmutables**: solo se
  agregan, nunca se modifican.
- **`persistencia.kai`** es el log de auditoría. Idea conceptual
  fuerte: en contabilidad, lo escrito queda. El archivo es
  evidencia legal.

## 18.2 El dominio: unidades, branding, tipos algebraicos

El centro del programa son los tipos:

```kai
pub unit USD

pub unit CuentaId
pub unit TransaccionId

#[derive(Show)]
pub type Cuenta = {
  id:     Int<CuentaId>,
  nombre: String,
  saldo:  Real<USD>,
}

#[derive(Show)]
pub type Movimiento
  = Debito(Int<CuentaId>, Real<USD>)
  | Credito(Int<CuentaId>, Real<USD>)

#[derive(Show)]
pub type Transaccion = {
  id:           Int<TransaccionId>,
  descripcion:  String,
  movimientos:  [Movimiento],
}
```

Tres decisiones del sistema de tipos vale enumerar:

- **`Real<USD>` en vez de `Real`.** El cap. 10 cubrió las
  unidades de medida. En este dominio importan especialmente:
  un programa contable que mezcla USD con EUR sin convertir
  produce números que parecen correctos pero no significan
  nada. Con UoM, esa mezcla no compila. Para extender el
  programa a múltiples monedas, declaras `unit EUR`, defines
  una tasa de cambio como `Real<USD / EUR>`, y el sistema de
  tipos te lleva de la mano. Sin UoM, lo descubres cuando un
  cliente reclama. (El stdlib trae además `money`, con
  `Money[c: Currency]` sobre `Decimal` y las monedas ISO
  declaradas; el capítulo 19 lo cubre. Aquí seguimos con
  `Real<USD>` porque el punto es la técnica de UoM.)
- **`Int<CuentaId>` vs `Int<TransaccionId>`.** El cap. 10
  cubrió también los branded types. Tener `Int` puro como id
  significa que pasar un id de transacción donde se espera un
  id de cuenta compila igual y revienta en runtime (o peor,
  sin avisar produce un resultado equivocado). Con
  branding, el sistema de tipos te lo dice antes.
- **`Movimiento` como sum type.** Un débito y un crédito
  tienen los mismos campos físicos (cuenta + monto), pero
  significan cosas distintas. Modelarlos como dos
  constructores del mismo sum type tiene dos efectos: el
  pattern match exhaustivo asegura que cualquier operación
  los trate explícitamente, y el sistema de tipos no nos deja
  sumar "monto de débito" con "monto de crédito" sin que
  pasemos por una conversión clara.

Compárese con la versión sin tipos ricos: un record `{
cuenta: Int, monto: Real, tipo: String }` donde `tipo` es
`"debito"` o `"credito"`. Funciona, pero el `tipo: String`
permite `"DEBITO"`, `"CR"`, `""`, todas inválidas. Cada
función que toca movimientos tiene que validarlo. Con el sum
type, el inválido **no se puede construir**.

## 18.3 La invariante central: cuadre

El módulo `cuadre.kai` es chico pero importante. Define la
invariante del ledger de doble entrada: en cada transacción,
la suma de los débitos debe igualar la suma de los créditos.

```kai
pub fn total_debitos(ms: [dominio.Movimiento]) : Real<USD> {
  match ms {
    []                               -> 0.0<USD>
    [dominio.Debito(_, m), ...rest]  -> m + total_debitos(rest)
    [dominio.Credito(_, _), ...rest] -> total_debitos(rest)
  }
}

pub fn total_creditos(ms: [dominio.Movimiento]) : Real<USD> { ... }

pub fn cuadra(ms: [dominio.Movimiento]) : Bool =
  total_debitos(ms) == total_creditos(ms)
```

Son tres funciones puras que definen una sola invariante
booleana. Los tests verifican el contrato pieza por pieza:

```kai
test "cuadra con una entrada y una salida" {
  let ms = [
    dominio.Debito(1<CuentaId>, 100.0<USD>),
    dominio.Credito(2<CuentaId>, 100.0<USD>),
  ]
  assert cuadra(ms)
}

test "no cuadra cuando los montos difieren" { ... }
test "cuadra con múltiples líneas" { ... }
```

No hay actores, ni IO, ni sockets: pura lógica. Si en seis
meses cambiamos cómo se representan los movimientos, estos
tests aseguran que la invariante sigue cumpliéndose.

Y donde el cap. 11 paga: declaramos también una **versión con
contrato**:

```kai
pub fn aplicar_si_cuadra(ms: [dominio.Movimiento]) : [dominio.Movimiento]
  requires cuadra(ms)
  ensures  cuadra(result)
= ms
```

`requires cuadra(ms)` declara que **llamar a esta función con
un grupo de movimientos que no cuadran es un error**. Si el
compilador puede probarlo estáticamente, rechaza la llamada
en compile time; si no, inserta un assert en runtime. El
`ensures cuadra(result)` declara que **el resultado de la
función también cuadra** (trivial aquí: devuelve la misma
lista). Esos dos contratos juntos forman la firma legal de la
función: las precondiciones que exige y la postcondición que
garantiza.

En un sistema contable real, este patrón se replica: cada
operación que toca movimientos lleva en su firma los
contratos del dominio.

## 18.4 El almacén: actor con invariantes

El almacén mantiene el estado del ledger: cuentas conocidas,
transacciones registradas, contadores de próximos IDs.

```kai
type Estado = {
  cuentas:        [dominio.Cuenta],
  transacciones:  [dominio.Transaccion],
  proxima_cuenta: Int,
  proxima_tx:     Int,
}
```

La función `procesar` toma un comando y el estado, devuelve
una respuesta y el estado nuevo. Lo importante: **toda
transacción pasa por validación de cuadre antes de
registrarse**.

```kai
Registrar(desc, movs) ->
  if not cuadre.cuadra(movs) {
    (dominio.ErrorDescuadre("..."), s)
  } else {
    match verificar_cuentas(movs, s.cuentas) {
      Some(id_faltante) -> (dominio.ErrorCuentaInexistente(id_faltante), s)
      None -> {
        let tx = dominio.Transaccion { id: s.proxima_tx<TransaccionId>, ... }
        let cuentas_actualizadas = aplicar_movs(s.cuentas, movs)
        let s2 = Estado { ...s, transacciones: [tx, ...s.transacciones], ... }
        (dominio.TransaccionRegistrada(tx), s2)
      }
    }
  }
```

Dos validaciones antes de aceptar:

1. **Cuadre**: la suma de débitos iguala la suma de créditos.
2. **Cuentas existentes**: todas las cuentas mencionadas en
   los movimientos están registradas.

Si una falla, devolvemos un error sin modificar el estado.
Eso es **transacción atómica**: o se aplica completa, o no se
aplica nada. No hay "media transacción registrada con cuadre
roto".

Las transacciones **se acumulan, nunca se modifican**. La
lista crece. Eso es deliberado: el ledger es por diseño un
historial inmutable. Borrar una transacción del pasado no
existe; corregir errores es escribir una **nueva** transacción
inversa, que también queda en el historial.

Esa inmutabilidad sale gratis en kaikai. Las listas son
inmutables por construcción; agregar un elemento crea una
lista nueva. No hay "modificación destructiva" disponible
para el bucle del actor a menos que se quisiera, con `var` o
`Array[T]`. Y como el actor recursa con el estado nuevo, cada
"versión" del ledger sobrevive intacta hasta el próximo paso.

## 18.5 El log de auditoría

El módulo `persistencia.kai` es prácticamente idéntico al del
cap. 17: un actor que recibe líneas de log y las agrega al
archivo. La diferencia conceptual: para un sistema contable,
**el archivo es la verdad**.

En contabilidad real, los registros de transacciones son
**append-only**: una vez escrito un asiento, queda. Las
correcciones se hacen agregando nuevos asientos inversos, no
modificando los originales. Esto es regulatorio (los
auditores lo exigen) pero también arquitectónico: un sistema
event-sourced que persiste todos los eventos permite
reconstruir cualquier estado intermedio.

```kai
pub type Evento = Linea(String)

fn bucle(path: String) : Unit / Actor[Evento] + File {
  match Actor.receive() {
    Linea(s) -> {
      file.append(path, s ++ "\n")
      bucle(path)
    }
  }
}
```

Cada evento que el almacén produce (cuenta creada, transacción
registrada) se manda al log via `Actor.send`. El log lo
escribe en orden estricto FIFO. Si la escritura a disco se
atrasa, los eventos se acumulan en el mailbox; el almacén
sigue respondiendo.

Una mejora para producción que dejamos como ejercicio: en vez
de strings, persistir un formato estructurado (JSON, CBOR,
TLV) que se pueda volver a leer al arrancar el sistema y
reconstruir el estado. Esto es **event sourcing** y kaikai lo
permite naturalmente.

## 18.6 El main: ejecutar un escenario

`main.kai` no abre un socket esta vez: simplemente ejecuta
una secuencia de operaciones para mostrar el sistema en
acción.

```kai
fn main() : Unit / Console + File + Spawn + Cancel + ... {
  let almacen_pid = almacen.arrancar()
  let log_pid     = persistencia.arrancar(PATH_LOG)

  paso(almacen_pid, log_pid, dominio.CrearCuenta("caja"))
  paso(almacen_pid, log_pid, dominio.CrearCuenta("ventas"))
  paso(almacen_pid, log_pid, dominio.CrearCuenta("gastos"))

  paso(almacen_pid, log_pid, dominio.Registrar("venta de tarjeta", [
    dominio.Debito(1<CuentaId>, 50.0<USD>),
    dominio.Credito(2<CuentaId>, 50.0<USD>),
  ]))

  paso(almacen_pid, log_pid, dominio.Registrar("café del equipo", [
    dominio.Debito(3<CuentaId>, 8.0<USD>),
    dominio.Credito(1<CuentaId>, 8.0<USD>),
  ]))

  # Intento descuadrado: el almacén lo rechaza.
  paso(almacen_pid, log_pid, dominio.Registrar("error", [
    dominio.Debito(1<CuentaId>, 100.0<USD>),
    dominio.Credito(2<CuentaId>, 50.0<USD>),
  ]))

  paso(almacen_pid, log_pid, dominio.ConsultarSaldo(1<CuentaId>))
  ...
}
```

`paso` es un helper que llama al almacén, imprime la
respuesta, y registra el evento en el log de auditoría. Después de
correr el `main`, el ledger tiene tres cuentas, dos
transacciones registradas (la venta y el café), una rechazada
(el intento descuadrado), y los saldos finales reflejan los
asientos. El archivo `ledger.audit.log` contiene una línea
por cada cuenta y transacción.

## 18.7 Lo que hace este caso distinto del cap. 17

El patrón general es el mismo; lo que cambia es el énfasis. Lo
que aparece en este capítulo y no aparecía en el anterior:

- **Unidades de medida.** `Real<USD>` en cada monto. El sistema
  de tipos rechaza mezclar monedas sin conversión explícita
  (cap. 10).
- **Branded types.** `Int<CuentaId>` vs `Int<TransaccionId>`.
  El compilador no nos deja confundirlos (cap. 10).
- **Contratos.** `requires cuadra(ms)` en `aplicar_si_cuadra`.
  La invariante del dominio queda en la firma de la función,
  verificable estática o dinámicamente (cap. 11).
- **Inmutabilidad por construcción.** Las transacciones nunca
  se modifican, solo se agregan. La estructura del ledger
  garantiza event sourcing.

Lo que aparece igual:

- **Sum types y match exhaustivo.** `Comando`, `Respuesta`,
  `Movimiento`. El compilador asegura que cada operación
  trata todos los casos.
- **Actores con estado.** El almacén y la persistencia siguen
  siendo actores, igual que en el cap. 17.
- **Modularidad.** Tipos puros separados de la maquinaria de
  actores. La función `procesar` se testea sin fibras.
- **Audit log via actor.** El patrón "un actor encapsula el
  IO costoso" se repite.

Esa **simetría entre los dos casos** es la lección. Cambia el
dominio (HTTP vs contabilidad), cambia qué herramientas del
lenguaje pesan más, pero la estructura del programa sigue
siendo la misma: dominio puro, actores con estado,
persistencia separada, módulos por responsabilidad.

## 18.8 Cómo extenderlo

Ideas para profundizar el ejemplo, en orden de dificultad:

- **Múltiples monedas.** Declarar `unit EUR`, `unit CLP`,
  cada cuenta tener su moneda como parámetro de tipo. Las
  transacciones entre monedas exigen una tasa de cambio
  explícita (`Real<USD / EUR>`).
- **Tipos de cuenta.** Distinguir activos, pasivos,
  patrimonio, ingresos, gastos. Cada tipo tiene reglas
  distintas para qué significa "débito" y "crédito" (en una
  cuenta de activo, débito suma; en pasivo, débito resta).
  Branded types como `Cuenta<Activo>` capturan eso.
- **Períodos contables.** Cerrar el ejercicio: todas las
  cuentas de ingresos y gastos se transfieren a resultado, y
  el ledger arranca el período nuevo con saldos iniciales.
- **Reconstrucción desde el log de auditoría.** Al arrancar, leer el
  archivo de log y replicar los eventos para reconstruir el
  estado en memoria. Esto es event sourcing canónico.
- **Reportes.** Estado de resultados, balance, libro mayor
  por cuenta. Cada uno es una función pura que recorre las
  transacciones y produce un string formateado.
- **Validación de cuenta antes de retirar.** Si se modela una
  cuenta de "saldo no negativo" como `Real<USD> where self >=
  0.0<USD>` (refinement type del cap. 11), el sistema de
  tipos rechaza cualquier movimiento que la deje en negativo.
- **Servir por HTTP.** Combinar este programa con el del cap.
  17: el bucle de accept queda igual, el handler que llamaba
  al almacén ahora llama al almacén del ledger. La estructura
  del programa cambia muy poco.

Cada una vuelve el sistema más cercano a uno de producción.
Ninguna obliga a reescribir las piezas anteriores. La
ortogonalidad paga.

## 18.9 Por qué fintech es un buen banco de pruebas

Fintech es uno de los pocos dominios donde la industria
acepta de buen grado que las herramientas pesen más en el
proceso de desarrollo. Si una función paga, la empresa
prefiere que el compilador la rechace antes de empujarla a
producción. Si el sistema garantiza que los débitos cuadran
con los créditos, el regulador duerme tranquilo. Si los
tipos distinguen monedas, el cambio del próximo trimestre no
introduce un bug sutil.

Lenguajes que ofrecen esas garantías (Haskell, OCaml, F#) han
tenido buena recepción en fintech histórica. kaikai
intenta acercar el mismo nivel de garantías con menos
ceremonia: unidades sin paquetes externos, contratos en la
firma, branding sin macros. La promesa es que el código se
puede escribir igual de directo que en Python o Go, con las
garantías que da el sistema de tipos.

¿Funciona la promesa? Eso lo decide quien escribe el código.
Este capítulo intentó mostrar una sección de un dominio
donde la apuesta vale la pena.

## 18.10 Filosofía: el cierre del libro

Hay un patrón que el libro ha venido proponiendo, capítulo a
capítulo, sin nombrarlo explícitamente hasta ahora. Vale
nombrarlo al final.

**El programa real está hecho de pequeñas piezas
ortogonales.** Tipos puros que describen el dominio. Funciones
puras que transforman el dominio. Actores que envuelven el
estado mutable que necesita persistir entre llamadas. Fibras
que paralelizan trabajo concurrente. Módulos que separan
responsabilidades. Contratos que ponen las invariantes del
dominio en la firma de las funciones que las preservan.

Cada pieza se prueba en aislamiento. Cada pieza declara en su
firma todo lo que hace. Cada pieza puede reemplazarse sin
tocar el resto.

Esto no es exclusivo de kaikai. Lo describen, con palabras
distintas, *No Silver Bullet* de Brooks, *Simple Made Easy*
de Hickey, *Out of the Tar Pit* de Moseley y Marks. Lo que
kaikai hace es ofrecer una sintaxis y un sistema de tipos
que **vuelven natural** este estilo. Las firmas que no
esconden nada salen gratis porque los efectos están en el tipo. Las funciones
puras son baratas porque la inmutabilidad es por defecto.
Los actores son una biblioteca porque los efectos
algebraicos lo permiten. Las invariantes del dominio están
en la firma porque los contratos están en el lenguaje.

Si después de leer el libro te quedas con una sola idea, que
sea esta: **el lenguaje no es lo que importa; lo que importa
es qué te permite construir, y qué te ayuda a evitar
construir mal**. kaikai apuesta a que con efectos, fibras,
contratos, unidades y holes en su lugar, el programador
escribe menos código equivocado y más código que merece
estar en producción. Si la apuesta funciona para ti, este
libro cumplió su propósito.

Gracias por leer hasta aquí. El compilador, el stdlib, los
documentos de diseño y los ejemplos viven en
`github.com/kaikailang-org/kaikai`. Hay una comunidad emergente, hay
issues que cerrar, hay piezas del lenguaje que están todavía
tomando forma. Si encuentras este experimento interesante,
hay lugar para que ayudes a hacerlo mejor.
