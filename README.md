# Verificador Formal de Coherencia en Políticas ABAC

Implementación y verificación formal bajo el paradigma de **Corrección por Construcción (CbC)** de un verificador de coherencia para políticas de control de acceso basado en atributos (**ABAC**), especificado y demostrado deductivamente en **Dafny**, validado mediante *model checking* en **UPPAAL** y compilado a **JavaScript** sin motores SMT en tiempo de ejecución.

- **Institución:** Escuela Profesional de Ingeniería de Sistemas — Universidad Nacional de San Agustín de Arequipa (UNSA)
- **Docente asesor:** Maribel Molina Barriga
- **Integrantes (Grupo 1):**
  - Mariel Alisson Jara Mamani
  - Luis Gustavo Sequeiros Condori
  - Yenaro Joel Noa Camino
  - Christian Raul Mestas Zegarra
- **Video de presentación final (Google Drive):** <https://drive.google.com/file/d/1KE4ritVUWolGW2XTkr3XbGNCnfplgZ14/view?usp=sharing>

---

## Guía rápida de verificación y ejecución

### 1. Requisitos e entorno reproducible

El proyecto incluye un entorno Nix reproducible en [`flake.nix`](flake.nix) con Dafny 4.11, UPPAAL 5.0, Bun, Node.js y Typst 0.15.1:

```bash
nix develop
```

### 2. Verificar la especificación formal en Dafny

Ejecute el verificador deductivo sobre los seis módulos formales:

```bash
dafny verify dafny/Schema.dfy dafny/Syntax.dfy dafny/Eval.dfy dafny/Coherence.dfy dafny/Transition.dfy dafny/BoundedCheck.dfy
```

Resultado esperado: `Dafny program verifier finished with 114 verified, 0 errors`.

### 3. Validar el modelo de estados en UPPAAL

1. Abra UPPAAL 5.0 (`uppaal`).
2. Cargue el modelo [`uppaal/abac-guard.xml`](uppaal/abac-guard.xml) y el archivo de consultas [`uppaal/abac-guard.q`](uppaal/abac-guard.q).
3. Ejecute **Check** en la pestaña *Verifier* para comprobar las 9 propiedades TCTL (3 de seguridad y 6 de alcance).

### 4. Compilar el núcleo formal a JavaScript y ejecutar las pruebas

```bash
bun install --frozen-lockfile
bun run build
bun test
```

- `bun run build` compila los cinco módulos operacionales (`Schema`, `Syntax`, `Eval`, `Coherence`, `Transition`) a `dist/verifier.cjs` y transpila la frontera TypeScript hacia `dist/`.
- `bun test` ejecuta las pruebas de análisis sintáctico, envolturas y repetición (*replay*) de escenarios clínicos (`27` pruebas en `3` archivos).

### 5. Compilar el artículo IEEE

```bash
typst compile paper/paper.typ paper/paper.pdf
```

---

## Propiedades formales verificadas

Una política $R$ es coherente (`Coherent(R, schema)`) si y solo si satisface simultáneamente:

1. **P1 — Consistencia:** ninguna solicitud válida activa a la vez una regla `Permit` y una regla `Deny`.
2. **P2 — Satisfacibilidad:** toda regla se activa para al menos una solicitud válida del esquema (sin reglas muertas).
3. **P3 — No sombreado:** toda regla decide en solitario al menos una solicitud válida (detecta reglas tapadas y duplicadas).
4. **P4 — Validez de esquema:** toda regla referencia únicamente atributos declarados, operadores válidos y literales dentro de dominio.

Ante cualquier rechazo, las operaciones guardadas (`TryAdd`, `TryUpdate`, `TryRemove`) devuelven un testigo mínimo (`Witness`) con la solicitud contraejemplo, las reglas implicadas y la propiedad vulnerada, dejando el conjunto confirmado intacto.

---

## Estructura del repositorio

| Ruta | Contenido |
|---|---|
| [`dafny/`](dafny/) | Especificación formal y demostraciones en Dafny (`Schema.dfy`, `Syntax.dfy`, `Eval.dfy`, `Coherence.dfy`, `Transition.dfy`, `BoundedCheck.dfy`). |
| [`uppaal/`](uppaal/) | Autómata finito `Admin` (`abac-guard.xml`) y las 9 consultas TCTL (`abac-guard.q`). |
| [`src/`](src/) | Frontera mínima en TypeScript (`schema.ts`, `parser.ts`, `wrappers.ts`, `batch.ts`, `explain.ts`, `errors.ts`, `index.ts`). |
| [`test/`](test/) | Pruebas de conformidad sintáctica, contratos de envoltura y *replay* de escenarios (`parser.test.ts`, `wrappers.test.ts`, `replay.test.ts`). |
| [`fixtures/`](fixtures/) | Esquema clínico [`schema-v1.json`](fixtures/schema-v1.json) (`64 800` solicitudes) y escenarios (`clean.json`, `emergency-override.json`, `contradictory.json`, `shadowed.json`, `unsatisfiable.json`). |
| [`paper/`](paper/) | Código fuente Typst en formato IEEE (`paper.typ`, `ieee.typ`, `refs.bib`, figuras) y documento compilado [`paper.pdf`](paper/paper.pdf). |
| [`feria-proyectos/`](feria-proyectos/) | Diapositivas en HTML/PDF basadas en la plantilla institucional (`slides/`), guion de exposición (`guion.md`) y bases (`recursos/`). |
| [`SPEC.md`](SPEC.md) | Especificación técnica del diseño formal y alcance del lenguaje. |

---

## Módulos y teoremas principales en Dafny

- **`dafny/Schema.dfy`**: define `AttrDecl`, `Value`, `ValidRequest` y la enumeración cartesiana `AllRequests`, con los lemas de solidez (`AllRequestsSound`) y completitud (`AllRequestsComplete`).
- **`dafny/Syntax.dfy`**: define `Effect`, `Pred`, `Rule`, `Ruleset`, `ValidRule`, `RemoveById` y `RemoveByIdSubset`.
- **`dafny/Eval.dfy`**: semántica denotacional pura (`Satisfies`, `Applies`, `Evaluate` con decisiones `Permit`, `Deny` y estado interno `Conflict`).
- **`dafny/Coherence.dfy`**: definiciones de `P1..P4`, `Coherent`, chequeos ejecutables `CheckCoherent` y demostraciones `CheckCoherentSound`, `CheckCoherentGenuine` y `CheckCoherentComplete`.
- **`dafny/Transition.dfy`**: interfaz guardada `TryAdd`, `TryUpdate`, `TryRemove` y teoremas inductivos `EmptyCoherent`, `AddPreserves`, `UpdatePreserves`, `RemovePreservesCoherent`, `EvaluateAgreesOnCoherent`, `WitnessSoundness` y `WitnessCompleteness`.
- **`dafny/BoundedCheck.dfy`**: verificación finita exhaustiva (`BoundedModelCheck`) sobre `SmallStateCount = 259` conjuntos de hasta 3 reglas (excluido de la compilación JavaScript).
