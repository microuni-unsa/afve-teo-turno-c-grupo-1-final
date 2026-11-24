# Puntos Clave de la Presentación — Feria de Proyectos UNSA 2026

Este documento sintetiza los requerimientos normativos de las bases del concurso y su correlación exacta con los componentes técnicos reales del proyecto **ABAC Coherence Verifier**, priorizando el rigor de Métodos Formales y manteniendo consistencia estricta entre `paper/paper.typ`, `feria-proyectos/slides/presentacion.html`, `feria-proyectos/guion.md`, los módulos en `dafny/` y el modelo en `uppaal/`.

---

## 1. Datos Generales y Categoría

- **Evento**: Feria de Proyectos 2026 — Escuela Profesional de Ingeniería de Sistemas (EPIS), UNSA.
- **Categoría**: **Categoría II – Intermedio** (Estudiantes de 3er y 4to año académico).
- **Asesoría**: Docente asesor — **Molina Barriga, Maribel**.
- **Formato del Entregable**:
  - Video MP4 de **7 minutos de duración máxima**.
  - Presentación visual de **14 láminas** basada estrictamente en la plantilla institucional (`plantilla-presentacion.pptx`: portada con logos UNSA/EPIS arriba, cuerpo limpio con pie `#ED7D31`, tipografía **Arimo** y tamaños de plantilla, y última lámina `Gracias…`).
  - Artículo científico en formato IEEE (`paper/paper.typ`, compilado con Typst 0.15.1 a `paper/paper.pdf`).
- **Equipo (4 integrantes)**:
  1. Jara Mamani, Mariel Alisson
  2. Sequeiros Condori, Luis Gustavo
  3. Noa Camino, Yenaro Joel
  4. Mestas Zegarra, Christian Raul

---

## 2. Sistema de Calificación (Rúbrica Categoría II — 100 Puntos)

| Criterio | Puntaje Máximo | Descripción de las Bases | Correlación con el Proyecto |
|---|:---:|---|---|
| **1. Objetivos del Proyecto** | **10 pts** | Resultados previstos alcanzables en plazo determinado. | • **General**: Diseñar y verificar formalmente en Dafny un verificador ABAC con preservación inductiva de coherencia, validado en UPPAAL y compilado a JS sin SMT en ejecución.<br>• **Específicos**: Formalización semántica P1–P4 (`OE1`), interfaz guardada con preservación inductiva y testigos mínimos (`OE2`), model checking TCTL en UPPAAL (`OE3`), y extracción ejecutable detrás de frontera ligera (`OE4`). |
| **2. Alcance del Proyecto** | **10 pts** | Tareas, recursos, plazos y límites de funcionamiento. | • **Alcance funcional y fragmento decidible**: Propiedades `P1 → P2 → P3 → P4` en `CheckCoherent`, 4 familias NIST SP 800-162 (`Enum`, `Bool`, `BoundedInt`), operaciones guardadas (`TryAdd`, `TryUpdate`, `TryRemove`, `tryAddMany`) y evaluación lineal `Evaluate`.<br>• **Delimitación por decidibilidad**: Esquemas discretos cerrados contra literales (sin PIP en vivo, aritmética abierta ni prioridades laxas) con cotas de protección `TooLarge` tratadas en el análisis de validez. |
| **3. Justificación del Proyecto** | **15 pts** | Necesidad, valor e impacto (responsabilidad social, seguridad de datos). | • **Intuición y escenarios reales**: Ejemplos claros de solicitud y regla ABAC frente a 3 fallas críticas (emergencia vs horario nocturno, rango imposible, sombreado departamental).<br>• **Teórica**: Insuficiencia del muestreo frente a `64 800` solicitudes en `schema-v1.json`.<br>• **Metodológica**: Paradigma CbC sin motores SMT en producción frente a herramientas previas (XACML/Z3, AWS Zelkova, Cedar, Mohawk). |
| **4. Metodología Utilizada** | **15 pts** | Conjunto de técnicas y procedimientos (2–3 fases o más). | Metodología de **Corrección por Construcción (CbC)** en 5 fases:<br>1. Especificación formal denotacional y enumeración constructiva `AllRequests`.<br>2. Verificación deductiva de P1–P4, 7 teoremas centrales y `BoundedCheck`.<br>3. Model checking exhaustivo sobre caso fijo en UPPAAL (`Admin`, 9 TCTL).<br>4. Compilación de los 5 módulos operacionales a JS detrás de frontera ligera.<br>5. Evaluación guiada paso a paso de escenarios clínicos y conformidad en frontera. |
| **5. Artefactos Empleados** | **20 pts** | Herramientas y estándares que determinan la calidad del producto. | • **Dafny 4.11**: Especificación matemática, 114 obligaciones verificadas (59 lemas) y síntesis JS.<br>• **Z3 (4.12+) y cvc5 (1.0+)**: Solucionadores SMT únicamente en tiempo de diseño.<br>• **UPPAAL 5.0**: Model checking de autómata discreto (`Admin`) y 9 consultas TCTL.<br>• **Estándares**: NIST SP 800-162, NIST SP 800-192, OASIS XACML 3.0 y IEEE (Typst 0.15.1).<br>• **Entorno anfitrión auxiliar (TS / Node / Bun)**: Análisis sintáctico de entrada y ejecución del núcleo compilado. |
| **6. Artefactos Desarrollados** | **30 pts** | Productos tangibles construidos por el equipo. | • **Núcleo Dafny** (`dafny/`): 6 módulos (`Schema`, `Syntax`, `Eval`, `Coherence`, `Transition`, `BoundedCheck`), 114 obligaciones verificadas, 7 teoremas principales y `259` conjuntos en `BoundedCheck`.<br>• **Modelo UPPAAL** (`uppaal/`): autómata `Admin` sobre caso fijo (`16` solicitudes, `10` reglas `r0..r9`), `23` nodos estables, `470` evaluaciones, `529` transiciones, `9/9` consultas TCTL satisfechas (`0` bloqueos).<br>• **Escenarios guiados (`fixtures/`)**: 5 políticas sobre `schema-v1.json` (`emergency-override`, `clean`, `contradictory`, `unsatisfiable`, `shadowed`).<br>• **Frontera y regresión (`src/`, `test/`)**: Adaptador ligero y pruebas de replay que confirman la reproducción exacta de testigos en el JS compilado (sin sustituir la prueba formal). |

---

## 3. Estrategia Narrativa y Coherencia Lógica (14 Láminas)

1. **Portada** (Slide 1)
2. **¿Qué es ABAC y por qué falla manualmente?** — Solicitud concreta, regla y 3 escenarios reales (Slide 2)
3. **Propiedades de coherencia (P1–P4)** — Tarjetas visuales en lenguaje claro + ejemplo y regla formal (Slide 3)
4. **Objetivos y alcance del proyecto** — Enfoque positivo sobre metas formales y fragmento decidible (Slide 4)
5. **Comparativa con trabajo previo** — Dafny + UPPAAL sin SMT en ejecución (Slide 5)
6. **Metodología CbC y herramientas formales** (Slide 6)
7. **Arquitectura y frontera de ejecución** — 5 módulos compilados vs `BoundedCheck` solo en verificación, frontera delgada TS sin lógica propia (Slide 7)
8. **Fases de verificación (`P1 → P2 → P3 → P4`)** (Slide 8)
9. **¿Cómo garantiza Dafny la corrección?** — `TryAdd` / `AddPreserves` anotado, 5 garantías prácticas detrás de 114 metas y `BoundedCheck` (259 conjuntos) (Slide 9)
10. **UPPAAL: modelo y caso fijo** — `Admin`, 16 solicitudes, repertorio `r0..r9`, pasos atómicos, 23 estados / 529 transiciones (Slide 10)
11. **UPPAAL: las 9 consultas TCTL** — Leyenda simple + Seguridad (3) y Alcance (6) con resultados (Slide 11)
12. **Caso guiado I: choque y solución (`emergency-override.json` → `clean.json`)** (Slide 12)
13. **Casos guiados II: fallos y garantías (P2–P4 + síntesis del sistema)** (Slide 13)
14. **Cierre `Gracias…`** — Cita de Hall & Chapman y repositorio (Slide 14)

---

## 4. Lineamientos de Diseño de Diapositivas (Plantilla Oficial PPTX)

1. **Fidelidad a `plantilla-presentacion.pptx`**:
   - Lienzo `1920 × 1080` (`960 pt × 540 pt`, escala exacta `1 pt = 2 px`).
   - Fondo blanco puro (`#FFFFFF`), texto negro (`#000000`), acentos del tema Office (`#ED7D31` en línea divisoria del pie, `#44546A` marino en encabezados de tabla/código).
   - Portada sin pie de página con logo UNSA arriba a la izquierda y logo EPIS arriba a la derecha.
   - Páginas interiores con título a `44 pt` (`88 px`), contenido y pie con línea `#ED7D31`, logos laterales y título centrado a `20 pt` (`40 px`).
   - Última página con `Gracias…` a `138 pt` (`276 px`), viñeta de lema y repositorio.
2. **Tipografía única**: **Arimo** (Google Fonts).

---

## 5. Distribución del Video (7 Minutos — 4 Personas)

- **Total disponible**: ~420 segundos (7:00 minutos).
- **Segmento 1 (Mariel Jara — Slides 1–3)**: Intuición concreta de ABAC (4 familias, solicitud y regla), 3 escenarios reales de falla manual en `schema-v1` (64 800 solicitudes) y propiedades formales P1–P4.
- **Segmento 2 (Luis Sequeiros — Slides 4–7)**: Objetivos y alcance decidible, comparativa con literatura SMT/Lean, metodología CbC con herramientas formales y arquitectura núcleo–frontera (5 módulos compilados, `BoundedCheck` solo en verificación).
- **Segmento 3 (Yenaro Noa — Slides 8–11)**: Flujo `P1 → P2 → P3 → P4`, pruebas deductivas en Dafny (114 obligaciones, `BoundedCheck` 259 conjuntos) y model checking en UPPAAL sobre caso fijo (`Admin`, 23 nodos, 529 transiciones, justificación de las 9 consultas TCTL).
- **Segmento 4 (Christian Mestas — Slides 12–14)**: Evaluación guiada paso a paso (`emergency-override.json` → `clean.json` + `Evaluate`, más trazas P2/P3/P4), síntesis de garantías formales (aclarando que replay confirma la frontera sin sustituir las pruebas formales) y cierre.
