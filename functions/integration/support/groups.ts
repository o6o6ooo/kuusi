import {adminFirestore} from "./firebase";

export type GroupFixture = {
  id: string;
  members: string[];
  name: string;
  ownerUID: string;
};

export async function createGroupFixture(
  ownerUID: string,
  members: string[] = [ownerUID],
  id = "group-1"
): Promise<GroupFixture> {
  const fixture = {
    id,
    members,
    name: "Family",
    ownerUID
  };
  const firestore = adminFirestore();

  await firestore.collection("groups").doc(id).set({
    id,
    name: fixture.name,
    owner_uid: ownerUID,
    members,
    created_at: new Date("2026-01-01T00:00:00Z")
  });

  await Promise.all(members.map((uid) =>
    firestore.collection("users").doc(uid).set({
      name: `User ${uid}`,
      groups: [id],
      favourites: [],
      usage_mb: 0
    }, {merge: true})
  ));

  return fixture;
}
