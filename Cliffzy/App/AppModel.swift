import Foundation
import Observation

enum AppTab: Hashable {
    case forYou, discover, myList, profile
}

/// Shared services and app-wide UI state, injected once at the root.
@MainActor
@Observable
final class AppModel {
    let api: any CliffzyAPI
    let account: AccountStore
    let purchases: PurchaseService
    let library: LibraryStore
    @ObservationIgnored let players = PlayerPool()

    var selectedTab: AppTab = .forYou
    /// The VIP paywall opened from outside a series (Profile, the crown in the feed header).
    var paywallPresented = false {
        didSet { if !paywallPresented { paywallEpisode = nil } }
    }
    /// Episode the paywall opens for, when it is opened to unlock one.
    var paywallEpisode: Episode?
    /// A series player opened from outside a tab (demo screens, deep links later).
    var presentedSeries: SeriesSelection?

    /// The catalog, shared by every tab so they show the same series without refetching.
    private(set) var allSeries: [Series] = []
    private(set) var shelves: [Shelf] = []
    private(set) var genres: [String] = []
    private(set) var catalogState: LoadState = .idle
    /// Episodes the server refused to play (402) since the detail loaded: shown locked.
    private(set) var refusedEpisodeIDs: Set<String> = []

    enum LoadState: Equatable {
        case idle, loading, loaded, failed(String)
    }

    init(api: any CliffzyAPI = AppConfig.makeAPI(), account: AccountStore? = nil, defaults: UserDefaults = .standard) {
        let account = account ?? AccountStore(defaults: defaults)
        self.api = api
        self.account = account
        library = LibraryStore(api: api, defaults: defaults)
        purchases = PurchaseService(api: api, account: account, previewStore: api is DemoAPI)
        players.resolver = { [api] episode in
            try await api.playback(seriesID: episode.seriesID, episode: episode.number)
        }
        players.onFailure = { [weak self] episode, error in
            guard let self, (error as? APIError) == .vipRequired else { return }
            self.refusedEpisodeIDs.insert(episode.id)
            // VIP may have just ended: read the account again.
            Task { await self.refreshAccount() }
        }
    }

    // MARK: Startup

    /// Account, catalog, purchases and library in parallel.
    func start() async {
        async let catalog: Void = loadCatalogIfNeeded()
        async let products: Void = purchases.loadProducts()
        await refreshAccount()
        _ = await (catalog, products)
        await purchases.syncWithServer()
        await library.refresh()
    }

    func refreshAccount() async {
        if let me = try? await api.me() { account.apply(me) }
    }

    func loadCatalogIfNeeded() async {
        guard catalogState == .idle else { return }
        await reloadCatalog()
    }

    func reloadCatalog() async {
        catalogState = .loading
        do {
            let feed = try await api.home()
            let newest = Set(feed.shelves.first { $0.id == "new" }?.items.prefix(3).map(\.id) ?? [])
            let previous = Dictionary(allSeries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            allSeries = feed.all.enumerated().map { index, card in
                let fresh = Series(card: card, paletteIndex: index, badge: newest.contains(card.id) ? "New" : nil)
                // Keep episodes already loaded for a series whose episode count did not change.
                if let old = previous[card.id], old.hasEpisodes, old.episodeCount == card.episodeCount {
                    var kept = old
                    kept.badge = fresh.badge
                    kept.posterURL = card.posterUrl ?? old.posterURL
                    return kept
                }
                return fresh
            }
            let byID = Dictionary(allSeries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            shelves = feed.shelves.compactMap { row in
                let items = row.items.compactMap { byID[$0.id] }
                guard !items.isEmpty else { return nil }
                return Shelf(id: row.id, title: row.title, series: items, style: row.ranked == true ? .ranked : .posters)
            }
            genres = feed.genres
            library.apply(continueWatching: feed.continueWatching)
            catalogState = .loaded
            if let screen = DemoScreen.requested { await applyDemoScreen(screen) }
        } catch {
            catalogState = allSeries.isEmpty ? .failed(error.localizedDescription) : .loaded
        }
    }

    // MARK: Series

    func series(id: String) -> Series? {
        allSeries.first { $0.id == id }
    }

    /// The series with its episode list and access rules, from the cache or the server.
    func detailedSeries(_ series: Series, refresh: Bool = false) async throws -> Series {
        if !refresh, let cached = self.series(id: series.id), cached.hasEpisodes { return cached }
        let detail = try await api.series(id: series.id)
        let base = self.series(id: series.id) ?? series
        let updated = base.applying(detail)
        if let index = allSeries.firstIndex(where: { $0.id == series.id }) {
            allSeries[index] = updated
        }
        refusedEpisodeIDs.subtract(updated.episodes.map(\.id))
        return updated
    }

    /// Whether an episode plays now: the server's answer, opened by VIP bought since, closed by a 402.
    func access(for episode: Episode) -> EpisodeAccess {
        if refusedEpisodeIDs.contains(episode.id) && !account.isVIP { return .locked }
        return account.access(for: episode)
    }

    /// VIP turned on: episodes the server refused get a fresh link.
    func vipDidChange() {
        guard account.isVIP else { return }
        refusedEpisodeIDs.removeAll()
        players.forgetFailures()
    }

    /// Where to resume a series: the last watched episode, or 1.
    func resumeEpisode(for series: Series) -> Int {
        library.lastEpisode[series.id] ?? 1
    }

    // MARK: Account

    /// "Delete account": the server removes the account, history and My List; a new anonymous
    /// account is made on the next request. The App Store subscription itself is not cancelled.
    func deleteAccount() async throws {
        try await api.deleteAccount()
        account.reset()
        library.clear()
        players.removeAll()
        refusedEpisodeIDs.removeAll()
        await refreshAccount()
    }
}
