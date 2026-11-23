#import "ieee.typ": ieee

#show: ieee.with(
  title: [Verificación formal de coherencia en políticas ABAC: un enfoque de corrección por construcción en Dafny y model checking en UPPAAL],
  abstract: [
    El control de acceso basado en atributos o ABAC permite formular directivas expresivas, aunque su edición manual suele introducir contradicciones entre permisos y denegaciones, reglas insatisfacibles, sombreado de directivas o errores de esquema. Este artículo presenta un verificador de coherencia cuyo núcleo de decisión está especificado y demostrado formalmente en Dafny, y compilado a JavaScript como biblioteca ejecutable sin motores SMT en tiempo de ejecución. El verificador comprueba cuatro propiedades formales de coherencia: consistencia (P1), satisfacibilidad (P2), ausencia de sombreado (P3) y validez de esquema (P4), emitiendo un testigo concreto ante cada infracción. Mediante lemas inductivos de preservación, las operaciones guardadas garantizan por construcción que todo conjunto confirmado permanece coherente. De forma complementaria, el autómata de transición del administrador se valida en UPPAAL sobre un caso fijo acotado de dieciséis solicitudes y diez reglas, confirmando la ausencia de interbloqueos y satisfaciendo nueve propiedades en lógica TCTL. Por último, se presenta una evaluación guiada paso a paso sobre un escenario clínico de emergencia y su remediación coherente.
  ],
  index-terms: (
    "control de acceso basado en atributos",
    "métodos formales",
    "Dafny",
    "UPPAAL",
    "lógica temporal",
    "coherencia de políticas",
    "verificación de software",
    "corrección por construcción",
    "verificación deductiva",
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

El control de acceso determina qué operaciones puede ejecutar un sujeto sobre un recurso y bajo qué contexto. A diferencia de los esquemas rígidos basados únicamente en roles, el control de acceso basado en atributos o ABAC (estandarizado en NIST SP 800-162 #cite(<hu2014guide>) y sujeto a lineamientos de verificación en NIST SP 800-192 #cite(<hu2017verification>)) expresa cada autorización evaluando propiedades de cuatro familias: sujeto (rol, departamento, nivel de autorización), recurso (tipo, sensibilidad), acción (lectura o escritura) y entorno (hora, estado de emergencia). Así, una directiva clínica puede autorizar la lectura de historias médicas de sensibilidad moderada al personal médico acreditado mediante una condición como `subject.role == medic && subject.clearance >= 4 && resource.type == record && resource.sensitivity <= 3 && action.name == read`.

Sin embargo, en hospitales, universidades y entidades públicas las directivas cambian con frecuencia por rotación de guardias, convenios y protocolos de urgencia. Cuando los administradores editan listas de reglas a mano sin respaldo formal, introducen anomalías silenciosas difíciles de detectar a simple vista. Por ejemplo, una regla que autoriza cualquier acceso durante una emergencia (`environment.emergency == true`) entra en conflicto con una salvaguarda nocturna que deniega operaciones desde las 18:00 (`environment.hour >= 18`) en cuanto coincide una urgencia vespertina. En otros casos, un ajuste erróneo de umbrales (`subject.clearance > 5 && subject.clearance < 2`) produce reglas muertas que jamás se activan, o una directiva específica por departamento (`subject.role == medic && subject.dept == cardio`) queda completamente sombreada por una regla general previa (`subject.role == medic`).

Este trabajo aborda dos metas formales complementarias. En primer lugar, decide de forma exacta la coherencia de un conjunto de reglas ABAC y entrega ante cada infracción un testigo mínimo con la solicitud conflictiva, las directivas implicadas y la propiedad vulnerada. En segundo lugar, garantiza mediante demostración deductiva que cada operación de evolución guardada preserva la coherencia del conjunto, impidiendo toda transición hacia estados inválidos. El núcleo de decisión se especifica y verifica en Dafny #cite(<leino2010dafny>), se valida dinámicamente sobre un caso acotado en UPPAAL #cite(<larsen1997uppaal>) y se compila a JavaScript para su ejecución directa sin motores SMT en producción.

El resto del documento se distribuye como sigue: la @sec:problema introduce el modelo ABAC con ejemplos concretos y define el problema formal; la @sec:justificacion y la @sec:objetivos detallan la justificación y metas del proyecto; la @sec:alcance delimita el fragmento decidible y los requerimientos funcionales; la @sec:relacionado analiza el trabajo previo; la @sec:metodologia y la @sec:artefactos_empleados exponen el método y las herramientas formales adoptadas; la @sec:artefactos_desarrollados documenta el núcleo en Dafny, el model checking en UPPAAL, la frontera de ejecución y una evaluación guiada sobre un caso clínico; la @sec:discusion analiza limitaciones y amenazas a la validez; la @sec:conclusiones resume las conclusiones y trabajo futuro, y la @sec:datos detalla la disponibilidad de artefactos.

= Definición del problema <sec:problema>

Para comprender las fallas que motivan el verificador, considérese un esquema clínico (`schema-v1`) con ocho atributos declarados: tres de sujeto (`role` en `{medic, nurse, admin}`, `dept` en `{cardio, radio, er}` y `clearance` en `[1..5]`), dos de recurso (`type` en `{record, lab, prescription}` y `sensitivity` en `[1..5]`), uno de acción (`name` en `{read, write}`) y dos de entorno (`hour` en `[0..23]` y `emergency` booleano). Una solicitud concreta $q$ asigna un valor válido a cada atributo, por ejemplo `(medic, er, 3, record, 4, read, 22, true)`, y una política $R$ consiste en una secuencia de directivas de la forma `Permit where <condición>` o `Deny where <condición>`.

Al ampliar o editar $R$ manualmente aparecen tres anomalías lógicas y una falla sintáctica que nuestro modelo formaliza como cuatro propiedades de coherencia:

1. *P1 — Consistencia (ausencia de contradicción):* ninguna solicitud válida activa simultáneamente una regla `Permit` y una regla `Deny`. Ejemplo: `Permit where environment.emergency == true` frente a `Deny where environment.hour >= 18` colisionan ante cualquier solicitud con `hour = 22` y `emergency = true`.
2. *P2 — Satisfacibilidad (ausencia de reglas muertas):* toda directiva en $R$ se activa para al menos una solicitud válida. Ejemplo: `Permit where subject.clearance > 5 && subject.clearance < 2` nunca dispara dentro del rango `[1..5]` y crea una falsa sensación de cobertura.
3. *P3 — No sombreado (ausencia de reglas nulas):* toda directiva decide en solitario al menos una solicitud válida. Ejemplo: añadir `Permit where subject.role == medic && subject.dept == cardio` cuando ya existe `Permit where subject.role == medic` hace que la regla específica nunca ejerza un efecto propio; los duplicados exactos también violan P3.
4. *P4 — Validez de esquema:* toda directiva emplea únicamente atributos declarados, operadores compatibles con el tipo del atributo y literales dentro de su dominio.

Un conjunto de reglas $R$ es coherente (`Coherent(R)`) si y solo si satisface conjuntamente P1, P2, P3 y P4. Además, en la evolución del sistema el criterio de éxito exige la invariante de tesis: todo conjunto de directivas alcanzable a través de la interfaz guardada es coherente.

El universo de solicitudes del modelo es discreto y finito. Cada solicitud asigna valores válidos a los $k$ atributos del esquema, de modo que la cardinalidad del espacio total `AllRequests` equivale al producto cartesiano de los dominios declarados:

$ |"AllRequests"| = product_(i=1)^(k) |D_i| $ <eq:allrequests>

donde $|D_i|$ denota la cardinalidad del dominio del atributo $i$. En el esquema clínico descrito, $|"AllRequests"| = 3 times 3 times 5 times 3 times 5 times 2 times 24 times 2 = 64\,800$ solicitudes posibles. Sobre este universo finito, comprobar consistencia P1 y satisfacibilidad P2 toma un tiempo $O(|R| dot |"AllRequests"|)$, mientras que detectar sombreado P3 requiere $O(|R|^2 dot |"AllRequests"|)$, donde $|R|$ es el número de reglas. Al excluir comparaciones abiertas entre atributos y aritmética no acotada, la @eq:allrequests garantiza la decidibilidad completa del análisis y permite sintetizar siempre un contraejemplo mínimo ante cualquier violación.

= Justificación del proyecto <sec:justificacion>

La necesidad del proyecto abarca factores teóricos, operativos y tecnológicos.

En el aspecto teórico, las pruebas por muestreo o cobertura de código resultan insuficientes para certificar directivas de autorización. El espacio de solicitudes crece exponencialmente con los dominios de atributos, de modo que las pruebas empíricas dejan combinaciones sin revisar. Asimismo, los análisis estáticos previos suelen evaluar políticas estáticas y aisladas #cite(<turkmen2017formal>), sin considerar la evolución de las reglas a lo largo del tiempo. Modelar el problema en un entorno de verificación deductiva permite probar lemas de solidez, completitud y preservación sobre todas las combinaciones del esquema.

En el aspecto operativo, las organizaciones con alta rotación modifican sus directivas con frecuencia. Si la gestión se realiza sobre archivos JSON o YAML sin validación formal, las inconsistencias no detectadas derivan en fallas de acceso. Un conflicto puede conceder accesos indebidos a datos clínicos o impedir el paso a personal médico en una guardia de emergencia. Disponer de un testigo mínimo que indique la solicitud conflictiva y las reglas implicadas facilita la corrección sin revisiones manuales prolongadas.

En el aspecto metodológico, el uso de métodos formales en aplicaciones web suele complicarse por la integración de motores de deducción externa. Mantener un demostrador lógico como servicio independiente añade latencia y puntos de fallo en producción. Este trabajo sigue el principio de corrección por construcción o CbC #cite(<hall2002correctness>): el núcleo formal se verifica en Dafny y compila directamente a JavaScript estándar detrás de una frontera mínima de validación de entrada. Así, el sistema entrega garantías formales sin requerir motores simbólicos en el entorno de ejecución.

= Objetivos del proyecto <sec:objetivos>

El objetivo general consiste en diseñar, verificar formalmente e implementar un verificador de coherencia para políticas ABAC que garantice la preservación de coherencia por construcción mediante demostración deductiva en Dafny y validación de estados en UPPAAL, compilado a JavaScript para su ejecución sin solucionadores SMT en producción.

Los objetivos específicos comprenden:

1. Formalización y semántica: definir en Dafny la sintaxis abstracta de reglas `Permit` y `Deny` sobre atributos de sujeto, recurso, acción y entorno con conectivos booleanos y comparaciones sobre rangos enteros acotados, junto con su semántica de evaluación y las propiedades P1 a P4.
2. Invariante de evolución y testigos: construir una interfaz de transición guardada (`TryAdd`, `TryUpdate`, `TryRemove`) y probar mediante lemas inductivos la preservación de `Coherent`, la inalcanzabilidad de decisiones conflictivas y la solidez y completitud de los testigos diagnósticos ante cada rechazo.
3. Validación de protocolos mediante model checking: modelar el autómata finito de administración en UPPAAL sobre un universo concreto acotado y comprobar mediante consultas TCTL la ausencia de interbloqueos, la invariancia de coherencia y la alcanzabilidad de las rutas de aceptación y rechazo.
4. Extracción ejecutable con frontera mínima: compilar el núcleo demostrado en Dafny hacia JavaScript estándar y disponer de una frontera ligera de entrada encargada exclusivamente de analizar reglas y validar dominios sin reimplementar decisiones lógicas.

= Alcance del proyecto <sec:alcance>

== Alcance funcional

El proyecto abarca el ciclo completo de especificación formal, demostración deductiva, verificación de modelos y extracción ejecutable del decisor:

1. Formalización de la sintaxis y semántica ABAC para atributos de enumeración, booleanos y enteros acotados en las cuatro familias de NIST SP 800-162 #cite(<hu2014guide>): sujeto, recurso, acción y entorno.
2. Verificación exacta de las cuatro propiedades de coherencia (P1 a P4) con emisión determinista del primer testigo mínimo infractor.
3. Interfaz de evolución guardada con operaciones individuales (`TryAdd`, `TryUpdate`, `TryRemove`) y adición por lotes con semántica de todo o nada (`tryAddMany`), conservando el conjunto inalterado ante rechazos.
4. Evaluación determinista de solicitudes (`Evaluate` y `evaluateMany`) en tiempo lineal respecto al número de reglas, con garantía formal de ausencia de conflictos sobre conjuntos confirmados.
5. Extracción del núcleo verificado hacia JavaScript ejecutable (`@grupo1/abac-verifier`) para validación sobre escenarios clínicos reales y casos de violación controlada.

== Delimitación del fragmento decidible

Para preservar la decidibilidad exacta, la síntesis constructiva de contraejemplos y la completitud de los lemas sobre dominios finitos, el lenguaje formal se restringe deliberadamente a predicados booleanos de atributo contra literal sobre esquemas cerrados. En consecuencia, quedan fuera del alcance las consultas en tiempo real a puntos de información externos (PIP), las expresiones abiertas de lógica de primer orden (cadenas libres, expresiones regulares o comparaciones dinámicas entre dos atributos de una misma solicitud), las estrategias laxas de resolución de conflictos (donde todo solapamiento permiso-denegación se reporta como error P1), así como la infraestructura de red (PEP/PDP distribuidos) y la persistencia histórica.

Asimismo, el analizador en la frontera valida tipos y dominios antes de invocar al núcleo compilado, traduciendo operadores abreviados (`in` y `between`) a árboles canónicos `Or` y `And`. Las cotas de protección frente a explosión combinatoria (`MAX_ENUM_VALUES`, `MAX_RULES_CHECKED` y `MAX_REQUEST_SPACE`) y los trade-offs de la enumeración cartesiana se detallan en la @sec:discusion.

La @tab:requerimientos resume los requerimientos funcionales del sistema, indicando su interfaz, salida esperada y comportamiento ante error.

#figure(
  placement: auto,
  scope: "parent",
  table(
    columns: (0.9fr, 1.4fr, 1fr, 1.1fr, 1.4fr),
    inset: (x: 4pt, y: 5pt),
    align: left,
    table.header([ID], [Descripción], [Interfaz], [Salida], [Comportamiento ante error]),
    [RF-01], [Cargar un esquema de atributos con familia, nombre, tipo y dominio.], [loadSchema], [Esquema validado.], [Esquema malformado o duplicado produce SchemaError.],
    [RF-02], [Analizar una regla con desazucarado sintáctico de in y between y validación contra el esquema.], [parseRule], [Regla válida.], [Sintaxis, atributo o literal fuera de dominio producen ParseError en la frontera.],
    [RF-03], [Añadir una regla solo si el conjunto extendido es coherente.], [tryAdd], [Conjunto aceptado o rechazo con testigo.], [El rechazo deja el conjunto de entrada inalterado.],
    [RF-04], [Actualizar la regla con un identificador existente bajo la misma guarda.], [tryUpdate], [Conjunto aceptado o rechazo con testigo.], [Identificador desconocido produce rechazo P4 y el conjunto queda inalterado.],
    [RF-05], [Eliminar una regla por identificador.], [remove], [Conjunto reducido.], [La eliminación preserva coherencia por monotonía de subconjunto.],
    [RF-06], [Añadir varias reglas en lote con semántica de todo o nada y en orden.], [tryAddMany], [Conjunto aceptado o primer rechazo.], [El primer rechazo aborta y devuelve el conjunto original.],
    [RF-07], [Informar la coherencia con desglose independiente por propiedad.], [checkCoherent], [Informe con P1 a P4 y primer testigo.], [El primer testigo sigue el orden de P1 a P4.],
    [RF-08], [Decidir una solicitud con las reglas que la activan.], [evaluate], [Decisión de permiso o denegación.], [Solicitud fuera de dominio produce DomainError; el estado interno Conflict es inalcanzable vía interfaz guardada.],
    [RF-09], [Decidir varias solicitudes preservando el orden.], [evaluateMany], [Lista de decisiones.], [Costo lineal por solicitud sin enumerar AllRequests.],
    [RF-10], [Formatear un testigo formal como explicación legible.], [explain], [Texto explicativo.], [Presenta el testigo sin ejecutar decisiones lógicas.],
    [RF-11], [Aplicar cotas de seguridad frente a explosión combinatoria.], [Todas], [Interrupción temprana ante exceso de cotas.], [El exceso sobre MAX_REQUEST_SPACE, MAX_RULES_CHECKED o MAX_ENUM_VALUES lanza TooLarge en tiempo $O(1)$.],
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

El model checking permite verificar de forma exhaustiva que los sistemas basados en estados finitos satisfacen propiedades de seguridad y alcanzabilidad. Zhang, Ryan y Guelev #cite(<zhang2008synthesising>) modelaron la evolución de políticas de acceso y verificaron propiedades mediante comprobación de modelos.

En este trabajo, la deducción formal en Dafny se complementa con verificación exhaustiva de estados en UPPAAL #cite(<larsen1997uppaal>). El autómata finito del administrador valida nueve propiedades en lógica de árbol de computación temporal (TCTL) sobre una instancia concreta de dieciséis solicitudes y diez directivas candidatas, confirmando ausencia de interbloqueos, atomicidad en estados transitorios comprometidos e invariancia de coherencia $A[] "coherent"()$ en toda trayectoria alcanzable.

== Síntesis comparativa

La @tab:comparativa contrasta nuestro trabajo frente a los principales enfoques de la literatura científica e industrial, evaluando el paradigma formal empleado, la dependencia de solucionadores en ejecución, el soporte de guardas de evolución con preservación inductiva, la presencia de testigos diagnósticos mínimos y el entorno de ejecución.

#figure(
  placement: auto,
  scope: "parent",
  table(
    columns: (1.15fr, 0.95fr, 0.85fr, 0.85fr, 1.1fr, 1.1fr),
    inset: (x: 4pt, y: 5pt),
    align: left,
    table.header([Enfoque], [Paradigma formal], [SMT en ejecución], [Guarda de evolución], [Testigo diagnóstico], [Entorno de ejecución]),
    [Análisis XACML, Turkmen #cite(<turkmen2017formal>)], [Traducción SMT], [Requerido con Z3], [No], [Modelo del solucionador], [Servicio externo],
    [Detección ABAC, Liu #cite(<liu2021novel>)], [Partición y grafos], [No], [No], [Par de reglas], [Algoritmo local],
    [Zelkova y BPA en AWS #cite(<backes2018semantic>) #cite(<bouchet2020block>)], [Reducción SMT], [Requerido con Z3], [No], [Contramodelo SMT], [Infraestructura nube],
    [Lenguaje Cedar, Cutler #cite(<cutler2024cedar>) #cite(<cutler2024built>)], [Verificación guiada en Lean], [Opcional en análisis], [No], [Diagnóstico sintáctico], [Binario Rust o WASM],
    [Mohawk para ARBAC, Jayaraman #cite(<jayaraman2013mohawk>)], [SMT y alcanzabilidad], [Requerido], [No, análisis a posteriori], [Traza de transición], [Herramienta CLI],
    [Verificador propuesto], [CbC deductivo con Dafny \ + UPPAAL TCTL], [Ninguno, compilado a JavaScript], [Sí, por lema inductivo], [Tupla mínima de solicitud y reglas], [Núcleo JS extraído + frontera ligera],
  ),
  caption: [Comparación sistemática del verificador propuesto frente a los enfoques de la literatura científica e industrial.],
) <tab:comparativa>

= Metodología utilizada y desarrollo <sec:metodologia>

== Enfoque metodológico

El desarrollo siguió el paradigma CbC. Bajo este principio, la especificación matemática previa, la demostración de lemas deductivos y el model checking orientan la construcción del software antes de extraer el código ejecutable.

El trabajo se organizó en cinco fases:

1. Fase 1: especificación y modelado del dominio. Se formalizó la sintaxis abstracta de las directivas ABAC, los tipos algebraicos y la semántica denotacional en Dafny, junto con la enumeración cartesiana constructiva `AllRequests`.
2. Fase 2: verificación deductiva en Dafny. Se especificaron las propiedades P1 a P4 con sus chequeos ejecutables y generadores de testigos. Se demostraron siete teoremas centrales de solidez, completitud y preservación (`EmptyCoherent`, `AddPreserves`, `UpdatePreserves`, `RemovePreservesCoherent`, `EvaluateAgreesOnCoherent`, `WitnessSoundness` y `WitnessCompleteness`) junto con los lemas de comprobación acotada en `BoundedCheck`, reuniendo ciento catorce obligaciones verificadas sin errores con Z3 y cvc5.
3. Fase 3: model checking sobre caso fijo en UPPAAL. Para validar exhaustivamente las transiciones del protocolo administrativo sobre una instancia concreta, se modeló el autómata finito `Admin` en `uppaal/abac-guard.xml` y se comprobaron nueve propiedades en TCTL relativas a ausencia de interbloqueos, invariancia de coherencia y alcanzabilidad de veredictos.
4. Fase 4: extracción verificada y frontera mínima. Los cinco módulos operacionales en Dafny se compilaron directamente a JavaScript estándar, rodeados por una frontera ligera encargada exclusivamente de analizar reglas, comprobar cotas de dominio y formatear testigos sin duplicar decisiones lógicas.
5. Fase 5: evaluación guiada y conformidad de frontera. Se trazó paso a paso la evolución de escenarios clínicos reales sobre `schema-v1.json`, complementada con pruebas automatizadas de regresión para confirmar que el artefacto compilado reproduce los testigos deducidos en la frontera de entrada.

= Artefactos empleados <sec:artefactos_empleados>

Las herramientas de verificación y estándares de autorización se seleccionaron por su rigor deductivo, capacidad de comprobación exhaustiva y reproducibilidad.

Para la verificación deductiva se empleó Dafny versión 4 en la especificación matemática, la demostración de propiedades y la síntesis de código JavaScript. La descarga de obligaciones lógicas se apoyó en los motores SMT Z3 versión 4.12 o superior y cvc5 versión 1.0 o superior. La comprobación exhaustiva de estados del autómata administrativo se realizó con UPPAAL versión 5.0.

El modelo de autorización sigue los lineamientos de NIST SP 800-162 y NIST SP 800-192, y toma como referencia comparativa el estándar OASIS XACML 3.0 #cite(<oasis2013xacml>). Como entorno anfitrión auxiliar para el analizador sintáctico y la ejecución del núcleo compilado se emplearon TypeScript versión 5 junto con Node.js 20+ y Bun 1.x. La composición tipográfica del artículo se realizó en Typst versión 0.15.1 bajo directrices IEEE.

La @tab:artefactos_empleados resume las herramientas formales, estándares y componentes auxiliares del proyecto.

#figure(
  placement: auto,
  scope: "parent",
  table(
    columns: (1.2fr, 0.8fr, 1.2fr, 2.5fr),
    inset: 5pt,
    align: left,
    table.header([Herramienta / Estándar], [Versión], [Categoría], [Rol y función en el proyecto]),
    [Dafny], [4.11], [Verificación deductiva], [Especificación formal ABAC, demostración de 114 obligaciones verificadas en 59 lemas y compilación directa a JavaScript.],
    [Z3 y cvc5], [4.12+ / 1.0+], [Solucionadores SMT], [Resolución en tiempo de diseño de las condiciones de verificación generadas por Dafny.],
    [UPPAAL], [5.0], [Model checking], [Exploración exhaustiva del autómata Admin sobre caso fijo y validación de 9 consultas TCTL.],
    [NIST SP 800-162 / 192 y XACML 3.0], [2014 / 2017 / 2013], [Estándares ABAC], [Marco de familias de atributos, taxonomía de anomalías y referencia comparativa de políticas.],
    [Entorno anfitrión (TS / Node / Bun)], [5.x / 20+ / 1.x], [Frontera de ejecución], [Análisis sintáctico de reglas en entrada, ejecución del módulo JS compilado y pruebas de regresión sobre testigos.],
  ),
  caption: [Herramientas formales, estándares y entorno auxiliar empleados en el proyecto.],
) <tab:artefactos_empleados>

= Artefactos desarrollados <sec:artefactos_desarrollados>

El proyecto articula un núcleo formal verificado en Dafny, un autómata de transición comprobado en UPPAAL, una frontera mínima de ejecución y una evaluación guiada sobre escenarios clínicos.

== Arquitectura del sistema

El sistema se organiza en tres capas con dependencias unidireccionales (@fig:arquitectura). La capa de núcleo reúne los cinco módulos operacionales en Dafny (`Schema`, `Syntax`, `Eval`, `Coherence` y `Transition`) compilados a JavaScript, además del módulo de verificación finita `BoundedCheck` exclusivo de tiempo de prueba. La capa anfitriona agrupa el cargador de esquema, el analizador sintáctico y los adaptadores hacia el módulo compilado. Esta frontera nunca reimplementa decisiones lógicas: únicamente valida entradas y presenta los testigos devueltos por Dafny.

#figure(
  image("img/architecture.png", width: 60%),
  caption: [Arquitectura del verificador: los módulos operacionales en Dafny compilan a JavaScript y la frontera anfitriona valida entradas, adapta estructuras y formatea diagnósticos.],
) <fig:arquitectura>

La @fig:clases detalla los tipos algebraicos formales del núcleo en Dafny (`AttrDecl`, `Value`, `Pred`, `Rule`, `Witness`, `AddResult` y `Decision`) junto con la interfaz pública expuesta al entorno anfitrión.

#figure(
  image("img/classes.png", width: 100%),
  caption: [Diagrama de tipos del núcleo formal en Dafny y su interfaz hacia la frontera anfitriona.],
) <fig:clases>

== Núcleo formal en Dafny

El núcleo en Dafny comprende seis módulos con cincuenta y nueve lemas que descargan ciento catorce obligaciones de verificación sin errores:
- `Schema.dfy` (10 lemas): declaraciones de familias y dominios, predicados `ValidDecl`, `SchemaWellFormed`, `ValidRequest` y demostraciones de solidez (`AllRequestsSound`) y completitud (`AllRequestsComplete`) para la enumeración cartesiana `AllRequests`.
- `Syntax.dfy` (1 lema): tipos algebraicos `Effect`, `Pred`, `Rule`, `Ruleset`, validación estructural `ValidRule` y el lema `RemoveByIdSubset` de monotonía de subconjuntos ante eliminaciones.
- `Eval.dfy`: semántica denotacional pura (`Satisfies`, `Applies`, `Evaluate`) sobre `Permit`, `Deny` y un estado interno `Conflict`.
- `Coherence.dfy` (34 lemas): especificación fantasma de `P1..P4` y `Coherent`, chequeos ejecutables `CheckP1..CheckP4`, composición secuencial `CheckCoherent` y pruebas de solidez (`CheckCoherentSound`), autenticidad de testigos (`CheckCoherentGenuine`) y completitud (`CheckCoherentComplete`).
- `Transition.dfy` (12 lemas): transiciones totales `TryAdd`, `TryUpdate` y `TryRemove`, teoremas inductivos de preservación (`EmptyCoherent`, `AddPreserves`, `UpdatePreserves`, `RemovePreservesCoherent`), inalcanzabilidad de conflicto (`EvaluateAgreesOnCoherent`) y teoremas de solidez y completitud de testigos (`WitnessSoundness`, `WitnessCompleteness` y sus variantes para actualización).
- `BoundedCheck.dfy` (2 lemas): módulo exclusivo de verificación (excluido de la compilación a JavaScript) que enumera exhaustivamente todos los conjuntos hasta longitud tres sobre un esquema reducido de ocho solicitudes y seis reglas (`SmallStateCount = 259` conjuntos) y demuestra `BoundedModelCheck`.

La @fig:chequeos resume el encadenamiento de `CheckCoherent` de P1 a P4 y los teoremas que respaldan cada etapa.

#figure(
  placement: auto,
  scope: "parent",
  image("img/check_phases.png", width: 100%),
  caption: [Etapas de comprobación de coherencia en el núcleo formal Dafny: orden de ejecución de propiedades P1 a P4, funciones ejecutables, lemas deductivos, testigos diagnósticos y costo computacional.],
) <fig:chequeos>

El siguiente fragmento ilustra la guarda `TryAdd` junto con su teorema inductivo `AddPreserves`:

#block(breakable: false)[
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
]

== Modelo de verificación en UPPAAL

Mientras Dafny prueba por inducción que toda operación guardada preserva `Coherent` para esquemas y conjuntos arbitrarios, UPPAAL #cite(<larsen1997uppaal>) se empleó como verificación independiente sobre una *instancia fija y concreta* (`uppaal/abac-guard.xml` y `uppaal/abac-guard.q`). El objetivo es doble: comprobar por exploración exhaustiva de estados que el protocolo dinámico de transición del autómata `Admin` carece de interbloqueos y mutaciones parciales, y confirmar sobre un repertorio representativo de directivas que tanto una política clínica válida como cada clase de rechazo diagnóstico (`P1` a `P4`) son efectivamente alcanzables.

El modelo constituye un único autómata discreto no temporizado (sin relojes continuos ni canales de sincronización) que instancia un microuniverso de $N_("req") = 16$ solicitudes ($2$ roles, $2$ acciones, $2$ horas `{8, 18}` y $2$ estados de emergencia, con los demás atributos fijos) y un conjunto máximo de `MAX_R = 3` reglas activas tomadas de un repertorio fijo de diez directivas (`r0..r9`), resumido en la @tab:pool_uppaal.

#figure(
  table(
    columns: (0.6fr, 0.7fr, 1.5fr, 1.4fr),
    inset: 5pt,
    align: left,
    table.header([Regla], [Efecto], [Condición en el modelo], [Caso que ejercita]),
    [`r0`], [Permit], [`role == 0 && ac == 0`], [Lectura médica (base limpia)],
    [`r1`], [Deny], [`ac == 1 && se >= 4 && cl <= 2`], [Escritura sensible (base limpia)],
    [`r2`], [Permit], [`em == 1 && ac == 0`], [Lectura en emergencia (base limpia)],
    [`r3`], [Deny], [`role == 0 && ac == 0`], [Contradice a `r0` (P1)],
    [`r4`], [Permit], [`role == 0`], [Cubre y sombrea a `r0` (P3)],
    [`r5`], [Permit], [`role == 0 && dept == 0`], [Equivalente a `r0` con `dept` fijo (P3)],
    [`r6`], [Permit], [`cl > 5 && cl < 2`], [Condición imposible (P2)],
    [`r7`], [Permit], [`em == 1`], [Permiso abierto de emergencia (P1 con `r8`)],
    [`r8`], [Deny], [`hr >= 18`], [Denegación nocturna (P1 con `r7`)],
    [`r9`], [Permit], [`em == 0` (`poolValid = 0`)], [Directiva inválida de esquema (P4)],
  ),
  caption: [Repertorio fijo de diez directivas candidatas en uppaal/abac-guard.xml.],
) <tab:pool_uppaal>

#figure(
  image("img/model_diagram.png", width: 90%),
  caption: [Autómata finito Admin en uppaal/abac-guard.xml con estados confirmados y comprometidos.],
) <fig:transicion>

Como muestra la @fig:transicion, `Empty` y `Coherent` representan configuraciones confirmadas almacenadas en el arreglo `committed` (tamaño `csz`). Las ubicaciones `TryingAddE`, `TryingAddC` y `TryingUpdC` son estados comprometidos (`committed`) donde el arreglo candidato `cand` se evalúa mediante `coherentC()`: al salir inmediatamente por las guardas complementarias `coherentC()` (`acceptCand`) o `!coherentC()` (`rejectUnified`), la validación y confirmación o rechazo ocurren de forma atómica sin intercalado ni corrupción de `committed`. Las auto-transiciones en `Empty` y `Coherent` modelan actualizaciones sobre identificadores ausentes (`onUnknown`, registrando `rejUnknownP4`) y eliminaciones (`doRemoveC`, registrando `lastOp = 2`).

Las nueve consultas en lógica TCTL de `uppaal/abac-guard.q` validan propiedades de seguridad (que nada inválido ocurra) y de alcanzabilidad (que el caso válido y todas las rutas diagnósticas existan). A continuación se detalla el propósito y sustento de cada fórmula, sintetizados en la @tab:consultas:

1. `A[] coherent()`: exige que en toda trayectoria y en todo estado alcanzable (incluso durante los estados comprometidos `Trying*`) el conjunto confirmado cumpla `p1() && p2() && p3() && p4()`. Fallaría si alguna transición alterara `committed` antes de superar `coherentC()`.
2. `A[] !deadlock`: certifica que el autómata nunca alcanza un estado sin salida posible. En `Trying*`, las guardas `coherentC()` y `!coherentC()` particionan el espacio; en `Empty` y `Coherent`, aun con `csz == MAX_R`, permanecen habilitadas actualizaciones, bajas o rechazos por identificador desconocido.
3. `A[] (lastOp != 2 || coherent())`: aísla explícitamente la operación de eliminación (`doRemoveC`, que fija `lastOp = 2` sin invocar `coherentC()`) para comprobar en el caso acotado que retirar cualquier regla preserva las cuatro propiedades, en correspondencia directa con `RemovePreservesCoherent`.
4. `E<> cleanAccepted`: actúa como prueba de no vacuidad sobre el caso fijo válido `{r0, r1, r2}`, confirmando que el autómata sí acepta la política clínica coherente esperada en lugar de satisfacer `A[] coherent()` rechazando toda inserción.
5. `E<> rejP1`: verifica que pares conflictivos del repertorio (como `r0` con `r3` o `r7` con `r8`) activan la rama de rechazo P1 (`rejP1 = true`) sin filtrarse al estado confirmado.
6. `E<> rejP2`: demuestra que la regla muerta `r6` (`cl > 5 && cl < 2`) dispara la detección de insatisfacibilidad (`rejP2 = true`).
7. `E<> rejP3`: confirma que reglas cubiertas o duplicadas (`r0` con `r4` o `r5`) alcanzan la rama de rechazo por sombreado (`rejP3 = true`) aun cuando satisfacen P1 y P2.
8. `E<> rejUnknownP4`: comprueba que invocar una actualización sobre un identificador no presente en `committed` ejecuta `onUnknown` y reporta rechazo P4 sin mutar el estado.
9. `E[] coherent()`: complementa la ausencia de bloqueos demostrando que existe al menos una traza infinita de evolución continua donde el sistema permanece permanentemente coherente.

#figure(
  placement: auto,
  scope: "parent",
  table(
    columns: (1.2fr, 0.75fr, 2.3fr),
    inset: 5pt,
    align: left,
    table.header([Consulta TCTL], [Clase], [Significado y justificación en el modelo]),
    [`A[] coherent()`], [Seguridad], [Todo estado alcanzable mantiene coherente a `committed`, descartando mutaciones parciales.],
    [`A[] !deadlock`], [Seguridad], [Ninguna ejecución se bloquea; las guardas cubren todas las salidas desde `Trying*` y estados estables.],
    [`A[] (lastOp != 2 || coherent())`], [Seguridad], [Toda baja (`doRemoveC`) preserva coherencia sin reevaluar `coherentC()`.],
    [`E<> cleanAccepted`], [Alcanzabilidad], [Prueba de no vacuidad: la política clínica válida `{r0, r1, r2}` es alcanzable y aceptada.],
    [`E<> rejP1`], [Alcanzabilidad], [Confirma detección y testigo P1 ante conflictos (`r0`/`r3` o `r7`/`r8`).],
    [`E<> rejP2`], [Alcanzabilidad], [Confirma detección P2 frente a la condición imposible de `r6`.],
    [`E<> rejP3`], [Alcanzabilidad], [Confirma detección P3 cuando `r4` o `r5` sombrean a `r0`.],
    [`E<> rejUnknownP4`], [Alcanzabilidad], [Verifica el rechazo P4 en frontera ante identificadores inexistentes en actualización.],
    [`E[] coherent()`], [Alcanzabilidad], [Asegura existencia de evolución continua e infinita siempre coherente.],
  ),
  caption: [Propiedades TCTL verificadas en uppaal/abac-guard.q con su justificación.],
) <tab:consultas>

Todas las consultas resultaron satisfechas (`Property is satisfied`, @fig:verificador). La comprobación en UPPAAL exploró 23 estados estables alcanzables (`Empty` más 22 subconjuntos coherentes), 470 evaluaciones de candidato y 529 transiciones, requiriendo 16.7 s para `A[] coherent()` y 28.7 s para `A[] !deadlock`.

#figure(
  image("img/checking_results.png", width: 90%),
  caption: [Panel del verificador de UPPAAL con las nueve consultas satisfechas.],
) <fig:verificador>

== Extracción ejecutable y frontera de entrada

Los cinco módulos operacionales en Dafny compilan directamente a JavaScript (`dafny build --target js`) para ejecutar las funciones `TryAdd`, `TryUpdate`, `TryRemove`, `CheckCoherent` y `Evaluate` sin invocar solucionadores SMT en producción. Sobre este código generado opera una frontera delgada en TypeScript encargada exclusivamente de validar el esquema y las cotas protectoras (`TooLarge`), analizar reglas en texto desazucarando `in` y `between` hacia nodos `Or` y `And` (`ParseError`), verificar que toda solicitud de evaluación sea total y pertenezca al dominio (`DomainError`) y redactar explicaciones legibles para los testigos (`explain`).

Esta capa anfitriona constituye la base confiable no demostrada del entorno de ejecución y no reimplementa ninguna decisión de coherencia. Las pruebas automatizadas en el repositorio (`parser.test.ts`, `wrappers.test.ts` y `replay.test.ts`) cumplen un rol estrictamente de *regresión y conformidad de frontera*: confirman que las estructuras adaptadas reproducen exactamente los testigos derivados por el núcleo Dafny y no sustituyen ni fundamentan la corrección matemática del sistema, la cual descansa exclusivamente en las demostraciones de Dafny y el model checking en UPPAAL.

== Evaluación guiada de caso clínico <sec:evaluacion_guiada>

Para ilustrar paso a paso el funcionamiento del verificador sobre el esquema clínico `schema-v1.json` ($64\,800$ solicitudes posibles), se traza la evolución del escenario `emergency-override.json` y su corrección hacia `clean.json`:

1. *Estado inicial ($R_0 = []$):* el conjunto vacío es vacuamente coherente según el lema `EmptyCoherent` (ubicación `Empty`).
2. *Primera inserción (`TryAdd(R_0, r_1)`):* se propone $r_1 =$ `Permit where environment.emergency == true`. `CheckCoherent([r_1], schema)` supera P1 (no hay reglas `Deny`), P2 (`r_1` dispara en la primera solicitud enumerada de `AllRequests`: `role=medic, dept=cardio, clearance=1, type=record, sensitivity=1, name=read, hour=0, emergency=true`), P3 (regla única) y P4 (esquema válido). La operación devuelve `Accepted([r_1])` asignando `id = 1` y transita a `Coherent`.
3. *Segunda inserción conflictiva (`TryAdd(R_1, r_2)`):* se propone la salvaguarda nocturna $r_2 =$ `Deny where environment.hour >= 18`. Al ejecutar `CheckCoherent([r_1, r_2], schema)`, la fase P1 (`CheckP1From`) recorre `AllRequests` por índice entero; todas las solicitudes con `hour < 18` pasan, hasta alcanzar el índice donde `hour = 18` y `emergency = true` (específicamente `role=medic, dept=cardio, clearance=1, type=record, sensitivity=1, name=read, hour=18, emergency=true`). Allí se activan simultáneamente `PermitApplies` (por $r_1$) y `DenyApplies` (por $r_2$). El chequeo se detiene en ese primer contraejemplo, `TryAdd` retorna `Rejected(Witness(q, [1, 2], "P1", ...))` y, conforme a `AddPreserves` y a la atomicidad del protocolo, el conjunto confirmado permanece inalterado en $R_1 = [r_1]$.
4. *Remediación coherente (`clean.json`) y evaluación:* para evitar la colisión nocturna, el administrador acota tanto la regla de emergencia como las restricciones de escritura en tres reglas: $r_1' =$ `Permit where subject.role == medic && action.name == read`, $r_2' =$ `Deny where action.name == write && resource.sensitivity >= 4 && subject.clearance <= 2` y $r_3' =$ `Permit where environment.emergency == true && action.name == read`. Al insertarlas secuencialmente mediante `TryAdd`, $r_1'$ y $r_2'$ operan sobre acciones disjuntas (`read` frente a `write`), y aunque $r_1'$ y $r_3'$ coinciden en lecturas médicas de emergencia, ambas comparten el efecto `Permit` (por lo que P1 se cumple) y $r_3'$ decide en solitario cualquier lectura de emergencia realizada por `nurse` o `admin` (por lo que P3 también se cumple). El conjunto final `[r_1', r_2', r_3']` es aceptado (`ids = [1, 2, 3]`) y, al consultar `Evaluate` para un enfermero de urgencias leyendo un historial a las 03:00 en emergencia, devuelve `Permit` atribuyendo el disparo a la regla `#3`, con imposibilidad demostrada de `Conflict` (`EvaluateAgreesOnCoherent`).

De forma análoga, los escenarios diagnósticos complementarios cubren las demás propiedades sobre el mismo esquema: `contradictory.json` produce rechazo P1 ante reglas espejo de permiso y denegación; `unsatisfiable.json` (`subject.clearance > 5 && subject.clearance < 2`) falla en P2 al agotar `[1..5]` sin disparos; `shadowed.json` (`subject.role == medic && subject.dept == cardio` tras `subject.role == medic`) falla en P3 al carecer de testigo solitario, y las actualizaciones sobre identificadores ausentes producen rechazo P4 inmediato. Todos estos testigos se reproducen de forma determinista al ejecutarse sobre el módulo JavaScript compilado.

== Resumen de artefactos formales

La @tab:artefactos_desarrollados consolida los artefactos verificados y de validación desarrollados, priorizando sus garantías formales y métricas de estado.

#figure(
  placement: auto,
  scope: "parent",
  table(
    columns: (1.2fr, 1.15fr, 0.85fr, 1.35fr, 2.35fr),
    inset: 5pt,
    align: left,
    table.header([Artefacto desarrollado], [Ruta / Módulo], [Formalismo], [Métricas formales], [Contribución técnica principal]),
    [Núcleo formal Dafny], [`dafny/`], [Dafny], [6 módulos, 59 lemas, 114 obligaciones (0 errores)], [Semántica ABAC, propiedades P1–P4, 7 teoremas inductivos centrales y `BoundedCheck` (259 conjuntos).],
    [Autómata de transición], [`uppaal/abac-guard.xml`], [UPPAAL], [1 autómata, 16 reqs, 10 reglas, 23 nodos, 529 transiciones], [Model checking exhaustivo de seguridad, atomicidad en estados comprometidos y 0 bloqueos.],
    [Consultas formales TCTL], [`uppaal/abac-guard.q`], [TCTL], [9 propiedades verificadas (3 seguridad, 6 alcance)], [Prueba de invariancia, preservación en bajas, no vacuidad (`cleanAccepted`) y rutas `P1..P4`.],
    [Escenarios clínicos], [`fixtures/`], [JSON / ABAC], [5 políticas sobre 64 800 solicitudes (`schema-v1`)], [Casos guiados de conflicto en emergencia, política limpia, regla muerta, sombreado y contradicción.],
    [Frontera y regresión], [`src/`, `test/`], [JS / TS], [Módulo compilado sin SMT en ejecución], [Análisis sintáctico con validación de esquema, cotas `TooLarge` y confirmación de testigos en frontera.],
  ),
  caption: [Catálogo consolidado de artefactos formales y escenarios de validación del proyecto.],
) <tab:artefactos_desarrollados>

= Discusión, limitaciones y amenazas a la validez <sec:discusion>

El diseño del verificador conjuga el rigor deductivo de CbC con las restricciones operativas de la evaluación determinista sin motores simbólicos en ejecución.

== Limitaciones intrínsecas del espacio cartesiano

La principal restricción temporal reside en la enumeración explícita del espacio cartesiano de solicitudes, expresado en la @eq:allrequests como $|"AllRequests"| = product_(i=1)^(k) |D_i|$. La comprobación exhaustiva previene falsos positivos y asegura que ante cualquier rechazo exista un contraejemplo reproducible.

Sin embargo, esta garantía conlleva un costo temporal de $O(|"AllRequests"| dot |R|)$ para consistencia P1 y satisfacibilidad P2, y de $O(|"AllRequests"| dot |R|^2)$ para la detección de sombreado P3. En esquemas de tamaño moderado, como el caso clínico de evaluación con ocho atributos y 64800 solicitudes en total, el proceso toma algunos segundos en JavaScript. Esta progresión geométrica frente al número de atributos $k$ limita la enumeración directa a políticas con dominios acotados.

Para proteger la disponibilidad del entorno de ejecución, el sistema aplica una comprobación defensiva conforme a RF-11: al cargar el esquema o procesar lotes se evalúan los topes de diseño, fijados en un millón de solicitudes en el espacio cartesiano, sesenta y cuatro directivas comprobadas y dieciséis valores por enumeración. Si una política rebasa estos límites, la biblioteca produce en tiempo $O(1)$ la excepción tipada TooLarge, lo que interrumpe el procesamiento antes de incurrir en recorridos combinatorios prolongados.

== Amenazas a la validez interna

La principal amenaza a la validez interna se ubica en la frontera de análisis sintáctico y adaptación previa al núcleo verificado en Dafny. El analizador desazucara listas `in` hacia disyunciones `||` y rangos `between` hacia conjunciones acotadas `&&` fuera de Dafny, por lo que esta traducción sintáctica forma parte de la base confiable no demostrada.

Esta amenaza se mitiga mediante tres controles: validación estricta de tipos y dominios antes de construir nodos AST, mapeo directo hacia los constructores algebraicos `And`, `Or` y `Atom` de Dafny, y pruebas de conformidad sintáctica en `test/parser.test.ts` (que comprueban el contrato de entrada sin sustituir la demostración formal del núcleo).

== Amenazas a la validez de constructo

Respecto a la validez de constructo, el modelo ABAC evalúa predicados atómicos frente a constantes literales fijadas en el esquema, por ejemplo `subject.role == medic`, y descarta comparaciones dinámicas entre múltiples atributos de una misma solicitud, como exigir que `subject.clearance` sea mayor o igual a `resource.sensitivity`.

Esta delimitación responde a una decisión de diseño: permitir comparaciones generales entre variables transformaría el problema en lógica de primer orden, cuya resolución requeriría motores SMT como Z3 durante la ejecución, con riesgo de indeterminación, tiempos de espera indefinidos y agotamiento de memoria. Al restringir las reglas a comparaciones literales sobre dominios finitos, el sistema asegura la decidibilidad y la obtención determinista de testigos.

== Amenazas a la validez externa

En cuanto a la validez externa, el sistema se orienta a entornos donde las políticas se definen sobre esquemas discretos bien tipados, tales como pasarelas de microservicios, sistemas hospitalarios o registros académicos. El enfoque no es directamente aplicable a sistemas que empleen atributos continuos de punto flotante o texto libre sin discretización previa.

Asimismo, el model checking en UPPAAL valida un autómata secuencial único (`Admin`) sobre un repertorio fijo de diez directivas y dieciséis solicitudes. Aunque confirma ausencia de interbloqueos y preservación de coherencia bajo cualquier secuencia de adición, actualización y baja dentro de esa instancia, escenarios concurrentes con múltiples administradores distribuidos requerirían protocolos externos de control de concurrencia.

= Conclusiones y trabajo futuro <sec:conclusiones>

== Conclusiones

Este artículo presentó el diseño, la verificación y la implementación de un verificador de coherencia para políticas ABAC desarrollado bajo el paradigma CbC. El sistema decide cuatro propiedades formales (P1 a P4), sintetiza testigos diagnósticos mínimos ante cada infracción y garantiza mediante lemas inductivos en Dafny que toda transición guardada preserva la coherencia del conjunto.

La solución articula dos técnicas formales complementarias: Dafny descargó 114 obligaciones de verificación sin errores en 59 lemas de solidez, completitud y preservación inductiva, mientras UPPAAL comprobó de forma exhaustiva la ausencia de interbloqueos y la invariancia de coherencia sobre un caso acotado mediante nueve propiedades en lógica TCTL. La compilación del núcleo verificado hacia JavaScript permite ejecutar decisiones formales deterministas sin motores SMT en tiempo de ejecución.

== Trabajo futuro

A partir de las limitaciones identificadas, se proyectan tres líneas de desarrollo futuro:

1. Representación simbólica mediante diagramas de decisión binaria o BDD y diagramas de decisión suprimidos por ceros o ZDD: reemplazar la enumeración cartesiana explícita por estructuras canónicas de decisión, lo que permitiría comprimir el espacio de estados y analizar esquemas de mayor dimensionalidad conservando la extracción de código verificado.
2. Verificación incremental localizada: demostrar lemas inductivos que acoten la comprobación de coherencia al subespacio de solicitudes afectado por la directiva modificada o añadida, lo que evitará reevaluar el espacio global y reducirá el costo temporal ante cambios aislados.
3. Protocolos de autorización distribuida para PDP concurrentes: extender el modelo en UPPAAL hacia arquitecturas con múltiples puntos de decisión distribuidos, incorporando modelos de consistencia eventual y sincronización frente a fallas parciales de red.

= Disponibilidad de datos y código <sec:datos>

El código fuente completo, las especificaciones en Dafny, los modelos y consultas de UPPAAL, los escenarios de evaluación, las pruebas de conformidad de frontera y este documento se encuentran disponibles bajo licencia de código abierto en el repositorio público https://github.com/microuni-unsa/afve-teo-turno-c-grupo-1-final/.
