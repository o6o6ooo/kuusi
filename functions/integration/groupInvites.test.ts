import {strict as assert} from "node:assert";
import {afterEach, beforeEach, describe, it} from "node:test";
import {Timestamp} from "firebase-admin/firestore";
import {
  adminFirestore,
  assertFirebaseError,
  callFunction,
  createEmulatorClient,
  disposeEmulatorClients,
  resetFirebaseEmulators
} from "./support/firebase";
import {createGroupFixture} from "./support/groups";

type InviteResult = {
  expiresAt: string;
  inviteLifetimeHours: number;
  inviteToken: string;
};

type JoinResult = {
  groupId: string;
  joined: boolean;
};

describe("Group invites", () => {
  beforeEach(async () => {
    await resetFirebaseEmulators();
  });

  afterEach(async () => {
    await disposeEmulatorClients();
  });

  it("creates an invite and lets another user join once", async () => {
    const owner = await createEmulatorClient();
    const guest = await createEmulatorClient();
    assert.ok(owner.uid);
    assert.ok(guest.uid);
    await createGroupFixture(owner.uid);

    const invite = await callFunction<InviteResult>(
      owner,
      "createGroupInvite",
      {groupId: "group-1"}
    );
    assert.equal(invite.inviteLifetimeHours, 24);
    assert.match(invite.inviteToken, /^[a-f0-9]{32}$/);

    const firstJoin = await callFunction<JoinResult>(
      guest,
      "joinGroupInvite",
      {inviteToken: invite.inviteToken}
    );
    const secondJoin = await callFunction<JoinResult>(
      guest,
      "joinGroupInvite",
      {inviteToken: invite.inviteToken}
    );

    assert.deepEqual(firstJoin, {groupId: "group-1", joined: true});
    assert.deepEqual(secondJoin, {groupId: "group-1", joined: false});

    const group = await adminFirestore()
      .collection("groups")
      .doc("group-1")
      .get();
    const user = await adminFirestore()
      .collection("users")
      .doc(guest.uid)
      .get();
    assert.deepEqual(group.data()?.members, [owner.uid, guest.uid]);
    assert.deepEqual(user.data()?.groups, ["group-1"]);
  });

  it("rejects invite creation by a non-member", async () => {
    const owner = await createEmulatorClient();
    const outsider = await createEmulatorClient();
    assert.ok(owner.uid);
    await createGroupFixture(owner.uid);

    await assertFirebaseError(
      () => callFunction(
        outsider,
        "createGroupInvite",
        {groupId: "group-1"}
      ),
      "functions/permission-denied"
    );
  });

  it("rejects and removes an expired invite", async () => {
    const owner = await createEmulatorClient();
    const guest = await createEmulatorClient();
    assert.ok(owner.uid);
    await createGroupFixture(owner.uid);
    await adminFirestore().collection("group_invites").doc("expired").set({
      created_by: owner.uid,
      group_id: "group-1",
      expires_at: Timestamp.fromMillis(Date.now() - 1)
    });

    await assertFirebaseError(
      () => callFunction(guest, "joinGroupInvite", {inviteToken: "expired"}),
      "functions/failed-precondition"
    );
    assert.equal(
      (await adminFirestore()
        .collection("group_invites")
        .doc("expired")
        .get()).exists,
      false
    );
  });

  it("enforces the fifteen-member group limit", async () => {
    const owner = await createEmulatorClient();
    const guest = await createEmulatorClient();
    assert.ok(owner.uid);
    const members = [
      owner.uid,
      ...Array.from({length: 14}, (_, index) => `member-${index}`)
    ];
    await createGroupFixture(owner.uid, members);
    await adminFirestore().collection("group_invites").doc("full-group").set({
      created_by: owner.uid,
      group_id: "group-1",
      expires_at: Timestamp.fromMillis(Date.now() + 60_000)
    });

    await assertFirebaseError(
      () => callFunction(
        guest,
        "joinGroupInvite",
        {inviteToken: "full-group"}
      ),
      "functions/resource-exhausted"
    );
  });
});
