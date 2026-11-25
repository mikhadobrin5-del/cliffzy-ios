import Foundation

/// A series as the UI shows it. Built from a server card; `episodes` fill in once the series
/// detail has loaded (episode list with access rules), see `AppModel.detailedSeries(_:)`.
struct Series: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var synopsis: String
    var genres: [String]
    var posterURL: URL?
    var episodeCount: Int
    /// How many episodes are free; known after the detail loads.
    var freeEpisodes: Int?
    var episodes: [Episode]
    /// Short label on the poster: "New", "Top".
    var badge: String?
    /// Index into the poster palette, used while a poster is missing or loading.
    var paletteIndex: Int

    init(card: SeriesCard, paletteIndex: Int, badge: String? = nil) {
        id = card.id
        title = card.title
        synopsis = ""
        genres = card.tags
        posterURL = card.posterUrl
        episodeCount = card.episodeCount
        freeEpisodes = nil
        episodes = []
        self.badge = badge
        self.paletteIndex = paletteIndex
    }

    var hasEpisodes: Bool { !episodes.isEmpty }

    func episode(number: Int) -> Episode? {
        episodes.first { $0.number == number }
    }

    /// Episode 1, for the For You feed, before the detail has loaded. Episode 1 is always free.
    var firstEpisode: Episode {
        episodes.first ?? Episode(seriesID: id, number: 1, duration: 0, access: .free)
    }

    /// Takes the episode list, description and access rules from the server's detail.
    func applying(_ detail: SeriesDetail) -> Series {
        var copy = self
        copy.title = detail.series.title
        copy.genres = detail.series.tags
        copy.posterURL = detail.series.posterUrl ?? posterURL
        copy.synopsis = detail.description
        copy.freeEpisodes = detail.freeEpisodes
        copy.episodes = detail.episodes.sorted { $0.number < $1.number }.map {
            Episode(seriesID: id, number: $0.number, duration: TimeInterval($0.durationSec), access: EpisodeAccess(server: $0.access))
        }
        copy.episodeCount = copy.episodes.count
        return copy
    }
}

enum EpisodeAccess: Hashable, Sendable {
    case free
    /// Open thanks to VIP.
    case vip
    case locked

    init(server value: String) {
        switch value.uppercased() {
        case "FREE": self = .free
        case "VIP": self = .vip
        default: self = .locked
        }
    }

    var isPlayable: Bool { self != .locked }
}

struct Episode: Identifiable, Hashable, Sendable {
    let seriesID: String
    /// 1-based position inside the series.
    let number: Int
    let duration: TimeInterval
    /// As the server reported it when the detail loaded; `AppModel.access(for:)` adds VIP bought since.
    let access: EpisodeAccess

    var id: String { "\(seriesID)-e\(number)" }
    var title: String { "Episode \(number)" }
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

extension Series {
    /// Grey cards for loading placeholders.
    static let placeholders: [Series] = (0..<4).map {
        Series(card: SeriesCard(id: "placeholder-\($0)", title: "Loading series title", posterUrl: nil, episodeCount: 20, tags: []), paletteIndex: $0)
    }
}
