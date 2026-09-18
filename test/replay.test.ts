import { describe, expect, test } from "bun:test";
import { readdirSync, readFileSync } from "node:fs";
import type { FailedProperty, Rule, Ruleset } from "#src/index.js";
import {
  checkCoherent,
  evaluate,
  explain,
  loadSchema,
  parseRule,
  tryAdd,
} from "#src/index.js";

const fixturesDir = new URL("../fixtures/", import.meta.url);

interface Fixture {
  description: string;
  schema: string;
  rules: string[];
  expect:
    | { status: "Accepted"; ids: number[] }
    | { status: "Rejected"; failedProperty: FailedProperty; ruleIds: number[] };
}

function loadFixture(name: string): Fixture {
  const raw: unknown = JSON.parse(
    readFileSync(new URL(name, fixturesDir), "utf8"),
  );
  if (typeof raw !== "object" || raw === null)
    throw new Error(`bad fixture ${name}`);
  return raw as Fixture;
}

function loadSchemaByName(schemaFile: string) {
  const decls: unknown = JSON.parse(
    readFileSync(new URL(schemaFile, fixturesDir), "utf8"),
  );
  return loadSchema(decls);
}

const fixtureFiles = readdirSync(fixturesDir).filter(
  (f) => f.endsWith(".json") && f !== "schema-v1.json",
);

describe("fixture replay", () => {
  for (const file of fixtureFiles) {
    test(file, () => {
      const fx = loadFixture(file);
      const schema = loadSchemaByName(fx.schema);
      let rs: Ruleset = [];
      for (const text of fx.rules) {
        const parsed = parseRule(text, schema);
        if (parsed instanceof Error) {
          throw new Error(
            `fixture ${file} failed to parse '${text}': ${parsed.message}`,
          );
        }
        const before = JSON.stringify(rs);
        const res = tryAdd(rs, parsed, schema);
        if (res.status === "Rejected") {
          expect(JSON.parse(before)).toEqual(rs);
          if (fx.expect.status !== "Rejected") {
            throw new Error(
              `fixture ${file} unexpectedly rejected: ${explain(res.witness)}`,
            );
          }
          expect(res.witness.failedProperty).toBe(fx.expect.failedProperty);
          expect(res.witness.ruleIds).toEqual(fx.expect.ruleIds);
          return;
        }
        rs = res.ruleset;
      }
      if (fx.expect.status !== "Accepted") {
        throw new Error(`fixture ${file} unexpectedly accepted`);
      }
      expect(rs.map((r) => r.id)).toEqual(fx.expect.ids);
      const report = checkCoherent(rs, schema);
      expect(report.coherent).toBe(true);
      expect(report.perProperty).toEqual({
        P1: true,
        P2: true,
        P3: true,
        P4: true,
      });
    });
  }

  test("clean fixture evaluates end to end", () => {
    const fx = loadFixture("clean.json");
    const schema = loadSchemaByName(fx.schema);
    let rs: Ruleset = [];
    for (const text of fx.rules) {
      const parsed = parseRule(text, schema) as Rule;
      rs = (
        tryAdd(rs, parsed, schema) as { status: "Accepted"; ruleset: Ruleset }
      ).ruleset;
    }
    const permit = evaluate(
      rs,
      {
        "subject.role": "medic",
        "subject.dept": "cardio",
        "subject.clearance": 5,
        "resource.type": "record",
        "resource.sensitivity": 1,
        "action.name": "read",
        "environment.hour": 10,
        "environment.emergency": false,
      },
      schema,
    );
    expect(permit).toEqual({ decision: "Permit", firingRuleIds: [1] });
    const deny = evaluate(
      rs,
      {
        "subject.role": "nurse",
        "subject.dept": "er",
        "subject.clearance": 1,
        "resource.type": "lab",
        "resource.sensitivity": 5,
        "action.name": "write",
        "environment.hour": 10,
        "environment.emergency": false,
      },
      schema,
    );
    expect(deny).toEqual({ decision: "Deny", firingRuleIds: [2] });
    const override = evaluate(
      rs,
      {
        "subject.role": "nurse",
        "subject.dept": "er",
        "subject.clearance": 5,
        "resource.type": "record",
        "resource.sensitivity": 1,
        "action.name": "read",
        "environment.hour": 3,
        "environment.emergency": true,
      },
      schema,
    );
    expect(override).toEqual({ decision: "Permit", firingRuleIds: [3] });
  });

  test("witness explanations are exact", () => {
    const schema = loadSchemaByName("schema-v1.json");
    const firstReq =
      "subject.role=medic, subject.dept=cardio, subject.clearance=1, resource.type=record, " +
      "resource.sensitivity=1, action.name=read, environment.hour=0, environment.emergency=true";
    const add = (texts: string[]): Ruleset => {
      let rs: Ruleset = [];
      for (const text of texts) {
        const res = tryAdd(rs, parseRule(text, schema) as Rule, schema);
        if (res.status === "Accepted") rs = res.ruleset;
        else return rs;
      }
      return rs;
    };
    const c1 = tryAdd(
      add([]),
      parseRule(
        "Permit where subject.role == medic && action.name == read",
        schema,
      ) as Rule,
      schema,
    );
    if (c1.status !== "Accepted") throw new Error("setup failed");
    const c2 = tryAdd(
      c1.ruleset,
      parseRule(
        "Deny where subject.role == medic && action.name == read",
        schema,
      ) as Rule,
      schema,
    );
    if (c2.status !== "Rejected") throw new Error("setup failed");
    expect(explain(c2.witness)).toBe(
      `Permit rule #1 and Deny rule #2 both fire when ${firstReq}.`,
    );

    const s1 = tryAdd(
      add([]),
      parseRule("Permit where subject.role == medic", schema) as Rule,
      schema,
    );
    if (s1.status !== "Accepted") throw new Error("setup failed");
    const s2 = tryAdd(
      s1.ruleset,
      parseRule(
        "Permit where subject.role == medic && subject.dept == cardio",
        schema,
      ) as Rule,
      schema,
    );
    if (s2.status !== "Rejected") throw new Error("setup failed");
    expect(explain(s2.witness)).toBe(
      `Rule #2 never alone decides a request (covered by #1 when ${firstReq}).`,
    );

    const u1 = tryAdd(
      add([]),
      parseRule(
        "Permit where subject.clearance > 5 && subject.clearance < 2",
        schema,
      ) as Rule,
      schema,
    );
    if (u1.status !== "Rejected") throw new Error("setup failed");
    expect(explain(u1.witness)).toBe("Rule #1 never fires on any request.");

    const e1 = tryAdd(
      add([]),
      parseRule("Permit where environment.emergency == true", schema) as Rule,
      schema,
    );
    if (e1.status !== "Accepted") throw new Error("setup failed");
    const e2 = tryAdd(
      e1.ruleset,
      parseRule("Deny where environment.hour >= 18", schema) as Rule,
      schema,
    );
    if (e2.status !== "Rejected") throw new Error("setup failed");
    expect(explain(e2.witness)).toBe(
      "Permit rule #1 and Deny rule #2 both fire when subject.role=medic, subject.dept=cardio, " +
        "subject.clearance=1, resource.type=record, resource.sensitivity=1, action.name=read, " +
        "environment.hour=18, environment.emergency=true.",
    );
  });
});
