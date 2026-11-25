import Foundation
import Security

/// Device ID and the server's API token for the anonymous account.
protocol CredentialStore: Sendable {
    /// Stable per install of the app on this device; created on first use.
    var deviceID: String { get }
    var token: String? { get }
    var userID: String? { get }
    func save(token: String, userID: String)
    /// Forget the token (the server rejected it); the device ID stays.
    func clearToken()
    /// After "Delete account": token and user ID go, the next sign-in creates a new account.
    func clearAccount()
}

/// Keychain storage: the device ID survives reinstalls, so a reinstall keeps the same account,
/// its history and VIP. Items never leave the device (no iCloud Keychain sync).
final class KeychainCredentialStore: CredentialStore {
    private let service: String

    init(service: String = "app.cliffzy.account") {
        self.service = service
    }

    var deviceID: String {
        if let existing = read("deviceId") { return existing }
        let id = UUID().uuidString
        write("deviceId", id)
        return id
    }

    var token: String? { read("token") }
    var userID: String? { read("userId") }

    func save(token: String, userID: String) {
        write("token", token)
        write("userId", userID)
    }

    func clearToken() {
        delete("token")
    }

    func clearAccount() {
        delete("token")
        delete("userId")
        // A new device ID, so the server creates a fresh account instead of finding the deleted one.
        write("deviceId", UUID().uuidString)
    }

    private func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
    }

    private func read(_ key: String) -> String? {
        var q = query(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ key: String, _ value: String) {
        let data = Data(value.utf8)
        let status = SecItemUpdate(query(key) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var q = query(key)
            q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(q as CFDictionary, nil)
        }
    }

    private func delete(_ key: String) {
        SecItemDelete(query(key) as CFDictionary)
    }
}

/// For tests and previews.
final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String]

    init(deviceID: String = "test-device-0001", token: String? = nil, userID: String? = nil) {
        values = ["deviceId": deviceID]
        values["token"] = token
        values["userId"] = userID
    }

    private func get(_ key: String) -> String? { lock.withLock { values[key] } }
    private func set(_ key: String, _ value: String?) { lock.withLock { values[key] = value } }

    var deviceID: String { get("deviceId") ?? "test-device-0001" }
    var token: String? { get("token") }
    var userID: String? { get("userId") }
    func save(token: String, userID: String) { set("token", token); set("userId", userID) }
    func clearToken() { set("token", nil) }
    func clearAccount() { set("token", nil); set("userId", nil); set("deviceId", UUID().uuidString) }
}
