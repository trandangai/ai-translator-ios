import AITranslatorCore
import AVFoundation
import Foundation

/// Multi-tier TTS playback engine with script-based locale guard and playback lifecycle callbacks (Section 3.6).
@MainActor
public final class TtsPlaybackEngine: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var activeCompletion: (() -> Void)?

    /// Optional Tier 1 Cloud Neural TTS provider returning MP3 `Data`.
    public var cloudTtsFetcher: (@Sendable (_ text: String, _ locale: String) async throws -> Data)?

    public var onPlaybackStarted: (() -> Void)?
    public var onPlaybackEnded: (() -> Void)?

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func speakTranslatedStream(
        text: String,
        targetLocale: String,
        volumeBoostDb: Int
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        stop()

        let resolvedLocale = ScriptDetector.resolveTtsLocale(for: trimmed, fallbackLocale: targetLocale)
        onPlaybackStarted?()

        // Tier 1: Cloud Neural TTS (if configured and <= 200 chars)
        if let fetcher = cloudTtsFetcher, trimmed.count <= 200 {
            do {
                let mp3Data = try await fetcher(trimmed, resolvedLocale)
                try await playMp3Data(mp3Data, volumeBoostDb: volumeBoostDb)
                onPlaybackEnded?()
                return
            } catch {
                // Fall back to Tier 2 AVSpeechSynthesizer
            }
        }

        // Tier 2: On-device AVSpeechSynthesizer
        await speakWithNativeSynthesizer(text: trimmed, locale: resolvedLocale, volumeBoostDb: volumeBoostDb)
        onPlaybackEnded?()
    }

    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        audioPlayer?.stop()
        audioPlayer = nil
        activeCompletion?()
        activeCompletion = nil
    }

    private func playMp3Data(_ data: Data, volumeBoostDb: Int) async throws {
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        // Map 0..12 dB to linear 0.8..1.0 on AVAudioPlayer (full >1.0 boost requires AVAudioEngine gain node)
        player.volume = min(1.0, 0.8 + Float(volumeBoostDb) * 0.02)
        self.audioPlayer = player

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.activeCompletion = { continuation.resume() }
            player.play()
        }
    }

    private func speakWithNativeSynthesizer(text: String, locale: String, volumeBoostDb: Int) async {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: locale)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.51 // ~1.02x natural pace (Section 3.6)
        utterance.volume = min(1.0, 0.85 + Float(volumeBoostDb) * 0.015)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.activeCompletion = { continuation.resume() }
            self.synthesizer.speak(utterance)
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.activeCompletion?()
            self.activeCompletion = nil
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.activeCompletion?()
            self.activeCompletion = nil
        }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.activeCompletion?()
            self.activeCompletion = nil
        }
    }
}
