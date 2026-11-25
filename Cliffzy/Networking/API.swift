import Foundation

/// Everything the app asks the Cliffzy backend (`cliffzy-api`, the same server the Android app uses).
///
/// `RemoteAPI` talks to the real server; `DemoAPI` is an in-memory stand-in for demo screens,
/// SwiftUI previews and tests.
protocol CliffzyAPI: Sendable {
    func home() async throws -> HomeFeed
    func series(id: String) async throws -> SeriesDetail
    /// Signed link to one episode's video. Throws `APIError.vipRequired` for a locked episode.
    func playback(seriesID: String, episode: Int) async throws -> PlaybackLink
    func reportProgress(seriesID: String, episode: Int, positionSec: Int) async throws
    func me() async throws -> Me
    /// Deletes the anonymous account with its history and My List; the next call makes a new one.
    func deleteAccount() async throws
    func myList() async throws -> [SeriesCard]
    func save(seriesID: String) async throws
    func unsave(seriesID: String) async throws
    func history() async throws -> [HistoryItem]
    /// Sends a StoreKit 2 transaction (`jwsRepresentation`) for the server to check with Apple's signature.
    func verifyAppleTransaction(_ jws: String) async throws -> Me
    /// The account ID; StoreKit purchases carry it as `appAccountToken` so the server can match renewals.
    func accountID() async throws -> UUID
}

enum APIError: LocalizedError, Equatable {
    /// 402: the episode needs VIP.
    case vipRequired
    case notFound
    case unauthorized
    case server(status: Int, code: String?)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .vipRequired: "This episode needs VIP."
        case .notFound: "Not found."
        case .unauthorized: "Couldn't sign in to Cliffzy."
        case .server(let status, let code): "The server answered \(status)\(code.map { " (\($0))" } ?? "")."
        case .invalidResponse: "The server sent something the app doesn't understand."
        }
    }

    init(status: Int, body: Data) {
        let code = (try? JSONDecoder().decode([String: String].self, from: body))?["error"]
        switch status {
        case 402: self = .vipRequired
        case 404: self = .notFound
        case 401: self = .unauthorized
        default: self = .server(status: status, code: code)
        }
    }
}

// MARK: - Wire format (mirrors the Kotlin data classes in cliffzy-backend)

struct SeriesCard: Codable, Hashable, Sendable {
    let id: String
    let title: String
    let posterUrl: URL?
    let episodeCount: Int
    let tags: [String]
}

struct EpisodeInfo: Codable, Hashable, Sendable {
    let number: Int
    let durationSec: Int
    /// FREE, VIP (open thanks to the subscription) or LOCKED.
    let access: String
}

struct ResumePoint: Codable, Hashable, Sendable {
    let episode: Int
    let positionSec: Int
}

struct SeriesDetail: Codable, Sendable {
    let series: SeriesCard
    let description: String
    let freeEpisodes: Int
    let episodes: [EpisodeInfo]
    let saved: Bool
    let resume: ResumePoint?
}

struct PlaybackLink: Codable, Sendable, Equatable {
    let url: URL
    /// Unix seconds when the signed link stops working.
    let expiresAt: TimeInterval

    var expiry: Date { Date(timeIntervalSince1970: expiresAt) }
}

struct ContinueItem: Codable, Sendable {
    let series: SeriesCard
    let episode: Int
    let positionSec: Int
    let progress: Double
}

struct ShelfInfo: Codable, Sendable {
    let id: String
    let title: String
    let items: [SeriesCard]
    /// Top 10 style with big numbers. Optional so an older server without the field still decodes.
    let ranked: Bool?
}

struct HomeFeed: Codable, Sendable {
    let banners: [SeriesCard]
    let continueWatching: [ContinueItem]
    let shelves: [ShelfInfo]
    let genres: [String]
    /// The whole published catalog, in catalog order.
    let all: [SeriesCard]
}

struct Me: Codable, Sendable, Equatable {
    let userId: String
    let vip: Bool
    /// Unix milliseconds.
    let vipUntil: Double?
    let devMode: Bool

    var vipExpiry: Date? { vipUntil.map { Date(timeIntervalSince1970: $0 / 1000) } }
}

struct HistoryItem: Codable, Sendable {
    let series: SeriesCard
    let episode: Int
    let positionSec: Int
    let progress: Double
}

struct DeviceAuth: Codable, Sendable {
    let userId: String
    let token: String
}
