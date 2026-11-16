import XCTest
@testable import AITranslatorCore

final class AIUtilitiesTests: XCTestCase {
    func testScriptDetectionAndDirectionInference() {
        XCTAssertEqual(
            ScriptDetector.inferDirectionFromOutput(
                pairId: "vi_zhtw",
                sourceText: "Xin chào",
                translatedText: "你好"
            ),
            .aToB
        )
        XCTAssertEqual(
            ScriptDetector.inferDirectionFromOutput(
                pairId: "vi_zhtw",
                sourceText: "我要去捷運站",
                translatedText: "Tôi muốn đi trạm tàu điện ngầm"
            ),
            .bToA
        )
        XCTAssertEqual(
            ScriptDetector.resolveTtsLocale(for: "台北捷運", fallbackLocale: "vi-VN"),
            "zh-TW"
        )
        XCTAssertEqual(
            ScriptDetector.resolveTtsLocale(for: "Cảm ơn bạn", fallbackLocale: "en-US"),
            "vi-VN"
        )
        XCTAssertTrue(ScriptDetector.isPromptEchoOrSilence("silence"))
        XCTAssertTrue(ScriptDetector.isPromptEchoOrSilence("Silent simultaneous interpreter rule"))
    }

    func testSlidingWindowRateLimiter() throws {
        let limiter = SlidingWindowRateLimiter(maxRequestsPerMinute: 5)
        for i in 0..<5 {
            try limiter.checkAndRecordRateLimit(nowMs: Int64(i * 1000))
        }
        XCTAssertThrowsError(try limiter.checkAndRecordRateLimit(nowMs: 10_000))
        // After 60 seconds, oldest entries expire
        XCTAssertNoThrow(try limiter.checkAndRecordRateLimit(nowMs: 61_000))
    }

    func testReconnectPolicyBackoffAndRenewal() {
        let policy = ReconnectPolicy()
        XCTAssertEqual(policy.delayMs(forAttempt: 0), 400)
        XCTAssertEqual(policy.delayMs(forAttempt: 1), 800)
        XCTAssertEqual(policy.delayMs(forAttempt: 4), 6400)
        XCTAssertEqual(policy.delayMs(forAttempt: 5), 12000)
        XCTAssertNil(policy.delayMs(forAttempt: 6))
        XCTAssertTrue(policy.shouldRenewSession(sessionStartedElapsedMs: 0, nowElapsedMs: 540_000))
    }

    func testLatencyTrackerPercentiles() {
        let tracker = LatencyStatsTracker()
        for v in [200, 400, 600, 800, 1000, 1200, 1400, 1600, 1800, 2000] as [Int64] {
            tracker.recordSample(ttftMs: v)
        }
        XCTAssertEqual(tracker.p50Ms, 1000)
        XCTAssertEqual(tracker.p90Ms, 1800)
    }
}
