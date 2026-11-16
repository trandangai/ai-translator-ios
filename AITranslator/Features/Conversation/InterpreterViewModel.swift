import AITranslatorCore
import Foundation
import Observation
import UIKit

/// Main @MainActor orchestrator wiring AudioCaptureEngine, EchoGateStateMachine, GeminiLiveSessionClient, and TtsPlaybackEngine (Section 2.1, 4.3, 7.3).
@MainActor
@Observable
public final class InterpreterViewModel {
    public private(set) var gatePhase: GatePhase = .idle
    public private(set) var waveformBands: [Float] = AudioFormatConstants.idleWaveformBands
    public private(set) var currentRmsDb: Float = -90.0
    public private(set) var isMuted: Bool = false
    public private(set) var isManualRecording: Bool = false
    public private(set) var activeTwoButtonDirection: SpokenDirection?

    public private(set) var lastDirection: SpokenDirection = .unknown
    public private(set) var partnerAText: String = ""
    public private(set) var partnerASubtext: String = ""
    public private(set) var partnerBText: String = ""
    public private(set) var partnerBSubtext: String = ""
    public private(set) var errorBanner: String?

    public let audioSession: AudioSessionManager
    public let captureEngine: AudioCaptureEngine
    public let ttsEngine: TtsPlaybackEngine
    public let geminiClient: GeminiLiveSessionClient
    public let historyStore: EncryptedHistoryStore
    public let userRepo: UserSettingsRepository
    public let prefsManager: LocalPreferencesManager
    public let authService: AuthService

    private let echoGate = EchoGateStateMachine()
    private let buffer = PreRollUtteranceBuffer()
    private var tailHoldTask: Task<Void, Never>?
    private var sessionActive: Bool = false

    public init(
        audioSession: AudioSessionManager,
        captureEngine: AudioCaptureEngine = AudioCaptureEngine(),
        ttsEngine: TtsPlaybackEngine = TtsPlaybackEngine(),
        geminiClient: GeminiLiveSessionClient = GeminiLiveSessionClient(),
        historyStore: EncryptedHistoryStore = EncryptedHistoryStore(),
        userRepo: UserSettingsRepository,
        prefsManager: LocalPreferencesManager,
        authService: AuthService
    ) {
        self.audioSession = audioSession
        self.captureEngine = captureEngine
        self.ttsEngine = ttsEngine
        self.geminiClient = geminiClient
        self.historyStore = historyStore
        self.userRepo = userRepo
        self.prefsManager = prefsManager
        self.authService = authService

        self.audioSession.onAudioFocusLost = { [weak self] in
            self?.stopSession()
        }
        self.ttsEngine.onPlaybackStarted = { [weak self] in
            guard let self else { return }
            self.echoGate.onPlaybackStarted(nowElapsedMs: Self.nowMs())
            self.gatePhase = self.echoGate.phase
        }
        self.ttsEngine.onPlaybackEnded = { [weak self] in
            guard let self else { return }
            let now = Self.nowMs()
            self.echoGate.onPlaybackFinished(nowElapsedMs: now)
            self.gatePhase = self.echoGate.phase
            self.scheduleTailHoldReopen()
        }
    }

    public func startSession() {
        let prefs = prefsManager.preferences
        echoGate.updateConfig(prefs.echoGateConfig)
        UIApplication.shared.isIdleTimerDisabled = prefs.keepScreenOn

        do {
            try audioSession.configureForLiveSession()
            let now = Self.nowMs()
            geminiClient.warmUpSession(nowElapsedMs: now)
            echoGate.startSession(nowElapsedMs: now)
            gatePhase = echoGate.phase
            sessionActive = true
            isMuted = false
            errorBanner = nil

            if let uid = authService.currentUser?.uid {
                Task { await userRepo.incrementUsage(uid: uid, sessionsDelta: 1) }
            }

            try captureEngine.start { [weak self] frameData in
                Task { @MainActor [weak self] in
                    self?.handleAudioFrame(frameData)
                }
            }
        } catch {
            errorBanner = error.localizedDescription
            stopSession()
        }
    }

    public func stopSession() {
        sessionActive = false
        tailHoldTask?.cancel()
        tailHoldTask = nil
        captureEngine.stop()
        ttsEngine.stop()
        buffer.clear()
        echoGate.stopSession()
        geminiClient.closeSession()
        audioSession.deactivate()
        UIApplication.shared.isIdleTimerDisabled = false

        gatePhase = .idle
        waveformBands = AudioFormatConstants.idleWaveformBands
        isManualRecording = false
        activeTwoButtonDirection = nil
    }

    public func toggleMute() {
        isMuted.toggle()
        echoGate.setMuted(isMuted, nowElapsedMs: Self.nowMs())
        gatePhase = echoGate.phase
    }

    public func toggleManualAutoRecord() {
        guard prefsManager.preferences.interactionMode == .auto else { return }
        if isManualRecording {
            isManualRecording = false
            flushAndTranslate(forcedDirection: nil)
        } else {
            isManualRecording = true
            buffer.clear()
        }
    }

    public func toggleTwoButtonTalk(direction: SpokenDirection) {
        if activeTwoButtonDirection == direction {
            activeTwoButtonDirection = nil
            flushAndTranslate(forcedDirection: direction)
        } else {
            ttsEngine.stop()
            buffer.clear()
            activeTwoButtonDirection = direction
            gatePhase = .speechActive
        }
    }

    public func replayTTS(text: String, locale: String) {
        Task {
            await ttsEngine.speakTranslatedStream(
                text: text,
                targetLocale: locale,
                volumeBoostDb: prefsManager.preferences.volumeBoostDb
            )
        }
    }

    public var droppedChunksCount: Int {
        buffer.droppedChunksCount
    }

    // MARK: - Frame Loop

    private func handleAudioFrame(_ frameData: Data) {
        guard sessionActive else { return }
        let now = Self.nowMs()
        geminiClient.checkAndRenewIfNeeded(nowElapsedMs: now)

        let rmsDb = AudioDspMath.calculateRmsDb(pcmData: frameData)
        currentRmsDb = rmsDb
        waveformBands = AudioDspMath.extractWaveformBands(pcmData: frameData)

        // Manual TWO_BUTTON or AUTO manual override
        if activeTwoButtonDirection != nil || isManualRecording {
            buffer.appendUtteranceChunk(frameData)
            if buffer.peekRawUtteranceBytes().count >= AudioFormatConstants.maxUtteranceBytes {
                let dir = activeTwoButtonDirection
                activeTwoButtonDirection = nil
                isManualRecording = false
                flushAndTranslate(forcedDirection: dir)
            }
            return
        }

        guard prefsManager.preferences.interactionMode == .auto else { return }

        let decision = echoGate.onAudioFrame(rmsDb: rmsDb, nowElapsedMs: now)
        gatePhase = decision.phase

        if decision.triggeredIdleTimeout {
            stopSession()
            return
        }

        if decision.triggeredBargeIn {
            ttsEngine.stop()
            buffer.clear()
        }

        if decision.shouldForwardMicChunk {
            buffer.appendUtteranceChunk(frameData)
            if echoGate.currentSpeechDurationMs >= AudioFormatConstants.maxContinuousSpeechMs {
                echoGate.forceEndSpeech(nowElapsedMs: now)
                gatePhase = echoGate.phase
                flushAndTranslate(forcedDirection: nil)
            }
        } else if decision.phase == .listeningGateOpen {
            buffer.pushPreRollFrame(frameData)
        }

        if decision.triggeredEndOfSpeech {
            flushAndTranslate(forcedDirection: nil)
        }
    }

    private func flushAndTranslate(forcedDirection: SpokenDirection?) {
        guard let wavData = buffer.consumeUtteranceWavBytes() else {
            echoGate.reopenListeningGate(nowElapsedMs: Self.nowMs())
            gatePhase = echoGate.phase
            return
        }

        gatePhase = .translating
        let prefs = prefsManager.preferences
        let pair = BuiltInLanguagePairs.pair(for: prefs.preferredPairId)
        let audioSeconds = max(1, (wavData.count - 44) / (AudioFormatConstants.inputSampleRate * 2))

        Task {
            do {
                let result = try await geminiClient.interpretUtteranceWav(
                    wavData: wavData,
                    pair: pair,
                    primaryModel: prefs.liveModelName,
                    subtitlesEnabled: prefs.subtitlesEnabled,
                    maxRpm: prefs.maxRequestsPerMinute,
                    forcedDirection: forcedDirection
                )

                guard let result else {
                    self.echoGate.reopenListeningGate(nowElapsedMs: Self.nowMs())
                    self.gatePhase = self.echoGate.phase
                    return
                }

                self.lastDirection = result.direction
                if result.direction == .aToB {
                    self.partnerAText = result.sourceText
                    self.partnerASubtext = result.translatedText
                    self.partnerBText = result.translatedText
                    self.partnerBSubtext = result.sourceText
                } else {
                    self.partnerBText = result.sourceText
                    self.partnerBSubtext = result.translatedText
                    self.partnerAText = result.translatedText
                    self.partnerASubtext = result.sourceText
                }

                if prefs.saveEncryptedHistory {
                    self.historyStore.appendTurn(
                        SavedHistoryTurn(
                            pairId: pair.id,
                            direction: result.direction,
                            sourceText: result.sourceText,
                            translatedText: result.translatedText
                        )
                    )
                }

                if let uid = self.authService.currentUser?.uid {
                    await self.userRepo.incrementUsage(uid: uid, audioSecondsDelta: audioSeconds)
                }

                await self.ttsEngine.speakTranslatedStream(
                    text: result.translatedText,
                    targetLocale: result.targetLocale,
                    volumeBoostDb: prefs.volumeBoostDb
                )
            } catch {
                self.errorBanner = error.localizedDescription
                self.echoGate.reopenListeningGate(nowElapsedMs: Self.nowMs())
                self.gatePhase = self.echoGate.phase
            }
        }
    }

    private func scheduleTailHoldReopen() {
        tailHoldTask?.cancel()
        let tailMs = UInt64(prefsManager.preferences.echoGatingTailMs)
        tailHoldTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: tailMs * 1_000_000)
            guard !Task.isCancelled, let self else { return }
            self.echoGate.reopenListeningGate(nowElapsedMs: Self.nowMs())
            self.gatePhase = self.echoGate.phase
        }
    }

    private static func nowMs() -> Int64 {
        Int64(ProcessInfo.processInfo.systemUptime * 1000)
    }
}
