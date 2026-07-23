import {strict as assert} from "node:assert";
import {describe, it} from "node:test";
import {
  buildUsageMap,
  chunked,
  emailLogId,
  isAlreadyExistsError,
  isObjectNotFoundError,
  normalizeBatchCount,
  normalizeEmail,
  numericValue,
  optionalNumber,
  roundMegabytes
} from "../src/functionLogic";

describe("Functions shared logic", () => {
  it("parses finite numeric values", () => {
    assert.equal(numericValue(12.5), 12.5);
    assert.equal(numericValue(" 12.5 "), 12.5);
    assert.equal(numericValue(""), null);
    assert.equal(numericValue(Number.POSITIVE_INFINITY), null);
  });

  it("accepts only positive integer optional values", () => {
    assert.equal(optionalNumber("42"), 42);
    assert.equal(optionalNumber(0), undefined);
    assert.equal(optionalNumber(1.5), undefined);
  });

  it("uses one as the fallback photo batch count", () => {
    assert.equal(normalizeBatchCount(3), 3);
    assert.equal(normalizeBatchCount(0), 1);
    assert.equal(normalizeBatchCount("3"), 1);
  });

  it("rounds storage usage to two decimal places", () => {
    assert.equal(roundMegabytes(1.234), 1.23);
    assert.equal(roundMegabytes(1.235), 1.24);
  });

  it("aggregates positive photo usage by uploader", () => {
    assert.deepEqual(
      buildUsageMap([
        {posted_by: "a", size_mb: 1.25},
        {posted_by: "a", size_mb: 0.75},
        {posted_by: "b", size_mb: 3},
        {posted_by: "b", size_mb: -1},
        {size_mb: 10}
      ]),
      {a: 2, b: 3}
    );
  });

  it("chunks batched writes without dropping entries", () => {
    assert.deepEqual(chunked([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]]);
    assert.deepEqual(chunked([1, 2], 0), [[1, 2]]);
  });

  it("normalizes email addresses", () => {
    assert.equal(normalizeEmail(" user@example.com "), "user@example.com");
    assert.equal(normalizeEmail("invalid"), null);
    assert.equal(normalizeEmail(undefined), null);
  });

  it("creates safe, bounded email log identifiers", () => {
    const id = emailLogId(
      "user/id",
      "premium expired",
      "2026-01-01".repeat(20)
    );

    assert.match(id, /^[A-Za-z0-9_-]+$/);
    assert.equal(id.length, 140);
  });

  it("recognises expected Firebase missing and duplicate errors", () => {
    const missing = Object.assign(new Error("missing"), {code: 404});
    const duplicate = Object.assign(
      new Error("duplicate"),
      {code: "already-exists"}
    );

    assert.equal(isObjectNotFoundError(missing), true);
    assert.equal(isAlreadyExistsError(duplicate), true);
    assert.equal(isObjectNotFoundError(new Error("other")), false);
    assert.equal(isAlreadyExistsError(new Error("other")), false);
  });
});
