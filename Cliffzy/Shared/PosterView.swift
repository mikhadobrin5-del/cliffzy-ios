import SwiftUI

/// Poster image, or a branded gradient with the title while real key art is missing.
struct PosterView: View {
    let series: Series
    var showsTitle = true
    var showsBadge = true

    private static let palettes: [[Color]] = [
        [Color(hex: 0x7A1636), Color(hex: 0x1A0712)],
        [Color(hex: 0x2B3A8C), Color(hex: 0x0B0F26)],
        [Color(hex: 0x8C5A12), Color(hex: 0x1F1206)],
        [Color(hex: 0x1E6B5C), Color(hex: 0x061A16)],
        [Color(hex: 0x5B1E8C), Color(hex: 0x140726)],
        [Color(hex: 0x8C1E1E), Color(hex: 0x200606)],
    ]

    var body: some View {
        Color.clear
            .aspectRatio(0.7, contentMode: .fit)
            .background { artwork }
            .overlay(alignment: .bottomLeading) {
                if showsTitle && series.posterURL == nil {
                    Text(series.title)
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .shadow(color: .black.opacity(0.4), radius: 3)
                        .padding(10)
                }
            }
            .overlay(alignment: .topLeading) {
                if showsBadge, let badge = series.badge {
                    Text(badge.uppercased())
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.accent, in: RoundedRectangle(cornerRadius: 4))
                        .accessibilityLabel(badge)
                        .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.poster))
    }

    @ViewBuilder
    private var artwork: some View {
        if let url = series.posterURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                gradient
            }
        } else {
            gradient
        }
    }

    static func colors(for series: Series) -> [Color] {
        palettes[abs(series.paletteIndex) % palettes.count]
    }

    private var gradient: some View {
        ZStack {
            LinearGradient(colors: Self.colors(for: series), startPoint: .top, endPoint: .bottom)
            Image(systemName: "play.fill")
                .font(.system(size: 64, weight: .black))
                .foregroundStyle(.white.opacity(0.08))
                .rotationEffect(.degrees(-12))
                .offset(x: 30, y: -20)
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
        }
    }
}

/// Full-bleed backdrop for locked episodes and the feed while video loads.
struct PosterBackdrop: View {
    let series: Series

    var body: some View {
        ZStack {
            LinearGradient(
                colors: PosterView.colors(for: series),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Color.black.opacity(0.45)
        }
    }
}

/// Poster + two-line title + meta, as used on shelves and grids.
struct PosterCard: View {
    let series: Series
    var meta: String?
    var width: CGFloat? = 112

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PosterView(series: series, showsTitle: false)
            Text(series.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
            Text(meta ?? "\(series.episodeCount) episodes")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .lineLimit(1)
        }
        .frame(width: width)
        .accessibilityElement(children: .combine)
    }
}
