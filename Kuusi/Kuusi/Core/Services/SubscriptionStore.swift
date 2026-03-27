import Combine
import Foundation
import StoreKit

enum SubscriptionStoreError: LocalizedError {
    case productUnavailable
    case purchasePending
    case purchaseCancelled
    case purchaseUnverified
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
        case .unknown:
            return "Purchase failed."
        }
    }
}

@MainActor
final class SubscriptionStore: ObservableObject {
    @Published private(set) var premiumProduct: Product?
    @Published private(set) var isPremiumActive = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false

    private var updatesTask: Task<Void, Never>?
    private let premiumProductID = "com.swallace.kuusi.premium.annual"

    init() {
        updatesTask = observeTransactionUpdates()

        Task {
            await prepare()
        }
    }

    deinit {
        updatesTask?.cancel()
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
    }

    var premiumPriceLabel: String? {
        premiumProduct.map { "\($0.displayPrice) / year" } ?? AppPlan.premium.priceLabel
    }

    private func refreshEntitlements() async {
        var premiumActive = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verifiedTransaction(from: result) else { continue }
            if transaction.productID == premiumProductID {
                premiumActive = true
            }
        }

        isPremiumActive = premiumActive
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                guard let transaction = try? verifiedTransaction(from: result) else { continue }
                await transaction.finish()
                await refreshEntitlements()
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
}
