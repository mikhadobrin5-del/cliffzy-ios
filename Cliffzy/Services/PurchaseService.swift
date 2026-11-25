import Foundation
import Observation
import StoreKit

/// What the paywall shows for the VIP plan, from StoreKit or from the preview store.
struct VIPPlan: Identifiable, Hashable {
    let id: String
    let displayPrice: String
    /// "week", "month", "year".
    let periodName: String
}

/// VIP subscription through StoreKit 2. The app never opens episodes by itself: every transaction
/// goes to the server (`POST /v1/billing/apple/verify`), which checks Apple's signature and turns
/// VIP on for the account. Renewals and refunds also reach the server from Apple directly.
///
/// A transaction is finished only after the server accepted it, so a failed upload is retried
/// by StoreKit on the next launch.
@MainActor
@Observable
final class PurchaseService {
    static let vipProductIDs = ["com.cliffzy.vip.weekly"]

    private(set) var products: [Product] = []
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    private(set) var storeError: String?

    @ObservationIgnored private let api: any CliffzyAPI
    @ObservationIgnored private let account: AccountStore
    /// Demo server and DEBUG builds without the App Store: "buying" is simulated.
    @ObservationIgnored let previewStore: Bool
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init(api: any CliffzyAPI, account: AccountStore, previewStore: Bool) {
        self.api = api
        self.account = account
        self.previewStore = previewStore
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var plans: [VIPPlan] {
        if !products.isEmpty {
            return products.map { product in
                VIPPlan(id: product.id, displayPrice: product.displayPrice, periodName: Self.periodName(product.subscription?.subscriptionPeriod))
            }
        }
        return previewStore ? [VIPPlan(id: Self.vipProductIDs[0], displayPrice: "$2.99", periodName: "week")] : []
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.vipProductIDs).sorted { $0.price < $1.price }
            storeError = products.isEmpty && !previewStore ? "VIP is not available in the App Store yet." : nil
        } catch {
            storeError = error.localizedDescription
        }
    }

    /// Returns true when VIP is on after the purchase (not cancelled, not pending).
    @discardableResult
    func purchase(_ plan: VIPPlan) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        guard let product = products.first(where: { $0.id == plan.id }) else {
            guard previewStore else { return false }
            account.apply(try await api.verifyAppleTransaction("preview"))
            return account.isVIP
        }
        let accountID = try await api.accountID()
        switch try await product.purchase(options: [.appAccountToken(accountID)]) {
        case .success(let verification):
            try await upload(verification)
            return account.isVIP
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// "Restore purchases": asks the App Store for this Apple ID's subscriptions and sends them to the server.
    func restore() async throws {
        isRestoring = true
        defer { isRestoring = false }
        if !previewStore { try await AppStore.sync() }
        await syncWithServer()
    }

    /// At launch: active subscriptions go to the server (covers a missed notification or a new device),
    /// then the account's VIP status is read back.
    func syncWithServer() async {
        if !previewStore || !products.isEmpty {
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result, Self.vipProductIDs.contains(transaction.productID) else { continue }
                try? await upload(result)
            }
        }
        if let me = try? await api.me() { account.apply(me) }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        do {
            try await upload(result)
        } catch {
            print("[Purchases] server did not accept the transaction yet: \(error)")
        }
    }

    private func upload(_ result: VerificationResult<Transaction>) async throws {
        guard case .verified(let transaction) = result else {
            print("[Purchases] unverified transaction ignored")
            return
        }
        guard Self.vipProductIDs.contains(transaction.productID) else {
            await transaction.finish()
            return
        }
        let me = try await api.verifyAppleTransaction(result.jwsRepresentation)
        account.apply(me)
        await transaction.finish()
    }

    private static func periodName(_ period: Product.SubscriptionPeriod?) -> String {
        switch period?.unit {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        case .year: "year"
        default: "period"
        }
    }
}
