# @grupo1/abac-verifier

Formally verified ABAC coherence checker. Dafny decides; TypeScript wraps.

## API

- `loadSchema(decls)` — validate runtime JSON attribute declarations.
- `parseRule(src, schema)` — parse `Permit where <pred>` / `Deny where <pred>`.
- `tryAdd(ruleset, rule, schema, opts?)` — guarded add (`Accepted` | `Rejected` + witness).
- `tryUpdate(ruleset, id, rule, schema, opts?)` — guarded update.
- `remove(ruleset, id, schema)` — removal (preserves coherence).
- `tryAddMany(ruleset, rules, schema, opts?)` — all-or-nothing batch add.
- `checkCoherent(ruleset, schema, opts?)` — per-property `{ P1, P2, P3, P4 }` report.
- `evaluate(ruleset, request, schema)` — `Permit` | `Deny` plus firing rule ids.
- `evaluateMany(ruleset, requests, schema, opts?)` — order-preserving bulk evaluate.
- `explain(witness)` — human-readable witness description.

## Caps

- `MAX_ENUM_VALUES = 16`, `MAX_RULES_CHECKED = 64`, `MAX_REQUEST_SPACE = 1000000`.
- Over-cap calls return/throw `TooLarge` by default.
- `allowUnbounded: true` lifts caps on the same exact decision path with one
  `unverified-performance` console warning per call; verdicts stay exact.
