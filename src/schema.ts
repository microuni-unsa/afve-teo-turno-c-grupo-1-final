import { createRequire } from "node:module";
import BigNumber from "bignumber.js";
import {
  DomainError,
  InvariantViolation,
  SchemaError,
  TooLarge,
} from "#src/errors.js";

// ---- Dafny FFI types ----
// The Dafny compiler emits an untyped JS module. These interfaces describe
// exactly the members the wrappers touch; the single unchecked cast below
// is the only place compiler knowledge is assumed.

/** A Dafny-compiled object value (datatype instance). Fields are read via df* helpers. */
export type DfObj = Record<string, unknown>;

export interface DfSeq extends Array<unknown> {
  toVerbatimString(asLiteral: boolean): string;
}

type DfCtors = Record<string, (...args: unknown[]) => DfObj>;
type DfApi = Record<string, (...args: unknown[]) => unknown>;

interface DfDafny {
  Seq: {
    of(...items: unknown[]): DfSeq;
    UnicodeFromString(s: string): DfSeq;
  };
  ZERO: BigNumber;
}

interface VerifierRoot {
  _dafny: DfDafny;
  Schema: {
    __default: DfApi;
    AttrDecl: DfCtors;
    AttrType: DfCtors;
    Value: DfCtors;
  };
  Syntax: { __default: DfApi; Pred: DfCtors; Rule: DfCtors; Effect: DfCtors };
  Eval: { __default: DfApi };
  Coherence: { __default: DfApi };
  Transition: { __default: DfApi };
}

const require = createRequire(import.meta.url);

function loadVerifier(): VerifierRoot {
  let raw: unknown;
  try {
    raw = require("../dist/verifier.cjs");
  } catch {
    try {
      raw = require("./verifier.cjs");
    } catch (errDist) {
      throw new Error(
        `Dafny core not found (run \`bun run build:dafny\` first): ${String(errDist)}`,
      );
    }
  }
  // Single unchecked cast: Dafny emits untyped JS; the VerifierRoot
  // interface pins the exact members used, checked by df* readers.
  return raw as unknown as VerifierRoot;
}

/** The Dafny-compiled core. All Satisfies / Applies / Coherent / Try* decisions run here. */
export const verifier: VerifierRoot = loadVerifier();

function isDfSeq(v: unknown): v is DfSeq {
  return (
    Array.isArray(v) &&
    typeof (v as { toVerbatimString?: unknown }).toVerbatimString === "function"
  );
}

export function asDfObj(v: unknown, what: string): DfObj {
  if (typeof v !== "object" || v === null) {
    throw new InvariantViolation(`Dafny ${what} is not an object`);
  }
  return v as Record<string, unknown>;
}

export function dfBool(obj: DfObj, field: string): boolean {
  const v: unknown = obj[field];
  if (typeof v !== "boolean") {
    throw new InvariantViolation(`Dafny field '${field}' is not a boolean`);
  }
  return v;
}

function dfSeq(obj: DfObj, field: string): DfSeq {
  const v: unknown = obj[field];
  if (!isDfSeq(v)) {
    throw new InvariantViolation(`Dafny field '${field}' is not a sequence`);
  }
  return v;
}

function dfBigNumber(v: unknown, what: string): BigNumber {
  if (!(v instanceof BigNumber)) {
    throw new InvariantViolation(`Dafny ${what} is not an integer`);
  }
  return v;
}

function dfNum(obj: DfObj, field: string): number {
  return dfBigNumber(obj[field], `field '${field}'`).toNumber();
}

export const MAX_ENUM_VALUES = 16;
export const MAX_RULES_CHECKED = 64;
export const DEFAULT_INT_MIN = 0;
export const DEFAULT_INT_MAX = 100;
/** Upper bound on |AllRequests| admitted without the unsafe opt-in. */
export const MAX_REQUEST_SPACE = 1000000;

export type AttrType = "Enum" | "Bool" | "BoundedInt";

export interface AttrDeclInput {
  family: string;
  name: string;
  type: AttrType;
  values?: string[];
  lo?: number;
  hi?: number;
}

export interface AttrDecl {
  family: string;
  name: string;
  type: AttrType;
  values: string[];
  lo: number;
  hi: number;
}

export interface Schema {
  decls: AttrDecl[];
  /** Opaque handle to the Dafny-compiled schema value. */
  dafnySchema: DfSeq;
}

export type Effect = "Permit" | "Deny";

export type CmpOp = "==" | "!=" | "<" | "<=" | ">" | ">=";

export type Pred =
  | {
      kind: "atom";
      family: string;
      attr: string;
      op: CmpOp;
      lit: string;
      num: number;
    }
  | { kind: "not"; p: Pred }
  | { kind: "and"; a: Pred; b: Pred }
  | { kind: "or"; a: Pred; b: Pred };

export interface Rule {
  /** 0 means unassigned; tryAdd assigns the next free id on commit. */
  id: number;
  effect: Effect;
  target: Pred;
}

export type Ruleset = Rule[];

/** Total assignment keyed by `family.name`. Values are validated at the boundary. */
export type Request = Record<string, string | boolean | number>;

export type FailedProperty = "P1" | "P2" | "P3" | "P4";

export interface Witness {
  req: Request;
  ruleIds: number[];
  failedProperty: FailedProperty;
  explanation: string;
}

export type AddResult =
  | { status: "Accepted"; ruleset: Ruleset }
  | { status: "Rejected"; witness: Witness };

export interface CoherenceReport {
  coherent: boolean;
  perProperty: { P1: boolean; P2: boolean; P3: boolean; P4: boolean };
  witness?: Witness;
}

export interface Evaluation {
  decision: "Permit" | "Deny";
  firingRuleIds: number[];
}

export interface Opts {
  allowUnbounded?: boolean;
}

export function attrKey(family: string, name: string): string {
  return `${family}.${name}`;
}

export function findDecl(
  schema: Schema,
  family: string,
  name: string,
): AttrDecl | undefined {
  return schema.decls.find((d) => d.family === family && d.name === name);
}

// ---- Dafny value construction (TS -> Dafny) ----

export function S(s: string): DfSeq {
  return verifier._dafny.Seq.UnicodeFromString(s);
}

export function jsStr(seq: DfSeq): string {
  return seq.toVerbatimString(false);
}

export function N(n: number): BigNumber {
  return new BigNumber(n);
}

function toDafnyAttrType(t: AttrType): DfObj {
  if (t === "Enum") return verifier.Schema.AttrType.create_Enum();
  if (t === "Bool") return verifier.Schema.AttrType.create_Bool();
  return verifier.Schema.AttrType.create_BoundedInt();
}

export function toDafnySchema(decls: AttrDecl[]): DfSeq {
  return verifier._dafny.Seq.of(
    ...decls.map((d) =>
      verifier.Schema.AttrDecl.create_AttrDecl(
        S(d.family),
        S(d.name),
        toDafnyAttrType(d.type),
        verifier._dafny.Seq.of(...d.values.map(S)),
        N(d.lo),
        N(d.hi),
      ),
    ),
  );
}

export function toDafnyPred(p: Pred): DfObj {
  switch (p.kind) {
    case "atom":
      return verifier.Syntax.Pred.create_Atom(
        S(p.family),
        S(p.attr),
        S(p.op),
        S(p.lit),
        N(p.num),
      );
    case "not":
      return verifier.Syntax.Pred.create_Not(toDafnyPred(p.p));
    case "and":
      return verifier.Syntax.Pred.create_And(
        toDafnyPred(p.a),
        toDafnyPred(p.b),
      );
    case "or":
      return verifier.Syntax.Pred.create_Or(toDafnyPred(p.a), toDafnyPred(p.b));
  }
}

export function toDafnyRule(rule: Rule): DfObj {
  const effect =
    rule.effect === "Permit"
      ? verifier.Syntax.Effect.create_Permit()
      : verifier.Syntax.Effect.create_Deny();
  return verifier.Syntax.Rule.create_Rule(
    N(rule.id),
    effect,
    toDafnyPred(rule.target),
  );
}

export function toDafnyRuleset(ruleset: Ruleset): DfSeq {
  return verifier._dafny.Seq.of(...ruleset.map(toDafnyRule));
}

/** Positional Dafny request aligned with schema.decls order. Rejects out-of-domain input. */
export function toDafnyRequest(request: Request, schema: Schema): DfSeq {
  const known: Record<string, true> = {};
  for (const d of schema.decls) {
    known[attrKey(d.family, d.name)] = true;
  }
  for (const key of Object.keys(request)) {
    if (known[key] !== true) {
      throw new DomainError(`unknown attribute '${key}'`);
    }
  }
  const values = schema.decls.map((d) => {
    const key = attrKey(d.family, d.name);
    const v: unknown = request[key];
    if (v === undefined) {
      throw new DomainError(`missing value for '${key}'`);
    }
    if (d.type === "Enum") {
      if (typeof v !== "string" || !d.values.includes(v)) {
        throw new DomainError(
          `'${key}' must be one of [${d.values.join(", ")}], got ${JSON.stringify(v)}`,
        );
      }
      return verifier.Schema.Value.create_EnumVal(S(v));
    }
    if (d.type === "Bool") {
      if (typeof v !== "boolean") {
        throw new DomainError(
          `'${key}' must be a boolean, got ${JSON.stringify(v)}`,
        );
      }
      return verifier.Schema.Value.create_BoolVal(v);
    }
    if (typeof v !== "number" || !Number.isInteger(v) || v < d.lo || v > d.hi) {
      throw new DomainError(
        `'${key}' must be an integer in [${d.lo}, ${d.hi}], got ${JSON.stringify(v)}`,
      );
    }
    return verifier.Schema.Value.create_IntVal(N(v));
  });
  return verifier._dafny.Seq.of(...values);
}

// ---- Dafny value reading (Dafny -> TS) ----

export function fromDafnyValue(dv: unknown): string | boolean | number {
  const obj = asDfObj(dv, "value");
  if (dfBool(obj, "is_EnumVal")) return jsStr(dfSeq(obj, "dtor_s"));
  if (dfBool(obj, "is_BoolVal")) return dfBool(obj, "dtor_b");
  return dfNum(obj, "dtor_n");
}

export function fromDafnyPred(dp: unknown): Pred {
  const obj = asDfObj(dp, "predicate");
  if (dfBool(obj, "is_Atom")) {
    const op = jsStr(dfSeq(obj, "dtor_op"));
    if (
      op !== "==" &&
      op !== "!=" &&
      op !== "<" &&
      op !== "<=" &&
      op !== ">" &&
      op !== ">="
    ) {
      throw new InvariantViolation(`unknown operator '${op}'`);
    }
    return {
      kind: "atom",
      family: jsStr(dfSeq(obj, "dtor_family")),
      attr: jsStr(dfSeq(obj, "dtor_attr")),
      op,
      lit: jsStr(dfSeq(obj, "dtor_lit")),
      num: dfNum(obj, "dtor_num"),
    };
  }
  if (dfBool(obj, "is_Not"))
    return { kind: "not", p: fromDafnyPred(obj.dtor_p) };
  if (dfBool(obj, "is_And"))
    return {
      kind: "and",
      a: fromDafnyPred(obj.dtor_a),
      b: fromDafnyPred(obj.dtor_b),
    };
  return {
    kind: "or",
    a: fromDafnyPred(obj.dtor_a),
    b: fromDafnyPred(obj.dtor_b),
  };
}

export function fromDafnyRule(dr: unknown): Rule {
  const obj = asDfObj(dr, "rule");
  return {
    id: dfNum(obj, "dtor_id"),
    effect: dfBool(asDfObj(obj.dtor_effect, "effect"), "is_Permit")
      ? "Permit"
      : "Deny",
    target: fromDafnyPred(obj.dtor_target),
  };
}

export function fromDafnyRuleset(druleset: unknown): Ruleset {
  if (!isDfSeq(druleset)) {
    throw new InvariantViolation("Dafny ruleset is not a sequence");
  }
  return druleset.map(fromDafnyRule);
}

export function fromDafnyRequest(dreq: unknown, schema: Schema): Request {
  if (!isDfSeq(dreq)) {
    throw new InvariantViolation("Dafny request is not a sequence");
  }
  // P2/P4 witnesses carry an empty request (the violation concerns a rule,
  // not a request); P1/P3 witnesses always carry a full positional request.
  if (dreq.length === 0) return {};
  if (dreq.length !== schema.decls.length) {
    throw new InvariantViolation(
      `Dafny request has length ${dreq.length} for ${schema.decls.length} attributes`,
    );
  }
  const out: Request = {};
  for (let i = 0; i < schema.decls.length; i++) {
    out[attrKey(schema.decls[i].family, schema.decls[i].name)] = fromDafnyValue(
      dreq[i],
    );
  }
  return out;
}

function asFailedProperty(s: string): FailedProperty {
  if (s === "P1" || s === "P2" || s === "P3" || s === "P4") return s;
  throw new InvariantViolation(`unknown failedProperty '${s}'`);
}

export function fromDafnyWitness(dw: unknown, schema: Schema): Witness {
  const obj = asDfObj(dw, "witness");
  return {
    req: fromDafnyRequest(obj.dtor_req, schema),
    ruleIds: dfSeq(obj, "dtor_ruleIds").map((x: unknown) =>
      dfBigNumber(x, "rule id").toNumber(),
    ),
    failedProperty: asFailedProperty(jsStr(dfSeq(obj, "dtor_failedProperty"))),
    explanation: jsStr(dfSeq(obj, "dtor_explanation")),
  };
}

// ---- Schema loading and caps ----

function validateDecl(raw: unknown, index: number): AttrDecl {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    throw new SchemaError(`declaration #${index} must be an object`);
  }
  if (
    !("family" in raw) ||
    typeof raw.family !== "string" ||
    raw.family === ""
  ) {
    throw new SchemaError(`declaration #${index} needs a non-empty family`);
  }
  if (!("name" in raw) || typeof raw.name !== "string" || raw.name === "") {
    throw new SchemaError(`declaration #${index} needs a non-empty name`);
  }
  if (
    !("type" in raw) ||
    (raw.type !== "Enum" && raw.type !== "Bool" && raw.type !== "BoundedInt")
  ) {
    throw new SchemaError(`declaration #${index} has unknown type`);
  }
  const family: string = raw.family;
  const name: string = raw.name;
  if (raw.type === "Enum") {
    if (
      !("values" in raw) ||
      !Array.isArray(raw.values) ||
      raw.values.length === 0
    ) {
      throw new SchemaError(
        `Enum '${family}.${name}' needs a non-empty values array`,
      );
    }
    const values: string[] = [];
    for (const v of raw.values) {
      if (typeof v !== "string" || v === "") {
        throw new SchemaError(
          `Enum '${family}.${name}' has an invalid value ${JSON.stringify(v)}`,
        );
      }
      values.push(v);
    }
    if (new Set(values).size !== values.length) {
      throw new SchemaError(`Enum '${family}.${name}' has duplicate values`);
    }
    if ("lo" in raw || "hi" in raw) {
      throw new SchemaError(`Enum '${family}.${name}' takes no lo/hi bounds`);
    }
    return { family, name, type: "Enum", values, lo: 0, hi: 0 };
  }
  if ("values" in raw) {
    throw new SchemaError(
      `'${family}.${name}' of type ${raw.type} takes no values array`,
    );
  }
  if (raw.type === "Bool") {
    if ("lo" in raw || "hi" in raw) {
      throw new SchemaError(`Bool '${family}.${name}' takes no lo/hi bounds`);
    }
    return { family, name, type: "Bool", values: [], lo: 0, hi: 0 };
  }
  let lo: number = DEFAULT_INT_MIN;
  let hi: number = DEFAULT_INT_MAX;
  if ("lo" in raw) {
    if (typeof raw.lo !== "number" || !Number.isInteger(raw.lo)) {
      throw new SchemaError(
        `BoundedInt '${family}.${name}' needs an integer lo`,
      );
    }
    lo = raw.lo;
  }
  if ("hi" in raw) {
    if (typeof raw.hi !== "number" || !Number.isInteger(raw.hi)) {
      throw new SchemaError(
        `BoundedInt '${family}.${name}' needs an integer hi`,
      );
    }
    hi = raw.hi;
  }
  if (lo > hi) {
    throw new SchemaError(`BoundedInt '${family}.${name}' has lo > hi`);
  }
  return { family, name, type: "BoundedInt", values: [], lo, hi };
}

export function loadSchema(decls: unknown, opts?: Opts): Schema {
  if (!Array.isArray(decls)) {
    throw new SchemaError("schema must be an array of attribute declarations");
  }
  if (decls.length === 0) {
    throw new SchemaError("schema must declare at least one attribute");
  }
  const parsed = decls.map((d, i) => validateDecl(d, i));
  const seen: Record<string, true> = {};
  for (const d of parsed) {
    const key = attrKey(d.family, d.name);
    if (seen[key] === true) {
      throw new SchemaError(`duplicate attribute '${key}'`);
    }
    seen[key] = true;
  }
  const unbounded = opts?.allowUnbounded === true;
  const overEnum = parsed.find(
    (d) => d.type === "Enum" && d.values.length > MAX_ENUM_VALUES,
  );
  if (overEnum !== undefined && !unbounded) {
    throw new TooLarge(
      MAX_ENUM_VALUES,
      overEnum.values.length,
      `Enum domain '${attrKey(overEnum.family, overEnum.name)}'`,
    );
  }
  let space = 1;
  for (const d of parsed) {
    space *=
      d.type === "Enum"
        ? d.values.length
        : d.type === "Bool"
          ? 2
          : d.hi - d.lo + 1;
    if (space > MAX_REQUEST_SPACE) break;
  }
  if (space > MAX_REQUEST_SPACE && !unbounded) {
    throw new TooLarge(MAX_REQUEST_SPACE, space, "Request space |AllRequests|");
  }
  if ((overEnum !== undefined || space > MAX_REQUEST_SPACE) && unbounded) {
    console.warn(
      "[abac-verifier] unverified-performance: schema exceeds verified caps; exact decision, unbounded cost.",
    );
  }
  return { decls: parsed, dafnySchema: toDafnySchema(parsed) };
}

/** Guard enumerating entry points (tryAdd/tryUpdate/tryAddMany/checkCoherent). */
export function checkCaps(
  ruleCount: number,
  schema: Schema,
  opts: Opts | undefined,
  what: string,
): void {
  const unbounded = opts?.allowUnbounded === true;
  const overRules = ruleCount > MAX_RULES_CHECKED;
  const overEnumDecl = schema.decls.find(
    (d) => d.type === "Enum" && d.values.length > MAX_ENUM_VALUES,
  );
  if (!overRules && overEnumDecl === undefined) return;
  if (!unbounded) {
    if (overRules) {
      throw new TooLarge(MAX_RULES_CHECKED, ruleCount, `${what} ruleset size`);
    }
    if (overEnumDecl !== undefined) {
      throw new TooLarge(
        MAX_ENUM_VALUES,
        overEnumDecl.values.length,
        `Enum domain '${attrKey(overEnumDecl.family, overEnumDecl.name)}'`,
      );
    }
    throw new InvariantViolation(
      `checkCaps reached with no violated cap in ${what}`,
    );
  }
  console.warn(
    `[abac-verifier] unverified-performance: ${what} exceeds verified caps; exact decision, unbounded cost.`,
  );
}
