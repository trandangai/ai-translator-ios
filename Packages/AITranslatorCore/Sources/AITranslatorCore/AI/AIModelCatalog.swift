import Foundation

public struct AIModelInfo: Identifiable, Sendable, Equatable {
    public let id: String
    public let badge: String

    public init(id: String, badge: String) {
        self.id = id
        self.badge = badge
    }
}

/// Supported Live & Transcription models with fallback chains (Section 5.1).
public enum AIModelCatalog: Sendable {
    public static let availableLiveModels: [AIModelInfo] = [
        AIModelInfo(id: "gemini-3.5-live-translate", badge: "Live API • Unlimited • 100K TPM"),
        AIModelInfo(id: "gemini-2.5-flash-preview-native-audio-dialog", badge: "Live API • Unlimited • 1M TPM"),
        AIModelInfo(id: "gemini-3-flash-live", badge: "Live API • Unlimited • 150K TPM"),
        AIModelInfo(id: "gemini-3.8-live", badge: "Live API • Unlimited • 150K TPM"),
        AIModelInfo(id: "gemini-3.1-flash-lite-preview", badge: "Standard API • Tier 1 • Flash Lite"),
        AIModelInfo(id: "gemini-3.5-flash-lite", badge: "Standard API • Tier 1 • Flash Lite")
    ]

    public static let availableTranscribeModels: [AIModelInfo] = [
        AIModelInfo(id: "gemini-3.5-transcribe-live", badge: "Live API • Unlimited • 100K TPM"),
        AIModelInfo(id: "gemini-3.5-live-translate", badge: "Live API • Unlimited • 100K TPM"),
        AIModelInfo(id: "gemini-3-flash-live", badge: "Live API • Unlimited • 150K TPM"),
        AIModelInfo(id: "gemini-3.8-live", badge: "Live API • Unlimited • 150K TPM"),
        AIModelInfo(id: "gemini-3.1-flash-lite-preview", badge: "Standard API • Tier 1 • Flash Lite"),
        AIModelInfo(id: "gemini-3.5-transcribe", badge: "Standard API • Transcribe")
    ]

    public static func buildCandidateModels(primary: String, from catalog: [AIModelInfo]) -> [String] {
        var result: [String] = [primary]
        for model in catalog where model.id != primary {
            result.append(model.id)
        }
        return result
    }
}
