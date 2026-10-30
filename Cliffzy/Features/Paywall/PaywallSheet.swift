import StoreKit
import SwiftUI

/// Unlock an episode with coins, buy a coin pack, or subscribe to VIP (screen 05).
/// With no episode it is the plain coin shop (from Profile or any CoinBadge).
struct PaywallSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var episode: Episode?

    @State private var selectedVIP: String?
    @State private var errorMessage: String?
    @State private var successCount = 0

    static let termsURL = URL(string: "https://cliffzy.app/terms")!
    static let privacyURL = URL(string: "https://cliffzy.app/privacy")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    balanceRow
                    if let episode {
                        unlockCard(for: episode)
                    }
                    vipSection
                    coinsSection
                    footer
                }
                .padding(Theme.Spacing.margin)
            }
            .background(Theme.Colors.bgBase)
            .navigationTitle(episode == nil ? "Coins" : "Unlock episode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SheetCloseButton() }
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
            .sensoryFeedback(.success, trigger: successCount)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Sections

    private var balanceRow: some View {
        HStack {
            Text("Your balance")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            CoinBadge(opensShop: false)
        }
    }

    private func unlockCard(for episode: Episode) -> some View {
        let price = app.entitlements.config.episodePriceCoins
        let short = app.entitlements.coinsNeeded(for: episode)
        return VStack(alignment: .leading, spacing: Theme.Spacing.inCard) {
            Text("Unlock episode \(episode.number) for \(price) coins")
                .font(.headline)
                .foregroundStyle(.white)
            Button {
                do {
                    try app.entitlements.unlock(episode)
                    successCount += 1
                    dismiss()
                } catch {
                    errorMessage = "Not enough coins. Pick a pack below."
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Unlock for \(price)")
                    CoinIcon(size: 18)
                }
            }
            .buttonStyle(.cliffzy(.coin))
            .disabled(short > 0)
            if short > 0 {
                Text("You need \(short) more coins. Pick a pack below.")
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(Theme.Spacing.margin)
        .background(Theme.Colors.bgElevated, in: RoundedRectangle(cornerRadius: 16))
    }

    private var vipSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.inCard) {
            Label {
                Text("VIP: every episode unlocked")
            } icon: {
                Image(systemName: "crown.fill").foregroundStyle(Theme.Colors.vip)
            }
            .font(.title3.bold())
            .foregroundStyle(.white)

            if app.entitlements.isVIP {
                Text("VIP is active. Enjoy every episode.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else if app.purchases.vipProducts.isEmpty {
                storeUnavailable
            } else {
                HStack(spacing: 10) {
                    ForEach(app.purchases.vipProducts, id: \.id) { product in
                        vipCard(product)
                    }
                }
                Button {
                    if let product = app.purchases.vipProducts.first(where: { $0.id == currentVIPSelection }) {
                        buy(product)
                    }
                } label: {
                    Text("Start VIP")
                }
                .buttonStyle(.cliffzy(.vip))
                .disabled(app.purchases.isPurchasing)
            }
        }
    }

    private var currentVIPSelection: String? {
        selectedVIP ?? app.purchases.vipProducts.last?.id
    }

    private func vipCard(_ product: Product) -> some View {
        let selected = product.id == currentVIPSelection
        let yearly = product.subscription?.subscriptionPeriod.unit == .year
        return Button {
            selectedVIP = product.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(yearly ? "Yearly" : "Weekly")
                    .font(.headline)
                Text(product.displayPrice)
                    .font(.title2.bold())
                    .monospacedDigit()
                Text(yearly ? weeklyEquivalent(product) : "per week")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Theme.Colors.bgElevated)
                    if selected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Theme.Gradients.vip)
                            .opacity(0.35)
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(selected ? Theme.Colors.vip : Theme.Colors.borderSubtle, lineWidth: selected ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if yearly {
                    Text("BEST VALUE")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.accent, in: Capsule())
                        .offset(x: -8, y: -9)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func weeklyEquivalent(_ product: Product) -> String {
        let perWeek = product.price / 52
        let formatted = perWeek.formatted(product.priceFormatStyle)
        if let weekly = app.purchases.vipProducts.first(where: { $0.subscription?.subscriptionPeriod.unit != .year }),
           weekly.price > 0 {
            let saving = (1 - (perWeek / weekly.price)) * 100
            let percent = NSDecimalNumber(decimal: saving).intValue
            return "≈ \(formatted)/wk · save \(percent)%"
        }
        return "≈ \(formatted)/wk"
    }

    private var coinsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.inCard) {
            Text("Coin packs")
                .font(.title3.bold())
                .foregroundStyle(.white)
            if app.purchases.coinProducts.isEmpty {
                storeUnavailable
            }
            ForEach(app.purchases.coinProducts, id: \.id) { product in
                coinRow(product)
            }
        }
    }

    private func coinRow(_ product: Product) -> some View {
        let pack = app.entitlements.config.pack(forProductID: product.id)
        return Button {
            buy(product)
        } label: {
            HStack(spacing: 12) {
                CoinIcon(size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\((pack?.coins ?? 0).formatted()) coins")
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let bonus = pack?.bonusPercent, bonus > 0 {
                        Text("+\(bonus)% bonus")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.Colors.coin)
                    }
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.accent, in: Capsule())
            }
            .padding(14)
            .background(Theme.Colors.bgSurface, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(app.purchases.isPurchasing)
    }

    private var storeUnavailable: some View {
        Text("The App Store isn't reachable right now. In the Simulator, run from Xcode so the StoreKit test config loads.")
            .font(.footnote)
            .foregroundStyle(Theme.Colors.textSecondary)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button("Restore purchases") {
                Task { await app.purchases.restore() }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            Text("Subscription renews automatically unless cancelled at least 24 hours before the end of the period. Manage in Settings.")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("Terms of Use", destination: Self.termsURL)
                Link("Privacy Policy", destination: Self.privacyURL)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func buy(_ product: Product) {
        Task {
            do {
                if try await app.purchases.purchase(product) {
                    successCount += 1
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
