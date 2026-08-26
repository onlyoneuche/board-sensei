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
    @Published private(set) var practiceSession = PracticeSession(
        context: CourseLibrary.context(
            courseID: JazzCourseCatalog.course.id,
            lessonID: JazzCourseCatalog.firstLesson.id
        )!
    )
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

    let audio = AudioService()
    private let midi = CoreMIDIService()
    private var validator = RustPracticeValidator(expectedPitch: 60)
    private var eventTask: Task<Void, Never>?
    private var deviceTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var completionSoundTask: Task<Void, Never>?
    private var practiceLoopTask: Task<Void, Never>?
    private var practiceLoopRestartPending = false
    private var preferredJazzPracticeKey = JazzPracticeKey.c

    var isUsingRust: Bool { validator.isUsingRust }
    private let legacyCompletedLessonsKey = "completedJazzLessonIDs"
    private let completedLessonsKey = "completedCourseLessonIDsV2"
    private let previewTempoKey = "exercisePreviewTempoBPM"
    private let jazzPracticeKeyKey = "jazzPracticeKeyV1"
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

    var activeLesson: PracticeLesson { practiceSession.context.lesson }
    var activeCourseID: String { practiceSession.context.courseID }
    var activeExperience: PracticeExperience { practiceSession.context.experience }
    var practicePresentation: PracticePresentation { practiceSession.presentation }
    var jazzPracticeKey: JazzPracticeKey { practiceSession.jazzPracticeKey }
    var supportsPracticeKeySelection: Bool { practiceSession.supportsKeySelection }
    var practiceStaffLayout: NotationStaffLayout { practiceSession.staffLayout }
    var practiceHandMode: PracticeHandMode { practiceSession.handMode }
    var practiceStartMeasure: Int { practiceSession.startMeasure }
    var practiceEndMeasure: Int { practiceSession.endMeasure }
    var automaticTempoProgressionEnabled: Bool { practiceSession.automaticTempoProgressionEnabled }
    var automaticTempoStep: Int { practiceSession.automaticTempoStep }
    var expectedPitch: UInt8 { expectedPitches.first ?? 60 }
    var practicePromptIndices: [Int] {
        practiceSession.promptIndices
    }
    var practicePromptCount: Int { practicePromptIndices.count }
    var completedSourcePromptIndices: Set<Int> {
        Set(practicePromptIndices.prefix(completedNotes))
    }
    var currentSourcePromptIndex: Int {
        practiceSession.currentSourcePromptIndex(completedPromptCount: completedNotes)
    }
    var lessonProgress: Double {
        guard practicePromptCount > 0 else { return 0 }
        return Double(completedNotes) / Double(practicePromptCount)
    }
    var isActiveLessonComplete: Bool { completedNotes == practicePromptCount }
    var isChordPrompt: Bool {
        practiceSession.validationMode(for: practiceSession.prompt(at: currentSourcePromptIndex)) == .exactHeldSet
    }
    var isPairedHandPrompt: Bool {
        practiceSession.validationMode(for: practiceSession.prompt(at: currentSourcePromptIndex)) == .freshAttackSet
    }
    var displayedPitches: [UInt8] { isPreviewPlaying ? previewPitches : expectedPitches }
    var displayedFeedback: PracticeFeedback { isPreviewPlaying ? .waiting : feedback }
    var displayedFingerings: [PracticeFingering] {
        if isPreviewPlaying {
            guard let previewPromptIndex, activeLesson.prompts.indices.contains(previewPromptIndex) else { return [] }
            return practiceSession.prompt(at: previewPromptIndex).fingerings
        }
        return practiceSession.prompt(at: currentSourcePromptIndex).fingerings
    }
    var activeLessonMeasureCount: Int { practiceSession.measureCount }
    var isFocusedPracticeSelection: Bool { practiceSession.isFocusedSelection }
    var isFullMeasureRange: Bool { practiceSession.isFullMeasureRange }
    var activeLessonNavigation: CourseLessonNavigation? { practiceSession.context.navigation }
    var practiceRoutePrompts: [PracticePrompt] {
        activeLesson.prompts.indices.map { practiceSession.prompt(at: $0) }
    }
    var activeHanonPracticeExercise: HanonExercise? { practiceSession.hanonPracticeExercise }

    init() {
        var migratedCompleted = CourseProgressKey.migrate(
            UserDefaults.standard.stringArray(forKey: completedLessonsKey) ?? [],
            courses: CourseLibrary.courses
        )
        let legacyCompleted = UserDefaults.standard.stringArray(forKey: legacyCompletedLessonsKey) ?? []
        for lessonID in legacyCompleted {
            if let key = CourseProgressKey.resolveLegacyLessonID(lessonID, courses: CourseLibrary.courses) {
                migratedCompleted.insert(key)
            }
        }
        completedLessonIDs = migratedCompleted
        UserDefaults.standard.set(completedLessonIDs.sorted(), forKey: completedLessonsKey)
        if !legacyCompleted.isEmpty {
            UserDefaults.standard.removeObject(forKey: legacyCompletedLessonsKey)
        }

        lessonRecords = LearningExperienceStore.loadRecords()
        let legacyRecords = LearningExperienceStore.loadLegacyRecords()
        for (lessonID, record) in legacyRecords {
            if let key = CourseProgressKey.resolveLegacyLessonID(lessonID, courses: CourseLibrary.courses),
               lessonRecords[key] == nil {
                lessonRecords[key] = record
            }
        }
        for progressKey in completedLessonIDs where lessonRecords[progressKey] == nil {
            lessonRecords[progressKey] = LessonProgressRecord(
                practiceStarts: 1,
                completions: 1,
                bestAccuracy: 1,
                lastAccuracy: 1
            )
        }
        LearningExperienceStore.saveRecords(lessonRecords)
        if !legacyRecords.isEmpty { LearningExperienceStore.clearLegacyRecords() }
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
        if let rawKey = UserDefaults.standard.object(forKey: jazzPracticeKeyKey) as? Int,
           let key = JazzPracticeKey(rawValue: rawKey) {
            preferredJazzPracticeKey = key
            practiceSession.selectJazzPracticeKey(key)
        }
        expectedPitches = practiceSession.prompt(at: 0).pitches
        configureValidatorForCurrentPrompt(resetHeldNotes: true)
    }

    func start() {
        BoardSenseiDiagnostics.trace("model", "start requested; hasStarted=\(hasStarted)")
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
        BoardSenseiDiagnostics.trace(
            "piano-input",
            "mouse press note=\(note) velocity=\(velocity) alreadyActive=\(activeNotes.contains(note))"
        )
        guard !activeNotes.contains(note) else { return }
        handle(.noteOn(
            note: note,
            velocity: velocity,
            channel: 0,
            timestamp: DispatchTime.now().uptimeNanoseconds
        ))
    }

    func endSimulatedNote(note: UInt8) {
        BoardSenseiDiagnostics.trace(
            "piano-input",
            "mouse release note=\(note) active=\(activeNotes.contains(note))"
        )
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
        audio.panic()
        activeNotes.removeAll()
        expectedPitches = practiceSession.prompt(at: currentSourcePromptIndex).pitches
        feedback = .waiting
        configureValidatorForCurrentPrompt(resetHeldNotes: true)
    }

    func startLesson(_ context: CourseLessonContext) {
        clearQuickHelp()
        stopPracticeLoop()
        stopExercisePreview()
        audio.panic()
        practiceSession = PracticeSession(
            context: context,
            jazzPracticeKey: preferredJazzPracticeKey
        )
        activeNotes.removeAll()
        var record = lessonRecords[context.progressKey] ?? LessonProgressRecord()
        record.registerStart()
        lessonRecords[context.progressKey] = record
        LearningExperienceStore.saveRecords(lessonRecords)
        resetLesson()
        isPracticeMode = true
    }

    func startLesson(course: PracticeCourse, lesson: PracticeLesson) {
        guard let context = CourseLibrary.context(courseID: course.id, lessonID: lesson.id) else { return }
        startLesson(context)
    }

    func startLessonInActiveCourse(_ lesson: PracticeLesson) {
        guard let context = CourseLibrary.context(courseID: activeCourseID, lessonID: lesson.id) else { return }
        startLesson(context)
    }

    func leavePractice(for destination: Destination = .courses) {
        clearQuickHelp()
        isPracticeMode = false
        stopPracticeLoop()
        stopExercisePreview()
        audio.panic()
        self.destination = destination
    }

    func isCompleted(_ lesson: PracticeLesson, in courseID: String) -> Bool {
        completedLessonIDs.contains(CourseProgressKey.make(courseID: courseID, lessonID: lesson.id))
    }

    func mastery(for lesson: PracticeLesson, in courseID: String) -> LessonMastery? {
        lessonRecords[CourseProgressKey.make(courseID: courseID, lessonID: lesson.id)]?.mastery
    }

    func progressRecord(for lesson: PracticeLesson, in courseID: String) -> LessonProgressRecord? {
        lessonRecords[CourseProgressKey.make(courseID: courseID, lessonID: lesson.id)]
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
        let shouldRestartPreview = isPreviewPlaying
        previewTempoBPM = min(max(beatsPerMinute, 50), 180)
        UserDefaults.standard.set(previewTempoBPM, forKey: previewTempoKey)
        if shouldRestartPreview { startExercisePreview() }
    }

    func setJazzPracticeKey(_ key: JazzPracticeKey) {
        guard supportsPracticeKeySelection, jazzPracticeKey != key else { return }
        stopPracticeLoop()
        stopExercisePreview()
        audio.resetPreviewPlaybackGeneration()
        preferredJazzPracticeKey = key
        UserDefaults.standard.set(key.rawValue, forKey: jazzPracticeKeyKey)
        practiceSession.selectJazzPracticeKey(key)
        resetCurrentPass(clearResult: true)
    }

    func practiceNoteName(_ pitch: UInt8) -> String {
        supportsPracticeKeySelection ? jazzPracticeKey.noteName(for: pitch) : noteName(pitch)
    }

    func setPracticeHandMode(_ mode: PracticeHandMode) {
        guard practiceSession.supportsFocusedPractice, practiceHandMode != mode else { return }
        BoardSenseiDiagnostics.trace(
            "practice-selection",
            "hand mode changing from=\(practiceHandMode.rawValue) to=\(mode.rawValue)"
        )
        stopPracticeLoop()
        stopExercisePreview()
        audio.resetPreviewPlaybackGeneration()
        practiceSession.handMode = mode
        resetCurrentPass(clearResult: true)
        BoardSenseiDiagnostics.trace(
            "practice-selection",
            "hand mode ready; firstPrompt=\(currentSourcePromptIndex) pitches=\(expectedPitches) previewPlaying=\(isPreviewPlaying)"
        )
    }

    func setPracticeMeasureRange(start: Int, end: Int) {
        guard practiceSession.supportsFocusedPractice else { return }
        let maximum = practiceSession.measureCount
        let safeStart = min(max(start, 1), maximum)
        let safeEnd = min(max(end, safeStart), maximum)
        guard practiceStartMeasure != safeStart || practiceEndMeasure != safeEnd else { return }
        stopPracticeLoop()
        stopExercisePreview()
        audio.resetPreviewPlaybackGeneration()
        practiceSession.startMeasure = safeStart
        practiceSession.endMeasure = safeEnd
        resetCurrentPass(clearResult: true)
    }

    func setAutomaticTempoProgressionEnabled(_ enabled: Bool) {
        guard practiceSession.supportsFocusedPractice else { return }
        practiceSession.automaticTempoProgressionEnabled = enabled
    }

    func setAutomaticTempoStep(_ step: Int) {
        guard practiceSession.supportsFocusedPractice else { return }
        practiceSession.automaticTempoStep = min(max(step, 1), 10)
    }

    func setMetronomeEnabled(_ enabled: Bool) {
        isMetronomeEnabled = enabled
        audio.setPreviewMetronomeEnabled(enabled)
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
        BoardSenseiDiagnostics.trace(
            "preview-action",
            "toggle entered; currentlyPlaying=\(isPreviewPlaying)"
        )
        if isPreviewPlaying { stopExercisePreview() }
        else { startExercisePreview() }
    }

    func toggleExerciseLoopEnabled() {
        BoardSenseiDiagnostics.trace(
            "preview-action",
            "loop toggle entered; oldValue=\(isExerciseLoopEnabled) previewPlaying=\(isPreviewPlaying)"
        )
        isExerciseLoopEnabled.toggle()
        if isPreviewPlaying { startExercisePreview() }
    }

    func startExercisePreview() {
        BoardSenseiDiagnostics.trace(
            "preview-action",
            "start entered; lesson=\(activeLesson.id) course=\(activeCourseID)"
        )
        stopCompletionSound()
        stopPracticeLoop()
        stopExercisePreview()
        let timeline = makeExercisePreviewTimeline()
        BoardSenseiDiagnostics.trace(
            "preview-action",
            "timeline ready; events=\(timeline.events.count) duration=\(timeline.durationQuarterNotes)"
        )
        do {
            try audio.startPreview(
                timeline: timeline,
                tempo: previewTempoBPM,
                looping: isExerciseLoopEnabled,
                metronomeEnabled: isMetronomeEnabled
            )
            BoardSenseiDiagnostics.trace("preview-action", "audio start returned")
            isPreviewPlaying = true
            BoardSenseiDiagnostics.trace("preview-action", "published isPreviewPlaying=true")
            previewTask = Task { [weak self] in
                guard let self else { return }
                BoardSenseiDiagnostics.trace("preview-observer", "task entered")
                await observeExercisePreview(timeline: timeline)
            }
        } catch {
            BoardSenseiDiagnostics.trace(
                "preview-action",
                "audio start failed; error=\(error.localizedDescription)"
            )
            isPreviewPlaying = false
            previewPitches = []
            previewPromptIndex = nil
        }
    }

    func stopExercisePreview() {
        BoardSenseiDiagnostics.trace(
            "preview-action",
            "stop entered; taskExists=\(previewTask != nil) playing=\(isPreviewPlaying)"
        )
        previewTask?.cancel()
        previewTask = nil
        audio.stopPreview()
        previewPitches = []
        previewPromptIndex = nil
        isPreviewPlaying = false
        if !isPracticeLoopActive { metronomeBeatIndex = nil }
    }

    private func handle(_ event: NormalizedMIDIEvent) {
        switch event {
        case let .noteOn(note, velocity, channel, _):
            BoardSenseiDiagnostics.trace(
                "midi-dispatch",
                "noteOn note=\(note) velocity=\(velocity) channel=\(channel) preview=\(isPreviewPlaying)"
            )
        case let .noteOff(note, _, channel, _):
            BoardSenseiDiagnostics.trace(
                "midi-dispatch",
                "noteOff note=\(note) channel=\(channel) preview=\(isPreviewPlaying)"
            )
        default:
            break
        }
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

        let input: (note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64)
        switch event {
        case let .noteOn(note, velocity, channel, timestamp) where velocity > 0:
            input = (note, velocity, channel, timestamp)
        case let .noteOff(note, _, channel, timestamp):
            input = (note, 0, channel, timestamp)
        default:
            return
        }

        let result = validator.validate(
            note: input.note,
            velocity: input.velocity,
            channel: input.channel,
            timestamp: input.timestamp
        )
        switch result.status {
        case .correct:
            completePrompt(notes: expectedPitches)
        case .incorrect:
            feedback = .incorrect(expected: expectedPitches, received: result.receivedPitch)
            mistakes += 1
            streak = 0
        case .partial:
            feedback = .waiting
        case .ignored, .unavailable:
            break
        }
    }

    private func configureValidatorForCurrentPrompt(resetHeldNotes: Bool) {
        if resetHeldNotes { validator.reset() }
        let prompt = practiceSession.prompt(at: currentSourcePromptIndex)
        let mode = practiceSession.validationMode(for: prompt)
        let spread: UInt16 = mode == .freshAttackSet ? 120 : 0
        if !validator.configure(pitches: prompt.pitches, mode: mode, spreadMilliseconds: spread) {
            validator.setExpectedPitch(prompt.pitches[0])
        }
    }

    private func completePrompt(notes: [UInt8]) {
        feedback = .correct(notes: notes)
        completedNotes += 1
        streak += 1
        expectedPitches = practiceSession.prompt(at: currentSourcePromptIndex).pitches
        if completedNotes < practicePromptCount {
            configureValidatorForCurrentPrompt(resetHeldNotes: false)
        } else {
            if isFocusedPracticeSelection {
                recordFocusedPracticeCompletion()
            } else {
                completedLessonIDs.insert(practiceSession.context.progressKey)
                persistCourseProgress()
                recordLessonCompletion()
            }
        }
    }

    private func persistCourseProgress() {
        UserDefaults.standard.set(completedLessonIDs.sorted(), forKey: completedLessonsKey)
    }

    private func recordLessonCompletion() {
        let progressKey = practiceSession.context.progressKey
        var record = lessonRecords[progressKey] ?? LessonProgressRecord()
        let priorMastery = record.mastery
        let priorBest = record.bestAccuracy
        let accuracy = record.registerCompletion(
            promptCount: activeLesson.promptCount,
            mistakes: mistakes
        )
        lessonRecords[progressKey] = record
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
        let record = lessonRecords[practiceSession.context.progressKey] ?? LessonProgressRecord()
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
            let signature = self.practiceSession.writtenTimeSignature ?? self.metronomeSignature
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

    private var previewPromptIndices: [Int] {
        practiceSession.playbackPromptIndices
    }

    private func makeExercisePreviewTimeline() -> PracticePlaybackTimeline {
        let signature = practiceSession.writtenTimeSignature ?? metronomeSignature
        var cursor = 0.0
        let events = previewPromptIndices.map { promptIndex in
            let prompt = practiceSession.prompt(at: promptIndex)
            let stepDuration = prompt.noteValue.quarterNoteBeats
            defer { cursor += stepDuration }
            return PracticePlaybackEvent(
                sourcePromptIndex: promptIndex,
                pitches: prompt.pitches,
                startQuarterNote: cursor,
                stepDurationQuarterNotes: stepDuration,
                audibleDurationQuarterNotes: max(0.02, stepDuration * 0.76)
            )
        }
        return PracticePlaybackTimeline(events: events, timeSignature: signature)
    }

    private func observeExercisePreview(timeline: PracticePlaybackTimeline) async {
        BoardSenseiDiagnostics.trace("preview-observer", "observer entered")
        while !Task.isCancelled, audio.isPreviewSequencePlaying {
            let position = audio.previewPositionInQuarterNotes
            let event = timeline.event(atQuarterNote: position, looping: isExerciseLoopEnabled)
            previewPromptIndex = event?.sourcePromptIndex
            previewPitches = event?.pitches ?? []

            let beatUnit = 4.0 / Double(timeline.timeSignature.denominator)
            metronomeBeatIndex = Int(floor(position / beatUnit + 0.000_1))
                % timeline.timeSignature.numerator
            do {
                try await Task.sleep(for: .milliseconds(24))
            } catch {
                return
            }
        }

        guard !Task.isCancelled else { return }
        BoardSenseiDiagnostics.trace("preview-observer", "render transport stopped naturally")
        audio.stopPreview()
        previewTask = nil
        previewPitches = []
        previewPromptIndex = nil
        isPreviewPlaying = false
        metronomeBeatIndex = nil
    }

}
