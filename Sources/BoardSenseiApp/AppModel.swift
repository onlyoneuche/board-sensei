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
    @Published private(set) var isPracticeLoopActive = false
    @Published private(set) var previewPitches: [UInt8] = []
    @Published private(set) var previewPromptIndex: Int?
    @Published private(set) var previewTempoBPM = 90
    @Published private(set) var isMetronomeEnabled = false
    @Published private(set) var metronomeSignature = PracticeTimeSignature.fourFour
    @Published private(set) var metronomeBeatIndex: Int?
    @Published private(set) var metronomeVolume: Float = 0.62
    @Published private(set) var quickHelpContent: QuickHelpContent?
    @Published private(set) var hasCompletedOnboarding = false
    @Published private(set) var learningGoal = LearningGoal.jazzFluency
    @Published private(set) var learnerExperience = LearnerExperience.beginner
    @Published private(set) var lessonRecords: [String: LessonProgressRecord] = [:]
    @Published private(set) var unlockedAchievements: Set<LearningAchievement> = []
    @Published private(set) var lessonCompletionResult: LessonCompletionResult?
    @Published private(set) var practiceDayStreak = 0
    @Published private(set) var celebrationSoundsEnabled = true
    @Published private(set) var animatedCelebrationsEnabled = true
    @Published private(set) var practiceStreaksEnabled = true
    @Published private(set) var practiceHandMode = PracticeHandMode.both
    @Published private(set) var practiceStartMeasure = 1
    @Published private(set) var practiceEndMeasure = 1
    @Published private(set) var automaticTempoProgressionEnabled = false
    @Published private(set) var automaticTempoStep = 5

    let audio = AudioService()
    private let midi = CoreMIDIService()
    private var validator = RustPracticeValidator(expectedPitch: 60)
    private var eventTask: Task<Void, Never>?
    private var deviceTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var completionSoundTask: Task<Void, Never>?
    private var practiceLoopTask: Task<Void, Never>?
    private var practiceLoopRestartPending = false

    var isUsingRust: Bool { validator.isUsingRust }
    private let completedLessonsKey = "completedJazzLessonIDs"
    private let previewTempoKey = "exercisePreviewTempoBPM"
    private let metronomeEnabledKey = "practiceMetronomeEnabled"
    private let metronomeVolumeKey = "practiceMetronomeVolume"
    private let metronomeSignatureKey = "practiceMetronomeSignature"
    private let onboardingCompletedKey = "onboardingCompletedV1"
    private let learningGoalKey = "learningGoalV1"
    private let learnerExperienceKey = "learnerExperienceV1"
    private let practiceDayStreakKey = "practiceDayStreakV1"
    private let lastPracticeDayKey = "lastPracticeDayV1"
    private let celebrationSoundsKey = "celebrationSoundsEnabledV1"
    private let animatedCelebrationsKey = "animatedCelebrationsEnabledV1"
    private let practiceStreaksKey = "practiceStreaksEnabledV1"

    var expectedPitch: UInt8 { expectedPitches.first ?? 60 }
    var practicePromptIndices: [Int] {
        activeLesson.promptIndices(
            fromMeasure: practiceStartMeasure,
            throughMeasure: practiceEndMeasure
        )
    }
    var practicePromptCount: Int { practicePromptIndices.count }
    var completedSourcePromptIndices: Set<Int> {
        Set(practicePromptIndices.prefix(completedNotes))
    }
    var currentSourcePromptIndex: Int {
        guard !practicePromptIndices.isEmpty else { return 0 }
        return practicePromptIndices[min(completedNotes, practicePromptIndices.count - 1)]
    }
    var lessonProgress: Double {
        guard practicePromptCount > 0 else { return 0 }
        return Double(completedNotes) / Double(practicePromptCount)
    }
    var isActiveLessonComplete: Bool { completedNotes == practicePromptCount }
    var isChordPrompt: Bool { expectedPitches.count > 1 }
    var displayedPitches: [UInt8] { isPreviewPlaying ? previewPitches : expectedPitches }
    var displayedFeedback: PracticeFeedback { isPreviewPlaying ? .waiting : feedback }
    var displayedFingerings: [PracticeFingering] {
        if isPreviewPlaying {
            guard let previewPromptIndex, activeLesson.prompts.indices.contains(previewPromptIndex) else { return [] }
            return activeLesson.prompts[previewPromptIndex].filtered(for: practiceHandMode).fingerings
        }
        return activeLesson.prompts[currentSourcePromptIndex].filtered(for: practiceHandMode).fingerings
    }
    var activeLessonMeasureCount: Int { activeLesson.scoreMeasureCount }

    var isHanonLesson: Bool {
        HanonCourseCatalog.lesson(id: activeLesson.id) != nil
    }
    var isFocusedPracticeSelection: Bool {
        practiceHandMode != .both
            || practiceStartMeasure != 1
            || practiceEndMeasure != activeLesson.scoreMeasureCount
    }
    var isFullMeasureRange: Bool {
        practiceStartMeasure == 1 && practiceEndMeasure == activeLesson.scoreMeasureCount
    }
    var activeLessonNavigation: CourseLessonNavigation? {
        JazzCourseCatalog.navigation(forLessonID: activeLesson.id)
            ?? HanonCourseCatalog.navigation(forLessonID: activeLesson.id)
    }

    init() {
        let stored = UserDefaults.standard.stringArray(forKey: completedLessonsKey) ?? []
        completedLessonIDs = Set(stored)
        lessonRecords = LearningExperienceStore.loadRecords()
        for lessonID in completedLessonIDs where lessonRecords[lessonID] == nil {
            lessonRecords[lessonID] = LessonProgressRecord(
                practiceStarts: 1,
                completions: 1,
                bestAccuracy: 1,
                lastAccuracy: 1
            )
        }
        unlockedAchievements = LearningExperienceStore.loadAchievements()
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
        if let rawGoal = UserDefaults.standard.string(forKey: learningGoalKey),
           let goal = LearningGoal(rawValue: rawGoal) {
            learningGoal = goal
        }
        if let rawExperience = UserDefaults.standard.string(forKey: learnerExperienceKey),
           let experience = LearnerExperience(rawValue: rawExperience) {
            learnerExperience = experience
        }
        practiceDayStreak = max(0, UserDefaults.standard.integer(forKey: practiceDayStreakKey))
        if let lastPracticeDate = UserDefaults.standard.object(forKey: lastPracticeDayKey) as? Date {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let lastDay = calendar.startOfDay(for: lastPracticeDate)
            let elapsedDays = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if elapsedDays > 1 {
                practiceDayStreak = 0
                UserDefaults.standard.set(0, forKey: practiceDayStreakKey)
            }
        }
        celebrationSoundsEnabled = UserDefaults.standard.object(forKey: celebrationSoundsKey) as? Bool ?? true
        animatedCelebrationsEnabled = UserDefaults.standard.object(forKey: animatedCelebrationsKey) as? Bool ?? true
        practiceStreaksEnabled = UserDefaults.standard.object(forKey: practiceStreaksKey) as? Bool ?? true
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
        practiceEndMeasure = activeLesson.scoreMeasureCount
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
        stopPracticeLoop()
        resetCurrentPass(clearResult: true)
    }

    func practiseAgain() {
        stopPracticeLoop()
        resetCurrentPass(clearResult: true)
    }

    func startPracticeLoop() {
        stopPracticeLoop()
        stopExercisePreview()
        isPracticeLoopActive = true
        setMetronomeEnabled(true)
        resetCurrentPass(clearResult: false)
        startPracticeLoopClock()
    }

    func stopPracticeLoop() {
        practiceLoopTask?.cancel()
        practiceLoopTask = nil
        practiceLoopRestartPending = false
        isPracticeLoopActive = false
        if !isPreviewPlaying { metronomeBeatIndex = nil }
    }

    private func resetCurrentPass(clearResult: Bool) {
        stopCompletionSound()
        stopExercisePreview()
        if clearResult { lessonCompletionResult = nil }
        completedNotes = 0
        mistakes = 0
        streak = 0
        expectedPitches = activeLesson.prompts[currentSourcePromptIndex]
            .filtered(for: practiceHandMode)
            .pitches
        feedback = .waiting
        validator.setExpectedPitch(expectedPitch)
    }

    func startLesson(_ lesson: PracticeLesson) {
        clearQuickHelp()
        stopPracticeLoop()
        stopExercisePreview()
        audio.panic()
        activeLesson = lesson
        practiceHandMode = .both
        practiceStartMeasure = 1
        practiceEndMeasure = lesson.scoreMeasureCount
        var record = lessonRecords[lesson.id] ?? LessonProgressRecord()
        record.registerStart()
        lessonRecords[lesson.id] = record
        LearningExperienceStore.saveRecords(lessonRecords)
        resetLesson()
        isPracticeMode = true
    }

    func leavePractice(for destination: Destination = .courses) {
        clearQuickHelp()
        isPracticeMode = false
        stopPracticeLoop()
        stopExercisePreview()
        audio.panic()
        self.destination = destination
    }

    func isCompleted(_ lesson: PracticeLesson) -> Bool {
        completedLessonIDs.contains(lesson.id)
    }

    func mastery(for lesson: PracticeLesson) -> LessonMastery? {
        lessonRecords[lesson.id]?.mastery
    }

    func progressRecord(for lesson: PracticeLesson) -> LessonProgressRecord? {
        lessonRecords[lesson.id]
    }

    func chooseLearningGoal(_ goal: LearningGoal) {
        learningGoal = goal
        UserDefaults.standard.set(goal.rawValue, forKey: learningGoalKey)
    }

    func chooseLearnerExperience(_ experience: LearnerExperience) {
        learnerExperience = experience
        UserDefaults.standard.set(experience.rawValue, forKey: learnerExperienceKey)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        destination = .courses
        UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
    }

    func restartOnboarding() {
        leavePractice(for: .courses)
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: onboardingCompletedKey)
    }

    func setCelebrationSoundsEnabled(_ enabled: Bool) {
        celebrationSoundsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: celebrationSoundsKey)
    }

    func setAnimatedCelebrationsEnabled(_ enabled: Bool) {
        animatedCelebrationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: animatedCelebrationsKey)
    }

    func setPracticeStreaksEnabled(_ enabled: Bool) {
        practiceStreaksEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: practiceStreaksKey)
    }

    func dismissLessonResult() {
        lessonCompletionResult = nil
    }

    func resetCourseProgress() {
        completedLessonIDs.removeAll()
        lessonRecords.removeAll()
        unlockedAchievements.removeAll()
        persistCourseProgress()
        LearningExperienceStore.saveRecords(lessonRecords)
        LearningExperienceStore.saveAchievements(unlockedAchievements)
    }

    func setPreviewTempo(_ beatsPerMinute: Int) {
        previewTempoBPM = min(max(beatsPerMinute, 50), 180)
        UserDefaults.standard.set(previewTempoBPM, forKey: previewTempoKey)
    }

    func setPracticeHandMode(_ mode: PracticeHandMode) {
        guard practiceHandMode != mode else { return }
        stopPracticeLoop()
        stopExercisePreview()
        practiceHandMode = mode
        resetCurrentPass(clearResult: true)
    }

    func setPracticeMeasureRange(start: Int, end: Int) {
        let maximum = activeLesson.scoreMeasureCount
        let safeStart = min(max(start, 1), maximum)
        let safeEnd = min(max(end, safeStart), maximum)
        guard practiceStartMeasure != safeStart || practiceEndMeasure != safeEnd else { return }
        stopPracticeLoop()
        stopExercisePreview()
        practiceStartMeasure = safeStart
        practiceEndMeasure = safeEnd
        resetCurrentPass(clearResult: true)
    }

    func setAutomaticTempoProgressionEnabled(_ enabled: Bool) {
        automaticTempoProgressionEnabled = enabled
    }

    func setAutomaticTempoStep(_ step: Int) {
        automaticTempoStep = min(max(step, 1), 10)
    }

    func setMetronomeEnabled(_ enabled: Bool) {
        isMetronomeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: metronomeEnabledKey)
        if !enabled, !isPracticeLoopActive { metronomeBeatIndex = nil }
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
        if isPracticeLoopActive { startPracticeLoopClock() }
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
        stopCompletionSound()
        stopPracticeLoop()
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
        if !isPracticeLoopActive { metronomeBeatIndex = nil }
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

        guard isPracticeMode, !isPreviewPlaying else { return }
        guard completedNotes < practicePromptCount else { return }
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
        let prompt = activeLesson.prompts[currentSourcePromptIndex].filtered(for: practiceHandMode)
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
        if completedNotes < practicePromptCount {
            expectedPitches = activeLesson.prompts[currentSourcePromptIndex]
                .filtered(for: practiceHandMode)
                .pitches
            if expectedPitches.count == 1 {
                validator.setExpectedPitch(expectedPitch)
            }
        } else {
            if isFocusedPracticeSelection {
                recordFocusedPracticeCompletion()
            } else {
                completedLessonIDs.insert(activeLesson.id)
                persistCourseProgress()
                recordLessonCompletion()
            }
        }
    }

    private func persistCourseProgress() {
        UserDefaults.standard.set(completedLessonIDs.sorted(), forKey: completedLessonsKey)
    }

    private func recordLessonCompletion() {
        var record = lessonRecords[activeLesson.id] ?? LessonProgressRecord()
        let priorMastery = record.mastery
        let priorBest = record.bestAccuracy
        let accuracy = record.registerCompletion(
            promptCount: activeLesson.promptCount,
            mistakes: mistakes
        )
        lessonRecords[activeLesson.id] = record
        LearningExperienceStore.saveRecords(lessonRecords)
        updatePracticeDayStreak()

        let achievements = newlyEarnedAchievements(after: record)
        lessonCompletionResult = LessonCompletionResult(
            lessonID: activeLesson.id,
            lessonTitle: activeLesson.title,
            accuracy: accuracy,
            mistakes: mistakes,
            mastery: record.mastery,
            masteryAdvanced: priorMastery != record.mastery,
            personalBest: accuracy > priorBest,
            newAchievements: achievements
        )

        applyAutomaticTempoProgression(afterAccuracy: accuracy)

        if celebrationSoundsEnabled {
            playCompletionChime()
        }
        if isPracticeLoopActive {
            practiceLoopRestartPending = true
        }
    }

    private func recordFocusedPracticeCompletion() {
        let accuracy = max(
            0,
            1 - Double(mistakes) / Double(max(practicePromptCount, 1))
        )
        let record = lessonRecords[activeLesson.id] ?? LessonProgressRecord()
        lessonCompletionResult = LessonCompletionResult(
            lessonID: activeLesson.id,
            lessonTitle: activeLesson.title,
            accuracy: accuracy,
            mistakes: mistakes,
            mastery: record.mastery,
            masteryAdvanced: false,
            personalBest: false,
            newAchievements: []
        )
        applyAutomaticTempoProgression(afterAccuracy: accuracy)
        if isPracticeLoopActive { practiceLoopRestartPending = true }
    }

    private func applyAutomaticTempoProgression(afterAccuracy accuracy: Double) {
        guard automaticTempoProgressionEnabled, accuracy >= 0.9 else { return }
        setPreviewTempo(previewTempoBPM + automaticTempoStep)
    }

    private func newlyEarnedAchievements(after record: LessonProgressRecord) -> [LearningAchievement] {
        var candidates: [LearningAchievement] = []
        if completedLessonIDs.count >= 1 { candidates.append(.firstLesson) }
        if completedLessonIDs.count >= 5 { candidates.append(.fiveLessons) }
        if record.mastery == .mastered { candidates.append(.firstMastery) }
        let earned = candidates.filter { !unlockedAchievements.contains($0) }
        unlockedAchievements.formUnion(earned)
        LearningExperienceStore.saveAchievements(unlockedAchievements)
        return earned
    }

    private func updatePracticeDayStreak() {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDate = defaults.object(forKey: lastPracticeDayKey) as? Date

        if let lastDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            if lastDay == today { return }
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
            practiceDayStreak = lastDay == yesterday ? practiceDayStreak + 1 : 1
        } else {
            practiceDayStreak = 1
        }

        defaults.set(today, forKey: lastPracticeDayKey)
        defaults.set(practiceDayStreak, forKey: practiceDayStreakKey)
    }

    private func playCompletionChime() {
        completionSoundTask?.cancel()
        completionSoundTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            guard !self.isPreviewPlaying else { return }
            self.audio.playCompletionChime()
            self.completionSoundTask = nil
        }
    }

    private func stopCompletionSound() {
        completionSoundTask?.cancel()
        completionSoundTask = nil
        audio.stopCompletionChime()
    }

    private func startPracticeLoopClock() {
        practiceLoopTask?.cancel()
        practiceLoopTask = Task { [weak self] in
            guard let self else { return }
            let signature = self.activeLesson.scoreMetadata?.timeSignature ?? self.metronomeSignature
            var beat = 0
            while !Task.isCancelled, self.isPracticeLoopActive {
                if beat == 0, self.practiceLoopRestartPending {
                    self.resetCurrentPass(clearResult: false)
                    self.practiceLoopRestartPending = false
                }
                self.metronomeBeatIndex = beat
                if self.isMetronomeEnabled {
                    self.audio.playMetronomeClick(accented: beat == 0)
                }

                do {
                    try await Task.sleep(
                        for: .milliseconds(signature.beatDurationMilliseconds(at: self.previewTempoBPM))
                    )
                } catch {
                    return
                }
                beat = (beat + 1) % signature.numerator
            }
        }
    }

    private func runExercisePreview() async {
        repeat {
            let prompts = activeLesson.prompts
            let signature = activeLesson.scoreMetadata?.timeSignature ?? metronomeSignature
            let beatUnitInQuarterNotes = 4.0 / Double(signature.denominator)
            let quarterNoteMilliseconds = 60_000.0 / Double(previewTempoBPM)
            var elapsedQuarterNotes = 0.0

            for promptIndex in previewPromptIndices {
                guard !Task.isCancelled else { return }
                let prompt = prompts[promptIndex].filtered(for: practiceHandMode)
                let writtenBeat = elapsedQuarterNotes / beatUnitInQuarterNotes
                let roundedBeat = writtenBeat.rounded()
                if abs(writtenBeat - roundedBeat) < 0.000_1 {
                    metronomeBeatIndex = Int(roundedBeat) % signature.numerator
                    if isMetronomeEnabled {
                        audio.playMetronomeClick(accented: metronomeBeatIndex == 0)
                    }
                }

                previewPromptIndex = promptIndex
                previewPitches = prompt.pitches
                audio.beginPreview(prompt.pitches)
                let durationMilliseconds = max(
                    20,
                    Int((quarterNoteMilliseconds * prompt.noteValue.quarterNoteBeats).rounded())
                )
                guard await sleepForPreviewNote(beatMilliseconds: durationMilliseconds) else {
                    audio.endPreview(prompt.pitches)
                    return
                }
                audio.endPreview(prompt.pitches)
                guard await sleepForPreviewGap(beatMilliseconds: durationMilliseconds) else { return }
                elapsedQuarterNotes += prompt.noteValue.quarterNoteBeats
            }

            if isExerciseLoopEnabled {
                let barQuarterNotes = Double(signature.numerator) * beatUnitInQuarterNotes
                let alignedQuarterNotes = ceil(elapsedQuarterNotes / barQuarterNotes) * barQuarterNotes
                while elapsedQuarterNotes + 0.000_1 < alignedQuarterNotes {
                    guard !Task.isCancelled else { return }
                    let writtenBeat = Int((elapsedQuarterNotes / beatUnitInQuarterNotes).rounded())
                    metronomeBeatIndex = writtenBeat % signature.numerator
                    if isMetronomeEnabled {
                        audio.playMetronomeClick(accented: metronomeBeatIndex == 0)
                    }
                    previewPromptIndex = nil
                    previewPitches = []
                    let padding = min(beatUnitInQuarterNotes, alignedQuarterNotes - elapsedQuarterNotes)
                    guard await sleepForBeat(
                        beatMilliseconds: Int((quarterNoteMilliseconds * padding).rounded())
                    ) else { return }
                    elapsedQuarterNotes += padding
                }
            }
        } while isExerciseLoopEnabled && !Task.isCancelled

        previewTask = nil
        previewPitches = []
        previewPromptIndex = nil
        isPreviewPlaying = false
        metronomeBeatIndex = nil
    }

    private var previewPromptIndices: [Int] {
        isFullMeasureRange ? activeLesson.playbackPromptIndices : practicePromptIndices
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
