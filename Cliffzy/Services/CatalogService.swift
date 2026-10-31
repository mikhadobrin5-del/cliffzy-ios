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
    let all: [Series]

    init() {
        let streams = [
            "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
            "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8",
            "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8",
        ].compactMap(URL.init(string:))

        struct Seed {
            let title: String
            let synopsis: String
            let genres: [String]
            let episodes: Int
            let views: Int
            let badge: String?
        }

        let seeds = [
            Seed(title: "The Billionaire's Secret Bride", synopsis: "She signed a contract marriage. He never planned to fall in love.", genres: ["Romance", "CEO"], episodes: 40, views: 12_400_000, badge: "Hot"),
            Seed(title: "Reborn to Take Revenge", synopsis: "Betrayed and left to die, she wakes up ten years in the past.", genres: ["Revenge", "Rebirth"], episodes: 32, views: 8_900_000, badge: "Hot"),
            Seed(title: "Alpha's Rejected Mate", synopsis: "Rejected on the night of the full moon, she rises as a queen.", genres: ["Werewolf", "Romance"], episodes: 36, views: 6_100_000, badge: nil),
            Seed(title: "My Husband Is the Boss", synopsis: "The quiet intern she married owns the company she works for.", genres: ["CEO", "Comedy"], episodes: 28, views: 4_700_000, badge: "New"),
            Seed(title: "The Heiress Returns", synopsis: "Thrown out as a fake daughter, the real heiress comes back.", genres: ["Family", "Revenge"], episodes: 30, views: 3_900_000, badge: nil),
            Seed(title: "Midnight Contract", synopsis: "One night, one deal, and a secret that could ruin them both.", genres: ["Thriller", "Romance"], episodes: 24, views: 2_800_000, badge: "New"),
            Seed(title: "Divorced, Then Adored", synopsis: "He signed the papers. Now he will do anything to win her back.", genres: ["Romance", "Drama"], episodes: 34, views: 2_200_000, badge: nil),
            Seed(title: "The Mafia Don's Nanny", synopsis: "She took the job to pay rent. She did not expect his rules.", genres: ["Mafia", "Romance"], episodes: 30, views: 1_600_000, badge: "Exclusive"),
            Seed(title: "Twin Sister Swap", synopsis: "One twin vanished. The other took her place and her fiancé.", genres: ["Thriller", "Family"], episodes: 26, views: 980_000, badge: "New"),
            Seed(title: "Queen of the Underground", synopsis: "By day a waitress, by night the boss nobody has ever seen.", genres: ["Revenge", "Mafia"], episodes: 38, views: 740_000, badge: nil),
        ]

        all = seeds.enumerated().map { index, seed in
            let seriesID = "s\(index + 1)"
            let episodes = (1...seed.episodes).map { number in
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
                title: seed.title,
                synopsis: seed.synopsis,
                genres: seed.genres,
                posterURL: nil,
                episodes: episodes,
                badge: seed.badge,
                views: seed.views,
                paletteIndex: index
            )
        }
    }

    func feed() async throws -> [Series] {
        all
    }

    func shelves() async throws -> [Shelf] {
        let ranked = all.sorted { $0.views > $1.views }
        let fresh = all.filter { $0.badge == "New" }
        let genres = ["Romance", "Revenge", "CEO", "Thriller", "Mafia"]
        let byGenre = genres.map { genre in
            Shelf(id: genre, title: genre, series: all.filter { $0.genres.contains(genre) })
        }
        return [
            Shelf(id: "top10", title: "Top 10 this week", series: Array(ranked.prefix(10)), style: .ranked),
            Shelf(id: "new", title: "New releases", series: fresh),
        ] + byGenre
    }

    func series(id: String) async throws -> Series {
        guard let series = all.first(where: { $0.id == id }) else { throw CatalogError.notFound }
        return series
    }
}
