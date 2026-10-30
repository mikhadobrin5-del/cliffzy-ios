import Foundation
import Observation

enum EpisodeAccess: Equatable {
    case free
    case unlocked
    case vip
    case locked(priceCoins: Int)

    var isPlayable: Bool {
        if case .locked = self { return false }
        return true
    }
}

enum UnlockError: Error, Equatable {
    case notEnoughCoins(needed: Int)
}

/// Coins, VIP status, unlocked episodes and the daily check-in streak.
///
/// MVP keeps this on the device. Before launch the wallet moves to the backend:
/// a local balance is trivial to tamper with.
@MainActor
@Observable
final class EntitlementStore {
    private(set) var coins: Int
    private(set) var isVIP: Bool
    private(set) var unlockedEpisodeIDs: Set<String>
    private(set) var lastDailyBonus: Date?
    /// Days claimed in the current 7-day cycle (0...7).
    private(set) var checkInStreak: Int

    let config: MonetizationConfig

    @ObservationIgnored private var creditedTransactionIDs: Set<String>
    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let coins = "entitlements.coins"
        static let vip = "entitlements.vip"
        static let unlocked = "entitlements.unlocked"
        static let dailyBonus = "entitlements.dailyBonus"
        static let streak = "entitlements.streak"
        static let credited = "entitlements.creditedTransactions"
    }

    init(config: MonetizationConfig = .default, defaults: UserDefaults = .standard) {
        self.config = config
        self.defaults = defaults
        coins = defaults.integer(forKey: Key.coins)
        isVIP = defaults.bool(forKey: Key.vip)
        unlockedEpisodeIDs = Set(defaults.stringArray(forKey: Key.unlocked) ?? [])
        lastDailyBonus = defaults.object(forKey: Key.dailyBonus) as? Date
        checkInStreak = defaults.integer(forKey: Key.streak)
        creditedTransactionIDs = Set(defaults.stringArray(forKey: Key.credited) ?? [])
    }

    func access(for episode: Episode) -> EpisodeAccess {
        if episode.number <= config.freeEpisodes { return .free }
        if isVIP { return .vip }
        if unlockedEpisodeIDs.contains(episode.id) { return .unlocked }
        return .locked(priceCoins: config.episodePriceCoins)
    }

    func coinsNeeded(for episode: Episode) -> Int {
        guard case .locked(let price) = access(for: episode) else { return 0 }
        return max(price - coins, 0)
    }

    func unlock(_ episode: Episode) throws {
        guard case .locked(let price) = access(for: episode) else { return }
        guard coins >= price else { throw UnlockError.notEnoughCoins(needed: price - coins) }
        coins -= price
        unlockedEpisodeIDs.insert(episode.id)
        save()
    }

    /// Credits a coin purchase once per transaction, even if StoreKit reports it twice.
    @discardableResult
    func credit(coins amount: Int, transactionID: String) -> Bool {
        guard !creditedTransactionIDs.contains(transactionID) else { return false }
        creditedTransactionIDs.insert(transactionID)
        coins += amount
        save()
        return true
    }

    func setVIP(_ active: Bool) {
        guard isVIP != active else { return }
        isVIP = active
        save()
    }

    // MARK: Daily check-in

    func canClaimDailyBonus(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let last = lastDailyBonus else { return true }
        return !calendar.isDate(last, inSameDayAs: now)
    }

    /// Reward for a given day of the 7-day cycle (1...7).
    func dailyReward(day: Int) -> Int {
        day == 7 ? config.weeklyBonusCoins : config.dailyBonusCoins
    }

    /// The day of the cycle the next claim counts as.
    func nextCheckInDay(now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let last = lastDailyBonus,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
              calendar.isDate(last, inSameDayAs: yesterday) || calendar.isDate(last, inSameDayAs: now)
        else { return 1 }
        return checkInStreak % 7 + 1
    }

    @discardableResult
    func claimDailyBonus(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard canClaimDailyBonus(now: now, calendar: calendar) else { return false }
        let day = nextCheckInDay(now: now, calendar: calendar)
        coins += dailyReward(day: day)
        checkInStreak = day
        lastDailyBonus = now
        save()
        return true
    }

    // MARK: Developer tools (DEBUG builds only)

    #if DEBUG
    func debugAddCoins(_ amount: Int) {
        coins += amount
        save()
    }

    func debugResetUnlocks() {
        unlockedEpisodeIDs.removeAll()
        save()
    }

    func debugResetDailyBonus() {
        lastDailyBonus = nil
        checkInStreak = 0
        save()
    }
    #endif

    private func save() {
        defaults.set(coins, forKey: Key.coins)
        defaults.set(isVIP, forKey: Key.vip)
        defaults.set(Array(unlockedEpisodeIDs), forKey: Key.unlocked)
        defaults.set(lastDailyBonus, forKey: Key.dailyBonus)
        defaults.set(checkInStreak, forKey: Key.streak)
        defaults.set(Array(creditedTransactionIDs), forKey: Key.credited)
    }
}
