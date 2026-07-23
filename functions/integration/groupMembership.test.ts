import {strict as assert} from "node:assert";
import {afterEach, beforeEach, describe, it} from "node:test";
import {
  adminFirestore,
  assertFirebaseError,
  callFunction,
  createEmulatorClient,
  disposeEmulatorClients,
  resetFirebaseEmulators
} from "./support/firebase";
import {createGroupFixture} from "./support/groups";

type LeaveResult = {
  deletedGroup: boolean;
  deletedPhotoCount: number;
  groupId: string;
  leftUid: string;
  newOwnerUid?: string;
};

describe("Group membership lifecycle", () => {
  beforeEach(async () => {
    await resetFirebaseEmulators();
  });

  afterEach(async () => {
    await disposeEmulatorClients();
  });

  it("lets the owner remove another member from both records", async () => {
    const owner = await createEmulatorClient();
    const member = await createEmulatorClient();
    assert.ok(owner.uid);
    assert.ok(member.uid);
    await createGroupFixture(owner.uid, [owner.uid, member.uid]);

    await callFunction(owner, "removeGroupMember", {
      groupId: "group-1",
      memberUid: member.uid
    });

    const firestore = adminFirestore();
    assert.deepEqual(
      (await firestore.collection("groups").doc("group-1").get())
        .data()?.members,
      [owner.uid]
    );
    assert.deepEqual(
      (await firestore.collection("users").doc(member.uid).get())
        .data()?.groups,
      []
    );
  });

  it("prevents non-owners and owners removing themselves", async () => {
    const owner = await createEmulatorClient();
    const member = await createEmulatorClient();
    assert.ok(owner.uid);
    assert.ok(member.uid);
    await createGroupFixture(owner.uid, [owner.uid, member.uid]);

    await assertFirebaseError(
      () => callFunction(member, "removeGroupMember", {
        groupId: "group-1",
        memberUid: owner.uid
      }),
      "functions/permission-denied"
    );
    await assertFirebaseError(
      () => callFunction(owner, "removeGroupMember", {
        groupId: "group-1",
        memberUid: owner.uid
      }),
      "functions/failed-precondition"
    );
  });

  it("transfers ownership when the owner leaves", async () => {
    const owner = await createEmulatorClient();
    const member = await createEmulatorClient();
    assert.ok(owner.uid);
    assert.ok(member.uid);
    await createGroupFixture(owner.uid, [owner.uid, member.uid]);

    const result = await callFunction<LeaveResult>(owner, "leaveGroup", {
      groupId: "group-1"
    });

    assert.equal(result.deletedGroup, false);
    assert.equal(result.newOwnerUid, member.uid);
    const group = await adminFirestore()
      .collection("groups")
      .doc("group-1")
      .get();
    assert.equal(group.data()?.owner_uid, member.uid);
    assert.deepEqual(group.data()?.members, [member.uid]);
  });

  it("deletes a group when its final member leaves", async () => {
    const owner = await createEmulatorClient();
    assert.ok(owner.uid);
    await createGroupFixture(owner.uid);

    const result = await callFunction<LeaveResult>(owner, "leaveGroup", {
      groupId: "group-1"
    });

    assert.equal(result.deletedGroup, true);
    assert.equal(
      (await adminFirestore().collection("groups").doc("group-1").get())
        .exists,
      false
    );
  });
});
