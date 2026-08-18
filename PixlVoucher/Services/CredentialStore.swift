import Foundation
import Security

/// Keychain-backed storage for the MikroTik API password. Same shape as the
/// Windows app's DPAPI-backed CredentialStore.cs (HasPassword/Save/Get/Delete).
enum CredentialStore {
    private static let service = "com.pixl.voucher.mikrotik"
    private static let account = "mikrotik-api-password"

    static func hasPassword() -> Bool {
        (try? getPassword()) != nil
    }

    static func savePassword(_ password: String) throws {
        guard !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CredentialStoreError.emptyPassword
        }

        let data = Data(password.utf8)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialStoreError.keychain(status)
        }
    }

    static func getPassword() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data, let password = String(data: data, encoding: .utf8) else {
            throw CredentialStoreError.notConfigured
        }

        return password
    }

    static func deletePassword() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(query as CFDictionary)
    }
}

enum CredentialStoreError: LocalizedError {
    case emptyPassword
    case notConfigured
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .emptyPassword:
            return "Password cannot be empty."
        case .notConfigured:
            return "MikroTik credentials have not been configured."
        case .keychain(let status):
            return "Unable to save credentials (Keychain error \(status))."
        }
    }
}
