import XCTest
@testable import Cliffzy

/// Answers requests from a closure instead of the network.
final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, String))?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var request = request
        if request.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            stream.close()
            request.httpBody = data
        }
        Self.requests.append(request)
        let (status, body) = Self.handler?(request) ?? (500, "")
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class RemoteAPITests: XCTestCase {
    private let base = URL(string: "https://api.test/")!
    private var session: URLSession!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        session = URLSession(configuration: config)
        StubProtocol.requests = []
    }

    private let userID = "7f1c2a52-6a0e-4c43-9a59-2f8f3a1d0b11"

    func testSignsInOnceWithDeviceIDAndSendsBearer() async throws {
        var issued = 0
        StubProtocol.handler = { request in
            switch request.url!.path {
            case "/v1/auth/device":
                issued += 1
                return (200, #"{"userId":"\#(self.userID)","token":"tok-\#(issued)"}"#)
            case "/v1/me":
                return (200, #"{"userId":"\#(self.userID)","vip":false,"vipUntil":null,"devMode":false}"#)
            default:
                return (404, "")
            }
        }
        let store = InMemoryCredentialStore(deviceID: "device-123456")
        let api = RemoteAPI(baseURL: base, session: session, credentials: store)
        _ = try await api.me()
        _ = try await api.me()

        let auth = StubProtocol.requests.filter { $0.url!.path == "/v1/auth/device" }
        XCTAssertEqual(auth.count, 1)
        XCTAssertEqual(String(data: auth[0].httpBody ?? Data(), encoding: .utf8), #"{"deviceId":"device-123456"}"#)
        let me = StubProtocol.requests.filter { $0.url!.path == "/v1/me" }
        XCTAssertEqual(me.map { $0.value(forHTTPHeaderField: "Authorization") }, ["Bearer tok-1", "Bearer tok-1"])
        XCTAssertEqual(store.token, "tok-1")
        let accountID = try await api.accountID()
        XCTAssertEqual(accountID, UUID(uuidString: userID))
    }

    func testExpiredTokenSignsInAgainOnce() async throws {
        StubProtocol.handler = { request in
            if request.url!.path == "/v1/auth/device" { return (200, #"{"userId":"\#(self.userID)","token":"fresh"}"#) }
            let bearer = request.value(forHTTPHeaderField: "Authorization")
            return bearer == "Bearer fresh" ? (200, "[]") : (401, #"{"error":"unauthorized"}"#)
        }
        let store = InMemoryCredentialStore(token: "stale", userID: userID)
        let api = RemoteAPI(baseURL: base, session: session, credentials: store)
        let list = try await api.myList()
        XCTAssertTrue(list.isEmpty)
        XCTAssertEqual(store.token, "fresh")
    }

    func testLockedEpisodeIsVIPRequired() async {
        StubProtocol.handler = { request in
            if request.url!.path == "/v1/auth/device" { return (200, #"{"userId":"\#(self.userID)","token":"t"}"#) }
            return (402, #"{"error":"vip_required"}"#)
        }
        let api = RemoteAPI(baseURL: base, session: session, credentials: InMemoryCredentialStore())
        do {
            _ = try await api.playback(seriesID: "a", episode: 9)
            XCTFail("expected vipRequired")
        } catch {
            XCTAssertEqual(error as? APIError, .vipRequired)
        }
        XCTAssertEqual(StubProtocol.requests.last?.url?.path, "/v1/series/a/episodes/9/playback")
    }

    func testAppleTransactionGoesToServer() async throws {
        StubProtocol.handler = { request in
            if request.url!.path == "/v1/auth/device" { return (200, #"{"userId":"\#(self.userID)","token":"t"}"#) }
            return (200, #"{"userId":"\#(self.userID)","vip":true,"vipUntil":1795656764000,"devMode":false}"#)
        }
        let api = RemoteAPI(baseURL: base, session: session, credentials: InMemoryCredentialStore())
        let me = try await api.verifyAppleTransaction("header.payload.signature")
        XCTAssertTrue(me.vip)
        let request = try XCTUnwrap(StubProtocol.requests.last)
        XCTAssertEqual(request.url?.path, "/v1/billing/apple/verify")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), #"{"signedTransaction":"header.payload.signature"}"#)
    }

    func testDemoServerLocksAfterFreeEpisodesUntilVIP() async throws {
        let api = DemoAPI()
        let id = DemoAPI.catalog[0].card.id
        _ = try await api.playback(seriesID: id, episode: DemoAPI.freeEpisodes)
        do {
            _ = try await api.playback(seriesID: id, episode: DemoAPI.freeEpisodes + 1)
            XCTFail("expected vipRequired")
        } catch {
            XCTAssertEqual(error as? APIError, .vipRequired)
        }
        _ = try await api.verifyAppleTransaction("preview")
        _ = try await api.playback(seriesID: id, episode: DemoAPI.freeEpisodes + 1)
        let detail = try await api.series(id: id)
        XCTAssertEqual(detail.episodes.last?.access, "VIP")
    }
}
