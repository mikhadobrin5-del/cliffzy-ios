import SwiftUI

// MARK: - Buttons

enum CliffzyButtonKind {
    case primary, vip, coin, secondary
}

/// Primary / VIP / Coin / Secondary buttons: 52 high, radius 14, `.headline`.
struct CliffzyButtonStyle: ButtonStyle {
    var kind: CliffzyButtonKind = .primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(kind == .coin ? Theme.Colors.bgBase : .white)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(background, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var background: AnyShapeStyle {
        switch kind {
        case .primary: AnyShapeStyle(Theme.Colors.accent)
        case .vip: AnyShapeStyle(Theme.Gradients.vip)
        case .coin: AnyShapeStyle(Theme.Colors.coin)
        case .secondary: AnyShapeStyle(Theme.Colors.bgElevated)
        }
    }
}

extension ButtonStyle where Self == CliffzyButtonStyle {
    static func cliffzy(_ kind: CliffzyButtonKind = .primary) -> CliffzyButtonStyle {
        CliffzyButtonStyle(kind: kind)
    }
}

/// Small capsule button ("Claim", "Top up", "Sign in", "Watch now").
struct CapsuleButtonStyle: ButtonStyle {
    var fill: Color = Theme.Colors.accent
    var text: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(text)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(fill, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(Capsule())
    }
}

/// Translucent button over video.
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Coins and badges

struct CoinIcon: View {
    var size: CGFloat = 18

    var body: some View {
        Image(systemName: "circle.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(Theme.Colors.coin)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Balance capsule. Tapping opens the coin shop.
struct CoinBadge: View {
    @Environment(AppModel.self) private var app
    var opensShop = true

    var body: some View {
        Button {
            if opensShop { app.shopPresented = true }
        } label: {
            HStack(spacing: 6) {
                CoinIcon(size: 18)
                Text(app.entitlements.coins.formatted())
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.coin)
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(Theme.Colors.bgElevated, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(app.entitlements.coins) coins")
        .accessibilityHint(opensShop ? "Opens the coin shop" : "")
    }
}

struct VIPBadge: View {
    var body: some View {
        Label("VIP", systemImage: "crown.fill")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Theme.Gradients.vip, in: Capsule())
    }
}

struct GenreChip: View {
    let text: String
    var selected = false

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(selected ? .black : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selected ? Color.white : Theme.Colors.bgElevated, in: Capsule())
    }
}

/// Chip over video (white 16%).
struct VideoChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.16), in: Capsule())
    }
}

// MARK: - Player chrome

/// Icon + caption on the right rail of the players.
struct RailButton: View {
    let systemImage: String
    let label: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RailLabel(systemImage: systemImage, label: label, tint: tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct RailLabel: View {
    let systemImage: String
    let label: String
    var tint: Color = .white

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 40)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
        .contentShape(Rectangle())
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.white)
            Spacer()
            if let action {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text("See all")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.margin)
    }
}

/// Close button for sheets.
struct SheetCloseButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.title2)
                .foregroundStyle(.white)
        }
        .accessibilityLabel("Close")
    }
}

/// Thin progress bar with an accent fill.
struct ProgressLine: View {
    let value: Double
    var height: CGFloat = 4
    var track: Color = .white.opacity(0.2)

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(Theme.Colors.accent)
                    .frame(width: proxy.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
