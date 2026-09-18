import { InvariantViolation } from "#src/errors.js";
import {
  type AddResult,
  asDfObj,
  type CoherenceReport,
  checkCaps,
  dfBool,
  type Evaluation,
  fromDafnyRuleset,
  fromDafnyWitness,
  N,
  type Opts,
  type Request,
  type Rule,
  type Ruleset,
  type Schema,
  toDafnyRequest,
  toDafnyRule,
  toDafnyRuleset,
  verifier,
} from "#src/schema.js";

function nextRuleId(ruleset: Ruleset): number {
  let max = 0;
  for (const r of ruleset) {
    if (r.id > max) max = r.id;
  }
  return max + 1;
}

function fromDafnyAddResult(dres: unknown, schema: Schema): AddResult {
  const obj = asDfObj(dres, "add result");
  if (dfBool(obj, "is_Accepted")) {
    return { status: "Accepted", ruleset: fromDafnyRuleset(obj.ruleset) };
  }
  return { status: "Rejected", witness: fromDafnyWitness(obj.w, schema) };
}

function isCleanCheck(raw: unknown): boolean {
  return dfBool(asDfObj(raw, "check result"), "is_NoWitness");
}

/**
 * Guarded add: assigns the next free id and commits only if the extended
 * ruleset is coherent. Rejection leaves the input ruleset unchanged.
 */
export function tryAdd(
  ruleset: Ruleset,
  rule: Rule,
  schema: Schema,
  opts?: Opts,
): AddResult {
  checkCaps(ruleset.length + 1, schema, opts, "tryAdd");
  const id = nextRuleId(ruleset);
  const raw = verifier.Transition.__default.TryAdd(
    toDafnyRuleset(ruleset),
    toDafnyRule({ ...rule, id }),
    schema.dafnySchema,
  );
  return fromDafnyAddResult(raw, schema);
}

/** Guarded update of the rule with `id`; the replacement keeps that id. */
export function tryUpdate(
  ruleset: Ruleset,
  id: number,
  rule: Rule,
  schema: Schema,
  opts?: Opts,
): AddResult {
  checkCaps(ruleset.length, schema, opts, "tryUpdate");
  const raw = verifier.Transition.__default.TryUpdate(
    toDafnyRuleset(ruleset),
    N(id),
    toDafnyRule({ ...rule, id }),
    schema.dafnySchema,
  );
  return fromDafnyAddResult(raw, schema);
}

/** Removal preserves coherence (Transition.RemovePreservesCoherent). */
export function remove(ruleset: Ruleset, id: number, schema: Schema): Ruleset {
  void schema;
  const raw = verifier.Transition.__default.TryRemove(
    toDafnyRuleset(ruleset),
    N(id),
  );
  return fromDafnyRuleset(raw);
}

/** Full coherence verdict with independently-queried per-property badges. */
export function checkCoherent(
  ruleset: Ruleset,
  schema: Schema,
  opts?: Opts,
): CoherenceReport {
  checkCaps(ruleset.length, schema, opts, "checkCoherent");
  const dr = toDafnyRuleset(ruleset);
  const p1 = verifier.Coherence.__default.CheckP1(dr, schema.dafnySchema);
  const p2 = verifier.Coherence.__default.CheckP2(dr, schema.dafnySchema);
  const p3 = verifier.Coherence.__default.CheckP3(dr, schema.dafnySchema);
  const p4 = verifier.Coherence.__default.CheckP4(dr, schema.dafnySchema);
  const perProperty = {
    P1: isCleanCheck(p1),
    P2: isCleanCheck(p2),
    P3: isCleanCheck(p3),
    P4: isCleanCheck(p4),
  };
  // First failure in P1..P4 order is exactly the combined CheckCoherent
  // witness (same checks, same order); no fifth scan is needed.
  const first = [p1, p2, p3, p4].find((w) => !isCleanCheck(w));
  if (first === undefined) {
    return { coherent: true, perProperty };
  }
  return {
    coherent: false,
    perProperty,
    witness: fromDafnyWitness(asDfObj(first, "check result").wit, schema),
  };
}

/**
 * Single-request decision with firing-rule attribution (via Dafny Applies).
 * No caps: cost is linear in ruleset size, no request-space enumeration.
 * Throws InvariantViolation on the unreachable Conflict state.
 */
export function evaluate(
  ruleset: Ruleset,
  request: Request,
  schema: Schema,
): Evaluation {
  const dr = toDafnyRuleset(ruleset);
  const dreq = toDafnyRequest(request, schema);
  const obj = asDfObj(
    verifier.Eval.__default.Evaluate(dr, dreq, schema.dafnySchema),
    "decision",
  );
  if (dfBool(obj, "is_Conflict")) {
    throw new InvariantViolation(
      "Evaluate returned Conflict on a committed ruleset",
    );
  }
  const firingRuleIds: number[] = [];
  for (const rule of ruleset) {
    if (
      verifier.Eval.__default.Applies(
        dreq,
        toDafnyRule(rule),
        schema.dafnySchema,
      ) === true
    ) {
      firingRuleIds.push(rule.id);
    }
  }
  if (dfBool(obj, "is_Permit")) {
    return { decision: "Permit", firingRuleIds };
  }
  if (dfBool(obj, "is_Deny")) {
    return { decision: "Deny", firingRuleIds };
  }
  throw new InvariantViolation("Evaluate returned an unknown Decision");
}
