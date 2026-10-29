import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var app

    @State private var showShop = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Coins")
                        Spacer()
                        CoinBadge(coins: app.entitlements.coins)
                    }
                    HStack {
                        Text("VIP")
                        Spacer()
                        Text(app.entitlements.isVIP ? "Active" : "Not active")
                            .foregroundStyle(app.entitlements.isVIP ? Color.pink : Color.secondary)
                    }
                    Button("Get coins or VIP") { showShop = true }
                }

                Section("Rewards") {
                    Button {
                        app.entitlements.claimDailyBonus()
                    } label: {
                        HStack {
                            Text("Daily check-in")
                            Spacer()
                            Text(app.entitlements.canClaimDailyBonus()
                                 ? "+\(app.entitlements.config.dailyBonusCoins)"
                                 : "Come back tomorrow")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!app.entitlements.canClaimDailyBonus())
                }

                Section {
                    Button("Restore purchases") {
                        Task { await app.purchases.restore() }
                    }
                } footer: {
                    Text("Cliffzy \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showShop) {
                PaywallSheet()
            }
        }
    }
}
