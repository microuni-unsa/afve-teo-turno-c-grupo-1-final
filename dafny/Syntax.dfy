// Policy syntax: effects, predicates, rules, validity against a schema.
// ValidRule lives here (not in Schema.dfy) because it references Pred;
// the include direction Schema <- Syntax forbids the reverse.
include "Schema.dfy"

module Syntax {
  import opened Schema

  datatype Effect = Permit | Deny

  datatype Pred =
    | Atom(family: string, attr: string, op: string, lit: string, num: int)
    | Not(p: Pred)
    | And(a: Pred, b: Pred)
    | Or(a: Pred, b: Pred)

  datatype Rule = Rule(id: int, effect: Effect, target: Pred)

  type Ruleset = seq<Rule>

  datatype Opt<T> = None | Some(v: T)

  function LookupDecl(schema: Schema, family: string, name: string): Opt<AttrDecl> {
    if |schema| == 0 then None
    else if schema[0].family == family && schema[0].name == name then Some(schema[0])
    else LookupDecl(schema[1..], family, name)
  }

  predicate ValidIntOp(op: string) {
    op == "==" || op == "!=" || op == "<" || op == "<=" || op == ">" || op == ">="
  }

  predicate ValidEqOp(op: string) {
    op == "==" || op == "!="
  }

  predicate ValidAtom(a: Pred, schema: Schema)
    requires a.Atom?
  {
    match LookupDecl(schema, a.family, a.attr)
      case None => false
      case Some(d) =>
        if d.attrType.BoundedInt? then ValidIntOp(a.op) && d.lo <= a.num <= d.hi
        else if d.attrType.Bool? then ValidEqOp(a.op) && (a.lit == "true" || a.lit == "false")
        else ValidEqOp(a.op) && a.lit in d.enumVals
  }

  predicate ValidPred(p: Pred, schema: Schema) {
    if p.Atom? then ValidAtom(p, schema)
    else if p.Not? then ValidPred(p.p, schema)
    else ValidPred(p.a, schema) && ValidPred(p.b, schema)
  }

  predicate ValidRule(rule: Rule, schema: Schema) {
    ValidPred(rule.target, schema)
  }

  predicate AllRulesValid(ruleset: Ruleset, schema: Schema) {
    forall r :: r in ruleset ==> ValidRule(r, schema)
  }

  function RemoveById(ruleset: Ruleset, id: int): Ruleset {
    if |ruleset| == 0 then []
    else if ruleset[0].id == id then RemoveById(ruleset[1..], id)
    else [ruleset[0]] + RemoveById(ruleset[1..], id)
  }

  function FindById(ruleset: Ruleset, id: int): Opt<Rule> {
    if |ruleset| == 0 then None
    else if ruleset[0].id == id then Some(ruleset[0])
    else FindById(ruleset[1..], id)
  }

  lemma RemoveByIdSubset(ruleset: Ruleset, id: int)
    ensures forall r :: r in RemoveById(ruleset, id) ==> r in ruleset && r.id != id
  {
    if |ruleset| == 0 {
    } else if ruleset[0].id == id {
      RemoveByIdSubset(ruleset[1..], id);
    } else {
      RemoveByIdSubset(ruleset[1..], id);
      assert forall r :: r in [ruleset[0]] + RemoveById(ruleset[1..], id) ==> r == ruleset[0] || r in RemoveById(ruleset[1..], id);
    }
  }
}
