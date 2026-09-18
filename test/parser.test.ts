import { describe, expect, test } from "bun:test";
import type { Schema } from "#src/index.js";
import { loadSchema, ParseError, parseRule } from "#src/index.js";

function tinySchema(): Schema {
  return loadSchema([
    { family: "group", name: "name", type: "Enum", values: ["x", "y"] },
    { family: "box", name: "n", type: "BoundedInt", lo: 0, hi: 10 },
    { family: "flag", name: "on", type: "Bool" },
  ]);
}

describe("parseRule", () => {
  test("parses a basic permit with id 0 placeholder", () => {
    const r = parseRule("Permit where group.name == x", tinySchema());
    expect(r).toEqual({
      id: 0,
      effect: "Permit",
      target: {
        kind: "atom",
        family: "group",
        attr: "name",
        op: "==",
        lit: "x",
        num: 0,
      },
    });
  });

  test("desugars in-lists to or-chains", () => {
    const r = parseRule("Deny where group.name in {x, y}", tinySchema());
    if (r instanceof ParseError) throw new Error(r.message);
    expect(r.effect).toBe("Deny");
    expect(r.target).toEqual({
      kind: "or",
      a: {
        kind: "atom",
        family: "group",
        attr: "name",
        op: "==",
        lit: "x",
        num: 0,
      },
      b: {
        kind: "atom",
        family: "group",
        attr: "name",
        op: "==",
        lit: "y",
        num: 0,
      },
    });
  });

  test("desugars between to a conjunction", () => {
    const r = parseRule("Permit where box.n between 2 and 5", tinySchema());
    if (r instanceof ParseError) throw new Error(r.message);
    expect(r.target).toEqual({
      kind: "and",
      a: { kind: "atom", family: "box", attr: "n", op: ">=", lit: "", num: 2 },
      b: { kind: "atom", family: "box", attr: "n", op: "<=", lit: "", num: 5 },
    });
  });

  test("respects ! over && over || with parens", () => {
    const r = parseRule(
      "Permit where !flag.on == true || box.n == 1 && group.name == x",
      tinySchema(),
    );
    if (r instanceof ParseError) throw new Error(r.message);
    expect(r.target.kind).toBe("or");
    if (r.target.kind !== "or") throw new Error("unreachable");
    expect(r.target.a.kind).toBe("not");
    expect(r.target.b.kind).toBe("and");
    const grouped = parseRule(
      "Permit where !(flag.on == true || box.n == 1) && group.name == x",
      tinySchema(),
    );
    if (grouped instanceof ParseError) throw new Error(grouped.message);
    expect(grouped.target.kind).toBe("and");
    if (grouped.target.kind !== "and") throw new Error("unreachable");
    expect(grouped.target.a.kind).toBe("not");
  });

  test("accepts != and comparisons on ints", () => {
    const r = parseRule(
      "Deny where box.n != 3 && box.n < 10 && box.n >= 0",
      tinySchema(),
    );
    if (r instanceof ParseError) throw new Error(r.message);
    expect(r.target.kind).toBe("and");
  });

  test("rejects unknown attributes", () => {
    const r = parseRule("Permit where nope.attr == 1", tinySchema());
    expect(r).toBeInstanceOf(ParseError);
  });

  test("rejects bad operators on bool and enum", () => {
    expect(
      parseRule("Permit where flag.on > true", tinySchema()),
    ).toBeInstanceOf(ParseError);
    expect(
      parseRule("Permit where group.name < x", tinySchema()),
    ).toBeInstanceOf(ParseError);
  });

  test("rejects out-of-domain literals", () => {
    expect(
      parseRule("Permit where group.name == z", tinySchema()),
    ).toBeInstanceOf(ParseError);
    expect(parseRule("Permit where box.n == 11", tinySchema())).toBeInstanceOf(
      ParseError,
    );
    expect(
      parseRule("Permit where flag.on == maybe", tinySchema()),
    ).toBeInstanceOf(ParseError);
    expect(
      parseRule("Permit where box.n between 2 and 99", tinySchema()),
    ).toBeInstanceOf(ParseError);
    expect(
      parseRule("Permit where box.n between 5 and 2", tinySchema()),
    ).toBeInstanceOf(ParseError);
    expect(
      parseRule("Permit where group.name in {}", tinySchema()),
    ).toBeInstanceOf(ParseError);
  });

  test("rejects malformed rules with offsets", () => {
    const cases = [
      "Allow where group.name == x",
      "Permit group.name == x",
      "Permit where group.name == x extra",
      "Permit where group.name == @",
      "Permit where ",
    ];
    for (const src of cases) {
      const r = parseRule(src, tinySchema());
      expect(r).toBeInstanceOf(ParseError);
      if (r instanceof ParseError) {
        expect(typeof r.offset).toBe("number");
      }
    }
  });
});
