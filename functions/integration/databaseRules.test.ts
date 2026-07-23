import {strict as assert} from "node:assert";
import {afterEach, beforeEach, describe, it} from "node:test";
import {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc
} from "firebase/firestore";
import {
  adminFirestore,
  assertPermissionDenied,
  createEmulatorClient,
  disposeEmulatorClients,
  resetFirebaseEmulators
} from "./support/firebase";
import {createGroupFixture} from "./support/groups";
import {createPhotoFixture} from "./support/photos";

describe("Firestore Security Rules", () => {
  beforeEach(async () => {
    await resetFirebaseEmulators();
  });

  afterEach(async () => {
    await disposeEmulatorClients();
  });

  it("allows a user to create a safe profile but not server fields", async () => {
    const client = await createEmulatorClient();
    assert.ok(client.uid);
    const userRef = doc(client.firestore, "users", client.uid);

    await setDoc(userRef, {
      name: "Sakura",
      groups: [],
      favourites: [],
      usage_mb: 0
    });

    assert.equal((await getDoc(userRef)).data()?.name, "Sakura");

    await assertPermissionDenied(() => updateDoc(userRef, {
      usage_mb: 100
    }));
    await assertPermissionDenied(() => updateDoc(userRef, {
      premium_product_id: "forged"
    }));
  });

  it("allows only group members to read photos", async () => {
    const member = await createEmulatorClient();
    const outsider = await createEmulatorClient();
    assert.ok(member.uid);
    assert.ok(outsider.uid);

    await createGroupFixture(member.uid);
    await createPhotoFixture("group-1", member.uid);
    const memberPhoto = doc(member.firestore, "photos", "photo-1");
    const outsiderPhoto = doc(outsider.firestore, "photos", "photo-1");

    assert.equal((await getDoc(memberPhoto)).data()?.posted_by, member.uid);
    await assertPermissionDenied(() => getDoc(outsiderPhoto));
  });

  it("allows permitted photo edits but denies direct create and delete", async () => {
    const member = await createEmulatorClient();
    assert.ok(member.uid);
    await createGroupFixture(member.uid);
    await createPhotoFixture("group-1", member.uid);

    const photoRef = doc(member.firestore, "photos", "photo-1");
    await updateDoc(photoRef, {caption: "A snowy day"});
    assert.equal((await getDoc(photoRef)).data()?.caption, "A snowy day");

    await assertPermissionDenied(() =>
      updateDoc(photoRef, {posted_by: "someone-else"})
    );
    await assertPermissionDenied(() => deleteDoc(photoRef));
    await assertPermissionDenied(() =>
      setDoc(doc(member.firestore, "photos", "forged"), {
        group_id: "group-1",
        posted_by: member.uid
      })
    );
  });

  it("allows members to rename a group but denies direct deletion", async () => {
    const member = await createEmulatorClient();
    assert.ok(member.uid);
    await createGroupFixture(member.uid);
    const groupRef = doc(member.firestore, "groups", "group-1");

    await updateDoc(groupRef, {name: "Winter"});
    assert.equal((await getDoc(groupRef)).data()?.name, "Winter");
    await assertPermissionDenied(() => deleteDoc(groupRef));

    assert.equal(
      (await adminFirestore().collection("groups").doc("group-1").get())
        .data()?.name,
      "Winter"
    );
  });
});
