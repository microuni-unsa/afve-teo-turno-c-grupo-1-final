// Request evaluation: pure recursive functions over predicates and rules.
// Everything here is executable and compiles to JS (no quantifiers,
// no heap, structural recursion over sequences only).
include "Syntax.dfy"

module Eval {
  import opened Schema
  import opened Syntax

  function CompareInt(n: int, op: string, m: int): bool {
    if op == "==" then n == m
    else if op == "!=" then n != m
    else if op == "<" then n < m
    else if op == "<=" then n <= m
    else if op == ">" then n > m
    else if op == ">=" then n >= m
    else false
  }

  function EvalBoolAtom(b: bool, op: string, lit: string): bool {
    if op == "==" then (b <==> lit == "true")
    else if op == "!=" then (b <==> lit != "true")
    else false
  }

  function EvalEnumAtom(s: string, op: string, lit: string): bool {
    if op == "==" then s == lit
    else if op == "!=" then s != lit
    else false
  }

  function FindIndex(schema: Schema, family: string, name: string): int {
    if |schema| == 0 then -1
    else if schema[0].family == family && schema[0].name == name then 0
    else
      var rest := FindIndex(schema[1..], family, name);
      if rest < 0 then -1 else 1 + rest
  }

  function EvalAtom(req: Request, a: Pred, schema: Schema): bool
    requires a.Atom?
  {
    var idx := FindIndex(schema, a.family, a.attr);
    if idx < 0 || idx >= |req| then false
    else match req[idx]
      case EnumVal(s) => EvalEnumAtom(s, a.op, a.lit)
      case BoolVal(b) => EvalBoolAtom(b, a.op, a.lit)
      case IntVal(n) => CompareInt(n, a.op, a.num)
  }

  function Satisfies(req: Request, p: Pred, schema: Schema): bool {
    if p.Atom? then EvalAtom(req, p, schema)
    else if p.Not? then !Satisfies(req, p.p, schema)
    else if p.And? then Satisfies(req, p.a, schema) && Satisfies(req, p.b, schema)
    else Satisfies(req, p.a, schema) || Satisfies(req, p.b, schema)
  }

  function Applies(req: Request, rule: Rule, schema: Schema): bool {
    Satisfies(req, rule.target, schema)
  }

  function AnyEffectApplies(ruleset: Ruleset, req: Request, schema: Schema, e: Effect): bool {
    if |ruleset| == 0 then false
    else ((ruleset[0].effect == e && Applies(req, ruleset[0], schema)) || AnyEffectApplies(ruleset[1..], req, schema, e))
  }

  function PermitApplies(ruleset: Ruleset, req: Request, schema: Schema): bool {
    AnyEffectApplies(ruleset, req, schema, Effect.Permit)
  }

  function DenyApplies(ruleset: Ruleset, req: Request, schema: Schema): bool {
    AnyEffectApplies(ruleset, req, schema, Effect.Deny)
  }

  datatype Decision = Permit | Deny | Conflict

  // Closed-world default: no applicable rule denies. Conflict is internal
  // only for raw (unguarded) input; unreachable on coherent rulesets.
  function Evaluate(ruleset: Ruleset, req: Request, schema: Schema): Decision {
    if PermitApplies(ruleset, req, schema) && DenyApplies(ruleset, req, schema) then Decision.Conflict
    else if PermitApplies(ruleset, req, schema) then Decision.Permit
    else Decision.Deny
  }
}
