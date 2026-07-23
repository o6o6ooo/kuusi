import {strict as assert} from "node:assert";
import {afterEach, beforeEach, describe, it} from "node:test";
import {
  adminFirestore,
  callFunction,
  createEmulatorClient,
  disposeEmulatorClients,
  resetFirebaseEmulators
} from "./support/firebase";
import {createGroupFixture} from "./support/groups";
import {createPhotoFixture} from "./support/photos";

describe("User data deletion", () => {
  beforeEach(async () => {
    await resetFirebaseEmulators();
  });

  afterEach(async () => {
    await disposeEmulatorClients();
  });

  it("removes the user while preserving a transferred shared group", async () => {
    const owner = await createEmulatorClient();
    const member = await createEmulatorClient();
    assert.ok(owner.uid);
    assert.ok(member.uid);
    await createGroupFixture(owner.uid, [owner.uid, member.uid]);
    await createPhotoFixture("group-1", owner.uid);
    const firestore = adminFirestore();
    await firestore.collection("users").doc(owner.uid)
      .collection("devices").doc("device-1").set({
        fcm_token: "token",
        notifications_enabled: true
      });

    const result = await callFunction<{
      deletedGroupCount: number;
      deletedPhotoCount: number;
      transferredGroupCount: number;
    }>(owner, "deleteCurrentUserData", {});

    assert.equal(result.deletedGroupCount, 0);
    assert.equal(result.transferredGroupCount, 1);
    assert.equal(result.deletedPhotoCount, 1);
    assert.equal(
      (await firestore.collection("users").doc(owner.uid).get()).exists,
      false
    );
    const group = await firestore.collection("groups").doc("group-1").get();
    assert.equal(group.data()?.owner_uid, member.uid);
    assert.deepEqual(group.data()?.members, [member.uid]);
  });
});
