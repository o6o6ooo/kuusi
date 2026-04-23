import Testing
@testable import Kuusi

struct UploadOverlayViewTests {
    @Test
    func parseYearTrimsWhitespaceAndParsesNumber() {
        #expect(UploadOverlayRules.parseYear(from: " 2025 ") == 2025)
    }

    @Test
    func parseYearRejectsEmptyText() {
        #expect(UploadOverlayRules.parseYear(from: "   ") == nil)
    }

    @Test
    func parseYearRejectsNonNumericText() {
        #expect(UploadOverlayRules.parseYear(from: "year") == nil)
    }

    @Test
    func canUploadRequiresSelectedImagesAndValidInputs() {
        #expect(
            UploadOverlayRules.canUpload(
                selectedImageCount: 2,
                isUploading: false,
                isImportingGooglePhotos: false,
                isEstimatingUploadSize: false,
                selectedGroupID: "group-1",
                yearText: "2025",
                effectiveUsageMB: 100,
                estimatedUploadSizeMB: 20,
                isPremiumActive: false
            ) == true
        )
    }

    @Test
    func canUploadRejectsMissingGroupOrYear() {
        #expect(
            UploadOverlayRules.canUpload(
                selectedImageCount: 1,
                isUploading: false,
                isImportingGooglePhotos: false,
                isEstimatingUploadSize: false,
                selectedGroupID: nil,
                yearText: "2025",
                effectiveUsageMB: 100,
                estimatedUploadSizeMB: 20,
                isPremiumActive: false
            ) == false
        )
        #expect(
            UploadOverlayRules.canUpload(
                selectedImageCount: 1,
                isUploading: false,
                isImportingGooglePhotos: false,
                isEstimatingUploadSize: false,
                selectedGroupID: "group-1",
                yearText: "",
                effectiveUsageMB: 100,
                estimatedUploadSizeMB: 20,
                isPremiumActive: false
            ) == false
        )
    }

    @Test
    func canUploadRejectsBusyStates() {
        #expect(
            UploadOverlayRules.canUpload(
                selectedImageCount: 1,
                isUploading: true,
                isImportingGooglePhotos: false,
                isEstimatingUploadSize: false,
                selectedGroupID: "group-1",
                yearText: "2025",
                effectiveUsageMB: 100,
                estimatedUploadSizeMB: 20,
                isPremiumActive: false
            ) == false
        )
        #expect(
            UploadOverlayRules.canUpload(
                selectedImageCount: 1,
                isUploading: false,
                isImportingGooglePhotos: true,
                isEstimatingUploadSize: false,
                selectedGroupID: "group-1",
                yearText: "2025",
                effectiveUsageMB: 100,
                estimatedUploadSizeMB: 20,
                isPremiumActive: false
            ) == false
        )
        #expect(
            UploadOverlayRules.canUpload(
                selectedImageCount: 1,
                isUploading: false,
                isImportingGooglePhotos: false,
                isEstimatingUploadSize: true,
                selectedGroupID: "group-1",
                yearText: "2025",
                effectiveUsageMB: 100,
                estimatedUploadSizeMB: 20,
                isPremiumActive: false
            ) == false
        )
    }

    @Test
    func canUploadRejectsStorageLimitAndProjectedOverflow() {
        #expect(
            UploadOverlayRules.canUpload(
                selectedImageCount: 1,
                isUploading: false,
                isImportingGooglePhotos: false,
                isEstimatingUploadSize: false,
                selectedGroupID: "group-1",
                yearText: "2025",
                effectiveUsageMB: 3072,
                estimatedUploadSizeMB: 1,
                isPremiumActive: false
            ) == false
        )
        #expect(
            UploadOverlayRules.canUpload(
                selectedImageCount: 1,
                isUploading: false,
                isImportingGooglePhotos: false,
                isEstimatingUploadSize: false,
                selectedGroupID: "group-1",
                yearText: "2025",
                effectiveUsageMB: 3071,
                estimatedUploadSizeMB: 2,
                isPremiumActive: false
            ) == false
        )
    }

    @Test
    func canUploadAllowsProjectedUsageWithinPremiumQuota() {
        #expect(
            UploadOverlayRules.canUpload(
                selectedImageCount: 1,
                isUploading: false,
                isImportingGooglePhotos: false,
                isEstimatingUploadSize: false,
                selectedGroupID: "group-1",
                yearText: "2025",
                effectiveUsageMB: 50000,
                estimatedUploadSizeMB: 1000,
                isPremiumActive: true
            ) == true
        )
    }

    @Test
    func uploadValidationMessagePrioritizesStorageLimitThenSignInThenGroupThenYear() {
        #expect(
            UploadOverlayRules.uploadValidationMessageID(
                currentUserID: "user-1",
                selectedGroupID: "group-1",
                yearText: "2025",
                effectiveUsageMB: 3072,
                estimatedUploadSizeMB: 0,
                isPremiumActive: false
            ) == .storageLimitReached
        )
        #expect(
            UploadOverlayRules.uploadValidationMessageID(
                currentUserID: nil,
                selectedGroupID: "group-1",
                yearText: "2025",
                effectiveUsageMB: 100,
                estimatedUploadSizeMB: 0,
                isPremiumActive: false
            ) == .pleaseSignInFirst
        )
        #expect(
            UploadOverlayRules.uploadValidationMessageID(
                currentUserID: "user-1",
                selectedGroupID: nil,
                yearText: "2025",
                effectiveUsageMB: 100,
                estimatedUploadSizeMB: 0,
                isPremiumActive: false
            ) == .selectGroup
        )
        #expect(
            UploadOverlayRules.uploadValidationMessageID(
                currentUserID: "user-1",
                selectedGroupID: "group-1",
                yearText: "",
                effectiveUsageMB: 100,
                estimatedUploadSizeMB: 0,
                isPremiumActive: false
            ) == .enterValidYear
        )
    }

    @Test
    func uploadValidationMessageReturnsStorageLimitReachedForProjectedOverflow() {
        #expect(
            UploadOverlayRules.uploadValidationMessageID(
                currentUserID: "user-1",
                selectedGroupID: "group-1",
                yearText: "2025",
                effectiveUsageMB: 3071,
                estimatedUploadSizeMB: 2,
                isPremiumActive: false
            ) == .storageLimitReached
        )
    }

    @Test
    func uploadValidationMessageReturnsNilWhenUploadCanProceed() {
        #expect(
            UploadOverlayRules.uploadValidationMessageID(
                currentUserID: "user-1",
                selectedGroupID: "group-1",
                yearText: "2025",
                effectiveUsageMB: 100,
                estimatedUploadSizeMB: 20,
                isPremiumActive: false
            ) == nil
        )
    }

    @Test
    func normalizedHashtagsSplitsTrimsLowercasesAndDropsHashes() {
        let result = UploadOverlayRules.normalizedHashtags(from: " #Tokyo, london\nFamily  ")

        #expect(result == ["tokyo", "london", "family"])
    }

    @Test
    func normalizedHashtagsSupportsTabsAndRepeatedSeparators() {
        let result = UploadOverlayRules.normalizedHashtags(from: "\t#Kids,,  TRIP\n\n#Spring ")

        #expect(result == ["kids", "trip", "spring"])
    }
}
