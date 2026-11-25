import Foundation

/// The real Cliffzy server. Signs in without registration: one anonymous account per device
/// (`POST /v1/auth/device`), with the token kept in the Keychain. A 401 signs in again once.
actor RemoteAPI: CliffzyAPI {
    let baseURL: URL
    private let session: URLSession
    private let credentials: any CredentialStore
    private var token: String?
    private var pendingAuth: Task<DeviceAuth, Error>?

    init(baseURL: URL, session: URLSession = .shared, credentials: any CredentialStore = KeychainCredentialStore()) {
        self.baseURL = baseURL
        self.session = session
        self.credentials = credentials
        token = credentials.token
    }

    // MARK: Endpoints

    func home() async throws -> HomeFeed {
        try await get("v1/home")
    }

    func series(id: String) async throws -> SeriesDetail {
        try await get("v1/series/\(id)")
    }

    func playback(seriesID: String, episode: Int) async throws -> PlaybackLink {
        try await get("v1/series/\(seriesID)/episodes/\(episode)/playback")
    }

    func reportProgress(seriesID: String, episode: Int, positionSec: Int) async throws {
        struct Body: Encodable { let seriesId: String; let episode: Int; let positionSec: Int }
        _ = try await send("POST", "v1/progress", body: Body(seriesId: seriesID, episode: max(episode, 1), positionSec: max(positionSec, 0)))
    }

    func me() async throws -> Me {
        try await get("v1/me")
    }

    func deleteAccount() async throws {
        _ = try await send("DELETE", "v1/me")
        token = nil
        credentials.clearAccount()
    }

    func myList() async throws -> [SeriesCard] {
        try await get("v1/list")
    }

    func save(seriesID: String) async throws {
        _ = try await send("PUT", "v1/list/\(seriesID)")
    }

    func unsave(seriesID: String) async throws {
        _ = try await send("DELETE", "v1/list/\(seriesID)")
    }

    func history() async throws -> [HistoryItem] {
        try await get("v1/history")
    }

    func verifyAppleTransaction(_ jws: String) async throws -> Me {
        struct Body: Encodable { let signedTransaction: String }
        let data = try await send("POST", "v1/billing/apple/verify", body: Body(signedTransaction: jws))
        return try decode(data)
    }

    func accountID() async throws -> UUID {
        if token == nil { _ = try await authorize() }
        if let id = credentials.userID.flatMap(UUID.init(uuidString:)) { return id }
        // A token from before the user ID was stored: ask the server.
        let me = try await me()
        credentials.save(token: token ?? "", userID: me.userId)
        guard let id = UUID(uuidString: me.userId) else { throw APIError.invalidResponse }
        return id
    }

    // MARK: Plumbing

    private func get<T: Decodable>(_ path: String) async throws -> T {
        try decode(try await send("GET", path))
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }

    private func send(_ method: String, _ path: String, body: (any Encodable)? = nil, retry: Bool = true) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.setValue("Bearer \(try await authorize())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 && retry {
            token = nil
            credentials.clearToken()
            return try await send(method, path, body: body, retry: false)
        }
        guard (200..<300).contains(status) else { throw APIError(status: status, body: data) }
        return data
    }

    private func authorize() async throws -> String {
        if let token { return token }
        if let pendingAuth { return try await pendingAuth.value.token }

        var request = URLRequest(url: baseURL.appending(path: "v1/auth/device"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["deviceId": credentials.deviceID])
        let session = session
        let task = Task<DeviceAuth, Error> {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(status) else { throw APIError(status: status, body: data) }
            return try JSONDecoder().decode(DeviceAuth.self, from: data)
        }
        pendingAuth = task
        defer { pendingAuth = nil }
        let auth = try await task.value
        token = auth.token
        credentials.save(token: auth.token, userID: auth.userId)
        return auth.token
    }
}
