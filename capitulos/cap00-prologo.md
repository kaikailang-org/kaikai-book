# Prólogo

Cuando aprendí a construir compiladores en la universidad quedé fascinado con el diseño de lenguajes de programación. Luego en mi vida laboral resolví varios problemas creando pequeños lenguajes (hoy en día se conocen como lenguajes de dominio específico, o DSL por sus siglas en inglés).  

Me encanta el diseño de lenguajes de programación, y me gusta aprenderlos, compararlos, entender por qué sus autores tomaron las decisiones que tomaron.
También aprendí por qué hay tantos lenguajes de programación.
Hace años hice una charla en una conferencia donde explico por qué pasa esto,
la pueden encontrar en YouTube (https://www.youtube.com/watch?v=Hp9HwLPYkjI).
En aquella charla presenté a Ogú, un lenguaje que inventé y desarrollé hace varios años.

**Ogú** es un personaje de caricatura, un cavernícola amigo de Mampato
creado por el ilustrador y caricaturista chileno Themo Lobos. 
Conseguí el permiso para usar el personaje como mascota del lenguaje, una de las
gestiones de las que estoy más orgulloso. El repositorio nació
hacia 2010, anuncié intenciones en el blog, escribí parsers,
volví a empezar, escribí una gramática, la cambié, leí y releí
varios de los libros clásicos sobre el tema (el del dragón, *Modern Compiler Implementation*,
*Engineering a Compiler*), y avancé muy poco.

En 2017 hice un asalto serio: durante dos meses, con sesenta horas
totales repartidas entre el trabajo y las noches, construí una
primera versión usando Clojure como backend. En esencia Ogú es un transpiler:
el compilador traduce la sintaxis de Ogú a
*S-expressions* que son interpretadas por Clojure, y la JVM hace el resto.
Un *"fake it 'til you make it"* lo suficientemente sólido como para hacer una
demostración a mi audiencia en la conferencia.

Pero Ogú quedó abandonado. El último commit es de 2021. La
[organización en GitHub](https://github.com/ogu-lang) sigue ahí
para quien quiera leerla. Reescribí el parser en Scala, un ejercicio
de persistencia y algo de masoquismo. Mi problema era la generación de código, pero también mi ambición.

Un amigo me dijo que si iba a crear un lenguaje, respondiera qué tenía
de novedoso ese lenguaje.

Aprendí nuevos lenguajes, en particular la familia funcional, como Haskell o F#. Me enamoré de Rust, y luché con el borrow checker y llegué a dominar
su sintaxis para los "lifetimes" y su promesa de gestión de memoria sin garbage collection.

También aprendí sobre teoría de categorías y tuve una epifanía,
que documenté en su momento en el post
[*Revelaciones*](https://lnds.net/blog/lnds/2015/10/01/revelaciones/) (2015).

Fue ahí que descubrí la teoría de las mónadas y de repente, cuando estaba sumergido en esa pasta, cayó en mis manos un post sobre efectos algebraicos.
Ahí leí el ensayo *"What Color is Your Function?"* de Bob Nystrom.
Y tuve una segunda epifanía.

Fue así como nació la idea de un nuevo lenguaje, que llamé kaikai.

Inicialmente el nombre era por la mítica serpiente de la mitología mapuche, pero descubrí que kai kai en la cultura Rapa Nui, hace referencia a
un juego en que se hacen figuras con cordel que se tejen con los dedos mientras se canta un *pata'u ta'u*, un verso recitado. 
En el kai kai la estructura y la narración van de la mano, como en un
programa bien tipado. 

Lo que distingue a kaikai de intentos anteriores, y lo que le da
originalidad y novedad, es lo que está en este libro: te toca a ti descubrirlo.
Lo que quiero comentar tiene que ver con un hecho central en la
creación de kaikai: el uso de la IA.

El compilador que se describe en este libro fue creado en un mes.
Así como Ogú fue construido en 60 horas, kaikai fue construido con ayuda
de Claude Code en un periodo de un mes. Algo que podría haber tomado años.

Mi reflexión fue la siguiente: la IA ha leído y entiende mejor que yo
todos los papers sobre efectos algebraicos, programación funcional, diseño
de lenguajes, etc. Puedo usar eso a mi favor.

Yo actué como arquitecto, ya tenía mucho diseño previo, la IA me ayudó a plasmar ese diseño.

En el camino inventé una forma de trabajar con la IA en el desarrollo del
lenguaje en tiempo récord.

Ese método lo documenté en lo que llamo ELP: *Empirical Lane Parallelism*.
Esta forma de usar los agentes para amplificar tu proceso de desarrollo
y construir productos de software robustos en poco tiempo está
documentada en mi repo: https://github.com/lnds/elp. Te invito a leerlo
para que entiendas cómo pude construir un compilador tan complejo como
el de kaikai en tan solo un mes.

## Una nota sobre cómo se escribió este libro

Este libro se escribió con la asistencia de un agente de IA 
([Claude Code](https://claude.com/product/claude-code) de
Anthropic) bajo mi dirección como autor y editor. Yo decidí qué
capítulos había, en qué orden, con qué voz, con qué énfasis.
Claude redactó borradores que yo edité, corregí, devolví y volví
a editar. Los ejemplos los validamos contra el compilador. Las
afirmaciones técnicas las verificamos contra la documentación
del lenguaje. La voz del libro la calibramos contra mi blog.

Lo menciono no como disculpa, sino como reconocimiento de la 
realidad que vivimos los ingenieros de software en 2026.
La IA escribió partes, mi
juicio decidió todo. En *El fin del software artesanal* escribí
que los telares de Jacquard ya están entre nosotros y
que la pregunta no es si los usaremos sino cómo. Este libro es
una respuesta concreta a esa pregunta: lo que la IA permite no es
prescindir del autor, es escribir libros que antes uno no se
habría atrevido a empezar. Sin ese apoyo este texto probablemente
seguiría en mi cabeza, como el dibujo de Ogú se quedó en la mía
durante años.

Si encuentras inconsistencias, ejemplos que no compilan,
afirmaciones desactualizadas o cualquier pifia: el lapsus es
mío, no del agente. El libro está en el repositorio
[`kaikailang-org/kaikai-book`](https://github.com/kaikailang-org/kaikai-book)
y los reportes se aceptan como issues o pull requests.

## Convenciones

Vale gastar unos párrafos en cómo está organizado el libro y
cómo leerlo. Nada de esto es difícil, pero saberlo de antemano
ahorra tropiezos.

### Estructura

El libro está organizado en cuatro partes, dieciocho capítulos
y seis apéndices.

- **Parte I (caps. 1–2)** es el aterrizaje: un tour del lenguaje
  con programas ejecutables y un capítulo corto sobre cómo
  *pensar* en kaikai.
- **Parte II (caps. 3–11)** cubre el núcleo: tipos, funciones,
  módulos, protocolos, unidades de medida, contratos. Lo que
  necesitas para leer y escribir kaikai cotidiano.
- **Parte III (caps. 12–15)** entra en lo distintivo: efectos
  algebraicos, concurrencia por fibras, actores, holes tipados
  con asistencia de IA.
- **Parte IV (caps. 16–18)** cierra con tooling y dos casos de
  estudio.
- **Apéndices A–F** quedan como referencia: bootstrap del
  compilador, Perceus, operadores, catálogo de efectos del
  stdlib, glosario, lecturas adicionales.

Si vienes de un mundo funcional y solo te interesa lo nuevo,
parte por la Parte III y vuelve al núcleo cuando te haga falta.

### Forma de cada capítulo

Cada capítulo abre con un párrafo o dos de contexto: por qué
importa el tema, qué problema resuelve. Después viene el cuerpo
técnico, denso, con ejemplos. Los capítulos clave cierran con un
**caso de estudio** que integra los conceptos en un programa
realista. Al final hay **ejercicios** numerados, entre tres y
ocho según el peso del capítulo.

### Numeración y citas

- **Capítulos** son números enteros (cap. 7, cap. 12).
- **Secciones** llevan el número del capítulo (§7.3, §12.10).
- **Ejercicios** se citan como *7.3* dentro del propio capítulo,
  *cap. 7, ejercicio 3* desde otro.
- **Apéndices** son letras (apéndice A, apéndice D), con
  secciones tipo §A.1.

### Tipografía

- **Negrita** se usa para introducir términos nuevos la primera
  vez que aparecen. Si una palabra está en negrita, es la
  definición.
- *Cursiva* se usa para énfasis y para títulos de obras citadas
  (*The Go Programming Language*, *Learn You a Haskell*).
- `Tipo monoespaciado` se usa para identificadores, código
  inline, nombres de archivo y comandos.

### Código

Todos los bloques marcados como `kai` son ejecutables. Puedes
copiarlos a un archivo `.kai`, compilarlos con `kai run`, y
producirán la salida que el texto promete. Si un bloque
aparece *sin* marca de lenguaje, es porque muestra una sesión de
terminal: lo que viene después del `$` es lo que tipeas, lo que
viene debajo es la salida.

```
$ kai run ejemplos/cap01/01_hola.kai
Hola, kaikai
```

Los ejemplos largos viven bajo `ejemplos/capNN/` en el
[repositorio del libro](https://github.com/kaikailang-org/kaikai-book),
y el texto los referencia por nombre cuando vale la pena bajarse
el archivo entero.

### Notación

El **lenguaje** se llama `kaikai`, siempre en minúscula, incluso
al inicio de oración. La **herramienta de línea de comandos** se
llama `kai`: la usas para compilar (`kai run`), correr tests
(`kai test`), buscar propiedades (`kai check`), medir
(`kai bench`).

Identificadores del lenguaje, palabras clave, mensajes del
compilador y nombres de archivo se quedan siempre en inglés en
ambas ediciones. Las palabras técnicas que ya forman parte del
léxico de la profesión —*handler*, *fiber*, *effect row*,
*pattern matching*— se usan en inglés sin cursiva. Los
conceptos con traducción limpia al español (*tipo suma*,
*unidad de medida*, *contrato*) sí se traducen.

### Idioma

El libro se publica en dos ediciones: español e inglés. Ambas
viven en el mismo repositorio, en árboles paralelos. Esta es la
edición en español, redactada en español neutro latinoamericano
informal. La edición en inglés no es traducción: se escribió en
paralelo, con la misma estructura y los mismos ejemplos pero
en la voz nativa de cada idioma.

### Software vivo

El compilador, el stdlib y este libro están en evolución. Las
versiones avanzan, los ejemplos a veces dejan de compilar entre
versiones, y los apéndices se desactualizan. Si encuentras una
discrepancia entre el libro y el compilador que tienes
instalado, manda un issue al
[repo del libro](https://github.com/kaikailang-org/kaikai-book/issues).
El libro indica al inicio de cada edición contra qué versión
del compilador se validó.

## Quién debería leer este libro

Programadores con experiencia en algún lenguaje: 
Python, JavaScript, Go, Java, C#, Rust, lo que sea, que tengan
curiosidad por uno nuevo. No asumo background funcional: si
nunca tocaste Haskell, OCaml o Elixir, los capítulos
introductorios te apoyan. Si vienes de un mundo
funcional, puedes saltar a la Parte III y leer directo lo
distintivo de kaikai.

No es un libro para principiantes absolutos en programación.
Asumo que sabes qué es una función, una lista, un tipo, un test.

## Gracias

A quien lee mi blog desde hace más de veinte años: este libro
existe porque ese diálogo existió. La constancia de los lectores,
los comentarios, los correos, las correcciones, las
discusiones que se prolongaron en Twitter primero y en
newsletters después, me confirmaron una y otra vez que valía la pena
escribir. Sin esa audiencia paciente kaikai habría seguido en
mi cabeza con Ogú.

A Themo Lobos, que ya no está, por Ogú el cavernícola y por
darle a tres generaciones de chilenos la convicción de que
los mundos imaginarios se construyen con las manos. Recomiendo
leer su novela gráfica *Mata-ki-te-rangi* (que se convirtió
en el primer largometraje animado chileno: *Ogú y Mampato en Rapa Nui*).
A los autores cuyas ideas kaikai recoge: Daan Leijen por Koka, Andreas
Rossberg y Jonathan Brachthäuser por Effekt, Joe Armstrong por
el espíritu BEAM, y a la comunidad académica que llevó los
efectos algebraicos desde Plotkin y Pretnar hasta una
herramienta usable. A los amigos que me bromeaban con Ogú y
ahora me preguntan por kaikai.

Y a Anthropic, por construir una herramienta que me permitió
escribir el compilador y este libro en un mes y no en la próxima década.

---

El compilador está vivo, el lenguaje está evolucionando, y la
comunidad es pequeña pero atenta. Hay lugar para más.
