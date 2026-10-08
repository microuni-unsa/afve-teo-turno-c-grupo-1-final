#import "ieee.typ": ieee

#show: ieee.with(
  title: [Verificación formal de coherencia en políticas ABAC: un verificador en Dafny compilado a JavaScript con escalabilidad acotada],
  abstract: [
    El control de acceso basado en atributos, conocido por sus siglas en inglés como ABAC por Attribute-Based Access Control, decide cada solicitud a partir de atributos de sujeto, recurso, acción y entorno. Los conjuntos de reglas ABAC escritos a mano son propensos a tres defectos silenciosos: contradicciones entre reglas de permiso y de denegación sobre la misma solicitud, reglas insatisfacibles que nunca se activan y reglas sombreadas que ninguna solicitud decide en solitario. Este trabajo propone un verificador de coherencia con núcleo formalmente verificado en Dafny. El predicado Coherent conjuga cuatro propiedades llamadas P1 a P4 que cubren consistencia, satisfacibilidad, no sombreado y validez de esquema, y la interfaz guardada solo confirma conjuntos de reglas coherentes y devuelve en caso contrario un testigo verificable por máquina con la solicitud, las reglas implicadas y la propiedad violada. La escalabilidad se garantiza por construcción acotada y decidible con dominios finitos por esquema, topes explícitos, recorridos por índice y decisiones exactas compiladas de Dafny a JavaScript sin reimplementación en TypeScript. Ni los veredictos sobre casos de estudio ni las mediciones de rendimiento forman parte de este entregable y quedan como trabajo futuro junto con la interfaz de demostración.
  ],
  index-terms: (
    "control de acceso basado en atributos",
    "métodos formales",
    "Dafny",
    "coherencia de políticas",
    "verificación de software",
    "escalabilidad acotada",
  ),
  authors: (
    (
      name: "Mariel Alisson Jara Mamani",
      department: [Departamento de Ingeniería de Sistemas],
      organization: [Universidad Nacional de San Agustín],
      location: [Arequipa, Perú],
      email: "mjarama@unsa.edu.pe",
    ),
    (
      name: "Luis Gustavo Sequeiros Condori",
      department: [Departamento de Ingeniería de Sistemas],
      organization: [Universidad Nacional de San Agustín],
      location: [Arequipa, Perú],
      email: "lsequeiros@unsa.edu.pe",
    ),
    (
      name: "Yenaro Joel Noa Camino",
      department: [Departamento de Ingeniería de Sistemas],
      organization: [Universidad Nacional de San Agustín],
      location: [Arequipa, Perú],
      email: "ynoa@unsa.edu.pe",
    ),
    (
      name: "Christian Raul Mestas Zegarra",
      department: [Departamento de Ingeniería de Sistemas],
      organization: [Universidad Nacional de San Agustín],
      location: [Arequipa, Perú],
      email: "cmestasz@unsa.edu.pe",
    ),
  ),
  bibliography: bibliography("refs.bib", style: "ieee"),
)

= Introducción <sec:introduccion>

El control de acceso es una de las funciones críticas de todo sistema de información: determina quién puede hacer qué sobre qué recurso y en qué condiciones. El control de acceso basado en atributos, conocido por sus siglas en inglés como ABAC por Attribute-Based Access Control, expresa esas decisiones mediante atributos de sujeto, recurso, acción y entorno, según la definición canónica del Instituto Nacional de Estándares y Tecnología de los Estados Unidos, conocido por sus siglas en inglés como NIST por National Institute of Standards and Technology #cite(<hu2014guide>), y su presentación resumida #cite(<hu2015abac>). Frente a modelos rígidos basados en roles, ABAC permite políticas expresivas como permitir la lectura de un historial clínico cuando el rol es personal médico y el nivel de autorización supera la sensibilidad del recurso. Esa expresividad tiene un costo: los conjuntos de reglas crecen, se superponen y se vuelven difíciles de auditar a mano.

En la región, las universidades, los hospitales y las entidades públicas gestionan sistemas donde las reglas de acceso cambian con frecuencia por rotación de personal, convenios y turnos de emergencia. La práctica habitual consiste en editar listas de reglas en archivos de configuración o paneles administrativos sin ningún chequeo formal posterior. Cada edición es una oportunidad para introducir una incoherencia silenciosa que solo se manifiesta cuando una solicitud concreta recibe una decisión incorrecta, sea una denegación que bloquea una atención urgente o un permiso que expone un recurso sensible.

El problema que aborda este trabajo es doble. Primero, decidir la coherencia de un conjunto de reglas ABAC y producir ante cada violación un testigo concreto que identifique la solicitud, las reglas implicadas y la propiedad incumplida. Segundo, garantizar que la evolución del conjunto preserve la coherencia por construcción, de modo que añadir, actualizar o eliminar reglas nunca deje al sistema en un estado incoherente. La propuesta consiste en un verificador cuyo núcleo de decisión está escrito y demostrado en Dafny, un verificador automático de programas para corrección funcional #cite(<leino2010dafny>), y compilado a JavaScript para su distribución como paquete npm con envolturas en TypeScript. La escalabilidad del enfoque es acotada y decidible por diseño: dominios finitos por esquema, topes explícitos con error declarado y recorridos con costo conocido.

La importancia de esta propuesta radica en que traslada la confianza desde las pruebas empíricas hacia las demostraciones verificadas por máquina. Un decisor compilado desde lemas de preservación ofrece la garantía de que todo conjunto de reglas confirmado por la interfaz guardada es coherente, propiedad que ningún conjunto de casos de prueba puede establecer por sí solo.

El resto del artículo se organiza como sigue. La @sec:problema define el problema y fija el vocabulario formal. La @sec:objetivos presenta los objetivos generales y específicos. La @sec:relacionado revisa el trabajo relacionado con una tabla comparativa. La @sec:arquitectura describe la arquitectura del sistema. La @sec:requerimientos lista los requerimientos funcionales. La @sec:implementacion detalla los temas específicos de implementación. La @sec:datos declara la disponibilidad de datos y código.

= Definición del problema <sec:problema>

Un conjunto de reglas ABAC se escribe y evoluciona a mano: se añaden reglas de permiso para nuevos casos, se agregan denegaciones como salvaguardas y se ajustan condiciones existentes. Sin un chequeo verificado por máquina, cada una de esas operaciones puede introducir incoherencias silenciosas.

Se distinguen tres clases de defecto, que este trabajo adopta como propiedades de coherencia. P1 es consistencia, donde ninguna solicitud activa a la vez una regla de permiso y una de denegación. P2 es satisfacibilidad, donde cada regla se activa para al menos una solicitud válida, pues una regla insatisfacible es código muerto con apariencia de protección. P3 es no sombreado, donde cada regla decide en solitario al menos una solicitud, pues una regla cubierta por otras resulta nula y su presencia confunde la auditoría. Los duplicados exactos se reportan bajo P3 y no como un chequeo aparte. P4 es validez de esquema, donde toda regla referencia solo atributos declarados, con literales dentro del dominio y operadores compatibles con el tipo. Un conjunto de reglas es coherente cuando cumple las cuatro propiedades a la vez.

El vocabulario es deliberadamente finito y decidible. Una solicitud es una asignación total de cada atributo declarado a un valor dentro de su dominio, sea enumeración, booleano o entero acotado. No existen comparaciones entre atributos ni operaciones aritméticas. El criterio de éxito es la invariante de tesis: todo conjunto de reglas alcanzable a través de la interfaz guardada es coherente.

= Objetivos <sec:objetivos>

El objetivo general consiste en proponer un verificador de coherencia para políticas ABAC formalmente verificado, con garantías de coherencia y escalabilidad acotada, distribuido como paquete npm cuyo núcleo de decisión está escrito y probado en Dafny y compilado a JavaScript.

Los objetivos específicos son los siguientes.

OE1. Formalizar en Dafny el lenguaje de políticas con reglas de permiso y denegación sobre atributos de sujeto, recurso, acción y entorno con negación, conjunción, disyunción e igualdades y comparaciones de enteros acotados contra literales, junto con su semántica de evaluación y las cuatro propiedades de coherencia P1 a P4.

OE2. Implementar una interfaz guardada y total que solo confirme conjuntos coherentes, con preservación de coherencia demostrada por lemas y rechazo con testigo que incluya la solicitud, los identificadores de reglas, la propiedad violada y una explicación, sin aplicación parcial.

OE3. Garantizar una escalabilidad acotada y decidible mediante dominios finitos por esquema, topes explícitos con error declarado y sin aproximaciones silenciosas, recorridos por índice de costo lineal y búsqueda de sombreado de costo cuadrático declarado.

OE4. Empaquetar el núcleo compilado desde Dafny con envolturas TypeScript bajo separación estricta de responsabilidades, donde Dafny decide toda determinación de coherencia y evaluación mientras TypeScript valida entradas, analiza sintaxis, sanea dominios y presenta resultados, sin reimplementar ninguna decisión.

= Trabajo relacionado <sec:relacionado>

== Análisis de políticas XACML

Fisler y colaboradores introdujeron la verificación y el análisis de impacto de cambios en políticas de control de acceso #cite(<fisler2005verification>), con lo que establecieron el análisis estático de políticas como disciplina. Turkmen y colaboradores formalizaron el análisis de políticas del Lenguaje Extensible de Marcado para Control de Acceso, conocido por sus siglas en inglés como XACML por eXtensible Access Control Markup Language, mediante solucionadores de teorías de satisfacibilidad módulo teorías, conocidos por sus siglas en inglés como SMT por Satisfiability Modulo Theories, primero en conferencia #cite(<turkmen2015analysis>) y luego en su extensión de revista #cite(<turkmen2017formal>). Ese es el antecedente metodológico más cercano, pues traduce políticas a fórmulas decidibles y delega la decisión a un SMT como Z3 #cite(<demoura2008z3>). Ferraiolo y colaboradores contrastaron XACML con el Control de Acceso de Próxima Generación, conocido por sus siglas en inglés como NGAC por Next Generation Access Control #cite(<ferraiolo2016xacml>). Frente a esa línea, este trabajo no traduce a SMT en cada consulta: las propiedades de coherencia y la interfaz guardada están escritas y probadas directamente en Dafny #cite(<leino2010dafny>), de modo que el testigo de cada violación y la preservación del invariante de evolución son lemas del propio desarrollo, y el decisor que se ejecuta es el código compilado desde esas pruebas.

== Detección de conflictos en ABAC

La literatura registra métodos dedicados de detección de conflictos en políticas ABAC #cite(<liu2021novel>) sobre el marco de definición estándar #cite(<hu2014guide>). Frente a esa línea, este trabajo unifica contradicción, insatisfacibilidad, sombreado y validez de esquema en un único predicado de coherencia con testigos homogéneos, y lo integra en una interfaz de evolución guardada donde el rechazo deja el conjunto inalterado.

== Lenguajes de autorización analizables

Cedar es un lenguaje de autorización expresivo, rápido, seguro y analizable con semántica formal y un enfoque guiado por verificación #cite(<cutler2024cedar>), cuya metodología de construcción se documentó por separado #cite(<cutler2024built>) y cuya implementación de referencia es pública #cite(<cedarrepo>). Frente a esa línea, este trabajo opera en un fragmento ABAC deliberadamente menor, sin aritmética ni comparaciones entre atributos, a cambio de una garantía distinta: no solo un lenguaje analizable, sino un invariante de evolución demostrado según el cual todo conjunto confirmado por la interfaz es coherente, ejecutado como código compilado desde las pruebas. El lenguaje abreviado de autorización ALFA ofrece una sintaxis compacta sobre el modelo XACML, aunque no se halló registro canónico verificable en Crossref ni en OpenAlex en esta sesión y por ello no se le asigna afirmación bibliográfica.

== Verificación de software con Dafny y SMT

Dafny es un verificador automático de programas para corrección funcional #cite(<leino2010dafny>) con documentación pública #cite(<dafnydocs>), apoyado en resolutores SMT como Z3 #cite(<demoura2008z3>) y cvc5 #cite(<barbosa2022cvc5>). Frente a desarrollos que usan Dafny para verificar programas de propósito general, este trabajo lo emplea simultáneamente como especificación ejecutable, pues la enumeración acotada de solicitudes es constructiva, como probador de los lemas de preservación y como fuente de compilación del decisor distribuido en npm.

== Síntesis comparativa

La @tab:comparativa resume las diferencias: los enfoques previos deciden por consulta mediante traducción a SMT o algoritmos dedicados, mientras que este trabajo compila el decisor desde pruebas verificadas y cierra el ciclo con una interfaz de evolución que preserva la coherencia por construcción.

#figure(
  table(
    columns: (1fr, 1fr, 1fr, 1fr),
    inset: 6pt,
    align: left,
    table.header([Enfoque], [Método de decisión], [Testigo de violación], [Garantía de evolución]),
    [Análisis XACML con SMT], [Traducción a SMT por consulta], [Modelo del solucionador], [Sin invariante de evolución],
    [Detección de conflictos ABAC], [Algoritmos dedicados de conflicto], [Par de reglas en conflicto], [Sin guarda de evolución],
    [Cedar], [Lenguaje analizable con verificación guiada], [Análisis de políticas Cedar], [Lenguaje seguro sin invariante de conjunto],
    [Este trabajo], [Núcleo Dafny compilado a JavaScript], [Solicitud con reglas y propiedad P1 a P4], [Interfaz guardada que solo confirma conjuntos coherentes],
  ),
  caption: [Comparación de enfoques de análisis de políticas de autorización.],
) <tab:comparativa>

= Arquitectura del sistema <sec:arquitectura>

El sistema se organiza en tres capas con una sola dirección de dependencia. La capa de núcleo contiene los módulos Dafny de esquema, sintaxis, evaluación, coherencia y transición. La capa de envolturas contiene el cargador de esquema, el analizador sintáctico, los adaptadores hacia valores compilados por Dafny y las funciones de interfaz. La capa de distribución contiene el paquete npm con el código compilado y las declaraciones de tipos. TypeScript nunca reimplementa una decisión del núcleo: valida, adapta y presenta.

#figure(
  image("img/architecture.png", width: 60%),
  caption: [Arquitectura del verificador: el núcleo Dafny compila a JavaScript y las envolturas TypeScript validan, adaptan y presentan sin reimplementar decisiones.],
) <fig:arquitectura>
= Requerimientos funcionales <sec:requerimientos>

#figure(
  placement: auto,
  scope: "parent",
  table(
    columns: (auto, 1fr, auto, 1fr, 1fr),
    inset: 6pt,
    align: left,
    table.header([ID], [Descripción], [Interfaz], [Salida], [Comportamiento ante error]),
    [RF-01], [Cargar un esquema de atributos con familia, nombre, tipo y dominio.], [loadSchema], [Esquema validado.], [Esquema malformado o duplicado produce SchemaError.],
    [RF-02], [Analizar una regla de permiso o denegación con condición sobre el esquema, lo que incluye P4.], [parseRule], [Regla válida.], [Sintaxis inválida produce ParseError y atributo o literal fuera de dominio produce rechazo P4.],
    [RF-03], [Añadir una regla solo si el conjunto extendido es coherente.], [tryAdd], [Conjunto aceptado o rechazo con testigo.], [El rechazo deja el conjunto de entrada inalterado.],
    [RF-04], [Actualizar la regla con un identificador existente bajo la misma guarda.], [tryUpdate], [Conjunto aceptado o rechazo con testigo.], [Identificador desconocido produce rechazo P4 y el conjunto queda inalterado.],
    [RF-05], [Eliminar una regla por identificador.], [remove], [Conjunto reducido.], [La eliminación preserva coherencia por monotonía de subconjunto.],
    [RF-06], [Añadir varias reglas en lote con semántica de todo o nada y en orden.], [tryAddMany], [Conjunto aceptado o primer rechazo.], [El primer rechazo aborta y devuelve el conjunto original.],
    [RF-07], [Informar la coherencia con desglose independiente por propiedad.], [checkCoherent], [Informe con P1 a P4 y primer testigo.], [El primer testigo sigue el orden de P1 a P4.],
    [RF-08], [Decidir una solicitud con las reglas que la activan.], [evaluate], [Decisión de permiso o denegación.], [Solicitud fuera de dominio produce DomainError y el estado interno de conflicto es inalcanzable vía interfaz guardada.],
    [RF-09], [Decidir varias solicitudes preservando el orden.], [evaluateMany], [Lista de decisiones.], [Sin topes por costo lineal por solicitud.],
    [RF-10], [Explicar un testigo en lenguaje legible solo desde TypeScript y sin probar.], [explain], [Texto explicativo.], [No decide y solo presenta.],
    [RF-11], [Imponer topes explícitos de escalabilidad acotada.], [Todas], [Verdictos exactos dentro de topes.], [El exceso produce TooLarge y la opción de topes liberados emite un aviso de rendimiento no verificado por llamada.],
  ),
  caption: [Requerimientos funcionales del verificador con su interfaz y comportamiento ante error.],
) <tab:requerimientos>

Quedan fuera del alcance la persistencia más allá del almacenamiento local, las cuentas de usuario, los conectores de puntos de información de políticas en vivo, la aplicación y distribución de decisiones, las estrategias de resolución de conflictos donde toda superposición de permiso y denegación es error, y el historial o reversión de versiones.

= Implementación <sec:implementacion>

El núcleo Dafny representa cada solicitud como una secuencia posicional donde la posición i guarda el valor del atributo i del esquema, lo que mantiene la enumeración y las demostraciones dentro de teoría pura de secuencias. Los recorridos de verificación usan índices explícitos en lugar de rebanadas de secuencia, pues el rebanado copia y volvía cuadráticos los barridos sobre el espacio total de solicitudes. Los recorridos sobre reglas conservan recursión estructural porque los conjuntos de reglas son pequeños.

La enumeración de solicitudes es constructiva y total: combina los valores de cada declaración con producto cartesiano explícito y cuenta con lemas de solidez y completitud que ligan pertenencia a la enumeración con validez de solicitud. Cada chequeo P1 a P4 es una función ejecutable que devuelve un testigo opcional, y cada uno cuenta con lemas de solidez que garantizan que todo testigo reportado viola genuinamente la propiedad nombrada, además de lemas de completitud sobre dominios acotados.

La frontera entre Dafny y TypeScript usa una única conversión no verificada donde el módulo JavaScript emitido por el compilador se interpreta bajo una interfaz que fija exactamente los miembros usados, y todo acceso posterior pasa por lectores defensivos que lanzan una violación de invariante ante formas inesperadas. Los valores enteros cruzan la frontera como números de precisión arbitraria y los identificadores de regla se asignan en la envoltura como el siguiente entero libre al confirmar. La evaluación de una solicitud nunca enumera el espacio de solicitudes y su costo es lineal en el tamaño del conjunto de reglas.

El chequeo de topes precede a toda operación costosa: número de valores por enumeración, número de reglas y tamaño del espacio de solicitudes. El modo de topes liberados recorre exactamente el mismo camino de decisión y emite un aviso de rendimiento no verificado por llamada, por lo que los veredictos siguen siendo exactos.

= Disponibilidad de datos <sec:datos>

El código fuente, los modelos Dafny, los casos de estudio y este manuscrito están disponibles en https://github.com/microuni-unsa/afve-teo-turno-c-grupo-1-final/.
