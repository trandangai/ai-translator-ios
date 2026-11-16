import CryptoKit
import Foundation
import Security

public enum KeychainStoreError: Error {
    case unhandledStatus(OSStatus)
    case invalidKeyData
}

/// Manages a hardware-backed 256-bit `SymmetricKey` in the iOS Keychain (Section 6.2, 9.5).
public final class KeychainSymmetricKeyStore: Sendable {
    private let account: String
    private let service: String

    public init(
        service: String = "com.aitranslator.ios.history",
        account: String = "ai_translator_history_aes_key"
    ) {
        self.service = service
        self.account = account
    }

    public func getOrCreateKey() throws -> SymmetricKey {
        if let existing = try loadKey() {
            return existing
        }
        let newKey = SymmetricKey(size: .bits256)
        try saveKey(newKey)
        return newKey
    }

    public func deleteKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func loadKey() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainStoreError.unhandledStatus(status)
        }
        guard let data = result as? Data, data.count == 32 else {
            throw KeychainStoreError.invalidKeyData
        }
        return SymmetricKey(data: data)
    }

    private func saveKey(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStoreError.unhandledStatus(status)
        }
    }
}
