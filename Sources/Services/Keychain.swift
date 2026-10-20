import Foundation
import Security

/// Small strings in the Keychain: the account's refresh token (never in UserDefaults), and with `group` the
/// keyboard handoff, which both the app and the Echo keyboard can read.
enum Keychain {
    private static func query(_ key: String, group: String?) -> [String: Any] {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.nulljosh.echo", kSecAttrAccount as String: key]
        if let group { q[kSecAttrAccessGroup as String] = group }
        return q
    }

    static func read(_ key: String, group: String? = nil) -> String? {
        var q = query(key, group: group)
        q[kSecReturnData as String] = true
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ key: String, _ value: String, group: String? = nil) {
        delete(key, group: group)
        var q = query(key, group: group)
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly // never rides along in a backup
        SecItemAdd(q as CFDictionary, nil)
    }

    static func delete(_ key: String, group: String? = nil) {
        SecItemDelete(query(key, group: group) as CFDictionary)
    }
}
