import Foundation
import Observation

/// The viewer's account as the server sees it: VIP status and until when.
/// The server decides access; this copy only drives the UI and is cached for a fast start.
@MainActor
@Observable
final class AccountStore {
    private(set) var isVIP: Bool
    private(set) var vipUntil: Date?
    private(set) var userID: String?

    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let vip = "account.vip"
        static let vipUntil = "account.vipUntil"
        static let userID = "account.userId"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        vipUntil = defaults.object(forKey: Key.vipUntil) as? Date
        isVIP = defaults.bool(forKey: Key.vip) && (vipUntil ?? .distantFuture) > Date()
        userID = defaults.string(forKey: Key.userID)
    }

    func apply(_ me: Me) {
        isVIP = me.vip
        vipUntil = me.vipExpiry
        userID = me.userId
        defaults.set(isVIP, forKey: Key.vip)
        defaults.set(vipUntil, forKey: Key.vipUntil)
        defaults.set(userID, forKey: Key.userID)
    }

    /// Locked episodes open as soon as VIP turns on, without reloading every series.
    func access(for episode: Episode) -> EpisodeAccess {
        if episode.access == .locked && isVIP { return .vip }
        return episode.access
    }

    func reset() {
        isVIP = false
        vipUntil = nil
        userID = nil
        [Key.vip, Key.vipUntil, Key.userID].forEach(defaults.removeObject(forKey:))
    }
}
