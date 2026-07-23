import {strict as assert} from "node:assert";
import {describe, it} from "node:test";
import {
  normalizeCaption,
  normalizeHashtags,
  normalizeText,
  normalizeUploadBatchId,
  normalizeUploadPhoto
} from "../src/functionLogic";
import {
  uploadBatchID,
  uploadUID,
  validUploadPhoto
} from "./support/photoFixtures";

describe("Functions input validation", () => {
  it("trims non-empty text and rejects other values", () => {
    assert.equal(normalizeText("  Kuusi  "), "Kuusi");
    assert.equal(normalizeText("   "), null);
    assert.equal(normalizeText(42), null);
  });

  it("accepts only safe upload batch identifiers", () => {
    assert.equal(normalizeUploadBatchId(" batch_abc-123 "), "batch_abc-123");
    assert.equal(normalizeUploadBatchId("batch/abc"), null);
    assert.equal(normalizeUploadBatchId("x".repeat(129)), null);
  });

  it("normalizes, deduplicates, and limits hashtags", () => {
    const values = [
      "#family",
      " family ",
      "#winter",
      "",
      42,
      ...Array.from({length: 35}, (_, index) => `tag${index}`)
    ];
    const result = normalizeHashtags(values);

    assert.deepEqual(result.slice(0, 2), ["family", "winter"]);
    assert.equal(result.length, 30);
  });

  it("normalizes caption whitespace and limits Unicode characters", () => {
    assert.equal(normalizeCaption("  A   snowy\n day  "), "A snowy day");
    assert.equal(normalizeCaption("   "), null);
    assert.equal(
      Array.from(normalizeCaption("🌲".repeat(150)) ?? "").length,
      140
    );
  });

  it("accepts upload files owned by the caller and batch", () => {
    assert.deepEqual(
      normalizeUploadPhoto(validUploadPhoto(), uploadUID, uploadBatchID),
      validUploadPhoto()
    );
  });

  it("rejects upload files outside the caller batch", () => {
    assert.throws(
      () => normalizeUploadPhoto(
        validUploadPhoto({
          previewPath: "photos/other/upload_batch_photo_preview.jpg"
        }),
        uploadUID,
        uploadBatchID
      ),
      (error: unknown) => {
        assert.equal(
          (error as {code?: string}).code,
          "permission-denied"
        );
        return true;
      }
    );
  });

  it("rejects invalid photo aspect ratios", () => {
    for (const aspectRatio of [0.19, 10.01, Number.NaN]) {
      assert.throws(
        () => normalizeUploadPhoto(
          validUploadPhoto({aspectRatio}),
          uploadUID,
          uploadBatchID
        ),
        (error: unknown) => {
          assert.equal(
            (error as {code?: string}).code,
            "invalid-argument"
          );
          return true;
        }
      );
    }
  });
});
