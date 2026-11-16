import AITranslatorCore
import Foundation
import Observation

@MainActor
@Observable
public final class TranscribeViewModel {
    public private(set) var isRecording: Bool = false
    public private(set) var isProcessing: Bool = false
    public private(set) var waveformBands: [Float] = AudioFormatConstants.idleWaveformBands
    public private(set) var result: StructuredTranscribeResponse?
    public private(set) var latencyMs: Int64 = 0
    public private(set) var modelUsed: String = ""
    public private(set) var diagnosticHint: String?

    private let audioSession: AudioSessionManager
    private let captureEngine = AudioCaptureEngine()
    private let ttsEngine = TtsPlaybackEngine()
    private let geminiClient = GeminiLiveSessionClient()
    private let buffer = PreRollUtteranceBuffer()
    private var peakObservedDbfs: Float = -90.0

    public let prefsManager: LocalPreferencesManager
    private let userRepo: UserSettingsRepository
    private let authService: AuthService

    public init(
        audioSession: AudioSessionManager,
        prefsManager: LocalPreferencesManager,
        userRepo: UserSettingsRepository,
        authService: AuthService
    ) {
        self.audioSession = audioSession
        self.prefsManager = prefsManager
        self.userRepo = userRepo
        self.authService = authService
    }

    public func toggleRecording() {
        if isRecording {
            stopAndTranscribe()
        } else {
            startRecording()
        }
    }

    public func startRecording() {
        diagnosticHint = nil
        peakObservedDbfs = -90.0
        buffer.clear()

        do {
            try audioSession.configureForLiveSession()
            isRecording = true
            try captureEngine.start { [weak self] frameData in
                Task { @MainActor [weak self] in
                    guard let self, self.isRecording else { return }
                    let rms = AudioDspMath.calculateRmsDb(pcmData: frameData)
                    self.peakObservedDbfs = max(self.peakObservedDbfs, rms)
                    self.waveformBands = AudioDspMath.extractWaveformBands(pcmData: frameData)
                    self.buffer.appendUtteranceChunk(frameData)
                }
            }
        } catch {
            isRecording = false
            diagnosticHint = error.localizedDescription
        }
    }

    public func stopAndTranscribe() {
        isRecording = false
        captureEngine.stop()
        waveformBands = AudioFormatConstants.idleWaveformBands

        guard let wavData = buffer.consumeUtteranceWavBytes() else {
            diagnosticHint = String(
                format: "Recording too short (<150ms) or silent. Peak mic level: %.1f dBFS",
                peakObservedDbfs
            )
            return
        }

        isProcessing = true
        let prefs = prefsManager.preferences
        let pair = BuiltInLanguagePairs.pair(for: prefs.preferredPairId)

        Task {
            defer { self.isProcessing = false }
            do {
                let output = try await geminiClient.transcribeAudioWav(
                    wavData: wavData,
                    pair: pair,
                    primaryModel: prefs.transcribeModelName,
                    maxRpm: prefs.maxRequestsPerMinute
                )
                self.result = output.response
                self.latencyMs = output.latencyMs
                self.modelUsed = output.modelUsed

                if let uid = self.authService.currentUser?.uid {
                    await self.userRepo.incrementUsage(uid: uid, transcribeDelta: 1)
                }
            } catch {
                self.diagnosticHint = error.localizedDescription
            }
        }
    }

    public func speakTranscript() {
        guard let result else { return }
        let locale = ScriptDetector.resolveTtsLocale(for: result.transcript, fallbackLocale: result.detectedLanguage)
        Task {
            await ttsEngine.speakTranslatedStream(
                text: result.transcript,
                targetLocale: locale,
                volumeBoostDb: prefsManager.preferences.volumeBoostDb
            )
        }
    }
}
