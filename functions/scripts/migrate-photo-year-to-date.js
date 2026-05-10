"use strict";

const { initializeApp, applicationDefault, cert } = require("firebase-admin/app");
const { getFirestore, FieldPath, FieldValue, Timestamp } = require("firebase-admin/firestore");
const fs = require("fs");
const path = require("path");

const DEFAULT_BATCH_SIZE = 200;
const MAX_BATCH_WRITES = 400;

function parseArgs(argv) {
  const options = {
    apply: false,
    batchSize: DEFAULT_BATCH_SIZE,
    credentials: process.env.GOOGLE_APPLICATION_CREDENTIALS || "",
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
  node scripts/migrate-photo-year-to-date.js [--apply] [--batch-size 200] [--credentials /path/to/service-account.json]

Defaults to dry-run mode. Use --apply to set date from created_at and delete year from photo documents.

Authentication:
  - Set GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
  - or pass --credentials /path/to/service-account.json
`);
}

function initialiseFirebase(credentialsPath) {
  if (credentialsPath) {
    const absolutePath = path.resolve(credentialsPath);
    const contents = fs.readFileSync(absolutePath, "utf8");
    initializeApp({
      credential: cert(JSON.parse(contents)),
    });
    return;
  }

  initializeApp({
    credential: applicationDefault(),
  });
}

function isTimestamp(value) {
  return value instanceof Timestamp || (
    value
    && typeof value === "object"
    && typeof value.toDate === "function"
    && typeof value.toMillis === "function"
  );
}

function resolvePhotoMigration(data) {
  const payload = {};
  const hasDate = isTimestamp(data.date);
  const hasYear = Object.prototype.hasOwnProperty.call(data, "year");

  if (!hasDate) {
    if (!isTimestamp(data.created_at)) {
      return { kind: "fail" };
    }
    payload.date = data.created_at;
  }

  if (hasYear) {
    payload.year = FieldValue.delete();
  }

  if (Object.keys(payload).length === 0) {
    return { kind: "skip" };
  }

  return { kind: "update", payload };
}

async function run() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    printUsage();
    return;
  }

  initialiseFirebase(options.credentials);
  const db = getFirestore();

  let scannedCount = 0;
  let updatedCount = 0;
  let skippedCount = 0;
  let failedCount = 0;
  let lastDocument = null;

  const pendingUpdates = [];

  while (true) {
    let query = db.collection("photos")
      .orderBy(FieldPath.documentId())
      .limit(options.batchSize);

    if (lastDocument) {
      query = query.startAfter(lastDocument);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    for (const document of snapshot.docs) {
      scannedCount += 1;
      const resolution = resolvePhotoMigration(document.data());

      if (resolution.kind === "skip") {
        skippedCount += 1;
        continue;
      }

      if (resolution.kind === "fail") {
        failedCount += 1;
        console.warn(`Skipped photo ${document.id} because created_at is missing or invalid.`);
        continue;
      }

      pendingUpdates.push({
        ref: document.ref,
        payload: resolution.payload,
      });
      updatedCount += 1;
    }

    lastDocument = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.docs.length < options.batchSize) {
      break;
    }
  }

  console.log(`Mode: ${options.apply ? "apply" : "dry-run"}`);
  console.log(`Scanned: ${scannedCount}`);
  console.log(`Ready to update: ${updatedCount}`);
  console.log(`Skipped: ${skippedCount}`);
  console.log(`Failed: ${failedCount}`);

  if (!options.apply || pendingUpdates.length === 0) {
    return;
  }

  for (let index = 0; index < pendingUpdates.length; index += MAX_BATCH_WRITES) {
    const batch = db.batch();
    const slice = pendingUpdates.slice(index, index + MAX_BATCH_WRITES);

    for (const update of slice) {
      batch.update(update.ref, update.payload);
    }

    await batch.commit();
  }

  console.log(`Committed updates: ${pendingUpdates.length}`);
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
