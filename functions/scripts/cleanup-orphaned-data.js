"use strict";

const { initializeApp, applicationDefault, cert } = require("firebase-admin/app");
const { getFirestore, FieldPath, FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const fs = require("fs");
const path = require("path");

const DEFAULT_BATCH_SIZE = 200;
const MAX_BATCH_WRITES = 400;
const MAX_GET_ALL_REFS = 300;
const NOTIFICATION_BATCH_RETENTION_DAYS = 7;
const NOTIFICATION_BATCH_RETENTION_MS = NOTIFICATION_BATCH_RETENTION_DAYS * 24 * 60 * 60 * 1000;
const DEFAULT_GOOGLE_SERVICE_INFO_PATH = path.resolve(__dirname, "../../Kuusi/GoogleService-Info.plist");

function parseArgs(argv) {
  const options = {
    apply: false,
    batchSize: DEFAULT_BATCH_SIZE,
    bucket: process.env.FIREBASE_STORAGE_BUCKET || "",
    credentials: process.env.GOOGLE_APPLICATION_CREDENTIALS || "",
    project: process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || "",
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === "--apply") {
      options.apply = true;
      continue;
    }

    if (arg === "--batch-size") {
      const value = argv[index + 1];
      const parsed = Number.parseInt(value, 10);
      if (!Number.isFinite(parsed) || parsed <= 0) {
        throw new Error("Expected a positive integer after --batch-size");
      }
      options.batchSize = parsed;
      index += 1;
      continue;
    }

    if (arg === "--credentials") {
      const value = argv[index + 1];
      if (!value) {
        throw new Error("Expected a file path after --credentials");
      }
      options.credentials = value;
      index += 1;
      continue;
    }

    if (arg === "--bucket") {
      const value = argv[index + 1];
      if (!value) {
        throw new Error("Expected a Firebase Storage bucket name after --bucket");
      }
      options.bucket = value;
      index += 1;
      continue;
    }

    if (arg === "--project") {
      const value = argv[index + 1];
      if (!value) {
        throw new Error("Expected a Firebase project ID after --project");
      }
      options.project = value;
      index += 1;
      continue;
    }

    if (arg === "--help" || arg === "-h") {
      options.help = true;
      continue;
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  return options;
}

function printUsage() {
  console.log(`
Usage:
  node scripts/cleanup-orphaned-data.js [--apply] [--batch-size 200] [--credentials /path/to/service-account.json]
  node scripts/cleanup-orphaned-data.js --project your-project --bucket your-project.firebasestorage.app

Defaults to dry-run mode. Use --apply to delete orphaned documents, stale user references, expired invites, and orphaned Storage files.

Cleanup targets:
  - photos whose group_id does not point at an existing groups document
  - Storage files that are not referenced by existing photos documents
  - users.favourites entries that do not point at existing photos documents
  - users.groups entries that do not point at existing groups documents
  - expired or invalid group_invites documents
  - photo_notification_batches documents older than 7 days

Authentication:
  - Set GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
  - or pass --credentials /path/to/service-account.json
  - Storage bucket defaults to ../../Kuusi/GoogleService-Info.plist
  - or set FIREBASE_STORAGE_BUCKET / pass --bucket your-project.firebasestorage.app
  - Set GOOGLE_CLOUD_PROJECT=your-project if the project cannot be detected automatically
`);
}

function initialiseFirebase(options) {
  if (!options.bucket) {
    options.bucket = storageBucketFromGoogleServiceInfo(DEFAULT_GOOGLE_SERVICE_INFO_PATH) || "";
  }

  if (!options.project && options.bucket) {
    options.project = projectIDFromBucket(options.bucket) || "";
  }

  const appOptions = {
    projectId: options.project || undefined,
    storageBucket: options.bucket || undefined,
  };

  if (options.project && !process.env.GOOGLE_CLOUD_PROJECT) {
    process.env.GOOGLE_CLOUD_PROJECT = options.project;
  }

  const credentialsPath = options.credentials;
  if (credentialsPath) {
    const absolutePath = path.resolve(credentialsPath);
    const contents = fs.readFileSync(absolutePath, "utf8");
    initializeApp({
      ...appOptions,
      credential: cert(JSON.parse(contents)),
    });
    return;
  }

  initializeApp({
    ...appOptions,
    credential: applicationDefault(),
  });
}

function projectIDFromBucket(bucket) {
  const match = /^([a-z0-9-]+)\.(appspot\.com|firebasestorage\.app)$/.exec(bucket);
  return match ? match[1] : null;
}

function storageBucketFromGoogleServiceInfo(filePath) {
  if (!fs.existsSync(filePath)) {
    return null;
  }

  const contents = fs.readFileSync(filePath, "utf8");
  const match = /<key>STORAGE_BUCKET<\/key>\s*<string>([^<]+)<\/string>/.exec(contents);
  return match ? match[1].trim() : null;
}

function normalisedString(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalisedStringArray(value) {
  if (!Array.isArray(value)) return [];
  return value.map(normalisedString).filter(Boolean);
}

function storagePathsForPhoto(data) {
  return [
    normalisedString(data.preview_storage_path),
    normalisedString(data.thumbnail_storage_path),
  ].filter(Boolean);
}

async function scanCollection(db, collectionName, batchSize, handleSnapshot) {
  let lastDocument = null;

  while (true) {
    let query = db.collection(collectionName)
      .orderBy(FieldPath.documentId())
      .limit(batchSize);

    if (lastDocument) {
      query = query.startAfter(lastDocument);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    await handleSnapshot(snapshot);

    lastDocument = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.docs.length < batchSize) {
      break;
    }
  }
}

async function loadExistingIDs(db, collectionName, ids) {
  const uniqueIDs = Array.from(new Set(ids.map(normalisedString).filter(Boolean)));
  const existingIDs = new Set();

  for (const chunk of chunked(uniqueIDs, MAX_GET_ALL_REFS)) {
    const refs = chunk.map((id) => db.collection(collectionName).doc(id));
    const snapshots = await db.getAll(...refs);

    snapshots.forEach((snapshot, index) => {
      if (snapshot.exists) {
        existingIDs.add(chunk[index]);
      }
    });
  }

  return existingIDs;
}

async function cleanupPhotosWithMissingGroups(db, bucket, options) {
  let scannedPhotos = 0;
  let orphanPhotos = 0;
  let deletedPhotos = 0;
  let deletedStorageFiles = 0;
  let removedFavouriteRefs = 0;
  let decrementedUsageUsers = 0;

  await scanCollection(db, "photos", options.batchSize, async (snapshot) => {
    scannedPhotos += snapshot.docs.length;

    const groupIDs = snapshot.docs
      .map((document) => normalisedString(document.data().group_id))
      .filter(Boolean);
    const existingGroupIDs = await loadExistingIDs(db, "groups", groupIDs);

    const orphanDocs = snapshot.docs.filter((document) => {
      const groupID = normalisedString(document.data().group_id);
      return !groupID || !existingGroupIDs.has(groupID);
    });

    if (orphanDocs.length === 0) {
      return;
    }

    const result = await deletePhotosAndCleanup(db, bucket, orphanDocs, options.apply);
    orphanPhotos += orphanDocs.length;
    deletedPhotos += result.deletedPhotos;
    deletedStorageFiles += result.deletedStorageFiles;
    removedFavouriteRefs += result.removedFavouriteRefs;
    decrementedUsageUsers += result.decrementedUsageUsers;
  });

  return {
    scannedPhotos,
    orphanPhotos,
    deletedPhotos,
    deletedStorageFiles,
    removedFavouriteRefs,
    decrementedUsageUsers,
  };
}

async function deletePhotosAndCleanup(db, bucket, photoDocs, apply) {
  const photoIDs = photoDocs.map((document) => document.id);
  const photoRecords = photoDocs.map((document) => ({
    id: document.id,
    ref: document.ref,
    data: document.data(),
  }));

  const storagePaths = photoRecords.flatMap((photo) => storagePathsForPhoto(photo.data));
  const usageByUserID = buildUsageMap(photoRecords.map((photo) => photo.data));
  const favouriteRemovals = await loadFavouriteRemovals(db, photoIDs);
  const removedFavouriteRefs = Object.values(favouriteRemovals)
    .reduce((sum, ids) => sum + ids.length, 0);

  if (!apply) {
    return {
      deletedPhotos: 0,
      deletedStorageFiles: 0,
      removedFavouriteRefs,
      decrementedUsageUsers: Object.keys(usageByUserID).length,
    };
  }

  const deletedStorageFiles = await deleteStoragePaths(bucket, storagePaths);

  const operations = [
    ...photoRecords.map((photo) => (batch) => batch.delete(photo.ref)),
    ...Object.entries(usageByUserID).map(([userID, sizeMB]) => (batch) =>
      batch.set(
        db.collection("users").doc(userID),
        { usage_mb: FieldValue.increment(-sizeMB) },
        { merge: true }
      )
    ),
    ...Object.entries(favouriteRemovals).map(([userID, ids]) => (batch) =>
      batch.set(
        db.collection("users").doc(userID),
        { favourites: FieldValue.arrayRemove(...ids) },
        { merge: true }
      )
    ),
  ];

  await commitOperations(db, operations);

  return {
    deletedPhotos: photoRecords.length,
    deletedStorageFiles,
    removedFavouriteRefs,
    decrementedUsageUsers: Object.keys(usageByUserID).length,
  };
}

function buildUsageMap(photos) {
  const usageByUserID = {};

  for (const photo of photos) {
    const postedBy = normalisedString(photo.posted_by);
    if (!postedBy || typeof photo.size_mb !== "number" || photo.size_mb <= 0) {
      continue;
    }
    usageByUserID[postedBy] = (usageByUserID[postedBy] || 0) + photo.size_mb;
  }

  return usageByUserID;
}

async function loadFavouriteRemovals(db, photoIDs) {
  if (photoIDs.length === 0) {
    return {};
  }

  const favouriteRemovals = {};

  for (const chunk of chunked(photoIDs, 10)) {
    const snapshot = await db.collection("users")
      .where("favourites", "array-contains-any", chunk)
      .get();

    for (const document of snapshot.docs) {
      favouriteRemovals[document.id] ||= new Set();
      for (const photoID of chunk) {
        favouriteRemovals[document.id].add(photoID);
      }
    }
  }

  return Object.fromEntries(
    Object.entries(favouriteRemovals).map(([userID, ids]) => [userID, Array.from(ids)])
  );
}

async function cleanupStorageWithMissingPhotos(db, bucket, options) {
  let scannedStorageFiles = 0;
  let skippedStorageFiles = 0;
  let orphanStorageFiles = 0;
  let deletedStorageFiles = 0;
  let pageToken = undefined;
  const referencedStoragePaths = await loadReferencedPhotoStoragePaths(db, options.batchSize);

  do {
    const [files, nextQuery] = await bucket.getFiles({
      autoPaginate: false,
      maxResults: options.batchSize,
      pageToken,
      prefix: "photos/",
    });

    scannedStorageFiles += files.length;

    const managedFiles = files.filter((file) => isManagedPhotoStoragePath(file.name));
    skippedStorageFiles += files.length - managedFiles.length;

    const orphanFiles = managedFiles
      .filter((file) => !referencedStoragePaths.has(file.name));

    orphanStorageFiles += orphanFiles.length;

    if (options.apply && orphanFiles.length > 0) {
      for (const file of orphanFiles) {
        try {
          await file.delete();
          deletedStorageFiles += 1;
        } catch (error) {
          if (!isObjectNotFoundError(error)) {
            throw error;
          }
        }
      }
    }

    pageToken = nextQuery && nextQuery.pageToken;
  } while (pageToken);

  return {
    scannedStorageFiles,
    skippedStorageFiles,
    orphanStorageFiles,
    deletedStorageFiles,
  };
}

async function loadReferencedPhotoStoragePaths(db, batchSize) {
  const referencedStoragePaths = new Set();

  await scanCollection(db, "photos", batchSize, async (snapshot) => {
    for (const document of snapshot.docs) {
      for (const storagePath of storagePathsForPhoto(document.data())) {
        referencedStoragePaths.add(storagePath);
      }
    }
  });

  return referencedStoragePaths;
}

function isManagedPhotoStoragePath(storagePath) {
  return /^photos\/[^/]+\/.+_(preview|thumb)\.jpg$/.test(storagePath);
}

async function cleanupUserReferences(db, options) {
  let scannedUsers = 0;
  let usersWithFavouriteUpdates = 0;
  let usersWithGroupUpdates = 0;
  let removedFavouriteRefs = 0;
  let removedGroupRefs = 0;
  const operations = [];

  await scanCollection(db, "users", options.batchSize, async (snapshot) => {
    scannedUsers += snapshot.docs.length;

    const favouriteIDs = snapshot.docs.flatMap((document) => normalisedStringArray(document.data().favourites));
    const groupIDs = snapshot.docs.flatMap((document) => normalisedStringArray(document.data().groups));

    const existingPhotoIDs = await loadExistingIDs(db, "photos", favouriteIDs);
    const existingGroupIDs = await loadExistingIDs(db, "groups", groupIDs);

    for (const document of snapshot.docs) {
      const favourites = normalisedStringArray(document.data().favourites);
      const groups = normalisedStringArray(document.data().groups);
      const missingFavouriteIDs = favourites.filter((photoID) => !existingPhotoIDs.has(photoID));
      const missingGroupIDs = groups.filter((groupID) => !existingGroupIDs.has(groupID));

      if (missingFavouriteIDs.length > 0) {
        usersWithFavouriteUpdates += 1;
        removedFavouriteRefs += missingFavouriteIDs.length;
      }

      if (missingGroupIDs.length > 0) {
        usersWithGroupUpdates += 1;
        removedGroupRefs += missingGroupIDs.length;
      }

      if (options.apply && (missingFavouriteIDs.length > 0 || missingGroupIDs.length > 0)) {
        operations.push((batch) => {
          const payload = {};
          if (missingFavouriteIDs.length > 0) {
            payload.favourites = FieldValue.arrayRemove(...missingFavouriteIDs);
          }
          if (missingGroupIDs.length > 0) {
            payload.groups = FieldValue.arrayRemove(...missingGroupIDs);
          }
          batch.set(document.ref, payload, { merge: true });
        });
      }
    }
  });

  if (options.apply && operations.length > 0) {
    await commitOperations(db, operations);
  }

  return {
    scannedUsers,
    usersWithFavouriteUpdates,
    usersWithGroupUpdates,
    removedFavouriteRefs,
    removedGroupRefs,
    updatedUsers: options.apply ? operations.length : 0,
  };
}

async function cleanupGroupInvites(db, options) {
  let scannedInvites = 0;
  let expiredInvites = 0;
  let invalidInvites = 0;
  let missingGroupInvites = 0;
  const operations = [];

  await scanCollection(db, "group_invites", options.batchSize, async (snapshot) => {
    scannedInvites += snapshot.docs.length;

    const groupIDs = snapshot.docs
      .map((document) => normalisedString(document.data().group_id))
      .filter(Boolean);
    const existingGroupIDs = await loadExistingIDs(db, "groups", groupIDs);

    for (const document of snapshot.docs) {
      const data = document.data();
      const groupID = normalisedString(data.group_id);
      const expiresAt = data.expires_at;
      const isExpired = expiresAt && typeof expiresAt.toMillis === "function" && expiresAt.toMillis() <= Date.now();
      const isInvalid = !groupID || !expiresAt || typeof expiresAt.toMillis !== "function";
      const isMissingGroup = groupID && !existingGroupIDs.has(groupID);

      if (!isExpired && !isInvalid && !isMissingGroup) {
        continue;
      }

      if (isExpired) {
        expiredInvites += 1;
      } else if (isInvalid) {
        invalidInvites += 1;
      } else {
        missingGroupInvites += 1;
      }

      if (options.apply) {
        operations.push((batch) => batch.delete(document.ref));
      }
    }
  });

  if (options.apply && operations.length > 0) {
    await commitOperations(db, operations);
  }

  return {
    scannedInvites,
    expiredInvites,
    invalidInvites,
    missingGroupInvites,
    deletedInvites: options.apply ? operations.length : 0,
  };
}

async function cleanupPhotoNotificationBatches(db, options) {
  let scannedNotificationBatches = 0;
  let expiredNotificationBatches = 0;
  let skippedNotificationBatches = 0;
  const cutoffMillis = Date.now() - NOTIFICATION_BATCH_RETENTION_MS;
  const operations = [];

  await scanCollection(db, "photo_notification_batches", options.batchSize, async (snapshot) => {
    scannedNotificationBatches += snapshot.docs.length;

    for (const document of snapshot.docs) {
      const createdAt = document.data().created_at;
      if (!createdAt || typeof createdAt.toMillis !== "function") {
        skippedNotificationBatches += 1;
        continue;
      }

      if (createdAt.toMillis() > cutoffMillis) {
        skippedNotificationBatches += 1;
        continue;
      }

      expiredNotificationBatches += 1;

      if (options.apply) {
        operations.push((batch) => batch.delete(document.ref));
      }
    }
  });

  if (options.apply && operations.length > 0) {
    await commitOperations(db, operations);
  }

  return {
    scannedNotificationBatches,
    expiredNotificationBatches,
    skippedNotificationBatches,
    deletedNotificationBatches: options.apply ? operations.length : 0,
  };
}

async function deleteStoragePaths(bucket, storagePaths) {
  let deletedCount = 0;

  for (const storagePath of storagePaths) {
    try {
      await bucket.file(storagePath).delete();
      deletedCount += 1;
    } catch (error) {
      if (!isObjectNotFoundError(error)) {
        throw error;
      }
    }
  }

  return deletedCount;
}

function isObjectNotFoundError(error) {
  return error && (error.code === 404 || error.code === "storage/object-not-found");
}

async function commitOperations(db, operations) {
  for (const chunk of chunked(operations, MAX_BATCH_WRITES)) {
    const batch = db.batch();
    for (const operation of chunk) {
      operation(batch);
    }
    await batch.commit();
  }
}

function chunked(items, size) {
  if (size <= 0) {
    return [items];
  }

  const chunks = [];
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }
  return chunks;
}

function printSection(title, result) {
  console.log(`\n${title}`);
  for (const [key, value] of Object.entries(result)) {
    console.log(`  ${key}: ${value}`);
  }
}

async function run() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    printUsage();
    return;
  }

  initialiseFirebase(options);
  const db = getFirestore();
  if (!options.bucket) {
    throw new Error("Firebase Storage bucket is required. Set FIREBASE_STORAGE_BUCKET or pass --bucket.");
  }
  const bucket = getStorage().bucket(options.bucket);

  console.log(`Mode: ${options.apply ? "apply" : "dry-run"}`);

  const orphanPhotoResult = await cleanupPhotosWithMissingGroups(db, bucket, options);
  const orphanStorageResult = await cleanupStorageWithMissingPhotos(db, bucket, options);
  const userReferenceResult = await cleanupUserReferences(db, options);
  const inviteResult = await cleanupGroupInvites(db, options);
  const notificationBatchResult = await cleanupPhotoNotificationBatches(db, options);

  printSection("Photos with missing groups", orphanPhotoResult);
  printSection("Storage files with missing photos", orphanStorageResult);
  printSection("User references", userReferenceResult);
  printSection("Group invites", inviteResult);
  printSection("Photo notification batches", notificationBatchResult);
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
