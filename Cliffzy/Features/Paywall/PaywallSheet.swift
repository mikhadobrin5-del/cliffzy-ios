import StoreKit
import SwiftUI

/// VIP subscription (screen 05). Opened for a locked episode or from Profile and the feed header.
/// The purchase goes through the App Store; the server checks it and opens every episode.
struct PaywallSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var episode: Episode?

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    header
                    benefits
                    planSection
                    footer
                }
                .padding(Theme.Spacing.margin)
            }
            .background(Theme.Colors.bgBase)
            .navigationTitle(episode.map { "Episode \($0.number)" } ?? "VIP")
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
            .onChange(of: app.account.isVIP) {
                if app.account.isVIP { dismiss() }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Colors.vip)
            Text(episode == nil ? "Watch everything with VIP" : "Keep watching with VIP")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text("Every episode of every series, as soon as it comes out.")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit("lock.open.fill", "All episodes unlocked")
            benefit("sparkles", "New series every week")
            benefit("iphone.and.arrow.forward", "Works on every device with your account")
            benefit("xmark.circle", "Cancel anytime in Settings")
        }
        .padding(Theme.Spacing.margin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.bgSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func benefit(_ icon: String, _ text: LocalizedStringKey) -> some View {
        Label {
            Text(text).foregroundStyle(.white)
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.Colors.vip)
        }
        .font(.subheadline.weight(.medium))
    }

    @ViewBuilder
    private var planSection: some View {
        if app.account.isVIP {
            Text(vipActiveText)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
        } else if let plan = app.purchases.plans.first {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VIP")
                            .font(.headline)
                        Text("Renews every \(plan.periodName)")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    Text("\(plan.displayPrice) / \(plan.periodName)")
                        .font(.title3.bold())
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Theme.Gradients.vip).opacity(0.35)
                )
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.Colors.vip, lineWidth: 2))

                Button {
                    buy(plan)
                } label: {
                    if app.purchases.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Subscribe for \(plan.displayPrice) / \(plan.periodName)")
                    }
                }
                .buttonStyle(.cliffzy(.vip))
                .disabled(app.purchases.isPurchasing)

                if app.purchases.previewStore {
                    Label("Demo server: the purchase is simulated and free.", systemImage: "hammer")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        } else {
            Text(app.purchases.storeError ?? "The App Store isn't reachable right now. Try again in a moment.")
                .font(.footnote)
                .foregroundStyle(Theme.Colors.textSecondary)
            Button("Try again") { Task { await app.purchases.loadProducts() } }
                .buttonStyle(CapsuleButtonStyle())
        }
    }

    private var vipActiveText: String {
        guard let until = app.account.vipUntil else { return "VIP is active. Enjoy every episode." }
        return "VIP is active until \(until.formatted(date: .abbreviated, time: .omitted))."
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    do {
                        try await app.purchases.restore()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                if app.purchases.isRestoring { ProgressView() } else { Text("Restore purchases") }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .disabled(app.purchases.isRestoring)

            Text(renewalText)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("Terms of Use", destination: AppConfig.termsURL)
                Link("Privacy Policy", destination: AppConfig.privacyURL)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Wording Apple expects next to an auto-renewing subscription.
    private var renewalText: String {
        let price = app.purchases.plans.first.map { "\($0.displayPrice) per \($0.periodName)" } ?? "the listed price"
        return "Payment is charged to your Apple ID at confirmation. The subscription renews automatically at \(price) unless it is cancelled at least 24 hours before the end of the current period. Manage or cancel it in Settings › Apple ID › Subscriptions."
    }

    private func buy(_ plan: VIPPlan) {
        Task {
            do {
                try await app.purchases.purchase(plan)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
