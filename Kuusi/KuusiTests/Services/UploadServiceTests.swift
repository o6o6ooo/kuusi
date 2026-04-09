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
    func makePhotoPayloadMapsPreparedImageFields() {
        let previewURL = URL(string: "https://example.com/preview.jpg")!
        let thumbURL = URL(string: "https://example.com/thumb.jpg")!
        let prepared = PreparedImage(
            id: "photo-1",
            previewData: Data([0x01]),
            thumbData: Data([0x02]),
            aspectRatio: 1.5,
            sizeMB: 2.345
        )

        let payload = UploadService.makePhotoPayload(
            previewURL: previewURL,
            thumbURL: thumbURL,
            groupID: "group-1",
            userID: "user-1",
            year: 2025,
            hashtags: ["family", "spring"],
            prepared: prepared
        )

        #expect(payload["photo_url"] as? String == previewURL.absoluteString)
        #expect(payload["thumbnail_url"] as? String == thumbURL.absoluteString)
        #expect(payload["group_id"] as? String == "group-1")
        #expect(payload["posted_by"] as? String == "user-1")
        #expect(payload["year"] as? Int == 2025)
        #expect(payload["hashtags"] as? [String] == ["family", "spring"])
        #expect(payload["aspect_ratio"] as? Double == 1.5)
        #expect(payload["size_mb"] as? Double == 2.35)
        #expect(payload["created_at"] != nil)
    }
}
