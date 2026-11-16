import Foundation

/// Pure-Swift DSP utilities for 16 kHz PCM16 Mono audio frames (Sections 3.2, 3.3, 3.5).
public enum AudioDspMath: Sendable {
    /// Converts little-endian PCM16 bytes into `[Int16]`.
    public static func decodePCM16(_ data: Data) -> [Int16] {
        let count = data.count / 2
        guard count > 0 else { return [] }
        return data.withUnsafeBytes { rawBuffer in
            var samples = [Int16](repeating: 0, count: count)
            for i in 0..<count {
                let lo = UInt16(rawBuffer[i * 2])
                let hi = UInt16(rawBuffer[i * 2 + 1]) << 8
                samples[i] = Int16(bitPattern: lo | hi)
            }
            return samples
        }
    }

    /// Encodes `[Int16]` into little-endian PCM16 `Data`.
    public static func encodePCM16(_ samples: [Int16]) -> Data {
        var data = Data(capacity: samples.count * 2)
        for sample in samples {
            let bits = UInt16(bitPattern: sample)
            data.append(UInt8(bits & 0xFF))
            data.append(UInt8((bits >> 8) & 0xFF))
        }
        return data
    }

    /// Computes RMS dBFS (`-90.0 ... 0.0`) with DC offset removal and +12 dB (4x) VAD pre-amplification.
    public static func calculateRmsDb(samples: [Int16]) -> Float {
        guard !samples.isEmpty else { return -90.0 }
        let count = samples.count
        var sum: Int64 = 0
        for s in samples {
            sum += Int64(s)
        }
        let dcOffset = Double(sum) / Double(count)

        var sumSquares: Double = 0.0
        for s in samples {
            let centered = max(-32768.0, min(32767.0, Double(s) - dcOffset))
            let boosted: Double
            if abs(centered) > 45.0 {
                boosted = max(-32768.0, min(32767.0, centered * 4.0))
            } else {
                boosted = centered
            }
            let norm = boosted / 32768.0
            sumSquares += norm * norm
        }

        let rms = sqrt(sumSquares / Double(count))
        if rms <= 1e-5 {
            return -90.0
        }
        let db = Float(20.0 * log10(rms))
        return max(-90.0, min(0.0, db))
    }

    public static func calculateRmsDb(pcmData: Data) -> Float {
        calculateRmsDb(samples: decodePCM16(pcmData))
    }

    /// Extracts 24 normalized acoustic waveform bands (`0.06 ... 1.0`) from a 480-sample frame.
    public static func extractWaveformBands(samples: [Int16]) -> [Float] {
        let bandCount = AudioFormatConstants.waveformBandCount
        guard samples.count >= bandCount else {
            return AudioFormatConstants.idleWaveformBands
        }
        let bucketSize = samples.count / bandCount
        var bands = [Float](repeating: 0.06, count: bandCount)
        for b in 0..<bandCount {
            let start = b * bucketSize
            let end = (b == bandCount - 1) ? samples.count : (start + bucketSize)
            var peak: Float = 0.0
            for i in start..<end {
                let norm = abs(Float(samples[i])) / 32768.0
                if norm > peak { peak = norm }
            }
            bands[b] = max(0.06, min(1.0, peak * 6.5))
        }
        return bands
    }

    public static func extractWaveformBands(pcmData: Data) -> [Float] {
        extractWaveformBands(samples: decodePCM16(pcmData))
    }

    /// Removes DC offset and applies automatic peak normalization up to +24 dB (16x) for quiet speakers.
    public static func normalizePcm16Audio(_ pcmData: Data) -> Data {
        var samples = decodePCM16(pcmData)
        guard !samples.isEmpty else { return pcmData }

        var sum: Int64 = 0
        for s in samples { sum += Int64(s) }
        let dcOffset = Double(sum) / Double(samples.count)

        var centered = [Double](repeating: 0, count: samples.count)
        var peak: Double = 0
        for i in 0..<samples.count {
            let c = max(-32768.0, min(32767.0, Double(samples[i]) - dcOffset))
            centered[i] = c
            let absC = abs(c)
            if absC > peak { peak = absC }
        }

        let gain: Double
        if peak >= 180.0 && peak <= 22000.0 {
            gain = max(1.0, min(16.0, 26000.0 / peak))
        } else {
            gain = 1.0
        }

        for i in 0..<samples.count {
            let scaled = max(-32767.0, min(32767.0, centered[i] * gain))
            samples[i] = Int16(scaled.rounded())
        }
        return encodePCM16(samples)
    }

    /// Computes peak dBFS of a PCM16 buffer (used for diagnostic hints on short/silent recordings).
    public static func peakDbfs(_ pcmData: Data) -> Float {
        let samples = decodePCM16(pcmData)
        guard !samples.isEmpty else { return -90.0 }
        var peak: Float = 0
        for s in samples {
            let norm = abs(Float(s)) / 32768.0
            if norm > peak { peak = norm }
        }
        if peak <= 1e-5 { return -90.0 }
        return max(-90.0, min(0.0, 20.0 * log10(peak)))
    }
}
