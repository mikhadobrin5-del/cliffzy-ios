import Foundation
import Observation
import StoreKit

/// StoreKit 2 purchases: coin packs (consumable) and VIP (auto-renewable).
/// Will be replaced by RevenueCat once the backend webhook exists.
@MainActor
@Observable
final class PurchaseService {
    private(set) var coinProducts: [Product] = []
    private(set) var vipProducts: [Product] = []
    private(set) var isPurchasing = false

    @ObservationIgnored private let entitlements: EntitlementStore
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init(entitlements: EntitlementStore) {
        self.entitlements = entitlements
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        let config = entitlements.config
        do {
            let products = try await Product.products(for: config.allProductIDs)
            coinProducts = products
                .filter { $0.type == .consumable }
                .sorted { $0.price < $1.price }
            vipProducts = products
                .filter { $0.type == .autoRenewable }
                .sorted { $0.price < $1.price }
        } catch {
            print("[Purchases] failed to load products: \(error)")
        }
        await refreshVIP()
    }

    /// Returns true when the purchase completed (not cancelled or pending).
    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        switch try await product.purchase() {
        case .success(let verification):
            await handle(verification)
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshVIP()
    }

    func refreshVIP() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productType == .autoRenewable,
               transaction.revocationDate == nil {
                active = true
            }
        }
        entitlements.setVIP(active)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            print("[Purchases] unverified transaction ignored")
            return
        }
        switch transaction.productType {
        case .consumable:
            if let coins = entitlements.config.coins(forProductID: transaction.productID) {
                entitlements.credit(coins: coins, transactionID: String(transaction.id))
            }
        case .autoRenewable:
            await refreshVIP()
        default:
            break
        }
        await transaction.finish()
    }
}
