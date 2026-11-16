import AITranslatorCore
import FirebaseAI
import Foundation

/// Gemini Live & Transcription AI client using `FirebaseAI` with fallback chains, rate limiting, and script guards (Section 5).
@MainActor
public final class GeminiLiveSessionClient {
    public private(set) var isSessionWarm: Bool = false
    public private(set) var sessionOpenedElapsedMs: Int64 = 0
    public private(set) var sessionRenewalsCount: Int = 0
    public private(set) var reconnectCount: Int = 0

    public let rateLimiter = SlidingWindowRateLimiter()
    public let reconnectPolicy = ReconnectPolicy()
    public let latencyTracker = LatencyStatsTracker()

    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())

    public init() {}

    public func warmUpSession(nowElapsedMs: Int64) {
        isSessionWarm = true
        sessionOpenedElapsedMs = nowElapsedMs
    }

    public func checkAndRenewIfNeeded(nowElapsedMs: Int64) {
        if isSessionWarm && reconnectPolicy.shouldRenewSession(sessionStartedElapsedMs: sessionOpenedElapsedMs, nowElapsedMs: nowElapsedMs) {
            sessionOpenedElapsedMs = nowElapsedMs
            sessionRenewalsCount += 1
        }
    }

    public func closeSession() {
        isSessionWarm = false
    }

    public func interpretUtteranceWav(
        wavData: Data,
        pair: LanguagePair,
        primaryModel: String,
        subtitlesEnabled: Bool,
        maxRpm: Int,
        forcedDirection: SpokenDirection? = nil,
        onFirstAudioChunkReady: ((_ text: String, _ targetLocale: String, _ ttftMs: Int64) -> Void)? = nil
    ) async throws -> LiveInterpretationResult? {
        rateLimiter.maxRequestsPerMinute = maxRpm
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        try rateLimiter.checkAndRecordRateLimit(nowMs: nowMs)

        let candidates = AIModelCatalog.buildCandidateModels(
            primary: primaryModel,
            from: AIModelCatalog.availableLiveModels
        )

        var lastError: Error?
        for (attempt, modelName) in candidates.enumerated() {
            do {
                if subtitlesEnabled {
                    if let result = try await runStructuredSubtitleCall(
                        wavData: wavData,
                        pair: pair,
                        modelName: modelName,
                        forcedDirection: forcedDirection
                    ) {
                        onFirstAudioChunkReady?(result.translatedText, result.targetLocale, result.ttftMs)
                        return result
                    }
                    return nil
                } else {
                    if let result = try await runStreamingDirectCall(
                        wavData: wavData,
                        pair: pair,
                        modelName: modelName,
                        forcedDirection: forcedDirection,
                        onFirstAudioChunkReady: onFirstAudioChunkReady
                    ) {
                        return result
                    }
                    return nil
                }
            } catch {
                lastError = error
                if attempt > 0 { reconnectCount += 1 }
                continue
            }
        }
        if let lastError { throw lastError }
        return nil
    }

    public func transcribeAudioWav(
        wavData: Data,
        pair: LanguagePair,
        primaryModel: String,
        maxRpm: Int
    ) async throws -> (response: StructuredTranscribeResponse, latencyMs: Int64, modelUsed: String) {
        rateLimiter.maxRequestsPerMinute = maxRpm
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        try rateLimiter.checkAndRecordRateLimit(nowMs: nowMs)

        let candidates = AIModelCatalog.buildCandidateModels(
            primary: primaryModel,
            from: AIModelCatalog.availableTranscribeModels
        )

        var lastError: Error?
        for modelName in candidates {
            let startMs = Int64(Date().timeIntervalSince1970 * 1000)
            do {
                let model = ai.generativeModel(
                    modelName: modelName,
                    generationConfig: GenerationConfig(
                        temperature: 0.1,
                        responseMIMEType: "application/json",
                        responseSchema: Self.transcribeSchema
                    ),
                    systemInstruction: ModelContent(role: "system", parts: Self.transcribeSystemPrompt(pair: pair))
                )
                let audioPart = InlineDataPart(data: wavData, mimeType: "audio/wav")
                let response = try await model.generateContent(audioPart)
                if let text = response.text,
                   let data = text.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode(StructuredTranscribeResponse.self, from: data),
                   !decoded.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let latency = Int64(Date().timeIntervalSince1970 * 1000) - startMs
                    return (decoded, latency, modelName)
                }

                // Secondary plain-text fallback on same model (Section 5.5)
                let plainModel = ai.generativeModel(
                    modelName: modelName,
                    generationConfig: GenerationConfig(temperature: 0.1)
                )
                let plainResponse = try await plainModel.generateContent(
                    "Transcribe verbatim and translate for pair \(pair.shortBadge):",
                    audioPart
                )
                if let plainText = plainResponse.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !plainText.isEmpty {
                    let latency = Int64(Date().timeIntervalSince1970 * 1000) - startMs
                    return (
                        StructuredTranscribeResponse(
                            detectedLanguage: pair.langACode,
                            transcript: plainText,
                            translation: ""
                        ),
                        latency,
                        modelName
                    )
                }
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError ?? NSError(domain: "GeminiLiveSessionClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "All transcription models failed"])
    }

    // MARK: - Mode A (Ultra-Low Latency Stream)

    private func runStreamingDirectCall(
        wavData: Data,
        pair: LanguagePair,
        modelName: String,
        forcedDirection: SpokenDirection?,
        onFirstAudioChunkReady: ((_ text: String, _ targetLocale: String, _ ttftMs: Int64) -> Void)?
    ) async throws -> LiveInterpretationResult? {
        let startMs = Int64(Date().timeIntervalSince1970 * 1000)
        var ttftMs: Int64 = 0

        let model = ai.generativeModel(
            modelName: modelName,
            generationConfig: GenerationConfig(temperature: 0.1),
            systemInstruction: ModelContent(role: "system", parts: Self.interpreterSystemPrompt(pair: pair, forcedDirection: forcedDirection))
        )

        let audioPart = InlineDataPart(data: wavData, mimeType: "audio/wav")
        let stream = try model.generateContentStream(audioPart)
        var assembled = ""

        for try await chunk in stream {
            if let text = chunk.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if ttftMs == 0 {
                    ttftMs = Int64(Date().timeIntervalSince1970 * 1000) - startMs
                    latencyTracker.recordSample(ttftMs: ttftMs)
                }
                assembled += text
            }
        }

        let cleaned = assembled.trimmingCharacters(in: .whitespacesAndNewlines)
        if ScriptDetector.isPromptEchoOrSilence(cleaned) {
            return nil
        }

        let finalTranslated = try await enforceWrongLanguageGuard(
            text: cleaned,
            pair: pair,
            modelName: modelName
        )

        let direction = forcedDirection ?? ScriptDetector.inferDirectionFromOutput(
            pairId: pair.id,
            sourceText: "",
            translatedText: finalTranslated
        )
        let fallbackLocale = (direction == .aToB) ? pair.langBCode : pair.langACode
        let targetLocale = ScriptDetector.resolveTtsLocale(for: finalTranslated, fallbackLocale: fallbackLocale)
        let rttMs = Int64(Date().timeIntervalSince1970 * 1000) - startMs
        latencyTracker.recordSample(ttftMs: ttftMs, rttMs: rttMs)

        onFirstAudioChunkReady?(finalTranslated, targetLocale, ttftMs)
        return LiveInterpretationResult(
            direction: direction,
            sourceText: "",
            translatedText: finalTranslated,
            targetLocale: targetLocale,
            ttftMs: ttftMs,
            rttMs: rttMs,
            modelUsed: modelName
        )
    }

    // MARK: - Mode B (Structured JSON Dual-Transcript)

    private func runStructuredSubtitleCall(
        wavData: Data,
        pair: LanguagePair,
        modelName: String,
        forcedDirection: SpokenDirection?
    ) async throws -> LiveInterpretationResult? {
        let startMs = Int64(Date().timeIntervalSince1970 * 1000)
        let model = ai.generativeModel(
            modelName: modelName,
            generationConfig: GenerationConfig(
                temperature: 0.1,
                responseMIMEType: "application/json",
                responseSchema: Self.subtitleSchema
            ),
            systemInstruction: ModelContent(role: "system", parts: Self.interpreterSystemPrompt(pair: pair, forcedDirection: forcedDirection))
        )

        let audioPart = InlineDataPart(data: wavData, mimeType: "audio/wav")
        let response = try await model.generateContent(audioPart)
        let rttMs = Int64(Date().timeIntervalSince1970 * 1000) - startMs
        latencyTracker.recordSample(ttftMs: rttMs, rttMs: rttMs)

        guard let jsonText = response.text,
              let jsonData = jsonText.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(SubtitleInterpretationResponse.self, from: jsonData) else {
            return nil
        }

        if decoded.detectedDirection.uppercased() == "SILENCE" ||
           ScriptDetector.isPromptEchoOrSilence(decoded.targetTranslation) {
            return nil
        }

        let direction = forcedDirection ?? ScriptDetector.inferDirectionFromOutput(
            pairId: pair.id,
            sourceText: decoded.sourceTranscript,
            translatedText: decoded.targetTranslation,
            modelHint: decoded.detectedDirection
        )

        let fallbackLocale = (direction == .aToB) ? pair.langBCode : pair.langACode
        let targetLocale = ScriptDetector.resolveTtsLocale(for: decoded.targetTranslation, fallbackLocale: fallbackLocale)

        return LiveInterpretationResult(
            direction: direction,
            sourceText: decoded.sourceTranscript,
            translatedText: decoded.targetTranslation,
            targetLocale: targetLocale,
            ttftMs: rttMs,
            rttMs: rttMs,
            modelUsed: modelName
        )
    }

    // MARK: - Wrong-Language Post-Generation Guard (Section 5.3)

    private func enforceWrongLanguageGuard(
        text: String,
        pair: LanguagePair,
        modelName: String
    ) async throws -> String {
        if pair.id == "vi_en" && ScriptDetector.containsCJK(text) {
            return try await retranslateText(text, into: "English (en-US)", modelName: modelName)
        }
        if pair.id == "vi_zhtw" && !ScriptDetector.containsCJK(text) && !ScriptDetector.containsVietnameseDiacritics(text) {
            return try await retranslateText(text, into: "Traditional Chinese, Taiwan Mandarin (zh-TW, 繁體中文)", modelName: modelName)
        }
        return text
    }

    private func retranslateText(_ text: String, into targetLanguage: String, modelName: String) async throws -> String {
        let model = ai.generativeModel(modelName: modelName, generationConfig: GenerationConfig(temperature: 0.1))
        let res = try await model.generateContent("Translate ONLY into \(targetLanguage). Output nothing else:\n\(text)")
        return res.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? text
    }

    // MARK: - Prompts & Schemas

    private static let subtitleSchema = Schema.object(
        properties: [
            "detectedDirection": .string(description: "A_TO_B | B_TO_A | SILENCE"),
            "sourceTranscript": .string(description: "Exact verbatim transcription in the spoken language"),
            "targetTranslation": .string(description: "Direct translation in the other language of the pair ONLY")
        ]
    )

    private static let transcribeSchema = Schema.object(
        properties: [
            "detectedLanguage": .string(description: "vi-VN | en-US | zh-TW | SILENCE"),
            "transcript": .string(description: "Complete verbatim transcription"),
            "translation": .string(description: "Natural translation into the other language of the active pair")
        ]
    )

    private static func interpreterSystemPrompt(pair: LanguagePair, forcedDirection: SpokenDirection?) -> String {
        let taiwanRule = pair.id == "vi_zhtw"
            ? "STRICT LANGUAGE PAIR RULE: Traditional Chinese, Taiwan Mandarin (zh-TW, 繁體中文) ONLY — use Taiwan vocabulary (計程車, 捷運, 軟體, 悠遊卡, 載具). NEVER output Simplified Chinese (zh-CN) or English."
            : "STRICT LANGUAGE PAIR RULE: Vietnamese (vi-VN) and US English (en-US) ONLY. NEVER output Chinese."
        let dirHint = forcedDirection.map { " Direction hint: \($0.rawValue)." } ?? ""
        return "You are a silent simultaneous interpreter for \(pair.langACode) <-> \(pair.langBCode). \(taiwanRule)\(dirHint) If the audio is silence or noise, output ONLY 'silence'."
    }

    private static func transcribeSystemPrompt(pair: LanguagePair) -> String {
        "Transcribe the audio verbatim and translate into the other language of the pair \(pair.langACode) <-> \(pair.langBCode). Output valid JSON."
    }
}
