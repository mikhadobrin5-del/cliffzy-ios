import AVFoundation

/// Keeps a few ready AVPlayers so the next swipe starts playing without a spinner.
/// Players are keyed by episode ID and evicted least-recently-used.
@MainActor
final class PlayerPool {
    private var players: [String: AVPlayer] = [:]
    private var order: [String] = []
    private let capacity: Int

    init(capacity: Int = 5) {
        self.capacity = capacity
    }

    func player(for episode: Episode) -> AVPlayer {
        if let player = players[episode.id] {
            touch(episode.id)
            return player
        }
        let item = AVPlayerItem(url: episode.streamURL)
        item.preferredForwardBufferDuration = 4
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true
        players[episode.id] = player
        touch(episode.id)
        evictIfNeeded()
        return player
    }

    /// Creates players for upcoming episodes so they start buffering.
    func preload(_ episodes: [Episode]) {
        for episode in episodes.prefix(capacity - 1) {
            _ = player(for: episode)
        }
    }

    func pauseAll(except episodeID: String? = nil) {
        for (id, player) in players where id != episodeID {
            player.pause()
        }
    }

    func removeAll() {
        players.values.forEach { $0.pause() }
        players.removeAll()
        order.removeAll()
    }

    private func touch(_ id: String) {
        order.removeAll { $0 == id }
        order.append(id)
    }

    private func evictIfNeeded() {
        while order.count > capacity {
            let id = order.removeFirst()
            players[id]?.pause()
            players[id] = nil
        }
    }
}
