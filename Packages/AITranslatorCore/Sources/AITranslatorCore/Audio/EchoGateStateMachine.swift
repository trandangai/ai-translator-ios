import Foundation

/// Deterministic Half-Duplex Echo Gate State Machine (Section 4.3).
public final class EchoGateStateMachine: @unchecked Sendable {
    private let lock = NSLock()
    public private(set) var config: EchoGateConfig
    public private(set) var phase: GatePhase = .idle

    private var speechStartElapsedMs: Int64 = 0
    private var lastVoiceActivityElapsedMs: Int64 = 0
    private var lastInteractionElapsedMs: Int64 = 0
    private var playbackEndedElapsedMs: Int64 = 0
    private var peakRmsDuringSpeechDb: Float = -90.0

    public init(config: EchoGateConfig = EchoGateConfig()) {
        self.config = config
    }

    public func updateConfig(_ newConfig: EchoGateConfig) {
        lock.lock()
        defer { lock.unlock() }
        self.config = newConfig
    }

    public func startSession(nowElapsedMs: Int64) {
        lock.lock()
        defer { lock.unlock() }
        phase = .listeningGateOpen
        lastInteractionElapsedMs = nowElapsedMs
        peakRmsDuringSpeechDb = -90.0
    }

    public func stopSession() {
        lock.lock()
        defer { lock.unlock() }
        phase = .idle
        peakRmsDuringSpeechDb = -90.0
    }

    public func setMuted(_ muted: Bool, nowElapsedMs: Int64) {
        lock.lock()
        defer { lock.unlock() }
        if muted {
            phase = .muted
            peakRmsDuringSpeechDb = -90.0
        } else if phase == .muted {
            phase = .listeningGateOpen
            lastInteractionElapsedMs = nowElapsedMs
        }
    }

    public func forceEndSpeech(nowElapsedMs: Int64) {
        lock.lock()
        defer { lock.unlock() }
        guard phase == .speechActive || phase == .listeningGateOpen else { return }
        peakRmsDuringSpeechDb = -90.0
        lastInteractionElapsedMs = nowElapsedMs
        phase = .translating
    }

    public func onPlaybackStarted(nowElapsedMs: Int64) {
        lock.lock()
        defer { lock.unlock() }
        lastInteractionElapsedMs = nowElapsedMs
        peakRmsDuringSpeechDb = -90.0
        phase = .playingGated
    }

    public func onPlaybackFinished(nowElapsedMs: Int64) {
        lock.lock()
        defer { lock.unlock() }
        playbackEndedElapsedMs = nowElapsedMs
        lastInteractionElapsedMs = nowElapsedMs
        phase = .tailHoldGated
    }

    public func reopenListeningGate(nowElapsedMs: Int64) {
        lock.lock()
        defer { lock.unlock() }
        guard phase != .idle && phase != .muted else { return }
        lastInteractionElapsedMs = nowElapsedMs
        peakRmsDuringSpeechDb = -90.0
        phase = .listeningGateOpen
    }

    public var currentSpeechDurationMs: Int64 {
        lock.lock()
        defer { lock.unlock() }
        guard phase == .speechActive else { return 0 }
        return max(0, lastVoiceActivityElapsedMs - speechStartElapsedMs)
    }

    /// Evaluates a single 30ms audio frame.
    public func onAudioFrame(rmsDb: Float, nowElapsedMs: Int64) -> EchoGateDecision {
        lock.lock()
        defer { lock.unlock() }

        switch phase {
        case .idle, .muted, .translating:
            return EchoGateDecision(phase: phase, shouldForwardMicChunk: false)

        case .listeningGateOpen:
            if rmsDb >= config.speechRmsThresholdDb {
                phase = .speechActive
                speechStartElapsedMs = nowElapsedMs
                lastVoiceActivityElapsedMs = nowElapsedMs
                lastInteractionElapsedMs = nowElapsedMs
                peakRmsDuringSpeechDb = rmsDb
                return EchoGateDecision(phase: phase, shouldForwardMicChunk: true)
            } else if nowElapsedMs - lastInteractionElapsedMs >= config.idleTimeoutMs {
                phase = .idle
                return EchoGateDecision(
                    phase: phase,
                    shouldForwardMicChunk: false,
                    triggeredIdleTimeout: true
                )
            } else {
                return EchoGateDecision(phase: phase, shouldForwardMicChunk: false)
            }

        case .speechActive:
            peakRmsDuringSpeechDb = max(peakRmsDuringSpeechDb, rmsDb)
            let isContinuingVoice = (rmsDb >= config.speechRmsThresholdDb) &&
                (rmsDb >= peakRmsDuringSpeechDb - 14.0)

            if isContinuingVoice {
                lastVoiceActivityElapsedMs = nowElapsedMs
                lastInteractionElapsedMs = nowElapsedMs
                return EchoGateDecision(phase: phase, shouldForwardMicChunk: true)
            } else {
                let silenceElapsed = nowElapsedMs - lastVoiceActivityElapsedMs
                if silenceElapsed >= config.vadSilenceMs {
                    peakRmsDuringSpeechDb = -90.0
                    phase = .translating
                    return EchoGateDecision(
                        phase: phase,
                        shouldForwardMicChunk: false,
                        triggeredEndOfSpeech: true
                    )
                } else {
                    return EchoGateDecision(phase: phase, shouldForwardMicChunk: true)
                }
            }

        case .playingGated:
            if config.allowBargeIn && rmsDb >= config.bargeInRmsThresholdDb {
                phase = .speechActive
                speechStartElapsedMs = nowElapsedMs
                lastVoiceActivityElapsedMs = nowElapsedMs
                lastInteractionElapsedMs = nowElapsedMs
                peakRmsDuringSpeechDb = rmsDb
                return EchoGateDecision(
                    phase: phase,
                    shouldForwardMicChunk: true,
                    triggeredBargeIn: true
                )
            }
            return EchoGateDecision(phase: phase, shouldForwardMicChunk: false)

        case .tailHoldGated:
            if nowElapsedMs - playbackEndedElapsedMs >= config.tailHoldMs {
                phase = .listeningGateOpen
                lastInteractionElapsedMs = nowElapsedMs
                return EchoGateDecision(phase: phase, shouldForwardMicChunk: false)
            }
            return EchoGateDecision(phase: phase, shouldForwardMicChunk: false)
        }
    }
}
