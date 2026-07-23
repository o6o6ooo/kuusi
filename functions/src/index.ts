import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, DocumentSnapshot, FieldValue, QueryDocumentSnapshot, Timestamp, WriteBatch } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getStorage } from "firebase-admin/storage";
import { AutoRenewStatus, Environment, SignedDataVerifier, Type } from "@apple/app-store-server-library";
import type { JWSRenewalInfoDecodedPayload, JWSTransactionDecodedPayload } from "@apple/app-store-server-library";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { randomUUID } from "crypto";
import {
  EmailPayload,
  legalUpdatedEmail,
  premiumCancelledEmail,
  premiumExpiredEmail,
  premiumExpiringEmail,
  premiumPurchasedEmail
} from "./emailTemplates.js";
import {
  buildUsageMap,
  chunked,
  emailLogId,
  errorMessage,
  isAlreadyExistsError,
  isObjectNotFoundError,
  normalizeBatchCount,
  normalizeCaption,
  normalizeEmail,
  normalizeHashtags,
  normalizeText,
  normalizeUploadBatchId,
  normalizeUploadPhoto,
  numericValue,
  optionalNumber,
  roundMegabytes
} from "./functionLogic.js";

initializeApp();

const db = getFirestore();
const storage = getStorage();
const maxBatchWriteCount = 450;
const maxGroupMembers = 15;
const maxMessagingBatchSize = 500;
const maxUploadBatchPhotoCount = 10;
const callableFunctionRegion = "europe-west2";
const notificationFunctionRegion = "europe-west2";
const emailFunctionRegion = "europe-west2";
const inviteLifetimeHours = 24;
const inviteLifetimeMs = inviteLifetimeHours * 60 * 60 * 1000;
const freeQuotaMB = 1024;
const premiumQuotaMB = 30720;
const premiumProductId = "com.swallace.kuusi.premium.annual";
const premiumExpiryNoticeDays = 7;
const emailBatchLimit = 100;
const emailFrom = "Kuusi <hi@kuusi.app>";
const resendApiKey = defineSecret("RESEND_API_KEY");
const appStoreBundleId = process.env.APP_STORE_BUNDLE_ID ?? "com.swallace.kuusi";
const appStoreAppAppleId = optionalNumber(process.env.APP_STORE_APP_APPLE_ID);
const appleRootCAG3 = Buffer.from(
  "MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA==",
  "base64"
);
const appStoreVerifiers = [
  {
    environment: Environment.SANDBOX,
    verifier: new SignedDataVerifier([appleRootCAG3], false, Environment.SANDBOX, appStoreBundleId)
  },
  ...(appStoreAppAppleId ? [{
    environment: Environment.PRODUCTION,
    verifier: new SignedDataVerifier([appleRootCAG3], false, Environment.PRODUCTION, appStoreBundleId, appStoreAppAppleId)
  }] : [])
];
const invalidMessagingTokenCodes = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered"
]);

type StorageBucket = ReturnType<typeof storage.bucket>;

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
  aspect_ratio?: number;
  caption?: string;
  created_at?: Timestamp;
  date?: Timestamp;
  group_id?: string;
  hashtags?: string[];
  preview_storage_path?: string;
  thumbnail_storage_path?: string;
  posted_by?: string;
  size_mb?: number;
  upload_batch_id?: string;
  upload_batch_count?: number;
};

type UploadCommitItem = {
  aspectRatio: number;
  finalPreviewPath: string;
  finalThumbnailPath: string;
  id: string;
  previewPath: string;
  ref: FirebaseFirestore.DocumentReference;
  sizeMB: number;
  thumbnailPath: string;
};

type LeaveGroupResult = {
  deletedGroup: boolean;
  deletedPhotoCount: number;
  newOwnerUid?: string;
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

type LegalAnnouncementData = {
  title?: string;
  body?: string;
  effective_at?: Timestamp;
  privacy_url?: string;
  status?: string;
  terms_url?: string;
};

type EmailType =
  | "premium_purchased"
  | "premium_cancelled"
  | "premium_expiring"
  | "premium_expired"
  | "legal_updated";

export const deleteGroup = onCall({ region: callableFunctionRegion }, async (request) => {
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

export const leaveGroup = onCall({ region: callableFunctionRegion }, async (request) => {
  const uid = request.auth?.uid;
  const groupId = normalizeGroupId(request.data?.groupId);

  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required");
  }

  if (!groupId) {
    throw new HttpsError("invalid-argument", "groupId is required");
  }

  const result = await leaveGroupForUser(groupId, uid);

  return {
    groupId,
    leftUid: uid,
    deletedGroup: result.deletedGroup,
    deletedPhotoCount: result.deletedPhotoCount,
    ...(result.newOwnerUid ? { newOwnerUid: result.newOwnerUid } : {})
  };
});

export const deleteCurrentUserData = onCall({ region: callableFunctionRegion }, async (request) => {
  const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required");
  }

  const groupsSnapshot = await db.collection("groups")
    .where("members", "array-contains", uid)
    .get();

  let deletedGroupCount = 0;
  let transferredGroupCount = 0;
  let deletedPhotoCount = 0;

  for (const groupDoc of groupsSnapshot.docs) {
    const result = await leaveGroupForUser(groupDoc.id, uid, groupDoc);
    deletedPhotoCount += result.deletedPhotoCount;
    if (result.deletedGroup) {
      deletedGroupCount += 1;
    } else if (result.newOwnerUid) {
      transferredGroupCount += 1;
    }
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
    transferredGroupCount,
    leftGroupCount: groupsSnapshot.size - deletedGroupCount,
    deletedPhotoCount
  };
});

export const createGroupInvite = onCall({ region: callableFunctionRegion }, async (request) => {
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

export const joinGroupInvite = onCall({ region: callableFunctionRegion }, async (request) => {
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
  let didJoin = false;

  await db.runTransaction(async (transaction) => {
    const groupSnapshot = await transaction.get(groupRef);
    if (!groupSnapshot.exists) {
      throw new HttpsError("not-found", "Group not found");
    }

    const groupData = groupSnapshot.data() as GroupData;
    const members = Array.isArray(groupData.members) ? groupData.members : [];

    const isAlreadyMember = members.includes(uid);
    didJoin = !isAlreadyMember;

    if (!isAlreadyMember && members.length >= maxGroupMembers) {
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
    joined: didJoin
  };
});

export const deletePhoto = onCall({ region: callableFunctionRegion }, async (request) => {
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

export const removeGroupMember = onCall({ region: callableFunctionRegion }, async (request) => {
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

export const syncSubscription = onCall({ region: callableFunctionRegion, secrets: [resendApiKey] }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required");
  }

  const signedTransactionInfo = normalizeText(request.data?.signedTransactionInfo);
  const signedRenewalInfo = normalizeText(request.data?.signedRenewalInfo);
  const userRef = db.collection("users").doc(uid);
  const previousUserSnapshot = await userRef.get();
  const previousUserData = previousUserSnapshot.data();
  const wasPremiumActive = isPremiumEntitlementActive(previousUserData);

  if (!signedTransactionInfo) {
    await userRef.update(clearPremiumCachePayload());
    if (wasPremiumActive) {
      await sendUserEmail(uid, "premium_expired", premiumExpiredEmail(), {
        dedupeKey: expirationDedupeKey(previousUserData?.premium_expires_at)
      });
    }
    return { isPremiumActive: false };
  }

  let transaction: JWSTransactionDecodedPayload;
  try {
    transaction = await verifyPremiumTransaction(signedTransactionInfo);
  } catch (error) {
    console.warn("Premium subscription transaction verification failed", {
      uid,
      error: errorMessage(error)
    });
    throw new HttpsError("failed-precondition", "Premium subscription could not be verified");
  }

  let renewalInfo: JWSRenewalInfoDecodedPayload | null = null;
  if (signedRenewalInfo) {
    try {
      renewalInfo = await verifyPremiumRenewalInfo(signedRenewalInfo);
    } catch (error) {
      console.warn("Premium subscription renewal info verification failed", {
        uid,
        error: errorMessage(error)
      });
    }
  }

  if (!isActivePremiumTransaction(transaction)) {
    await userRef.update(clearPremiumCachePayload());
    if (wasPremiumActive) {
      await sendUserEmail(uid, "premium_expired", premiumExpiredEmail(), {
        dedupeKey: expirationDedupeKey(previousUserData?.premium_expires_at)
      });
    }
    return { isPremiumActive: false };
  }

  const expiresDate = transaction.expiresDate as number;
  const willAutoRenew = renewalInfo?.autoRenewStatus === AutoRenewStatus.ON
    || (renewalInfo?.autoRenewStatus !== AutoRenewStatus.OFF && previousUserData?.premium_will_auto_renew === true);
  await userRef.update(premiumCachePayload(transaction, expiresDate, willAutoRenew));

  if (!wasPremiumActive) {
    await sendUserEmail(uid, "premium_purchased", premiumPurchasedEmail(expiresDate), {
      dedupeKey: currentTransactionDedupeKey(transaction)
    });
  } else if (previousUserData?.premium_will_auto_renew === true && !willAutoRenew) {
    await sendUserEmail(uid, "premium_cancelled", premiumCancelledEmail(expiresDate), {
      dedupeKey: currentTransactionDedupeKey(transaction, "cancelled")
    });
  }

  return {
    isPremiumActive: true,
    premiumExpiresAt: new Date(expiresDate).toISOString()
  };
});

export const commitPhotoUploadBatch = onCall({ region: callableFunctionRegion }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required");
  }

  const groupId = normalizeGroupId(request.data?.groupId);
  const uploadBatchId = normalizeUploadBatchId(request.data?.uploadBatchId);
  const hashtags = normalizeHashtags(request.data?.hashtags);
  const caption = normalizeCaption(request.data?.caption);
  const inputPhotos: unknown[] = Array.isArray(request.data?.photos) ? request.data.photos : [];

  if (!groupId || !uploadBatchId) {
    throw new HttpsError("invalid-argument", "groupId and uploadBatchId are required");
  }

  if (inputPhotos.length === 0 || inputPhotos.length > maxUploadBatchPhotoCount) {
    throw new HttpsError("invalid-argument", "photos must contain 1 to 10 items");
  }

  const groupSnapshot = await db.collection("groups").doc(groupId).get();
  if (!groupSnapshot.exists) {
    throw new HttpsError("not-found", "Group not found");
  }

  const groupData = groupSnapshot.data() as GroupData;
  const members = Array.isArray(groupData.members) ? groupData.members : [];
  if (!members.includes(uid)) {
    throw new HttpsError("permission-denied", "Only group members can upload photos");
  }

  const bucket = storage.bucket();
  const createdAt = new Date();
  const committedPhotos: UploadCommitItem[] = [];

  try {
    for (const rawPhoto of inputPhotos) {
      const input = normalizeUploadPhoto(rawPhoto, uid, uploadBatchId);
      const ref = db.collection("photos").doc();
      const finalPreviewPath = `photos/${uid}/${ref.id}_preview.jpg`;
      const finalThumbnailPath = `photos/${uid}/${ref.id}_thumb.jpg`;
      const [previewSizeMB, thumbnailSizeMB] = await Promise.all([
        storageFileSizeMB(bucket, input.previewPath),
        storageFileSizeMB(bucket, input.thumbnailPath)
      ]);

      await Promise.all([
        bucket.file(input.previewPath).copy(bucket.file(finalPreviewPath)),
        bucket.file(input.thumbnailPath).copy(bucket.file(finalThumbnailPath))
      ]);

      committedPhotos.push({
        ...input,
        finalPreviewPath,
        finalThumbnailPath,
        ref,
        sizeMB: roundMegabytes(previewSizeMB + thumbnailSizeMB)
      });
    }

    const totalUploadMB = roundMegabytes(committedPhotos.reduce((total, photo) => total + photo.sizeMB, 0));

    await db.runTransaction(async (transaction) => {
      const freshGroupSnapshot = await transaction.get(db.collection("groups").doc(groupId));
      if (!freshGroupSnapshot.exists) {
        throw new HttpsError("not-found", "Group not found");
      }

      const freshGroupData = freshGroupSnapshot.data() as GroupData;
      const freshMembers = Array.isArray(freshGroupData.members) ? freshGroupData.members : [];
      if (!freshMembers.includes(uid)) {
        throw new HttpsError("permission-denied", "Only group members can upload photos");
      }

      const userRef = db.collection("users").doc(uid);
      const userSnapshot = await transaction.get(userRef);
      const usageMB = numericValue(userSnapshot.data()?.usage_mb) ?? 0;
      const quotaMB = isPremiumEntitlementActive(userSnapshot.data()) ? premiumQuotaMB : freeQuotaMB;
      if (usageMB + totalUploadMB > quotaMB) {
        throw new HttpsError("resource-exhausted", "Storage limit reached");
      }

      for (const photo of committedPhotos) {
        transaction.set(photo.ref, {
          preview_storage_path: photo.finalPreviewPath,
          thumbnail_storage_path: photo.finalThumbnailPath,
          group_id: groupId,
          posted_by: uid,
          hashtags,
          ...(caption ? { caption } : {}),
          aspect_ratio: photo.aspectRatio,
          size_mb: photo.sizeMB,
          upload_batch_id: uploadBatchId,
          upload_batch_count: committedPhotos.length,
          date: FieldValue.serverTimestamp(),
          created_at: FieldValue.serverTimestamp()
        });
      }

      transaction.set(userRef, {
        usage_mb: FieldValue.increment(totalUploadMB)
      }, { merge: true });
    });

    await deleteStoragePaths([
      ...committedPhotos.map((photo) => photo.previewPath),
      ...committedPhotos.map((photo) => photo.thumbnailPath)
    ]);

    return {
      photos: committedPhotos.map((photo) => ({
        id: photo.ref.id,
        preview_storage_path: photo.finalPreviewPath,
        thumbnail_storage_path: photo.finalThumbnailPath,
        group_id: groupId,
        posted_by: uid,
        hashtags,
        ...(caption ? { caption } : {}),
        aspect_ratio: photo.aspectRatio,
        size_mb: photo.sizeMB,
        upload_batch_id: uploadBatchId,
        upload_batch_count: committedPhotos.length,
        date: createdAt.toISOString(),
        created_at: createdAt.toISOString()
      })),
      totalUploadMB
    };
  } catch (error) {
    await deleteStoragePaths([
      ...committedPhotos.map((photo) => photo.finalPreviewPath),
      ...committedPhotos.map((photo) => photo.finalThumbnailPath),
      ...inputPhotos.flatMap((rawPhoto) => {
        try {
          const input = normalizeUploadPhoto(rawPhoto, uid, uploadBatchId);
          return [input.previewPath, input.thumbnailPath];
        } catch {
          return [];
        }
      })
    ]);

    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", errorMessage(error));
  }
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
  const uploadBatchCount = normalizeBatchCount(photoData.upload_batch_count);

  if (!photoId || !groupId || !postedBy) {
    return;
  }

  const uploadBatchId = normalizeText(photoData.upload_batch_id) ?? photoId;

  const shouldNotify = await reservePhotoBatchNotification(
    uploadBatchId,
    groupId,
    postedBy,
    photoId,
    uploadBatchCount
  );
  if (!shouldNotify) {
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
  const photoCountLabel = uploadBatchCount === 1 ? "a new photo" : `${uploadBatchCount} new photos`;
  const delivery = await sendPushToUserIDs(recipientUIDs, {
    title: groupData.name ? `New photo in ${groupData.name}` : "New photo in Kuusi",
    body: `${senderName} posted ${photoCountLabel}`,
    data: {
      type: "photo_posted",
      group_id: groupId,
      photo_id: photoId,
      posted_by: postedBy,
      upload_batch_id: uploadBatchId
    }
  });

  console.info("Photo notification delivered", {
    groupId,
    photoId,
    uploadBatchId,
    uploadBatchCount,
    recipientCount: recipientUIDs.length,
    sentCount: delivery.sentCount,
    failedCount: delivery.failedCount
  });
});

export const sendPremiumExpiryEmails = onSchedule({
  schedule: "every day 09:00",
  timeZone: "Europe/London",
  region: emailFunctionRegion,
  secrets: [resendApiKey]
}, async () => {
  const now = Date.now();
  const expiringEnd = Timestamp.fromMillis(now + premiumExpiryNoticeDays * 24 * 60 * 60 * 1000);
  const nowTimestamp = Timestamp.fromMillis(now);

  const expiringSnapshot = await db.collection("users")
    .where("premium_expires_at", ">", nowTimestamp)
    .where("premium_expires_at", "<=", expiringEnd)
    .where("premium_will_auto_renew", "==", false)
    .limit(emailBatchLimit)
    .get();

  for (const userDocument of expiringSnapshot.docs) {
    const expiresAt = userDocument.data().premium_expires_at;
    if (!(expiresAt instanceof Timestamp)) {
      continue;
    }
    await sendUserEmail(userDocument.id, "premium_expiring", premiumExpiringEmail(expiresAt.toMillis()), {
      dedupeKey: expirationDedupeKey(expiresAt)
    });
  }

  const expiredSnapshot = await db.collection("users")
    .where("premium_expires_at", "<=", nowTimestamp)
    .limit(emailBatchLimit)
    .get();

  for (const userDocument of expiredSnapshot.docs) {
    const expiresAt = userDocument.data().premium_expires_at;
    if (!(expiresAt instanceof Timestamp)) {
      continue;
    }
    await sendUserEmail(userDocument.id, "premium_expired", premiumExpiredEmail(), {
      dedupeKey: expirationDedupeKey(expiresAt)
    });
    await userDocument.ref.update(clearPremiumCachePayload());
  }
});

export const onLegalAnnouncementCreated = onDocumentCreated({
  document: "legal_announcements/{announcementId}",
  region: emailFunctionRegion,
  secrets: [resendApiKey]
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    return;
  }

  const announcementId = normalizeText(event.params.announcementId);
  if (!announcementId) {
    return;
  }

  const announcementRef = snapshot.ref;
  const announcementData = snapshot.data() as LegalAnnouncementData;
  if (announcementData.status === "draft") {
    return;
  }

  const title = normalizeText(announcementData.title) ?? "Important update to Kuusi terms";
  const body = normalizeText(announcementData.body);
  if (!body) {
    await announcementRef.set({
      status: "failed",
      failure_reason: "body_required",
      updated_at: FieldValue.serverTimestamp()
    }, { merge: true });
    return;
  }

  const usersSnapshot = await db.collection("users")
    .orderBy("__name__")
    .limit(emailBatchLimit)
    .get();
  let sentCount = 0;

  for (const userDocument of usersSnapshot.docs) {
    const didSend = await sendUserEmail(userDocument.id, "legal_updated", legalUpdatedEmail({
      body,
      effectiveAt: announcementData.effective_at,
      privacyURL: normalizeText(announcementData.privacy_url),
      termsURL: normalizeText(announcementData.terms_url),
      title
    }), {
      dedupeKey: announcementId
    });
    if (didSend) {
      sentCount += 1;
    }
  }

  await announcementRef.set({
    status: "sent",
    sent_at: FieldValue.serverTimestamp(),
    sent_count: sentCount,
    updated_at: FieldValue.serverTimestamp()
  }, { merge: true });
});

function normalizeGroupId(value: unknown): string | null {
  return normalizeText(value);
}

async function verifyPremiumTransaction(signedTransactionInfo: string): Promise<JWSTransactionDecodedPayload> {
  const errors: string[] = [];

  for (const entry of appStoreVerifiers) {
    try {
      return await entry.verifier.verifyAndDecodeTransaction(signedTransactionInfo);
    } catch (error) {
      errors.push(`${entry.environment}: ${errorMessage(error)}`);
    }
  }

  throw new Error(errors.join("; ") || "No App Store verifier is configured");
}

async function verifyPremiumRenewalInfo(signedRenewalInfo: string): Promise<JWSRenewalInfoDecodedPayload> {
  const errors: string[] = [];

  for (const entry of appStoreVerifiers) {
    try {
      return await entry.verifier.verifyAndDecodeRenewalInfo(signedRenewalInfo);
    } catch (error) {
      errors.push(`${entry.environment}: ${errorMessage(error)}`);
    }
  }

  throw new Error(errors.join("; ") || "No App Store verifier is configured");
}

function isActivePremiumTransaction(transaction: JWSTransactionDecodedPayload): boolean {
  const expiresDate = numericValue(transaction.expiresDate);
  return transaction.productId === premiumProductId
    && transaction.type === Type.AUTO_RENEWABLE_SUBSCRIPTION
    && transaction.revocationDate === undefined
    && expiresDate !== null
    && expiresDate > Date.now();
}

function premiumCachePayload(
  transaction: JWSTransactionDecodedPayload,
  expiresDate: number,
  willAutoRenew: boolean
): FirebaseFirestore.DocumentData {
  return {
    premium_expires_at: Timestamp.fromMillis(expiresDate),
    premium_product_id: transaction.productId,
    premium_original_transaction_id: transaction.originalTransactionId ?? "",
    premium_transaction_id: transaction.transactionId ?? "",
    premium_environment: transaction.environment ?? "",
    premium_will_auto_renew: willAutoRenew,
    premium_last_verified_at: FieldValue.serverTimestamp()
  };
}

function clearPremiumCachePayload(): FirebaseFirestore.DocumentData {
  return {
    premium_expires_at: FieldValue.delete(),
    premium_product_id: FieldValue.delete(),
    premium_original_transaction_id: FieldValue.delete(),
    premium_transaction_id: FieldValue.delete(),
    premium_environment: FieldValue.delete(),
    premium_will_auto_renew: FieldValue.delete(),
    premium_last_verified_at: FieldValue.serverTimestamp()
  };
}

function isPremiumEntitlementActive(data: FirebaseFirestore.DocumentData | undefined): boolean {
  const expiresAt = data?.premium_expires_at;
  if (expiresAt instanceof Timestamp) {
    return expiresAt.toMillis() > Date.now();
  }

  return false;
}

async function sendUserEmail(
  uid: string,
  type: EmailType,
  payload: EmailPayload,
  options: { dedupeKey: string }
): Promise<boolean> {
  const recipient = await loadUserEmail(uid);
  const logRef = db.collection("email_logs").doc(emailLogId(uid, type, options.dedupeKey));

  try {
    await logRef.create({
      user_id: uid,
      email: recipient ?? "",
      type,
      dedupe_key: options.dedupeKey,
      status: recipient ? "pending" : "skipped",
      created_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
      ...(recipient ? {} : { failure_reason: "missing_email" })
    });
  } catch (error) {
    if (isAlreadyExistsError(error)) {
      return false;
    }
    throw error;
  }

  if (!recipient) {
    return false;
  }

  try {
    const providerMessageId = await sendEmail(recipient, payload);
    await logRef.set({
      status: "accepted",
      provider: "resend",
      provider_message_id: providerMessageId,
      accepted_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp()
    }, { merge: true });
    return true;
  } catch (error) {
    await logRef.set({
      status: "failed",
      failure_reason: errorMessage(error),
      updated_at: FieldValue.serverTimestamp()
    }, { merge: true });
    console.warn("Email delivery failed", {
      uid,
      type,
      error: errorMessage(error)
    });
    return false;
  }
}

async function loadUserEmail(uid: string): Promise<string | null> {
  try {
    const userRecord = await getAuth().getUser(uid);
    return normalizeEmail(userRecord.email);
  } catch (error) {
    console.warn("Failed to load user email", {
      uid,
      error: errorMessage(error)
    });
    return null;
  }
}

async function sendEmail(to: string, payload: EmailPayload): Promise<string> {
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${resendApiKey.value()}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      from: emailFrom,
      to: [to],
      subject: payload.subject,
      html: payload.html,
      text: payload.text
    })
  });

  const responseText = await response.text();
  if (!response.ok) {
    throw new Error(`resend_${response.status}: ${responseText}`);
  }

  try {
    const data = JSON.parse(responseText) as { id?: unknown };
    const id = normalizeText(data.id);
    return id ?? "";
  } catch {
    return "";
  }
}

function currentTransactionDedupeKey(transaction: JWSTransactionDecodedPayload, suffix?: string): string {
  const base = normalizeText(transaction.transactionId)
    ?? normalizeText(transaction.originalTransactionId)
    ?? "unknown_transaction";
  return suffix ? `${base}_${suffix}` : base;
}

function expirationDedupeKey(value: unknown): string {
  if (value instanceof Timestamp) {
    return value.toDate().toISOString().slice(0, 10);
  }
  return "unknown_expiration";
}

async function storageFileSizeMB(bucket: StorageBucket, path: string): Promise<number> {
  try {
    const [metadata] = await bucket.file(path).getMetadata();
    const byteSize = numericValue(metadata.size);
    if (byteSize === null || byteSize <= 0) {
      throw new HttpsError("failed-precondition", "Upload file is empty");
    }
    return byteSize / 1024 / 1024;
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("failed-precondition", `Upload file is missing: ${path}`);
  }
}

async function deleteStoragePaths(paths: string[]): Promise<void> {
  const bucket = storage.bucket();
  const uniquePaths = Array.from(new Set(paths.filter((path) => path.length > 0)));

  for (const path of uniquePaths) {
    try {
      await bucket.file(path).delete();
    } catch (error) {
      if (!isObjectNotFoundError(error)) {
        console.warn("Failed to delete upload storage path", {
          path,
          error: errorMessage(error)
        });
      }
    }
  }
}

async function reservePhotoBatchNotification(
  uploadBatchId: string,
  groupId: string,
  postedBy: string,
  photoId: string,
  uploadBatchCount: number
): Promise<boolean> {
  const notificationRef = db.collection("photo_notification_batches").doc(uploadBatchId);

  return db.runTransaction(async (transaction) => {
    const existingSnapshot = await transaction.get(notificationRef);
    if (existingSnapshot.exists) {
      return false;
    }

    transaction.create(notificationRef, {
      created_at: FieldValue.serverTimestamp(),
      first_photo_id: photoId,
      group_id: groupId,
      posted_by: postedBy,
      photo_count: uploadBatchCount
    });

    return true;
  });
}

async function deleteOwnedGroup(
  groupId: string,
  requesterUID: string,
  existingSnapshot?: DocumentSnapshot
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

async function leaveGroupForUser(
  groupId: string,
  uid: string,
  existingSnapshot?: DocumentSnapshot
): Promise<LeaveGroupResult> {
  const groupRef = db.collection("groups").doc(groupId);
  const groupSnapshot = existingSnapshot ?? await groupRef.get();

  if (!groupSnapshot.exists) {
    throw new HttpsError("not-found", "Group not found");
  }

  const groupData = groupSnapshot.data() as GroupData;
  const memberIDs = Array.isArray(groupData.members) ? groupData.members : [];

  if (!memberIDs.includes(uid)) {
    throw new HttpsError("permission-denied", "Only group members can leave this group");
  }

  if (groupData.owner_uid === uid && memberIDs.filter((memberID) => memberID !== uid).length === 0) {
    const deletedPhotoCount = await deleteOwnedGroup(groupId, uid, groupSnapshot);
    return {
      deletedGroup: true,
      deletedPhotoCount
    };
  }

  let newOwnerUid: string | undefined;

  await db.runTransaction(async (transaction) => {
    const freshGroupSnapshot = await transaction.get(groupRef);
    if (!freshGroupSnapshot.exists) {
      throw new HttpsError("not-found", "Group not found");
    }

    const freshGroupData = freshGroupSnapshot.data() as GroupData;
    const freshMemberIDs = Array.isArray(freshGroupData.members) ? freshGroupData.members : [];
    if (!freshMemberIDs.includes(uid)) {
      throw new HttpsError("permission-denied", "Only group members can leave this group");
    }

    const remainingMemberIDs = freshMemberIDs.filter((memberID) => memberID !== uid);
    if (freshGroupData.owner_uid === uid) {
      const nextOwnerUid = remainingMemberIDs[0];
      if (!nextOwnerUid) {
        throw new HttpsError("failed-precondition", "The final owner cannot leave during ownership transfer");
      }
      newOwnerUid = nextOwnerUid;
      transaction.update(groupRef, {
        members: remainingMemberIDs,
        owner_uid: nextOwnerUid
      });
    } else {
      transaction.update(groupRef, {
        members: FieldValue.arrayRemove(uid)
      });
    }

    transaction.set(
      db.collection("users").doc(uid),
      { groups: FieldValue.arrayRemove(groupId) },
      { merge: true }
    );
  });

  return {
    deletedGroup: false,
    deletedPhotoCount: 0,
    ...(newOwnerUid ? { newOwnerUid } : {})
  };
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
  photos: Array<{ preview_storage_path?: string; thumbnail_storage_path?: string }>
): Promise<void> {
  const bucket = storage.bucket();

  for (const photo of photos) {
    for (const path of [photo.preview_storage_path, photo.thumbnail_storage_path]) {
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
