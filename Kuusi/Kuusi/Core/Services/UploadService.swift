import FirebaseFunctions
import FirebaseStorage
import Foundation
import UIKit

enum UploadServiceError: Error {
    case failedToPrepareImages
    case invalidCommitResponse
}

final class UploadService {
    private static let functionsRegion = "europe-west2"
    private static let storageRetryTimeout: TimeInterval = 30

    private let previewMaxDimension: CGFloat = 1200
    private let previewCompression: CGFloat = 0.6
    private let thumbnailMaxDimension: CGFloat = 600
    private let thumbnailCompression: CGFloat = 0.55

    private let storage: Storage = {
        let storage = Storage.storage()
        storage.maxUploadRetryTime = UploadService.storageRetryTimeout
        storage.maxOperationRetryTime = UploadService.storageRetryTimeout
        return storage
    }()
    private let functions = Functions.functions(region: UploadService.functionsRegion)

    func upload(
        images: [UIImage],
        userID: String,
        groupID: String,
        year: Int,
        hashtags: [String],
        isPremiumActive: Bool
    ) async throws -> [FeedPhoto] {
        let preparedImages = await prepareImagesForUpload(images)
        try Self.ensurePreparedImagesExist(preparedImages, originalCount: images.count)
        let uploadBatchID = UUID().uuidString

        let temporaryPhotos = try await uploadTemporaryImages(
            preparedImages,
            userID: userID,
            uploadBatchID: uploadBatchID
        )

        do {
            return try await commitUploadBatch(
                temporaryPhotos: temporaryPhotos,
                groupID: groupID,
                year: year,
                hashtags: hashtags,
                uploadBatchID: uploadBatchID,
                isPremiumActive: isPremiumActive
            )
        } catch {
            await deleteTemporaryAssets(temporaryPhotos)
            throw error
        }
    }

    func estimatedUploadSizeMB(for images: [UIImage]) async throws -> Double {
        let preparedImages = await prepareImagesForUpload(images)
        try Self.ensurePreparedImagesExist(preparedImages, originalCount: images.count)
        return preparedImages.reduce(0) { $0 + $1.sizeMB }
    }

    private func prepareImagesForUpload(_ images: [UIImage]) async -> [PreparedImage] {
        await withTaskGroup(of: (Int, PreparedImage?).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask(priority: .userInitiated) { [self] in
                    let prepared = await prepareImage(image)
                    return (index, prepared)
                }
            }

            var preparedByIndex: [Int: PreparedImage] = [:]
            for await (index, prepared) in group {
                if let prepared {
                    preparedByIndex[index] = prepared
                }
            }

            return preparedByIndex
                .sorted { $0.key < $1.key }
                .map(\.value)
        }
    }

    private func prepareImage(_ image: UIImage) async -> PreparedImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let id = UUID().uuidString

                guard
                    let previewData = self.resizedJPEGData(
                        from: image,
                        maxDimension: self.previewMaxDimension,
                        compression: self.previewCompression
                    ),
                    let thumbData = self.resizedJPEGData(
                        from: image,
                        maxDimension: self.thumbnailMaxDimension,
                        compression: self.thumbnailCompression
                    )
                else {
                    continuation.resume(returning: nil)
                    return
                }

                let sizeMB = Double(previewData.count + thumbData.count) / 1024.0 / 1024.0
                continuation.resume(returning: PreparedImage(
                    id: id,
                    previewData: previewData,
                    thumbData: thumbData,
                    aspectRatio: Self.aspectRatio(for: image.size),
                    sizeMB: sizeMB
                ))
            }
        }
    }

    private func uploadTemporaryImages(
        _ preparedImages: [PreparedImage],
        userID: String,
        uploadBatchID: String
    ) async throws -> [TemporaryUploadedPhoto] {
        var uploadedPhotos: [TemporaryUploadedPhoto] = []
        uploadedPhotos.reserveCapacity(preparedImages.count)

        do {
            for prepared in preparedImages {
                let uploaded = try await uploadTemporaryImage(
                    prepared,
                    userID: userID,
                    uploadBatchID: uploadBatchID
                )
                uploadedPhotos.append(uploaded)
            }
            return uploadedPhotos
        } catch {
            await deleteTemporaryAssets(uploadedPhotos)
            throw error
        }
    }

    private func uploadTemporaryImage(
        _ prepared: PreparedImage,
        userID: String,
        uploadBatchID: String
    ) async throws -> TemporaryUploadedPhoto {
        let previewPath = Self.temporaryPreviewPath(userID: userID, uploadBatchID: uploadBatchID, photoID: prepared.id)
        let thumbPath = Self.temporaryThumbnailPath(userID: userID, uploadBatchID: uploadBatchID, photoID: prepared.id)

        async let previewUploadTask = uploadData(prepared.previewData, at: previewPath)
        async let thumbUploadTask = uploadData(prepared.thumbData, at: thumbPath)

        do {
            _ = try await (previewUploadTask, thumbUploadTask)
            return TemporaryUploadedPhoto(
                id: prepared.id,
                previewPath: previewPath,
                thumbnailPath: thumbPath,
                aspectRatio: prepared.aspectRatio
            )
        } catch {
            await deleteTemporaryAssets([
                TemporaryUploadedPhoto(
                    id: prepared.id,
                    previewPath: previewPath,
                    thumbnailPath: thumbPath,
                    aspectRatio: prepared.aspectRatio
                )
            ])
            throw error
        }
    }

    private func resizedJPEGData(from image: UIImage, maxDimension: CGFloat, compression: CGFloat) -> Data? {
        let targetSize = Self.targetSize(for: image.size, maxDimension: maxDimension)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: compression)
    }

    private func uploadData(_ data: Data, at path: String) async throws {
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
            ref.putData(data, metadata: metadata) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let metadata else {
                    continuation.resume(throwing: NSError(domain: "Storage", code: -1))
                    return
                }
                continuation.resume(returning: metadata)
            }
        }
    }

    private func commitUploadBatch(
        temporaryPhotos: [TemporaryUploadedPhoto],
        groupID: String,
        year: Int,
        hashtags: [String],
        uploadBatchID: String,
        isPremiumActive: Bool
    ) async throws -> [FeedPhoto] {
        let payload: [String: Any] = [
            "groupId": groupID,
            "year": year,
            "hashtags": hashtags,
            "uploadBatchId": uploadBatchID,
            "isPremiumActive": isPremiumActive,
            "photos": temporaryPhotos.map { $0.commitPayload() }
        ]
        let result = try await functions.httpsCallable("commitPhotoUploadBatch").call(payload)
        return try Self.feedPhotos(from: result.data)
    }

    private func deleteTemporaryAssets(_ photos: [TemporaryUploadedPhoto]) async {
        for photo in photos {
            for path in [photo.previewPath, photo.thumbnailPath] {
                try? await deleteStoragePath(path)
            }
        }
    }

    private func deleteStoragePath(_ path: String) async throws {
        let ref = storage.reference(withPath: path)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    static func targetSize(for originalSize: CGSize, maxDimension: CGFloat) -> CGSize {
        let maxSide = max(originalSize.width, originalSize.height)
        guard maxSide > 0 else { return .zero }

        let ratio = min(1.0, maxDimension / maxSide)
        return CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
    }

    static func aspectRatio(for size: CGSize) -> Double {
        max(Double(size.width / max(size.height, 1)), 0.2)
    }

    static func roundedMegabytes(_ sizeMB: Double) -> Double {
        Double(round(100 * sizeMB) / 100)
    }

    static func ensurePreparedImagesExist(_ preparedImages: [PreparedImage], originalCount: Int) throws {
        if originalCount > 0 && preparedImages.isEmpty {
            throw UploadServiceError.failedToPrepareImages
        }
    }

    static func temporaryPreviewPath(userID: String, uploadBatchID: String, photoID: String) -> String {
        "photos/\(userID)/upload_\(uploadBatchID)_\(photoID)_preview.jpg"
    }

    static func temporaryThumbnailPath(userID: String, uploadBatchID: String, photoID: String) -> String {
        "photos/\(userID)/upload_\(uploadBatchID)_\(photoID)_thumb.jpg"
    }

    nonisolated private static func feedPhotos(from data: Any) throws -> [FeedPhoto] {
        guard
            let payload = data as? [String: Any],
            let photoPayloads = payload["photos"] as? [[String: Any]]
        else {
            throw UploadServiceError.invalidCommitResponse
        }

        return try photoPayloads.map(feedPhoto(from:))
    }

    nonisolated private static func feedPhoto(from payload: [String: Any]) throws -> FeedPhoto {
        guard
            let id = payload["id"] as? String,
            let previewPath = payload["preview_storage_path"] as? String,
            let thumbnailPath = payload["thumbnail_storage_path"] as? String,
            let groupID = payload["group_id"] as? String,
            let postedBy = payload["posted_by"] as? String,
            let hashtags = payload["hashtags"] as? [String],
            let year = intValue(payload["year"]),
            let sizeMB = doubleValue(payload["size_mb"]),
            let aspectRatio = doubleValue(payload["aspect_ratio"])
        else {
            throw UploadServiceError.invalidCommitResponse
        }

        let createdAt = (payload["created_at"] as? String).flatMap(Self.dateFromISOString)
        return FeedPhoto(
            id: id,
            previewStoragePath: previewPath,
            thumbnailStoragePath: thumbnailPath,
            groupID: groupID,
            postedBy: postedBy,
            year: year,
            hashtags: hashtags,
            isFavourite: false,
            sizeMB: sizeMB,
            aspectRatio: aspectRatio,
            createdAt: createdAt
        )
    }

    nonisolated private static func dateFromISOString(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        return ISO8601DateFormatter().date(from: value)
    }

    nonisolated private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    nonisolated private static func doubleValue(_ value: Any?) -> Double? {
        if let double = value as? Double {
            return double
        }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return nil
    }
}

private struct TemporaryUploadedPhoto: Sendable {
    let id: String
    let previewPath: String
    let thumbnailPath: String
    let aspectRatio: Double

    func commitPayload() -> [String: Any] {
        [
            "id": id,
            "previewPath": previewPath,
            "thumbnailPath": thumbnailPath,
            "aspectRatio": aspectRatio
        ]
    }
}

struct PreparedImage: Sendable {
    let id: String
    let previewData: Data
    let thumbData: Data
    let aspectRatio: Double
    let sizeMB: Double
}
