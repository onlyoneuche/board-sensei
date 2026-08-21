import Combine
import Foundation
import MusicCore

enum PracticeFeedback: Equatable {
    case waiting
    case correct(notes: [UInt8])
    case incorrect(expected: [UInt8], received: UInt8)

    var title: String {
        switch self {
        case .waiting: "Play the highlighted prompt"
        case .correct: "Correct"
        case .incorrect: "Try again"
        }
    }

    var symbol: String {
        switch self {
        case .waiting: "music.note"
        case .correct: "checkmark.circle.fill"
        case .incorrect: "arrow.counterclockwise.circle.fill"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    enum Destination: String, CaseIterable, Identifiable {
        case courses = "Courses"
        case midiLab = "MIDI Lab"
        case architecture = "Foundation"
        case settings = "Settings"

        var id: Self { self }
        var symbol: String {
            switch self {
            case .courses: "graduationcap.fill"
            case .midiLab: "pianokeys"
            case .architecture: "square.3.layers.3d"
            case .settings: "gearshape.fill"
            }
        }
    }

    @Published var destination: Destination? = .courses
    @Published private(set) var devices: [MIDIDeviceDescriptor] = []
    @Published var selectedDeviceID: Int32?
    @Published private(set) var recentEvents: [NormalizedMIDIEvent] = []
    @Published private(set) var connectionMessage = "Looking for a MIDI keyboard…"
    @Published private(set) var expectedPitches: [UInt8] = [60]
    @Published private(set) var activeNotes: Set<UInt8> = []
    @Published private(set) var feedback: PracticeFeedback = .waiting
    @Published private(set) var completedNotes = 0
    @Published private(set) var mistakes = 0
    @Published private(set) var streak = 0
    @Published private(set) var hasStarted = false
    @Published private(set) var activeLesson = JazzCourseCatalog.firstLesson
    @Published private(set) var completedLessonIDs: Set<String> = []
    @Published private(set) var isPracticeMode = false
    @Published private(set) var isPreviewPlaying = false
    @Published private(set) var isExerciseLoopEnabled = false
    @Published private(set) var previewPitches: [UInt8] = []
    @Published private(set) var previewPromptIndex: Int?
    @Published private(set) var previewTempoBPM = 90
    @Published private(set) var isMetronomeEnabled = false
    @Published private(set) var metronomeSignature = PracticeTimeSignature.fourFour
    @Published private(set) var metronomeBeatIndex: Int?
    @Published private(set) var metronomeVolume: Float = 0.62
    @Published private(set) var quickHelpContent: QuickHelpContent?

    let audio = AudioService()
    private let midi = CoreMIDIService()
    private var validator = RustPracticeValidator(expectedPitch: 60)
    private var eventTask: Task<Void, Never>?
    private var deviceTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?

    var isUsingRust: Bool { validator.isUsingRust }
    private let completedLessonsKey = "completedJazzLessonIDs"
    private let previewTempoKey = "exercisePreviewTempoBPM"
    private let metronomeEnabledKey = "practiceMetronomeEnabled"
    private let metronomeVolumeKey = "practiceMetronomeVolume"
    private let metronomeSignatureKey = "practiceMetronomeSignature"

    var expectedPitch: UInt8 { expectedPitches.first ?? 60 }
    var lessonProgress: Double { Double(completedNotes) / Double(activeLesson.promptCount) }
    var isActiveLessonComplete: Bool { completedNotes == activeLesson.promptCount }
    var isChordPrompt: Bool { expectedPitches.count > 1 }
    var displayedPitches: [UInt8] { isPreviewPlaying ? previewPitches : expectedPitches }
    var displayedFeedback: PracticeFeedback { isPreviewPlaying ? .waiting : feedback }
    var activeLessonNavigation: CourseLessonNavigation? {
        JazzCourseCatalog.navigation(forLessonID: activeLesson.id)
    }

    init() {
        let stored = UserDefaults.standard.stringArray(forKey: completedLessonsKey) ?? []
        completedLessonIDs = Set(stored)
        let storedTempo = UserDefaults.standard.integer(forKey: previewTempoKey)
        previewTempoBPM = storedTempo == 0 ? 90 : min(max(storedTempo, 50), 180)
        isMetronomeEnabled = UserDefaults.standard.bool(forKey: metronomeEnabledKey)
        let storedVolume = UserDefaults.standard.object(forKey: metronomeVolumeKey) as? Double
        metronomeVolume = min(max(Float(storedVolume ?? 0.62), 0), 1)
        audio.metronomeVolume = metronomeVolume
        if let signatureID = UserDefaults.standard.string(forKey: metronomeSignatureKey),
           let signature = PracticeTimeSignature.common.first(where: { $0.id == signatureID }) {
            metronomeSignature = signature
        }
        expectedPitches = activeLesson.prompts[0].pitches
        validator.setExpectedPitch(expectedPitch)
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        audio.start()

        deviceTask = Task { [weak self] in
            guard let self else { return }
            for await devices in midi.devices {
                self.devices = devices
                self.connectionMessage = devices.isEmpty ? "No MIDI keyboard detected" : "\(devices.count) MIDI source\(devices.count == 1 ? "" : "s") available"
                if selectedDeviceID == nil, let first = devices.first {
                    connect(to: first.id)
                }
            }
        }

        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in midi.events {
                handle(event)
            }
        }

        do {
            try midi.start()
        } catch {
            connectionMessage = error.localizedDescription
        }
    }

    func connect(to id: Int32) {
        do {
            try midi.connect(to: id)
            selectedDeviceID = id
            let name = devices.first(where: { $0.id == id })?.name ?? "MIDI keyboard"
            connectionMessage = "Connected to \(name)"
        } catch {
            connectionMessage = error.localizedDescription
        }
    }

    func disconnectMIDI() {
        midi.disconnect()
        selectedDeviceID = nil
        connectionMessage = "MIDI disconnected"
        audio.panic()
    }

    func simulate(note: UInt8, velocity: UInt8 = 96) {
        beginSimulatedNote(note: note, velocity: velocity)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            self?.endSimulatedNote(note: note)
        }
    }

    func simulateChord(_ notes: [UInt8], velocity: UInt8 = 96) {
        notes.forEach { beginSimulatedNote(note: $0, velocity: velocity) }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            notes.forEach { self?.endSimulatedNote(note: $0) }
        }
    }

    func beginSimulatedNote(note: UInt8, velocity: UInt8 = 96) {
        guard !activeNotes.contains(note) else { return }
        handle(.noteOn(
            note: note,
            velocity: velocity,
            channel: 0,
            timestamp: DispatchTime.now().uptimeNanoseconds
        ))
    }

    func endSimulatedNote(note: UInt8) {
        guard activeNotes.contains(note) else { return }
        handle(.noteOff(
            note: note,
            velocity: 0,
            channel: 0,
            timestamp: DispatchTime.now().uptimeNanoseconds
        ))
    }

    func resetLesson() {
        stopExercisePreview()
        completedNotes = 0
        mistakes = 0
        streak = 0
        expectedPitches = activeLesson.prompts[0].pitches
        feedback = .waiting
        validator.setExpectedPitch(expectedPitch)
    }

    func startLesson(_ lesson: PracticeLesson) {
        clearQuickHelp()
        stopExercisePreview()
        audio.panic()
        activeLesson = lesson
        resetLesson()
        isPracticeMode = true
    }

    func leavePractice(for destination: Destination = .courses) {
        clearQuickHelp()
        isPracticeMode = false
        stopExercisePreview()
        audio.panic()
        self.destination = destination
    }

    func isCompleted(_ lesson: PracticeLesson) -> Bool {
        completedLessonIDs.contains(lesson.id)
    }

    func resetCourseProgress() {
        completedLessonIDs.removeAll()
        persistCourseProgress()
    }

    func setPreviewTempo(_ beatsPerMinute: Int) {
        previewTempoBPM = min(max(beatsPerMinute, 50), 180)
        UserDefaults.standard.set(previewTempoBPM, forKey: previewTempoKey)
    }

    func setMetronomeEnabled(_ enabled: Bool) {
        isMetronomeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: metronomeEnabledKey)
        if !enabled { metronomeBeatIndex = nil }
    }

    func setMetronomeVolume(_ volume: Float) {
        let clamped = min(max(volume, 0), 1)
        metronomeVolume = clamped
        audio.metronomeVolume = clamped
        UserDefaults.standard.set(Double(clamped), forKey: metronomeVolumeKey)
    }

    func setMetronomeSignature(_ signature: PracticeTimeSignature) {
        metronomeSignature = signature
        UserDefaults.standard.set(signature.id, forKey: metronomeSignatureKey)
    }

    func showQuickHelp(title: String, detail: String) {
        quickHelpContent = QuickHelpContent(title: title, detail: detail)
    }

    func clearQuickHelp() {
        quickHelpContent = nil
    }

    func toggleExercisePreview() {
        if isPreviewPlaying { stopExercisePreview() }
        else { startExercisePreview() }
    }

    func toggleExerciseLoopEnabled() {
        isExerciseLoopEnabled.toggle()
    }

    func startExercisePreview() {
        stopExercisePreview()
        isPreviewPlaying = true
        previewTask = Task { [weak self] in
            await self?.runExercisePreview()
        }
    }

    func stopExercisePreview() {
        previewTask?.cancel()
        previewTask = nil
        audio.stopPreview()
        previewPitches = []
        previewPromptIndex = nil
        isPreviewPlaying = false
    }

    private func handle(_ event: NormalizedMIDIEvent) {
        recentEvents.insert(event, at: 0)
        if recentEvents.count > 100 { recentEvents.removeLast(recentEvents.count - 100) }
        audio.handle(event)

        switch event {
        case let .noteOn(note, velocity, _, _) where velocity > 0:
            activeNotes.insert(note)
        case let .noteOff(note, _, _, _):
            activeNotes.remove(note)
        default:
            break
        }

        guard !isPreviewPlaying else { return }
        guard completedNotes < activeLesson.promptCount else { return }
        guard case let .noteOn(note, velocity, channel, timestamp) = event, velocity > 0 else { return }

        if isChordPrompt {
            validateChordPrompt(receivedNote: note)
            return
        }

        let result = validator.validate(note: note, velocity: velocity, channel: channel, timestamp: timestamp)
        switch result.status {
        case .correct:
            completePrompt(notes: [note])
        case .incorrect:
            feedback = .incorrect(expected: [result.expectedPitch], received: result.receivedPitch)
            mistakes += 1
            streak = 0
        case .ignored, .unavailable:
            break
        }
    }

    private func validateChordPrompt(receivedNote: UInt8) {
        let prompt = activeLesson.prompts[completedNotes]
        guard prompt.accepts(receivedNote) else {
            feedback = .incorrect(expected: expectedPitches, received: receivedNote)
            mistakes += 1
            streak = 0
            return
        }

        if prompt.isSatisfied(by: activeNotes) {
            completePrompt(notes: expectedPitches)
        } else {
            feedback = .waiting
        }
    }

    private func completePrompt(notes: [UInt8]) {
        feedback = .correct(notes: notes)
        completedNotes += 1
        streak += 1
        if completedNotes < activeLesson.promptCount {
            expectedPitches = activeLesson.prompts[completedNotes].pitches
            if expectedPitches.count == 1 {
                validator.setExpectedPitch(expectedPitch)
            }
        } else {
            completedLessonIDs.insert(activeLesson.id)
            persistCourseProgress()
        }
    }

    private func persistCourseProgress() {
        UserDefaults.standard.set(completedLessonIDs.sorted(), forKey: completedLessonsKey)
    }

    private func runExercisePreview() async {
        repeat {
            let prompts = activeLesson.prompts
            for (beat, prompt) in prompts.enumerated() {
                guard !Task.isCancelled else { return }
                let beatMilliseconds = currentBeatMilliseconds
                metronomeBeatIndex = beat % metronomeSignature.numerator
                if isMetronomeEnabled {
                    audio.playMetronomeClick(accented: metronomeBeatIndex == 0)
                }

                previewPromptIndex = beat
                previewPitches = prompt.pitches
                audio.beginPreview(prompt.pitches)
                guard await sleepForPreviewNote(beatMilliseconds: beatMilliseconds) else {
                    audio.endPreview(prompt.pitches)
                    return
                }
                audio.endPreview(prompt.pitches)
                guard await sleepForPreviewGap(beatMilliseconds: beatMilliseconds) else { return }
            }

            if isExerciseLoopEnabled {
                let alignedBeatCount = metronomeSignature.barAlignedBeatCount(
                    forPromptCount: prompts.count
                )
                for beat in prompts.count..<alignedBeatCount {
                    guard !Task.isCancelled else { return }
                    let beatMilliseconds = currentBeatMilliseconds
                    metronomeBeatIndex = beat % metronomeSignature.numerator
                    if isMetronomeEnabled {
                        audio.playMetronomeClick(accented: metronomeBeatIndex == 0)
                    }
                    previewPromptIndex = nil
                    previewPitches = []
                    guard await sleepForBeat(beatMilliseconds: beatMilliseconds) else { return }
                }
            }
        } while isExerciseLoopEnabled && !Task.isCancelled

        previewTask = nil
        previewPitches = []
        previewPromptIndex = nil
        isPreviewPlaying = false
        metronomeBeatIndex = nil
    }

    private var currentBeatMilliseconds: Int {
        metronomeSignature.beatDurationMilliseconds(at: previewTempoBPM)
    }

    private func sleepForPreviewNote(beatMilliseconds: Int) async -> Bool {
        do {
            try await Task.sleep(for: .milliseconds(Int(Double(beatMilliseconds) * 0.76)))
            return true
        } catch {
            return false
        }
    }

    private func sleepForPreviewGap(beatMilliseconds: Int) async -> Bool {
        do {
            try await Task.sleep(for: .milliseconds(Int(Double(beatMilliseconds) * 0.24)))
            return true
        } catch {
            return false
        }
    }

    private func sleepForBeat(beatMilliseconds: Int) async -> Bool {
        do {
            try await Task.sleep(for: .milliseconds(beatMilliseconds))
            return true
        } catch {
            return false
        }
    }

}
