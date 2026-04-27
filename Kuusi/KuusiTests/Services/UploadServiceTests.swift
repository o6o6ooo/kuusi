import CoreGraphics
import Foundation
import Testing
@testable import Kuusi

struct UploadServiceTests {
    @Test
    func targetSizeDownscalesLandscapeImage() {
        let result = UploadService.targetSize(for: CGSize(width: 2400, height: 1200), maxDimension: 1200)

        #expect(result.width == 1200)
        #expect(result.height == 600)
    }

    @Test
    func targetSizeKeepsSmallerImageSize() {
        let result = UploadService.targetSize(for: CGSize(width: 800, height: 400), maxDimension: 1200)

        #expect(result.width == 800)
        #expect(result.height == 400)
    }

    @Test
    func aspectRatioFloorsVeryTallImageAtPointTwo() {
        let result = UploadService.aspectRatio(for: CGSize(width: 10, height: 500))

        #expect(result == 0.2)
    }

    @Test
    func roundedMegabytesRoundsToTwoDecimals() {
        let result = UploadService.roundedMegabytes(1.236)

        #expect(result == 1.24)
    }

    @Test
    func ensurePreparedImagesExistThrowsWhenAllImagesFailPreparation() {
        #expect(throws: UploadServiceError.failedToPrepareImages) {
            try UploadService.ensurePreparedImagesExist([], originalCount: 2)
        }
    }

    @Test
    func ensurePreparedImagesExistAllowsEmptyInputSelection() throws {
        try UploadService.ensurePreparedImagesExist([], originalCount: 0)
    }

    @Test
    func makePhotoPayloadMapsPreparedImageFields() {
        let prepared = PreparedImage(
            id: "photo-1",
            previewData: Data([0x01]),
            thumbData: Data([0x02]),
            aspectRatio: 1.5,
            sizeMB: 2.345
        )

        let payload = UploadService.makePhotoPayload(
            previewPath: "photos/user-1/photo-1_preview.jpg",
            thumbPath: "photos/user-1/photo-1_thumb.jpg",
            groupID: "group-1",
            userID: "user-1",
            year: 2025,
            hashtags: ["family", "spring"],
            prepared: prepared
        )

        #expect(payload["preview_storage_path"] as? String == "photos/user-1/photo-1_preview.jpg")
        #expect(payload["thumbnail_storage_path"] as? String == "photos/user-1/photo-1_thumb.jpg")
        #expect(payload["group_id"] as? String == "group-1")
        #expect(payload["posted_by"] as? String == "user-1")
        #expect(payload["year"] as? Int == 2025)
        #expect(payload["hashtags"] as? [String] == ["family", "spring"])
        #expect(payload["aspect_ratio"] as? Double == 1.5)
        #expect(payload["size_mb"] as? Double == 2.35)
        #expect(payload["created_at"] != nil)
    }
}
