import AITranslatorCore
import CryptoKit
import Foundation

/// Protocol for key provisioning (allows in-memory testing without Keychain entitlements).
public protocol SymmetricKeyProviding: Sendable {
    func getOrCreateKey() throws -> SymmetricKey
    func deleteKey()
}

extension KeychainSymmetricKeyStore: SymmetricKeyProviding {}

/// Encrypts/decrypts up to 50 `SavedHistoryTurn` entries with AES-256-GCM (`base64(iv):base64(ciphertext + tag)`).
public final class EncryptedHistoryStore: @unchecked Sendable {
    private static let blobKey = "ai_translator_encrypted_history_blob_v1"
    private let keyProvider: any SymmetricKeyProviding
    private let defaults: UserDefaults
    private let lock = NSLock()

    public init(
        keyProvider: any SymmetricKeyProviding = KeychainSymmetricKeyStore(),
        defaults: UserDefaults = .standard
    ) {
        self.keyProvider = keyProvider
        self.defaults = defaults
    }

    public func loadTurns() -> [SavedHistoryTurn] {
        lock.lock()
        let blob = defaults.string(forKey: Self.blobKey)
        lock.unlock()

        guard let blob, !blob.isEmpty else { return [] }
        let parts = blob.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let ivData = Data(base64Encoded: parts[0]),
              let combinedCipherTag = Data(base64Encoded: parts[1]),
              combinedCipherTag.count >= 16 else {
            return []
        }

        do {
            let key = try keyProvider.getOrCreateKey()
            let nonce = try AES.GCM.Nonce(data: ivData)
            let ciphertext = combinedCipherTag.dropLast(16)
            let tag = combinedCipherTag.suffix(16)
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            let plainData = try AES.GCM.open(sealedBox, using: key)
            return try JSONDecoder().decode([SavedHistoryTurn].self, from: plainData)
        } catch {
            return []
        }
    }

    public func appendTurn(_ turn: SavedHistoryTurn) {
        var current = loadTurns()
        current.append(turn)
        if current.count > SavedHistoryTurn.maxStoredTurns {
            current.removeFirst(current.count - SavedHistoryTurn.maxStoredTurns)
        }
        saveTurns(current)
    }

    public func wipeAll() {
        lock.lock()
        defaults.removeObject(forKey: Self.blobKey)
        lock.unlock()
        keyProvider.deleteKey()
    }

    private func saveTurns(_ turns: [SavedHistoryTurn]) {
        do {
            let key = try keyProvider.getOrCreateKey()
            let plainData = try JSONEncoder().encode(turns)
            let sealed = try AES.GCM.seal(plainData, using: key)
            let ivBase64 = Data(sealed.nonce).base64EncodedString()
            var cipherAndTag = Data(sealed.ciphertext)
            cipherAndTag.append(sealed.tag)
            let cipherTagBase64 = cipherAndTag.base64EncodedString()
            let serialized = "\(ivBase64):\(cipherTagBase64)"

            lock.lock()
            defaults.set(serialized, forKey: Self.blobKey)
            lock.unlock()
        } catch {
            // Zero-retention fail-safe: never write plaintext on encryption failure
        }
    }
}
