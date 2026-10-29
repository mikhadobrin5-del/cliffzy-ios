import SwiftUI

/// Poster image, or a generated gradient with the title while real artwork is missing.
struct PosterView: View {
    let series: Series

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = series.posterURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
                Text(series.title)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .padding(8)
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholder: some View {
        // Stable per series (String.hashValue changes between launches).
        let seed = series.id.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }
        let hue = Double(abs(seed % 360)) / 360
        return LinearGradient(
            colors: [Color(hue: hue, saturation: 0.6, brightness: 0.55), .black],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct CoinBadge: View {
    let coins: Int

    var body: some View {
        Label("\(coins)", systemImage: "circle.hexagongrid.fill")
            .font(.subheadline.bold())
            .foregroundStyle(.yellow)
    }
}
