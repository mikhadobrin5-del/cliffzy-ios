import XCTest
@testable import Cliffzy

final class RemoteCatalogTests: XCTestCase {
    private let base = URL(string: "https://media.example.com/cliffzy/catalog.json")!

    private func example() throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/catalog.example.json")
        return try Data(contentsOf: url)
    }

    func testExampleFileDecodesWithRelativeAndAbsoluteLinks() throws {
        let document = try CatalogDocument.decode(try example(), baseURL: base, region: "US")
        XCTAssertEqual(document.series.count, 2)

        let first = try XCTUnwrap(document.series.first)
        XCTAssertEqual(first.id, "kontrakt-na-god")
        XCTAssertEqual(first.episodes.map(\.number), [1, 2, 3])
        XCTAssertEqual(first.episodes[0].streamURL.absoluteString, "https://media.example.com/cliffzy/series/kontrakt-na-god/ep-0001.mp4")
        XCTAssertEqual(first.episodes[2].title, "Episode 3")
        XCTAssertEqual(first.posterURL?.absoluteString, "https://media.example.com/cliffzy/posters/kontrakt-na-god.jpg")

        let second = document.series[1]
        XCTAssertEqual(second.episodes[0].streamURL.absoluteString, "https://cdn.example.com/series/koroleva/ep-0001.mp4")
        XCTAssertEqual(second.views, 0)

        XCTAssertEqual(document.shelves.map(\.id), ["top", "new"])
        XCTAssertEqual(document.shelves[0].style, .ranked)
    }

    func testShelvesAreDerivedWhenFileHasNone() throws {
        let json = """
        {"version":1,"series":[
          {"id":"a","title":"A","genres":["Drama"],"views":5,"episodes":[{"number":2,"video":"a/2.mp4"},{"number":1,"video":"a/1.mp4"}]},
          {"id":"b","title":"B","genres":["Drama"],"views":9,"badge":"New","episodes":[{"number":1,"video":"b/1.mp4"}]}
        ]}
        """
        let document = try CatalogDocument.decode(Data(json.utf8), baseURL: base, region: "US")
        XCTAssertEqual(document.series[0].episodes.map(\.number), [1, 2])
        let top = try XCTUnwrap(document.shelves.first)
        XCTAssertEqual(top.style, .ranked)
        XCTAssertEqual(top.series.map(\.id), ["b", "a"])
        XCTAssertTrue(document.shelves.contains { $0.id == "new" })
    }

    func testRegionalSeriesShowOnlyInLicensedCountries() throws {
        let json = """
        {"version":1,"series":[
          {"id":"ww","title":"Worldwide","episodes":[{"number":1,"video":"ww/1.mp4"}]},
          {"id":"na","title":"North America","regions":["US","CA"],"episodes":[{"number":1,"video":"na/1.mp4"}]}
        ],"shelves":[{"id":"top","title":"Top","series":["na","ww"]}]}
        """
        let us = try CatalogDocument.decode(Data(json.utf8), baseURL: base, region: "us")
        XCTAssertEqual(us.series.map(\.id), ["ww", "na"])
        let de = try CatalogDocument.decode(Data(json.utf8), baseURL: base, region: "DE")
        XCTAssertEqual(de.series.map(\.id), ["ww"])
        XCTAssertEqual(de.shelves.first?.series.map(\.id), ["ww"])
        let unknown = try CatalogDocument.decode(Data(json.utf8), baseURL: base, region: nil)
        XCTAssertEqual(unknown.series.map(\.id), ["ww"])
    }

    func testRejectsUnknownVersionAndEmptySeries() {
        XCTAssertThrowsError(try CatalogDocument.decode(Data(#"{"version":2,"series":[]}"#.utf8), baseURL: base))
        XCTAssertThrowsError(try CatalogDocument.decode(Data(#"{"version":1,"series":[{"id":"x","title":"X","episodes":[]}]}"#.utf8), baseURL: base))
    }

    func testFallsBackToLastGoodCopyWhenOffline() async throws {
        let cache = FileManager.default.temporaryDirectory.appendingPathComponent("catalog-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: cache) }
        let data = try example()

        let online = RemoteCatalogService(url: base, cacheFile: cache) { _ in data }
        _ = try await online.feed()

        let offline = RemoteCatalogService(url: base, cacheFile: cache) { _ in throw URLError(.notConnectedToInternet) }
        let feed = try await offline.feed()
        XCTAssertEqual(feed.count, 2)
    }
}
