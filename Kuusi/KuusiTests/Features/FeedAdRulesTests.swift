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
		#expect(
			FeedAdRules.canLoadFeedAds(isPremiumActive: false, canRequestAds: true)
				== true
		)
		#expect(
			FeedAdRules.canLoadFeedAds(isPremiumActive: false, canRequestAds: false)
				== false
		)
		#expect(
			FeedAdRules.canLoadFeedAds(isPremiumActive: true, canRequestAds: true)
				== false
		)
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
		#expect(
			FeedAdRules.shouldGatherConsent(
				isPremiumActive: false,
				scenePhase: .active
			) == true
		)
		#expect(
			FeedAdRules.shouldGatherConsent(
				isPremiumActive: true,
				scenePhase: .active
			) == false
		)
		#expect(
			FeedAdRules.shouldGatherConsent(
				isPremiumActive: false,
				scenePhase: .inactive
			) == false
		)
	}

	@Test
	func inlineAdsStartAfterConfiguredPhotoIndexAndRepeatByInterval() {
		#expect(
			PhotoGridInlineAdRules.shouldShowInlineAd(
				afterPhotoAt: 7,
				photoID: "photo-7",
				showsInlineAds: true,
				hiddenInlineAdPhotoIDs: []
			) == false
		)
		#expect(
			PhotoGridInlineAdRules.shouldShowInlineAd(
				afterPhotoAt: 8,
				photoID: "photo-8",
				showsInlineAds: true,
				hiddenInlineAdPhotoIDs: []
			) == true
		)
		#expect(
			PhotoGridInlineAdRules.shouldShowInlineAd(
				afterPhotoAt: 19,
				photoID: "photo-19",
				showsInlineAds: true,
				hiddenInlineAdPhotoIDs: []
			) == false
		)
		#expect(
			PhotoGridInlineAdRules.shouldShowInlineAd(
				afterPhotoAt: 20,
				photoID: "photo-20",
				showsInlineAds: true,
				hiddenInlineAdPhotoIDs: []
			) == true
		)
	}

	@Test
	func inlineAdsRespectHiddenFailedAds() {
		#expect(
			PhotoGridInlineAdRules.shouldShowInlineAd(
				afterPhotoAt: 8,
				photoID: "photo-8",
				showsInlineAds: true,
				hiddenInlineAdPhotoIDs: ["photo-8"]
			) == false
		)
	}

	@Test
	func inlineAdsFollowFeedAdLoadingEligibility() {
		let freeWithConsent = FeedAdRules.canLoadFeedAds(
			isPremiumActive: false,
			canRequestAds: true
		)
		let freeWithoutConsent = FeedAdRules.canLoadFeedAds(
			isPremiumActive: false,
			canRequestAds: false
		)
		let premiumWithConsent = FeedAdRules.canLoadFeedAds(
			isPremiumActive: true,
			canRequestAds: true
		)

		#expect(
			PhotoGridInlineAdRules.shouldShowInlineAd(
				afterPhotoAt: 8,
				photoID: "photo-8",
				showsInlineAds: freeWithConsent,
				hiddenInlineAdPhotoIDs: []
			) == true
		)
		#expect(
			PhotoGridInlineAdRules.shouldShowInlineAd(
				afterPhotoAt: 8,
				photoID: "photo-8",
				showsInlineAds: freeWithoutConsent,
				hiddenInlineAdPhotoIDs: []
			) == false
		)
		#expect(
			PhotoGridInlineAdRules.shouldShowInlineAd(
				afterPhotoAt: 8,
				photoID: "photo-8",
				showsInlineAds: premiumWithConsent,
				hiddenInlineAdPhotoIDs: []
			) == false
		)
	}
}
