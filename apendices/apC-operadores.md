# Apéndice C · Tabla de operadores y precedencia

Este apéndice resume todos los operadores del lenguaje con su
precedencia y asociatividad. Está pensado como referencia
rápida: cuando dudas cómo parsea `a | f |> g`, lo consultas y
sigues.

La precedencia está numerada de más alta (1, aprieta primero)
a más baja (8, aprieta último). Cada nivel se resuelve contra
el nivel inmediatamente superior.

## C.1 Tabla principal

| Nivel | Operadores                                       | Asociatividad     |
|------:|--------------------------------------------------|-------------------|
| 1     | llamada `f(args)`, campo `.`, índice `[i]`       | Postfija          |
| 2     | unario `-`, `not`                                | Prefija           |
| 3     | `*`, `/`, `//`, `%`                              | Izquierda         |
| 4     | `+`, `-` (binarios), `++` (concat de strings)    | Izquierda         |
| 5     | `==`, `!=`, `<`, `>`, `<=`, `>=`                 | **No-asociativa** |
| 6     | `and`                                            | Izquierda (corto) |
| 7     | `or`                                             | Izquierda (corto) |
| 8     | `\|>`, `\|`, `\|\|`, `\|?`                       | Izquierda         |

### Detalles por nivel

- **Nivel 1 (postfijos).** Se asocian por izquierda: `a.b.c`
  significa `(a.b).c`; `f(x)(y)` significa `(f(x))(y)`.
- **Nivel 2 (prefijos).** Unario `-x` y `not x`. Aplican antes
  que cualquier operador binario.
- **Nivel 3 (multiplicativos).** `*` y `/` sobre `Int` y `Real`,
  `//` es división entera, `%` es resto. Asociación izquierda:
  `a / b / c` es `(a / b) / c`.
- **Nivel 4 (aditivos).** `+` y `-` binarios sobre números, `++`
  para concatenar strings.
- **Nivel 5 (comparaciones).** **No se encadenan.** Escribir
  `a < b < c` es error de sintaxis. La forma correcta es
  `a < b and b < c`. Esto elimina la clase de bugs donde
  `1 == 1 == true` parsea inesperadamente.
- **Nivel 6 (`and`) y 7 (`or`).** Lógicos con corto-circuito.
  `and` aprieta más fuerte que `or`, así que
  `a or b and c` es `a or (b and c)`.
- **Nivel 8 (pipes).** Cuatro operadores al mismo nivel:
  `|>` (apply), `|` (map), `||` (flat-map), `|?` (filter).
  Todos asocian a izquierda. `xs | f |> g` es `(xs | f) |> g`.

## C.2 Operadores que **no** son operadores

Algunas formas que parecen operadores en otros lenguajes son
construcciones de sintaxis aparte en kaikai:

- **`=` (asignación de `let`)**: parte de la sintaxis de `let`,
  no es un operador. `let x = expr` es una declaración.
- **`:=` (escritura a celda mutable)**: parte de la sintaxis
  de `var`. `nombre := expr` es la forma azucarada de
  `State.set(nombre, expr)`. No participa en la tabla de
  precedencia.
- **`@nombre` (lectura de celda mutable)**: lectura azucarada
  de `State.get(nombre)`. Es un prefijo del nombre, no
  participa en la tabla.
- **`->` (en `match`, en lambdas, en `handle`)**: separador
  sintáctico, no operador.
- **`/` (en firma de efecto)**: separa el tipo de retorno de
  la fila de efectos: `fn f() : Int / Log`. Solo aparece en
  posición de firma.
- **`!` (propagación de `Option`/`Result`)**: postfijo sobre
  expresiones que devuelven `Option[T]` o `Result[E, T]`,
  hace propagación temprana del error o el `None`. Equivale
  más o menos al `?` de Rust. No es un operador binario.
- **`?` y `?nombre` (holes)**: marcadores de agujero, no
  operadores.
- **`...` (spread)**: aparece en literales de record y de
  lista (`[h, ...t]`, `Punto { ...p, x: 10 }`); también en
  patrones. No es operador.
- **`<>` (anotación de unidad de medida)**: `1.50<USD>`,
  `Real<EUR>`. La unidad va entre los paréntesis angulares;
  no son los operadores `<` y `>`.

## C.3 Equivalencias útiles

Algunos operadores son azúcar sintáctica para llamadas a
funciones del stdlib. Conocer las equivalencias ayuda cuando
el operador no parece funcionar o cuando uno quiere ver el
mecanismo subyacente.

| Operador        | Equivale a                              |
|-----------------|-----------------------------------------|
| `x |> f`        | `f(x)`                                  |
| `x |> f(_, b)`  | `f(x, b)`                               |
| `xs | f`        | `list.map(xs, f)`                       |
| `xs || f`       | `list.flat_map(xs, f)`                  |
| `xs |? p`       | `list.filter(xs, p)`                    |
| `a ++ b`        | `string_concat(a, b)` (cuando son `String`) |
| `a[i]`          | `Mutable.array_get(a, i)`               |
| `a[i] := v`     | `Mutable.array_set(a, i, v)`            |
| `@nombre`       | `State.get(nombre)` (con `var`)         |
| `nombre := v`   | `State.set(nombre, v)` (con `var`)      |

## C.4 Recordatorio: comparación no asociativa

La regla del nivel 5 merece énfasis aparte porque es donde el
lector que viene de otros lenguajes más se sorprende.

En la mayoría de los lenguajes:

```
1 == 1 == 1     # Python: false (1 == 1 → true, true == 1 → false)
1 < 2 < 3       # C: 1 (1 < 2 → 1, 1 < 3 → 1; no es lo que parece)
```

En kaikai, ninguna de las dos compila. El compilador exige
que escribas la intención explícitamente:

```kai
1 == 1 and 1 == 1       # claramente: dos comparaciones
1 < 2 and 2 < 3         # rango: cada lado se compara explícito
```

Esto elimina una clase pequeña pero molesta de bugs. Para
quien venga de Python y le moleste tener que escribir más,
vale recordar que la regla es la misma de Pascal, Eiffel y
SQL. No es una rareza de kaikai.
