export { evaluateMany, tryAddMany } from "#src/batch.js";
export {
  DomainError,
  InvariantViolation,
  ParseError,
  SchemaError,
  TooLarge,
} from "#src/errors.js";
export { explain } from "#src/explain.js";
export { parseRule } from "#src/parser.js";
export type {
  AddResult,
  AttrDecl,
  AttrDeclInput,
  CmpOp,
  CoherenceReport,
  Effect,
  Evaluation,
  FailedProperty,
  Opts,
  Pred,
  Request,
  Rule,
  Ruleset,
  Schema,
  Witness,
} from "#src/schema.js";
export {
  attrKey,
  checkCaps,
  DEFAULT_INT_MAX,
  DEFAULT_INT_MIN,
  findDecl,
  loadSchema,
  MAX_ENUM_VALUES,
  MAX_REQUEST_SPACE,
  MAX_RULES_CHECKED,
} from "#src/schema.js";
export {
  checkCoherent,
  evaluate,
  remove,
  tryAdd,
  tryUpdate,
} from "#src/wrappers.js";
