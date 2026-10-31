import SwiftUI

/// Brand tokens from the design spec (Figma variables collection "Cliffzy").
enum Theme {
    enum Colors {
        static let bgBase = Color(hex: 0x0B0B10)
        static let bgSurface = Color(hex: 0x16161E)
        static let bgElevated = Color(hex: 0x22222D)
        static let accent = Color(hex: 0xFF2D55)
        static let coin = Color(hex: 0xFFC83D)
        static let vip = Color(hex: 0xA855F7)
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: 0xB4B4C3)
        static let textTertiary = Color(hex: 0x6E6E80)
        static let borderSubtle = Color(hex: 0x2E2E3A)
    }

    enum Gradients {
        static let vip = LinearGradient(
            colors: [Colors.vip, Colors.accent],
            startPoint: .leading,
            endPoint: .trailing
        )
        static let vipCard = LinearGradient(
            colors: [Color(hex: 0x6D28D9), Color(hex: 0xBE123C)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let avatar = LinearGradient(
            colors: [Colors.accent, Colors.vip],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let scrimTop = LinearGradient(
            colors: [.black.opacity(0.6), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        static let scrimBottom = LinearGradient(
            colors: [.clear, .black.opacity(0.9)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    enum Spacing {
        static let margin: CGFloat = 16
        static let section: CGFloat = 24
        static let inCard: CGFloat = 12
    }

    enum Radius {
        static let poster: CGFloat = 10
        static let button: CGFloat = 14
        static let row: CGFloat = 14
        static let card: CGFloat = 18
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension TimeInterval {
    /// 75 → "1:15"
    var clockFormatted: String {
        guard isFinite, self >= 0 else { return "0:00" }
        let total = Int(self)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
