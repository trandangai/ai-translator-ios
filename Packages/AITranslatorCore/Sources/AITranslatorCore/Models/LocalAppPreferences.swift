import Foundation

public enum AppUILanguage: String, Codable, Sendable, CaseIterable {
    case vietnamese = "VIETNAMESE"
    case english = "ENGLISH"
}

public enum InteractionMode: String, Codable, Sendable, CaseIterable {
    case auto = "AUTO"
    case twoButton = "TWO_BUTTON"
}

/// Client preferences persisted in UserDefaults (Section 6.2).
public struct LocalAppPreferences: Codable, Sendable, Equatable {
    public var uiLanguage: AppUILanguage
    public var preferredPairId: String
    public var interactionMode: InteractionMode
    public var subtitlesEnabled: Bool
    public var echoGatingTailMs: Int
    public var vadSilenceMs: Int
    public var vadSensitivityPct: Int
    public var volumeBoostDb: Int
    public var subtitleFontSizeSp: Int
    public var keepScreenOn: Bool
    public var saveEncryptedHistory: Bool
    public var hasAcceptedPrivacyConsent: Bool
    public var showDebugOverlay: Bool
    public var twoSessionFixedAbMode: Bool
    public var allowBargeIn: Bool
    public var liveModelName: String
    public var transcribeModelName: String
    public var dailyCapSeconds: Int
    public var maxRequestsPerMinute: Int

    public init(
        uiLanguage: AppUILanguage = .vietnamese,
        preferredPairId: String = "vi_en",
        interactionMode: InteractionMode = .auto,
        subtitlesEnabled: Bool = false,
        echoGatingTailMs: Int = 320,
        vadSilenceMs: Int = 400,
        vadSensitivityPct: Int = 65,
        volumeBoostDb: Int = 3,
        subtitleFontSizeSp: Int = 20,
        keepScreenOn: Bool = true,
        saveEncryptedHistory: Bool = false,
        hasAcceptedPrivacyConsent: Bool = false,
        showDebugOverlay: Bool = false,
        twoSessionFixedAbMode: Bool = false,
        allowBargeIn: Bool = false,
        liveModelName: String = "gemini-3.5-live-translate",
        transcribeModelName: String = "gemini-3.5-transcribe-live",
        dailyCapSeconds: Int = 3600,
        maxRequestsPerMinute: Int = 60
    ) {
        self.uiLanguage = uiLanguage
        self.preferredPairId = preferredPairId
        self.interactionMode = interactionMode
        self.subtitlesEnabled = subtitlesEnabled
        self.echoGatingTailMs = max(100, min(1500, echoGatingTailMs))
        self.vadSilenceMs = max(150, min(2000, vadSilenceMs))
        self.vadSensitivityPct = max(1, min(100, vadSensitivityPct))
        self.volumeBoostDb = max(0, min(12, volumeBoostDb))
        self.subtitleFontSizeSp = max(14, min(32, subtitleFontSizeSp))
        self.keepScreenOn = keepScreenOn
        self.saveEncryptedHistory = saveEncryptedHistory
        self.hasAcceptedPrivacyConsent = hasAcceptedPrivacyConsent
        self.showDebugOverlay = showDebugOverlay
        self.twoSessionFixedAbMode = twoSessionFixedAbMode
        self.allowBargeIn = allowBargeIn
        self.liveModelName = liveModelName
        self.transcribeModelName = transcribeModelName
        self.dailyCapSeconds = max(60, min(14400, dailyCapSeconds))
        self.maxRequestsPerMinute = max(5, min(120, maxRequestsPerMinute))
    }

    public var echoGateConfig: EchoGateConfig {
        EchoGateConfig(
            tailHoldMs: Int64(echoGatingTailMs),
            vadSilenceMs: Int64(vadSilenceMs),
            vadSensitivityPct: vadSensitivityPct,
            allowBargeIn: allowBargeIn
        )
    }
}
