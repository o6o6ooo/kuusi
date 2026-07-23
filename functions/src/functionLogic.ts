import {HttpsError} from "firebase-functions/v2/https";

export type NormalizedUploadPhoto = {
  aspectRatio: number;
  id: string;
  previewPath: string;
  thumbnailPath: string;
};

export function normalizeText(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ?
    value.trim() :
    null;
}

export function normalizeUploadBatchId(value: unknown): string | null {
  const text = normalizeText(value);
  return text && /^[A-Za-z0-9_-]{1,128}$/.test(text) ? text : null;
}

export function normalizeHashtags(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  const hashtags = value
    .map((item) => normalizeText(item))
    .filter((item): item is string => item !== null)
    .map((item) => item.replace(/^#/, "").trim())
    .filter((item) => item.length > 0 && item.length <= 40);

  return Array.from(new Set(hashtags)).slice(0, 30);
}

export function normalizeCaption(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const normalized = value.split(/\s+/u).filter(Boolean).join(" ").trim();
  if (normalized.length === 0) {
    return null;
  }

  return Array.from(normalized).slice(0, 140).join("");
}

export function normalizeUploadPhoto(
  value: unknown,
  uid: string,
  uploadBatchId: string
): NormalizedUploadPhoto {
  if (!value || typeof value !== "object") {
    throw new HttpsError("invalid-argument", "Each photo must be an object");
  }

  const data = value as Record<string, unknown>;
  const id = normalizeUploadBatchId(data.id);
  const previewPath = normalizeText(data.previewPath);
  const thumbnailPath = normalizeText(data.thumbnailPath);
  const aspectRatio = numericValue(data.aspectRatio);
  const expectedPrefix = `photos/${uid}/upload_${uploadBatchId}_`;

  if (!id || !previewPath || !thumbnailPath || aspectRatio === null) {
    throw new HttpsError(
      "invalid-argument",
      "Each photo requires id, paths, and aspectRatio"
    );
  }

  if (!Number.isFinite(aspectRatio) || aspectRatio < 0.2 || aspectRatio > 10) {
    throw new HttpsError("invalid-argument", "aspectRatio is invalid");
  }

  if (
    !previewPath.startsWith(expectedPrefix) ||
    !previewPath.endsWith("_preview.jpg") ||
    !thumbnailPath.startsWith(expectedPrefix) ||
    !thumbnailPath.endsWith("_thumb.jpg")
  ) {
    throw new HttpsError("permission-denied", "Upload paths are invalid");
  }

  return {
    aspectRatio,
    id,
    previewPath,
    thumbnailPath
  };
}

export function normalizeBatchCount(value: unknown): number {
  return typeof value === "number" && Number.isInteger(value) && value > 0 ?
    value :
    1;
}

export function numericValue(value: unknown): number | null {
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }

  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }

  return null;
}

export function optionalNumber(value: unknown): number | undefined {
  const parsed = numericValue(value);
  return parsed !== null && Number.isInteger(parsed) && parsed > 0 ?
    parsed :
    undefined;
}

export function normalizeEmail(value: unknown): string | null {
  const text = normalizeText(value);
  return text && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(text) ? text : null;
}

export function roundMegabytes(sizeMB: number): number {
  return Math.round(sizeMB * 100) / 100;
}

export function buildUsageMap(
  photos: Array<{posted_by?: string; size_mb?: number}>
): Record<string, number> {
  const usageByUserID: Record<string, number> = {};

  for (const photo of photos) {
    if (
      !photo.posted_by ||
      typeof photo.size_mb !== "number" ||
      photo.size_mb <= 0
    ) {
      continue;
    }
    usageByUserID[photo.posted_by] =
      (usageByUserID[photo.posted_by] ?? 0) + photo.size_mb;
  }

  return usageByUserID;
}

export function emailLogId(
  uid: string,
  type: string,
  dedupeKey: string
): string {
  return [uid, type, dedupeKey]
    .join("_")
    .replace(/[^A-Za-z0-9_-]/g, "_")
    .slice(0, 140);
}

export function errorMessage(error: unknown): string {
  return error instanceof Error && error.message.length > 0 ?
    error.message :
    "unknown_error";
}

export function isObjectNotFoundError(error: unknown): boolean {
  if (!(error instanceof Error)) {
    return false;
  }

  const maybeCode = error as Error & {code?: number | string};
  return maybeCode.code === 404 ||
    maybeCode.code === "storage/object-not-found";
}

export function isAlreadyExistsError(error: unknown): boolean {
  if (!(error instanceof Error)) {
    return false;
  }

  const maybeCode = error as Error & {code?: number | string};
  return maybeCode.code === 6 ||
    maybeCode.code === "already-exists" ||
    maybeCode.code === "firestore/already-exists";
}

export function chunked<T>(items: T[], size: number): T[][] {
  if (size <= 0) {
    return [items];
  }

  const chunks: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }
  return chunks;
}
