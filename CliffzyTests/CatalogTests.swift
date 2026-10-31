import XCTest
@testable import Cliffzy

final class CatalogTests: XCTestCase {
    func testMockCatalogHasPlayableSeries() async throws {
        let catalog = MockCatalogService()
        let feed = try await catalog.feed()
        XCTAssertFalse(feed.isEmpty)
        for series in feed {
            XCTAssertEqual(series.episodes.map(\.number), Array(1...series.episodeCount))
        }
    }

    func testTopShelfIsRankedByViews() async throws {
        let shelves = try await MockCatalogService().shelves()
        let top = try XCTUnwrap(shelves.first)
        XCTAssertEqual(top.style, .ranked)
        XCTAssertEqual(top.series.map(\.views), top.series.map(\.views).sorted(by: >))
    }
}
