import Foundation

/// Opens a given screen with sample progress, for screenshots and quick manual checks.
/// Launch with `-CliffzyScreen <name>` (Xcode scheme argument or `simctl launch`).
/// Names: feed, series, locked, episodes, paywall, discover, mylist, profile.
enum DemoScreen: String, CaseIterable {
    case feed, series, locked, episodes, paywall, discover, mylist, profile

    static var requested: DemoScreen? {
        UserDefaults.standard.string(forKey: "CliffzyScreen").flatMap(DemoScreen.init(rawValue:))
    }
}

extension AppModel {
    /// Seeds sample state and routes to the requested screen. Call after the catalog loads.
    func applyDemoScreen(_ screen: DemoScreen) {
        guard let first = allSeries.first else { return }
        #if DEBUG
        entitlements.debugResetUnlocks()
        entitlements.debugAddCoins(40 - entitlements.coins)
        #endif
        let seeds = allSeries.prefix(4)
        for (index, series) in seeds.enumerated().reversed() {
            library.recordWatched(seriesID: series.id, episodeNumber: [4, 12, 2, 7][index])
            if !library.isFavorite(series.id) { library.toggleFavorite(series.id) }
        }

        switch screen {
        case .feed:
            selectedTab = .forYou
        case .discover:
            selectedTab = .discover
        case .mylist:
            selectedTab = .myList
        case .profile:
            selectedTab = .profile
        case .series:
            presentedSeries = SeriesSelection(series: first, episode: 4)
        case .locked:
            presentedSeries = SeriesSelection(series: first, episode: 6)
        case .episodes:
            presentedSeries = SeriesSelection(series: first, episode: 4, showsEpisodes: true)
        case .paywall:
            selectedTab = .discover
            shopEpisode = first.episode(number: 6)
            shopPresented = true
        }
    }
}
