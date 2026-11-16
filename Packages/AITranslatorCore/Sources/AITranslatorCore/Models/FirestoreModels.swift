import Foundation

/// Cloud Firestore `/users/{userId}` document schema (Section 6.1).
public struct UserSettingsProfile: Codable, Sendable, Equatable {
    public let userId: String
    public var preferredPairId: String
    public var interactionMode: String
    public var subtitlesEnabled: Bool
    public var echoGatingTailMs: Int
    public var vadSilenceMs: Int
    public var vadSensitivityPct: Int
    public var volumeBoostDb: Int
    public var createdAt: Date?
    public var updatedAt: Date?

    public init(
        userId: String,
        preferredPairId: String = "vi_en",
        interactionMode: String = "AUTO",
        subtitlesEnabled: Bool = false,
        echoGatingTailMs: Int = 320,
        vadSilenceMs: Int = 400,
        vadSensitivityPct: Int = 65,
        volumeBoostDb: Int = 3,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.userId = userId
        self.preferredPairId = preferredPairId
        self.interactionMode = interactionMode
        self.subtitlesEnabled = subtitlesEnabled
        self.echoGatingTailMs = max(100, min(1500, echoGatingTailMs))
        self.vadSilenceMs = max(150, min(2000, vadSilenceMs))
        self.vadSensitivityPct = max(1, min(100, vadSensitivityPct))
        self.volumeBoostDb = max(0, min(12, volumeBoostDb))
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Cloud Firestore `/users/{userId}/daily_quotas/{dateKey}` document schema (Section 6.1).
public struct DailyUsageQuota: Codable, Sendable, Equatable {
    public var audioSecondsUsed: Int
    public var sessionsCount: Int
    public var transcribeCount: Int
    public var dailyCapSeconds: Int
    public var updatedAt: Date?

    public init(
        audioSecondsUsed: Int = 0,
        sessionsCount: Int = 0,
        transcribeCount: Int = 0,
        dailyCapSeconds: Int = 3600,
        updatedAt: Date? = nil
    ) {
        self.audioSecondsUsed = max(0, min(86400, audioSecondsUsed))
        self.sessionsCount = max(0, min(10000, sessionsCount))
        self.transcribeCount = max(0, min(50000, transcribeCount))
        self.dailyCapSeconds = max(60, min(86400, dailyCapSeconds))
        self.updatedAt = updatedAt
    }

    public static func utcDateKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
