import Foundation

enum AppConfig {
    /// The Cliffzy server, from the `-CliffzyAPI <url>` launch argument (to try another server from
    /// Xcode) or the `API_BASE_URL` build setting via Info.plist. HTTPS only.
    static var apiBaseURL: URL? {
        let defaults = UserDefaults.standard.string(forKey: "CliffzyAPI")
        let plist = Bundle.main.object(forInfoDictionaryKey: "CliffzyAPIBaseURL") as? String
        for value in [defaults, plist] {
            guard let value, !value.isEmpty, !value.hasPrefix("$("),
                  let url = URL(string: value.hasSuffix("/") ? value : value + "/"), url.scheme == "https"
            else { continue }
            return url
        }
        return nil
    }

    /// The real server, or the in-memory demo for `-CliffzyScreen` screenshots and builds without a server URL.
    static func makeAPI() -> any CliffzyAPI {
        if DemoScreen.requested == nil, let url = apiBaseURL {
            return RemoteAPI(baseURL: url)
        }
        return DemoAPI()
    }

    /// Legal pages served by the backend (the same pages the Android app links to).
    static var privacyURL: URL { page("privacy") }
    static var termsURL: URL { page("terms") }
    static var deleteDataURL: URL { page("delete-account") }
    static let supportEmail = "support@buzzard.world"
    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    /// Share link: the server sends iPhones to the App Store and others to Google Play.
    static func shareURL(for seriesID: String) -> URL {
        page("s/\(seriesID)")
    }

    private static func page(_ path: String) -> URL {
        (apiBaseURL ?? URL(string: "https://cliffzy-api.onrender.com/")!).appending(path: path)
    }
}
