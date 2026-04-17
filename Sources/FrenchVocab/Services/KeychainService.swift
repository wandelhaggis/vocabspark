import Foundation
import Security

/// Minimal Keychain wrapper for a single credential string.
/// Used for the OpenAI API key so it doesn't end up in iCloud backups.
enum KeychainService {
    private static let service = "com.michikoenig.vocabspark"
    private static let account = "openai_api_key"

    static func save(_ value: String) {
        delete()
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// One-time migration from UserDefaults to Keychain. Safe to call on every launch.
    static func migrateFromUserDefaultsIfNeeded() {
        guard load() == nil else { return }
        let defaults = UserDefaults.standard
        if let oldKey = defaults.string(forKey: "openai_api_key"), !oldKey.isEmpty {
            save(oldKey)
            defaults.removeObject(forKey: "openai_api_key")
        }
    }
}
