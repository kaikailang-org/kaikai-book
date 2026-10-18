# Apéndice B · Perceus a fondo

El §13.2 cubre la idea base de Perceus en una página: el
compilador analiza el programa, sabe en qué punto cada valor
deja de usarse, e inserta ahí un `drop` que decrementa el
contador de referencias y, si llega a cero, libera la memoria.
No hay GC, no hay borrow checker, no hay anotaciones de
lifetime.

Este apéndice entra en el detalle. Te sirve si vienes de Rust y
te preguntas por qué kaikai no necesita borrow checker, si
vienes de Java y te preguntas por qué no necesita pausas de GC,
o si quieres entender cómo una idea publicada en 2021 cambió el
equilibrio entre RC, GC y ownership.

Para programar en kaikai te alcanza el modelo de §13.2. Esto es
para ver los engranajes.

## B.1 El paper, en una frase

El paper que inventó Perceus es **"Perceus: Garbage Free
Reference Counting with Reuse"** (Reinking, Xie, de Moura,
Leijen, PLDI 2021). Su idea central, en paráfrasis mía:
insertar las operaciones de conteo *después* del chequeo de
tipos, con información *precisa de último uso*, vuelve al RC
competitivo con un GC de trazado sin perder la liberación
determinista.

Tres palabras pesan ahí:

- **After type checking.** El análisis trabaja sobre el
  programa ya tipado, no sobre el AST crudo, y eso le da
  información suficiente para razonar sobre forma y unicidad.
- **Precise last-use.** Para cada variable, el compilador
  identifica el lugar exacto donde se usa por última vez.
  Después de ese punto, el `drop` es seguro.
- **Reuse.** Es el truco que vuelve a Perceus competitivo con
  GC: cuando un valor se va a liberar y un valor del mismo
  shape se va a crear, el compilador reusa la misma memoria.

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

Por dentro, `list.sum` y `list.length` hacen lo mismo: cada vez
que recorren la cola de la lista, deciden si están en el último
uso. Si lo están, no duplican; si no, sí.

El programa final tiene **el mínimo número posible de
operaciones** sobre los contadores. Esa minimización es el
corazón del paper.

## B.3 Reuse in place

Lo más interesante de Perceus es el **reuse in place**. Cuando
una función va a liberar un valor de cierto shape y crear de
inmediato otro del mismo shape, el compilador reutiliza el
bloque de memoria: en vez de liberar y asignar, sobreescribe.

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
mutación, y **el resultado del programa es idéntico**: para ti,
la función sigue siendo pura.

Las condiciones para reuse in place son tres, todas
verificables en compilación:

1. **El receptor es de uso único** (RC == 1).
2. **El valor nuevo tiene el mismo shape**: mismo tag, mismos
   campos.
3. **No hay aliasing en vivo en otra parte**: nadie más tiene un
   puntero al cons original.

Cuando las tres se cumplen, el compilador emite código
indistinguible de una mutación destructiva, pero el valor sigue
siendo inmutable: si el programa cambiara y aparecieran dos
referencias al cons, el reuse se desactivaría solo y caería al
patrón "liberar + asignar". Tú no lo notas.

Esta optimización vuelve a `map`, `filter`, los árboles AVL o
el parseo de listas **tan rápidos como las versiones con
mutación** de los lenguajes imperativos. Por eso Koka, que usa
Perceus, y Lean 4, cuyo RC con reuse es el antecesor directo de
Perceus, compilan a código competitivo con C.

## B.4 Comparación con `Rc<RefCell<T>>` de Rust

Si vienes de Rust, esto te suena: Rust también tiene RC
(`Rc<T>`, `Arc<T>`). La diferencia con Perceus:

| Aspecto | Rust `Rc<T>` | Perceus en kaikai |
|---|---|---|
| Quién decide cuándo incrementar | El programador (clone) | El compilador |
| Quién decide cuándo decrementar | El destructor automático | El compilador |
| Anotaciones requeridas | `Rc<T>`, `Arc<T>`, `Rc::clone(&x)` | ninguna |
| Mutabilidad de contenido | Necesita `RefCell<T>` | Por defecto, inmutable |
| Ciclos | Memory leak silencioso | Imposibles (sin mutación) |
| Costo en single-use | El `Rc` cuenta siempre | Sin costo: el compilador no emite RC |

La diferencia más fuerte es la última. En Rust, cuando declaras
`Rc<T>` el contador está SIEMPRE, incluso en los casos donde el
valor tiene un solo uso. En kaikai, **si el valor tiene un solo
uso, no se emite RC**. El compilador inserta los `dup`s solo
donde hacen falta, después del análisis de last-use.

Un programa kaikai funcional puro, donde nada se comparte de
verdad entre varias variables, tiene cero overhead de RC: listas,
records y closures se liberan en su último uso sin pasar por un
contador. El RC aparece solo cuando el programa de verdad
comparte.

## B.5 Y los ciclos, ¿qué?

La crítica clásica al RC es que **no maneja ciclos**: si dos
valores se referencian mutuamente y nadie más los referencia,
ninguno baja nunca a 0 y la memoria se fuga. Por eso Python tiene un
"cycle collector" sobre su RC, y Rust te obliga a usar `Weak` a
mano.

Perceus no necesita ninguno de los dos **porque los valores en
kaikai son inmutables**.

Para crear un ciclo necesitas mutación: A apunta a B, después
modificas B para que apunte a A. Sin mutación, no puedes
construir el segundo paso. Cuando construyes B, A todavía no
existe; cuando construyes A apuntando a B, A no es accesible
desde B.

Las únicas excepciones son los mecanismos de mutación que kaikai
provee deliberadamente: `var` local (que el compilador enmascara
y limita), `Ref[T]`, mailboxes de actores, arrays mutables.
Todos ellos tienen disciplinas específicas que evitan ciclos
(cada mailbox, por ejemplo, pertenece a un solo actor, y el
handler del actor la libera en su `finally` cuando el actor
termina o lo cancelan).

En la práctica, un programa kaikai típico no construye ciclos:
sus estructuras son árboles (listas, AVL, JSON, ASTs). Si
necesitas algo con ciclos (un grafo, un cache con LRU), usas
estructuras explícitas que codifican la adyacencia sin punteros
directos: índices en un arreglo, identificadores en un mapa. Es
más trabajo, pero el costo intelectual queda visible donde
corresponde.

## B.6 Por qué la separación por fibra simplifica el RC

El cap. 13 menciona que cada fibra tiene su propio heap. Además
de aislar errores, **eso deja a Perceus libre de locks**.

Si dos fibras compartieran punteros al mismo valor, los
incrementos y decrementos del contador tendrían que ser
**atómicos**: la CPU emite una barrera de memoria y sincroniza
con otros núcleos. En programas de muchas fibras, ese overhead
es enorme.

Cuando cada fibra tiene su propio heap, los contadores son
locales. **No hay sincronización**. Un `dup` es un `++` sobre un
entero, sin barreras. Un `drop` es un `--`, idem.

Por eso el modelo de fibras de kaikai y Perceus se diseñan
juntos: cada uno habilita al otro. Las fibras aisladas
permiten RC sin sincronización; el RC eficiente permite
millones de fibras sin un GC detrás.

Cuando dos fibras necesitan compartir un valor, lo hacen vía
una operación explícita (`send` a un mailbox, devolver de un
`await`). El runtime copia el valor (o lo mueve si es seguro) al
heap de la fibra receptora. La transferencia es explícita en el
programa, y por eso predecible.

## B.7 Lo que cuesta y lo que se gana

Perceus tiene costos:

- **El análisis estático es trabajo del compilador**, más
  lento que tipos crudos. En kaikai, el análisis está integrado
  con la inferencia y se ejecuta en milisegundos para programas
  típicos.
- **Cuando un valor se duplica de verdad, el RC cuesta.** Si
  tienes muchas estructuras compartidas pesadas, el `dup`/`drop`
  se nota.
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

Las fuentes, si quieres más:

- **Reinking, Xie, de Moura, Leijen. "Perceus: Garbage Free
  Reference Counting with Reuse"**. PLDI 2021. El paper.
- **Lorenzen, Leijen. "Reference Counting with Frame Limited
  Reuse"**. ICFP 2022. Reemplaza el reuse de Perceus por uno
  guiado por los drops, más estable ante cambios pequeños del
  programa y con una cota para el heap máximo.
- **Koka language documentation** (Daan Leijen et al.). Koka es
  el lenguaje donde Perceus nació; mucho del vocabulario
  ("reuse in place", "borrowed binds", "drop specialisation")
  viene de ahí.
- **Ullrich, de Moura. "Counting Immutable Beans: Reference
  Counting Optimized for Purely Functional Programming"**. IFL
  2019. El RC del compilador de Lean 4, con reuse in place y
  referencias prestadas; Perceus parte de ese trabajo.

En el código de kaikai, el análisis vive en
`stage2/compiler/perceus.kai`. Si quieres ver cómo se
implementa, empieza ahí.
