import Foundation

public enum RateLimitError: Error, LocalizedError, Equatable {
    case quotaReached(maxRpm: Int, waitSeconds: Int)

    public var errorDescription: String? {
        switch self {
        case let .quotaReached(maxRpm, waitSeconds):
            return "Quota rate limit reached (\(maxRpm) requests/min). Please wait \(waitSeconds)s before the next utterance."
        }
    }
}

/// 60-second sliding-window RPM rate limiter (Section 5.2).
public final class SlidingWindowRateLimiter: @unchecked Sendable {
    private let lock = NSLock()
    private var timestampsMs: [Int64] = []
    public var maxRequestsPerMinute: Int

    public init(maxRequestsPerMinute: Int = 60) {
        self.maxRequestsPerMinute = max(5, min(120, maxRequestsPerMinute))
    }

    public func checkAndRecordRateLimit(nowMs: Int64) throws {
        lock.lock()
        defer { lock.unlock() }

        let cutoff = nowMs - 60_000
        timestampsMs.removeAll { $0 <= cutoff }

        if timestampsMs.count >= maxRequestsPerMinute {
            let oldest = timestampsMs.first ?? nowMs
            let remainingMs = max(1000, (oldest + 60_000) - nowMs)
            let waitSeconds = Int(ceil(Double(remainingMs) / 1000.0))
            throw RateLimitError.quotaReached(maxRpm: maxRequestsPerMinute, waitSeconds: waitSeconds)
        }

        timestampsMs.append(nowMs)
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        timestampsMs.removeAll()
    }
}
