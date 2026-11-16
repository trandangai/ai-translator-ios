import Foundation

/// On-device encrypted history turn (Section 6.2). Capped at 50 most recent turns.
public struct SavedHistoryTurn: Codable, Sendable, Equatable, Identifiable {
    public static let maxStoredTurns = 50

    public let id: UUID
    public let timestampMs: Int64
    public let pairId: String
    public let direction: SpokenDirection
    public let sourceText: String
    public let translatedText: String

    public init(
        id: UUID = UUID(),
        timestampMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        pairId: String,
        direction: SpokenDirection,
        sourceText: String,
        translatedText: String
    ) {
        self.id = id
        self.timestampMs = timestampMs
        self.pairId = pairId
        self.direction = direction
        self.sourceText = sourceText
        self.translatedText = translatedText
    }
}
