import Foundation

/// In-memory server for demo screens (`-CliffzyScreen`), SwiftUI previews and tests.
/// Plays public HLS test streams and follows the real rules: the first episodes are free,
/// the rest answer 402 until VIP is on. "Buying" VIP here is free.
actor DemoAPI: CliffzyAPI {
    struct DemoSeries {
        let card: SeriesCard
        let synopsis: String
        let durations: [Int]
    }

    static let freeEpisodes = 5
    private static let streams = [
        "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8",
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8",
    ].compactMap(URL.init(string:))

    static let catalog: [DemoSeries] = {
        let seeds: [(String, String, [String], Int)] = [
            ("The Billionaire's Secret Bride", "She signed a contract marriage. He never planned to fall in love.", ["Romance", "Billionaire"], 40),
            ("Reborn to Take Revenge", "Betrayed and left to die, she wakes up ten years in the past.", ["Revenge", "Rebirth"], 32),
            ("Alpha's Rejected Mate", "Rejected on the night of the full moon, she rises as a queen.", ["Werewolf", "Romance"], 36),
            ("My Husband Is the Boss", "The quiet intern she married owns the company she works for.", ["Billionaire", "Comedy"], 28),
            ("The Heiress Returns", "Thrown out as a fake daughter, the real heiress comes back.", ["Family", "Revenge"], 30),
            ("Midnight Contract", "One night, one deal, and a secret that could ruin them both.", ["Thriller", "Romance"], 24),
            ("Divorced, Then Adored", "He signed the papers. Now he will do anything to win her back.", ["Romance", "Drama"], 34),
            ("The Mafia Don's Nanny", "She took the job to pay rent. She did not expect his rules.", ["Mafia", "Romance"], 30),
        ]
        return seeds.enumerated().map { index, seed in
            let id = "demo-\(index + 1)"
            return DemoSeries(
                card: SeriesCard(id: id, title: seed.0, posterUrl: nil, episodeCount: seed.3, tags: seed.2),
                synopsis: seed.1,
                durations: (1...seed.3).map { 60 + ($0 * 7 + index * 13) % 60 }
            )
        }
    }()

    private var vipUntil: Date?
    private var saved: [String] = []
    private var progress: [(id: String, episode: Int, position: Int)] = []
    private let userID = UUID()

    init(vip: Bool = false) {
        vipUntil = vip ? Date().addingTimeInterval(7 * 86_400) : nil
    }

    private var isVIP: Bool { (vipUntil ?? .distantPast) > Date() }

    private func find(_ id: String) throws -> DemoSeries {
        guard let series = Self.catalog.first(where: { $0.card.id == id }) else { throw APIError.notFound }
        return series
    }

    func home() async throws -> HomeFeed {
        let cards = Self.catalog.map(\.card)
        let cont = progress.compactMap { entry in
            Self.catalog.first { $0.card.id == entry.id }.map {
                ContinueItem(series: $0.card, episode: entry.episode, positionSec: entry.position, progress: Double(entry.episode) / Double($0.card.episodeCount))
            }
        }
        var genres: [String] = []
        for tag in cards.flatMap(\.tags) where !genres.contains(tag) { genres.append(tag) }
        return HomeFeed(
            banners: Array(cards.prefix(5)),
            continueWatching: cont,
            shelves: [
                ShelfInfo(id: "top", title: "Top 10", items: Array(cards.prefix(10)), ranked: true),
                ShelfInfo(id: "new", title: "New releases", items: Array(cards.reversed()), ranked: false),
            ],
            genres: genres,
            all: cards
        )
    }

    func series(id: String) async throws -> SeriesDetail {
        let series = try find(id)
        let episodes = series.durations.enumerated().map { index, duration in
            let n = index + 1
            return EpisodeInfo(number: n, durationSec: duration, access: n <= Self.freeEpisodes ? "FREE" : (isVIP ? "VIP" : "LOCKED"))
        }
        let resume = progress.first { $0.id == id }.map { ResumePoint(episode: $0.episode, positionSec: $0.position) }
        return SeriesDetail(series: series.card, description: series.synopsis, freeEpisodes: Self.freeEpisodes, episodes: episodes, saved: saved.contains(id), resume: resume)
    }

    func playback(seriesID: String, episode: Int) async throws -> PlaybackLink {
        let series = try find(seriesID)
        guard (1...series.card.episodeCount).contains(episode) else { throw APIError.notFound }
        guard episode <= Self.freeEpisodes || isVIP else { throw APIError.vipRequired }
        let index = Self.catalog.firstIndex { $0.card.id == seriesID } ?? 0
        return PlaybackLink(url: Self.streams[(index + episode) % Self.streams.count], expiresAt: Date().addingTimeInterval(6 * 3600).timeIntervalSince1970)
    }

    func reportProgress(seriesID: String, episode: Int, positionSec: Int) async throws {
        progress.removeAll { $0.id == seriesID }
        progress.insert((seriesID, episode, positionSec), at: 0)
    }

    func me() async throws -> Me {
        Me(userId: userID.uuidString, vip: isVIP, vipUntil: vipUntil.map { $0.timeIntervalSince1970 * 1000 }, devMode: true)
    }

    func deleteAccount() async throws {
        vipUntil = nil
        saved = []
        progress = []
    }

    func myList() async throws -> [SeriesCard] {
        saved.compactMap { id in Self.catalog.first { $0.card.id == id }?.card }
    }

    func save(seriesID: String) async throws {
        _ = try find(seriesID)
        if !saved.contains(seriesID) { saved.insert(seriesID, at: 0) }
    }

    func unsave(seriesID: String) async throws {
        saved.removeAll { $0 == seriesID }
    }

    func history() async throws -> [HistoryItem] {
        progress.compactMap { entry in
            Self.catalog.first { $0.card.id == entry.id }.map {
                HistoryItem(series: $0.card, episode: entry.episode, positionSec: entry.position, progress: Double(entry.episode) / Double($0.card.episodeCount))
            }
        }
    }

    /// Any "transaction" turns VIP on for a week (the preview store has no App Store behind it).
    func verifyAppleTransaction(_ jws: String) async throws -> Me {
        vipUntil = Date().addingTimeInterval(7 * 86_400)
        return try await me()
    }

    func accountID() async throws -> UUID {
        userID
    }
}
