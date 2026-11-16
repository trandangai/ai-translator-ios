import AITranslatorCore
import AVFoundation
import Foundation

/// Captures microphone audio via `AVAudioEngine` and converts it into 16 kHz Mono PCM16 30ms (960-byte) frames (Sections 3.1, 9.3).
public final class AudioCaptureEngine: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: Double(AudioFormatConstants.inputSampleRate),
        channels: AVAudioChannelCount(AudioFormatConstants.inputChannels),
        interleaved: true
    )!

    private var converter: AVAudioConverter?
    private var pendingPCMBytes = Data()
    private let lock = NSLock()
    private var isRunning = false

    public var isVoiceProcessingEnabled: Bool = false

    public init() {}

    public func start(onFrame: @escaping @Sendable (Data) -> Void) throws {
        lock.lock()
        guard !isRunning else {
            lock.unlock()
            return
        }
        pendingPCMBytes.removeAll(keepingCapacity: true)
        lock.unlock()

        let inputNode = engine.inputNode
        try? inputNode.setVoiceProcessingEnabled(isVoiceProcessingEnabled)

        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw NSError(domain: "AudioCaptureEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize AVAudioConverter"])
        }
        self.converter = converter

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.processInputBuffer(buffer, converter: converter, onFrame: onFrame)
        }

        engine.prepare()
        try engine.start()

        lock.lock()
        isRunning = true
        lock.unlock()
    }

    public func stop() {
        lock.lock()
        let wasRunning = isRunning
        isRunning = false
        pendingPCMBytes.removeAll(keepingCapacity: true)
        lock.unlock()

        guard wasRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    private func processInputBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        onFrame: @escaping @Sendable (Data) -> Void
    ) {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputCapacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio)) + 16
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else {
            return
        }

        var error: NSError?
        var inputConsumed = false
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil,
              let int16Ptr = outputBuffer.int16ChannelData?[0] else {
            return
        }

        let byteCount = Int(outputBuffer.frameLength) * 2
        let chunkData = Data(bytes: int16Ptr, count: byteCount)

        var readyFrames: [Data] = []
        lock.lock()
        pendingPCMBytes.append(chunkData)
        while pendingPCMBytes.count >= AudioFormatConstants.bytesPerFrame {
            let frame = pendingPCMBytes.prefix(AudioFormatConstants.bytesPerFrame)
            readyFrames.append(Data(frame))
            pendingPCMBytes.removeFirst(AudioFormatConstants.bytesPerFrame)
        }
        lock.unlock()

        for frame in readyFrames {
            onFrame(frame)
        }
    }
}
