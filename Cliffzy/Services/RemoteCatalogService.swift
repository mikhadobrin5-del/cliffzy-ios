import Foundation

/// Catalog read from one JSON file on Cliffzy's own server.
///
/// The file format is documented in `wiki/catalog-format.md` and an example lives in
/// `docs/catalog.example.json`. Relative links inside the file (posters, videos) are
/// resolved against the catalog URL, so the JSON can sit next to the media folders.
/// The last good copy is kept on disk and used when the network is down.
struct RemoteCatalogService: CatalogService {
    typealias Loader = @Sendable (URL) async throws -> Data

    let url: URL
    private let load: Loader
    private let cacheFile: URL?

    init(url: URL, cacheFile: URL? = RemoteCatalogService.defaultCacheFile, load: Loader? = nil) {
        self.url = url
        self.cacheFile = cacheFile
        self.load = load ?? { url in
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadRevalidatingCacheData
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw CatalogError.badStatus(http.statusCode)
            }
            return data
        }
    }

    static var defaultCacheFile: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("catalog.json")
    }

    func feed() async throws -> [Series] {
        try await document().series
    }

    func shelves() async throws -> [Shelf] {
        try await document().shelves
    }

    func series(id: String) async throws -> Series {
        guard let series = try await document().series.first(where: { $0.id == id }) else {
            throw CatalogError.notFound
        }
        return series
    }

    // MARK: - Loading

    private func document() async throws -> CatalogDocument {
        do {
            let data = try await load(url)
            let document = try CatalogDocument.decode(data, baseURL: url)
            if let cacheFile { try? data.write(to: cacheFile, options: .atomic) }
            return document
        } catch {
            // Offline or a bad deploy: fall back to the last catalog that worked.
            if let cacheFile, let data = try? Data(contentsOf: cacheFile),
               let cached = try? CatalogDocument.decode(data, baseURL: url) {
                return cached
            }
            throw error
        }
    }
}

/// The parsed catalog file: series in feed order plus Discover shelves.
struct CatalogDocument: Sendable {
    let series: [Series]
    let shelves: [Shelf]

    static func decode(_ data: Data, baseURL: URL) throws -> CatalogDocument {
        let file = try JSONDecoder().decode(CatalogFile.self, from: data)
        guard file.version == 1 else { throw CatalogError.unsupportedVersion(file.version) }

        let series = try file.series.enumerated().map { index, item in
            try item.makeSeries(index: index, baseURL: baseURL)
        }
        guard !series.isEmpty else { throw CatalogError.empty }

        let shelves: [Shelf]
        if let rows = file.shelves, !rows.isEmpty {
            let byID = Dictionary(series.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            shelves = rows.compactMap { row in
                let items = row.series.compactMap { byID[$0] }
                guard !items.isEmpty else { return nil }
                return Shelf(id: row.id, title: row.title, series: items, style: row.style == "ranked" ? .ranked : .posters)
            }
        } else {
            shelves = Shelf.defaultShelves(for: series)
        }
        return CatalogDocument(series: series, shelves: shelves)
    }
}

// MARK: - File format (version 1)

private struct CatalogFile: Decodable {
    let version: Int
    let series: [SeriesItem]
    let shelves: [ShelfItem]?

    struct SeriesItem: Decodable {
        let id: String
        let title: String
        let synopsis: String?
        let genres: [String]?
        let poster: String?
        let badge: String?
        let views: Int?
        let episodes: [EpisodeItem]

        func makeSeries(index: Int, baseURL: URL) throws -> Series {
            let episodes = try self.episodes
                .sorted { $0.number < $1.number }
                .map { episode in
                    guard let stream = URL(string: episode.video, relativeTo: baseURL)?.absoluteURL else {
                        throw CatalogError.badLink(series: id, value: episode.video)
                    }
                    return Episode(
                        id: "\(id)-e\(episode.number)",
                        seriesID: id,
                        number: episode.number,
                        title: episode.title ?? "Episode \(episode.number)",
                        duration: episode.duration ?? 0,
                        streamURL: stream
                    )
                }
            guard !episodes.isEmpty else { throw CatalogError.noEpisodes(series: id) }
            return Series(
                id: id,
                title: title,
                synopsis: synopsis ?? "",
                genres: genres ?? [],
                posterURL: poster.flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL },
                episodes: episodes,
                badge: badge,
                views: views ?? 0,
                paletteIndex: index
            )
        }
    }

    struct EpisodeItem: Decodable {
        let number: Int
        let title: String?
        let duration: TimeInterval?
        let video: String
    }

    struct ShelfItem: Decodable {
        let id: String
        let title: String
        let style: String?
        let series: [String]
    }
}

extension Shelf {
    /// Discover rows built from the series alone, used when the catalog file
    /// lists no shelves of its own: top by views, new releases, then by genre.
    static func defaultShelves(for all: [Series]) -> [Shelf] {
        let ranked = all.sorted { $0.views > $1.views }
        let fresh = all.filter { $0.badge == "New" }
        var genres: [String] = []
        for genre in all.flatMap(\.genres) where !genres.contains(genre) {
            genres.append(genre)
        }
        let byGenre = genres.prefix(6).map { genre in
            Shelf(id: "genre-\(genre)", title: genre, series: all.filter { $0.genres.contains(genre) })
        }
        var rows = [Shelf(id: "top10", title: "Top 10 this week", series: Array(ranked.prefix(10)), style: .ranked)]
        if !fresh.isEmpty { rows.append(Shelf(id: "new", title: "New releases", series: fresh)) }
        return rows + byGenre
    }
}

enum CatalogConfig {
    /// Catalog URL from the `-CliffzyCatalogURL <url>` launch argument (for testing
    /// a server from Xcode) or from the `CATALOG_URL` build setting via Info.plist.
    /// Nil means "use the built-in demo catalog".
    static var url: URL? {
        let defaults = UserDefaults.standard.string(forKey: "CliffzyCatalogURL")
        let plist = Bundle.main.object(forInfoDictionaryKey: "CliffzyCatalogURL") as? String
        for value in [defaults, plist] {
            if let value, !value.isEmpty, !value.hasPrefix("$("), let url = URL(string: value), url.scheme == "https" {
                return url
            }
        }
        return nil
    }

    static func makeService() -> any CatalogService {
        if DemoScreen.requested == nil, let url = url {
            return RemoteCatalogService(url: url)
        }
        return MockCatalogService()
    }
}
