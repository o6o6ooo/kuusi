import Foundation
import Testing

@testable import Kuusi

struct ConsentStoreTests {
	@Test
	func shouldStartGatheringConsentOnlyBeforeSessionFetch() {
		#expect(
			ConsentStoreRules.shouldStartGatheringConsent(
				isGatheringConsent: false,
				hasGatheredConsentThisSession: false
			) == true
		)
		#expect(
			ConsentStoreRules.shouldStartGatheringConsent(
				isGatheringConsent: true,
				hasGatheredConsentThisSession: false
			) == false
		)
		#expect(
			ConsentStoreRules.shouldStartGatheringConsent(
				isGatheringConsent: false,
				hasGatheredConsentThisSession: true
			) == false
		)
	}
}
