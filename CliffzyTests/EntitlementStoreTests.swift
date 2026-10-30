import XCTest
@testable import Cliffzy

@MainActor
final class EntitlementStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: EntitlementStore!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "EntitlementStoreTests")
        defaults.removePersistentDomain(forName: "EntitlementStoreTests")
        store = EntitlementStore(config: .default, defaults: defaults)
    }

    private func episode(_ number: Int) -> Episode {
        Episode(
            id: "s1-e\(number)",
            seriesID: "s1",
            number: number,
            title: "Episode \(number)",
            duration: 90,
            streamURL: URL(string: "https://example.com/\(number).m3u8")!
        )
    }

    func testFirstEpisodesAreFree() {
        XCTAssertEqual(store.access(for: episode(1)), .free)
        XCTAssertEqual(store.access(for: episode(5)), .free)
        XCTAssertEqual(store.access(for: episode(6)), .locked(priceCoins: 60))
    }

    func testUnlockSpendsCoins() throws {
        store.credit(coins: 100, transactionID: "t1")
        try store.unlock(episode(6))
        XCTAssertEqual(store.coins, 40)
        XCTAssertEqual(store.access(for: episode(6)), .unlocked)
    }

    func testUnlockFailsWithoutCoins() {
        XCTAssertThrowsError(try store.unlock(episode(6))) { error in
            XCTAssertEqual(error as? UnlockError, .notEnoughCoins(needed: 60))
        }
        XCTAssertEqual(store.coins, 0)
    }

    func testVIPOpensEverything() {
        store.setVIP(true)
        XCTAssertEqual(store.access(for: episode(20)), .vip)
    }

    func testSameTransactionCreditedOnce() {
        XCTAssertTrue(store.credit(coins: 500, transactionID: "t1"))
        XCTAssertFalse(store.credit(coins: 500, transactionID: "t1"))
        XCTAssertEqual(store.coins, 500)
    }

    func testDailyBonusOncePerDay() {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(store.claimDailyBonus(now: day))
        XCTAssertFalse(store.claimDailyBonus(now: day.addingTimeInterval(60)))
        XCTAssertTrue(store.claimDailyBonus(now: day.addingTimeInterval(86_400)))
        XCTAssertEqual(store.coins, 20)
    }

    func testSeventhDayPaysWeeklyBonus() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for day in 0..<7 {
            XCTAssertTrue(store.claimDailyBonus(now: start.addingTimeInterval(Double(day) * 86_400)))
        }
        XCTAssertEqual(store.checkInStreak, 7)
        XCTAssertEqual(store.coins, 6 * 10 + 30)
    }

    func testMissedDayRestartsStreak() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        store.claimDailyBonus(now: start)
        store.claimDailyBonus(now: start.addingTimeInterval(86_400))
        XCTAssertEqual(store.checkInStreak, 2)
        store.claimDailyBonus(now: start.addingTimeInterval(4 * 86_400))
        XCTAssertEqual(store.checkInStreak, 1)
    }

    func testCoinsNeeded() {
        store.credit(coins: 40, transactionID: "t1")
        XCTAssertEqual(store.coinsNeeded(for: episode(6)), 20)
        XCTAssertEqual(store.coinsNeeded(for: episode(1)), 0)
    }

    func testStatePersists() throws {
        store.credit(coins: 100, transactionID: "t1")
        try store.unlock(episode(7))
        let reloaded = EntitlementStore(config: .default, defaults: defaults)
        XCTAssertEqual(reloaded.coins, 40)
        XCTAssertEqual(reloaded.access(for: episode(7)), .unlocked)
    }
}
