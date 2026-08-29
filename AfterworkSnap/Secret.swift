import Foundation
import Security

/// The app secret: from Secrets.xcconfig via Info.plist into the Keychain on
/// first launch; the send path reads it only from the Keychain.
enum Secret {
    private static let service = "co.msmr.afterworksnap"
    private static let account = "upload-secret"

    static func seedIfNeeded() {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "UPLOAD_SECRET") as? String,
              !value.isEmpty, read() != value else { return }
        let data = Data(value.utf8)
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                      kSecAttrService: service, kSecAttrAccount: account]
        if SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary) == errSecItemNotFound {
            var add = query
            add[kSecValueData] = data
            add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func read() -> String? {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                      kSecAttrService: service, kSecAttrAccount: account,
                                      kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
