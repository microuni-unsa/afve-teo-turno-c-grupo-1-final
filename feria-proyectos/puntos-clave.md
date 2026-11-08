# Puntos Clave de la Presentación — Feria de Proyectos UNSA 2026

Este documento sintetiza los requerimientos normativos de las bases del concurso y su correlación exacta con los componentes técnicos reales del proyecto **ABAC Coherence Verifier**, sirviendo como guía de referencia continua.

---

## 1. Datos Generales y Categoría

- **Evento**: Feria de Proyectos 2026 — Escuela Profesional de Ingeniería de Sistemas (EPIS), UNSA.
- **Categoría**: **Categoría II – Intermedio** (Estudiantes de 3er y 4to año académico).
- **Formato del Entregable**:
  - Video MP4 de **7 minutos de duración máxima**.
  - Presentación visual basada en la plantilla institucional (estilo minimalista, logos oficiales, encabezados y pies de página formales).
  - Artículo científico en formato IEEE.
- **Equipo (4 integrantes)**:
  1. Yenaro Joel Noa Camino (Presenta en cámara)
  2. Luis Gustavo Sequeiros Condori (Presenta en cámara)
  3. Christian Raul Mestas Zegarra (Presenta en cámara)
  4. Mariel Alisson Jara Mamani (Presenta en narración / voz en off)

---

## 2. Sistema de Calificación (Rubric Categoría II — 100 Puntos)

| Criterio | Puntaje Máximo | Descripción de las Bases | Correlación con el Proyecto |
|---|:---:|---|---|
| **1. Objetivos del Proyecto** | **10 pts** | Resultados previstos alcanzables en plazo determinado. | • **General**: Diseñar, verificar formalmente e implementar un verificador de coherencia ABAC con garantías de preservación por construcción.<br>• **Específicos**: Formalización semántica en Dafny, invariante de evolución guardada, model checking en UPPAAL, y empaquetado seguro en npm/TypeScript. |
| **2. Alcance del Proyecto** | **10 pts** | Tareas, recursos, plazos y límites de funcionamiento. | • **En alcance**: 4 propiedades canónicas (P1 a P4), 4 familias NIST SP 800-162, dominios finitos acotados, guardas atómicas (`tryAdd`, `tryUpdate`, `remove`), generación de testigos mínimos.<br>• **Exclusiones**: Sin PIP en vivo, sin lógica de primer orden no acotada, sin resolución laxa de conflictos (cualquier choque es error). |
| **3. Justificación del Proyecto** | **15 pts** | Necesidad, valor e impacto (responsabilidad social, seguridad de datos). | • **Teórica**: Insuﬁciencia del muestreo empírico ante la explosión combinatoria del espacio cartesiano de solicitudes.<br>• **Operativa / Social**: En hospitales y organismos públicos, reglas contradictorias bloquean atención de emergencias o exponen historiales confidenciales.<br>• **Tecnológica**: Paradigma CbC que elimina la dependencia de motores SMT pesados en producción. |
| **4. Metodología Utilizada** | **15 pts** | Conjunto de técnicas y procedimientos (2-3 fases o más). | Metodología formal de **Corrección por Construcción (CbC)** en 5 fases:<br>1. Especificación formal denotacional.<br>2. Verificación deductiva e invariantes en Dafny.<br>3. Verificación temporal de estados en UPPAAL.<br>4. Compilación verificada a JavaScript y envolturas TypeScript.<br>5. Validación empírica con fixtures y regresión. |
| **5. Artefactos Empleados** | **20 pts** | Herramientas y estándares que determinan la calidad del producto. | • **Dafny 4.x**: Verificación deductiva y síntesis a JavaScript.<br>• **Z3 (4.12+) & cvc5 (1.0+)**: Solucionadores SMT automáticos.<br>• **UPPAAL 5.0**: Model checking de sistemas de transición temporizados.<br>• **TypeScript 5.x, Node.js 20, Bun 1.x**: Entorno anfitrión tipado y empaquetado.<br>• **Biome**: Aseguramiento estático y calidad de código TypeScript.<br>• **Estándares**: NIST SP 800-162 y NIST SP 800-192. |
| **6. Artefactos Desarrollados** | **30 pts** | Productos tangibles construidos por el equipo. | • **Núcleo Dafny** (`dafny/`): 6 módulos formales, 7 lemas matemáticos de solidez, completitud y preservación inductiva (`AddPreserves`).<br>• **Modelo de Autómata UPPAAL** (`uppaal/`): 23 estados, 529 transiciones, 9 consultas TCTL satisfechas sin deadlock.<br>• **Biblioteca TypeScript** (`src/`): Analizador sintáctico estricto (`parser.ts`), adaptadores seguros (`wrappers.ts`), explicador de testigos (`explain.ts`), operaciones en lote (`batch.ts`).<br>• **Paquete npm**: `@grupo1/abac-verifier` ejecutable en navegador y Node.js.<br>• **Fixtures y Banco de Pruebas** (`fixtures/`, `test/`): Casos reales de urgencia médica, pruebas de regresión y reproducción de contraejemplos. |

---

## 3. Estrategia Narrativa y Descomposición MECE

Para que la audiencia y el jurado comprendan de forma inmediata y empaticen con el valor del proyecto, la narrativa sigue la estructura recomendada:

```
[1. Dolor Humano y Operativo]
       │
       ▼
[2. La Solución por Construcción]
       │
       ▼
[3. Descomposición MECE del Problema y Coherencia]
       ├── P1: Consistencia (Sin contradicción Permiso vs Denegación)
       ├── P2: Satisfacibilidad (Sin directivas vacías o muertas)
       ├── P3: No-Sombreado (Sin directivas redundantes o enmascaradas)
       └── P4: Validez de Esquema (Tipos, identificadores y rangos acotados)
       │
       ▼
[4. Demostración y Garantías Matemáticas (Dafny + UPPAAL + TypeScript)]
       │
       ▼
[5. Impacto y Conclusiones]
```

---

## 4. Lineamientos de Diseño de Diapositivas

1. **Minimalismo riguroso**:
   - Fondo blanco puro con toques de gris suave (`#E7E6E6`).
   - Encabezado institucional en azul marino formal (`#44546A`) con logos oficiales de EPIS y UNSA.
   - Pie de página sobrio con título del proyecto y numeración de página.
   - Acentos cromáticos controlados: azul institucional (`#5B9BD5`) y naranja de alerta/énfasis (`#ED7D31`).
2. **Baja densidad de texto**:
   - Cero texto amontonado. Una sola idea de alto impacto por diapositiva.
   - Prohibido el uso de etiquetas diagnósticas o explicaciones entre paréntesis en las diapositivas.
   - Tipografía limpia, moderna y legible (DM Sans + JetBrains Mono).
3. **Autocontención**:
   - Cada diapositiva debe entenderse por sí misma mediante diagramas visuales y relaciones directas.
4. **Dominio de diagramas y visuales reales**:
   - Uso de diagramas arquitectónicos, autómatas, fases de comprobación y capturas de consola del proyecto real.

---

## 5. Distribución del Video (7 Minutos — 4 Personas)

- **Total disponible**: 420 segundos (7:00 minutos).
- **Segmento 1 (Mariel Jara — ~100 s)**: El Dolor en entornos críticos (salud, educación), fallas silenciosas en políticas ABAC, y formulación del problema.
- **Segmento 2 (Luis Sequeiros — ~105 s)**: La Solución por construcción (CbC), arquitectura integral en 3 capas, y descomposición MECE (las 4 propiedades de coherencia P1–P4).
- **Segmento 3 (Yenaro Noa — ~110 s)**: Demostración deductiva en Dafny (lemas de preservación) y verificación de concurrencia y ausencia de bloqueos en UPPAAL (9 consultas TCTL).
- **Segmento 4 (Christian Mestas — ~105 s)**: Capa defensiva en TypeScript, paquete npm `@grupo1/abac-verifier`, demostración en vivo con casos de urgencia médica y conclusiones.
