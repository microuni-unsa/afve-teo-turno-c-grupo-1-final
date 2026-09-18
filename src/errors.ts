export class TooLarge extends Error {
  readonly limit: number;
  readonly actual: number;
  constructor(limit: number, actual: number, what: string) {
    super(`${what} exceeds the verified bound: got ${actual}, limit ${limit}`);
    this.name = "TooLarge";
    this.limit = limit;
    this.actual = actual;
  }
}

export class SchemaError extends Error {
  constructor(message: string) {
    super(`Invalid schema: ${message}`);
    this.name = "SchemaError";
  }
}

export class ParseError extends Error {
  readonly offset: number;
  constructor(message: string, offset: number) {
    super(`Parse error at offset ${offset}: ${message}`);
    this.name = "ParseError";
    this.offset = offset;
  }
}

export class DomainError extends Error {
  constructor(message: string) {
    super(`Out-of-domain request value: ${message}`);
    this.name = "DomainError";
  }
}

export class InvariantViolation extends Error {
  constructor(message: string) {
    super(`Unreachable verifier state: ${message}`);
    this.name = "InvariantViolation";
  }
}
