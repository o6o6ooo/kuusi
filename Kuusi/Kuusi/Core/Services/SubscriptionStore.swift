import Combine
import FirebaseFunctions
import Foundation
import StoreKit
import UIKit

enum SubscriptionStoreError: LocalizedError {
    case productUnavailable
    case purchasePending
    case purchaseCancelled
    case purchaseUnverified
    case manageSubscriptionsUnavailable
    case subscriptionSyncFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "Premium subscription is not available right now."
        case .purchasePending:
            return "Purchase is pending approval."
        case .purchaseCancelled:
            return "Purchase was cancelled."
        case .purchaseUnverified:
            return "Purchase could not be verified."
        case .manageSubscriptionsUnavailable:
            return "Subscriptions can be managed from your Apple account settings."
        case .subscriptionSyncFailed:
            return "Premium subscription could not be synced."
        case .unknown:
            return "Purchase failed."
        }
    }
}

@MainActor
final class SubscriptionStore: ObservableObject {
    @Published private(set) var premiumProduct: Product?
    @Published private(set) var isPremiumActive = false
    @Published private(set) var renewalDate: Date?
    @Published private(set) var willAutoRenew = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false

    private var updatesTask: Task<Void, Never>?
    private var subscriptionStatusUpdatesTask: Task<Void, Never>?
    private static let functionsRegion = "europe-west2"
    private let premiumProductID = "com.swallace.kuusi.premium.annual"
    private let functions = Functions.functions(region: SubscriptionStore.functionsRegion)
    nonisolated private static let premiumFallbackPriceLabel = "£24.99 / year"

    struct EntitlementSnapshot: Equatable {
        let isPremiumActive: Bool
        let renewalDate: Date?
        let willAutoRenew: Bool
    }

    init() {
        updatesTask = observeTransactionUpdates()
        subscriptionStatusUpdatesTask = observeSubscriptionStatusUpdates()

        Task {
            await prepare()
        }
    }

    deinit {
        updatesTask?.cancel()
        subscriptionStatusUpdatesTask?.cancel()
    }

    func prepare() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: [premiumProductID])
            premiumProduct = products.first(where: { $0.id == premiumProductID })
        } catch {
            premiumProduct = nil
        }
    }

    func purchasePremium() async throws {
        guard !isPurchasing else { return }
        if premiumProduct == nil {
            await loadProducts()
        }
        guard let premiumProduct else {
            throw SubscriptionStoreError.productUnavailable
        }

        isPurchasing = true
        defer { isPurchasing = false }

        let result: Product.PurchaseResult
        do {
            result = try await premiumProduct.purchase()
        } catch {
            throw error
        }

        switch result {
        case let .success(verification):
            let transaction = try verifiedTransaction(from: verification)
            await transaction.finish()
            await refreshEntitlements()
            try await syncSubscription()
        case .pending:
            throw SubscriptionStoreError.purchasePending
        case .userCancelled:
            throw SubscriptionStoreError.purchaseCancelled
        @unknown default:
            throw SubscriptionStoreError.unknown
        }
    }

    func restorePurchases() async throws {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        try await AppStore.sync()
        await refreshEntitlements()
        try await syncSubscription()
    }

    func syncSubscription() async throws {
        let signedTransactionInfo = try await currentPremiumTransactionJWS()
        if isPremiumActive && signedTransactionInfo == nil {
            throw SubscriptionStoreError.subscriptionSyncFailed
        }

        var payload: [String: Any] = [:]
        if let signedTransactionInfo {
            payload["signedTransactionInfo"] = signedTransactionInfo
        }
        if let signedRenewalInfo = try? await currentPremiumRenewalInfoJWS() {
            payload["signedRenewalInfo"] = signedRenewalInfo
        }

        do {
            let result = try await functions.httpsCallable("syncSubscription").call(payload)
            if isPremiumActive {
                let response = result.data as? [String: Any]
                guard response?["isPremiumActive"] as? Bool == true else {
                    throw SubscriptionStoreError.subscriptionSyncFailed
                }
            }
        } catch {
            throw SubscriptionStoreError.subscriptionSyncFailed
        }
    }

    func openManageSubscriptions() async throws {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            throw SubscriptionStoreError.manageSubscriptionsUnavailable
        }

        try await AppStore.showManageSubscriptions(in: windowScene)
        await refreshEntitlements()
        try? await syncSubscription()
    }

    var premiumPriceLabel: String? {
        Self.makePremiumPriceLabel(displayPrice: premiumProduct?.displayPrice)
    }

    var entitlementSnapshot: EntitlementSnapshot {
        Self.makeEntitlementSnapshot(
            premiumActive: isPremiumActive,
            renewalDate: renewalDate,
            autoRenew: willAutoRenew
        )
    }

    private func refreshEntitlements() async {
        var premiumActive = false
        var nextRenewalDate: Date?
        var autoRenew = false

        if let subscription = premiumProduct?.subscription {
            do {
                let statuses = try await subscription.status
                for status in statuses {
                    let transaction = try? verifiedTransaction(from: status.transaction)
                    let renewalInfo = try? verifiedTransaction(from: status.renewalInfo)
                    guard let transaction, transaction.productID == premiumProductID else { continue }

                    switch status.state {
                    case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
                        premiumActive = true
                        nextRenewalDate = transaction.expirationDate
                        autoRenew = renewalInfo?.willAutoRenew ?? false
                    case .expired, .revoked:
                        if nextRenewalDate == nil {
                            nextRenewalDate = transaction.expirationDate
                        }
                    default:
                        break
                    }
                }
            } catch {
                // Keep current-entitlements fallback below.
            }
        }

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verifiedTransaction(from: result) else { continue }
            if transaction.productID == premiumProductID {
                premiumActive = true
                nextRenewalDate = transaction.expirationDate ?? nextRenewalDate
            }
        }

        isPremiumActive = premiumActive
        renewalDate = nextRenewalDate
        willAutoRenew = premiumActive && autoRenew
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                guard let transaction = try? verifiedTransaction(from: result) else { continue }
                await transaction.finish()
                await refreshEntitlements()
                try? await syncSubscription()
            }
        }
    }

    private func observeSubscriptionStatusUpdates() -> Task<Void, Never> {
        Task {
            for await _ in Product.SubscriptionInfo.Status.updates {
                await refreshEntitlements()
                try? await syncSubscription()
            }
        }
    }

    private func verifiedTransaction<T>(from result: VerificationResult<T>) throws -> T {
        switch result {
        case let .verified(safe):
            return safe
        case .unverified:
            throw SubscriptionStoreError.purchaseUnverified
        }
    }

    private func currentPremiumTransactionJWS() async throws -> String? {
        for await result in Transaction.currentEntitlements {
            let transaction = try verifiedTransaction(from: result)
            guard transaction.productID == premiumProductID else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
                continue
            }
            return result.jwsRepresentation
        }

        return nil
    }

    private func currentPremiumRenewalInfoJWS() async throws -> String? {
        guard let subscription = premiumProduct?.subscription else {
            return nil
        }

        let statuses = try await subscription.status
        for status in statuses {
            let transaction = try? verifiedTransaction(from: status.transaction)
            guard transaction?.productID == premiumProductID else { continue }
            return status.renewalInfo.jwsRepresentation
        }

        return nil
    }

    nonisolated static func makePremiumPriceLabel(displayPrice: String?) -> String? {
        if let displayPrice {
            return "\(displayPrice) / year"
        }
        return premiumFallbackPriceLabel
    }

    nonisolated static func makeEntitlementSnapshot(
        premiumActive: Bool,
        renewalDate: Date?,
        autoRenew: Bool
    ) -> EntitlementSnapshot {
        EntitlementSnapshot(
            isPremiumActive: premiumActive,
            renewalDate: renewalDate,
            willAutoRenew: premiumActive && autoRenew
        )
    }
}
