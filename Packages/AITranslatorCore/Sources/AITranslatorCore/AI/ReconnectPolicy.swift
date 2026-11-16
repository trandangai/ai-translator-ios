import Foundation

/// Exponential backoff & proactive 9-minute session renewal policy (Section 5.6).
public struct ReconnectPolicy: Sendable {
    public let baseDelayMs: Int64
    public let maxDelayMs: Int64
    public let maxAttempts: Int
    public let renewalThresholdMs: Int64

    public init(
        baseDelayMs: Int64 = 400,
        maxDelayMs: Int64 = 12_000,
        maxAttempts: Int = 6,
        renewalThresholdMs: Int64 = 9 * 60 * 1000
    ) {
        self.baseDelayMs = baseDelayMs
        self.maxDelayMs = maxDelayMs
        self.maxAttempts = maxAttempts
        self.renewalThresholdMs = renewalThresholdMs
    }

    /// Returns delay in ms for 0-based attempt (`400, 800, 1600, 3200, 6400, 12000`), or `nil` if exhausted.
    public func delayMs(forAttempt attempt: Int) -> Int64? {
        guard attempt >= 0 && attempt < maxAttempts else { return nil }
        let multiplier = Int64(1 << min(attempt, 10))
        return min(maxDelayMs, baseDelayMs * multiplier)
    }

    public func shouldRenewSession(sessionStartedElapsedMs: Int64, nowElapsedMs: Int64) -> Bool {
        (nowElapsedMs - sessionStartedElapsedMs) >= renewalThresholdMs
    }
}
