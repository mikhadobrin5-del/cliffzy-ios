import Foundation

struct Series: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let synopsis: String
    let genres: [String]
    let posterURL: URL?
    let episodes: [Episode]

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
    let id: String
    let title: String
    let series: [Series]
}
