import Foundation

protocol CatalogService: Sendable {
    /// Series for the vertical "For You" feed, in display order.
    func feed() async throws -> [Series]
    /// Rows for the Discover screen.
    func shelves() async throws -> [Shelf]
    func series(id: String) async throws -> Series
}

enum CatalogError: Error {
    case notFound
}

/// Demo catalog backed by public HLS test streams, so the app runs before the
/// real backend and content exist. Swap for a Supabase-backed service later.
struct MockCatalogService: CatalogService {
    private let all: [Series]

    init() {
        let streams = [
            "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
            "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8",
            "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8",
        ].compactMap(URL.init(string:))

        let seeds: [(String, String, [String])] = [
            ("The Billionaire's Secret Bride", "She signed a contract marriage. He never planned to fall in love.", ["Romance", "CEO"]),
            ("Reborn to Take Revenge", "Betrayed and left to die, she wakes up ten years in the past.", ["Revenge", "Rebirth"]),
            ("Alpha's Rejected Mate", "Rejected on the night of the full moon, she rises as a queen.", ["Werewolf", "Romance"]),
            ("My Husband Is the Boss", "The quiet intern she married is the owner of her company.", ["CEO", "Comedy"]),
            ("The Heiress Returns", "Thrown out as a fake daughter, the real heiress comes back.", ["Family", "Revenge"]),
            ("Midnight Contract", "One night, one deal, and a secret that could ruin them both.", ["Thriller", "Romance"]),
        ]

        all = seeds.enumerated().map { index, seed in
            let seriesID = "s\(index + 1)"
            let episodes = (1...20).map { number in
                Episode(
                    id: "\(seriesID)-e\(number)",
                    seriesID: seriesID,
                    number: number,
                    title: "Episode \(number)",
                    duration: 90,
                    streamURL: streams[(index + number) % streams.count]
                )
            }
            return Series(
                id: seriesID,
                title: seed.0,
                synopsis: seed.1,
                genres: seed.2,
                posterURL: nil,
                episodes: episodes
            )
        }
    }

    func feed() async throws -> [Series] {
        all
    }

    func shelves() async throws -> [Shelf] {
        let genres = Array(Set(all.flatMap(\.genres))).sorted()
        let byGenre = genres.map { genre in
            Shelf(id: genre, title: genre, series: all.filter { $0.genres.contains(genre) })
        }
        return [Shelf(id: "trending", title: "Trending now", series: all)] + byGenre
    }

    func series(id: String) async throws -> Series {
        guard let series = all.first(where: { $0.id == id }) else { throw CatalogError.notFound }
        return series
    }
}
