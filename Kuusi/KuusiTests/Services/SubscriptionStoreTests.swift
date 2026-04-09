import Foundation
import Testing
@testable import Kuusi

struct SubscriptionStoreTests {
    @Test
    func productUnavailableErrorHasExpectedMessage() {
        #expect(
            SubscriptionStoreError.productUnavailable.errorDescription
            == "Premium subscription is not available right now."
        )
    }

    @Test
    func purchaseCancelledErrorHasExpectedMessage() {
        #expect(
            SubscriptionStoreError.purchaseCancelled.errorDescription
            == "Purchase was cancelled."
        )
    }

    @Test
    func premiumPriceLabelUsesDisplayPriceWhenAvailable() {
        let label = SubscriptionStore.makePremiumPriceLabel(displayPrice: "$19.99")

        #expect(label == "$19.99 / year")
    }

    @Test
    func premiumPriceLabelFallsBackToPlanLabel() {
        let label = SubscriptionStore.makePremiumPriceLabel(displayPrice: nil)

        #expect(label == AppPlan.premium.priceLabel)
    }

    @Test
    func entitlementSnapshotDisablesAutoRenewWhenPremiumIsInactive() {
        let snapshot = SubscriptionStore.makeEntitlementSnapshot(
            premiumActive: false,
            renewalDate: Date(timeIntervalSince1970: 100),
            autoRenew: true
        )

        #expect(snapshot.isPremiumActive == false)
        #expect(snapshot.willAutoRenew == false)
        #expect(snapshot.renewalDate == Date(timeIntervalSince1970: 100))
    }

    @Test
    func entitlementSnapshotKeepsAutoRenewWhenPremiumIsActive() {
        let snapshot = SubscriptionStore.makeEntitlementSnapshot(
            premiumActive: true,
            renewalDate: Date(timeIntervalSince1970: 100),
            autoRenew: true
        )

        #expect(snapshot.isPremiumActive == true)
        #expect(snapshot.willAutoRenew == true)
    }
}
