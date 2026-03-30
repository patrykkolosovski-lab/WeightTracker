import Foundation
import StoreKit

struct PremiumCoordinator {
    private let entitlementCache: PremiumEntitlementCacheStore
    private let subscriptionService: PremiumSubscriptionService

    init(
        entitlementCache: PremiumEntitlementCacheStore = PremiumEntitlementCacheStore(),
        subscriptionService: PremiumSubscriptionService = .shared
    ) {
        self.entitlementCache = entitlementCache
        self.subscriptionService = subscriptionService
    }

    func restoreCachedState() -> Bool {
        entitlementCache.isPremiumUnlocked()
    }

    var transactionUpdates: Transaction.Transactions {
        subscriptionService.transactionUpdates
    }

    func refreshState() async -> PremiumStorefrontState {
        let storefrontState = await subscriptionService.storefrontState()
        entitlementCache.setPremiumUnlocked(storefrontState.isUnlocked)
        return storefrontState
    }

    func purchasePremium() async throws -> PremiumPurchaseOutcome {
        try await subscriptionService.purchasePremium()
    }

    func openManageSubscriptions() async throws {
        try await subscriptionService.openManageSubscriptions()
    }

    func finishIfNeeded(_ result: VerificationResult<Transaction>) async {
        await subscriptionService.finishIfNeeded(result)
    }
}
