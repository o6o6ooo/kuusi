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
}
