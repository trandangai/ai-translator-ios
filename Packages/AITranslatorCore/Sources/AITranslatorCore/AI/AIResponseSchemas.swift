import Foundation

/// Mode B structured JSON response (Section 5.3).
public struct SubtitleInterpretationResponse: Codable, Sendable, Equatable {
    public let detectedDirection: String
    public let sourceTranscript: String
    public let targetTranslation: String

    public init(detectedDirection: String, sourceTranscript: String, targetTranslation: String) {
        self.detectedDirection = detectedDirection
        self.sourceTranscript = sourceTranscript
        self.targetTranslation = targetTranslation
    }
}

/// Transcribe Studio structured JSON response (Section 5.5).
public struct StructuredTranscribeResponse: Codable, Sendable, Equatable {
    public let detectedLanguage: String
    public let transcript: String
    public let translation: String

    public init(detectedLanguage: String, transcript: String, translation: String) {
        self.detectedLanguage = detectedLanguage
        self.transcript = transcript
        self.translation = translation
    }
}

/// Unified live interpretation result consumed by `InterpreterViewModel`.
public struct LiveInterpretationResult: Sendable, Equatable {
    public let direction: SpokenDirection
    public let sourceText: String
    public let translatedText: String
    public let targetLocale: String
    public let ttftMs: Int64
    public let rttMs: Int64
    public let modelUsed: String

    public init(
        direction: SpokenDirection,
        sourceText: String,
        translatedText: String,
        targetLocale: String,
        ttftMs: Int64,
        rttMs: Int64,
        modelUsed: String
    ) {
        self.direction = direction
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.targetLocale = targetLocale
        self.ttftMs = ttftMs
        self.rttMs = rttMs
        self.modelUsed = modelUsed
    }
}
