import Testing
@testable import Kuusi

struct AppPlanTests {
    @Test
    func freePlanMatchesExpectedProductShape() {
        #expect(AppPlan.free.quotaMB == 3072.0)
        #expect(AppPlan.free.maxGroups == 3)
        #expect(AppPlan.free.title == "Free plan")
        #expect(AppPlan.free.priceLabel == nil)
        #expect(AppPlan.free.productID == nil)
        #expect(AppPlan.free.featureLines == [
            "3GB storage",
            "Preview photos up to 2 years",
            "Have up to 3 groups"
        ])
    }

    @Test
    func premiumPlanMatchesExpectedProductShape() {
        #expect(AppPlan.premium.quotaMB == 51200.0)
        #expect(AppPlan.premium.maxGroups == 10)
        #expect(AppPlan.premium.title == "Premium plan")
        #expect(AppPlan.premium.priceLabel == "£24.99 / year")
        #expect(AppPlan.premium.productID == "com.swallace.kuusi.premium.annual")
        #expect(AppPlan.premium.featureLines == [
            "50GB storage",
            "Preview all photos",
            "Have up to 10 groups"
        ])
    }

    @Test
    func freePreviewExpiresOnSecondAnniversaryDate() {
        let calendar = Calendar(identifier: .gregorian)
        let createdAt = calendar.date(from: DateComponents(year: 2024, month: 4, day: 15, hour: 9))!
        let beforeExpiry = calendar.date(from: DateComponents(year: 2026, month: 4, day: 15, hour: 8, minute: 59))!
        let atExpiry = calendar.date(from: DateComponents(year: 2026, month: 4, day: 15, hour: 9))!

        #expect(
            PlanAccessPolicy.previewAccess(
                for: createdAt,
                isPremiumActive: false,
                now: beforeExpiry,
                calendar: calendar
            ) == .full
        )
        #expect(
            PlanAccessPolicy.previewAccess(
                for: createdAt,
                isPremiumActive: false,
                now: atExpiry,
                calendar: calendar
            ) == .thumbnailOnly
        )
    }

    @Test
    func premiumKeepsFullPreviewForOlderPhotos() {
        let calendar = Calendar(identifier: .gregorian)
        let createdAt = calendar.date(from: DateComponents(year: 2021, month: 1, day: 1))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 15))!

        #expect(
            PlanAccessPolicy.previewAccess(
                for: createdAt,
                isPremiumActive: true,
                now: now,
                calendar: calendar
            ) == .full
        )
    }

    @Test
    func storageLimitChecksMatchPlanQuota() {
        #expect(PlanAccessPolicy.isStorageLimitReached(usageMB: 3072, isPremiumActive: false) == true)
        #expect(PlanAccessPolicy.isStorageLimitReached(usageMB: 3071.99, isPremiumActive: false) == false)
        #expect(PlanAccessPolicy.canUpload(currentUsageMB: 3071, additionalUsageMB: 0.5, isPremiumActive: false) == true)
        #expect(PlanAccessPolicy.canUpload(currentUsageMB: 3071, additionalUsageMB: 1.1, isPremiumActive: false) == false)
    }
}
