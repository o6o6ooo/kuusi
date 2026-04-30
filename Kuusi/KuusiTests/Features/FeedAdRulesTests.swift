import AppTrackingTransparency
import SwiftUI
import Testing
@testable import Kuusi

struct FeedAdRulesTests {
    @Test
    func freeUsersShowFeedAdsButPremiumUsersDoNot() {
        #expect(FeedAdRules.shouldShowFeedAds(isPremiumActive: false) == true)
        #expect(FeedAdRules.shouldShowFeedAds(isPremiumActive: true) == false)
    }

    @Test
    func canLoadFeedAdsRequiresFreePlanAndConsent() {
        #expect(FeedAdRules.canLoadFeedAds(isPremiumActive: false, canRequestAds: true) == true)
        #expect(FeedAdRules.canLoadFeedAds(isPremiumActive: false, canRequestAds: false) == false)
        #expect(FeedAdRules.canLoadFeedAds(isPremiumActive: true, canRequestAds: true) == false)
    }

    @Test
    func shouldRequestTrackingAuthorizationOnlyForFreeUsersInActiveScene() {
        #expect(
            FeedAdRules.shouldRequestTrackingAuthorization(
                isPremiumActive: false,
                scenePhase: .active,
                trackingAuthorizationStatus: .notDetermined,
                hasStartedTrackingAuthorizationRequest: false
            ) == true
        )
        #expect(
            FeedAdRules.shouldRequestTrackingAuthorization(
                isPremiumActive: true,
                scenePhase: .active,
                trackingAuthorizationStatus: .notDetermined,
                hasStartedTrackingAuthorizationRequest: false
            ) == false
        )
        #expect(
            FeedAdRules.shouldRequestTrackingAuthorization(
                isPremiumActive: false,
                scenePhase: .background,
                trackingAuthorizationStatus: .notDetermined,
                hasStartedTrackingAuthorizationRequest: false
            ) == false
        )
        #expect(
            FeedAdRules.shouldRequestTrackingAuthorization(
                isPremiumActive: false,
                scenePhase: .active,
                trackingAuthorizationStatus: .authorized,
                hasStartedTrackingAuthorizationRequest: false
            ) == false
        )
        #expect(
            FeedAdRules.shouldRequestTrackingAuthorization(
                isPremiumActive: false,
                scenePhase: .active,
                trackingAuthorizationStatus: .notDetermined,
                hasStartedTrackingAuthorizationRequest: true
            ) == false
        )
    }

    @Test
    func shouldGatherConsentOnlyForFreeUsersInActiveScene() {
        #expect(FeedAdRules.shouldGatherConsent(isPremiumActive: false, scenePhase: .active) == true)
        #expect(FeedAdRules.shouldGatherConsent(isPremiumActive: true, scenePhase: .active) == false)
        #expect(FeedAdRules.shouldGatherConsent(isPremiumActive: false, scenePhase: .inactive) == false)
    }
}
