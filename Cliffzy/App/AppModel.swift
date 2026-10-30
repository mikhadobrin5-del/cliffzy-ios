import Foundation
import Observation

enum AppTab: Hashable {
    case forYou, discover, myList, profile
}

/// Shared services and app-wide UI state, injected once at the root.
@MainActor
@Observable
final class AppModel {
    let catalog: any CatalogService
    let entitlements: EntitlementStore
    let purchases: PurchaseService
    let library: LibraryStore
    @ObservationIgnored let players = PlayerPool()

    var selectedTab: AppTab = .forYou
    /// The coin shop (paywall without an episode), opened from any CoinBadge.
    var shopPresented = false

    /// Catalog cache so every tab shows the same series without refetching.
    private(set) var allSeries: [Series] = []
    private(set) var shelves: [Shelf] = []
    private(set) var catalogState: LoadState = .idle

    enum LoadState: Equatable {
        case idle, loading, loaded, failed(String)
    }

    init(
        catalog: any CatalogService = MockCatalogService(),
        entitlements: EntitlementStore = EntitlementStore(),
        library: LibraryStore = LibraryStore()
    ) {
        self.catalog = catalog
        self.entitlements = entitlements
        self.library = library
        purchases = PurchaseService(entitlements: entitlements)
    }

    func loadCatalogIfNeeded() async {
        guard catalogState == .idle else { return }
        await reloadCatalog()
    }

    func reloadCatalog() async {
        catalogState = .loading
        do {
            async let feed = catalog.feed()
            async let rows = catalog.shelves()
            allSeries = try await feed
            shelves = try await rows
            catalogState = .loaded
        } catch {
            catalogState = .failed(error.localizedDescription)
        }
    }

    func series(id: String) -> Series? {
        allSeries.first { $0.id == id }
    }

    /// Where to resume a series: the last watched episode, or 1.
    func resumeEpisode(for series: Series) -> Int {
        library.lastEpisode[series.id] ?? 1
    }
}
