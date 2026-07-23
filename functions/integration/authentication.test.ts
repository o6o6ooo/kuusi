import {strict as assert} from "node:assert";
import {afterEach, beforeEach, describe, it} from "node:test";
import {
  assertFirebaseError,
  callFunction,
  createEmulatorClient,
  disposeEmulatorClients,
  resetFirebaseEmulators
} from "./support/firebase";

describe("Firebase Authentication and callable boundary", () => {
  beforeEach(async () => {
    await resetFirebaseEmulators();
  });

  afterEach(async () => {
    await disposeEmulatorClients();
  });

  it("signs a user in anonymously through the Auth emulator", async () => {
    const client = await createEmulatorClient();

    assert.ok(client.uid);
    assert.equal(client.auth.currentUser?.uid, client.uid);
    assert.equal(client.auth.currentUser?.isAnonymous, true);
  });

  it("rejects unauthenticated callable requests", async () => {
    const client = await createEmulatorClient(false);

    await assertFirebaseError(
      () => callFunction(client, "createGroupInvite", {groupId: "group-1"}),
      "functions/unauthenticated"
    );
  });
});
