import {
  adminFirestore,
  adminStorage,
  waitForDocument
} from "./firebase";

export type PhotoFixture = {
  id: string;
  previewPath: string;
  thumbnailPath: string;
};

export async function createPhotoFixture(
  groupID: string,
  uploaderUID: string,
  id = "photo-1",
  sizeMB = 2.5
): Promise<PhotoFixture> {
  const previewPath = `photos/${uploaderUID}/${id}_preview.jpg`;
  const thumbnailPath = `photos/${uploaderUID}/${id}_thumb.jpg`;
  const firestore = adminFirestore();
  const bucket = adminStorage().bucket();

  await Promise.all([
    firestore.collection("photos").doc(id).set({
      group_id: groupID,
      posted_by: uploaderUID,
      preview_storage_path: previewPath,
      thumbnail_storage_path: thumbnailPath,
      size_mb: sizeMB,
      aspect_ratio: 1.5,
      hashtags: [],
      date: new Date("2026-01-01T00:00:00Z"),
      created_at: new Date("2026-01-01T00:00:00Z")
    }),
    bucket.file(previewPath).save(Buffer.from("preview")),
    bucket.file(thumbnailPath).save(Buffer.from("thumbnail"))
  ]);
  await waitForDocument("photo_notification_batches", id);

  return {id, previewPath, thumbnailPath};
}
