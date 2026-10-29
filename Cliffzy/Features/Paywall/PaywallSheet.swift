import StoreKit
import SwiftUI

/// Unlock an episode with coins, buy a coin pack, or subscribe to VIP.
/// Pass no episode to use it as a plain coin shop (from Profile).
struct PaywallSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var episode: Episode?

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    balance
                    if let episode {
                        unlockSection(for: episode)
                    }
                    vipSection
                    coinsSection
                    Button("Restore purchases") {
                        Task { await app.purchases.restore() }
                    }
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .navigationTitle(episode == nil ? "Coins" : "Unlock episode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Purchase failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: app.entitlements.isVIP) {
                if app.entitlements.isVIP, episode != nil { dismiss() }
            }
        }
    }

    private var balance: some View {
        HStack {
            Text("Your balance")
                .foregroundStyle(.secondary)
            Spacer()
            CoinBadge(coins: app.entitlements.coins)
        }
    }

    private func unlockSection(for episode: Episode) -> some View {
        let price = app.entitlements.config.episodePriceCoins
        let canAfford = app.entitlements.coins >= price
        return Button {
            do {
                try app.entitlements.unlock(episode)
                dismiss()
            } catch {
                errorMessage = "Not enough coins. Pick a pack below."
            }
        } label: {
            Text("Unlock episode \(episode.number) for \(price) coins")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canAfford ? Color.pink : Color.gray.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
        .disabled(!canAfford)
    }

    @ViewBuilder
    private var vipSection: some View {
        if !app.purchases.vipProducts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("VIP: every episode unlocked")
                    .font(.headline)
                ForEach(app.purchases.vipProducts, id: \.id) { product in
                    productRow(product, title: product.displayName, highlight: true)
                }
            }
        }
    }

    private var coinsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Coin packs")
                .font(.headline)
            if app.purchases.coinProducts.isEmpty {
                Text("Store is unavailable right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(app.purchases.coinProducts, id: \.id) { product in
                let coins = app.entitlements.config.coins(forProductID: product.id) ?? 0
                productRow(product, title: "\(coins) coins", highlight: false)
            }
        }
    }

    private func productRow(_ product: Product, title: String, highlight: Bool) -> some View {
        Button {
            Task {
                do {
                    try await app.purchases.purchase(product)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } label: {
            HStack {
                Text(title).font(.body.bold())
                Spacer()
                Text(product.displayPrice).font(.body.bold())
            }
            .padding()
            .background(
                highlight ? Color.pink.opacity(0.25) : Color.white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .foregroundStyle(.white)
        }
        .disabled(app.purchases.isPurchasing)
    }
}
