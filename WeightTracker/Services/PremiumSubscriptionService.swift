import Foundation
import StoreKit
import UIKit

struct PremiumStorefrontState {
    let isUnlocked: Bool
    let displayPrice: String?
}

enum PremiumPurchaseOutcome {
    case purchased
    case cancelled
    case pending
}

enum PremiumSubscriptionError: LocalizedError {
    case productUnavailable
    case failedVerification
    case missingWindowScene

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "Premium is unavailable right now."
        case .failedVerification:
            return "The App Store could not verify this Premium purchase."
        case .missingWindowScene:
            return "Unable to open Apple subscriptions right now."
        }
    }
}

actor PremiumSubscriptionService {
    static let shared = PremiumSubscriptionService()
    static let productID = "com.befit.premium.monthly"

    private var cachedProduct: Product?

    nonisolated var transactionUpdates: Transaction.Transactions {
        Transaction.updates
    }

    func storefrontState() async -> PremiumStorefrontState {
        let isUnlocked = await hasActivePremiumEntitlement()
        let product = try? await loadProduct()
        return PremiumStorefrontState(
            isUnlocked: isUnlocked,
            displayPrice: product?.displayPrice
        )
    }

    @MainActor
    func purchasePremium() async throws -> PremiumPurchaseOutcome {
        guard let product = try await loadProduct(forceRefresh: true) else {
            throw PremiumSubscriptionError.productUnavailable
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verificationResult):
            let transaction = try verifiedTransaction(from: verificationResult)
            await transaction.finish()
            return .purchased
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    @MainActor
    func openManageSubscriptions() async throws {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            throw PremiumSubscriptionError.missingWindowScene
        }

        try await StoreKit.AppStore.showManageSubscriptions(in: scene)
    }

    func finishIfNeeded(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result,
              transaction.productID == Self.productID else {
            return
        }

        await transaction.finish()
    }

    private func loadProduct(forceRefresh: Bool = false) async throws -> Product? {
        if !forceRefresh, let cachedProduct {
            return cachedProduct
        }

        let products = try await Product.products(for: [Self.productID])
        let product = products.first
        cachedProduct = product
        return product
    }

    private func hasActivePremiumEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements(for: Self.productID) {
            guard case .verified(let transaction) = result else { continue }
            if transaction.revocationDate == nil {
                return true
            }
        }

        return false
    }

    private nonisolated func verifiedTransaction(
        from result: VerificationResult<Transaction>
    ) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw PremiumSubscriptionError.failedVerification
        }
    }
}

struct PremiumEntitlementCacheStore {
    private let unlockedKey = "befit.premium.unlocked"

    func isPremiumUnlocked() -> Bool {
        UserDefaults.standard.bool(forKey: unlockedKey)
    }

    func setPremiumUnlocked(_ isUnlocked: Bool) {
        UserDefaults.standard.set(isUnlocked, forKey: unlockedKey)
    }
}
