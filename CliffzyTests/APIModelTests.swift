import XCTest
@testable import Cliffzy

/// Responses copied from the live server (cliffzy-api.onrender.com, 2026-11-25), trimmed.
final class APIModelTests: XCTestCase {
    private let detailJSON = """
    {"series":{"id":"cheat-on-me-feed-my-monster","title":"Cheat on Me Feed My Monster",
      "posterUrl":"https://cliffzy-api.onrender.com/v1/posters/cheat-on-me-feed-my-monster.jpg","episodeCount":7,"tags":["Revenge","Fantasy"]},
     "description":"","freeEpisodes":5,
     "episodes":[{"number":2,"durationSec":80,"access":"FREE"},{"number":1,"durationSec":75,"access":"FREE"},
       {"number":3,"durationSec":81,"access":"FREE"},{"number":4,"durationSec":85,"access":"FREE"},
       {"number":5,"durationSec":84,"access":"FREE"},{"number":6,"durationSec":106,"access":"LOCKED"},
       {"number":7,"durationSec":112,"access":"VIP"}],
     "saved":false,"resume":null}
    """

    private let homeJSON = """
    {"banners":[],"continueWatching":[{"series":{"id":"b","title":"B","posterUrl":null,"episodeCount":9,"tags":["Fantasy"]},"episode":3,"positionSec":40,"progress":0.33}],
     "shelves":[{"id":"top","title":"Top 10","items":[{"id":"b","title":"B","posterUrl":null,"episodeCount":9,"tags":["Fantasy"]}],"ranked":true},
                {"id":"new","title":"New releases","items":[{"id":"a","title":"A","posterUrl":"https://x.test/a.jpg","episodeCount":6,"tags":["Romance"]}]}],
     "genres":["Fantasy","Romance"],
     "all":[{"id":"a","title":"A","posterUrl":"https://x.test/a.jpg","episodeCount":6,"tags":["Romance"]},
            {"id":"b","title":"B","posterUrl":null,"episodeCount":9,"tags":["Fantasy"]}]}
    """

    func testSeriesDetailMapsEpisodesInOrderWithAccess() throws {
        let detail = try JSONDecoder().decode(SeriesDetail.self, from: Data(detailJSON.utf8))
        let card = detail.series
        let series = Series(card: card, paletteIndex: 0).applying(detail)

        XCTAssertEqual(series.episodes.map(\.number), Array(1...7))
        XCTAssertEqual(series.freeEpisodes, 5)
        XCTAssertEqual(series.episode(number: 1)?.duration, 75)
        XCTAssertEqual(series.episode(number: 5)?.access, .free)
        XCTAssertEqual(series.episode(number: 6)?.access, .locked)
        XCTAssertEqual(series.episode(number: 7)?.access, .vip)
        XCTAssertEqual(series.episode(number: 6)?.id, "cheat-on-me-feed-my-monster-e6")
        XCTAssertEqual(series.posterURL?.host, "cliffzy-api.onrender.com")
    }

    func testHomeFeedDecodes() throws {
        let feed = try JSONDecoder().decode(HomeFeed.self, from: Data(homeJSON.utf8))
        XCTAssertEqual(feed.all.map(\.id), ["a", "b"])
        XCTAssertNil(feed.all[1].posterUrl)
        XCTAssertEqual(feed.shelves.first?.ranked, true)
        XCTAssertNil(feed.shelves.last?.ranked)
        XCTAssertEqual(feed.continueWatching.first?.episode, 3)
    }

    func testPlaybackAndMe() throws {
        let link = try JSONDecoder().decode(PlaybackLink.self, from: Data(#"{"url":"https://s3.us-east-005.backblazeb2.com/b/ep-0001.mp4?X-Amz-Signature=abc","expiresAt":1795656764}"#.utf8))
        XCTAssertEqual(link.expiry, Date(timeIntervalSince1970: 1_795_656_764))

        let me = try JSONDecoder().decode(Me.self, from: Data(#"{"userId":"7f1c2a52-6a0e-4c43-9a59-2f8f3a1d0b11","vip":true,"vipUntil":1795656764000,"devMode":false}"#.utf8))
        XCTAssertTrue(me.vip)
        XCTAssertEqual(me.vipExpiry, Date(timeIntervalSince1970: 1_795_656_764))

        let none = try JSONDecoder().decode(Me.self, from: Data(#"{"userId":"x","vip":false,"vipUntil":null,"devMode":false}"#.utf8))
        XCTAssertNil(none.vipExpiry)
    }

    func testErrorsFromStatusCodes() {
        XCTAssertEqual(APIError(status: 402, body: Data(#"{"error":"vip_required"}"#.utf8)), .vipRequired)
        XCTAssertEqual(APIError(status: 404, body: Data()), .notFound)
        XCTAssertEqual(APIError(status: 503, body: Data(#"{"error":"billing_not_configured"}"#.utf8)), .server(status: 503, code: "billing_not_configured"))
    }

    @MainActor
    func testVIPOpensLockedEpisodesWithoutReload() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let account = AccountStore(defaults: defaults)
        let locked = Episode(seriesID: "a", number: 6, duration: 60, access: .locked)
        let free = Episode(seriesID: "a", number: 1, duration: 60, access: .free)
        XCTAssertEqual(account.access(for: locked), .locked)

        account.apply(Me(userId: "u", vip: true, vipUntil: Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000, devMode: false))
        XCTAssertEqual(account.access(for: locked), .vip)
        XCTAssertEqual(account.access(for: free), .free)

        // Cached for the next launch.
        XCTAssertTrue(AccountStore(defaults: defaults).isVIP)
        account.reset()
        XCTAssertFalse(AccountStore(defaults: defaults).isVIP)
    }
}
