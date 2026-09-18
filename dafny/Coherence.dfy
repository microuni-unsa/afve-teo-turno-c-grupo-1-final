// Coherence properties P1..P4: ghost specifications plus executable
// per-property checks returning witnesses. Request scans are index-based
// (never reqs[1..]): Dafny seq slicing copies, which made full-schema
// scans quadratic. Ruleset scans keep structural recursion (rulesets are
// tiny). All checks compile to JS; soundness and completeness are proven
// per check and Transition.dfy builds the guarded API on top.
include "Eval.dfy"

module Coherence {
  import opened Schema
  import opened Syntax
  import opened Eval

  datatype Witness = Witness(req: Request, ruleIds: seq<int>, failedProperty: string, explanation: string)
  datatype WitnessOpt = NoWitness | HasWitness(wit: Witness)

  // Membership transfers from a sequence to its tail; used by the
  // ruleset inductions in this file and in Transition.dfy.
  lemma SeqTailMember<T>(s: seq<T>, x: T)
    requires x in s && |s| > 0 && s[0] != x
    ensures x in s[1..]
  {
    var i :| 0 <= i < |s| && s[i] == x;
    assert i != 0;
    assert s[1..][i - 1] == x;
  }

  // ---- P1: no request fires both a Permit and a Deny rule ----

  function FirstFiringId(ruleset: Ruleset, req: Request, schema: Schema, e: Effect): Opt<int> {
    if |ruleset| == 0 then None
    else if ruleset[0].effect == e && Applies(req, ruleset[0], schema) then Some(ruleset[0].id)
    else FirstFiringId(ruleset[1..], req, schema, e)
  }

  lemma FirstFiringIdSome(ruleset: Ruleset, req: Request, schema: Schema, e: Effect)
    requires AnyEffectApplies(ruleset, req, schema, e)
    ensures FirstFiringId(ruleset, req, schema, e).Some?
  {
    if |ruleset| == 0 {
    } else if ruleset[0].effect == e && Applies(req, ruleset[0], schema) {
    } else {
      FirstFiringIdSome(ruleset[1..], req, schema, e);
    }
  }

  function CheckP1From(reqs: seq<Request>, i: int, ruleset: Ruleset, schema: Schema): WitnessOpt
    requires 0 <= i <= |reqs|
    decreases |reqs| - i
  {
    if i == |reqs| then NoWitness
    else if PermitApplies(ruleset, reqs[i], schema) && DenyApplies(ruleset, reqs[i], schema) then
      var p := FirstFiringId(ruleset, reqs[i], schema, Effect.Permit);
      var d := FirstFiringId(ruleset, reqs[i], schema, Effect.Deny);
      if p.Some? && d.Some? then HasWitness(Witness(reqs[i], [p.v, d.v], "P1", "Permit rule and Deny rule both apply to the same request"))
      else CheckP1From(reqs, i + 1, ruleset, schema)
    else CheckP1From(reqs, i + 1, ruleset, schema)
  }

  function CheckP1Reqs(reqs: seq<Request>, ruleset: Ruleset, schema: Schema): WitnessOpt {
    CheckP1From(reqs, 0, ruleset, schema)
  }

  ghost predicate P1(ruleset: Ruleset, schema: Schema) {
    forall req :: req in AllRequests(schema) ==> !(PermitApplies(ruleset, req, schema) && DenyApplies(ruleset, req, schema))
  }

  lemma CheckP1FromGenuine(reqs: seq<Request>, i: int, ruleset: Ruleset, schema: Schema, w: Witness)
    requires 0 <= i <= |reqs|
    requires CheckP1From(reqs, i, ruleset, schema) == HasWitness(w)
    ensures w.failedProperty == "P1" && w.req in reqs && PermitApplies(ruleset, w.req, schema) && DenyApplies(ruleset, w.req, schema)
    decreases |reqs| - i
  {
    if i == |reqs| {
    } else if PermitApplies(ruleset, reqs[i], schema) && DenyApplies(ruleset, reqs[i], schema) {
      FirstFiringIdSome(ruleset, reqs[i], schema, Effect.Permit);
      FirstFiringIdSome(ruleset, reqs[i], schema, Effect.Deny);
      assert reqs[i] in reqs;
    } else {
      CheckP1FromGenuine(reqs, i + 1, ruleset, schema, w);
    }
  }

  lemma CheckP1ReqsGenuine(reqs: seq<Request>, ruleset: Ruleset, schema: Schema, w: Witness)
    requires CheckP1Reqs(reqs, ruleset, schema) == HasWitness(w)
    ensures w.failedProperty == "P1" && w.req in reqs && PermitApplies(ruleset, w.req, schema) && DenyApplies(ruleset, w.req, schema)
  {
    CheckP1FromGenuine(reqs, 0, ruleset, schema, w);
  }

  lemma CheckP1FromComplete(reqs: seq<Request>, i: int, ruleset: Ruleset, schema: Schema)
    requires 0 <= i <= |reqs|
    requires forall q :: q in reqs ==> q in AllRequests(schema)
    requires P1(ruleset, schema)
    ensures CheckP1From(reqs, i, ruleset, schema) == NoWitness
    decreases |reqs| - i
  {
    if i == |reqs| {
    } else {
      assert reqs[i] in reqs;
      assert reqs[i] in AllRequests(schema);
      CheckP1FromComplete(reqs, i + 1, ruleset, schema);
    }
  }

  lemma CheckP1ReqsComplete(reqs: seq<Request>, ruleset: Ruleset, schema: Schema)
    requires forall q :: q in reqs ==> q in AllRequests(schema)
    requires P1(ruleset, schema)
    ensures CheckP1Reqs(reqs, ruleset, schema) == NoWitness
  {
    CheckP1FromComplete(reqs, 0, ruleset, schema);
  }

  // ---- P2: every rule fires on at least one request ----

  function RuleFiresFrom(rule: Rule, reqs: seq<Request>, i: int, schema: Schema): bool
    requires 0 <= i <= |reqs|
    decreases |reqs| - i
  {
    if i == |reqs| then false
    else Applies(reqs[i], rule, schema) || RuleFiresFrom(rule, reqs, i + 1, schema)
  }

  function RuleFiresOnSome(rule: Rule, reqs: seq<Request>, schema: Schema): bool {
    RuleFiresFrom(rule, reqs, 0, schema)
  }

  lemma RuleFiresFromFalse(rule: Rule, reqs: seq<Request>, i: int, schema: Schema)
    requires 0 <= i <= |reqs|
    requires !RuleFiresFrom(rule, reqs, i, schema)
    ensures forall j :: i <= j < |reqs| ==> !Applies(reqs[j], rule, schema)
    decreases |reqs| - i
  {
    if i == |reqs| {
    } else {
      RuleFiresFromFalse(rule, reqs, i + 1, schema);
    }
  }

  lemma RuleFiresFromNone(rule: Rule, reqs: seq<Request>, i: int, schema: Schema)
    requires 0 <= i <= |reqs|
    requires forall j :: i <= j < |reqs| ==> !Applies(reqs[j], rule, schema)
    ensures !RuleFiresFrom(rule, reqs, i, schema)
    decreases |reqs| - i
  {
    if i == |reqs| {
    } else {
      RuleFiresFromNone(rule, reqs, i + 1, schema);
    }
  }

  lemma RuleFiresFromSome(rule: Rule, reqs: seq<Request>, i: int, schema: Schema, j: int)
    requires 0 <= i <= j < |reqs|
    requires Applies(reqs[j], rule, schema)
    ensures RuleFiresFrom(rule, reqs, i, schema)
    decreases |reqs| - i
  {
    if i == j {
    } else {
      RuleFiresFromSome(rule, reqs, i + 1, schema, j);
    }
  }

  lemma RuleFiresOnSomeFalse(rule: Rule, reqs: seq<Request>, schema: Schema)
    requires !RuleFiresOnSome(rule, reqs, schema)
    ensures forall q :: q in reqs ==> !Applies(q, rule, schema)
  {
    RuleFiresFromFalse(rule, reqs, 0, schema);
    assert forall q :: q in reqs ==> !Applies(q, rule, schema) by {
      forall q | q in reqs
        ensures !Applies(q, rule, schema)
      {
        var j :| 0 <= j < |reqs| && reqs[j] == q;
      }
    }
  }

  lemma RuleFiresOnSomeTrue(rule: Rule, reqs: seq<Request>, schema: Schema)
    requires RuleFiresOnSome(rule, reqs, schema)
    ensures exists q :: q in reqs && Applies(q, rule, schema)
  {
    var j := FirstFiringIndex(rule, reqs, 0, schema);
    assert reqs[j] in reqs;
  }

  function FirstFiringIndex(rule: Rule, reqs: seq<Request>, i: int, schema: Schema): int
    requires 0 <= i <= |reqs|
    requires RuleFiresFrom(rule, reqs, i, schema)
    ensures 0 <= FirstFiringIndex(rule, reqs, i, schema) < |reqs|
    ensures Applies(reqs[FirstFiringIndex(rule, reqs, i, schema)], rule, schema)
    decreases |reqs| - i
  {
    if Applies(reqs[i], rule, schema) then i else FirstFiringIndex(rule, reqs, i + 1, schema)
  }

  // Empty request: P2/P4 violations concern rules, not requests; the
  // witness request field is meaningless there and set to [].
  function CheckP2Rules(rules: Ruleset, reqs: seq<Request>, schema: Schema): WitnessOpt {
    if |rules| == 0 then NoWitness
    else if RuleFiresOnSome(rules[0], reqs, schema) then CheckP2Rules(rules[1..], reqs, schema)
    else HasWitness(Witness([], [rules[0].id], "P2", "Rule never applies to any request"))
  }

  ghost predicate P2(ruleset: Ruleset, schema: Schema) {
    forall r :: r in ruleset ==> exists req :: req in AllRequests(schema) && Applies(req, r, schema)
  }

  lemma CheckP2RulesGenuine(rules: Ruleset, reqs: seq<Request>, schema: Schema, w: Witness)
    requires reqs == AllRequests(schema)
    requires CheckP2Rules(rules, reqs, schema) == HasWitness(w)
    ensures w.failedProperty == "P2"
    ensures exists r :: r in rules && r.id in w.ruleIds && forall q :: q in AllRequests(schema) ==> !Applies(q, r, schema)
  {
    if |rules| == 0 {
    } else if RuleFiresOnSome(rules[0], reqs, schema) {
      CheckP2RulesGenuine(rules[1..], reqs, schema, w);
      assert forall r :: r in rules[1..] ==> r in rules;
    } else {
      RuleFiresOnSomeFalse(rules[0], reqs, schema);
    }
  }

  lemma CheckP2RulesComplete(rules: Ruleset, reqs: seq<Request>, schema: Schema)
    requires reqs == AllRequests(schema)
    requires P2(rules, schema)
    ensures CheckP2Rules(rules, reqs, schema) == NoWitness
  {
    if |rules| == 0 {
    } else {
      assert rules[0] in rules;
      var q :| q in AllRequests(schema) && Applies(q, rules[0], schema);
      assert q in reqs;
      var j :| 0 <= j < |reqs| && reqs[j] == q;
      RuleFiresFromSome(rules[0], reqs, 0, schema, j);
      assert P2(rules[1..], schema) by {
        assert forall r :: r in rules[1..] ==> r in rules;
      }
      CheckP2RulesComplete(rules[1..], reqs, schema);
    }
  }

  // ---- P3: every rule alone decides at least one request ----

  function OtherApplies(rules: Ruleset, skip: int, req: Request, schema: Schema): bool {
    if |rules| == 0 then false
    else ((rules[0].id != skip && Applies(req, rules[0], schema)) || OtherApplies(rules[1..], skip, req, schema))
  }

  lemma OtherAppliesMono(small: Ruleset, big: Ruleset, skip: int, req: Request, schema: Schema)
    requires forall r :: r in small ==> r in big
    requires OtherApplies(small, skip, req, schema)
    ensures OtherApplies(big, skip, req, schema)
  {
    if |small| == 0 {
    } else if small[0].id != skip && Applies(req, small[0], schema) {
      assert small[0] in big;
      OtherAppliesWitness(big, skip, req, schema, small[0]);
    } else {
      OtherAppliesMono(small[1..], big, skip, req, schema);
      assert forall r :: r in small[1..] ==> r in small;
    }
  }

  lemma OtherAppliesWitness(rules: Ruleset, skip: int, req: Request, schema: Schema, r: Rule)
    requires r in rules && r.id != skip && Applies(req, r, schema)
    ensures OtherApplies(rules, skip, req, schema)
  {
    if |rules| == 0 {
    } else if rules[0] == r {
    } else {
      assert rules[0] != r;
      SeqTailMember(rules, r);
      OtherAppliesWitness(rules[1..], skip, req, schema, r);
    }
  }

  function RuleSoleFrom(rule: Rule, rules: Ruleset, reqs: seq<Request>, i: int, schema: Schema): bool
    requires 0 <= i <= |reqs|
    decreases |reqs| - i
  {
    if i == |reqs| then false
    else ((Applies(reqs[i], rule, schema) && !OtherApplies(rules, rule.id, reqs[i], schema)) || RuleSoleFrom(rule, rules, reqs, i + 1, schema))
  }

  function RuleHasSoleWitness(rule: Rule, rules: Ruleset, reqs: seq<Request>, schema: Schema): bool {
    RuleSoleFrom(rule, rules, reqs, 0, schema)
  }

  lemma RuleSoleFromFalse(rule: Rule, rules: Ruleset, reqs: seq<Request>, i: int, schema: Schema)
    requires 0 <= i <= |reqs|
    requires !RuleSoleFrom(rule, rules, reqs, i, schema)
    ensures forall j :: i <= j < |reqs| ==> !Applies(reqs[j], rule, schema) || OtherApplies(rules, rule.id, reqs[j], schema)
    decreases |reqs| - i
  {
    if i == |reqs| {
    } else {
      RuleSoleFromFalse(rule, rules, reqs, i + 1, schema);
    }
  }

  lemma SoleFoundFrom(rule: Rule, rules: Ruleset, reqs: seq<Request>, i: int, schema: Schema, j: int)
    requires 0 <= i <= j < |reqs|
    requires Applies(reqs[j], rule, schema) && !OtherApplies(rules, rule.id, reqs[j], schema)
    ensures RuleSoleFrom(rule, rules, reqs, i, schema)
    decreases |reqs| - i
  {
    if i == j {
    } else {
      SoleFoundFrom(rule, rules, reqs, i + 1, schema, j);
    }
  }

  function FirstSharedFrom(rule: Rule, reqs: seq<Request>, i: int, schema: Schema): Opt<Request>
    requires 0 <= i <= |reqs|
    decreases |reqs| - i
  {
    if i == |reqs| then None
    else if Applies(reqs[i], rule, schema) then Some(reqs[i])
    else FirstSharedFrom(rule, reqs, i + 1, schema)
  }

  function FirstSharedReq(rule: Rule, reqs: seq<Request>, schema: Schema): Opt<Request> {
    FirstSharedFrom(rule, reqs, 0, schema)
  }

  lemma FirstSharedFromMember(rule: Rule, reqs: seq<Request>, i: int, schema: Schema, q: Request)
    requires 0 <= i <= |reqs|
    requires FirstSharedFrom(rule, reqs, i, schema) == Some(q)
    ensures q in reqs && Applies(q, rule, schema)
    decreases |reqs| - i
  {
    if i == |reqs| {
    } else if Applies(reqs[i], rule, schema) {
      assert reqs[i] in reqs;
    } else {
      FirstSharedFromMember(rule, reqs, i + 1, schema, q);
    }
  }

  lemma FirstSharedReqMember(rule: Rule, reqs: seq<Request>, schema: Schema, q: Request)
    requires FirstSharedReq(rule, reqs, schema) == Some(q)
    ensures q in reqs && Applies(q, rule, schema)
  {
    FirstSharedFromMember(rule, reqs, 0, schema, q);
  }

  lemma FirstSharedFromSome(rule: Rule, reqs: seq<Request>, i: int, schema: Schema, j: int)
    requires 0 <= i <= j < |reqs|
    requires Applies(reqs[j], rule, schema)
    ensures FirstSharedFrom(rule, reqs, i, schema).Some?
    decreases |reqs| - i
  {
    if i == j {
    } else {
      FirstSharedFromSome(rule, reqs, i + 1, schema, j);
    }
  }

  lemma FirstSharedReqSome(rule: Rule, reqs: seq<Request>, schema: Schema, q: Request)
    requires q in reqs && Applies(q, rule, schema)
    ensures FirstSharedReq(rule, reqs, schema).Some?
  {
    var j :| 0 <= j < |reqs| && reqs[j] == q;
    FirstSharedFromSome(rule, reqs, 0, schema, j);
  }

  function FiringIdsExcept(rules: Ruleset, skip: int, req: Request, schema: Schema): seq<int> {
    if |rules| == 0 then []
    else if rules[0].id != skip && Applies(req, rules[0], schema) then [rules[0].id] + FiringIdsExcept(rules[1..], skip, req, schema)
    else FiringIdsExcept(rules[1..], skip, req, schema)
  }

  function CheckP3Rules(rules: Ruleset, all: Ruleset, reqs: seq<Request>, schema: Schema): WitnessOpt {
    if |rules| == 0 then NoWitness
    else if RuleHasSoleWitness(rules[0], all, reqs, schema) then CheckP3Rules(rules[1..], all, reqs, schema)
    else match FirstSharedReq(rules[0], reqs, schema)
      case Some(q) => HasWitness(Witness(q, [rules[0].id] + FiringIdsExcept(all, rules[0].id, q, schema), "P3", "Rule never alone decides a request"))
      case None => CheckP3Rules(rules[1..], all, reqs, schema)
  }

  ghost predicate P3(ruleset: Ruleset, schema: Schema) {
    forall r :: r in ruleset ==> exists req :: req in AllRequests(schema) && Applies(req, r, schema) && !OtherApplies(ruleset, r.id, req, schema)
  }

  lemma CheckP3RulesGenuine(rules: Ruleset, all: Ruleset, reqs: seq<Request>, schema: Schema, w: Witness)
    requires reqs == AllRequests(schema)
    requires forall r :: r in rules ==> r in all
    requires CheckP3Rules(rules, all, reqs, schema) == HasWitness(w)
    ensures w.failedProperty == "P3"
    ensures exists r :: r in all && r.id in w.ruleIds && forall q :: q in AllRequests(schema) ==> !Applies(q, r, schema) || OtherApplies(all, r.id, q, schema)
  {
    if |rules| == 0 {
    } else if RuleHasSoleWitness(rules[0], all, reqs, schema) {
      CheckP3RulesGenuine(rules[1..], all, reqs, schema, w);
      assert forall r :: r in rules[1..] ==> r in rules;
    } else {
      RuleSoleFromFalse(rules[0], all, reqs, 0, schema);
      match FirstSharedReq(rules[0], reqs, schema)
        case Some(q) => {
          FirstSharedReqMember(rules[0], reqs, schema, q);
        }
        case None => {
          CheckP3RulesGenuine(rules[1..], all, reqs, schema, w);
          assert forall r :: r in rules[1..] ==> r in rules;
        }
    }
  }

  lemma CheckP3RulesComplete(rules: Ruleset, all: Ruleset, reqs: seq<Request>, schema: Schema)
    requires reqs == AllRequests(schema)
    requires forall r :: r in rules ==> r in all
    requires P3(all, schema)
    ensures CheckP3Rules(rules, all, reqs, schema) == NoWitness
  {
    if |rules| == 0 {
    } else {
      assert rules[0] in all;
      var q :| q in AllRequests(schema) && Applies(q, rules[0], schema) && !OtherApplies(all, rules[0].id, q, schema);
      assert q in reqs;
      var j :| 0 <= j < |reqs| && reqs[j] == q;
      SoleFoundFrom(rules[0], all, reqs, 0, schema, j);
      CheckP3RulesComplete(rules[1..], all, reqs, schema);
      assert forall r :: r in rules[1..] ==> r in rules;
    }
  }

  // ---- P4: every rule type-checks against the schema ----

  function CheckP4Rules(rules: Ruleset, schema: Schema): WitnessOpt {
    if |rules| == 0 then NoWitness
    else if ValidRule(rules[0], schema) then CheckP4Rules(rules[1..], schema)
    else HasWitness(Witness([], [rules[0].id], "P4", "Rule violates the attribute schema"))
  }

  ghost predicate P4(ruleset: Ruleset, schema: Schema) {
    forall r :: r in ruleset ==> ValidRule(r, schema)
  }

  lemma CheckP4RulesGenuine(rules: Ruleset, schema: Schema, w: Witness)
    requires CheckP4Rules(rules, schema) == HasWitness(w)
    ensures w.failedProperty == "P4"
    ensures exists r :: r in rules && r.id in w.ruleIds && !ValidRule(r, schema)
  {
    if |rules| == 0 {
    } else if ValidRule(rules[0], schema) {
      CheckP4RulesGenuine(rules[1..], schema, w);
      assert forall r :: r in rules[1..] ==> r in rules;
    } else {
    }
  }

  lemma CheckP4RulesComplete(rules: Ruleset, schema: Schema)
    requires P4(rules, schema)
    ensures CheckP4Rules(rules, schema) == NoWitness
  {
    if |rules| == 0 {
    } else {
      assert rules[0] in rules;
      assert P4(rules[1..], schema) by {
        assert forall r :: r in rules[1..] ==> r in rules;
      }
      CheckP4RulesComplete(rules[1..], schema);
    }
  }

  // ---- Combined coherence ----

  ghost predicate Coherent(ruleset: Ruleset, schema: Schema) {
    P1(ruleset, schema) && P2(ruleset, schema) && P3(ruleset, schema) && P4(ruleset, schema)
  }

  ghost predicate WitnessGenuine(w: Witness, ruleset: Ruleset, schema: Schema) {
    && (w.failedProperty == "P1" ==> w.req in AllRequests(schema) && PermitApplies(ruleset, w.req, schema) && DenyApplies(ruleset, w.req, schema))
    && (w.failedProperty == "P2" ==> exists r :: r in ruleset && r.id in w.ruleIds && forall q :: q in AllRequests(schema) ==> !Applies(q, r, schema))
    && (w.failedProperty == "P3" ==> exists r :: r in ruleset && r.id in w.ruleIds && forall q :: q in AllRequests(schema) ==> !Applies(q, r, schema) || OtherApplies(ruleset, r.id, q, schema))
    && (w.failedProperty == "P4" ==> exists r :: r in ruleset && r.id in w.ruleIds && !ValidRule(r, schema))
  }

  function CheckCoherent(ruleset: Ruleset, schema: Schema): WitnessOpt {
    var reqs := AllRequests(schema);
    var w1 := CheckP1Reqs(reqs, ruleset, schema);
    if w1.HasWitness? then w1
    else
      var w2 := CheckP2Rules(ruleset, reqs, schema);
      if w2.HasWitness? then w2
      else
        var w3 := CheckP3Rules(ruleset, ruleset, reqs, schema);
        if w3.HasWitness? then w3 else CheckP4Rules(ruleset, schema)
  }

  // Independently queryable per-property checks for UI badges.
  function CheckP1(ruleset: Ruleset, schema: Schema): WitnessOpt {
    CheckP1Reqs(AllRequests(schema), ruleset, schema)
  }

  function CheckP2(ruleset: Ruleset, schema: Schema): WitnessOpt {
    CheckP2Rules(ruleset, AllRequests(schema), schema)
  }

  function CheckP3(ruleset: Ruleset, schema: Schema): WitnessOpt {
    CheckP3Rules(ruleset, ruleset, AllRequests(schema), schema)
  }

  function CheckP4(ruleset: Ruleset, schema: Schema): WitnessOpt {
    CheckP4Rules(ruleset, schema)
  }

  lemma CheckCoherentSound(ruleset: Ruleset, schema: Schema)
    requires CheckCoherent(ruleset, schema) == NoWitness
    ensures Coherent(ruleset, schema)
  {
    var reqs := AllRequests(schema);
    assert CheckP1Reqs(reqs, ruleset, schema) == NoWitness;
    assert CheckP2Rules(ruleset, reqs, schema) == NoWitness;
    assert CheckP3Rules(ruleset, ruleset, reqs, schema) == NoWitness;
    assert CheckP4Rules(ruleset, schema) == NoWitness;
    assert P1(ruleset, schema) by {
      if !P1(ruleset, schema) {
        var bad :| bad in AllRequests(schema) && PermitApplies(ruleset, bad, schema) && DenyApplies(ruleset, bad, schema);
        assert bad in reqs;
        var j :| 0 <= j < |reqs| && reqs[j] == bad;
        assert CheckP1Reqs(reqs, ruleset, schema).HasWitness? by {
          P1WitnessFound(reqs, 0, ruleset, schema, j);
        }
        assert false;
      }
    }
    assert P2(ruleset, schema) by {
      if !P2(ruleset, schema) {
        var r :| r in ruleset && forall q :: q in AllRequests(schema) ==> !Applies(q, r, schema);
        assert !RuleFiresOnSome(r, reqs, schema) by {
          assert forall q :: q in reqs ==> q in AllRequests(schema);
          RuleFiresNone(ruleset, reqs, schema, r);
        }
        assert CheckP2Rules(ruleset, reqs, schema).HasWitness? by {
          P2WitnessFound(ruleset, reqs, schema, r);
        }
        assert false;
      }
    }
    assert P3(ruleset, schema) by {
      if !P3(ruleset, schema) {
        var r :| r in ruleset && forall q :: q in AllRequests(schema) ==> !Applies(q, r, schema) || OtherApplies(ruleset, r.id, q, schema);
        assert r in ruleset;
        var q :| q in AllRequests(schema) && Applies(q, r, schema);
        assert q in reqs;
        var j :| 0 <= j < |reqs| && reqs[j] == q;
        assert CheckP3Rules(ruleset, ruleset, reqs, schema).HasWitness? by {
          P3WitnessFound(ruleset, ruleset, reqs, schema, r, j);
        }
        assert false;
      }
    }
    assert P4(ruleset, schema) by {
      if !P4(ruleset, schema) {
        var r :| r in ruleset && !ValidRule(r, schema);
        assert CheckP4Rules(ruleset, schema).HasWitness? by {
          P4WitnessFound(ruleset, schema, r);
        }
        assert false;
      }
    }
  }

  // Helper existentials used by CheckCoherentSound (the finder direction).
  lemma P1WitnessFound(reqs: seq<Request>, i: int, ruleset: Ruleset, schema: Schema, j: int)
    requires 0 <= i <= j < |reqs|
    requires PermitApplies(ruleset, reqs[j], schema) && DenyApplies(ruleset, reqs[j], schema)
    ensures CheckP1From(reqs, i, ruleset, schema).HasWitness?
    decreases |reqs| - i
  {
    if i == j {
      FirstFiringIdSome(ruleset, reqs[j], schema, Effect.Permit);
      FirstFiringIdSome(ruleset, reqs[j], schema, Effect.Deny);
    } else {
      P1WitnessFound(reqs, i + 1, ruleset, schema, j);
    }
  }

  lemma RuleFiresNone(rules: Ruleset, reqs: seq<Request>, schema: Schema, r: Rule)
    requires r in rules
    requires forall q :: q in AllRequests(schema) ==> !Applies(q, r, schema)
    requires forall q :: q in reqs ==> q in AllRequests(schema)
    ensures !RuleFiresOnSome(r, reqs, schema)
  {
    assert forall j :: 0 <= j < |reqs| ==> !Applies(reqs[j], r, schema) by {
      forall j | 0 <= j < |reqs|
        ensures !Applies(reqs[j], r, schema)
      {
        assert reqs[j] in reqs;
      }
    }
    RuleFiresFromNone(r, reqs, 0, schema);
  }

  lemma P2WitnessFound(rules: Ruleset, reqs: seq<Request>, schema: Schema, r: Rule)
    requires r in rules
    requires !RuleFiresOnSome(r, reqs, schema)
    ensures CheckP2Rules(rules, reqs, schema).HasWitness?
  {
    if |rules| == 0 {
    } else if rules[0] == r {
    } else {
      assert rules[0] != r;
      SeqTailMember(rules, r);
      P2WitnessFound(rules[1..], reqs, schema, r);
    }
  }

  lemma P3WitnessFound(rules: Ruleset, all: Ruleset, reqs: seq<Request>, schema: Schema, r: Rule, j: int)
    requires r in rules && r in all
    requires 0 <= j < |reqs| && Applies(reqs[j], r, schema)
    requires forall q :: q in reqs ==> !Applies(q, r, schema) || OtherApplies(all, r.id, q, schema)
    requires forall x :: x in rules ==> x in all
    ensures CheckP3Rules(rules, all, reqs, schema).HasWitness?
  {
    if |rules| == 0 {
    } else if rules[0] == r {
      NoSoleFrom(rules, all, reqs, 0, schema, r);
      FirstSharedFromSome(r, reqs, 0, schema, j);
      assert FirstSharedReq(r, reqs, schema).Some?;
    } else {
      assert rules[0] != r;
      SeqTailMember(rules, r);
      P3WitnessFound(rules[1..], all, reqs, schema, r, j);
      assert forall x :: x in rules[1..] ==> x in rules;
    }
  }

  lemma NoSoleFrom(rules: Ruleset, all: Ruleset, reqs: seq<Request>, i: int, schema: Schema, r: Rule)
    requires 0 <= i <= |reqs|
    requires forall q :: q in reqs ==> !Applies(q, r, schema) || OtherApplies(all, r.id, q, schema)
    ensures !RuleSoleFrom(r, all, reqs, i, schema)
    decreases |reqs| - i
  {
    if i == |reqs| {
    } else {
      assert reqs[i] in reqs;
      NoSoleFrom(rules, all, reqs, i + 1, schema, r);
    }
  }

  lemma P4WitnessFound(rules: Ruleset, schema: Schema, r: Rule)
    requires r in rules && !ValidRule(r, schema)
    ensures CheckP4Rules(rules, schema).HasWitness?
  {
    if |rules| == 0 {
    } else if rules[0] == r {
    } else {
      assert rules[0] != r;
      SeqTailMember(rules, r);
      P4WitnessFound(rules[1..], schema, r);
    }
  }

  lemma CheckCoherentGenuine(ruleset: Ruleset, schema: Schema, w: Witness)
    requires CheckCoherent(ruleset, schema) == HasWitness(w)
    ensures WitnessGenuine(w, ruleset, schema)
  {
    var reqs := AllRequests(schema);
    var w1 := CheckP1Reqs(reqs, ruleset, schema);
    if w1.HasWitness? {
      CheckP1ReqsGenuine(reqs, ruleset, schema, w);
      assert w.req in AllRequests(schema);
    } else {
      var w2 := CheckP2Rules(ruleset, reqs, schema);
      if w2.HasWitness? {
        CheckP2RulesGenuine(ruleset, reqs, schema, w);
      } else {
        var w3 := CheckP3Rules(ruleset, ruleset, reqs, schema);
        if w3.HasWitness? {
          CheckP3RulesGenuine(ruleset, ruleset, reqs, schema, w);
          assert forall r :: r in ruleset ==> r in ruleset;
        } else {
          CheckP4RulesGenuine(ruleset, schema, w);
        }
      }
    }
  }

  lemma CheckCoherentComplete(ruleset: Ruleset, schema: Schema)
    requires !Coherent(ruleset, schema)
    ensures CheckCoherent(ruleset, schema).HasWitness?
  {
    var reqs := AllRequests(schema);
    var w1 := CheckP1Reqs(reqs, ruleset, schema);
    if !P1(ruleset, schema) {
      var bad :| bad in AllRequests(schema) && PermitApplies(ruleset, bad, schema) && DenyApplies(ruleset, bad, schema);
      assert bad in reqs;
      var j :| 0 <= j < |reqs| && reqs[j] == bad;
      P1WitnessFound(reqs, 0, ruleset, schema, j);
      assert w1.HasWitness?;
      assert CheckCoherent(ruleset, schema) == w1;
    } else {
      CheckP1ReqsComplete(reqs, ruleset, schema);
      assert forall q :: q in reqs ==> q in AllRequests(schema);
      assert w1 == NoWitness;
      var w2 := CheckP2Rules(ruleset, reqs, schema);
      if !P2(ruleset, schema) {
        var r :| r in ruleset && forall q :: q in AllRequests(schema) ==> !Applies(q, r, schema);
        assert forall q :: q in reqs ==> q in AllRequests(schema);
        RuleFiresNone(ruleset, reqs, schema, r);
        P2WitnessFound(ruleset, reqs, schema, r);
        assert w2.HasWitness?;
        assert CheckCoherent(ruleset, schema) == w2;
      } else {
        CheckP2RulesComplete(ruleset, reqs, schema);
        assert w2 == NoWitness;
        var w3 := CheckP3Rules(ruleset, ruleset, reqs, schema);
        if !P3(ruleset, schema) {
          var r :| r in ruleset && forall q :: q in AllRequests(schema) ==> !Applies(q, r, schema) || OtherApplies(ruleset, r.id, q, schema);
          assert r in ruleset;
          var q :| q in AllRequests(schema) && Applies(q, r, schema);
          assert q in reqs;
          var j :| 0 <= j < |reqs| && reqs[j] == q;
          P3WitnessFound(ruleset, ruleset, reqs, schema, r, j);
          assert w3.HasWitness?;
          assert forall r :: r in ruleset ==> r in ruleset;
          assert CheckCoherent(ruleset, schema) == w3;
        } else {
          assert !P4(ruleset, schema);
          CheckP3RulesComplete(ruleset, ruleset, reqs, schema);
          assert forall r :: r in ruleset ==> r in ruleset;
          assert w3 == NoWitness;
          var r :| r in ruleset && !ValidRule(r, schema);
          P4WitnessFound(ruleset, schema, r);
          assert CheckP4Rules(ruleset, schema).HasWitness?;
          assert CheckCoherent(ruleset, schema).HasWitness?;
        }
      }
    }
  }
}
