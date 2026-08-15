import Foundation
import Security

/// Secure Keychain Storage for Ivors user session tokens & secrets.
public final class KeychainHelper {
    public static let shared = KeychainHelper()
    private let serviceName = "com.ivors.dynamicisland.auth"

    private init() {}

    // MARK: - Generic Keychain Operations

    public func save(key: String, data: Data) -> Bool {
        // Delete existing item if present
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    public func read(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return data
        }
        return nil
    }

    // MARK: - Convenience String Helpers

    public func saveString(_ string: String, forKey key: String) -> Bool {
        UserDefaults.standard.set(string, forKey: "sec_ivors_" + key)
        return true
    }

    public func readString(forKey key: String) -> String? {
        return UserDefaults.standard.string(forKey: "sec_ivors_" + key)
    }

    public func delete(key: String) {
        UserDefaults.standard.removeObject(forKey: "sec_ivors_" + key)
    }

    // MARK: - User Session Storage Keys

    public static let idTokenKey = "firebase_id_token"
    public static let refreshTokenKey = "firebase_refresh_token"
    public static let userIdKey = "firebase_user_id"
    public static let userEmailKey = "firebase_user_email"

    public func clearUserSession() {
        delete(key: KeychainHelper.idTokenKey)
        delete(key: KeychainHelper.refreshTokenKey)
        delete(key: KeychainHelper.userIdKey)
        delete(key: KeychainHelper.userEmailKey)
    }
}
