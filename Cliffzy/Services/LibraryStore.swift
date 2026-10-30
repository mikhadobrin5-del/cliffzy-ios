import Foundation
import Observation

/// "My List" favourites and where the viewer stopped in each series.
@MainActor
@Observable
final class LibraryStore {
    private(set) var favoriteSeriesIDs: [String]
    /// Series ID → last episode number watched, most recent first in `recentSeriesIDs`.
    private(set) var lastEpisode: [String: Int]
    private(set) var recentSeriesIDs: [String]
    private(set) var likedSeriesIDs: Set<String>

    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let favorites = "library.favorites"
        static let lastEpisode = "library.lastEpisode"
        static let recent = "library.recent"
        static let liked = "library.liked"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favoriteSeriesIDs = defaults.stringArray(forKey: Key.favorites) ?? []
        lastEpisode = defaults.dictionary(forKey: Key.lastEpisode) as? [String: Int] ?? [:]
        recentSeriesIDs = defaults.stringArray(forKey: Key.recent) ?? []
        likedSeriesIDs = Set(defaults.stringArray(forKey: Key.liked) ?? [])
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
        save()
    }

    /// Episodes the viewer has reached in a series, for "Episode 4 of 68" and progress bars.
    func watchedUpTo(_ seriesID: String) -> Int? {
        lastEpisode[seriesID]
    }

    func clearHistory() {
        lastEpisode.removeAll()
        recentSeriesIDs.removeAll()
        save()
    }

    func isFavorite(_ seriesID: String) -> Bool {
        favoriteSeriesIDs.contains(seriesID)
    }

    func toggleFavorite(_ seriesID: String) {
        if let index = favoriteSeriesIDs.firstIndex(of: seriesID) {
            favoriteSeriesIDs.remove(at: index)
        } else {
            favoriteSeriesIDs.insert(seriesID, at: 0)
        }
        save()
    }

    func recordWatched(seriesID: String, episodeNumber: Int) {
        lastEpisode[seriesID] = episodeNumber
        recentSeriesIDs.removeAll { $0 == seriesID }
        recentSeriesIDs.insert(seriesID, at: 0)
        save()
    }

    private func save() {
        defaults.set(favoriteSeriesIDs, forKey: Key.favorites)
        defaults.set(lastEpisode, forKey: Key.lastEpisode)
        defaults.set(recentSeriesIDs, forKey: Key.recent)
        defaults.set(Array(likedSeriesIDs), forKey: Key.liked)
    }
}
