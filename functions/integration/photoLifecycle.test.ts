import {strict as assert} from "node:assert";
import {afterEach, beforeEach, describe, it} from "node:test";
import {
  adminFirestore,
  adminStorage,
  assertFirebaseError,
  callFunction,
  createEmulatorClient,
  disposeEmulatorClients,
  resetFirebaseEmulators
} from "./support/firebase";
import {createGroupFixture} from "./support/groups";
import {createPhotoFixture} from "./support/photos";

describe("Photo deletion lifecycle", () => {
  beforeEach(async () => {
    await resetFirebaseEmulators();
  });

  afterEach(async () => {
    await disposeEmulatorClients();
  });

  it("deletes Firestore and Storage data and repairs user metadata", async () => {
    const uploader = await createEmulatorClient();
    const member = await createEmulatorClient();
    assert.ok(uploader.uid);
    assert.ok(member.uid);
    await createGroupFixture(uploader.uid, [uploader.uid, member.uid]);
    const photo = await createPhotoFixture("group-1", uploader.uid);
    const firestore = adminFirestore();

    await firestore.collection("users").doc(uploader.uid).set({
      usage_mb: 10,
      favourites: [photo.id]
    }, {merge: true});
    await firestore.collection("users").doc(member.uid).set({
      favourites: [photo.id, "keep"]
    }, {merge: true});

    const result = await callFunction<{
      deletedPhotoCount: number;
      deletedPhotoId: string;
    }>(uploader, "deletePhoto", {photoId: photo.id});

    assert.deepEqual(result, {
      deletedPhotoCount: 1,
      deletedPhotoId: photo.id
    });
    assert.equal(
      (await firestore.collection("photos").doc(photo.id).get()).exists,
      false
    );
    assert.equal(
      (await firestore.collection("users").doc(uploader.uid).get())
        .data()?.usage_mb,
      7.5
    );
    assert.deepEqual(
      (await firestore.collection("users").doc(member.uid).get())
        .data()?.favourites,
      ["keep"]
    );

    const bucket = adminStorage().bucket();
    assert.equal((await bucket.file(photo.previewPath).exists())[0], false);
    assert.equal((await bucket.file(photo.thumbnailPath).exists())[0], false);
  });

  it("prevents another member from deleting the photo", async () => {
    const uploader = await createEmulatorClient();
    const member = await createEmulatorClient();
    assert.ok(uploader.uid);
    assert.ok(member.uid);
    await createGroupFixture(uploader.uid, [uploader.uid, member.uid]);
    const photo = await createPhotoFixture("group-1", uploader.uid);

    await assertFirebaseError(
      () => callFunction(member, "deletePhoto", {photoId: photo.id}),
      "functions/permission-denied"
    );
  });
});
