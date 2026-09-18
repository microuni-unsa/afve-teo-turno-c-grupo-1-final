// Attribute schema (PIP contract): declarations, positional requests,
// bounded enumeration of all schema-valid requests with soundness and
// completeness lemmas. Requests are positional: req[i] is the value for
// schema[i]. This keeps enumeration and proofs in pure sequence theory.
module Schema {
  datatype AttrType = Enum | Bool | BoundedInt

  datatype AttrDecl = AttrDecl(
    family: string,
    name: string,
    attrType: AttrType,
    enumVals: seq<string>,
    lo: int,
    hi: int
  )

  type Schema = seq<AttrDecl>

  datatype Value = EnumVal(s: string) | BoolVal(b: bool) | IntVal(n: int)

  type Request = seq<Value>

  const DEFAULT_INT_MIN: int := 0
  const DEFAULT_INT_MAX: int := 100
  const MAX_ENUM_VALUES: int := 16
  const MAX_RULES_CHECKED: int := 64

  function AttrKey(family: string, name: string): string {
    family + "." + name
  }

  function DeclKey(d: AttrDecl): string {
    AttrKey(d.family, d.name)
  }

  predicate ValidDecl(d: AttrDecl) {
    && (d.attrType.Enum? ==> 0 < |d.enumVals| <= MAX_ENUM_VALUES)
    && (d.attrType.BoundedInt? ==> d.lo <= d.hi)
  }

  predicate SchemaWellFormed(schema: Schema) {
    && (forall d :: d in schema ==> ValidDecl(d))
    && (forall i, j :: 0 <= i < j < |schema| ==> DeclKey(schema[i]) != DeclKey(schema[j]))
  }

  predicate ValueMatchesDecl(v: Value, d: AttrDecl) {
    || (v.EnumVal? && d.attrType.Enum? && v.s in d.enumVals)
    || (v.BoolVal? && d.attrType.Bool?)
    || (v.IntVal? && d.attrType.BoundedInt? && d.lo <= v.n <= d.hi)
  }

  predicate ValidRequest(req: Request, schema: Schema) {
    |req| == |schema| && forall i :: 0 <= i < |schema| ==> ValueMatchesDecl(req[i], schema[i])
  }

  // ---- Bounded enumeration of all schema-valid requests ----

  function EnumValsAsValues(vals: seq<string>): seq<Value> {
    if |vals| == 0 then [] else [EnumVal(vals[0])] + EnumValsAsValues(vals[1..])
  }

  function IntRangeAsValues(lo: int, hi: int): seq<Value>
    decreases hi - lo
  {
    if hi < lo then [] else [IntVal(lo)] + IntRangeAsValues(lo + 1, hi)
  }
  function ValuesForDecl(d: AttrDecl): seq<Value> {
    if d.attrType.Enum? then EnumValsAsValues(d.enumVals)
    else if d.attrType.Bool? then [BoolVal(true), BoolVal(false)]
    else IntRangeAsValues(d.lo, d.hi)
  }

  function PrependHead(v: Value, tails: seq<Request>): seq<Request> {
    seq(|tails|, i requires 0 <= i < |tails| => [v] + tails[i])
  }
  function CombineHeads(vs: seq<Value>, tails: seq<Request>): seq<Request> {
    if |vs| == 0 then [] else PrependHead(vs[0], tails) + CombineHeads(vs[1..], tails)
  }

  function AllRequests(schema: Schema): seq<Request> {
    if |schema| == 0 then [[]]
    else CombineHeads(ValuesForDecl(schema[0]), AllRequests(schema[1..]))
  }

  lemma TailWellFormed(schema: Schema)
    requires |schema| > 0
    requires SchemaWellFormed(schema)
  {
    assert forall d :: d in schema[1..] ==> d in schema;
    assert forall i :: 0 <= i < |schema[1..]| ==> schema[1..][i] == schema[i + 1];
  }

  // ---- Value-domain membership lemmas ----

  lemma EnumValsAsValuesMember(vals: seq<string>, s: string)
    ensures (EnumVal(s) in EnumValsAsValues(vals)) <==> (s in vals)
  {
    if |vals| == 0 {
    } else {
      EnumValsAsValuesMember(vals[1..], s);
    }
  }

  lemma EnumValsAsValuesAreEnum(vals: seq<string>)
    ensures forall i :: 0 <= i < |EnumValsAsValues(vals)| ==> EnumValsAsValues(vals)[i].EnumVal?
  {
    if |vals| == 0 {
    } else {
      EnumValsAsValuesAreEnum(vals[1..]);
    }
  }

  lemma IntRangeAsValuesMember(lo: int, hi: int, n: int)
    ensures (IntVal(n) in IntRangeAsValues(lo, hi)) <==> (lo <= n <= hi)
    decreases hi - lo
  {
    if hi < lo {
    } else if n == lo {
    } else {
      IntRangeAsValuesMember(lo + 1, hi, n);
    }
  }

  lemma IntRangeAsValuesAreInt(lo: int, hi: int)
    ensures forall i :: 0 <= i < |IntRangeAsValues(lo, hi)| ==> IntRangeAsValues(lo, hi)[i].IntVal?
    decreases hi - lo
  {
    if hi < lo {
    } else {
      IntRangeAsValuesAreInt(lo + 1, hi);
    }
  }

  lemma ValuesForDeclMember(v: Value, d: AttrDecl)
    requires ValidDecl(d)
    ensures (v in ValuesForDecl(d)) <==> ValueMatchesDecl(v, d)
  {
    if d.attrType.Enum? {
      if v.EnumVal? {
        EnumValsAsValuesMember(d.enumVals, v.s);
      } else {
        EnumValsAsValuesAreEnum(d.enumVals);
      }
    } else if d.attrType.Bool? {
    } else {
      if v.IntVal? {
        IntRangeAsValuesMember(d.lo, d.hi, v.n);
      } else {
        IntRangeAsValuesAreInt(d.lo, d.hi);
      }
    }
  }

  lemma PrependHeadMember(v: Value, tails: seq<Request>, req: Request)
    ensures (req in PrependHead(v, tails)) <==> (exists t :: t in tails && req == [v] + t)
  {
    assert |PrependHead(v, tails)| == |tails|;
    assert forall i :: 0 <= i < |tails| ==> PrependHead(v, tails)[i] == [v] + tails[i];
    if req in PrependHead(v, tails) {
      var i :| 0 <= i < |PrependHead(v, tails)| && PrependHead(v, tails)[i] == req;
      var t := tails[i];
      assert t in tails && req == [v] + t;
    }
    if exists t :: t in tails && req == [v] + t {
      var t :| t in tails && req == [v] + t;
      var i :| 0 <= i < |tails| && tails[i] == t;
      assert PrependHead(v, tails)[i] == req;
      assert req in PrependHead(v, tails);
    }
  }

  lemma CombineHeadsMember(vs: seq<Value>, tails: seq<Request>, req: Request)
    ensures (req in CombineHeads(vs, tails)) <==> (exists v :: v in vs && exists t :: t in tails && req == [v] + t)
  {
    if |vs| == 0 {
    } else {
      PrependHeadMember(vs[0], tails, req);
      CombineHeadsMember(vs[1..], tails, req);
    }
  }

  // ---- Enumeration soundness and completeness ----

  lemma AllRequestsSound(schema: Schema, req: Request)
    requires SchemaWellFormed(schema)
    requires req in AllRequests(schema)
    ensures ValidRequest(req, schema)
  {
    if |schema| == 0 {
      assert req == [];
    } else {
      TailWellFormed(schema);
      CombineHeadsMember(ValuesForDecl(schema[0]), AllRequests(schema[1..]), req);
      var v :| v in ValuesForDecl(schema[0]) && exists t :: t in AllRequests(schema[1..]) && req == [v] + t;
      var t :| t in AllRequests(schema[1..]) && req == [v] + t;
      AllRequestsSound(schema[1..], t);
      ValuesForDeclMember(v, schema[0]);
      assert |req| == |schema|;
      assert forall i :: 0 <= i < |schema| ==> ValueMatchesDecl(req[i], schema[i]);
    }
  }

  lemma AllRequestsComplete(schema: Schema, req: Request)
    requires SchemaWellFormed(schema)
    requires ValidRequest(req, schema)
    ensures req in AllRequests(schema)
  {
    if |schema| == 0 {
      assert req == [];
    } else {
      TailWellFormed(schema);
      assert ValidRequest(req[1..], schema[1..]) by {
        assert |req[1..]| == |schema[1..]|;
        assert forall i :: 0 <= i < |schema[1..]| ==> req[1..][i] == req[i + 1];
        assert forall i :: 0 <= i < |schema[1..]| ==> schema[1..][i] == schema[i + 1];
      }
      AllRequestsComplete(schema[1..], req[1..]);
      ValuesForDeclMember(req[0], schema[0]);
      CombineHeadsMember(ValuesForDecl(schema[0]), AllRequests(schema[1..]), req);
      assert req == [req[0]] + req[1..];
    }
  }
}
