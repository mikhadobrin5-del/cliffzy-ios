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
            } else if app.purchases.vipItems.isEmpty {
                storeUnavailable
            } else {
                HStack(spacing: 10) {
                    ForEach(app.purchases.vipItems) { item in
                        vipCard(item)
                    }
                }
                Button {
                    if let item = app.purchases.vipItems.first(where: { $0.id == currentVIPSelection }) {
                        buy(item)
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
        selectedVIP ?? app.purchases.vipItems.last?.id
    }

    private func vipCard(_ item: StoreItem) -> some View {
        let selected = item.id == currentVIPSelection
        let yearly = item.isYearly
        return Button {
            selectedVIP = item.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(yearly ? "Yearly" : "Weekly")
                    .font(.headline)
                Text(item.displayPrice)
                    .font(.title2.bold())
                    .monospacedDigit()
                Text(yearly ? weeklyEquivalent(item) : "per week")
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

    private func weeklyEquivalent(_ item: StoreItem) -> String {
        let perWeek = item.price / 52
        let formatted = perWeek.formatted(item.priceFormatStyle)
        if let weekly = app.purchases.vipItems.first(where: { !$0.isYearly }),
           weekly.price > 0 {
            // Via Double: NSDecimalNumber.intValue misreads long decimals (gave 0%).
            let ratio = NSDecimalNumber(decimal: perWeek / weekly.price).doubleValue
            let percent = Int(((1 - ratio) * 100).rounded())
            return "≈ \(formatted)/wk · save \(percent)%"
        }
        return "≈ \(formatted)/wk"
    }

    private var coinsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.inCard) {
            Text("Coin packs")
                .font(.title3.bold())
                .foregroundStyle(.white)
            if app.purchases.coinItems.isEmpty {
                storeUnavailable
            }
            ForEach(app.purchases.coinItems) { item in
                coinRow(item)
            }
            if app.purchases.isPreviewStore {
                Label("Test prices: purchases here are simulated and free.", systemImage: "hammer")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
    }

    private func coinRow(_ item: StoreItem) -> some View {
        let pack = app.entitlements.config.pack(forProductID: item.id)
        return Button {
            buy(item)
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
                Text(item.displayPrice)
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

    private func buy(_ item: StoreItem) {
        Task {
            do {
                if try await app.purchases.purchase(item) {
                    successCount += 1
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
