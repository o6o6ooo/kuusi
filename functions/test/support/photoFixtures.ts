export const uploadUID = "user-123";
export const uploadBatchID = "batch_abc-123";

export function validUploadPhoto(overrides: Record<string, unknown> = {}) {
  return {
    id: "photo-1",
    previewPath:
      `photos/${uploadUID}/upload_${uploadBatchID}_photo-1_preview.jpg`,
    thumbnailPath:
      `photos/${uploadUID}/upload_${uploadBatchID}_photo-1_thumb.jpg`,
    aspectRatio: 1.5,
    ...overrides
  };
}
