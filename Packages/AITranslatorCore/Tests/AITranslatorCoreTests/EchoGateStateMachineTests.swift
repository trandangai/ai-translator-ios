import XCTest
@testable import AITranslatorCore

final class EchoGateStateMachineTests: XCTestCase {
    func testThresholdFormulasMatchSpec() {
        let defaultConfig = EchoGateConfig()
        XCTAssertEqual(defaultConfig.speechRmsThresholdDb, -41.5, accuracy: 0.01)
        XCTAssertEqual(defaultConfig.bargeInRmsThresholdDb, -27.5, accuracy: 0.01)

        let maxSens = EchoGateConfig(vadSensitivityPct: 100)
        XCTAssertEqual(maxSens.speechRmsThresholdDb, -52.0, accuracy: 0.01)

        let minSens = EchoGateConfig(vadSensitivityPct: 1)
        XCTAssertEqual(minSens.speechRmsThresholdDb, -22.3, accuracy: 0.01)
        XCTAssertEqual(minSens.bargeInRmsThresholdDb, -12.0, accuracy: 0.01)
    }

    func testFullHalfDuplexCycleAndTailHold() {
        let sm = EchoGateStateMachine(config: EchoGateConfig(tailHoldMs: 320, vadSilenceMs: 400, vadSensitivityPct: 65))
        sm.startSession(nowElapsedMs: 1000)
        XCTAssertEqual(sm.phase, .listeningGateOpen)

        // Silence below -41.5 dBFS stays open, does not forward
        let d1 = sm.onAudioFrame(rmsDb: -60.0, nowElapsedMs: 1030)
        XCTAssertEqual(d1.phase, .listeningGateOpen)
        XCTAssertFalse(d1.shouldForwardMicChunk)

        // Voice above -41.5 dBFS enters SPEECH_ACTIVE
        let d2 = sm.onAudioFrame(rmsDb: -30.0, nowElapsedMs: 1060)
        XCTAssertEqual(d2.phase, .speechActive)
        XCTAssertTrue(d2.shouldForwardMicChunk)

        // Trailing silence < 400ms still forwards
        let d3 = sm.onAudioFrame(rmsDb: -55.0, nowElapsedMs: 1300)
        XCTAssertEqual(d3.phase, .speechActive)
        XCTAssertTrue(d3.shouldForwardMicChunk)

        // Silence >= 400ms triggers end-of-speech -> TRANSLATING
        let d4 = sm.onAudioFrame(rmsDb: -55.0, nowElapsedMs: 1460)
        XCTAssertEqual(d4.phase, .translating)
        XCTAssertTrue(d4.triggeredEndOfSpeech)
        XCTAssertFalse(d4.shouldForwardMicChunk)

        // Playback starts -> PLAYING_GATED
        sm.onPlaybackStarted(nowElapsedMs: 1800)
        XCTAssertEqual(sm.phase, .playingGated)
        XCTAssertFalse(sm.onAudioFrame(rmsDb: -20.0, nowElapsedMs: 1900).shouldForwardMicChunk)

        // Playback finishes -> TAIL_HOLD_GATED for 320ms
        sm.onPlaybackFinished(nowElapsedMs: 2500)
        XCTAssertEqual(sm.phase, .tailHoldGated)
        XCTAssertEqual(sm.onAudioFrame(rmsDb: -25.0, nowElapsedMs: 2800).phase, .tailHoldGated)

        // After 320ms -> LISTENING_GATE_OPEN
        XCTAssertEqual(sm.onAudioFrame(rmsDb: -60.0, nowElapsedMs: 2820).phase, .listeningGateOpen)
    }

    func testBargeInWhenEnabled() {
        let sm = EchoGateStateMachine(config: EchoGateConfig(vadSensitivityPct: 65, allowBargeIn: true))
        sm.startSession(nowElapsedMs: 0)
        sm.onPlaybackStarted(nowElapsedMs: 100)
        // Barge-in threshold is -27.5 dBFS
        let denied = sm.onAudioFrame(rmsDb: -30.0, nowElapsedMs: 130)
        XCTAssertFalse(denied.triggeredBargeIn)

        let allowed = sm.onAudioFrame(rmsDb: -25.0, nowElapsedMs: 160)
        XCTAssertTrue(allowed.triggeredBargeIn)
        XCTAssertEqual(allowed.phase, .speechActive)
        XCTAssertTrue(allowed.shouldForwardMicChunk)
    }

    func testIdleTimeoutClosesAfterTwoMinutes() {
        let sm = EchoGateStateMachine(config: EchoGateConfig(idleTimeoutMs: 120_000))
        sm.startSession(nowElapsedMs: 1000)
        let d = sm.onAudioFrame(rmsDb: -70.0, nowElapsedMs: 121_000)
        XCTAssertTrue(d.triggeredIdleTimeout)
        XCTAssertEqual(d.phase, .idle)
    }
}
