import Foundation

/// All pricing knobs in one place. Ships with defaults; later fetched from the backend
/// so prices and the free-episode count can change without an App Store release.
struct MonetizationConfig: Codable, Hashable, Sendable {
    var freeEpisodes: Int
    var episodePriceCoins: Int
    var dailyBonusCoins: Int
    /// Reward on day 7 of the check-in streak.
    var weeklyBonusCoins: Int
    var coinPacks: [CoinPack]
    var vipProductIDs: [String]

    var allProductIDs: [String] {
        coinPacks.map(\.productID) + vipProductIDs
    }

    func coins(forProductID id: String) -> Int? {
        pack(forProductID: id)?.coins
    }

    func pack(forProductID id: String) -> CoinPack? {
        coinPacks.first { $0.productID == id }
    }

    static let `default` = MonetizationConfig(
        freeEpisodes: 5,
        episodePriceCoins: 60,
        dailyBonusCoins: 10,
        weeklyBonusCoins: 30,
        coinPacks: [
            CoinPack(productID: "com.cliffzy.coins.500", coins: 500),
            CoinPack(productID: "com.cliffzy.coins.1100", coins: 1100, bonusPercent: 10),
            CoinPack(productID: "com.cliffzy.coins.2400", coins: 2400, bonusPercent: 20),
        ],
        vipProductIDs: [
            "com.cliffzy.vip.weekly",
            "com.cliffzy.vip.yearly",
        ]
    )
}

struct CoinPack: Codable, Hashable, Identifiable, Sendable {
    let productID: String
    let coins: Int
    /// Bonus shown on the pack, in percent ("+10%").
    var bonusPercent: Int = 0

    var id: String { productID }
}
