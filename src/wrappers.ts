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

export function remove(ruleset: Ruleset, id: number, schema: Schema): Ruleset {
  void schema;
  const raw = verifier.Transition.__default.TryRemove(
    toDafnyRuleset(ruleset),
    N(id),
  );
  return fromDafnyRuleset(raw);
}

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
