import {strict as assert} from "node:assert";
import {afterEach, beforeEach, describe, it} from "node:test";
import {getBytes, ref, uploadString} from "firebase/storage";
import {
  adminStorage,
  assertPermissionDenied,
  createEmulatorClient,
  disposeEmulatorClients,
  resetFirebaseEmulators
} from "./support/firebase";

describe("Storage Security Rules", () => {
  beforeEach(async () => {
    await resetFirebaseEmulators();
  });

  afterEach(async () => {
    await disposeEmulatorClients();
  });

  it("allows users to upload only below their own photo path", async () => {
    const client = await createEmulatorClient();
    assert.ok(client.uid);

    const ownFile = ref(client.storage, `photos/${client.uid}/preview.jpg`);
    await uploadString(ownFile, "preview");

    const [exists] = await adminStorage()
      .bucket()
      .file(`photos/${client.uid}/preview.jpg`)
      .exists();
    assert.equal(exists, true);

    await assertPermissionDenied(() =>
      uploadString(ref(client.storage, "photos/other/preview.jpg"), "forged")
    );
  });

  it("allows signed-in reads and denies unauthenticated reads", async () => {
    const signedIn = await createEmulatorClient();
    const signedOut = await createEmulatorClient(false);
    assert.ok(signedIn.uid);
    const path = `photos/${signedIn.uid}/preview.jpg`;
    await adminStorage().bucket().file(path).save(Buffer.from("preview"));

    assert.equal(
      Buffer.from(await getBytes(ref(signedIn.storage, path))).toString(),
      "preview"
    );
    await assertPermissionDenied(() => getBytes(ref(signedOut.storage, path)));
  });
});
