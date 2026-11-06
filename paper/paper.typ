#import "ieee.typ": ieee

#show: ieee.with(
  title: [Verificación formal de coherencia en políticas ABAC: un verificador en Dafny compilado a JavaScript con escalabilidad acotada],
  abstract: [
    El control de acceso basado en atributos, conocido como ABAC, permite formular políticas expresivas, pero su administración manual introduce incoherencias silenciosas: contradicciones entre permisos y denegaciones, reglas insatisfacibles y sombreado de directivas. Este artículo presenta un verificador de coherencia formalmente probado cuyo núcleo de decisión está especificado y demostrado en Dafny, y compilado directamente a JavaScript para su distribución como paquete en npm con envolturas en TypeScript. El sistema comprueba cuatro propiedades de coherencia: consistencia, satisfacibilidad, no sombreado y validez de esquema, con emisión de testigos concretos ante cada infracción. Mediante lemas inductivos de preservación, el sistema garantiza que toda evolución del conjunto de reglas a través de su interfaz guardada mantiene la coherencia por construcción. El diseño del autómata de transición se valida mediante verificación de modelos en UPPAAL sobre un universo finito de solicitudes y reglas, con ausencia de interbloqueos y satisfacibilidad de nueve propiedades de seguridad y alcanzabilidad. El trabajo expone la metodología formal empleada, las herramientas adoptadas y los componentes de software desarrollados.
  ],
  index-terms: (
    "control de acceso basado en atributos",
    "métodos formales",
    "Dafny",
    "UPPAAL",
    "coherencia de políticas",
    "verificación de software",
    "escalabilidad acotada",
    "TypeScript",
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

#show figure.where(kind: table): set block(breakable: true)
#set table.cell(breakable: false)

= Introducción <sec:introduccion>

El control de acceso es una función central en los sistemas de información, pues determina qué operaciones puede ejecutar cada sujeto sobre un recurso y bajo qué condiciones. ABAC expresa esas decisiones mediante atributos de sujeto, recurso, acción y entorno, de acuerdo con la definición canónica del Instituto Nacional de Estándares y Tecnología de los Estados Unidos, conocido como NIST por sus siglas en inglés #cite(<hu2014guide>), y su presentación sintética #cite(<hu2015abac>). Frente a los esquemas basados en roles, ABAC permite especificar reglas expresivas, tales como autorizar la lectura de una historia clínica cuando el cargo corresponde a personal médico y el nivel de habilitación supera la sensibilidad del documento. Esta flexibilidad aumenta el tamaño y la superposición de las directivas, lo que dificulta su auditoría manual.

En universidades, hospitales y organismos públicos, las directivas de acceso cambian con frecuencia por rotación de turnos, convenios y servicios de guardia. La práctica habitual delega la administración a la edición directa de archivos de configuración o paneles de gestión sin verificación formal. Cualquier omisión introduce contradicciones silenciosas que solo se manifiestan cuando una solicitud concreta recibe un veredicto erróneo, sea una denegación indebida que detiene una atención médica o una autorización que expone datos confidenciales.

Este trabajo resuelve dos problemas concretos. Primero, decide la coherencia de un conjunto de reglas ABAC y emite ante cada defecto un testigo estructurado que identifica la solicitud, las directivas en conflicto y la propiedad vulnerada. Segundo, garantiza que toda mutación del conjunto preserve la coherencia por construcción, impidiendo que adiciones, modificaciones o bajas dejen al sistema en un estado inválido. La solución integra un núcleo de decisión especificado y demostrado en Dafny #cite(<leino2010dafny>), compilado a JavaScript y distribuido en el gestor de paquetes npm con capas protectoras en TypeScript. La complejidad computacional se acota mediante dominios finitos por esquema, topes declarados con errores explícitos y algoritmos de recorrido deterministas.

A diferencia de las comprobaciones muestrales, un verificador demostrado formalmente garantiza que toda política confirmada por la interfaz guardada satisface las invariantes de coherencia de forma exhaustiva.

El artículo se estructura de la siguiente manera. La @sec:problema define el problema formal y establece las definiciones básicas. La @sec:justificacion expone la justificación teórica, operativa y metodológica. La @sec:objetivos formula los objetivos del proyecto. La @sec:alcance delimita el alcance funcional, los requerimientos y las exclusiones. La @sec:relacionado examina el trabajo previo y presenta una tabla comparativa. La @sec:metodologia detalla el proceso metodológico y sus etapas. La @sec:artefactos_empleados cataloga las herramientas y estándares adoptados. La @sec:artefactos_desarrollados documenta los módulos construidos, el modelo de estados y la batería de pruebas. La @sec:datos declara el acceso al código y los datos.

= Definición del problema <sec:problema>

Un conjunto de reglas ABAC se construye de manera incremental mediante directivas de autorización y restricciones de salvaguarda. Sin comprobación matemática, estas ediciones introducen anomalías lógicas.

El marco formal distingue tres clases de fallas lógicas, complementadas por una propiedad de conformidad sintáctica. La propiedad P1 exige consistencia, de modo que ninguna solicitud válida active simultáneamente una regla de permiso y una de denegación. La propiedad P2 exige satisfacibilidad, garantizando que cada regla cuente con al menos una solicitud que satisfaga sus condiciones, lo que previene la existencia de directivas vacías. La propiedad P3 exige ausencia de sombreado, asegurando que cada directiva determine en solitario el resultado de al menos una consulta, evitando reglas redundantes o duplicadas. La propiedad P4 exige validez de esquema, imponiendo que toda regla emplee únicamente atributos declarados, tipos compatibles y valores dentro del rango permitido. Un conjunto de reglas es coherente cuando satisface conjuntamente las cuatro propiedades.

El dominio es finito y decidible. Cada solicitud asigna valores totales a los atributos del esquema dentro de rangos acotados de enteros, valores booleanos o constantes de enumeración. No se permiten dependencias relacionales entre atributos ni operaciones aritméticas abiertas. El criterio central del diseño asegura que todo estado alcanzable mediante la interfaz guardada preserve la coherencia del conjunto.

= Justificación del proyecto <sec:justificacion>

La justificación del proyecto comprende tres dimensiones: teórica, operativa y tecnológica.

En el ámbito teórico, los métodos convencionales de prueba basados en muestreo de casos o cobertura de código resultan insuficientes para certificar la corrección de directivas de acceso. El espacio de solicitudes crece de forma exponencial con el producto cartesiano de los dominios de atributos, lo que deja combinaciones sin evaluar durante las pruebas empíricas. Los análisis estáticos previos suelen limitarse a evaluar conjuntos de reglas estáticos y aislados #cite(<turkmen2017formal>), sin respaldar formalmente la evolución dinámica de las políticas. Especificar el problema en un entorno de verificación deductiva permite demostrar lemas universales de solidez, completitud y preservación que abarcan todas las combinaciones posibles del esquema.

En el plano operativo y de seguridad, los entornos con alta rotación organizativa modifican sus políticas de autorización de forma continua. Cuando la administración se realiza sobre archivos en formatos como JSON o YAML, las inconsistencias desapercibidas provocan fallas de acceso. Un conflicto puede otorgar privilegios indebidos y vulnerar la privacidad de datos clínicos, o denegar el paso a personal de guardia durante una emergencia médica. La generación de un testigo mínimo con la solicitud conflictiva y los identificadores de regla permite auditar y corregir las directivas sin requerir inspecciones manuales extensas.

En el plano metodológico y tecnológico, la aplicación de métodos formales en entornos comerciales suele verse frenada por la dificultad de integrar demostradores matemáticos en arquitecturas web. Alojar un motor de resolución lógica como servicio independiente incrementa la latencia y la superficie de exposición en producción. Este desarrollo adopta el principio de corrección por construcción, conocido como CbC por sus siglas en inglés: el núcleo formal se demuestra en Dafny y se compila a código JavaScript estándar, protegido por envolturas en TypeScript. El sistema ofrece garantías matemáticas directas sin añadir dependencias de cálculo simbólico en el entorno de despliegue.

= Objetivos del proyecto <sec:objetivos>

El objetivo general consiste en diseñar, verificar formalmente e implementar un verificador de coherencia para políticas ABAC con garantías de preservación por construcción y escalabilidad acotada, distribuido como paquete en el ecosistema npm con núcleo de decisión demostrado en Dafny, validado mediante model checking en UPPAAL y provisto de capas protectoras en TypeScript.

Los objetivos específicos son los siguientes:

1. Formalización y semántica: formalizar en Dafny la sintaxis abstracta de reglas de permiso y denegación sobre atributos de sujeto, recurso, acción y entorno con expresiones booleanas y comparaciones de enteros acotados frente a literales, definiendo su semántica denotacional y las cuatro propiedades de coherencia de P1 a P4.
2. Invariante de evolución y guardas: implementar una interfaz de administración total que confirme únicamente conjuntos coherentes, demostrando mediante lemas inductivos la preservación de la coherencia ante operaciones de adición, actualización y retiro de reglas, con generación de testigos diagnósticos ante rechazos.
3. Verificación de concurrencia y ausencia de bloqueos: modelar el autómata de transición del administrador en la herramienta UPPAAL y verificar exhaustivamente la ausencia de interbloqueos, la invariancia de coherencia y la alcanzabilidad de cada clase de veredicto.
4. Empaquetado y aislamiento en la frontera: compilar el núcleo probado de Dafny a JavaScript y construir una biblioteca modular en TypeScript con validación sintáctica estricta, límites de escala explícitos y una suite de pruebas de regresión reproducible.

= Alcance del proyecto <sec:alcance>

== Alcance funcional

El proyecto abarca el ciclo completo de especificación formal, verificación deductiva, verificación de modelos, compilación y empaquetado del software:

1. Definición formal de la sintaxis ABAC para atributos de enumeración finita, valores booleanos y enteros acotados, distribuidos en las cuatro categorías del estándar NIST SP 800-162 #cite(<hu2014guide>): sujeto, recurso, acción y entorno.
2. Formulación matemática e implementación de las cuatro propiedades de coherencia: consistencia P1, satisfacibilidad P2, ausencia de sombreado P3 y validez de esquema P4.
3. Interfaz de evolución guardada con operaciones atómicas individuales de adición tryAdd, actualización tryUpdate y eliminación remove, así como procesamiento por lotes con semántica atómica mediante tryAddMany.
4. Motor de decisión para consultas individuales evaluate y múltiples evaluateMany, garantizando un costo computacional lineal respecto al total de reglas.
5. Biblioteca para entornos Node.js y navegadores bajo el paquete \@grupo1/abac-verifier, incorporando tipado estático, analizador sintáctico y formateador de diagnósticos.
6. Validación experimental mediante casos de estudio sobre directivas clínicas de urgencia, conjuntos consistentes y casos con violaciones deliberadas, respaldados por pruebas de regresión.

== Límites y exclusiones

Para mantener la decidibilidad formal y la predictibilidad del tiempo de cálculo, se establecen las siguientes exclusiones:

1. Conexiones en tiempo real a puntos de información de políticas, conocidos como PIP por sus siglas en inglés: el verificador no efectúa consultas de red, lecturas a bases de datos ni invocaciones a servicios externos de contexto. Los atributos se limitan a los dominios fijados en el esquema.
2. Lógica de primer orden y relaciones dinámicas entre atributos: no se contemplan cadenas de texto abiertas, expresiones regulares ni comparaciones dinámicas entre campos, como contrastar la habilitación del usuario frente a la clasificación del recurso. Cada condición atómica evalúa un atributo contra un valor literal fijo.
3. Mecanismos permisivos de resolución de conflictos: no se admiten estrategias como prioridad de denegación, prioridad de permiso o pesos numéricos para dirimir solapamientos. Toda coincidencia simultánea entre permiso y denegación para una misma solicitud se califica como incoherencia.
4. Puntos de aplicación de políticas, conocidos como PEP, y puntos de decisión distribuidos, conocidos como PDP: la biblioteca no provee intermediarios de red para captura de tráfico ni componentes de autenticación.
5. Gestión de versiones y almacenamiento histórico: la persistencia relacional y el seguimiento histórico de versiones corresponden a capas externas a este verificador.

== Supuestos y condiciones de frontera

El funcionamiento del sistema parte de que los dominios de los atributos son finitos y quedan determinados al cargar el esquema. Toda solicitud que ingresa a la biblioteca se valida como una asignación completa y bien tipada antes de su procesamiento en el núcleo. Asimismo, el sistema impone límites operativos al número de valores por enumeración y a la cantidad de reglas, emitiendo errores tipados cuando una política excede los topes admitidos.

La @tab:requerimientos describe los requerimientos funcionales del sistema, indicando la operación correspondiente, la salida esperada y la gestión de excepciones.

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
    [RF-11], [Imponer topes explícitos de escalabilidad acotada.], [Todas], [Veredictos exactos dentro de topes.], [El exceso produce TooLarge y la opción de topes liberados emite un aviso de rendimiento no verificado por llamada.],
  ),
  caption: [Requerimientos funcionales del verificador con su interfaz y comportamiento ante error.],
) <tab:requerimientos>

= Trabajo relacionado <sec:relacionado>

== Análisis de políticas XACML

Fisler y sus colaboradores establecieron las bases del análisis formal de políticas al verificar propiedades y evaluar el impacto de cambios en directivas de autorización #cite(<fisler2005verification>). Turkmen y su equipo formalizaron el análisis del Lenguaje Extensible de Marcado para Control de Acceso, conocido como XACML por sus siglas en inglés, mediante traductores a solucionadores de satisfacibilidad módulo teorías, conocida como SMT por sus siglas en inglés, primero en su publicación de conferencia #cite(<turkmen2015analysis>) y posteriormente en su edición extendida #cite(<turkmen2017formal>). Dicha aproximación traduce las directivas a fórmulas lógicas y consulta a un solucionador externo como Z3 #cite(<demoura2008z3>). Ferraiolo y su equipo compararon el comportamiento de XACML con el Control de Acceso de Próxima Generación, conocido como NGAC por sus siglas en inglés #cite(<ferraiolo2016xacml>). A diferencia de esos esquemas, el presente desarrollo no formula consultas repetitivas a un motor SMT en tiempo de ejecución: las condiciones de coherencia y las guardas de modificación se demuestran de forma directa en Dafny #cite(<leino2010dafny>), por lo que el algoritmo ejecutado corresponde al código extraído de las pruebas deductivas.

== Detección de conflictos en ABAC

Diversos estudios proponen algoritmos específicos para detectar conflictos en modelos ABAC #cite(<liu2021novel>) basados en las guías estándar #cite(<hu2014guide>). La presente propuesta unifica los defectos de contradicción, reglas insatisfacibles, sombreado y violación de esquema en una comprobación común con testigos uniformes, e integra el diagnóstico dentro de una interfaz guardada que preserva el estado ante cualquier rechazo.

== Lenguajes de autorización analizables

Cedar constituye un lenguaje de autorización diseñado para evaluación rápida y análisis formal mediante verificación guiada #cite(<cutler2024cedar>), con metodología documentada #cite(<cutler2024built>) y código público #cite(<cedarrepo>). Frente a Cedar, este proyecto restringe intencionalmente el lenguaje al omitir operaciones aritméticas abiertas y comparaciones cruzadas entre atributos, a cambio de una garantía inductiva: toda política aceptada por la interfaz guardada mantiene la coherencia por construcción. Por su parte, el lenguaje ALFA ofrece una sintaxis simplificada para el estándar XACML, pero carece de un marco integrado de verificación formal y compilación directa a JavaScript.

== Verificación de software con Dafny y motores SMT

Dafny opera como un entorno formal de programación y verificación funcional #cite(<dafnydocs>), utilizando motores SMT como Z3 #cite(<demoura2008z3>) y cvc5 #cite(<barbosa2022cvc5>) para solventar las condiciones lógicas de prueba. Mientras que los usos convencionales aplican Dafny a programas generales, este proyecto lo emplea simultáneamente como especificación formal ejecutable, como probador deductivo de lemas de preservación y como base para compilar el módulo distribuido en npm.

== Síntesis comparativa

La @tab:comparativa contrasta los enfoques existentes, comparando su metodología, el tipo de testigo generado, la presencia de garantías de preservación y la existencia de invariantes de evolución.

#figure(
  placement: auto,
  table(
    columns: (1fr, 1.05fr, 1fr, 1fr),
    inset: (x: 2.8pt, y: 4.5pt),
    align: left,
    table.header([Enfoque], [Método], [Testigo], [Garantía]),
    [Análisis XACML con SMT], [Traducción a SMT por consulta], [Modelo del solucionador], [Sin invariante de evolución],
    [Detección de conflictos ABAC], [Algoritmos dedicados], [Par de reglas en conflicto], [Sin guarda de evolución],
    [Lenguaje Cedar], [Verificación formal guiada], [Diagnóstico del analizador], [Sin invariante de conjunto],
  ),
  caption: [Comparación de enfoques de análisis de políticas de autorización.],
) <tab:comparativa>

= Metodología utilizada y desarrollo <sec:metodologia>

== Enfoque metodológico

Para el desarrollo del proyecto se aplicó una metodología de métodos formales guiada por el paradigma de corrección por construcción CbC. En lugar de desarrollar código preliminar para someterlo a pruebas muestrales posteriores, este paradigma fundamenta el desarrollo en la especificación matemática previa, la deducción de lemas y la comprobación de modelos en cada fase de diseño.

El desarrollo se articuló en cinco fases secuenciales:

1. Fase 1: especificación y modelado formal del dominio. Se formalizó la sintaxis abstracta de las políticas ABAC, los tipos de datos algebraicos y la semántica denotacional en Dafny, formulando la función AllRequests para enumerar el espacio cartesiano de solicitudes sobre secuencias puras.
2. Fase 2: verificación deductiva de propiedades e invariantes en Dafny. Se formalizaron las propiedades de coherencia de P1 a P4 junto con sus funciones de decisión ejecutables y generadores de testigos, demostrando siete lemas deductivos de solidez, completitud y preservación resueltos mediante los motores SMT Z3 y cvc5.
3. Fase 3: verificación de estados por model checking en UPPAAL. Con el fin de evaluar la interacción temporal y la concurrencia en la administración de políticas, se construyó un autómata de estados finitos en UPPAAL mediante el archivo uppaal/abac-guard.xml y se formularon nueve consultas en lógica de árbol de computación temporal, conocida como TCTL por sus siglas en inglés, para comprobar la ausencia de interbloqueos y la persistencia de coherencia.
4. Fase 4: compilación verificada y diseño de envolturas defensivas. El código puro verificado en Dafny se compiló a JavaScript estándar, sobre el cual se construyeron capas de integración en TypeScript encargadas del análisis sintáctico, control de límites operativos y formateo de testimonios.
5. Fase 5: validación empírica, banco de pruebas y reproducibilidad. Se establecieron escenarios de prueba basados en situaciones reales, como directivas médicas de urgencia y casos de inconsistencia inducida, configurando suites de repetición de contraejemplos e integrando la compilación hermética mediante Nix Flakes.

= Artefactos empleados <sec:artefactos_empleados>

El desarrollo integró herramientas de deducción formal, lenguajes de desarrollo y estándares de autorización seleccionados por su rigor técnico y su reproducibilidad.

En el ámbito de la verificación formal, se utilizó Dafny versión 4 para la especificación matemática, la deducción de propiedades y la generación de código JavaScript. La resolución de metas lógicas en Dafny se apoyó en los motores SMT Z3 versión 4.12 o superior y cvc5 versión 1.0 o superior. Para el análisis exhaustivo de estados y concurrencia se empleó la herramienta UPPAAL versión 5.0.

En la capa de programación anfitriona y ejecución, se utilizó TypeScript versión 5 para el análisis sintáctico y las barreras defensivas de tipos, complementado por Node.js versión 20 o superior y Bun versión 1 como entornos de ejecución y empaquetado. El formateo y análisis estático de código se gestionó mediante Biome versión 1.9 o superior.

Como base teórica y normativa de autorización, el sistema adopta las directrices de la Publicación Especial 800-162 de NIST y los lineamientos comparativos del estándar XACML 3.0. La reproducibilidad del entorno de desarrollo y compilación se garantizó mediante Nix Flakes, mientras que la composición tipográfica de este artículo se realizó en Typst versión 0.15.1 bajo lineamientos de IEEE.

La @tab:artefactos_empleados resume la pila tecnológica y herramientas formales utilizadas en el núcleo y la capa anfitriona del sistema, indicando su versión, categoría y su rol específico en la arquitectura de la solución.

#figure(
  placement: auto,
  scope: "parent",
  table(
    columns: (1.2fr, 0.8fr, 1.2fr, 2.5fr),
    inset: 5pt,
    align: left,
    table.header([Herramienta / Tecnología], [Versión], [Categoría], [Rol y función en el proyecto]),
    [Dafny], [4.x], [Verificación deductiva], [Especificación matemática del modelo ABAC, prueba de 7 lemas y compilación a JavaScript.],
    [Z3 y cvc5], [4.12+ / 1.0+], [Solucionadores SMT], [Resolución automatizada de metas lógicas y condiciones de verificación en Dafny.],
    [UPPAAL], [5.0], [Model checking], [Verificación temporal de estados del administrador y validación de 9 consultas TCTL.],
    [TypeScript], [5.x], [Lenguaje anfitrión], [Analizador sintáctico, barreras defensivas de tipos y envolturas del núcleo compilado.],
    [Node.js y Bun], [20+ / 1.x], [Entorno de ejecución], [Ejecución del banco de pruebas, suite de regresión y empaquetado para distribución npm.],
    [Biome], [1.9+], [Calidad y análisis estático], [Formateo estricto y detección de malas prácticas en la base de código TypeScript.],
  ),
  caption: [Pila tecnológica y herramientas formales del proyecto.],
) <tab:artefactos_empleados>

= Artefactos desarrollados <sec:artefactos_desarrollados>

El proyecto generó un conjunto articulado de módulos formales, código ejecutable y bancos de evaluación.

== Arquitectura del sistema

El sistema se estructura en tres capas con dependencias unidireccionales, como se presenta en la @fig:arquitectura. La capa de núcleo contiene los módulos Dafny correspondientes a esquema, sintaxis, evaluación, coherencia y transición. La capa de envolturas incluye el cargador de esquema, el analizador sintáctico, los adaptadores de tipos hacia las funciones generadas por Dafny y la interfaz de programación pública. La capa de distribución comprende el paquete npm empaquetado junto con sus declaraciones de tipos. La capa en TypeScript no recalcula decisiones del verificador: valida entradas, adapta estructuras y presenta los diagnósticos.

#figure(
  image("img/architecture.png", width: 60%),
  caption: [Arquitectura del verificador: el núcleo Dafny compila a JavaScript y las envolturas TypeScript validan, adaptan y presentan sin reimplementar decisiones.],
) <fig:arquitectura>

La @fig:clases presenta las clases y tipos del verificador agrupados en sus dos componentes principales: el núcleo formal en Dafny y las envolturas en TypeScript.

#figure(
  image("img/classes.png", width: 100%),
  caption: [Diagrama de clases del verificador con el núcleo Dafny y las envolturas TypeScript.],
) <fig:clases>

== Núcleo formal en Dafny

El núcleo en Dafny está compuesto por seis módulos principales:
- Schema.dfy: declaraciones de familias de atributos, tipos de enumeración, booleanos y enteros acotados, condiciones de validez y generación del espacio cartesiano de solicitudes AllRequests.
- Syntax.dfy: tipos algebraicos para condiciones lógicas, efectos de permiso y denegación, reglas individuales y colecciones ordenadas Ruleset.
- Eval.dfy: semántica denotacional pura para evaluar la satisfacción de condiciones mediante Satisfies, la activación de reglas mediante Applies y el veredicto sobre solicitudes mediante Evaluate.
- Coherence.dfy: formalización de las propiedades P1 a P4, algoritmos de decisión ejecutables y emisión de testimonios diagnósticos Witness.
- Transition.dfy: operaciones guardadas de actualización TryAdd, TryUpdate y TryRemove, junto con las demostraciones deductivas de preservación invariante y solidez de testigos.
- BoundedCheck.dfy: procedimientos de comprobación exhaustiva sobre configuraciones acotadas para contrastar lemas inductivos.

En el núcleo, la estructura AttrDecl define cada atributo con su familia, identificador, tipo y dominio. La estructura Request implementa una secuencia ordenada de valores alineada con las posiciones del esquema, lo que circunscribe el razonamiento a la teoría de secuencias. Los recorridos sobre el espacio de solicitudes operan mediante índices enteros directos, evitando la creación de particiones intermedias en memoria.

La @fig:chequeos resume el proceso de comprobación de coherencia implementado en Dafny, detallando su algoritmo ejecutable, estructura de testigo, lemas asociados y complejidad asintótica.

#figure(
  placement: auto,
  scope: "parent",
  image("img/check_phases.png", width: 100%),
  caption: [Etapas de comprobación de coherencia en el núcleo formal Dafny: orden de ejecución de propiedades P4 a P3, funciones ejecutables, lemas deductivos, testigos diagnósticos y costo computacional.],
) <fig:chequeos>

El siguiente bloque de código presenta la función de adición guardada TryAdd y su correspondiente lema deductivo de preservación AddPreserves verificado en Dafny:

```dafny
function TryAdd(R: Ruleset, r: Rule, schema: Schema): AddResult {
  var w := CheckCoherent(R + [r], schema);
  if w.NoWitness? then Accepted(R + [r]) else Rejected(w.wit)
}
lemma AddPreserves(R: Ruleset, r: Rule, schema: Schema)
  ensures match TryAdd(R, r, schema)
    case Accepted(rs) => Coherent(rs, schema)
    case Rejected(_) => true
{
  var w := CheckCoherent(R + [r], schema);
  if w == NoWitness {
    CheckCoherentSound(R + [r], schema);
  }
}
```

== Modelo de verificación en UPPAAL

El autómata del componente de administración se especificó y validó en UPPAAL #cite(<larsen1997uppaal>) mediante el modelo uppaal/abac-guard.xml y las propiedades en uppaal/abac-guard.q. El universo de prueba abarca dieciséis solicitudes generadas a partir de dos roles, dos acciones, dos bandas horarias y dos estados de emergencia, evaluando diez reglas candidatas.

#figure(
  image("img/model_diagram.png", width: 90%),
  caption: [Autómata Admin modelado en UPPAAL en uppaal/abac-guard.xml.],
) <fig:transicion>

Como muestra la @fig:transicion, las ubicaciones Empty y Coherent modelan configuraciones consistentes confirmadas, mientras que TryingAddE, TryingAddC y TryingUpdC constituyen estados comprometidos que imponen transiciones atómicas sin entrelazado de eventos concurrentes.

Las nueve consultas formuladas en TCTL se organizan en propiedades de seguridad y de alcanzabilidad, expuestas en la @tab:consultas.

#figure(
  table(
    columns: (auto, 1fr, auto),
    inset: 6pt,
    align: left,
    table.header([Consulta], [Lectura en lenguaje natural], [Clase]),
    [A\[\] coherent()], [Todo estado alcanzable es coherente], [Seguridad],
    [A\[\] \!deadlock], [Ninguna ejecución se bloquea], [Seguridad],
    [A\[\] (lastOp \!= 2 \|\| coherent())], [Toda eliminación preserva coherencia], [Seguridad],
    [E\<\> cleanAccepted], [El conjunto con reglas r0, r1 y r2 es aceptable], [Alcanzabilidad],
    [E\<\> rejP1], [El rechazo por contradicción ocurre, testigo con reglas r0 y r3], [Alcanzabilidad],
    [E\<\> rejP2], [El rechazo por regla muerta ocurre, testigo con regla r6], [Alcanzabilidad],
    [E\<\> rejP3], [El rechazo por sombreado ocurre, testigo con reglas r0 y r4], [Alcanzabilidad],
    [E\<\> rejUnknownP4], [El rechazo por identificador desconocido ocurre], [Alcanzabilidad],
    [E\[\] coherent()], [Existe una senda siempre coherente], [Alcanzabilidad],
  ),
  caption: [Consultas de uppaal/abac-guard.q agrupadas por clase.],
) <tab:consultas>

Todas las consultas resultaron satisfechas, como documenta la @fig:verificador. La verificación requirió 16.7 segundos para la invariante de coherencia global A[] coherent() y 28.7 segundos para la ausencia de interbloqueos A[] !deadlock, explorando 23 estados alcanzables y 529 transiciones.

#figure(
  image("img/checking_results.png", width: 90%),
  caption: [Panel del verificador de UPPAAL: las nueve consultas se satisfacen.],
) <fig:verificador>

== Biblioteca y envolturas en TypeScript

La capa en TypeScript define los puntos de acceso y las validaciones de entrada:
- schema.ts: verifica declaraciones de atributos y provee métodos de construcción seguros.
- parser.ts: analiza sintácticamente las expresiones de condición y las directivas ABAC, validando identificadores y literales contra el esquema cargado.
- wrappers.ts: coordina la comunicación con el motor compilado de Dafny mediante funciones lectoras y ofrece los métodos tryAdd, tryUpdate, remove, checkCoherent y evaluate.
- explain.ts: transforma la estructura del testigo formal en mensajes diagnósticos legibles.
- batch.ts: administra la evaluación y adición de directivas por lotes bajo semántica atómica.
- errors.ts: declara errores estructurados para fallas de esquema, sintaxis, valores fuera de rango y superación de límites de escala.

== Banco de pruebas, casos de estudio y suite de regresión

Se diseñaron escenarios canónicos de evaluación estructurados en formato JSON:
- clean.json: directivas válidas y mutuamente coherentes.
- contradictory.json: conflicto por superposición entre una directiva de permiso y una de denegación ante una misma solicitud, correspondiente a una violación P1.
- unsatisfiable.json: directiva con predicados contradictorios sobre rangos enteros, correspondiente a una violación P2.
- shadowed.json: directiva redundante cubierta por directivas previas, correspondiente a una violación P3.
- emergency-override.json: directiva clínica de excepción en urgencias médicas para autorizar acceso fuera de horario regular.

La suite automatizada de pruebas, integrada por test/parser.test.ts, test/wrappers.test.ts y test/replay.test.ts, valida el rechazo ante entradas malformadas y confirma la reproducción exacta de los testigos generados.

== Resumen consolidador de artefactos desarrollados

La @tab:artefactos_desarrollados reúne los artefactos desarrollados en el proyecto, detallando su ubicación relativa, lenguaje utilizado, tamaño y contribución técnica.

#figure(
  placement: auto,
  scope: "parent",
  table(
    columns: (1.2fr, 1.2fr, 0.8fr, 1.2fr, 2.5fr),
    inset: 5pt,
    align: left,
    table.header([Artefacto desarrollado], [Ruta / Módulo], [Lenguaje], [Métricas], [Contribución técnica principal]),
    [Núcleo formal Dafny], [dafny/], [Dafny], [6 módulos, ~48 KB, 7 lemas], [Especificación ejecutable, semántica ABAC, 4 propiedades de coherencia e invariante de evolución probado.],
    [Modelo de estados UPPAAL], [uppaal/abac-guard.xml], [XML / UPPAAL], [1 autómata, 23 estados, 529 transiciones], [Model checking de transiciones del componente Admin, libre de interbloqueos.],
    [Consultas formales TCTL], [uppaal/abac-guard.q], [TCTL], [9 consultas verificadas], [Comprobación matemática de seguridad y alcanzabilidad de veredictos.],
    [Analizador sintáctico], [src/parser.ts], [TypeScript], [9.6 KB], [Parser estricto de reglas ABAC con verificación inmediata de tipo y rango contra el esquema.],
    [Envolturas y adaptadores], [src/wrappers.ts, schema.ts], [TypeScript], [19.7 KB], [Capa defensiva y frontera segura con el motor JavaScript compilado desde Dafny.],
    [Generador de explicaciones], [src/explain.ts], [TypeScript], [0.9 KB], [Traducción legible de testigos formales hacia explicaciones diagnósticas para administradores.],
  ),
  caption: [Catálogo consolidado de artefactos desarrollados por el proyecto.],
) <tab:artefactos_desarrollados>

= Disponibilidad de datos y código <sec:datos>

El código fuente completo, las especificaciones en Dafny, los modelos y consultas de UPPAAL, la suite de pruebas automatizadas y este documento se encuentran disponibles bajo licencia de código abierto en el repositorio público https://github.com/microuni-unsa/afve-teo-turno-c-grupo-1-final/.
