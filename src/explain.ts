import type { Witness } from "#src/schema.js";

/** Human-readable witness description (TS-side only; never a verifier decision). */
export function explain(witness: Witness): string {
  const req = Object.entries(witness.req)
    .map(([k, v]) => `${k}=${String(v)}`)
    .join(", ");
  const first = witness.ruleIds[0] ?? -1;
  switch (witness.failedProperty) {
    case "P1": {
      const second = witness.ruleIds[1] ?? -1;
      return `Permit rule #${first} and Deny rule #${second} both fire when ${req}.`;
    }
    case "P2":
      return `Rule #${first} never fires on any request.`;
    case "P3": {
      const covering = witness.ruleIds
        .slice(1)
        .map((id) => `#${id}`)
        .join(", ");
      return `Rule #${first} never alone decides a request (covered by ${covering} when ${req}).`;
    }
    case "P4":
      return `Rule #${first} is not a valid rule for this schema (unknown id or schema violation).`;
  }
}
