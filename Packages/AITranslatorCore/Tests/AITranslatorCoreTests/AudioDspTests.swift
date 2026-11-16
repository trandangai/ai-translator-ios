import XCTest
@testable import AITranslatorCore

final class AudioDspTests: XCTestCase {
    func testSilentFrameReturnsMinus90Db() {
        let silent = [Int16](repeating: 0, count: AudioFormatConstants.samplesPerFrame)
        let db = AudioDspMath.calculateRmsDb(samples: silent)
        XCTAssertEqual(db, -90.0, accuracy: 0.01)
    }

    func testFullScaleSquareWaveReturns0Db() {
        let loud = [Int16](repeating: 32767, count: AudioFormatConstants.samplesPerFrame)
        let db = AudioDspMath.calculateRmsDb(samples: loud)
        XCTAssertEqual(db, 0.0, accuracy: 0.1)
    }

    func testWaveformExtractorProduces24ClampedBands() {
        let samples = (0..<AudioFormatConstants.samplesPerFrame).map { i -> Int16 in
            i < 240 ? 1000 : 16000
        }
        let bands = AudioDspMath.extractWaveformBands(samples: samples)
        XCTAssertEqual(bands.count, 24)
        XCTAssertTrue(bands.allSatisfy { $0 >= 0.06 && $0 <= 1.0 })
        XCTAssertEqual(bands.last ?? 0, 1.0, accuracy: 0.001)
    }

    func testPreRollPrepends12FramesAndEnforcesMinMaxBounds() {
        let buffer = PreRollUtteranceBuffer()
        let frame = Data(repeating: 1, count: AudioFormatConstants.bytesPerFrame)
        for _ in 0..<15 {
            buffer.pushPreRollFrame(frame)
        }
        // Append 1 speech frame -> total 12 pre-roll + 1 speech = 13 frames = 12,480 bytes (>= 4,800)
        buffer.appendUtteranceChunk(frame)
        let wav = buffer.consumeUtteranceWavBytes()
        XCTAssertNotNil(wav)
        XCTAssertEqual(wav?.count, 44 + 13 * AudioFormatConstants.bytesPerFrame)
    }

    func testShortUtteranceBelow150msIsDiscarded() {
        let buffer = PreRollUtteranceBuffer()
        let tiny = Data(repeating: 2, count: 1000)
        buffer.appendUtteranceChunk(tiny)
        XCTAssertNil(buffer.consumeUtteranceWavBytes())
    }

    func testWavHeaderFormat() {
        let pcm = Data(repeating: 0x10, count: 960)
        let wav = WavEncoder.pcm16ToWavBytes(pcm)
        XCTAssertEqual(wav.count, 44 + 960)
        XCTAssertEqual(String(data: wav.subdata(in: 0..<4), encoding: .utf8), "RIFF")
        XCTAssertEqual(String(data: wav.subdata(in: 8..<12), encoding: .utf8), "WAVE")
        XCTAssertEqual(String(data: wav.subdata(in: 12..<16), encoding: .utf8), "fmt ")
        XCTAssertEqual(String(data: wav.subdata(in: 36..<40), encoding: .utf8), "data")
    }
}
