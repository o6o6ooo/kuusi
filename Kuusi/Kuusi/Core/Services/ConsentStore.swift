import Combine
import Foundation
import UIKit
import UserMessagingPlatform

enum ConsentStoreRules {
    static func shouldStartGatheringConsent(
        isGatheringConsent: Bool,
        hasGatheredConsentThisSession: Bool
    ) -> Bool {
        !isGatheringConsent && !hasGatheredConsentThisSession
    }
}

@MainActor
final class ConsentStore: ObservableObject {
    @Published private(set) var canRequestAds = ConsentInformation.shared.canRequestAds
    @Published private(set) var isPrivacyOptionsRequired = (
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    )

    private let usesUITestFixture: Bool
    private var isGatheringConsent = false
    private var hasGatheredConsentThisSession = false

    init() {
        usesUITestFixture = false
    }

#if DEBUG
    struct UITestFixture {
        let canRequestAds: Bool
        let isPrivacyOptionsRequired: Bool
    }

    init(uiTestFixture: UITestFixture) {
        usesUITestFixture = true
        canRequestAds = uiTestFixture.canRequestAds
        isPrivacyOptionsRequired = uiTestFixture.isPrivacyOptionsRequired
    }
#endif

    func gatherConsentIfNeeded() async {
        guard !usesUITestFixture else { return }
        guard ConsentStoreRules.shouldStartGatheringConsent(
            isGatheringConsent: isGatheringConsent,
            hasGatheredConsentThisSession: hasGatheredConsentThisSession
        ) else {
            refreshState()
            return
        }

        isGatheringConsent = true
        defer { isGatheringConsent = false }

        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false

        do {
            try await requestConsentInfoUpdate(with: parameters)
            hasGatheredConsentThisSession = true
            try await loadAndPresentConsentFormIfRequired()
        } catch {
            hasGatheredConsentThisSession = true
        }

        refreshState()
    }

    func presentPrivacyOptions() async throws {
        guard !usesUITestFixture else { return }
        try await presentPrivacyOptionsForm()
        refreshState()
    }

    private func refreshState() {
        canRequestAds = ConsentInformation.shared.canRequestAds
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private func requestConsentInfoUpdate(with parameters: RequestParameters) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func loadAndPresentConsentFormIfRequired() async throws {
        try await ConsentForm.loadAndPresentIfRequired(from: UIApplication.topViewController())
    }

    private func presentPrivacyOptionsForm() async throws {
        try await ConsentForm.presentPrivacyOptionsForm(from: UIApplication.topViewController())
    }
}
