import Foundation

struct Series: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let synopsis: String
    let genres: [String]
    let posterURL: URL?
    let episodes: [Episode]
    /// Short label on the poster: "New", "Hot", "Exclusive".
    var badge: String?
    var views: Int = 0
    /// Index into the poster palette until real key art exists.
    var paletteIndex: Int = 0

    var episodeCount: Int { episodes.count }

    func episode(number: Int) -> Episode? {
        episodes.first { $0.number == number }
    }
}

struct Episode: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let seriesID: String
    /// 1-based position inside the series.
    let number: Int
    let title: String
    let duration: TimeInterval
    let streamURL: URL
}

struct Shelf: Identifiable, Hashable, Sendable {
    enum Style: Hashable, Sendable {
        case posters
        case ranked
    }

    let id: String
    let title: String
    let series: [Series]
    var style: Style = .posters
}

extension Int {
    /// 2_400_000 → "2.4M", 18_500 → "18.5K".
    var compactFormatted: String {
        formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }
}
