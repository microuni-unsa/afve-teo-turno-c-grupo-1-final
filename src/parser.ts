import { ParseError } from "#src/errors.js";
import {
  type AttrDecl,
  type CmpOp,
  findDecl,
  type Pred,
  type Rule,
  type Schema,
} from "#src/schema.js";

interface Token {
  text: string;
  pos: number;
  num: number;
  isNum: boolean;
}

const TWO_CHAR_OPS: Record<string, true> = {
  "==": true,
  "!=": true,
  "<=": true,
  ">=": true,
  "&&": true,
  "||": true,
};

const ONE_CHAR_OPS: Record<string, true> = {
  "<": true,
  ">": true,
  "!": true,
  "(": true,
  ")": true,
  "{": true,
  "}": true,
  ",": true,
  ".": true,
};

function isIdentStart(c: string): boolean {
  return (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c === "_";
}

function isIdentChar(c: string): boolean {
  return isIdentStart(c) || (c >= "0" && c <= "9");
}

function isDigit(c: string): boolean {
  return c >= "0" && c <= "9";
}

function tokenize(src: string): Token[] {
  const tokens: Token[] = [];
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    if (c === " " || c === "\t" || c === "\n" || c === "\r") {
      i++;
      continue;
    }
    const two = src.slice(i, i + 2);
    if (TWO_CHAR_OPS[two] === true) {
      tokens.push({ text: two, pos: i, num: 0, isNum: false });
      i += 2;
      continue;
    }
    if (ONE_CHAR_OPS[c] === true) {
      tokens.push({ text: c, pos: i, num: 0, isNum: false });
      i++;
      continue;
    }
    if (isDigit(c) || (c === "-" && isDigit(src[i + 1] ?? ""))) {
      let j = i + (c === "-" ? 1 : 0);
      while (j < src.length && isDigit(src[j])) j++;
      const text = src.slice(i, j);
      tokens.push({
        text,
        pos: i,
        num: Number.parseInt(text, 10),
        isNum: true,
      });
      i = j;
      continue;
    }
    if (isIdentStart(c)) {
      let j = i + 1;
      while (j < src.length && isIdentChar(src[j])) j++;
      tokens.push({ text: src.slice(i, j), pos: i, num: 0, isNum: false });
      i = j;
      continue;
    }
    throw new ParseError(`unexpected character '${c}'`, i);
  }
  return tokens;
}

class Parser {
  private pos = 0;

  constructor(
    private readonly tokens: Token[],
    private readonly src: string,
    private readonly schema: Schema,
  ) {}

  private get eof(): boolean {
    return this.pos >= this.tokens.length;
  }

  private peek(): Token {
    if (this.eof) {
      throw new ParseError("unexpected end of input", this.src.length);
    }
    return this.tokens[this.pos];
  }

  private eat(text: string): Token {
    const t = this.peek();
    if (t.text !== text) {
      throw new ParseError(`expected '${text}', found '${t.text}'`, t.pos);
    }
    this.pos++;
    return t;
  }

  parseRule(): Rule {
    const head = this.peek();
    if (head.text !== "Permit" && head.text !== "Deny") {
      throw new ParseError("rule must start with 'Permit' or 'Deny'", head.pos);
    }
    this.pos++;
    this.eat("where");
    const target = this.parseOr();
    if (!this.eof) {
      throw new ParseError(
        `unexpected trailing input '${this.peek().text}'`,
        this.peek().pos,
      );
    }
    return { id: 0, effect: head.text, target };
  }

  private parseOr(): Pred {
    let left = this.parseAnd();
    while (!this.eof && this.tokens[this.pos].text === "||") {
      this.pos++;
      left = { kind: "or", a: left, b: this.parseAnd() };
    }
    return left;
  }

  private parseAnd(): Pred {
    let left = this.parseUnary();
    while (!this.eof && this.tokens[this.pos].text === "&&") {
      this.pos++;
      left = { kind: "and", a: left, b: this.parseUnary() };
    }
    return left;
  }

  private parseUnary(): Pred {
    if (!this.eof && this.tokens[this.pos].text === "!") {
      this.pos++;
      return { kind: "not", p: this.parseUnary() };
    }
    if (!this.eof && this.tokens[this.pos].text === "(") {
      this.pos++;
      const inner = this.parseOr();
      this.eat(")");
      return inner;
    }
    return this.parseAtom();
  }

  private parseRef(): { family: string; attr: string; pos: number } {
    const family = this.peek();
    if (!isIdentStart(family.text[0] ?? "")) {
      throw new ParseError(
        `expected attribute reference, found '${family.text}'`,
        family.pos,
      );
    }
    this.pos++;
    this.eat(".");
    const attr = this.peek();
    if (!isIdentStart(attr.text[0] ?? "")) {
      throw new ParseError(
        `expected attribute name, found '${attr.text}'`,
        attr.pos,
      );
    }
    this.pos++;
    return { family: family.text, attr: attr.text, pos: family.pos };
  }

  private parseAtom(): Pred {
    const ref = this.parseRef();
    const decl = findDecl(this.schema, ref.family, ref.attr);
    if (decl === undefined) {
      throw new ParseError(
        `unknown attribute '${ref.family}.${ref.attr}'`,
        ref.pos,
      );
    }
    const next = this.peek();
    if (next.text === "in") {
      return this.parseInList(decl, next.pos);
    }
    if (next.text === "between") {
      return this.parseBetween(decl, next.pos);
    }
    if (
      next.text !== "==" &&
      next.text !== "!=" &&
      next.text !== "<" &&
      next.text !== "<=" &&
      next.text !== ">" &&
      next.text !== ">="
    ) {
      throw new ParseError(
        `expected operator, 'in', or 'between', found '${next.text}'`,
        next.pos,
      );
    }
    const op = next.text as CmpOp;
    this.pos++;
    return this.parseAtomLiteral(decl, op, this.peek());
  }

  private parseAtomLiteral(decl: AttrDecl, op: CmpOp, lit: Token): Pred {
    const family = decl.family;
    const attr = decl.name;
    if (decl.type === "Bool") {
      if (op !== "==" && op !== "!=") {
        throw new ParseError(
          `operator '${op}' not allowed on Bool '${family}.${attr}'`,
          lit.pos,
        );
      }
      if (lit.text !== "true" && lit.text !== "false") {
        throw new ParseError(
          `Bool '${family}.${attr}' needs 'true' or 'false', found '${lit.text}'`,
          lit.pos,
        );
      }
      this.pos++;
      return { kind: "atom", family, attr, op, lit: lit.text, num: 0 };
    }
    if (decl.type === "Enum") {
      if (op !== "==" && op !== "!=") {
        throw new ParseError(
          `operator '${op}' not allowed on Enum '${family}.${attr}'`,
          lit.pos,
        );
      }
      if (!decl.values.includes(lit.text)) {
        throw new ParseError(
          `'${family}.${attr}' must be one of [${decl.values.join(", ")}], found '${lit.text}'`,
          lit.pos,
        );
      }
      this.pos++;
      return { kind: "atom", family, attr, op, lit: lit.text, num: 0 };
    }
    if (!lit.isNum) {
      throw new ParseError(
        `BoundedInt '${family}.${attr}' needs an integer literal, found '${lit.text}'`,
        lit.pos,
      );
    }
    if (lit.num < decl.lo || lit.num > decl.hi) {
      throw new ParseError(
        `literal ${lit.num} outside [${decl.lo}, ${decl.hi}] for '${family}.${attr}'`,
        lit.pos,
      );
    }
    this.pos++;
    return { kind: "atom", family, attr, op, lit: "", num: lit.num };
  }

  private parseInList(decl: AttrDecl, pos: number): Pred {
    this.pos++;
    this.eat("{");
    const lits: Token[] = [];
    if (!this.eof && this.tokens[this.pos].text !== "}") {
      lits.push(this.peek());
      this.pos++;
      while (!this.eof && this.tokens[this.pos].text === ",") {
        this.pos++;
        lits.push(this.peek());
        this.pos++;
      }
    }
    this.eat("}");
    if (lits.length === 0) {
      throw new ParseError(
        `empty 'in' list for '${decl.family}.${decl.name}'`,
        pos,
      );
    }
    let acc: Pred | undefined;
    for (const lit of lits) {
      const atom = this.parseAtomLiteral(decl, "==", lit);
      acc = acc === undefined ? atom : { kind: "or", a: acc, b: atom };
    }
    if (acc === undefined) {
      throw new ParseError(
        `empty 'in' list for '${decl.family}.${decl.name}'`,
        pos,
      );
    }
    return acc;
  }

  private parseBetween(decl: AttrDecl, pos: number): Pred {
    if (decl.type !== "BoundedInt") {
      throw new ParseError(
        `'between' requires a BoundedInt attribute, '${decl.family}.${decl.name}' is not one`,
        pos,
      );
    }
    this.pos++;
    const loTok = this.peek();
    if (!loTok.isNum) {
      throw new ParseError(
        `'between' needs an integer lower bound, found '${loTok.text}'`,
        loTok.pos,
      );
    }
    this.pos++;
    this.eat("and");
    const hiTok = this.peek();
    if (!hiTok.isNum) {
      throw new ParseError(
        `'between' needs an integer upper bound, found '${hiTok.text}'`,
        hiTok.pos,
      );
    }
    this.pos++;
    if (
      loTok.num < decl.lo ||
      loTok.num > decl.hi ||
      hiTok.num < decl.lo ||
      hiTok.num > decl.hi
    ) {
      throw new ParseError(
        `'between' bounds must lie in [${decl.lo}, ${decl.hi}] for '${decl.family}.${decl.name}'`,
        pos,
      );
    }
    if (loTok.num > hiTok.num) {
      throw new ParseError(
        `'between' lower bound exceeds upper bound for '${decl.family}.${decl.name}'`,
        pos,
      );
    }
    return {
      kind: "and",
      a: {
        kind: "atom",
        family: decl.family,
        attr: decl.name,
        op: ">=",
        lit: "",
        num: loTok.num,
      },
      b: {
        kind: "atom",
        family: decl.family,
        attr: decl.name,
        op: "<=",
        lit: "",
        num: hiTok.num,
      },
    };
  }
}

/**
 * Parse `Permit where <pred>` / `Deny where <pred>`. Supports `! && ||`,
 * parens, `in {a, b}`, and `between m and n` (desugared to the core).
 * Returns the Rule with id 0 (unassigned); tryAdd assigns ids on commit.
 * All syntax, type, and domain violations return a ParseError value;
 * check the result with instanceof before use.
 */
export function parseRule(src: string, schema: Schema): Rule | ParseError {
  try {
    const tokens = tokenize(src);
    return new Parser(tokens, src, schema).parseRule();
  } catch (err) {
    if (err instanceof ParseError) return err;
    throw err;
  }
}
