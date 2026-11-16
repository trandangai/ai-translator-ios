import Foundation

/// Audio format constants matching Section 3.1 of IOS_ARCHITECTURE_AND_SPEC.md.
public enum AudioFormatConstants: Sendable {
    public static let inputSampleRate: Int = 16_000
    public static let inputChannels: Int = 1
    public static let bitsPerSample: Int = 16
    public static let frameDurationMs: Int = 30
    public static let samplesPerFrame: Int = (inputSampleRate * frameDurationMs) / 1000 // 480
    public static let bytesPerFrame: Int = samplesPerFrame * 2 // 960
    public static let outputSampleRate: Int = 24_000

    public static let preRollFrameCount: Int = 12 // 12 * 30ms = 360ms
    public static let maxUtteranceSeconds: Int = 45
    public static let maxUtteranceBytes: Int = inputSampleRate * 2 * maxUtteranceSeconds // 1,440,000
    public static let minUtteranceBytes: Int = 4_800 // 150ms
    public static let maxContinuousSpeechMs: Int64 = 12_000 // 12s auto-flush

    public static let waveformBandCount: Int = 24
    public static let idleWaveformBands: [Float] = Array(repeating: 0.08, count: waveformBandCount)
}
