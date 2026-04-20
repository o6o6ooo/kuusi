import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, QueryDocumentSnapshot, Timestamp, WriteBatch } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getStorage } from "firebase-admin/storage";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { randomUUID } from "crypto";

initializeApp();

const db = getFirestore();
const storage = getStorage();
const maxBatchWriteCount = 450;
const maxGroupMembers = 50;
const maxMessagingBatchSize = 500;
const notificationFunctionRegion = "europe-west2";
const inviteLifetimeHours = 24;
const inviteLifetimeMs = inviteLifetimeHours * 60 * 60 * 1000;
const invalidMessagingTokenCodes = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered"
]);

type GroupData = {
  name?: string;
  owner_uid?: string;
  members?: string[];
};

type GroupInviteData = {
  created_at?: Timestamp;
  created_by?: string;
  expires_at?: Timestamp;
  group_id?: string;
};

type PhotoData = {
  group_id?: string;
  photo_url?: string;
  thumbnail_url?: string;
  posted_by?: string;
  size_mb?: number;
};

type DeviceData = {
  fcm_token?: string;
  notifications_enabled?: boolean;
};

type DeviceTarget = {
  ref: FirebaseFirestore.DocumentReference;
  token: string;
};

type PushPayload = {
  title: string;
  body: string;
  data?: Record<string, string>;
};

type AdminNotificationData = {
  title?: string;
  body?: string;
  target?: string;
  target_group_ids?: string[];
  deep_link?: string;
  status?: string;
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

  const userRef = db.collection("users").doc(uid);
  const deviceSnapshot = await userRef.collection("devices").get();

  await commitOperations([
    ...deviceSnapshot.docs.map((deviceDoc) => (batch: WriteBatch) => batch.delete(deviceDoc.ref)),
    (batch: WriteBatch) => batch.delete(userRef)
  ]);

  return {
    deletedUserId: uid,
    deletedGroupCount,
    deletedJoinedGroupCount: joinedGroups.length,
    deletedPhotoCount
  };
});

export const createGroupInvite = onCall(async (request) => {
  const uid = request.auth?.uid;
  const groupId = normalizeGroupId(request.data?.groupId);

  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required");
  }

  if (!groupId) {
    throw new HttpsError("invalid-argument", "groupId is required");
  }

  const groupSnapshot = await db.collection("groups").doc(groupId).get();
  if (!groupSnapshot.exists) {
    throw new HttpsError("not-found", "Group not found");
  }

  const groupData = groupSnapshot.data() as GroupData;
  const members = Array.isArray(groupData.members) ? groupData.members : [];
  if (!members.includes(uid)) {
    throw new HttpsError("permission-denied", "Only group members can create invite QR codes");
  }

  const inviteToken = randomUUID().replace(/-/g, "").toLowerCase();
  const expiresAt = Timestamp.fromMillis(Date.now() + inviteLifetimeMs);

  await db.collection("group_invites").doc(inviteToken).set({
    created_at: FieldValue.serverTimestamp(),
    created_by: uid,
    expires_at: expiresAt,
    group_id: groupId
  });

  return {
    expiresAt: expiresAt.toDate().toISOString(),
    inviteLifetimeHours,
    inviteToken
  };
});

export const joinGroupInvite = onCall(async (request) => {
  const uid = request.auth?.uid;
  const inviteToken = normalizeGroupId(request.data?.inviteToken);

  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required");
  }

  if (!inviteToken) {
    throw new HttpsError("invalid-argument", "inviteToken is required");
  }

  const inviteRef = db.collection("group_invites").doc(inviteToken);
  const inviteSnapshot = await inviteRef.get();
  if (!inviteSnapshot.exists) {
    throw new HttpsError("invalid-argument", "Invite not found");
  }

  const inviteData = inviteSnapshot.data() as GroupInviteData;
  const groupId = normalizeGroupId(inviteData.group_id);
  const expiresAt = inviteData.expires_at;

  if (!groupId || !expiresAt || typeof expiresAt.toMillis !== "function") {
    throw new HttpsError("invalid-argument", "Invite is invalid");
  }

  if (expiresAt.toMillis() <= Date.now()) {
    await inviteRef.delete();
    throw new HttpsError("failed-precondition", "Invite has expired");
  }

  const groupRef = db.collection("groups").doc(groupId);
  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (transaction) => {
    const groupSnapshot = await transaction.get(groupRef);
    if (!groupSnapshot.exists) {
      throw new HttpsError("not-found", "Group not found");
    }

    const groupData = groupSnapshot.data() as GroupData;
    const members = Array.isArray(groupData.members) ? groupData.members : [];

    if (!members.includes(uid) && members.length >= maxGroupMembers) {
      throw new HttpsError("resource-exhausted", "Group member limit reached");
    }

    transaction.set(userRef, {
      groups: FieldValue.arrayUnion(groupId)
    }, { merge: true });
    transaction.update(groupRef, {
      members: FieldValue.arrayUnion(uid)
    });
  });

  return {
    groupId,
    joined: true
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

export const removeGroupMember = onCall(async (request) => {
  const uid = request.auth?.uid;
  const groupId = normalizeGroupId(request.data?.groupId);
  const memberUid = normalizeGroupId(request.data?.memberUid);

  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required");
  }

  if (!groupId || !memberUid) {
    throw new HttpsError("invalid-argument", "groupId and memberUid are required");
  }

  const groupRef = db.collection("groups").doc(groupId);
  const memberRef = db.collection("users").doc(memberUid);

  await db.runTransaction(async (transaction) => {
    const groupSnapshot = await transaction.get(groupRef);
    if (!groupSnapshot.exists) {
      throw new HttpsError("not-found", "Group not found");
    }

    const groupData = groupSnapshot.data() as GroupData;
    const ownerUid = groupData.owner_uid;

    if (ownerUid !== uid) {
      throw new HttpsError("permission-denied", "Only the owner can remove members");
    }

    if (ownerUid === memberUid) {
      throw new HttpsError("failed-precondition", "The owner cannot be removed");
    }

    transaction.update(groupRef, {
      members: FieldValue.arrayRemove(memberUid)
    });
    transaction.set(memberRef, {
      groups: FieldValue.arrayRemove(groupId)
    }, { merge: true });
  });

  return {
    groupId,
    memberUid,
    removed: true
  };
});

export const onPhotoCreated = onDocumentCreated({
  document: "photos/{photoId}",
  region: notificationFunctionRegion
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    return;
  }

  const photoId = normalizeText(event.params.photoId);
  const photoData = snapshot.data() as PhotoData;
  const groupId = normalizeText(photoData.group_id);
  const postedBy = normalizeText(photoData.posted_by);

  if (!photoId || !groupId || !postedBy) {
    return;
  }

  const groupSnapshot = await db.collection("groups").doc(groupId).get();
  if (!groupSnapshot.exists) {
    return;
  }

  const groupData = groupSnapshot.data() as GroupData;
  const recipientUIDs = (Array.isArray(groupData.members) ? groupData.members : [])
    .map((memberUID) => normalizeText(memberUID))
    .filter((memberUID): memberUID is string => memberUID !== null && memberUID !== postedBy);

  if (recipientUIDs.length === 0) {
    return;
  }

  const senderName = await loadUserDisplayName(postedBy);
  const delivery = await sendPushToUserIDs(recipientUIDs, {
    title: groupData.name ? `New photo in ${groupData.name}` : "New photo in Kuusi",
    body: `${senderName} posted a new photo`,
    data: {
      type: "photo_posted",
      group_id: groupId,
      photo_id: photoId,
      posted_by: postedBy
    }
  });

  console.info("Photo notification delivered", {
    groupId,
    photoId,
    recipientCount: recipientUIDs.length,
    sentCount: delivery.sentCount,
    failedCount: delivery.failedCount
  });
});

export const onAdminNotificationCreated = onDocumentCreated({
  document: "admin_notifications/{notificationId}",
  region: notificationFunctionRegion
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    return;
  }

  const notificationId = normalizeText(event.params.notificationId);
  if (!notificationId) {
    return;
  }

  const notificationRef = snapshot.ref;
  const notificationData = snapshot.data() as AdminNotificationData;

  if (notificationData.status === "draft") {
    return;
  }

  const title = normalizeText(notificationData.title);
  const body = normalizeText(notificationData.body);
  if (!title || !body) {
    await notificationRef.set({
      status: "failed",
      failure_reason: "title_and_body_required",
      updated_at: FieldValue.serverTimestamp()
    }, { merge: true });
    return;
  }

  const target = normalizeText(notificationData.target) ?? "all";
  let delivery: { sentCount: number; failedCount: number; tokenCount: number };

  if (target === "group") {
    const groupIDs = normalizeStringArray(notificationData.target_group_ids);
    if (groupIDs.length === 0) {
      await notificationRef.set({
        status: "failed",
        failure_reason: "target_group_ids_required",
        updated_at: FieldValue.serverTimestamp()
      }, { merge: true });
      return;
    }

    const memberUIDs = await loadMemberUIDsForGroups(groupIDs);
    delivery = await sendPushToUserIDs(memberUIDs, {
      title,
      body,
      data: {
        type: "admin_announcement",
        notification_id: notificationId,
        deep_link: normalizeText(notificationData.deep_link) ?? "feed"
      }
    });
  } else {
    delivery = await sendPushToAllDevices({
      title,
      body,
      data: {
        type: "admin_announcement",
        notification_id: notificationId,
        deep_link: normalizeText(notificationData.deep_link) ?? "feed"
      }
    });
  }

  await notificationRef.set({
    status: "sent",
    sent_at: FieldValue.serverTimestamp(),
    delivery: {
      sent_count: delivery.sentCount,
      failed_count: delivery.failedCount,
      token_count: delivery.tokenCount
    },
    updated_at: FieldValue.serverTimestamp()
  }, { merge: true });
});

function normalizeGroupId(value: unknown): string | null {
  return normalizeText(value);
}

function normalizeText(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

function normalizeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => normalizeText(item))
    .filter((item): item is string => item !== null);
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

async function loadUserDisplayName(uid: string): Promise<string> {
  const userSnapshot = await db.collection("users").doc(uid).get();
  if (!userSnapshot.exists) {
    return "Someone";
  }

  const name = normalizeText(userSnapshot.data()?.name);
  return name ?? "Someone";
}

async function loadMemberUIDsForGroups(groupIDs: string[]): Promise<string[]> {
  const memberUIDs = new Set<string>();

  for (const groupID of groupIDs) {
    const groupSnapshot = await db.collection("groups").doc(groupID).get();
    if (!groupSnapshot.exists) {
      continue;
    }

    const groupData = groupSnapshot.data() as GroupData;
    for (const memberUID of normalizeStringArray(groupData.members)) {
      memberUIDs.add(memberUID);
    }
  }

  return Array.from(memberUIDs);
}

async function sendPushToAllDevices(payload: PushPayload): Promise<{ sentCount: number; failedCount: number; tokenCount: number }> {
  const snapshot = await db.collectionGroup("devices")
    .where("notifications_enabled", "==", true)
    .get();

  const targets = snapshot.docs.flatMap((document) => deviceTargetsFromData(document.ref, document.data() as DeviceData));
  return sendPushToDeviceTargets(targets, payload);
}

async function sendPushToUserIDs(
  userIDs: string[],
  payload: PushPayload
): Promise<{ sentCount: number; failedCount: number; tokenCount: number }> {
  if (userIDs.length === 0) {
    return { sentCount: 0, failedCount: 0, tokenCount: 0 };
  }

  const uniqueUIDs = Array.from(new Set(userIDs));
  const targets: DeviceTarget[] = [];

  for (const uid of uniqueUIDs) {
    const snapshot = await db.collection("users")
      .doc(uid)
      .collection("devices")
      .where("notifications_enabled", "==", true)
      .get();

    targets.push(...snapshot.docs.flatMap((document) => deviceTargetsFromData(document.ref, document.data() as DeviceData)));
  }

  return sendPushToDeviceTargets(targets, payload);
}

function deviceTargetsFromData(ref: FirebaseFirestore.DocumentReference, data: DeviceData): DeviceTarget[] {
  const token = normalizeText(data.fcm_token);
  if (!data.notifications_enabled || !token) {
    return [];
  }

  return [{ ref, token }];
}

async function sendPushToDeviceTargets(
  targets: DeviceTarget[],
  payload: PushPayload
): Promise<{ sentCount: number; failedCount: number; tokenCount: number }> {
  const dedupedTargets = Array.from(new Map(targets.map((target) => [target.token, target])).values());
  if (dedupedTargets.length === 0) {
    return { sentCount: 0, failedCount: 0, tokenCount: 0 };
  }

  let sentCount = 0;
  let failedCount = 0;

  for (const chunk of chunked(dedupedTargets, maxMessagingBatchSize)) {
    const response = await getMessaging().sendEachForMulticast({
      tokens: chunk.map((target) => target.token),
      notification: {
        title: payload.title,
        body: payload.body
      },
      data: payload.data,
      apns: {
        payload: {
          aps: {
            sound: "default"
          }
        }
      }
    });

    const staleRefs: FirebaseFirestore.DocumentReference[] = [];
    response.responses.forEach((sendResponse, index) => {
      if (sendResponse.success) {
        sentCount += 1;
        return;
      }

      failedCount += 1;
      if (sendResponse.error && invalidMessagingTokenCodes.has(sendResponse.error.code)) {
        staleRefs.push(chunk[index].ref);
      }
    });

    if (staleRefs.length > 0) {
      await commitOperations(staleRefs.map((ref) => (batch: WriteBatch) => batch.delete(ref)));
    }
  }

  return {
    sentCount,
    failedCount,
    tokenCount: dedupedTargets.length
  };
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
