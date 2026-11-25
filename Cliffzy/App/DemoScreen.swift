import Foundation

/// Opens a given screen with sample progress on the demo server, for screenshots and quick checks.
/// Launch with `-CliffzyScreen <name>` (Xcode scheme argument or `simctl launch`).
/// Names: feed, series, locked, episodes, paywall, discover, mylist, profile.
enum DemoScreen: String, CaseIterable {
    case feed, series, locked, episodes, paywall, discover, mylist, profile

    static var requested: DemoScreen? {
        UserDefaults.standard.string(forKey: "CliffzyScreen").flatMap(DemoScreen.init(rawValue:))
    }
}

extension AppModel {
    /// Seeds sample history on the demo server and routes to the requested screen.
    func applyDemoScreen(_ screen: DemoScreen) async {
        guard api is DemoAPI, let first = allSeries.first else { return }
        for (index, series) in allSeries.prefix(4).enumerated().reversed() {
            try? await api.reportProgress(seriesID: series.id, episode: [4, 12, 2, 7][index], positionSec: 30)
            try? await api.save(seriesID: series.id)
        }
        await library.refresh()
        guard let detailed = try? await detailedSeries(first) else { return }

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
            presentedSeries = SeriesSelection(series: detailed, episode: 4)
        case .locked:
            presentedSeries = SeriesSelection(series: detailed, episode: 6)
        case .episodes:
            presentedSeries = SeriesSelection(series: detailed, episode: 4, showsEpisodes: true)
        case .paywall:
            selectedTab = .discover
            paywallEpisode = detailed.episode(number: 6)
            paywallPresented = true
        }
    }
}
