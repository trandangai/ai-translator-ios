import Foundation

/// Prepends a standard 44-byte RIFF WAVE header for 16 kHz, 1-channel, 16-bit PCM audio (Section 3.5).
public enum WavEncoder: Sendable {
    public static func pcm16ToWavBytes(
        _ pcmData: Data,
        sampleRate: Int = AudioFormatConstants.inputSampleRate,
        channels: Int = AudioFormatConstants.inputChannels,
        bitsPerSample: Int = AudioFormatConstants.bitsPerSample
    ) -> Data {
        let dataSize = UInt32(pcmData.count)
        let chunkSize = UInt32(36) + dataSize
        let byteRate = UInt32(sampleRate * channels * (bitsPerSample / 8))
        let blockAlign = UInt16(channels * (bitsPerSample / 8))

        var header = Data(capacity: 44 + pcmData.count)
        header.append(contentsOf: "RIFF".utf8)
        appendUInt32LE(&header, chunkSize)
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        appendUInt32LE(&header, 16) // Subchunk1Size for PCM
        appendUInt16LE(&header, 1)  // AudioFormat = 1 (PCM)
        appendUInt16LE(&header, UInt16(channels))
        appendUInt32LE(&header, UInt32(sampleRate))
        appendUInt32LE(&header, byteRate)
        appendUInt16LE(&header, blockAlign)
        appendUInt16LE(&header, UInt16(bitsPerSample))
        header.append(contentsOf: "data".utf8)
        appendUInt32LE(&header, dataSize)
        header.append(pcmData)
        return header
    }

    private static func appendUInt32LE(_ data: inout Data, _ value: UInt32) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private static func appendUInt16LE(_ data: inout Data, _ value: UInt16) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }
}
