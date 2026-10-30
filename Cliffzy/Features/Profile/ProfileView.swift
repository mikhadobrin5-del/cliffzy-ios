import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(AppModel.self) private var app

    @State private var showSettings = false
    @State private var showSignIn = false
    @State private var claimCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.section) {
                    userRow
                    coinsCard
                    vipCard
                    linksList
                    #if DEBUG
                    DeveloperSection()
                    #endif
                    Text("Cliffzy \(appVersion)")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(.bottom, 8)
                }
                .padding(Theme.Spacing.margin)
            }
            .background(Theme.Colors.bgBase)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
            .sensoryFeedback(.success, trigger: claimCount)
            .alert("Sign in is coming soon", isPresented: $showSignIn) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("In the test build your coins and progress are saved on this device.")
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(build))"
    }

    // MARK: User

    private var userRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Theme.Gradients.avatar, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Guest")
                        .font(.headline)
                        .foregroundStyle(.white)
                    if app.entitlements.isVIP { VIPBadge() }
                }
                Text("Sign in to keep coins & progress")
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 8)
            Button("Sign in") { showSignIn = true }
                .buttonStyle(CapsuleButtonStyle(fill: Theme.Colors.bgElevated))
        }
    }

    // MARK: Coins + check-in

    private var coinsCard: some View {
        let store = app.entitlements
        let canClaim = store.canClaimDailyBonus()
        let nextDay = store.nextCheckInDay()
        // Days already claimed in this cycle, for the 7-day strip.
        let claimedDays = canClaim ? nextDay - 1 : store.checkInStreak
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Coins")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    HStack(spacing: 8) {
                        CoinIcon(size: 28)
                        Text(store.coins.formatted())
                            .font(.largeTitle.bold())
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }
                }
                Spacer()
                Button("Top up") { app.shopPresented = true }
                    .buttonStyle(CapsuleButtonStyle(fill: Theme.Colors.coin, text: Theme.Colors.bgBase))
            }

            Divider().overlay(Theme.Colors.borderSubtle)

            HStack(spacing: 12) {
                Image(systemName: "gift.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.coin)
                    .frame(width: 36, height: 36)
                    .background(Theme.Colors.coin.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily check-in")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("+\(store.dailyReward(day: nextDay)) free coins today")
                        .font(.footnote)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                if canClaim {
                    Button("Claim") {
                        withAnimation {
                            if store.claimDailyBonus() { claimCount += 1 }
                        }
                    }
                    .buttonStyle(CapsuleButtonStyle())
                } else {
                    Text("Claimed ✓")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }

            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { day in
                    let claimed = day <= claimedDays
                    VStack(spacing: 4) {
                        Text("+\(store.dailyReward(day: day))")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(claimed ? Theme.Colors.coin : .white)
                        Text("Day \(day)")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        claimed ? Theme.Colors.coin.opacity(0.18) : Theme.Colors.bgElevated,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(claimed ? "Claimed" : "")
                }
            }
        }
        .padding(Theme.Spacing.margin)
        .background(Theme.Colors.bgSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: VIP

    private var vipCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.title)
                .foregroundStyle(Theme.Colors.coin)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.entitlements.isVIP ? "VIP · Active" : "VIP · Not active")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Every episode unlocked, no ads")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer(minLength: 8)
            if !app.entitlements.isVIP {
                Button("Get VIP") { app.shopPresented = true }
                    .buttonStyle(CapsuleButtonStyle(fill: .white, text: .black))
            }
        }
        .padding(Theme.Spacing.margin)
        .background(Theme.Gradients.vipCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: Links

    private var linksList: some View {
        VStack(spacing: 0) {
            NavigationLink { SettingsView() } label: {
                ProfileRow(icon: "bell", title: "Notifications")
            }
            divider
            Button {
                Task { await app.purchases.restore() }
            } label: {
                ProfileRow(icon: "arrow.clockwise", title: "Restore purchases", showsChevron: false)
            }
            divider
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                ProfileRow(icon: "globe", title: "Language", detail: Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en"))
            }
            divider
            Link(destination: URL(string: "mailto:support@cliffzy.app")!) {
                ProfileRow(icon: "questionmark.circle", title: "Help & support")
            }
            divider
            Link(destination: PaywallSheet.termsURL) {
                ProfileRow(icon: "doc.text", title: "Terms & Privacy")
            }
        }
        .buttonStyle(.plain)
        .background(Theme.Colors.bgSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
    }

    private var divider: some View {
        Divider().overlay(Theme.Colors.borderSubtle).padding(.leading, 52)
    }
}

private struct ProfileRow: View {
    let icon: String
    let title: LocalizedStringKey
    var detail: String?
    var showsChevron = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 24)
            Text(title)
                .font(.body)
                .foregroundStyle(.white)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("settings.notifications") private var notifications = true
    @AppStorage("settings.autoplay") private var autoplay = true

    var body: some View {
        Form {
            Section {
                Toggle("New episode alerts", isOn: $notifications)
                Toggle("Autoplay next episode", isOn: $autoplay)
            } footer: {
                Text("Notifications are a preview in the test build.")
            }
            Section {
                Button("Clear watch history", role: .destructive) {
                    app.library.clearHistory()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.bgBase)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
/// Test-build helpers (spec: Developer section in DEBUG builds).
private struct DeveloperSection: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Developer")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                Button { app.entitlements.debugAddCoins(500) } label: {
                    ProfileRow(icon: "plus.circle", title: "+500 coins", showsChevron: false)
                }
                Divider().overlay(Theme.Colors.borderSubtle).padding(.leading, 52)
                Button { app.entitlements.setVIP(!app.entitlements.isVIP) } label: {
                    ProfileRow(icon: "crown", title: "Toggle VIP", detail: app.entitlements.isVIP ? "On" : "Off", showsChevron: false)
                }
                Divider().overlay(Theme.Colors.borderSubtle).padding(.leading, 52)
                Button { app.entitlements.debugResetUnlocks() } label: {
                    ProfileRow(icon: "lock.rotation", title: "Reset unlocks", showsChevron: false)
                }
                Divider().overlay(Theme.Colors.borderSubtle).padding(.leading, 52)
                Button { app.entitlements.debugResetDailyBonus() } label: {
                    ProfileRow(icon: "gift", title: "Reset daily bonus", showsChevron: false)
                }
            }
            .buttonStyle(.plain)
            .background(Theme.Colors.bgSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
        }
    }
}
#endif
