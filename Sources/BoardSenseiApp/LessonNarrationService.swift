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
        BoardSenseiDiagnostics.trace("narration", "service init")
        manifest = Self.loadManifest()
        super.init()
        synthesizer.delegate = self
        BoardSenseiDiagnostics.trace("narration", "service ready; manifestLessons=\(manifest.lessons.count)")
    }

    func sourceDescription(lessonID: String, contentHash: String) -> String {
        recordedURL(lessonID: lessonID, contentHash: contentHash) == nil
            ? "System fallback"
            : "Studio narration"
    }

    func toggle(lessonID: String, contentHash: String, text: String) {
        BoardSenseiDiagnostics.trace(
            "narration",
            "toggle entered; lesson=\(lessonID) state=\(String(describing: state))"
        )
        switch state {
        case .idle:
            if let url = recordedURL(lessonID: lessonID, contentHash: contentHash),
               startRecordedAudio(at: url) {
                BoardSenseiDiagnostics.trace("narration", "recorded playback started; file=\(url.lastPathComponent)")
                return
            }

            BoardSenseiDiagnostics.trace("narration", "starting system voice fallback")
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: nil)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            synthesizer.speak(utterance)
            playbackSource = .systemVoice
            state = .speaking
            BoardSenseiDiagnostics.trace("narration", "system voice speak returned")
        case .speaking:
            BoardSenseiDiagnostics.trace("narration", "pause requested; source=\(String(describing: playbackSource))")
            if playbackSource == .recorded {
                audioPlayer?.pause()
                state = .paused
            } else if synthesizer.pauseSpeaking(at: .word) {
                state = .paused
            }
        case .paused:
            BoardSenseiDiagnostics.trace("narration", "resume requested; source=\(String(describing: playbackSource))")
            if playbackSource == .recorded {
                audioPlayer?.play()
                state = .speaking
            } else if synthesizer.continueSpeaking() {
                state = .speaking
            }
        }
    }

    func stop() {
        BoardSenseiDiagnostics.trace("narration", "stop requested; state=\(String(describing: state))")
        guard state != .idle else { return }
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
        playbackSource = nil
        state = .idle
        BoardSenseiDiagnostics.trace("narration", "stopped")
    }

    private func startRecordedAudio(at url: URL) -> Bool {
        BoardSenseiDiagnostics.trace("narration", "constructing AVAudioPlayer; file=\(url.lastPathComponent)")
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
            BoardSenseiDiagnostics.trace("narration", "recorded playback failed; error=\(error.localizedDescription)")
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
        BoardSenseiDiagnostics.trace("narration", "playback finished callback")
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
