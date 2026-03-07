import FirebaseFirestore
import FirebaseStorage
import Foundation
import UIKit

final class UploadService {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    func upload(images: [UIImage], userID: String) async throws {
        var uploadedCount = 0
        var totalUploadedMB: Double = 0

        for image in images {
            let id = UUID().uuidString

            guard
                let previewData = resizedJPEGData(from: image, maxDimension: 1200, compression: 0.6),
                let thumbData = resizedJPEGData(from: image, maxDimension: 180, compression: 0.45)
            else {
                continue
            }

            let previewPath = "photos/\(userID)/\(id)_preview.jpg"
            let thumbPath = "photos/\(userID)/\(id)_thumb.jpg"

            let previewURL = try await uploadData(previewData, at: previewPath)
            let thumbURL = try await uploadData(thumbData, at: thumbPath)

            let sizeMB = Double(previewData.count + thumbData.count) / 1024.0 / 1024.0
            totalUploadedMB += sizeMB
            uploadedCount += 1

            let currentYear = Calendar.current.component(.year, from: Date())
            let payload: [String: Any] = [
                "photo_url": previewURL.absoluteString,
                "thumbnail_url": thumbURL.absoluteString,
                "group_id": "default",
                "posted_by": userID,
                "year": currentYear,
                "hashtags": [],
                "size_mb": Double(round(100 * sizeMB) / 100),
                "created_at": FieldValue.serverTimestamp()
            ]

            try await addPhotoDocument(payload)
        }

        if uploadedCount > 0 {
            try await updateUserCounters(uid: userID, count: uploadedCount, totalMB: totalUploadedMB)
        }
    }

    private func resizedJPEGData(from image: UIImage, maxDimension: CGFloat, compression: CGFloat) -> Data? {
        let originalSize = image.size
        let maxSide = max(originalSize.width, originalSize.height)
        let ratio = min(1.0, maxDimension / maxSide)
        let targetSize = CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
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

    private func updateUserCounters(uid: String, count: Int, totalMB: Double) async throws {
        let ref = db.collection("users").document(uid)
        let payload: [String: Any] = [
            "upload_count": FieldValue.increment(Int64(count)),
            "upload_total_mb": FieldValue.increment(totalMB),
            "updatedAt": FieldValue.serverTimestamp()
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
}
