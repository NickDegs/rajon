import Foundation
import Security

/// SMS oturum token'ını iCloud Keychain ile saklar → yeni cihazda otomatik giriş.
/// `kSecAttrSynchronizable` iCloud Keychain senkronu (iCloud entitlement GEREKMEZ).
enum AuthService {
    private static let service = "app.realvirtuality.blockings.auth"
    private static let tokenKey = "rajon_sms_token"
    private static let phoneKey = "rajon_sms_phone"

    static func kaydet(token: String, phone: String) {
        yaz(tokenKey, token)
        yaz(phoneKey, phone)
    }
    static func sil() {
        sil(tokenKey); sil(phoneKey)
    }
    static var token: String? { oku(tokenKey) }
    static var phone: String? { oku(phoneKey) }
    static var girisli: Bool { (token?.isEmpty == false) }

    // MARK: Keychain (synchronizable)
    private static func yaz(_ key: String, _ value: String) {
        sil(key)
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanTrue!,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(q as CFDictionary, nil)
    }
    private static func oku(_ key: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data, let s = String(data: d, encoding: .utf8) else { return nil }
        return s
    }
    private static func sil(_ key: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        SecItemDelete(q as CFDictionary)
    }
}
