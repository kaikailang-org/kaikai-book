# Capítulo 18 · Caso de estudio: ledger contable

En el capítulo 17 construiste un servidor HTTP: muchos
clientes, una fibra por conexión, actores para encapsular
estado. Ahí lo que pesa es la concurrencia.

Este capítulo cierra el libro con **un libro mayor contable**,
donde lo que pesa es la precisión. Un débito que no calza con
su crédito es un bug que tu auditor va a encontrar antes que
tú, y "funciona y pasa los tests" no alcanza: tienes que poder
mostrar **por qué** funciona. Lo elegí porque es donde un error
de tipos deja de ser una molestia y se convierte en plata.

Fintech es uno de los dominios donde más caro sale equivocarse
y donde más rinde tener garantías en el tipo. Mezclar USD con
EUR cuesta plata; también sumar débitos con créditos, o
permitir un retiro sin verificar saldo. Las unidades de
medida, los contratos y el branding existen para que esas
equivocaciones no compilen, no para que las descubras en
producción.

El programa es un ledger de doble entrada: mantiene cuentas
con saldo, registra transacciones con débitos y créditos,
valida que cuadren y persiste un log de auditoría inmutable.
Son unas 280 líneas en cinco módulos.

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

La estructura es deliberadamente similar a la del cap. 17;
cambia el énfasis:

- **`dominio.kai`** es más rico que el del cap. 17. Aparecen
  unidades de medida (`Real<USD>`), branded types
  (`Int<CuentaId>`, `Int<TransaccionId>`), y un sum type
  `Movimiento` que distingue débitos de créditos.
- **`cuadre.kai`** es nuevo, dedicado a una invariante: la
  suma de débitos en una transacción debe igualar la suma de
  créditos. Aparece como función pura testeable Y como
  **contrato** (`requires`) sobre la operación de registrar.
- **`almacen.kai`** es el actor de siempre, pero ahora valida
  cuadre antes de aceptar una transacción y mantiene saldos
  por cuenta. Las transacciones son **inmutables**: solo se
  agregan, nunca se modifican.
- **`persistencia.kai`** es el log de auditoría. En
  contabilidad, lo escrito queda: el archivo es evidencia
  legal.

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

Tres decisiones del sistema de tipos:

- **`Real<USD>` en vez de `Real`.** Las unidades de medida del
  cap. 10 importan especialmente aquí: un programa contable
  que mezcla USD con EUR sin convertir produce números que
  parecen correctos pero no significan nada. Con UoM, esa
  mezcla no compila. Para extender el programa a múltiples
  monedas, declaras `unit EUR`, defines una tasa de cambio como
  `Real<USD / EUR>` y el sistema de tipos te lleva de la mano.
  Sin UoM, lo descubres cuando un cliente reclama. (El stdlib trae además `money`, con
  `Money[c: Currency]` sobre `Decimal` y las monedas ISO
  declaradas; el capítulo 19 lo cubre. Aquí seguimos con
  `Real<USD>` porque el punto es la técnica de UoM.)
- **`Int<CuentaId>` vs `Int<TransaccionId>`.** Branded types,
  también del cap. 10. Con `Int` puro como id, pasar un id de
  transacción donde se espera uno de cuenta compila igual y
  revienta en runtime (o peor, produce sin avisar un resultado
  equivocado). Con branding, el sistema de tipos te lo dice
  antes.
- **`Movimiento` como sum type.** Un débito y un crédito
  tienen los mismos campos físicos (cuenta + monto), pero
  significan cosas distintas. Como dos constructores del
  mismo sum type, el pattern match exhaustivo obliga a toda
  operación a tratarlos explícitamente, y el sistema de tipos
  no te deja sumar "monto de débito" con "monto de crédito"
  sin pasar por una conversión clara.

Compara con la versión sin tipos ricos: un record `{
cuenta: Int, monto: Real, tipo: String }` donde `tipo` es
`"debito"` o `"credito"`. Funciona, pero `tipo: String`
permite `"DEBITO"`, `"CR"`, `""`, todas inválidas, y cada
función que toca movimientos tiene que validarlo. Con el sum
type, el inválido **no se puede construir**.

## 18.3 La invariante central: cuadre

El módulo `cuadre.kai` es chico y define la invariante del
ledger de doble entrada: en cada transacción, la suma de los
débitos debe igualar la suma de los créditos.

```kai
fn debito(m: dominio.Movimiento) : [Real<USD>] = match m {
  dominio.Debito(_, monto) -> [monto]
  dominio.Credito(_, _)    -> []
}

pub fn total_debitos(ms: [dominio.Movimiento]) : Real<USD> =
  ms || debito |> list.sum

pub fn total_creditos(ms: [dominio.Movimiento]) : Real<USD> = ...

pub fn cuadra(ms: [dominio.Movimiento]) : Bool =
  total_debitos(ms) == total_creditos(ms)
```

Funciones puras para una sola invariante booleana. Los tests
verifican el contrato pieza por pieza:

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

Sin actores, IO ni sockets: pura lógica. Si en seis meses
cambias cómo se representan los movimientos, estos tests
aseguran que la invariante se sigue cumpliendo.

Aquí rinde el cap. 11: el módulo declara también una
**versión con contrato**:

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
`ensures cuadra(result)` declara que **el resultado también
cuadra** (trivial aquí: devuelve la misma lista). Juntos
forman la firma legal de la función: lo que exige y lo que
garantiza.

En un sistema contable real, cada operación que toca
movimientos lleva en su firma los contratos del dominio.

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

La función `procesar` toma un comando y el estado, y devuelve
una respuesta y el estado nuevo. **Toda transacción pasa por
validación de cuadre antes de registrarse**.

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

Si una falla, `procesar` devuelve un error sin tocar el
estado. Es una **transacción atómica**: se aplica completa o
no se aplica. No existe "media transacción registrada con
cuadre roto".

Las transacciones **se acumulan, nunca se modifican**. Es
deliberado: el ledger es por diseño un historial inmutable.
Borrar una transacción del pasado no existe; corregir un error
es escribir una **nueva** transacción inversa, que también
queda en el historial.

Esa inmutabilidad sale gratis en kaikai. Las listas son
inmutables por construcción; agregar un elemento crea una
lista nueva. El bucle del actor no tiene "modificación
destructiva" a mano salvo que la pidas con `var` o `Array[T]`.
Y como el actor recursa con el estado nuevo, cada "versión"
del ledger sobrevive intacta hasta el próximo paso.

## 18.5 El log de auditoría

El módulo `persistencia.kai` es casi idéntico al del cap. 17:
un actor que recibe líneas de log y las agrega al archivo. La
diferencia está en el dominio: para un sistema contable, **el
archivo es la verdad**.

En contabilidad real, los registros son **append-only**: un
asiento escrito queda, y las correcciones se hacen con
asientos inversos nuevos. Los auditores lo exigen, y además
tiene una razón arquitectónica: un sistema event-sourced que
persiste todos los eventos permite reconstruir cualquier
estado intermedio.

```kai
pub type Evento = Linea(String)

pub fn persistencia_loop(path: String) : Unit / Actor[Evento] + File {
  match Actor.receive() {
    Linea(s) -> {
      file.append(path, s ++ "\n")
      persistencia_loop(path)
    }
  }
}
```

Cada evento del almacén (cuenta creada, transacción
registrada) va al log vía `Actor.send`, que lo escribe en
orden FIFO estricto. Si el disco se atrasa, los eventos se
acumulan en el mailbox y el almacén sigue respondiendo.

Queda como ejercicio una mejora para producción: persistir un
formato estructurado (JSON, CBOR, TLV) en vez de strings, para
releerlo al arrancar y reconstruir el estado. Eso es **event
sourcing**, y kaikai lo permite naturalmente.

## 18.6 El main: ejecutar un escenario

`main.kai` no abre un socket esta vez: ejecuta una secuencia
de operaciones para mostrar el sistema en acción.

```kai
fn main() : Int / Stdout + File + Spawn + Cancel {
  persistencia.reset_log(PATH_LOG)

  # `paso()` toca tres efectos Actor[T], así que `main` anida
  # tres `with_mailbox` para cerrarlos antes de llegar a su
  # propia fila.
  with_mailbox {
    with_mailbox {
      with_mailbox {
        let almacen_body: () -> Unit / Actor[almacen.AlmacenMsg] + Actor[almacen.AlmacenResp] = () => almacen.almacen_loop(almacen.estado_inicial())
        let log_body:     () -> Unit / Actor[persistencia.Evento] + File = () => persistencia.persistencia_loop(PATH_LOG)
        let almacen_pid = spawn_actor(almacen_body)
        let log_pid     = spawn_actor(log_body)

        println("== creando cuentas ==")
        paso(almacen_pid, log_pid, dominio.CrearCuenta("caja"))
        paso(almacen_pid, log_pid, dominio.CrearCuenta("ventas"))
        paso(almacen_pid, log_pid, dominio.CrearCuenta("gastos"))

        println("== registrando una venta ==")
        paso(almacen_pid, log_pid, dominio.Registrar("venta de tarjeta", [
          dominio.Debito(1<CuentaId>, 50.0<USD>),
          dominio.Credito(2<CuentaId>, 50.0<USD>),
        ]))

        println("== pagando un gasto ==")
        paso(almacen_pid, log_pid, dominio.Registrar("café del equipo", [
          dominio.Debito(3<CuentaId>, 8.0<USD>),
          dominio.Credito(1<CuentaId>, 8.0<USD>),
        ]))

        println("== intento descuadrado (debe fallar) ==")
        paso(almacen_pid, log_pid, dominio.Registrar("error", [
          dominio.Debito(1<CuentaId>, 100.0<USD>),
          dominio.Credito(2<CuentaId>, 50.0<USD>),
        ]))

        println("== saldos finales ==")
        paso(almacen_pid, log_pid, dominio.ConsultarSaldo(1<CuentaId>))
        paso(almacen_pid, log_pid, dominio.ConsultarSaldo(2<CuentaId>))
        paso(almacen_pid, log_pid, dominio.ConsultarSaldo(3<CuentaId>))
      }
    }
  }
  0
}
```

`paso` es un helper que llama al almacén, imprime la
respuesta y registra el evento en el log de auditoría. Al
terminar `main`, el ledger tiene tres cuentas, dos
transacciones registradas (la venta y el café) y una
rechazada (el intento descuadrado); los saldos finales
reflejan los asientos. El archivo `ledger.audit.log` tiene
una línea por cada cuenta y transacción.

## 18.7 Lo que hace este caso distinto del cap. 17

El patrón general es el mismo; cambia el énfasis. Lo nuevo
en este capítulo:

- **Unidades de medida.** `Real<USD>` en cada monto. El sistema
  de tipos rechaza mezclar monedas sin conversión explícita
  (cap. 10).
- **Branded types.** `Int<CuentaId>` vs `Int<TransaccionId>`.
  El compilador no te deja confundirlos (cap. 10).
- **Contratos.** `requires cuadra(ms)` en `aplicar_si_cuadra`.
  La invariante del dominio queda en la firma de la función,
  verificable estática o dinámicamente (cap. 11).
- **Inmutabilidad por construcción.** Las transacciones nunca
  se modifican, solo se agregan. La estructura del ledger
  garantiza event sourcing.

Lo que se repite:

- **Sum types y match exhaustivo.** `Comando`, `Respuesta`,
  `Movimiento`. El compilador asegura que cada operación
  trata todos los casos.
- **Actores con estado.** El almacén y la persistencia siguen
  siendo actores, igual que en el cap. 17.
- **Modularidad.** Tipos puros separados de la maquinaria de
  actores. La función `procesar` se testea sin fibras.
- **Audit log via actor.** El patrón "un actor encapsula el
  IO costoso" se repite.

Esa **simetría entre los dos casos** es la lección. Cambian
el dominio y las herramientas que más pesan, pero la
estructura sigue igual: dominio puro, actores con estado,
persistencia separada, módulos por responsabilidad.

## 18.8 Cómo extenderlo

Ideas para extender el ejemplo, en orden de dificultad:

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
  17: el bucle de accept queda igual y el handler llama ahora
  al almacén del ledger. La estructura cambia muy poco.

Cada una acerca el sistema a uno de producción, y ninguna
obliga a reescribir las piezas anteriores. La ortogonalidad
rinde.

## 18.9 Por qué fintech es un buen banco de pruebas

Fintech es uno de los pocos dominios donde la industria
acepta de buen grado que las herramientas pesen más en el
desarrollo. Si una función desembolsa el monto equivocado, la
empresa prefiere que lo atrape el compilador y no producción.
Si el sistema garantiza
que los débitos cuadran con los créditos, el regulador
duerme tranquilo. Si los tipos distinguen monedas, el cambio
del próximo trimestre no introduce un bug sutil.

Haskell, OCaml y F#, que ofrecen esas garantías, han tenido
buena recepción en fintech. kaikai intenta acercar el mismo
nivel de garantías con menos ceremonia: unidades sin paquetes
externos, contratos en la firma, branding sin macros. La
promesa es escribir tan directo como en Python o Go, con las
garantías del sistema de tipos.

Si la promesa se cumple lo decide quien escribe el código.
Este capítulo te mostró un dominio donde la apuesta vale la
pena.

## 18.10 Filosofía: el cierre del libro

El libro propone un patrón capítulo a capítulo sin haberlo
nombrado. Es hora de nombrarlo.

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
esconden nada salen gratis porque los efectos están en el
tipo. Las funciones puras son baratas porque la inmutabilidad
es por defecto.
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
`github.com/kaikailang-org/kaikai`. Hay issues que cerrar y
piezas del lenguaje que todavía toman forma. Si este
experimento te interesa, hay lugar para que ayudes a
mejorarlo.
