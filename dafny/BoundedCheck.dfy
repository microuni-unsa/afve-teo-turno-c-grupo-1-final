// Bounded model check (ghost/test-only, excluded from the JS build):
// a finite state space over a shrunk schema is defined as data, and the
// transition invariant plus witness soundness are discharged over every
// element via the general Transition lemmas. SmallStateCount is executable
// so paper artifacts can report the explored state count.
include "Transition.dfy"

module BoundedCheck {
  import opened Schema
  import opened Syntax
  import opened Eval
  import opened Coherence
  import opened Transition

  const MAX_RULES_SMALL: int := 3

  function SmallSchema(): Schema {
    [AttrDecl("subject", "role", Enum, ["a", "b"], 0, 0),
     AttrDecl("resource", "kind", Enum, ["record", "lab"], 0, 0),
     AttrDecl("environment", "emergency", Bool, [], 0, 0)]
  }

  lemma SmallSchemaWellFormed()
    ensures SchemaWellFormed(SmallSchema())
  {
  }

  function SmallPreds(): seq<Pred> {
    [Atom("subject", "role", "==", "a", 0),
     Atom("subject", "role", "==", "b", 0),
     Atom("resource", "kind", "==", "record", 0),
     Atom("environment", "emergency", "==", "true", 0)]
  }

  function SmallRules(): seq<Rule> {
    [Rule(0, Effect.Permit, SmallPreds()[0]),
     Rule(1, Effect.Deny, SmallPreds()[1]),
     Rule(2, Effect.Permit, SmallPreds()[2]),
     Rule(3, Effect.Deny, SmallPreds()[3]),
     Rule(4, Effect.Permit, SmallPreds()[1]),
     Rule(5, Effect.Deny, SmallPreds()[0])]
  }

  function ExtendAll(prefixes: seq<Ruleset>, pool: seq<Rule>): seq<Ruleset> {
    if |prefixes| == 0 then []
    else ExtendOne(prefixes[0], pool) + ExtendAll(prefixes[1..], pool)
  }

  function ExtendOne(prefix: Ruleset, pool: seq<Rule>): seq<Ruleset> {
    if |pool| == 0 then []
    else [prefix + [pool[0]]] + ExtendOne(prefix, pool[1..])
  }

  function RulesetsOfLength(k: int, pool: seq<Rule>): seq<Ruleset>
    requires k >= 0
    decreases k
  {
    if k == 0 then [[]] else ExtendAll(RulesetsOfLength(k - 1, pool), pool)
  }

  function AllSmallRulesets(): seq<Ruleset> {
    RulesetsOfLength(0, SmallRules()) + RulesetsOfLength(1, SmallRules()) +
    RulesetsOfLength(2, SmallRules()) + RulesetsOfLength(3, SmallRules())
  }

  function SmallStateCount(): int {
    |AllSmallRulesets()|
  }

  ghost predicate ModelHoldsFor(R: Ruleset) {
    Coherent(R, SmallSchema()) ==>
      forall r :: r in SmallRules() ==>
        match TryAdd(R, r, SmallSchema())
          case Accepted(r2) => Coherent(r2, SmallSchema())
          case Rejected(w) => WitnessGenuine(w, R + [r], SmallSchema())
  }

  lemma BoundedModelCheck()
    ensures forall R :: R in AllSmallRulesets() ==> ModelHoldsFor(R)
  {
    forall R | R in AllSmallRulesets()
      ensures ModelHoldsFor(R)
    {
      if Coherent(R, SmallSchema()) {
        forall r | r in SmallRules()
          ensures match TryAdd(R, r, SmallSchema())
            case Accepted(r2) => Coherent(r2, SmallSchema())
            case Rejected(w) => WitnessGenuine(w, R + [r], SmallSchema())
        {
          match TryAdd(R, r, SmallSchema())
            case Accepted(r2) => {
              AddPreserves(R, r, SmallSchema());
            }
            case Rejected(w) => {
              WitnessSoundness(R, r, SmallSchema(), w);
            }
        }
      }
    }
  }
}
