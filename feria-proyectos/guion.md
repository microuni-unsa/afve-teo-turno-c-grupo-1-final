# Guion de Presentación — Feria de Proyectos UNSA 2026

- **Duración máxima:** 7 minutos (~420 s)
- **Equipo:** 4 integrantes
- **Presentación:** 14 láminas (`feria-proyectos/slides/presentacion.html`)

---

## Segmento 1 — Mariel Alisson Jara Mamani (Slides 1–3)

### Slide 1 — Portada

Buenos días, miembros del jurado. Soy Mariel Jara y, junto con Luis Sequeiros, Yenaro Noa y Christian Mestas, asesorados por la profesora Maribel Molina Barriga de Ingeniería de Sistemas de la Universidad Nacional de San Agustín, presentamos: Verificación formal de coherencia en políticas ABAC.

### Slide 2 — ¿Qué es ABAC y por qué falla manualmente?

En hospitales, universidades y entidades públicas, el control de acceso decide quién consulta o modifica información sensible. El modelo basado en atributos, o ABAC (estandarizado en NIST 800-162 y 800-192), evalúa 4 aspectos por solicitud: sujeto, recurso, acción y entorno. Por ejemplo, autoriza a un médico de nivel 4 o más a leer historias de sensibilidad 3 o menor, y bloquea la escritura sensible para niveles 2 o menores.

El problema aparece al editar reglas a mano cada día y surgen 3 fallas silenciosas: una regla de emergencia choca con un bloqueo nocturno desde las 18:00; exigir nivel mayor a 5 y menor a 2 en una escala de 1 a 5 crea una regla muerta; y añadir cardiología bajo una regla general médica deja la nueva regla tapada. Con 64 800 combinaciones posibles, probar casos sueltos oculta conflictos hasta producción.

### Slide 3 — Propiedades de coherencia (P1–P4)

Por eso exigimos 4 propiedades conjuntas tras cada cambio: consistencia, para que ninguna solicitud active permiso y denegación a la vez; satisfacibilidad, para que toda regla sirva al menos en un caso válido; no sombreado, para que cada regla decida al menos una solicitud por sí sola; y validez de esquema, para aceptar solo atributos declarados, operadores válidos y valores en rango.

---

## Segmento 2 — Luis Gustavo Sequeiros Condori (Slides 4–7)

### Slide 4 — Objetivos y alcance del proyecto

Gracias, Mariel. Soy Luis Sequeiros. Nuestro objetivo es construir un verificador ABAC demostrado en Dafny y validado en UPPAAL que opere sin motores lógicos externos en producción. Cubrimos listas cerradas, booleanos y enteros acotados en los 4 aspectos del estándar NIST, con operaciones seguras para agregar, editar, borrar, cargar lotes y evaluar solicitudes, fijando límites máximos de tamaño para garantizar respuestas exactas y predecibles.

### Slide 5 — Comparativa con trabajo previo

Frente a trabajos previos —como analizadores sobre XACML, Mohawk o AWS Zelkova, que requieren motores externos activos en cada revisión, o Cedar, que no verifica automáticamente la coherencia global tras cada cambio—, aplicamos corrección por construcción: demostramos la seguridad antes de compilar, ejecutamos sin motores externos y entregamos el ejemplo exacto cuando una regla falla.

### Slide 6 — Metodología CbC y herramientas formales

Metodológicamente seguimos 5 fases de corrección por construcción: modelar reglas y solicitudes, demostrar las 4 propiedades y la preservación ante cambios, explorar rutas sobre un caso fijo, compilar el núcleo a JavaScript y trazar casos guiados. Usamos Dafny 4.11 con Z3 y cvc5 solo en diseño, UPPAAL 5.0, estándares NIST y XACML 3.0, y TypeScript.

### Slide 7 — Arquitectura y frontera de ejecución

En la arquitectura separamos estrictamente el núcleo matemático de la capa externa. Los 5 módulos operacionales de Dafny compilan a JavaScript, dejando el chequeo finito solo para pruebas. Afuera, una capa mínima en TypeScript valida formatos, traduce reglas y redacta mensajes claros de error, sin tomar jamás decisiones lógicas propias.

---

## Segmento 3 — Yenaro Joel Noa Camino (Slides 8–11)

### Slide 8 — Fases de verificación (P1 a P4)

Gracias, Luis. Soy Yenaro Noa. Al verificar una política, el sistema revisa las 4 propiedades en orden fijo: consistencia, satisfacibilidad, no sombreado y validez de esquema. Apenas halla un fallo en cualquier etapa, se detiene de inmediato y devuelve el primer caso concreto que lo demuestra.

### Slide 9 — ¿Cómo garantiza Dafny la corrección?

Dafny respalda esto con 114 objetivos demostrados sin errores en 59 teoremas, probando 5 garantías prácticas: toda regla agregada o editada que entra mantiene la coherencia desde una política vacía válida; borrar reglas siempre es seguro; al evaluar solicitudes jamás chocan permiso y denegación; todo rechazo muestra un fallo real sin omitir errores; y un chequeo exhaustivo verifica las 259 combinaciones finitas de hasta 3 reglas.

### Slide 10 — UPPAAL: modelo y caso fijo

Complementamos Dafny con UPPAAL 5.0 para recorrer todas las rutas del flujo administrativo sobre un caso clínico fijo: 16 solicitudes —combinando 2 roles, 2 acciones, horarios de 08:00 y 18:00, y 2 estados de emergencia— frente a 10 reglas, hasta 3 activas, con casos limpios y fallos. Evaluando cambios de forma atómica antes de guardar, sin temporizadores externos, exploró 23 estados estables, 470 evaluaciones y 529 transiciones sin bloqueos.

### Slide 11 — UPPAAL: las 9 consultas TCTL

Comprobamos 9 consultas temporales en UPPAAL, todas cumplidas. En seguridad, 3 de 3 probaron que la política siempre sigue válida, sin bloqueos ni daños al borrar reglas, tardando 16.7 segundos en coherencia y 28.7 en ausencia de bloqueos. En alcance, 6 de 6 confirmaron que la política limpia de 3 reglas se aprueba, que todo rechazo es alcanzable y que el sistema evoluciona continuamente.

---

## Segmento 4 — Christian Raul Mestas Zegarra (Slides 12–14)

### Slide 12 — Caso guiado I: choque y solución

Gracias, Yenaro. Soy Christian Mestas, y veamos 2 casos clínicos paso a paso. Primero, partiendo de una política vacía, aceptamos la regla #1 que permite acceso en emergencia. Al intentar añadir la regla #2 que deniega desde las 18:00, el verificador halla un choque exacto —un médico leyendo a las 18:00 en emergencia— y la rechaza dejando intacta la #1. Luego corregimos el diseño en 3 reglas: #1 permite leer a médicos, #2 bloquea escritura sensible con nivel 2 o menor, y #3 permite leer en emergencia. Así, una enfermera leyendo a las 03:00 en emergencia recibe permiso por la #3.

### Slide 13 — Casos guiados II: fallos y garantías

También bloqueamos otros 3 fallos reales antes de guardar: una regla muerta con nivel mayor a 5 y menor a 2, imposible en las 64 800 solicitudes de 1 a 5; una regla sombreada para cardiología bajo la general de médicos; y editar una regla #99 inexistente o con datos fuera de esquema. Así, Dafny garantiza la coherencia matemática, UPPAAL valida el flujo administrativo, producción evalúa directo sin motores externos, y las pruebas de repetición confirman que la interfaz reproduce fielmente los mismos ejemplos de fallo.

### Slide 14 — Cierre: Gracias…

Cerramos con la frase de Anthony Hall y Roderick Chapman: debemos construir software correcto por construcción, y no software incierto hasta después de entregarlo. Desde la UNSA entregamos un verificador demostrado, abierto en nuestro repositorio y listo para sistemas críticos. Muchas gracias.
