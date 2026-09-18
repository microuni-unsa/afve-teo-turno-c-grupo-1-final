// Guarded ruleset evolution: total TryAdd / TryRemove / TryUpdate with an
// inductive coherence invariant. Preservation for Add and Update holds by
// construction of the guard; removal preservation is proved by subset
// monotonicity. Unknown-id update is rejected as P4 per plan.
include "Coherence.dfy"

module Transition {
  import opened Schema
  import opened Syntax
  import opened Eval
  import opened Coherence

  datatype AddResult = Accepted(ruleset: Ruleset) | Rejected(w: Witness)

  function TryAdd(R: Ruleset, r: Rule, schema: Schema): AddResult {
    var w := CheckCoherent(R + [r], schema);
    if w.NoWitness? then Accepted(R + [r]) else Rejected(w.wit)
  }

  function TryRemove(R: Ruleset, id: int): Ruleset {
    RemoveById(R, id)
  }

  function ReplaceById(R: Ruleset, id: int, r: Rule): Ruleset {
    if |R| == 0 then []
    else if R[0].id == id then [r] + R[1..]
    else [R[0]] + ReplaceById(R[1..], id, r)
  }

  function TryUpdate(R: Ruleset, id: int, r: Rule, schema: Schema): AddResult {
    if FindById(R, id).None? then Rejected(Witness([], [id], "P4", "Unknown rule id"))
    else
      var R2 := ReplaceById(R, id, r);
      var w := CheckCoherent(R2, schema);
      if w.NoWitness? then Accepted(R2) else Rejected(w.wit)
  }

  // ---- 1. Empty ruleset is vacuously coherent ----

  lemma EmptyCoherent(schema: Schema)
    ensures Coherent([], schema)
  {
  }

  // ---- 2/4. Guarded add/update preserve coherence by construction ----

  lemma AddPreserves(R: Ruleset, r: Rule, schema: Schema)
    ensures match TryAdd(R, r, schema)
      case Accepted(rs) => Coherent(rs, schema)
      case Rejected(_) => true
  {
    var w := CheckCoherent(R + [r], schema);
    if w == NoWitness {
      CheckCoherentSound(R + [r], schema);
    }
  }

  lemma UpdatePreserves(R: Ruleset, id: int, r: Rule, schema: Schema)
    ensures match TryUpdate(R, id, r, schema)
      case Accepted(rs) => Coherent(rs, schema)
      case Rejected(_) => true
  {
    if FindById(R, id).None? {
    } else {
      var R2 := ReplaceById(R, id, r);
      var w := CheckCoherent(R2, schema);
      if w == NoWitness {
        CheckCoherentSound(R2, schema);
      }
    }
  }

  // ---- 3. Removal preserves coherence (subset monotonicity) ----

  lemma AnyEffectAppliesWitness(rules: Ruleset, req: Request, schema: Schema, e: Effect, r: Rule)
    requires r in rules && r.effect == e && Applies(req, r, schema)
    ensures AnyEffectApplies(rules, req, schema, e)
  {
    if |rules| == 0 {
    } else if rules[0] == r {
    } else {
      assert rules[0] != r;
      SeqTailMember(rules, r);
      AnyEffectAppliesWitness(rules[1..], req, schema, e, r);
    }
  }

  lemma AnyEffectAppliesMono(small: Ruleset, big: Ruleset, req: Request, schema: Schema, e: Effect)
    requires forall r :: r in small ==> r in big
    ensures AnyEffectApplies(small, req, schema, e) ==> AnyEffectApplies(big, req, schema, e)
  {
    if |small| == 0 {
    } else if small[0].effect == e && Applies(req, small[0], schema) {
      assert small[0] in big;
      AnyEffectAppliesWitness(big, req, schema, e, small[0]);
    } else {
      AnyEffectAppliesMono(small[1..], big, req, schema, e);
      assert forall r :: r in small[1..] ==> r in small;
    }
  }

  lemma RemovePreservesCoherent(R: Ruleset, id: int, schema: Schema)
    requires Coherent(R, schema)
    ensures Coherent(RemoveById(R, id), schema)
  {
    var R2 := RemoveById(R, id);
    RemoveByIdSubset(R, id);
    assert P1(R2, schema) by {
      forall req | req in AllRequests(schema)
        ensures !(PermitApplies(R2, req, schema) && DenyApplies(R2, req, schema))
      {
        if PermitApplies(R2, req, schema) && DenyApplies(R2, req, schema) {
          AnyEffectAppliesMono(R2, R, req, schema, Effect.Permit);
          AnyEffectAppliesMono(R2, R, req, schema, Effect.Deny);
          assert P1(R, schema);
          assert false;
        }
      }
    }
    assert P2(R2, schema) by {
      forall r | r in R2
        ensures exists req :: req in AllRequests(schema) && Applies(req, r, schema)
      {
        assert r in R;
        assert P2(R, schema);
      }
    }
    assert P3(R2, schema) by {
      forall r | r in R2
        ensures exists req :: req in AllRequests(schema) && Applies(req, r, schema) && !OtherApplies(R2, r.id, req, schema)
      {
        assert r in R;
        assert P3(R, schema);
        var q :| q in AllRequests(schema) && Applies(q, r, schema) && !OtherApplies(R, r.id, q, schema);
        if OtherApplies(R2, r.id, q, schema) {
          OtherAppliesMono(R2, R, r.id, q, schema);
          assert forall x :: x in R2 ==> x in R;
          assert false;
        }
      }
    }
    assert P4(R2, schema) by {
      forall r | r in R2
        ensures ValidRule(r, schema)
      {
        assert r in R;
        assert P4(R, schema);
      }
    }
  }

  // ---- 5. Evaluate agrees with the Permit side on coherent rulesets ----

  lemma EvaluateAgreesOnCoherent(ruleset: Ruleset, req: Request, schema: Schema)
    requires SchemaWellFormed(schema)
    requires Coherent(ruleset, schema)
    requires ValidRequest(req, schema)
    ensures (Evaluate(ruleset, req, schema) == Decision.Permit) <==> PermitApplies(ruleset, req, schema)
  {
    AllRequestsComplete(schema, req);
    assert req in AllRequests(schema);
    assert P1(ruleset, schema);
  }

  // ---- 6. Every Rejected witness genuinely violates the named property ----

  lemma WitnessSoundness(R: Ruleset, r: Rule, schema: Schema, w: Witness)
    requires TryAdd(R, r, schema) == Rejected(w)
    ensures WitnessGenuine(w, R + [r], schema)
  {
    var c := CheckCoherent(R + [r], schema);
    assert c.HasWitness?;
    assert c == HasWitness(w);
    CheckCoherentGenuine(R + [r], schema, w);
  }

  lemma WitnessSoundnessUpdate(R: Ruleset, id: int, r: Rule, schema: Schema, w: Witness)
    requires FindById(R, id).Some?
    requires TryUpdate(R, id, r, schema) == Rejected(w)
    ensures WitnessGenuine(w, ReplaceById(R, id, r), schema)
  {
    var R2 := ReplaceById(R, id, r);
    var c := CheckCoherent(R2, schema);
    assert c.HasWitness?;
    assert c == HasWitness(w);
    CheckCoherentGenuine(R2, schema, w);
  }

  lemma UnknownUpdateRejected(R: Ruleset, id: int, r: Rule, schema: Schema, w: Witness)
    requires FindById(R, id).None?
    requires TryUpdate(R, id, r, schema) == Rejected(w)
    ensures w.failedProperty == "P4" && w.ruleIds == [id]
  {
  }

  // ---- 7. Every coherence violation yields a witness (bounded scope:
  // the enumeration is finite by construction over the schema domains) ----

  lemma WitnessCompleteness(R: Ruleset, r: Rule, schema: Schema)
    requires !Coherent(R + [r], schema)
    ensures TryAdd(R, r, schema).Rejected?
  {
    CheckCoherentComplete(R + [r], schema);
  }

  lemma WitnessCompletenessUpdate(R: Ruleset, id: int, r: Rule, schema: Schema)
    requires FindById(R, id).Some?
    requires !Coherent(ReplaceById(R, id, r), schema)
    ensures TryUpdate(R, id, r, schema).Rejected?
  {
    CheckCoherentComplete(ReplaceById(R, id, r), schema);
  }
}
