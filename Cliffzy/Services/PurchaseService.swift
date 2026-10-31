import Foundation
import Observation
import StoreKit

/// What the paywall shows for one product, whether it came from StoreKit or from the preview store.
struct StoreItem: Identifiable, Hashable {
    let id: String
    let displayPrice: String
    let price: Decimal
    let isYearly: Bool
    let priceFormatStyle: Decimal.FormatStyle.Currency
}

/// StoreKit 2 purchases: coin packs (consumable) and VIP (auto-renewable).
/// Will be replaced by RevenueCat once the backend webhook exists.
///
/// In DEBUG builds where StoreKit returns no products (an app installed on the Simulator
/// without Xcode's StoreKit config), a preview store stands in so every flow stays testable.
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

    // MARK: Items for the paywall

    var coinItems: [StoreItem] {
        if !coinProducts.isEmpty { return coinProducts.map(Self.item(from:)) }
        return isPreviewStore ? PreviewStore.coinItems : []
    }

    var vipItems: [StoreItem] {
        if !vipProducts.isEmpty { return vipProducts.map(Self.item(from:)) }
        return isPreviewStore ? PreviewStore.vipItems : []
    }

    /// True when the paywall runs on test prices with no App Store involved.
    var isPreviewStore: Bool {
        #if DEBUG
        return coinProducts.isEmpty && vipProducts.isEmpty
        #else
        return false
        #endif
    }

    private static func item(from product: Product) -> StoreItem {
        StoreItem(
            id: product.id,
            displayPrice: product.displayPrice,
            price: product.price,
            isYearly: product.subscription?.subscriptionPeriod.unit == .year,
            priceFormatStyle: product.priceFormatStyle
        )
    }

    // MARK: Loading and buying

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
        if !vipProducts.isEmpty {
            await refreshVIP()
        }
    }

    /// Returns true when the purchase completed (not cancelled or pending).
    @discardableResult
    func purchase(_ item: StoreItem) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        guard let product = (coinProducts + vipProducts).first(where: { $0.id == item.id }) else {
            return previewPurchase(item)
        }

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
        if !vipProducts.isEmpty {
            await refreshVIP()
        }
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

    private func previewPurchase(_ item: StoreItem) -> Bool {
        guard isPreviewStore else { return false }
        if let coins = entitlements.config.coins(forProductID: item.id) {
            entitlements.credit(coins: coins, transactionID: "preview-\(UUID().uuidString)")
        } else {
            entitlements.setVIP(true)
        }
        return true
    }
}

/// Test prices for DEBUG builds without StoreKit (USD, matching StoreKit/Cliffzy.storekit).
private enum PreviewStore {
    static let usd = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))

    static let coinItems = [
        item("com.cliffzy.coins.500", 4.99),
        item("com.cliffzy.coins.1100", 9.99),
        item("com.cliffzy.coins.2400", 19.99),
    ]

    static let vipItems = [
        item("com.cliffzy.vip.weekly", 9.99),
        item("com.cliffzy.vip.yearly", 99.99, yearly: true),
    ]

    private static func item(_ id: String, _ price: Decimal, yearly: Bool = false) -> StoreItem {
        StoreItem(id: id, displayPrice: price.formatted(usd), price: price, isYearly: yearly, priceFormatStyle: usd)
    }
}
