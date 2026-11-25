import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(AppModel.self) private var app

    @State private var showSettings = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.section) {
                    userRow
                    vipCard
                    linksList
                    accountList
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
            .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) { deleteAccount() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your watch history and My List are deleted from Cliffzy's servers. An App Store subscription is not cancelled: manage it in Settings › Apple ID › Subscriptions.")
            }
            .alert("Cliffzy", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
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
                    if app.account.isVIP { VIPBadge() }
                }
                Text("History, My List and VIP are saved to this device's account.")
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: VIP

    private var vipCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.title)
                .foregroundStyle(Theme.Colors.coin)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.account.isVIP ? "VIP · Active" : "VIP · Not active")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(vipDetail)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer(minLength: 8)
            if app.account.isVIP {
                Link("Manage", destination: AppConfig.manageSubscriptionsURL)
                    .buttonStyle(CapsuleButtonStyle(fill: .white, text: .black))
            } else {
                Button("Get VIP") { app.paywallPresented = true }
                    .buttonStyle(CapsuleButtonStyle(fill: .white, text: .black))
            }
        }
        .padding(Theme.Spacing.margin)
        .background(Theme.Gradients.vipCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var vipDetail: String {
        if app.account.isVIP, let until = app.account.vipUntil {
            return "Every episode unlocked · renews or ends \(until.formatted(date: .abbreviated, time: .omitted))"
        }
        return "Every episode of every series unlocked"
    }

    // MARK: Links

    private var linksList: some View {
        VStack(spacing: 0) {
            Button {
                Task {
                    do {
                        try await app.purchases.restore()
                        message = app.account.isVIP ? "VIP is restored." : "No active VIP subscription was found for this Apple ID."
                    } catch {
                        message = error.localizedDescription
                    }
                }
            } label: {
                ProfileRow(icon: "arrow.clockwise", title: "Restore purchases", showsChevron: false)
            }
            divider
            Link(destination: URL(string: "mailto:\(AppConfig.supportEmail)")!) {
                ProfileRow(icon: "questionmark.circle", title: "Help & support")
            }
            divider
            Link(destination: AppConfig.termsURL) {
                ProfileRow(icon: "doc.text", title: "Terms of Use")
            }
            divider
            Link(destination: AppConfig.privacyURL) {
                ProfileRow(icon: "hand.raised", title: "Privacy Policy")
            }
        }
        .buttonStyle(.plain)
        .background(Theme.Colors.bgSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
    }

    /// Account deletion inside the app (App Review Guideline 5.1.1(v)).
    private var accountList: some View {
        Button {
            confirmDelete = true
        } label: {
            HStack(spacing: 12) {
                if deleting {
                    ProgressView().frame(width: 24)
                } else {
                    Image(systemName: "trash").frame(width: 24)
                }
                Text("Delete account")
                Spacer()
            }
            .foregroundStyle(Theme.Colors.accent)
            .padding(.horizontal, Theme.Spacing.margin)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(deleting)
        .background(Theme.Colors.bgSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
    }

    private var divider: some View {
        Divider().overlay(Theme.Colors.borderSubtle).padding(.leading, 52)
    }

    private func deleteAccount() {
        deleting = true
        Task {
            defer { deleting = false }
            do {
                try await app.deleteAccount()
                message = "Your account and its data were deleted."
            } catch {
                message = error.localizedDescription
            }
        }
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
    @AppStorage("settings.autoplay") private var autoplay = true

    var body: some View {
        Form {
            Section {
                Toggle("Autoplay next episode", isOn: $autoplay)
            }
            Section {
                Link("Delete your data on the web", destination: AppConfig.deleteDataURL)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.bgBase)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
