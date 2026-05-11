# Apéndice B · Perceus a fondo

El §13.2 cubre la idea base de Perceus en una página: el
compilador analiza el programa, sabe en qué punto cada valor
deja de usarse, e inserta ahí un `drop` que decrementa el
contador de referencias y, si llega a cero, libera la memoria.
No hay GC, no hay borrow checker, no hay anotaciones de
lifetime.

Este apéndice se mete en el detalle. Para qué sirve: si vienes
de Rust y te preguntas por qué kaikai no necesita borrow
checker; si vienes de Java y te preguntas por qué kaikai no
necesita pausas de GC; o si simplemente quieres entender cómo
una idea publicada en 2021 cambió el equilibrio entre RC, GC y
ownership.

No hace falta leer este apéndice para programar en kaikai. El
modelo de §13.2 alcanza. Este texto es para quien quiere ver
los engranajes.

## B.1 El paper, en una frase

El paper que inventó Perceus es **"Perceus: Garbage Free
Reference Counting with Reuse"** (Reinking, Xie, de Moura,
Leijen, PLDI 2021). La frase central:

> Inserting reference count operations *after* type checking,
> using *precise last-use information*, makes RC competitive
> with tracing GC while keeping deterministic deallocation.

Tres palabras pesan ahí:

- **After type checking.** El análisis se hace sobre el
  programa ya tipado, no sobre el AST crudo. Esto da
  información suficiente para razonar sobre forma y unicidad.
- **Precise last-use.** Para cada variable, el compilador
  identifica el lugar exacto donde se usa por última vez.
  Después de ese punto, el `drop` es seguro.
- **Reuse.** Es el truco que vuelve a Perceus competitivo con
  GC: cuando un valor se va a liberar y un valor del mismo
  shape se va a crear, el compilador reusa la misma memoria.

Vamos por partes.

## B.2 Análisis paso a paso: dónde van los drops

Toma esta función simple:

```kai
fn ejemplo(xs: [Int]) : Int {
  let n = list.length(xs)
  let s = list.sum(xs)
  s + n
}
```

¿Qué tiene que pasar con `xs` cuando la función termina?
Depende de quién la creó. Si la lista es propiedad de la
función (la creó adentro, o fue movida como argumento), hay
que liberarla. Si es compartida con otros, no.

Perceus analiza el cuerpo y encuentra:

- `xs` se usa en la línea 2 (`list.length`).
- `xs` se usa otra vez en la línea 3 (`list.sum`).
- Después no se vuelve a usar.

El compilador inserta:

```
fn ejemplo(xs: [Int]) : Int {
  let n = list.length(dup(xs))   # dup: incrementa rc de xs
  let s = list.sum(xs)            # último uso: pasa ownership
  s + n
}
```

`dup(xs)` incrementa el RC porque `list.length` va a "consumir"
una referencia (haciendo su propio drop al final). El segundo
uso, `list.sum(xs)`, ya no necesita `dup`: es el último uso, y
la referencia que ya tenía la función se transfiere.

`list.sum` y `list.length` por dentro hacen lo mismo: cada vez
que recorren la cola de la lista, deciden si están en el último
uso. Si lo están, no duplican. Si no, sí.

El programa final tiene **el mínimo número de operaciones
posibles** sobre los contadores. Esa minimización es el corazón
del paper.

## B.3 Reuse in place

La parte más interesante de Perceus es el **reuse in place**.
Cuando una función va a liberar un valor de cierto shape y
crear inmediatamente otro del mismo shape, el compilador
reutiliza el mismo bloque de memoria. No se libera, no se
asigna: se sobreescribe.

El ejemplo canónico es el `map` sobre listas:

```kai
fn map[a, b](xs: [a], f: (a) -> b) : [b] {
  match xs {
    []           -> []
    [h, ...rest] -> [f(h), ...map(rest, f)]
  }
}
```

Sin reuse, este `map` haría:

1. Liberar el cons `[h, ...rest]` (después de extraerlos).
2. Asignar un cons nuevo `[f(h), ...]`.

Con reuse:

1. Reescribir el cons existente con el nuevo head.

Mismo cons, misma posición en memoria, mismo costo que una
mutación. Pero **el resultado del programa es idéntico**: la
función sigue siendo pura desde el punto de vista del
programador.

Las condiciones para reuse in place son tres, todas verificables
en tiempo de compilación:

1. **El receptor es de uso único** (RC == 1).
2. **El valor nuevo tiene el mismo shape**: mismo tag, mismos
   campos.
3. **No hay aliasing en vivo en otra parte**: nadie más tiene un
   puntero al cons original.

Cuando las tres se cumplen, el compilador emite código que es
indistinguible de una mutación destructiva. Pero conceptualmente
sigue siendo inmutable: si el programa cambiara y aparecieran
dos referencias al cons, el reuse se desactivaría
automáticamente y caería al patrón "liberar + asignar". El
programador no nota.

Esta optimización es lo que hace que algoritmos como `map`,
`filter`, AVL trees, parseo de listas, sean **tan rápidos como
las versiones con mutación** en lenguajes imperativos. Es la
razón por la que Koka y Lean 4 (que también usan Perceus)
pueden compilar competitivo con C.

## B.4 Comparación con `Rc<RefCell<T>>` de Rust

Si vienes de Rust, te suena familiar: hay RC en Rust también
(`Rc<T>`, `Arc<T>`). ¿En qué se diferencia Perceus?

| Aspecto | Rust `Rc<T>` | Perceus en kaikai |
|---|---|---|
| Quién decide cuándo incrementar | El programador (clone) | El compilador |
| Quién decide cuándo decrementar | El destructor automático | El compilador |
| Anotaciones requeridas | `Rc<T>`, `Arc<T>`, `Rc::clone(&x)` | ninguna |
| Mutabilidad de contenido | Necesita `RefCell<T>` | Por defecto, inmutable |
| Ciclos | Memory leak silencioso | Imposibles (sin mutación) |
| Costo en single-use | Pago el `Rc` siempre | Sin costo: el compilador no emite RC |

La diferencia más fuerte es la última. En Rust, cuando declaras
`Rc<T>` pagas el contador SIEMPRE, incluso en los casos donde el
valor tiene un solo uso. En kaikai, **si el valor tiene un solo
uso, no se emite RC**. El compilador inserta los `dup`s solo
donde hacen falta, después del análisis de last-use.

Eso significa que un programa kaikai funcional puro, donde nada
se comparte de verdad entre varias variables, tiene cero
overhead de RC. Las listas, los records, los closures, todos se
liberan al instante en su último uso sin pasar por un contador.
El RC solo aparece cuando el programa de verdad necesita
compartir.

## B.5 Y los ciclos, ¿qué?

La crítica clásica al RC es que **no maneja ciclos**: si dos
valores se referencian mutuamente y nadie más los referencia,
ninguno baja a 0 nunca, y leakan. Es por eso que Python tiene un
"cycle collector" arriba de su RC, y Rust te obliga a usar `Weak`
manualmente.

¿Por qué Perceus no necesita ninguno de los dos?

**Porque los valores en kaikai son inmutables.**

Para crear un ciclo necesitas mutación: A apunta a B, después
modificas B para que apunte a A. Sin mutación, no puedes
construir el segundo paso. Cuando construyes B, A todavía no
existe; cuando construyes A apuntando a B, A no es accesible
desde B.

Las únicas excepciones son los mecanismos de mutación que kaikai
provee deliberadamente: `var` local (que el compilador enmascara
y limita), `Ref[T]`, mailboxes de actores, arrays mutables.
Todos ellos tienen disciplinas específicas que evitan ciclos
(las mailboxes, por ejemplo, viven en un actor específico y el
GC del runtime las maneja).

En la práctica: un programa kaikai típico no construye ciclos.
Las estructuras de datos son árboles (listas, AVL, JSON, ASTs).
Cuando un programador quiere algo con ciclos (un grafo, un cache
con LRU), recurre a estructuras explícitas que codifican la
adjacencia sin punteros directos: índices en un array,
identificadores en un mapa. Es más trabajo, pero el costo
intelectual queda visible donde corresponde.

## B.6 Por qué la separación por fibra simplifica el RC

El cap. 13 menciona que cada fibra tiene su propio heap. Esto
no es solo aislación de errores: **es lo que hace que Perceus
sea libre de locks**.

Si dos fibras compartieran punteros al mismo valor, los
incrementos y decrementos del contador tendrían que ser
**atómicos**. Atómico significa que la CPU emite una barrera de
memoria, sincroniza con otros núcleos, paga overhead. En
programas de muchas fibras, ese overhead es enorme.

Cuando cada fibra tiene su propio heap, los contadores son
locales. **No hay sincronización**. Un `dup` es un `++` sobre un
entero, sin barreras. Un `drop` es un `--`, idem.

Esto es por qué el modelo de fibras de kaikai y Perceus se
diseñan juntos: cada uno habilita al otro. Las fibras aisladas
permiten RC sin sincronización; el RC eficiente permite
millones de fibras sin pagar GC.

Cuando dos fibras necesitan compartir un valor, lo hacen via
una operación explícita (`send` a un mailbox, devolver de un
`await`). El runtime copia el valor (o lo mueve si es seguro) al
heap de la fibra receptora. La transferencia es explícita en el
programa, y por eso predecible.

## B.7 Lo que cuesta y lo que se gana

Perceus tiene costos. Vale enumerarlos:

- **El análisis estático es trabajo del compilador.** Más
  lento que tipos crudos. En kaikai, el análisis está integrado
  con la inferencia y se ejecuta en milisegundos para programas
  típicos.
- **Cuando un valor se duplica de verdad, paga el RC.** Si
  tienes muchas estructuras compartidas pesadas, el `dup`/`drop`
  cuesta.
- **Reuse in place depende de la unicidad estática.** Si el
  análisis no puede probar unicidad, la optimización no aplica
  y caes a la versión segura.

Lo que se gana:

- **Determinismo.** Sabes exactamente cuándo se libera cada
  valor. Sin pausas, sin "GC corrió ahora", sin
  no-determinismo entre runs.
- **Memory predictability.** El peak de memoria se puede
  estimar mirando el programa. No hay "el GC esperó demasiado
  y se acumuló".
- **Cero anotaciones.** Sin `'a`, sin `&mut`, sin
  `Rc::clone(&x)`. El compilador hace el trabajo.
- **Composición con efectos.** El RC no interactúa con efectos
  en formas raras. `handle` y `resume` no tienen overhead
  oculto de GC.

## B.8 Para seguir

Si este apéndice te dejó con ganas de más, las fuentes:

- **Reinking, Xie, de Moura, Leijen. "Perceus: Garbage Free
  Reference Counting with Reuse"**. PLDI 2021. El paper.
- **Lorenz, Leijen. "Reference Counting with Frame Limited
  Reuse"**. ICFP 2023. Una extensión que mejora reuse cuando
  el shape no calza exactamente.
- **Koka language documentation** (Daan Leijen et al.). Koka es
  el lenguaje donde Perceus nació; mucho del vocabulario
  ("reuse in place", "borrowed binds", "drop specialisation")
  viene de ahí.
- **Lean 4 RC implementation** (de Moura et al.). Lean 4
  también usa Perceus, con un enfoque más cercano a
  certificación formal.

En el código de kaikai, el lugar donde vive el análisis es
`stage2/perceus.kai`. Si quieres ver cómo se implementa, ese es
el punto de partida.
