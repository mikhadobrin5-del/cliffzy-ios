import AVFoundation

/// Keeps a few ready AVPlayers so the next swipe starts without a spinner.
///
/// Video links are signed by the server and live about 6 hours, so a player is handed out at once
/// and gets its item when the link arrives (AVPlayer starts as soon as an item is set if `play()`
/// was already called). A link close to expiry is fetched again before reuse. Players are keyed by
/// episode ID and evicted least-recently-used.
@MainActor
final class PlayerPool {
    typealias Resolver = @Sendable (Episode) async throws -> PlaybackLink

    private struct Entry {
        let player: AVPlayer
        var expiry: Date?
        var task: Task<Void, Never>?
        var failedAt: Date?
    }

    private var entries: [String: Entry] = [:]
    private var order: [String] = []
    private let capacity: Int

    /// Gets the signed link for an episode (`GET /v1/series/{id}/episodes/{n}/playback`).
    var resolver: Resolver?
    /// The server refused the link (402: VIP needed, or another error); the UI shows the lock or a retry.
    var onFailure: ((Episode, Error) -> Void)?

    init(capacity: Int = 5) {
        self.capacity = capacity
    }

    func player(for episode: Episode) -> AVPlayer {
        if let entry = entries[episode.id] {
            touch(episode.id)
            // A failed link is retried at most every 5 s, however often SwiftUI asks for the player.
            let retry = entry.task == nil && (entry.failedAt.map { -$0.timeIntervalSinceNow > 5 } ?? true)
            let expiring = entry.expiry.map { $0.timeIntervalSinceNow < 120 } ?? false
            if (retry || expiring) && entry.player.timeControlStatus != .playing {
                load(episode)
            }
            return entry.player
        }
        let player = AVPlayer()
        player.automaticallyWaitsToMinimizeStalling = true
        entries[episode.id] = Entry(player: player)
        touch(episode.id)
        load(episode)
        evictIfNeeded()
        return player
    }

    /// Creates players for upcoming episodes so they start buffering.
    func preload(_ episodes: [Episode]) {
        for episode in episodes.prefix(capacity - 1) {
            _ = player(for: episode)
        }
    }

    /// Fetches a new link, for example after VIP turned on or the network came back.
    func reload(_ episode: Episode) {
        guard entries[episode.id] != nil else { return }
        entries[episode.id]?.failedAt = nil
        load(episode)
    }

    /// Lets every refused link be fetched again on the next request (VIP just turned on).
    func forgetFailures() {
        for id in entries.keys where entries[id]?.task == nil {
            entries[id]?.failedAt = nil
        }
    }

    func position(of episode: Episode) -> Double {
        entries[episode.id]?.player.currentTime().seconds ?? 0
    }

    func pauseAll(except episodeID: String? = nil) {
        for (id, entry) in entries where id != episodeID {
            entry.player.pause()
        }
    }

    func removeAll() {
        for entry in entries.values {
            entry.task?.cancel()
            entry.player.pause()
        }
        entries.removeAll()
        order.removeAll()
    }

    private func load(_ episode: Episode) {
        guard let resolver else { return }
        let id = episode.id
        entries[id]?.task?.cancel()
        entries[id]?.task = Task { [weak self] in
            do {
                let link = try await resolver(episode)
                guard !Task.isCancelled, let self, let entry = self.entries[id] else { return }
                let item = AVPlayerItem(url: link.url)
                item.preferredForwardBufferDuration = 4
                let resumeAt = entry.player.currentItem == nil ? nil : entry.player.currentTime()
                entry.player.replaceCurrentItem(with: item)
                if let resumeAt, resumeAt.seconds > 1 {
                    _ = await entry.player.seek(to: resumeAt)
                }
                self.entries[id]?.expiry = link.expiry
                self.entries[id]?.failedAt = nil
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.entries[id]?.task = nil
                self.entries[id]?.failedAt = Date()
                self.onFailure?(episode, error)
            }
        }
    }

    private func touch(_ id: String) {
        order.removeAll { $0 == id }
        order.append(id)
    }

    private func evictIfNeeded() {
        while order.count > capacity {
            let id = order.removeFirst()
            entries[id]?.task?.cancel()
            entries[id]?.player.pause()
            entries[id] = nil
        }
    }
}
