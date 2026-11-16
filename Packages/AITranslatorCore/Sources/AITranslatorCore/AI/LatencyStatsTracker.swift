import Foundation

/// Tracks TTFT / RTT latency samples, p50/p90 percentiles, and estimated session cost (Section 5.3, 7.3).
public final class LatencyStatsTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var samplesMs: [Int64] = []
    public private(set) var lastTtftMs: Int64 = 0
    public private(set) var lastRttMs: Int64 = 0

    public init() {}

    public func recordSample(ttftMs: Int64, rttMs: Int64? = nil) {
        lock.lock()
        defer { lock.unlock() }
        lastTtftMs = ttftMs
        if let rttMs { lastRttMs = rttMs }
        samplesMs.append(ttftMs)
        if samplesMs.count > 200 {
            samplesMs.removeFirst(samplesMs.count - 200)
        }
    }

    public var p50Ms: Int64 {
        percentile(0.50)
    }

    public var p90Ms: Int64 {
        percentile(0.90)
    }

    private func percentile(_ p: Double) -> Int64 {
        lock.lock()
        let sorted = samplesMs.sorted()
        lock.unlock()
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, max(0, Int(ceil(p * Double(sorted.count))) - 1))
        return sorted[index]
    }

    public static func estimatedCostUsd(audioSecondsUsed: Int) -> Double {
        (Double(audioSecondsUsed) / 60.0) * 0.008
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        samplesMs.removeAll()
        lastTtftMs = 0
        lastRttMs = 0
    }
}
