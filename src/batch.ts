import type {
  AddResult,
  Evaluation,
  Opts,
  Request,
  Rule,
  Ruleset,
  Schema,
} from "#src/schema.js";
import { checkCaps } from "#src/schema.js";
import { evaluate, tryAdd } from "#src/wrappers.js";

/**
 * All-or-nothing batch add: rules commit in order with sequential ids;
 * the first Rejected aborts and the input ruleset is returned unchanged.
 */
export function tryAddMany(
  ruleset: Ruleset,
  rules: Rule[],
  schema: Schema,
  opts?: Opts,
): AddResult {
  checkCaps(ruleset.length + rules.length, schema, opts, "tryAddMany");
  let current = ruleset;
  for (const rule of rules) {
    const res = tryAdd(current, rule, schema, opts);
    if (res.status === "Rejected") return res;
    current = res.ruleset;
  }
  return { status: "Accepted", ruleset: current };
}

/**
 * Order-preserving bulk evaluate. No caps: per-request cost is linear,
 * with no request-space enumeration.
 */
export function evaluateMany(
  ruleset: Ruleset,
  requests: Request[],
  schema: Schema,
): Evaluation[] {
  return requests.map((req) => evaluate(ruleset, req, schema));
}
