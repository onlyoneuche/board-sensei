@preconcurrency import AVFoundation
import Combine
import Foundation
import MusicCore

@MainActor
final class LessonNarrationService: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case speaking
        case paused
    }

    @Published private(set) var state: State = .idle

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var playbackSource: PlaybackSource?
    private let manifest: NarrationManifest

    private enum PlaybackSource {
        case recorded
        case systemVoice
    }

    override init() {
        manifest = Self.loadManifest()
        super.init()
        synthesizer.delegate = self
    }

    func sourceDescription(lessonID: String, contentHash: String) -> String {
        recordedURL(lessonID: lessonID, contentHash: contentHash) == nil
            ? "System fallback"
            : "Studio narration"
    }

    func toggle(lessonID: String, contentHash: String, text: String) {
        switch state {
        case .idle:
            if let url = recordedURL(lessonID: lessonID, contentHash: contentHash),
               startRecordedAudio(at: url) {
                return
            }

            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: nil)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            synthesizer.speak(utterance)
            playbackSource = .systemVoice
            state = .speaking
        case .speaking:
            if playbackSource == .recorded {
                audioPlayer?.pause()
                state = .paused
            } else if synthesizer.pauseSpeaking(at: .word) {
                state = .paused
            }
        case .paused:
            if playbackSource == .recorded {
                audioPlayer?.play()
                state = .speaking
            } else if synthesizer.continueSpeaking() {
                state = .speaking
            }
        }
    }

    func stop() {
        guard state != .idle else { return }
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
        playbackSource = nil
        state = .idle
    }

    private func startRecordedAudio(at url: URL) -> Bool {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            guard player.play() else { return false }
            audioPlayer = player
            playbackSource = .recorded
            state = .speaking
            return true
        } catch {
            return false
        }
    }

    private func recordedURL(lessonID: String, contentHash: String) -> URL? {
        guard manifest.schemaVersion == NarrationManifest.currentSchemaVersion,
              let asset = manifest.lessons[lessonID],
              asset.contentHash == contentHash else {
            return nil
        }

        let filename = (asset.file as NSString).deletingPathExtension
        let fileExtension = (asset.file as NSString).pathExtension
        return Bundle.module.url(
            forResource: filename,
            withExtension: fileExtension,
            subdirectory: "Narration"
        )
    }

    private static func loadManifest() -> NarrationManifest {
        guard let url = Bundle.module.url(
            forResource: "manifest",
            withExtension: "json",
            subdirectory: "Narration"
        ), let data = try? Data(contentsOf: url),
           let manifest = try? JSONDecoder().decode(NarrationManifest.self, from: data) else {
            return NarrationManifest()
        }
        return manifest
    }

    private func playbackFinished() {
        audioPlayer = nil
        playbackSource = nil
        state = .idle
    }
}

extension LessonNarrationService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in self?.playbackFinished() }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in self?.playbackFinished() }
    }
}

extension LessonNarrationService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.playbackFinished() }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in self?.playbackFinished() }
    }
}
