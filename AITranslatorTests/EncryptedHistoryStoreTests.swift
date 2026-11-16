import AITranslatorCore
import CryptoKit
import XCTest
@testable import AITranslator

final class InMemoryKeyProvider: SymmetricKeyProviding, @unchecked Sendable {
    private var key: SymmetricKey?
    func getOrCreateKey() throws -> SymmetricKey {
        if let key { return key }
        let created = SymmetricKey(size: .bits256)
        key = created
        return created
    }
    func deleteKey() {
        key = nil
    }
}

final class EncryptedHistoryStoreTests: XCTestCase {
    func testAesGcmRoundTripCapAt50AndWipe() {
        let suiteName = "test.history.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = EncryptedHistoryStore(keyProvider: InMemoryKeyProvider(), defaults: defaults)

        for i in 1...55 {
            store.appendTurn(
                SavedHistoryTurn(
                    pairId: "vi_zhtw",
                    direction: .aToB,
                    sourceText: "Xin chào \(i)",
                    translatedText: "你好 \(i)"
                )
            )
        }

        let loaded = store.loadTurns()
        XCTAssertEqual(loaded.count, 50)
        XCTAssertEqual(loaded.first?.sourceText, "Xin chào 6")
        XCTAssertEqual(loaded.last?.sourceText, "Xin chào 55")

        store.wipeAll()
        XCTAssertTrue(store.loadTurns().isEmpty)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
