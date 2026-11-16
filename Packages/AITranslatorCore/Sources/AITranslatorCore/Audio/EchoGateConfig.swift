import Foundation

/// 7 deterministic phases of the Half-Duplex Echo Gate State Machine (Section 4.1).
public enum GatePhase: String, Codable, Sendable, CaseIterable {
    case idle = "IDLE"
    case listeningGateOpen = "LISTENING_GATE_OPEN"
    case speechActive = "SPEECH_ACTIVE"
    case translating = "TRANSLATING"
    case playingGated = "PLAYING_GATED"
    case tailHoldGated = "TAIL_HOLD_GATED"
    case muted = "MUTED"
}

/// Configuration & threshold formulas for `EchoGateStateMachine` (Section 4.2).
public struct EchoGateConfig: Sendable, Equatable {
    public var tailHoldMs: Int64
    public var vadSilenceMs: Int64
    public var vadSensitivityPct: Int
    public var allowBargeIn: Bool
    public var idleTimeoutMs: Int64

    public init(
        tailHoldMs: Int64 = 320,
        vadSilenceMs: Int64 = 400,
        vadSensitivityPct: Int = 65,
        allowBargeIn: Bool = false,
        idleTimeoutMs: Int64 = 120_000
    ) {
        self.tailHoldMs = max(100, min(1500, tailHoldMs))
        self.vadSilenceMs = max(150, min(2000, vadSilenceMs))
        self.vadSensitivityPct = max(1, min(100, vadSensitivityPct))
        self.allowBargeIn = allowBargeIn
        self.idleTimeoutMs = idleTimeoutMs
    }

    /// `speechRmsThresholdDb = -22.0 - (clamp(vadSensitivityPct, 1, 100) * 0.30)`
    public var speechRmsThresholdDb: Float {
        let clamped = Float(max(1, min(100, vadSensitivityPct)))
        return -22.0 - (clamped * 0.30)
    }

    /// `bargeInRmsThresholdDb = min(speechRmsThresholdDb + 14.0, -12.0)`
    public var bargeInRmsThresholdDb: Float {
        min(speechRmsThresholdDb + 14.0, -12.0)
    }
}

/// Result emitted on each 30ms frame evaluation.
public struct EchoGateDecision: Sendable, Equatable {
    public let phase: GatePhase
    public let shouldForwardMicChunk: Bool
    public let triggeredEndOfSpeech: Bool
    public let triggeredBargeIn: Bool
    public let triggeredIdleTimeout: Bool

    public init(
        phase: GatePhase,
        shouldForwardMicChunk: Bool,
        triggeredEndOfSpeech: Bool = false,
        triggeredBargeIn: Bool = false,
        triggeredIdleTimeout: Bool = false
    ) {
        self.phase = phase
        self.shouldForwardMicChunk = shouldForwardMicChunk
        self.triggeredEndOfSpeech = triggeredEndOfSpeech
        self.triggeredBargeIn = triggeredBargeIn
        self.triggeredIdleTimeout = triggeredIdleTimeout
    }
}
