import Foundation
import Observation

/// My List and watch history, kept on the server so they follow the account.
/// Changes show at once and are sent in the background; likes stay on the device.
@MainActor
@Observable
final class LibraryStore {
    private(set) var favoriteSeriesIDs: [String] = []
    /// Series ID → last episode reached; `recentSeriesIDs` is most recent first.
    private(set) var lastEpisode: [String: Int] = [:]
    private(set) var recentSeriesIDs: [String] = []
    private(set) var likedSeriesIDs: Set<String>

    @ObservationIgnored private let api: any CliffzyAPI
    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let liked = "library.liked"
    }

    init(api: any CliffzyAPI, defaults: UserDefaults = .standard) {
        self.api = api
        self.defaults = defaults
        likedSeriesIDs = Set(defaults.stringArray(forKey: Key.liked) ?? [])
    }

    /// Reloads My List and history from the server.
    func refresh() async {
        async let list = api.myList()
        async let history = api.history()
        if let list = try? await list {
            favoriteSeriesIDs = list.map(\.id)
        }
        if let history = try? await history {
            recentSeriesIDs = history.map(\.series.id)
            lastEpisode = Dictionary(history.map { ($0.series.id, $0.episode) }, uniquingKeysWith: { first, _ in first })
        }
    }

    /// "Continue watching" from the home feed, so it shows before the history request returns.
    func apply(continueWatching items: [ContinueItem]) {
        for item in items.reversed() where !recentSeriesIDs.contains(item.series.id) {
            recentSeriesIDs.insert(item.series.id, at: 0)
            lastEpisode[item.series.id] = item.episode
        }
    }

    func isLiked(_ seriesID: String) -> Bool {
        likedSeriesIDs.contains(seriesID)
    }

    func toggleLike(_ seriesID: String) {
        if likedSeriesIDs.contains(seriesID) {
            likedSeriesIDs.remove(seriesID)
        } else {
            likedSeriesIDs.insert(seriesID)
        }
        defaults.set(Array(likedSeriesIDs), forKey: Key.liked)
    }

    func watchedUpTo(_ seriesID: String) -> Int? {
        lastEpisode[seriesID]
    }

    func isFavorite(_ seriesID: String) -> Bool {
        favoriteSeriesIDs.contains(seriesID)
    }

    func toggleFavorite(_ seriesID: String) {
        let adding = !isFavorite(seriesID)
        if adding {
            favoriteSeriesIDs.insert(seriesID, at: 0)
        } else {
            favoriteSeriesIDs.removeAll { $0 == seriesID }
        }
        let api = api
        Task {
            do {
                if adding { try await api.save(seriesID: seriesID) } else { try await api.unsave(seriesID: seriesID) }
            } catch {
                // Put it back as the server has it.
                if adding { favoriteSeriesIDs.removeAll { $0 == seriesID } } else if !isFavorite(seriesID) { favoriteSeriesIDs.insert(seriesID, at: 0) }
            }
        }
    }

    /// Where the viewer is: shown at once, saved on the server for Continue watching on any device.
    func recordWatched(seriesID: String, episodeNumber: Int, positionSec: Int = 0) {
        lastEpisode[seriesID] = episodeNumber
        recentSeriesIDs.removeAll { $0 == seriesID }
        recentSeriesIDs.insert(seriesID, at: 0)
        let api = api
        Task.detached {
            try? await api.reportProgress(seriesID: seriesID, episode: episodeNumber, positionSec: positionSec)
        }
    }

    /// After the account is deleted.
    func clear() {
        favoriteSeriesIDs = []
        lastEpisode = [:]
        recentSeriesIDs = []
        likedSeriesIDs = []
        defaults.removeObject(forKey: Key.liked)
    }
}
