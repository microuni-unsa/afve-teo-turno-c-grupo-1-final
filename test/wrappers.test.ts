import { describe, expect, test } from "bun:test";
import type { Rule, Ruleset, Schema } from "#src/index.js";
import {
  checkCoherent,
  DomainError,
  evaluate,
  loadSchema,
  parseRule,
  remove,
  TooLarge,
  tryAdd,
  tryAddMany,
  tryUpdate,
} from "#src/index.js";
import { fromDafnyRule, toDafnyRule, verifier } from "#src/schema.js";

function tinySchema(): Schema {
  return loadSchema([
    { family: "group", name: "name", type: "Enum", values: ["x", "y"] },
    { family: "box", name: "n", type: "BoundedInt", lo: 0, hi: 3 },
  ]);
}

function mustParse(text: string, schema: Schema): Rule {
  const r = parseRule(text, schema);
  if (r instanceof Error) throw r;
  return r;
}

describe("wrappers", () => {
  test("tryAdd assigns sequential ids and preserves content", () => {
    const schema = tinySchema();
    const a = tryAdd(
      [],
      mustParse("Permit where group.name == x", schema),
      schema,
    );
    if (a.status !== "Accepted") throw new Error("setup failed");
    expect(a.ruleset.map((r) => r.id)).toEqual([1]);
    expect(a.ruleset[0].effect).toBe("Permit");
    const b = tryAdd(
      a.ruleset,
      mustParse("Deny where group.name == y", schema),
      schema,
    );
    if (b.status !== "Accepted") throw new Error("setup failed");
    expect(b.ruleset.map((r) => r.id)).toEqual([1, 2]);
  });

  test("rejected commits leave the input ruleset unchanged", () => {
    const schema = tinySchema();
    const a = tryAdd(
      [],
      mustParse("Permit where group.name == x", schema),
      schema,
    );
    if (a.status !== "Accepted") throw new Error("setup failed");
    const before = JSON.parse(JSON.stringify(a.ruleset));
    const res = tryAdd(
      a.ruleset,
      mustParse("Deny where group.name == x", schema),
      schema,
    );
    if (res.status !== "Rejected") throw new Error("expected rejection");
    expect(res.witness.failedProperty).toBe("P1");
    expect(a.ruleset).toEqual(before);
  });

  test("tryUpdate keeps the id and guards the replacement", () => {
    const schema = tinySchema();
    const a = tryAdd(
      [],
      mustParse("Permit where group.name == x", schema),
      schema,
    );
    if (a.status !== "Accepted") throw new Error("setup failed");
    const ok = tryUpdate(
      a.ruleset,
      1,
      mustParse("Permit where group.name == y", schema),
      schema,
    );
    if (ok.status !== "Accepted") throw new Error("setup failed");
    expect(ok.ruleset).toHaveLength(1);
    expect(ok.ruleset[0].id).toBe(1);
    const bad = tryUpdate(
      a.ruleset,
      99,
      mustParse("Permit where group.name == y", schema),
      schema,
    );
    if (bad.status !== "Rejected") throw new Error("expected rejection");
    expect(bad.witness.failedProperty).toBe("P4");
    expect(bad.witness.ruleIds).toEqual([99]);
    const clash = tryUpdate(
      ok.ruleset,
      1,
      mustParse("Deny where group.name == y", schema),
      schema,
    );
    if (clash.status !== "Accepted") throw new Error("setup failed");
    const clash2 = tryAdd(
      clash.ruleset,
      mustParse("Permit where group.name == y", schema),
      schema,
    );
    if (clash2.status !== "Rejected") throw new Error("expected rejection");
    expect(clash2.witness.failedProperty).toBe("P1");
  });

  test("remove drops by id and preserves coherence", () => {
    const schema = tinySchema();
    let rs: Ruleset = [];
    for (const text of [
      "Permit where group.name == x",
      "Deny where group.name == y",
    ]) {
      const res = tryAdd(rs, mustParse(text, schema), schema);
      if (res.status !== "Accepted") throw new Error("setup failed");
      rs = res.ruleset;
    }
    const dropped = remove(rs, 1, schema);
    expect(dropped.map((r) => r.id)).toEqual([2]);
    expect(checkCoherent(dropped, schema).coherent).toBe(true);
    expect(remove(rs, 99, schema)).toEqual(rs);
  });

  test("checkCoherent reports raw incoherent rulesets per property", () => {
    const schema = tinySchema();
    const raw: Ruleset = [
      { ...mustParse("Permit where group.name == x", schema), id: 1 },
      { ...mustParse("Deny where group.name == x", schema), id: 2 },
    ];
    const report = checkCoherent(raw, schema);
    expect(report.coherent).toBe(false);
    expect(report.perProperty.P1).toBe(false);
    expect(report.perProperty.P2).toBe(true);
    expect(report.witness?.failedProperty).toBe("P1");
  });

  test("evaluate rejects out-of-domain requests at the boundary", () => {
    const schema = tinySchema();
    const a = tryAdd(
      [],
      mustParse("Permit where group.name == x", schema),
      schema,
    );
    if (a.status !== "Accepted") throw new Error("setup failed");
    expect(() => evaluate(a.ruleset, { "group.name": "x" }, schema)).toThrow(
      DomainError,
    );
    expect(() =>
      evaluate(a.ruleset, { "group.name": "x", "box.n": 99 }, schema),
    ).toThrow(DomainError);
    expect(() =>
      evaluate(a.ruleset, { "group.name": "x", "box.n": 1.5 }, schema),
    ).toThrow(DomainError);
    expect(() =>
      evaluate(
        a.ruleset,
        { "group.name": "x", "box.n": 1, "other.a": 1 },
        schema,
      ),
    ).toThrow(DomainError);
    expect(() =>
      evaluate(a.ruleset, { "group.name": "z", "box.n": 1 }, schema),
    ).toThrow(DomainError);
  });

  test("oversized batches throw TooLarge unless opted in", () => {
    const schema = tinySchema();
    const many: Rule[] = [];
    for (let i = 0; i < 65; i++) {
      many.push(mustParse("Permit where group.name == x", schema));
    }
    let err: unknown;
    try {
      tryAddMany([], many, schema);
    } catch (e) {
      err = e;
    }
    expect(err).toBeInstanceOf(TooLarge);
    if (err instanceof TooLarge) {
      expect(err.limit).toBe(64);
      expect(err.actual).toBe(65);
    }
    const res = tryAddMany([], many, schema, { allowUnbounded: true });
    expect(res.status === "Accepted" || res.status === "Rejected").toBe(true);
  });

  test("oversized enum domains throw TooLarge unless opted in", () => {
    const decls = [
      {
        family: "g",
        name: "n",
        type: "Enum",
        values: Array.from({ length: 17 }, (_, i) => `v${i}`),
      },
    ];
    expect(() => loadSchema(decls)).toThrow(TooLarge);
    const schema = loadSchema(decls, { allowUnbounded: true });
    expect(schema.decls).toHaveLength(1);
  });

  test("request-space blowup is capped at load", () => {
    const decls = [
      { family: "env", name: "big", type: "BoundedInt", lo: 0, hi: 2000000 },
    ];
    expect(() => loadSchema(decls)).toThrow(TooLarge);
    expect(loadSchema(decls, { allowUnbounded: true }).decls).toHaveLength(1);
  });

  test("Dafny and TS caps agree", () => {
    const root = verifier.Schema.__default as Record<string, unknown>;
    const num = (v: unknown): number =>
      (v as { toNumber(): number }).toNumber();
    expect(num(root.MAX__ENUM__VALUES)).toBe(16);
    expect(num(root.MAX__RULES__CHECKED)).toBe(64);
    expect(num(root.DEFAULT__INT__MIN)).toBe(0);
    expect(num(root.DEFAULT__INT__MAX)).toBe(100);
  });

  test("rule marshal round-trips through Dafny values", () => {
    const schema = tinySchema();
    const rule = {
      ...mustParse("Permit where group.name == x && box.n >= 1", schema),
      id: 7,
    };
    expect(fromDafnyRule(toDafnyRule(rule))).toEqual(rule);
    void schema;
  });
});
