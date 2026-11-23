# Puntos Clave de la Presentación — Feria de Proyectos UNSA 2026

Este documento sintetiza los requerimientos normativos de las bases del concurso y su correlación exacta con los componentes técnicos reales del proyecto **ABAC Coherence Verifier**, alineado con el artículo en `paper/paper.typ` y la plantilla oficial `plantilla-presentacion.pptx`.

---

## 1. Datos Generales y Categoría

- **Evento**: Feria de Proyectos 2026 — Escuela Profesional de Ingeniería de Sistemas (EPIS), UNSA.
- **Categoría**: **Categoría II – Intermedio** (Estudiantes de 3er y 4to año académico).
- **Asesoría**: Docente asesor — **Molina Barriga, Maribel**.
- **Formato del Entregable**:
  - Video MP4 de **7 minutos de duración máxima**.
  - Presentación visual basada estrictamente en la plantilla institucional (`plantilla-presentacion.pptx`: portada con logos UNSA/EPIS arriba, cuerpo limpio con pie `#ED7D31`, tipografía **Arimo** y tamaños de plantilla, y última lámina `Gracias…`).
  - Artículo científico en formato IEEE (`paper/paper.typ`, compilado con Typst 0.15.1).
- **Equipo (4 integrantes)**:
  1. Jara Mamani, Mariel Alisson
  2. Sequeiros Condori, Luis Gustavo
  3. Noa Camino, Yenaro Joel
  4. Mestas Zegarra, Christian Raul

---

## 2. Sistema de Calificación (Rúbrica Categoría II — 100 Puntos)

| Criterio | Puntaje Máximo | Descripción de las Bases | Correlación con el Proyecto |
|---|:---:|---|---|
| **1. Objetivos del Proyecto** | **10 pts** | Resultados previstos alcanzables en plazo determinado. | • **General**: Diseñar, verificar formalmente e implementar un verificador ABAC con preservación por construcción y escalabilidad acotada (`Dafny → JS` + `UPPAAL` + `TypeScript/npm`).<br>• **Específicos**: Formalización semántica P1–P4, interfaz guardada con preservación inductiva, model checking en UPPAAL, y frontera defensiva empaquetada. |
| **2. Alcance del Proyecto** | **10 pts** | Tareas, recursos, plazos y límites de funcionamiento. | • **En alcance**: Propiedades P1–P4 en orden secuencial `P1 → P2 → P3 → P4` en `CheckCoherent`, 4 familias NIST SP 800-162, guardas atómicas (`tryAdd`, `tryUpdate`, `remove`, `tryAddMany`), evaluación lineal (`evaluate`, `evaluateMany`), topes explícitos (`MAX_ENUM_VALUES=16`, `MAX_RULES_CHECKED=64`, `MAX_REQUEST_SPACE=1,000,000` con error `TooLarge`).<br>• **Exclusiones**: Sin PIP en vivo, sin lógica de primer orden abierta ni comparación entre atributos, sin resolución laxa de conflictos, sin PEP/PDP ni historial. |
| **3. Justificación del Proyecto** | **15 pts** | Necesidad, valor e impacto (responsabilidad social, seguridad de datos). | • **Teórica**: Insuficiencia del muestreo empírico frente a 64 800 solicitudes en `schema-v1.json`.<br>• **Operativa / Social**: En hospitales y organismos públicos, reglas contradictorias bloquean atención de urgencias o exponen historiales confidenciales.<br>• **Tecnológica**: Paradigma CbC que elimina solucionadores SMT pesados en producción y supera las limitaciones de herramientas previas (XACML/Z3, AWS Zelkova, Cedar, Mohawk). |
| **4. Metodología Utilizada** | **15 pts** | Conjunto de técnicas y procedimientos (2–3 fases o más). | Metodología de **Corrección por Construcción (CbC)** en 5 fases:<br>1. Especificación formal denotacional y espacio `AllRequests`.<br>2. Verificación deductiva de P1–P4 y 7 lemas en Dafny.<br>3. Model checking temporal de estados en UPPAAL.<br>4. Compilación verificada a JS puro y envolturas defensivas TS.<br>5. Validación empírica con fixtures clínicos y suite de regresión. |
| **5. Artefactos Empleados** | **20 pts** | Herramientas y estándares que determinan la calidad del producto. | • **Dafny 4.11**: Verificación deductiva (114 metas, 0 errores) y síntesis a JavaScript.<br>• **Z3 (4.12+) & cvc5 (1.0+)**: Solucionadores SMT en tiempo de diseño.<br>• **UPPAAL 5.0**: Model checking temporal.<br>• **TypeScript 5.x, Node.js 20+, Bun 1.x**: Entorno anfitrión y pruebas.<br>• **Biome 1.9+**: Formateo y análisis estático.<br>• **Estándares**: NIST SP 800-162, NIST SP 800-192, XACML 3.0 y IEEE (Typst 0.15.1). |
| **6. Artefactos Desarrollados** | **30 pts** | Productos tangibles construidos por el equipo. | • **Núcleo Dafny** (`dafny/`): 6 módulos (~48 KB: `Schema`, `Syntax`, `Eval`, `Coherence`, `Transition`, `BoundedCheck`), 7 lemas principales (incluyendo `EvaluateAgreesOnCoherent`).<br>• **Modelo UPPAAL** (`uppaal/`): 23 estados, 529 transiciones, 9/9 consultas TCTL satisfechas sin deadlock.<br>• **Biblioteca TypeScript** (`src/`): `schema.ts`, `parser.ts`, `wrappers.ts`, `batch.ts`, `explain.ts`, `errors.ts` (5 errores tipados).<br>• **Paquete npm**: `@grupo1/abac-verifier` para Node.js y navegadores.<br>• **Fixtures y Pruebas** (`fixtures/`, `test/`): 5 fixtures JSON (`clean`, `contradictory`, `unsatisfiable`, `shadowed`, `emergency-override`) y 27 pruebas en 3 suites (`parser`, `wrappers`, `replay`). |

---

## 3. Estrategia Narrativa y Coherencia Lógica

1. **Problema y justificación** (Slide 2)
2. **Propiedades de coherencia P1–P4** (Slide 3)
3. **Objetivos y alcance acotado** (Slide 4)
4. **Comparativa con trabajo previo** (Slide 5)
5. **Metodología CbC y artefactos** (Slide 6)
6. **Arquitectura en 3 capas** (Slide 7)
7. **Fases de verificación `P1 → P2 → P3 → P4`** (Slide 8)
8. **Núcleo formal en Dafny** (Slide 9)
9. **Model checking en UPPAAL** (Slide 10)
10. **Envolturas en TypeScript** (Slide 11)
11. **Casos de estudio (`emergency-override.json` rechazado P1 vs `clean.json` aceptado) y validación** (Slide 12)
12. **Cierre `Gracias…` con lema de Hall & Chapman y repositorio** (Slide 13)

---

## 4. Lineamientos de Diseño de Diapositivas (Plantilla Oficial PPTX)

1. **Fidelidad a `plantilla-presentacion.pptx`**:
   - Lienzo `1920 × 1080` (`960 pt × 540 pt`, escala exacta `1 pt = 2 px`).
   - Fondo blanco puro (`#FFFFFF`), texto negro (`#000000`), acentos tomados del tema de Office (`#ED7D31` en línea divisoria del pie, `#44546A` marino en encabezados de tabla/código).
   - Portada sin pie de página con logo UNSA arriba a la izquierda y logo EPIS arriba a la derecha.
   - Páginas interiores sin barra superior: solo título a `44 pt` (`88 px`), contenido y pie con línea `#ED7D31`, logo UNSA a la izquierda, título del proyecto centrado a `20 pt` (`40 px`) y logo EPIS a la derecha.
   - Última página con `Gracias…` a `138 pt` (`276 px`), viñeta de lema (`28 pt` / `56 px`) y repositorio.
2. **Tipografía y tamaños exactos**:
   - Fuente única: **Arimo** (cargada desde Google Fonts).
   - Tamaños: `44 pt` (`88 px`) títulos, `28 pt` (`56 px`) nivel 1, `24 pt` (`48 px`) nivel 2 y encabezados de columna, `20 pt` (`40 px`) nivel 3 y pie, `18 pt` (`36 px`) / `16 pt` (`32 px`) nivel 4 y tablas.

---

## 5. Distribución del Video (7 Minutos — 4 Personas)

- **Total disponible**: ~420 segundos (7:00 minutos).
- **Segmento 1 (Mariel Jara — Slides 1–3)**: Contexto crítico, explosión combinatoria (NIST SP 800-162/192) y definición del problema.
- **Segmento 2 (Luis Sequeiros — Slides 4–8)**: Comparativa con trabajo previo, objetivos, alcance acotado, las 4 propiedades P1–P4, arquitectura en 3 capas y fases `P1 → P2 → P3 → P4`.
- **Segmento 3 (Yenaro Noa — Slides 9–10)**: Núcleo Dafny (6 módulos, 7 lemas, 114 metas) y model checking en UPPAAL (23 estados, 529 transiciones, 9 consultas TCTL).
- **Segmento 4 (Christian Mestas — Slides 11–13)**: Frontera TypeScript (`@grupo1/abac-verifier`), demostración sobre `emergency-override.json` vs `clean.json`, métricas reales (27 pruebas, `evaluate()` en 0.08 ms) y cierre.
