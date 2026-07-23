import {strict as assert} from "node:assert";
import {afterEach, beforeEach, describe, it} from "node:test";
import {
  adminFirestore,
  adminStorage,
  assertFirebaseError,
  callFunction,
  createEmulatorClient,
  disposeEmulatorClients,
  resetFirebaseEmulators,
  waitForDocument
} from "./support/firebase";
import {createGroupFixture} from "./support/groups";

type CommitResult = {
  photos: Array<{
    id: string;
    preview_storage_path: string;
    thumbnail_storage_path: string;
  }>;
  totalUploadMB: number;
};

describe("Photo upload commit", () => {
  beforeEach(async () => {
    await resetFirebaseEmulators();
  });

  afterEach(async () => {
    await disposeEmulatorClients();
  });

  it("moves temporary files and commits photo metadata and usage", async () => {
    const uploader = await createEmulatorClient();
    assert.ok(uploader.uid);
    await createGroupFixture(uploader.uid);
    const batchID = "batch-1";
    const prefix = `photos/${uploader.uid}/upload_${batchID}_photo-1`;
    const previewPath = `${prefix}_preview.jpg`;
    const thumbnailPath = `${prefix}_thumb.jpg`;
    const bucket = adminStorage().bucket();
    await Promise.all([
      bucket.file(previewPath).save(Buffer.alloc(128 * 1024, 1)),
      bucket.file(thumbnailPath).save(Buffer.alloc(32 * 1024, 1))
    ]);

    const result = await callFunction<CommitResult>(
      uploader,
      "commitPhotoUploadBatch",
      {
        groupId: "group-1",
        uploadBatchId: batchID,
        hashtags: ["#winter", "family"],
        caption: "  A   snowy day ",
        photos: [{
          id: "photo-1",
          previewPath,
          thumbnailPath,
          aspectRatio: 1.5
        }]
      }
    );

    assert.equal(result.photos.length, 1);
    assert.equal(result.totalUploadMB, 0.16);
    const committed = result.photos[0];
    const storedPhoto = await adminFirestore()
      .collection("photos")
      .doc(committed.id)
      .get();
    assert.equal(storedPhoto.data()?.caption, "A snowy day");
    assert.deepEqual(storedPhoto.data()?.hashtags, ["winter", "family"]);
    assert.equal(
      (await adminFirestore()
        .collection("users")
        .doc(uploader.uid)
        .get()).data()?.usage_mb,
      0.16
    );

    assert.equal((await bucket.file(previewPath).exists())[0], false);
    assert.equal((await bucket.file(thumbnailPath).exists())[0], false);
    assert.equal(
      (await bucket.file(committed.preview_storage_path).exists())[0],
      true
    );
    assert.equal(
      (await bucket.file(committed.thumbnail_storage_path).exists())[0],
      true
    );
    await waitForDocument("photo_notification_batches", batchID);
  });

  it("rejects uploads from users outside the group", async () => {
    const owner = await createEmulatorClient();
    const outsider = await createEmulatorClient();
    assert.ok(owner.uid);
    assert.ok(outsider.uid);
    await createGroupFixture(owner.uid);

    await assertFirebaseError(
      () => callFunction(outsider, "commitPhotoUploadBatch", {
        groupId: "group-1",
        uploadBatchId: "batch-1",
        photos: [{
          id: "photo-1",
          previewPath:
            `photos/${outsider.uid}/upload_batch-1_photo-1_preview.jpg`,
          thumbnailPath:
            `photos/${outsider.uid}/upload_batch-1_photo-1_thumb.jpg`,
          aspectRatio: 1.5
        }]
      }),
      "functions/permission-denied"
    );
  });
});
