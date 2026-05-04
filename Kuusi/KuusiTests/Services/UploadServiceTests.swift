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
    func temporaryStoragePathsUseUploadBatchPrefix() {
        #expect(
            UploadService.temporaryPreviewPath(
                userID: "user-1",
                uploadBatchID: "batch-1",
                photoID: "photo-1"
            ) == "photos/user-1/upload_batch-1_photo-1_preview.jpg"
        )
        #expect(
            UploadService.temporaryThumbnailPath(
                userID: "user-1",
                uploadBatchID: "batch-1",
                photoID: "photo-1"
            ) == "photos/user-1/upload_batch-1_photo-1_thumb.jpg"
        )
    }
}
