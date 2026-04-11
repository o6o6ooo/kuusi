import FirebaseFirestore
import FirebaseStorage
import Foundation
import UIKit

final class UploadService {
    private let previewMaxDimension: CGFloat = 1200
    private let previewCompression: CGFloat = 0.6
    private let thumbnailMaxDimension: CGFloat = 600
    private let thumbnailCompression: CGFloat = 0.55

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    func upload(images: [UIImage], userID: String, groupID: String, year: Int, hashtags: [String]) async throws {
        var uploadedCount = 0
        var totalUploadedMB: Double = 0
        let preparedImages = await prepareImagesForUpload(images)

        for prepared in preparedImages {
            let previewPath = "photos/\(userID)/\(prepared.id)_preview.jpg"
            let thumbPath = "photos/\(userID)/\(prepared.id)_thumb.jpg"

            let previewURL = try await uploadData(prepared.previewData, at: previewPath)
            let thumbURL = try await uploadData(prepared.thumbData, at: thumbPath)

            totalUploadedMB += prepared.sizeMB
            uploadedCount += 1

            let payload = Self.makePhotoPayload(
                previewURL: previewURL,
                thumbURL: thumbURL,
                groupID: groupID,
                userID: userID,
                year: year,
                hashtags: hashtags,
                prepared: prepared
            )

            try await addPhotoDocument(payload)
        }

        if uploadedCount > 0 {
            try await updateUserUsage(uid: userID, totalMB: totalUploadedMB)
        }
    }

    private func prepareImagesForUpload(_ images: [UIImage]) async -> [PreparedImage] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let prepared: [PreparedImage] = images.compactMap { image in
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
                        return nil
                    }

                    let sizeMB = Double(previewData.count + thumbData.count) / 1024.0 / 1024.0
                    return PreparedImage(
                        id: id,
                        previewData: previewData,
                        thumbData: thumbData,
                        aspectRatio: Self.aspectRatio(for: image.size),
                        sizeMB: sizeMB
                    )
                }

                continuation.resume(returning: prepared)
            }
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

    private func uploadData(_ data: Data, at path: String) async throws -> URL {
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

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            ref.downloadURL { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(throwing: NSError(domain: "Storage", code: -2))
                    return
                }
                continuation.resume(returning: url)
            }
        }
    }

    private func addPhotoDocument(_ data: [String: Any]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.collection("photos").addDocument(data: data) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    private func updateUserUsage(uid: String, totalMB: Double) async throws {
        let ref = db.collection("users").document(uid)
        let payload: [String: Any] = [
            "usage_mb": FieldValue.increment(totalMB)
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setData(payload, merge: true) { error in
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

    static func makePhotoPayload(
        previewURL: URL,
        thumbURL: URL,
        groupID: String,
        userID: String,
        year: Int,
        hashtags: [String],
        prepared: PreparedImage
    ) -> [String: Any] {
        [
            "photo_url": previewURL.absoluteString,
            "thumbnail_url": thumbURL.absoluteString,
            "group_id": groupID,
            "posted_by": userID,
            "year": year,
            "hashtags": hashtags,
            "aspect_ratio": prepared.aspectRatio,
            "size_mb": roundedMegabytes(prepared.sizeMB),
            "created_at": FieldValue.serverTimestamp()
        ]
    }
}

struct PreparedImage {
    let id: String
    let previewData: Data
    let thumbData: Data
    let aspectRatio: Double
    let sizeMB: Double
}
