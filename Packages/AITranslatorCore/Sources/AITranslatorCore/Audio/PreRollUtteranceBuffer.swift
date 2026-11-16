import Foundation

/// Thread-safe (actor-isolated or lock-free single-owner) Pre-Roll Ring Buffer + Utterance Accumulator (Section 3.4).
public final class PreRollUtteranceBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var preRollFrames: [Data] = []
    private var utteranceBuffer = Data()
    public private(set) var droppedChunksCount: Int = 0

    public init() {}

    /// Records a 30ms frame while waiting for speech (`utteranceBuffer.isEmpty`).
    public func pushPreRollFrame(_ pcmBytes: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard utteranceBuffer.isEmpty else { return }
        preRollFrames.append(pcmBytes)
        if preRollFrames.count > AudioFormatConstants.preRollFrameCount {
            preRollFrames.removeFirst(preRollFrames.count - AudioFormatConstants.preRollFrameCount)
        }
    }

    /// Appends an active speech frame; prepends all pre-roll frames on the first chunk of a new utterance.
    public func appendUtteranceChunk(_ pcmBytes: Data) {
        lock.lock()
        defer { lock.unlock() }
        if utteranceBuffer.isEmpty && !preRollFrames.isEmpty {
            for frame in preRollFrames {
                if utteranceBuffer.count + frame.count <= AudioFormatConstants.maxUtteranceBytes {
                    utteranceBuffer.append(frame)
                }
            }
            preRollFrames.removeAll(keepingCapacity: true)
        }

        if utteranceBuffer.count + pcmBytes.count <= AudioFormatConstants.maxUtteranceBytes {
            utteranceBuffer.append(pcmBytes)
        } else {
            droppedChunksCount += 1
        }
    }

    /// Consumes the accumulated utterance, normalizes it, and wraps it in a 44-byte RIFF WAV container.
    /// Returns `nil` if shorter than `minUtteranceBytes` (4800 bytes / 150ms).
    public func consumeUtteranceWavBytes() -> Data? {
        lock.lock()
        let raw = utteranceBuffer
        utteranceBuffer.removeAll(keepingCapacity: true)
        preRollFrames.removeAll(keepingCapacity: true)
        lock.unlock()

        guard raw.count >= AudioFormatConstants.minUtteranceBytes else {
            return nil
        }
        let normalized = AudioDspMath.normalizePcm16Audio(raw)
        return WavEncoder.pcm16ToWavBytes(normalized)
    }

    /// Consumes raw PCM16 bytes without WAV wrapping (for diagnostics such as peak dBFS).
    public func peekRawUtteranceBytes() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return utteranceBuffer
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        utteranceBuffer.removeAll(keepingCapacity: true)
        preRollFrames.removeAll(keepingCapacity: true)
    }
}
