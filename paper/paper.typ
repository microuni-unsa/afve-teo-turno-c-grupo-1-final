#import "ieee.typ": ieee

#show: ieee.with(
  title: [Verificación formal de coherencia en políticas ABAC: un enfoque de corrección por construcción en Dafny y model checking en UPPAAL],
  abstract: [
    El control de acceso basado en atributos o ABAC permite formular directivas expresivas, aunque su edición manual suele introducir contradicciones entre permisos y denegaciones, reglas insatisfacibles o sombreado de directivas. Este artículo describe un verificador de coherencia con un núcleo de decisión especificado y demostrado en Dafny, compilado a JavaScript para su distribución como paquete en npm junto con envolturas en TypeScript. El sistema comprueba cuatro propiedades de coherencia: consistencia, satisfacibilidad, ausencia de sombreado y validez de esquema, y entrega testigos concretos ante cada infracción. Mediante lemas inductivos de preservación, el verificador asegura que las operaciones de la interfaz guardada mantienen la coherencia del conjunto de reglas. El autómata de administración se valida en UPPAAL sobre un universo acotado de solicitudes y directivas, donde comprueba la ausencia de interbloqueos y satisface nueve propiedades temporales de seguridad y alcanzabilidad. Por último, el documento presenta la metodología, los módulos construidos y las restricciones de escala propias de la enumeración cartesiana.
  ],
  index-terms: (
    "control de acceso basado en atributos",
    "métodos formales",
    "Dafny",
    "UPPAAL",
    "coherencia de políticas",
    "verificación de software",
    "corrección por construcción",
    "verificación deductiva",
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

El control de acceso determina las operaciones que cada sujeto puede ejecutar sobre un recurso y bajo qué condiciones. ABAC formula estas decisiones mediante atributos de sujeto, recurso, acción y entorno, conforme a las pautas del Instituto Nacional de Estándares y Tecnología de Estados Unidos o NIST #cite(<hu2014guide>) y los lineamientos de verificación del estándar NIST SP 800-192 #cite(<hu2017verification>). Respecto a los esquemas basados en roles, ABAC ofrece mayor expresividad, como autorizar la lectura de una historia clínica cuando el usuario es médico y su habilitación supera la sensibilidad del documento. No obstante, esta flexibilidad incrementa la cantidad y el solapamiento de las directivas, lo que complica la revisión manual.

En universidades, centros hospitalarios y administraciones públicas, las reglas de acceso cambian con regularidad por rotación de turnos, convenios y guardias. Su mantenimiento habitual se apoya en ediciones directas de archivos de configuración o paneles web sin comprobaciones formales. Cualquier omisión genera conflictos lógicos que se manifiestan cuando una solicitud obtiene un resultado erróneo, como una denegación indebida que frena la atención clínica o un permiso que expone información reservada.

Este trabajo aborda dos aspectos específicos. En primer lugar, decide la coherencia de un conjunto de reglas ABAC y entrega ante cada fallo un testigo estructurado con la solicitud, las directivas involucradas y la propiedad vulnerada. En segundo lugar, asegura que cada mutación guardada preserve la coherencia del conjunto, de modo que ninguna adición, cambio o baja conduzca a un estado inválido. La solución utiliza un núcleo de decisión demostrado en Dafny #cite(<leino2010dafny>), compilado a JavaScript y distribuido como paquete en npm con envolturas en TypeScript. El costo de cómputo se controla mediante dominios discretos por esquema, límites declarados con rechazo inmediato y algoritmos deterministas de enumeración.

El resto del documento se distribuye como sigue: la @sec:problema define el problema formal; la @sec:justificacion y la @sec:objetivos detallan la justificación y metas del proyecto; la @sec:alcance precisa el alcance funcional y las exclusiones; la @sec:relacionado analiza el trabajo previo; la @sec:metodologia y la @sec:artefactos_empleados exponen el método y las herramientas adoptadas; la @sec:artefactos_desarrollados documenta los módulos construidos y los modelos de verificación; la @sec:discusion evalúa limitaciones y amenazas a la validez; la @sec:conclusiones resume las conclusiones y líneas futuras, y la @sec:datos detalla el acceso al repositorio y sus artefactos.

= Definición del problema <sec:problema>

Un conjunto de reglas ABAC se amplía de forma incremental con directivas de autorización y salvaguardas. Sin validación formal, las modificaciones continuas provocan fallas lógicas.

El modelo distingue tres tipos de anomalías lógicas y una condición de validez sintáctica. La propiedad P1 define consistencia: ninguna solicitud válida activa a la vez una regla de permiso y una de denegación. La propiedad P2 define satisfacibilidad: cada directiva tiene al menos una solicitud que satisface sus condiciones, lo que descarta reglas insatisfacibles. La propiedad P3 define ausencia de sombreado: cada regla decide por sí sola el resultado de al menos una consulta, lo que evita directivas redundantes. La propiedad P4 define validez de esquema: toda directiva utiliza solo atributos declarados, tipos compatibles y valores dentro del rango admitido. Un conjunto de directivas resulta coherente cuando satisface a la vez las cuatro propiedades.

El dominio del sistema es discreto y finito. Cada solicitud asigna valores a los $k$ atributos del esquema en rangos enteros acotados, booleanos o constantes de enumeración. La cardinalidad del espacio total de solicitudes AllRequests corresponde al producto cartesiano de los dominios declarados:

$ |"AllRequests"| = product_(i=1)^(k) |D_i| $ <eq:allrequests>

donde $|D_i|$ denota la cardinalidad del dominio del atributo $i$. Sobre este universo, comprobar consistencia P1 y satisfacibilidad P2 toma un tiempo de $O(|R| dot |"AllRequests"|)$, mientras que detectar sombreado P3 toma $O(|R|^2 dot |"AllRequests"|)$, donde $|R|$ es el número total de directivas. El modelo no incluye comparaciones dinámicas entre atributos ni operaciones aritméticas abiertas. Si bien el crecimiento de la @eq:allrequests restringe la cantidad de atributos del esquema, garantiza la decidibilidad y permite obtener un contraejemplo mínimo ante cualquier infracción.

= Justificación del proyecto <sec:justificacion>

La necesidad del proyecto abarca factores teóricos, operativos y tecnológicos.

En el aspecto teórico, las pruebas por muestreo o cobertura de código resultan insuficientes para certificar directivas de autorización. El espacio de solicitudes crece exponencialmente con los dominios de atributos, de modo que las pruebas empíricas dejan combinaciones sin revisar. Asimismo, los análisis estáticos previos suelen evaluar políticas estáticas y aisladas #cite(<turkmen2017formal>), sin considerar la evolución de las reglas a lo largo del tiempo. Modelar el problema en un entorno de verificación deductiva permite probar lemas de solidez, completitud y preservación sobre todas las combinaciones del esquema.

En el aspecto operativo, las organizaciones con alta rotación modifican sus directivas con frecuencia. Si la gestión se realiza sobre archivos JSON o YAML sin validación formal, las inconsistencias no detectadas derivan en fallas de acceso. Un conflicto puede conceder accesos indebidos a datos clínicos o impedir el paso a personal médico en una guardia de emergencia. Disponer de un testigo mínimo que indique la solicitud conflictiva y las reglas implicadas facilita la corrección sin revisiones manuales prolongadas.

En el aspecto metodológico, el uso de métodos formales en aplicaciones web suele complicarse por la integración de motores de deducción externa. Mantener un demostrador lógico como servicio independiente añade latencia y puntos de fallo en producción. Este trabajo sigue el principio de corrección por construcción o CbC #cite(<hall2002correctness>): el núcleo formal se verifica en Dafny y compila directamente a JavaScript estándar, integrado con envolturas en TypeScript. Así, el sistema entrega garantías formales sin requerir motores simbólicos en el entorno de ejecución.

= Objetivos del proyecto <sec:objetivos>

El objetivo general es diseñar, verificar e implementar un verificador de coherencia para políticas ABAC que preserve la coherencia ante cambios mediante pruebas deductivas en Dafny, validación de protocolos en UPPAAL y distribución como biblioteca en npm con envolturas en TypeScript.

Los objetivos específicos comprenden:

1. Formalización y semántica: definir en Dafny la sintaxis abstracta de reglas de permiso y denegación sobre atributos de sujeto, recurso, acción y entorno con expresiones booleanas y rangos enteros acotados, junto con su semántica denotacional y las propiedades de P1 a P4.
2. Invariante de evolución y guardas: construir una interfaz de gestión que admita solo conjuntos coherentes y probar mediante lemas inductivos la preservación de coherencia en operaciones de adición, modificación y baja de reglas, con entrega de testigos diagnósticos ante rechazos.
3. Verificación de protocolos y ausencia de bloqueos: modelar el autómata del administrador en UPPAAL y comprobar la ausencia de interbloqueos, la invariancia de coherencia y la alcanzabilidad de los diferentes veredictos sobre una configuración finita.
4. Empaquetado y validación en frontera: compilar el núcleo verificado de Dafny a JavaScript y estructurar una biblioteca modular en TypeScript con análisis sintáctico, límites de dominio y pruebas automatizadas de regresión.

= Alcance del proyecto <sec:alcance>

== Alcance funcional

El proyecto abarca el ciclo completo de especificación formal, verificación deductiva, verificación de modelos, compilación y empaquetado del software:

1. Definición formal de la sintaxis ABAC para atributos de enumeración, booleanos y enteros acotados en las cuatro categorías de NIST SP 800-162 #cite(<hu2014guide>): sujeto, recurso, acción y entorno.
2. Formulación e implementación de las cuatro propiedades de coherencia: consistencia P1, satisfacibilidad P2, ausencia de sombreado P3 y validez de esquema P4.
3. Interfaz de evolución guardada con operaciones individuales de adición tryAdd, actualización tryUpdate y eliminación remove, junto con procesamiento por lotes mediante tryAddMany.
4. Motor de evaluación para consultas individuales evaluate y múltiples evaluateMany con costo temporal lineal respecto al número de directivas.
5. Biblioteca para entornos Node.js y navegadores en el paquete \@grupo1/abac-verifier, con tipado estático, analizador sintáctico y formateo de diagnósticos.
6. Validación empírica mediante casos de estudio sobre directivas clínicas de urgencia, conjuntos coherentes y casos de violación inducida, acompañados por pruebas de regresión.

== Límites y exclusiones

Para mantener la decidibilidad formal y la predictibilidad del tiempo de cálculo, se establecen las siguientes exclusiones:

1. Conexiones en tiempo real a puntos de información de políticas o PIP: el verificador no realiza consultas de red ni lecturas a bases de datos externas. Los atributos quedan acotados a los dominios del esquema.
2. Lógica de primer orden y relaciones dinámicas entre atributos: no se admiten cadenas de texto libre, expresiones regulares ni comparaciones entre dos atributos de una misma solicitud. Cada condición atómica contrasta un atributo contra un valor literal fijo.
3. Mecanismos de resolución de conflictos: no se emplean reglas de prioridad de denegación ni pesos para resolver solapamientos. Toda coincidencia de permiso y denegación sobre una misma solicitud constituye una contradicción P1.
4. Puntos de aplicación de políticas o PEP, y puntos de decisión distribuidos o PDP: la biblioteca no incluye intermediarios de red ni módulos de autenticación.
5. Gestión de versiones y almacenamiento histórico: la persistencia y el control histórico de directivas corresponden a sistemas externos.

== Supuestos y condiciones de frontera

El sistema asume que los dominios de atributos son finitos y se fijan al cargar el esquema. Toda solicitud recibida por la biblioteca se valida como una asignación completa y bien tipada antes de pasar al núcleo. El analizador en TypeScript desazucara construcciones sintácticas, tales como pertenencia a listas in y rangos between, y las traduce a árboles booleanos canónicos compatibles con el núcleo formal. La correspondencia de esta transformación se comprueba mediante pruebas automatizadas de estructura sobre el árbol de sintaxis abstracta o AST y pruebas de ida y vuelta en test/parser.test.ts. Con el fin de evitar la sobrecarga por crecimiento del espacio AllRequests, el sistema establece límites fijos sobre la cantidad de reglas, los valores por enumeración y el tamaño del producto cartesiano, arrojando la excepción TooLarge en tiempo $O(1)$ cuando una política supera los umbrales previstos.

La @tab:requerimientos describe los requerimientos funcionales del sistema, indicando la operación correspondiente, la salida esperada y la gestión de excepciones.

#figure(
  placement: auto,
  scope: "parent",
  table(
    columns: (0.9fr, 1.4fr, 1fr, 1.1fr, 1.4fr),
    inset: (x: 4pt, y: 5pt),
    align: left,
    table.header([ID], [Descripción], [Interfaz], [Salida], [Comportamiento ante error]),
    [RF-01], [Cargar un esquema de atributos con familia, nombre, tipo y dominio.], [loadSchema], [Esquema validado.], [Esquema malformado o duplicado produce SchemaError.],
    [RF-02], [Analizar una regla con desazucarado sintáctico de operadores in y between y validación P4.], [parseRule], [Regla válida.], [Sintaxis inválida produce ParseError y atributo o literal fuera de dominio produce rechazo P4.],
    [RF-03], [Añadir una regla solo si el conjunto extendido es coherente.], [tryAdd], [Conjunto aceptado o rechazo con testigo.], [El rechazo deja el conjunto de entrada inalterado.],
    [RF-04], [Actualizar la regla con un identificador existente bajo la misma guarda.], [tryUpdate], [Conjunto aceptado o rechazo con testigo.], [Identificador desconocido produce rechazo P4 y el conjunto queda inalterado.],
    [RF-05], [Eliminar una regla por identificador.], [remove], [Conjunto reducido.], [La eliminación preserva coherencia por monotonía de subconjunto.],
    [RF-06], [Añadir varias reglas en lote con semántica de todo o nada y en orden.], [tryAddMany], [Conjunto aceptado o primer rechazo.], [El primer rechazo aborta y devuelve el conjunto original.],
    [RF-07], [Informar la coherencia con desglose independiente por propiedad.], [checkCoherent], [Informe con P1 a P4 y primer testigo.], [El primer testigo sigue el orden de P1 a P4.],
    [RF-08], [Decidir una solicitud con las reglas que la activan.], [evaluate], [Decisión de permiso o denegación.], [Solicitud fuera de dominio produce DomainError y el estado interno de conflicto es inalcanzable vía interfaz guardada.],
    [RF-09], [Decidir varias solicitudes preservando el orden.], [evaluateMany], [Lista de decisiones.], [Sin topes por costo lineal por solicitud.],
    [RF-10], [Explicar un testigo en lenguaje natural desde TypeScript.], [explain], [Texto explicativo.], [Presenta la información del testigo sin ejecutar decisiones lógicas.],
    [RF-11], [Aplicar límites de dominio para evitar explosión combinatoria.], [Todas], [Interrupción temprana ante exceso de cotas.], [El exceso sobre MAX_REQUEST_SPACE, MAX_RULES_CHECKED o MAX_ENUM_VALUES lanza TooLarge en tiempo $O(1)$.],
  ),
  caption: [Requerimientos funcionales del verificador con su interfaz y comportamiento ante error.],
) <tab:requerimientos>

= Trabajo relacionado <sec:relacionado>

El análisis formal de políticas de acceso abarca taxonomías de anomalías, razonamiento estático con demostradores lógicos, evolución guardada de reglas, lenguajes de especificación y model checking sobre protocolos de administración.

== Taxonomía de anomalías y verificación de políticas ABAC

El análisis sistemático de anomalías en reglas de seguridad parte de los trabajos en cortafuegos de Al-Shaer y Hamed #cite(<alshaer2004taxonomy>), quienes clasificaron los defectos en conflicto, sombreado, redundancia y vacuidad. Dicha taxonomía fue adaptada a modelos de autorización basados en atributos por NIST en el estándar SP 800-192 #cite(<hu2017verification>).

En el ámbito de ABAC, diversas investigaciones estudian anomalías mediante modelos lógicos y grafos. Kolovski, Hendler y Parsia #cite(<kolovski2007analyzing>) formalizaron directivas de autorización con lógicas descriptivas y redujeron la detección de consistencia y redundancia al razonamiento ontológico. Margheri y sus colaboradores #cite(<margheri2019rigorous>) propusieron un marco formal para la especificación y análisis estático de políticas ABAC con múltiples atributos. Liu y sus coautores #cite(<liu2021novel>) desarrollaron un método de detección de conflictos basado en partición de dominios y grafos de decisión.

A diferencia de tales esquemas, el verificador presentado en este artículo formaliza cuatro propiedades de P1 a P4 mediante semántica denotacional en Dafny #cite(<leino2010dafny>). El sistema unifica la detección de inconsistencias P1, reglas insatisfacibles P2, sombreado P3 y falta de validez sintáctica P4, produciendo un testigo diagnóstico con la tupla mínima del contraejemplo.

== Razonamiento estático mediante solucionadores SMT y SAT

Los solucionadores de satisfacibilidad booleana o SAT y de satisfacibilidad módulo teorías o SMT son herramientas habituales en el análisis estático de directivas de seguridad. Hughes y Bultan #cite(<hughes2008automated>) tradujeron especificaciones de autorización a fórmulas proposicionales para verificar propiedades de seguridad y sintetizar contraejemplos con solucionadores SAT. Jayaraman y su equipo #cite(<jayaraman2011automatic>) aplicaron este enfoque a la detección de fallas y emisión de testigos en directivas empresariales con motores SMT.

En el contexto de XACML, Turkmen y sus coautores #cite(<turkmen2017formal>) definieron un marco que traduce directivas compuestas a fórmulas de lógica de primer orden resueltas con Z3 #cite(<demoura2008z3>). A nivel industrial, Amazon Web Services o AWS desarrolló el analizador Zelkova #cite(<backes2018semantic>) y el sistema Block Public Access o BPA #cite(<bouchet2020block>), los cuales transforman políticas de gestión de identidad o IAM y reglas de depósitos S3 en consultas SMT para auditar configuraciones indebidas.

Estos enfoques dependen de llamadas a solucionadores SMT en tiempo de despliegue o durante la evaluación de consultas, lo que añade latencia y posibles tiempos de espera indefinidos. En contraste, este desarrollo sigue el paradigma CbC #cite(<hall2002correctness>): los solucionadores Z3 #cite(<demoura2008z3>) y cvc5 #cite(<barbosa2022cvc5>) intervienen únicamente en tiempo de diseño para verificar las pruebas en Dafny #cite(<leino2010dafny>). El código que opera en producción es JavaScript extraído de la especificación verificada, sin herramientas de cálculo simbólico en tiempo de ejecución.

== Evolución guardada de directivas y administración de acceso

La administración dinámica de directivas introduce riesgos de regresión en las autorizaciones. Fisler y su equipo #cite(<fisler2005verification>) propusieron analizar el impacto de cambios con la herramienta Margrave comparando versiones sucesivas de una política. En administración delegada, Sasturkar, Yang y Stoller #cite(<sasturkar2011policy>) estudiaron la complejidad de los análisis de seguridad en modelos de control de acceso basados en roles administrativos o ARBAC, y Jayaraman y sus colaboradores presentaron Mohawk #cite(<jayaraman2013mohawk>) para comprobar alcanzabilidad de privilegios ante cambios administrativos.

Sin embargo, los enfoques previos efectúan análisis posteriores sobre directivas ya modificadas o exploran escenarios hipotéticos sin mecanismos que detengan en origen una transición a un estado inconsistente. La presente propuesta incorpora una interfaz de mutación guardada con las operaciones tryAdd, tryUpdate y remove, respaldada por el lema deductivo AddPreserves. Cuando una regla propuesta introduce contradicciones, reglas muertas o sombreado, el sistema rechaza la operación, conserva el estado previo y genera un testigo con la solicitud infractora.

== Lenguajes de autorización analizables y verificación guiada

El desarrollo de lenguajes de autorización verificables condujo a propuestas como Cedar #cite(<cutler2024cedar>), diseñado con desarrollo guiado por verificación #cite(<cutler2024built>). Cedar especifica su modelo formal en Lean y realiza análisis estáticos mediante reducción a SMT. En Cedar, el modelo formal y el motor de ejecución en Rust constituyen bases de código separadas, lo que requiere pruebas diferenciales aleatorias para comprobar su correspondencia, y el lenguaje no incluye guardas inductivas en la interfaz de administración para rechazar inserciones conflictivas. Por su parte, lenguajes como ALFA #cite(<oasis2015alfa>) compilan hacia XML para XACML, pero delegan el análisis en motores externos y carecen de compilación hacia entornos JavaScript. La solución descrita en este artículo extrae el código JavaScript directamente de la especificación demostrada en Dafny y restringe las condiciones a dominios discretos acotados, lo que asegura la decidibilidad del espacio AllRequests y preserva la equivalencia entre la especificación probada y el código ejecutado.

== Model checking de protocolos de administración de acceso

El model checking permite certificar que los sistemas interactivos de seguridad satisfacen propiedades temporales. Zhang, Ryan y Guelev #cite(<zhang2008synthesising>) modelaron la evolución de políticas de acceso y verificaron propiedades mediante comprobación de modelos.

En este trabajo, la deducción formal se complementa con verificación temporal en UPPAAL #cite(<larsen1997uppaal>). El autómata de estados finitos del administrador valida nueve consultas en lógica de árbol de computación temporal o TCTL. El modelo confirma que el protocolo carece de interbloqueos, que los estados transitorios comprometidos ejecutan operaciones de adición y actualización de forma atómica, y que la condición de coherencia $A[] "coherent"()$ se mantiene como invariante en todas las trayectorias de ejecución.

== Síntesis comparativa

La @tab:comparativa contrasta nuestro trabajo frente a los principales enfoques de la literatura científica e industrial, evaluando el paradigma formal empleado, la dependencia de solucionadores en ejecución, el soporte de guardas de evolución con preservación inductiva, la presencia de testigos diagnósticos mínimos y el entorno de despliegue.

#figure(
  table(
    columns: (1.15fr, 0.95fr, 0.85fr, 0.85fr, 1.1fr, 1.1fr),
    inset: (x: 3.5pt, y: 5pt),
    align: left,
    table.header([Enfoque], [Paradigma formal], [SMT en ejecución], [Guarda de evolución], [Testigo diagnóstico], [Entorno de despliegue]),
    [Análisis XACML, Turkmen #cite(<turkmen2017formal>)], [Traducción SMT], [Requerido con Z3], [No], [Modelo del solucionador], [Servicio externo],
    [Detección ABAC, Liu #cite(<liu2021novel>)], [Partición y grafos], [No], [No], [Par de reglas], [Algoritmo local],
    [Zelkova y BPA en AWS #cite(<backes2018semantic>) #cite(<bouchet2020block>)], [Reducción SMT], [Requerido con Z3], [No], [Contramodelo SMT], [Infraestructura nube],
    [Lenguaje Cedar, Cutler #cite(<cutler2024cedar>) #cite(<cutler2024built>)], [Verificación guiada en Lean], [Opcional en análisis], [No], [Diagnóstico sintáctico], [Binario Rust o WASM],
    [Mohawk para ARBAC, Jayaraman #cite(<jayaraman2013mohawk>)], [SMT y alcanzabilidad], [Requerido], [No, análisis a posteriori], [Traza de transición], [Herramienta CLI],
    [Verificador propuesto], [CbC deductivo con Dafny \ + UPPAAL TCTL], [Ninguno, compilado a JavaScript], [Sí, por lema inductivo], [Tupla mínima de solicitud y reglas], [Paquete npm para JS, Node y TS],
  ),
  caption: [Comparación sistemática del verificador propuesto frente a los enfoques de la literatura científica e industrial.],
) <tab:comparativa>

= Metodología utilizada y desarrollo <sec:metodologia>

== Enfoque metodológico

El desarrollo siguió el paradigma CbC. Bajo este principio, la especificación matemática previa, la demostración de lemas deductivos y el model checking orientan la construcción del software antes de generar código ejecutable.

El trabajo se organizó en cinco fases:

1. Fase 1: especificación y modelado del dominio. Se formalizó la sintaxis abstracta de las directivas ABAC, los tipos algebraicos y la semántica denotacional en Dafny, y se definió la función AllRequests para la enumeración cartesiana sobre secuencias de valores.
2. Fase 2: verificación deductiva en Dafny. Se especificaron las propiedades de coherencia de P1 a P4 con sus funciones de decisión ejecutables y generadores de testigos. Se demostraron siete teoremas de solidez, completitud y preservación: AddPreserves, UpdatePreserves, RemovePreservesCoherent, CheckCoherentSound, CheckCoherentComplete, WitnessSoundness y WitnessCompleteness, sustentados por cincuenta y dos lemas inductivos auxiliares que reúnen cincuenta y nueve demostraciones verificadas con los motores SMT Z3 y cvc5.
3. Fase 3: verificación temporal en UPPAAL. Para analizar la concurrencia y la interacción temporal del administrador, se construyó un autómata de estados finitos en uppaal/abac-guard.xml y se verificaron nueve consultas en TCTL relativas a ausencia de interbloqueos y preservación de coherencia.
4. Fase 4: compilación verificada y diseño de envolturas. El núcleo verificado en Dafny se compiló a JavaScript estándar, y sobre él se desarrollaron envolturas en TypeScript dedicadas a análisis sintáctico, control de límites operativos y formateo de testigos.
5. Fase 5: validación empírica y reproducibilidad. Se definieron escenarios de prueba con directivas médicas de urgencia y casos con inconsistencias inducidas, complementados con pruebas automatizadas de regresión en integración continua.

= Artefactos empleados <sec:artefactos_empleados>

Las herramientas de verificación, lenguajes de desarrollo y estándares de autorización se seleccionaron por su madurez y reproducibilidad.

Para la verificación formal se empleó Dafny versión 4 en la especificación matemática, la deducción de propiedades y la generación de código JavaScript. La resolución de obligaciones de prueba se apoyó en los motores SMT Z3 versión 4.12 o superior y cvc5 versión 1.0 o superior. La verificación de estados y concurrencia se realizó con UPPAAL versión 5.0.

En la capa anfitriona se empleó TypeScript versión 5 para el análisis sintáctico y el tipado defensivo, junto con Node.js versión 20 o superior y Bun versión 1 como entornos de ejecución y empaquetado. El análisis estático de código se configuró con Biome versión 1.9 o superior.

El modelo de autorización sigue los lineamientos de NIST SP 800-162 y toma como referencia comparativa el estándar OASIS XACML 3.0 #cite(<oasis2013xacml>). La composición tipográfica del artículo se realizó en Typst versión 0.15.1 bajo directrices de IEEE.

La @tab:artefactos_empleados resume la pila tecnológica y herramientas formales utilizadas en el núcleo y la capa anfitriona del sistema, indicando su versión, categoría y su rol específico en la arquitectura de la solución.

#figure(
  placement: auto,
  scope: "parent",
  table(
    columns: (1.2fr, 0.8fr, 1.2fr, 2.5fr),
    inset: 5pt,
    align: left,
    table.header([Herramienta / Tecnología], [Versión], [Categoría], [Rol y función en el proyecto]),
    [Dafny], [4.x], [Verificación deductiva], [Especificación matemática del modelo ABAC, prueba de 59 lemas: 7 teoremas de preservación y solidez junto a 52 lemas auxiliares, y compilación a JavaScript.],
    [Z3 y cvc5], [4.12+ / 1.0+], [Solucionadores SMT], [Resolución automatizada de metas lógicas y condiciones de verificación en Dafny.],
    [UPPAAL], [5.0], [Model checking], [Verificación temporal de estados del administrador y validación de 9 consultas TCTL.],
    [TypeScript], [5.x], [Lenguaje anfitrión], [Analizador sintáctico, barreras defensivas de tipos y envolturas del núcleo compilado.],
    [Node.js y Bun], [20+ / 1.x], [Entorno de ejecución], [Ejecución del banco de pruebas, suite de regresión y empaquetado para distribución npm.],
    [Biome], [1.9+], [Calidad y análisis estático], [Formateo estricto y detección de malas prácticas en la base de código TypeScript.],
  ),
  caption: [Pila tecnológica y herramientas formales del proyecto.],
) <tab:artefactos_empleados>

= Artefactos desarrollados <sec:artefactos_desarrollados>

El proyecto comprende módulos de verificación formal, código ejecutable y pruebas automatizadas.

== Arquitectura del sistema

El sistema se organiza en tres capas con dependencias unidireccionales, representadas en la @fig:arquitectura. La capa de núcleo contiene los módulos en Dafny dedicados a esquema, sintaxis, evaluación, coherencia y transiciones. La capa de envolturas comprende el cargador de esquema, el analizador sintáctico, los adaptadores de tipos hacia las funciones compiladas de Dafny y la interfaz de programación pública. La capa de distribución reúne el paquete de npm con sus declaraciones de tipos. La capa en TypeScript no calcula decisiones lógicas de coherencia: valida entradas, adapta estructuras y presenta los diagnósticos generados por el núcleo.

#figure(
  image("img/architecture.png", width: 60%),
  caption: [Arquitectura del verificador: el núcleo Dafny compila a JavaScript y las envolturas en TypeScript validan entradas, adaptan estructuras y formatean diagnósticos.],
) <fig:arquitectura>

La @fig:clases presenta las clases y tipos del verificador agrupados en sus dos componentes principales: el núcleo formal en Dafny y las envolturas en TypeScript.

#figure(
  image("img/classes.png", width: 100%),
  caption: [Diagrama de clases del verificador con el núcleo Dafny y las envolturas TypeScript.],
) <fig:clases>

== Núcleo formal en Dafny

El núcleo en Dafny está compuesto por seis módulos principales que reúnen cincuenta y nueve lemas deductivos demostrados:
- Schema.dfy, con diez lemas: declaraciones de familias de atributos, tipos de enumeración, booleanos y enteros acotados, condiciones de validez y lemas de corrección para enumerar el espacio cartesiano de solicitudes AllRequests.
- Syntax.dfy, con un lema: tipos algebraicos para condiciones lógicas, efectos de permiso y denegación, directivas individuales, colecciones ordenadas Ruleset y el lema de monotonía de subconjuntos ante retiro de directivas.
- Eval.dfy: semántica denotacional pura para evaluar la satisfacción de condiciones mediante Satisfies, la activación de directivas mediante Applies y la decisión sobre solicitudes mediante Evaluate.
- Coherence.dfy, con treinta y cuatro lemas: formulación matemática de las propiedades P1 a P4, algoritmos de decisión ejecutables, generación de testimonios diagnósticos Witness y lemas de solidez y completitud.
- Transition.dfy, con doce lemas: operaciones guardadas de actualización TryAdd, TryUpdate y TryRemove, junto con demostraciones de preservación invariante como AddPreserves, UpdatePreserves y RemovePreservesCoherent, además de solidez de contraejemplos.
- BoundedCheck.dfy, con dos lemas: procedimientos de comprobación exhaustiva sobre configuraciones finitas para contrastar lemas inductivos en casos sintéticos.

La base de demostraciones articula siete teoremas de solidez, completitud y preservación inductiva respaldados por cincuenta y dos lemas auxiliares. La estructura AttrDecl define cada atributo con su familia, identificador, tipo y dominio. La estructura Request define una secuencia de valores alineada con las posiciones del esquema, lo que sitúa el razonamiento en la teoría de secuencias. El recorrido sobre el espacio de solicitudes opera por índices enteros directos, lo que evita crear particiones intermedias en memoria.

La @fig:chequeos resume el proceso de comprobación de coherencia implementado en Dafny mediante `CheckCoherent`, que evalúa secuencialmente de P1 a P4 y emite el primer testigo mínimo hallado (mientras el analizador en TypeScript valida sintaxis y esquema en la frontera de entrada, y `TryUpdate` rechaza con P4 todo identificador inexistente).

#figure(
  placement: auto,
  scope: "parent",
  image("img/check_phases.png", width: 100%),
  caption: [Etapas de comprobación de coherencia en el núcleo formal Dafny: orden de ejecución de propiedades P1 a P4, funciones ejecutables, lemas deductivos, testigos diagnósticos y costo computacional.],
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

El autómata del componente de administración se especificó y validó en UPPAAL #cite(<larsen1997uppaal>) en el modelo uppaal/abac-guard.xml y el conjunto de consultas uppaal/abac-guard.q. La verificación analiza un universo acotado de dieciséis solicitudes, con $N_(r e q) = 16$, obtenidas de dos roles, una unidad, una acreditación, un recurso, una sensibilidad, dos acciones, dos bandas horarias y dos estados de emergencia, donde $2 times 1 times 1 times 1 times 1 times 2 times 2 times 2 = 16$. El modelo evalúa diez directivas candidatas y hasta tres directivas activas a la vez.

Esta comprobación temporal complementa la verificación deductiva de Dafny. Mientras Dafny asegura la preservación de coherencia para reglas de tamaño arbitrario, UPPAAL certifica la progresión del protocolo, la atomicidad en los estados transitorios comprometidos y la ausencia de interbloqueos en el autómata del administrador.

#figure(
  image("img/model_diagram.png", width: 90%),
  caption: [Autómata Admin modelado en UPPAAL en uppaal/abac-guard.xml.],
) <fig:transicion>

Como indica la @fig:transicion, las ubicaciones Empty y Coherent modelan configuraciones consistentes confirmadas, mientras que TryingAddE, TryingAddC y TryingUpdC son estados comprometidos que aseguran transiciones atómicas.

Las nueve consultas formuladas en TCTL se dividen en propiedades de seguridad y de alcanzabilidad, expuestas en la @tab:consultas.

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
  caption: [Panel del verificador de UPPAAL con las nueve consultas satisfechas.],
) <fig:verificador>

== Biblioteca y envolturas en TypeScript

La capa en TypeScript define los puntos de acceso y las validaciones de entrada:
- schema.ts: comprueba las declaraciones de atributos, calcula la cardinalidad cartesiana y ofrece constructores seguros.
- parser.ts: analiza las expresiones de condición y directivas ABAC, desazucara operadores de conveniencia convirtiendo in en disyunciones y between en conjunciones acotadas, y valida identificadores y literales frente al esquema cargado.
- wrappers.ts: coordina la comunicación con el motor compilado de Dafny y expone las funciones tryAdd, tryUpdate, remove, checkCoherent y evaluate.
- explain.ts: traduce la estructura del testigo formal a mensajes diagnósticos legibles.
- batch.ts: gestiona la evaluación y adición de directivas por lotes con semántica atómica.
- errors.ts: define excepciones estructuradas para errores de esquema, sintaxis, valores fuera de rango y superación de límites de dominio mediante la excepción TooLarge.

Dado que el analizador opera en el lenguaje anfitrión fuera del núcleo formal probado, su correspondencia con el AST de Dafny se comprueba mediante pruebas de estructura de árbol, precedencia de operadores y análisis de ida y vuelta en test/parser.test.ts.

== Banco de pruebas, casos de estudio y suite de regresión

Se estructuraron escenarios representativos en formato JSON:
- clean.json: directivas válidas y coherentes sobre el esquema clínico schema-v1.json.
- contradictory.json: conflicto por superposición entre permiso y denegación para una misma solicitud, correspondiente a una violación P1.
- unsatisfiable.json: directiva con predicados contradictorios sobre rangos enteros, correspondiente a una violación P2.
- shadowed.json: directiva redundante cubierta por directivas previas, correspondiente a una violación P3.
- emergency-override.json: escenario clínico donde una excepción de urgencia médica colisiona con una restricción fuera de horario regular, provocando un rechazo P1 con testigo concreto (en contraste con clean.json, donde la excepción se acota para preservar coherencia).

La suite de pruebas automatizadas, compuesta por test/parser.test.ts, test/wrappers.test.ts y test/replay.test.ts, comprueba el rechazo ante entradas malformadas, valida el desazucarado del analizador y confirma la reproducción exacta de los testigos generados.

== Resumen consolidador de artefactos desarrollados

La @tab:artefactos_desarrollados reúne los artefactos desarrollados en el proyecto, detallando su ubicación relativa, lenguaje utilizado, tamaño y contribución técnica.

#figure(
  placement: auto,
  scope: "parent",
  table(
    columns: (1.2fr, 1.2fr, 0.8fr, 1.3fr, 2.4fr),
    inset: 5pt,
    align: left,
    table.header([Artefacto desarrollado], [Ruta / Módulo], [Lenguaje], [Métricas], [Contribución técnica principal]),
    [Núcleo formal Dafny], [dafny/], [Dafny], [6 módulos, ~48 KB, 59 lemas], [Especificación ejecutable, semántica ABAC, 4 propiedades de coherencia y 7 teoremas con 52 lemas auxiliares probados.],
    [Modelo de estados UPPAAL], [uppaal/abac-guard.xml], [XML / UPPAAL], [1 autómata, 16 reqs, 10 reglas, 23 estados, 529 transiciones], [Model checking acotado de transiciones del componente Admin, libre de interbloqueos.],
    [Consultas formales TCTL], [uppaal/abac-guard.q], [TCTL], [9 consultas verificadas], [Comprobación matemática de seguridad y alcanzabilidad de veredictos.],
    [Analizador sintáctico], [src/parser.ts], [TypeScript], [9.6 KB], [Analizador estricto con desazucarado de operadores in y between y validación contra el esquema.],
    [Envolturas y adaptadores], [src/wrappers.ts, schema.ts], [TypeScript], [19.7 KB], [Capa defensiva y frontera segura con el motor JavaScript compilado desde Dafny.],
    [Generador de explicaciones], [src/explain.ts], [TypeScript], [0.9 KB], [Traducción legible de testigos formales hacia explicaciones diagnósticas para administradores.],
  ),
  caption: [Catálogo consolidado de artefactos desarrollados por el proyecto.],
) <tab:artefactos_desarrollados>

= Discusión, limitaciones y amenazas a la validez <sec:discusion>

El diseño del verificador conjuga el rigor deductivo de CbC con las restricciones operativas de la evaluación determinista sin motores simbólicos en ejecución.

== Limitaciones intrínsecas del espacio cartesiano

La principal restricción temporal reside en la enumeración explícita del espacio cartesiano de solicitudes, expresado en la @eq:allrequests como $|"AllRequests"| = product_(i=1)^(k) |D_i|$. La comprobación exhaustiva previene falsos positivos y asegura que ante cualquier rechazo exista un contraejemplo reproducible.

Sin embargo, esta garantía conlleva un costo temporal de $O(|"AllRequests"| dot |R|)$ para consistencia P1 y satisfacibilidad P2, y de $O(|"AllRequests"| dot |R|^2)$ para la detección de sombreado P3. En esquemas de tamaño moderado, como el caso clínico de evaluación con ocho atributos y 64800 solicitudes en total, el proceso toma algunos segundos en JavaScript. Esta progresión geométrica frente al número de atributos $k$ limita la enumeración directa a políticas con dominios acotados.

Para proteger la disponibilidad del entorno de ejecución, el sistema aplica una comprobación defensiva conforme a RF-11: al cargar el esquema o procesar lotes se evalúan los topes de diseño, fijados en un millón de solicitudes en el espacio cartesiano, sesenta y cuatro directivas comprobadas y dieciséis valores por enumeración. Si una política rebasa estos límites, la biblioteca produce en tiempo $O(1)$ la excepción tipada TooLarge, lo que interrumpe el procesamiento antes de incurrir en recorridos combinatorios prolongados.

== Amenazas a la validez interna

La principal amenaza a la validez interna se ubica en la frontera entre el lenguaje anfitrión TypeScript y el núcleo verificado en Dafny. El analizador en src/parser.ts desazucara listas in hacia disyunciones || y rangos between hacia conjunciones acotadas &&. Al ejecutarse en TypeScript, esta transformación carece de demostración interactiva en Dafny.

Esta amenaza se mitiga mediante tres mecanismos: primero, validación de tipos y rangos de literales antes de generar los nodos del árbol; segundo, correspondencia directa con los tipos algebraicos And, Or y Atom de Dafny; y tercero, cobertura de pruebas de regresión sintáctica y de ida y vuelta en test/parser.test.ts para evitar que directivas malformadas alcancen el núcleo de decisión.

== Amenazas a la validez de constructo

Respecto a la validez de constructo, el modelo ABAC evalúa predicados atómicos frente a constantes literales fijadas en el esquema, por ejemplo subject.role == medic, y descarta comparaciones dinámicas entre múltiples atributos de una misma solicitud, como exigir que subject.clearance sea mayor o igual a resource.sensitivity.

Esta delimitación responde a una decisión de diseño: permitir comparaciones generales entre variables transformaría el problema en lógica de primer orden, cuya resolución requeriría motores SMT como Z3 durante la ejecución, con riesgo de indeterminación, tiempos de espera indefinidos y agotamiento de memoria. Al restringir las reglas a comparaciones literales sobre dominios finitos, el sistema asegura la decidibilidad y la obtención determinista de testigos.

== Amenazas a la validez externa

En cuanto a la validez externa, el sistema se orienta a entornos donde las políticas se definen sobre esquemas discretos bien tipados, tales como pasarelas de microservicios, sistemas hospitalarios o registros académicos. El enfoque no es directamente aplicable a sistemas que empleen atributos continuos de punto flotante o texto libre sin discretización previa.

Asimismo, el análisis en UPPAAL se realizó sobre una configuración acotada de 16 solicitudes y 10 directivas. Aunque esta verificación certifica la ausencia de interbloqueos y la atomicidad del protocolo en dicha topología, escenarios concurrentes con múltiples administradores distribuidos en disputa por modificaciones requerirían protocolos externos de consenso transaccional.

= Conclusiones y trabajo futuro <sec:conclusiones>

== Conclusiones

Este artículo presentó el diseño, la verificación y la implementación de un verificador de coherencia para políticas ABAC desarrollado bajo el paradigma CbC. El sistema evalúa cuatro propiedades de coherencia de P1 a P4, genera testigos diagnósticos mínimos ante cada violación y asegura mediante lemas inductivos en Dafny que toda mutación guardada preserva la coherencia del estado.

La solución combina dos métodos formales complementarios: Dafny permitió demostrar cincuenta y nueve lemas deductivos de solidez, completitud y preservación de invariantes, y UPPAAL certificó la ausencia de interbloqueos y la atomicidad del protocolo administrativo mediante nueve consultas en TCTL. La compilación del núcleo desde Dafny a JavaScript estándar facilitó su distribución como paquete en npm bajo el nombre \@grupo1/abac-verifier con envolturas en TypeScript, sin requerir solucionadores SMT en tiempo de ejecución.

== Trabajo futuro

A partir de las limitaciones identificadas, se proyectan tres líneas de desarrollo futuro:

1. Representación simbólica mediante diagramas de decisión binaria o BDD y diagramas de decisión suprimidos por ceros o ZDD: reemplazar la enumeración cartesiana explícita por estructuras canónicas de decisión, lo que permitiría comprimir el espacio de estados y analizar esquemas de mayor dimensionalidad conservando la extracción de código verificado.
2. Verificación incremental localizada: demostrar lemas inductivos que acoten la comprobación de coherencia al subespacio de solicitudes afectado por la directiva modificada o añadida, lo que evitará reevaluar el espacio global y reducirá el costo temporal ante cambios aislados.
3. Protocolos de autorización distribuida para PDP concurrentes: extender el modelo en UPPAAL hacia arquitecturas con múltiples puntos de decisión distribuidos, incorporando modelos de consistencia eventual y sincronización frente a fallas parciales de red.

= Disponibilidad de datos y código <sec:datos>

El código fuente completo, las especificaciones en Dafny, los modelos y consultas de UPPAAL, la suite de pruebas automatizadas y este documento se encuentran disponibles bajo licencia de código abierto en el repositorio público https://github.com/microuni-unsa/afve-teo-turno-c-grupo-1-final/.
