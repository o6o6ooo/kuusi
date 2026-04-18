import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, QueryDocumentSnapshot, WriteBatch } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { HttpsError, onCall } from "firebase-functions/v2/https";

initializeApp();

const db = getFirestore();
const storage = getStorage();
const maxBatchWriteCount = 450;

type GroupData = {
  owner_uid?: string;
  members?: string[];
};

type PhotoData = {
  photo_url?: string;
  thumbnail_url?: string;
  posted_by?: string;
  size_mb?: number;
};

export const deleteGroup = onCall(async (request) => {
  const uid = request.auth?.uid;
  const groupId = normalizeGroupId(request.data?.groupId);

  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required");
  }

  if (!groupId) {
    throw new HttpsError("invalid-argument", "groupId is required");
  }

  const deletedPhotoCount = await deleteOwnedGroup(groupId, uid);

  return {
    deletedGroupId: groupId,
    deletedPhotoCount
  };
});

export const deleteCurrentUserData = onCall(async (request) => {
  const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required");
  }

  const groupsSnapshot = await db.collection("groups")
    .where("members", "array-contains", uid)
    .get();

  const ownedGroups = groupsSnapshot.docs.filter((doc) => (doc.data() as GroupData).owner_uid === uid);
  const joinedGroups = groupsSnapshot.docs.filter((doc) => (doc.data() as GroupData).owner_uid !== uid);

  let deletedGroupCount = 0;
  let deletedPhotoCount = 0;

  for (const groupDoc of ownedGroups) {
    deletedPhotoCount += await deleteOwnedGroup(groupDoc.id, uid, groupDoc);
    deletedGroupCount += 1;
  }

  if (joinedGroups.length > 0) {
    await commitOperations(
      joinedGroups.map((groupDoc) => (batch: WriteBatch) =>
        batch.update(groupDoc.ref, {
          members: FieldValue.arrayRemove(uid)
        })
      )
    );
  }

  const userPhotosSnapshot = await db.collection("photos")
    .where("posted_by", "==", uid)
    .get();
  deletedPhotoCount += await deletePhotosAndCleanup(userPhotosSnapshot.docs);

  await db.collection("users").doc(uid).delete();

  return {
    deletedUserId: uid,
    deletedGroupCount,
    deletedJoinedGroupCount: joinedGroups.length,
    deletedPhotoCount
  };
});

export const deletePhoto = onCall(async (request) => {
  const uid = request.auth?.uid;
  const photoId = normalizeGroupId(request.data?.photoId);

  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required");
  }

  if (!photoId) {
    throw new HttpsError("invalid-argument", "photoId is required");
  }

  const photoSnapshot = await db.collection("photos").doc(photoId).get();
  if (!photoSnapshot.exists) {
    throw new HttpsError("not-found", "Photo not found");
  }

  const photoData = photoSnapshot.data() as PhotoData;
  if (photoData.posted_by !== uid) {
    throw new HttpsError("permission-denied", "Only the uploader can delete this photo");
  }

  const deletedPhotoCount = await deletePhotosAndCleanup([photoSnapshot as QueryDocumentSnapshot]);

  return {
    deletedPhotoId: photoId,
    deletedPhotoCount
  };
});

function normalizeGroupId(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

async function deleteOwnedGroup(
  groupId: string,
  requesterUID: string,
  existingSnapshot?: QueryDocumentSnapshot
): Promise<number> {
  const groupRef = db.collection("groups").doc(groupId);
  const groupSnapshot = existingSnapshot ?? await groupRef.get();

  if (!groupSnapshot.exists) {
    throw new HttpsError("not-found", "Group not found");
  }

  const groupData = groupSnapshot.data() as GroupData;
  if (groupData.owner_uid !== requesterUID) {
    throw new HttpsError("permission-denied", "Only the owner can delete this group");
  }

  const memberIDs = Array.isArray(groupData.members) ? groupData.members : [];
  const photosSnapshot = await db.collection("photos")
    .where("group_id", "==", groupId)
    .get();

  const deletedPhotoCount = await deletePhotosAndCleanup(photosSnapshot.docs);

  await commitOperations([
    ...memberIDs.map((memberID) => (batch: WriteBatch) =>
      batch.set(
        db.collection("users").doc(memberID),
        { groups: FieldValue.arrayRemove(groupId) },
        { merge: true }
      )
    ),
    (batch: WriteBatch) => batch.delete(groupRef)
  ]);

  return deletedPhotoCount;
}

async function deletePhotosAndCleanup(
  photoDocs: QueryDocumentSnapshot[]
): Promise<number> {
  if (photoDocs.length === 0) {
    return 0;
  }

  const photoIDs = photoDocs.map((doc) => doc.id);
  const photos = photoDocs.map((doc) => ({
    id: doc.id,
    ...(doc.data() as PhotoData)
  }));

  await deleteStorageAssets(photos);

  const usageByUserID = buildUsageMap(photos);
  const favouriteRemovals = await loadFavouriteRemovals(photoIDs);

  await commitOperations([
    ...photoDocs.map((photoDoc) => (batch: WriteBatch) => batch.delete(photoDoc.ref)),
    ...Object.entries(usageByUserID).map(([userID, sizeMB]) => (batch: WriteBatch) =>
      batch.set(
        db.collection("users").doc(userID),
        { usage_mb: FieldValue.increment(-sizeMB) },
        { merge: true }
      )
    ),
    ...Object.entries(favouriteRemovals).map(([userID, ids]) => (batch: WriteBatch) =>
      batch.set(
        db.collection("users").doc(userID),
        { favourites: FieldValue.arrayRemove(...ids) },
        { merge: true }
      )
    )
  ]);

  return photoDocs.length;
}

function buildUsageMap(photos: Array<{ posted_by?: string; size_mb?: number }>): Record<string, number> {
  const usageByUserID: Record<string, number> = {};

  for (const photo of photos) {
    if (!photo.posted_by || typeof photo.size_mb !== "number" || photo.size_mb <= 0) {
      continue;
    }
    usageByUserID[photo.posted_by] = (usageByUserID[photo.posted_by] ?? 0) + photo.size_mb;
  }

  return usageByUserID;
}

async function loadFavouriteRemovals(photoIDs: string[]): Promise<Record<string, string[]>> {
  if (photoIDs.length === 0) {
    return {};
  }

  const favouriteRemovals: Record<string, Set<string>> = {};

  for (const chunk of chunked(photoIDs, 10)) {
    const snapshot = await db.collection("users")
      .where("favourites", "array-contains-any", chunk)
      .get();

    for (const document of snapshot.docs) {
      favouriteRemovals[document.id] ??= new Set<string>();
      for (const photoID of chunk) {
        favouriteRemovals[document.id].add(photoID);
      }
    }
  }

  return Object.fromEntries(
    Object.entries(favouriteRemovals).map(([userID, ids]) => [userID, Array.from(ids)])
  );
}

async function deleteStorageAssets(
  photos: Array<{ photo_url?: string; thumbnail_url?: string }>
): Promise<void> {
  const bucket = storage.bucket();

  for (const photo of photos) {
    for (const urlString of [photo.photo_url, photo.thumbnail_url]) {
      const path = parseStoragePath(urlString);
      if (!path) {
        continue;
      }

      try {
        await bucket.file(path).delete();
      } catch (error) {
        if (isObjectNotFoundError(error)) {
          continue;
        }
        throw error;
      }
    }
  }
}

function parseStoragePath(urlString: string | undefined): string | null {
  if (!urlString) {
    return null;
  }

  if (urlString.startsWith("gs://")) {
    const withoutScheme = urlString.slice("gs://".length);
    const slashIndex = withoutScheme.indexOf("/");
    return slashIndex >= 0 ? withoutScheme.slice(slashIndex + 1) : null;
  }

  try {
    const url = new URL(urlString);
    const marker = "/o/";
    const markerIndex = url.pathname.indexOf(marker);
    if (markerIndex < 0) {
      return null;
    }
    return decodeURIComponent(url.pathname.slice(markerIndex + marker.length));
  } catch {
    return null;
  }
}

function isObjectNotFoundError(error: unknown): boolean {
  if (!(error instanceof Error)) {
    return false;
  }

  const maybeCode = error as Error & { code?: number | string };
  return maybeCode.code === 404 || maybeCode.code === "storage/object-not-found";
}

async function commitOperations(
  operations: Array<(batch: WriteBatch) => void>
): Promise<void> {
  for (const chunk of chunked(operations, maxBatchWriteCount)) {
    const batch = db.batch();
    for (const operation of chunk) {
      operation(batch);
    }
    await batch.commit();
  }
}

function chunked<T>(items: T[], size: number): T[][] {
  if (size <= 0) {
    return [items];
  }

  const chunks: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }
  return chunks;
}
