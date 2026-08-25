import CryptoKit
import Foundation

public enum CourseLevel: String, CaseIterable, Codable, Sendable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    public var id: Self { self }

    public var summary: String {
        switch self {
        case .beginner: "Build the harmony, keyboard, and listening foundations used throughout jazz."
        case .intermediate: "Connect voicings, chord-scale choices, and voice leading across progressions."
        case .advanced: "Develop a flexible vocabulary for modern harmony, comping, and arrangement."
        }
    }
}

public enum NotationStaffLayout: String, Codable, Sendable, Equatable {
    case treble
    case bass
    case grand
}

<<<<<<< Updated upstream
=======
public enum PracticeExperience: String, Codable, Sendable, Equatable {
    case jazz
    case hanonTechnique
}

public enum JazzPromptKind: String, Codable, Sendable, Equatable {
    case melodic
    case chord
}

public enum JazzPracticeKey: Int, CaseIterable, Codable, Sendable, Equatable, Identifiable {
    case c = 0
    case dFlat = 1
    case d = 2
    case eFlat = 3
    case e = 4
    case f = 5
    case gFlat = 6
    case g = 7
    case aFlat = 8
    case a = 9
    case bFlat = 10
    case b = 11

    public var id: Self { self }
    public var semitoneOffset: Int { rawValue }

    public var displayName: String {
        switch self {
        case .c: "C"
        case .dFlat: "D♭"
        case .d: "D"
        case .eFlat: "E♭"
        case .e: "E"
        case .f: "F"
        case .gFlat: "G♭"
        case .g: "G"
        case .aFlat: "A♭"
        case .a: "A"
        case .bFlat: "B♭"
        case .b: "B"
        }
    }

    public var prefersFlats: Bool {
        switch self {
        case .dFlat, .eFlat, .f, .gFlat, .aFlat, .bFlat: true
        case .c, .d, .e, .g, .a, .b: false
        }
    }

    public func noteName(for midiPitch: UInt8) -> String {
        let sharpNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let flatNames = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]
        let pitch = Int(midiPitch)
        let names = prefersFlats ? flatNames : sharpNames
        return "\(names[pitch % 12])\((pitch / 12) - 1)"
    }
}

public enum PianoHand: String, Codable, Sendable, Equatable, Hashable {
    case left
    case right

    public var abbreviatedName: String { self == .left ? "LH" : "RH" }
}

public enum PracticeHandMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case both = "Both hands"
    case right = "Right hand"
    case left = "Left hand"

    public var id: Self { self }

    public var hand: PianoHand? {
        switch self {
        case .both: nil
        case .right: .right
        case .left: .left
        }
    }
}

public struct PracticeFingering: Codable, Sendable, Equatable {
    public let pitch: UInt8
    public let hand: PianoHand
    public let finger: UInt8

    public init(pitch: UInt8, hand: PianoHand, finger: UInt8) {
        precondition((1...5).contains(finger), "Piano finger numbers must be between 1 and 5")
        self.pitch = pitch
        self.hand = hand
        self.finger = finger
    }

    public var displayName: String { "\(hand.abbreviatedName) \(finger)" }
}

public enum PracticeNoteValue: String, Codable, Sendable, Equatable {
    case sixteenth
    case eighth
    case quarter
    case half
    case whole

    public var quarterNoteBeats: Double {
        switch self {
        case .sixteenth: 0.25
        case .eighth: 0.5
        case .quarter: 1
        case .half: 2
        case .whole: 4
        }
    }
}

public struct PracticeRepeatSection: Codable, Sendable, Equatable {
    public let startPromptIndex: Int
    public let endPromptIndex: Int
    public let playbackCount: Int

    public init(startPromptIndex: Int, endPromptIndex: Int, playbackCount: Int = 2) {
        precondition(startPromptIndex >= 0 && endPromptIndex >= startPromptIndex)
        precondition(playbackCount >= 2)
        self.startPromptIndex = startPromptIndex
        self.endPromptIndex = endPromptIndex
        self.playbackCount = playbackCount
    }
}

public struct PracticeScoreMetadata: Codable, Sendable, Equatable {
    public let timeSignature: PracticeTimeSignature
    public let promptsPerMeasure: Int
    public let measuresPerSystem: Int
    public let repeatSection: PracticeRepeatSection?

    public init(
        timeSignature: PracticeTimeSignature,
        promptsPerMeasure: Int,
        measuresPerSystem: Int = 4,
        repeatSection: PracticeRepeatSection? = nil
    ) {
        precondition(promptsPerMeasure > 0 && measuresPerSystem > 0)
        self.timeSignature = timeSignature
        self.promptsPerMeasure = promptsPerMeasure
        self.measuresPerSystem = measuresPerSystem
        self.repeatSection = repeatSection
    }
}

public struct JazzExercise: Codable, Sendable, Equatable {
    public let promptKind: JazzPromptKind
    public let prompts: [PracticePrompt]

    public init(promptKind: JazzPromptKind, prompts: [PracticePrompt]) {
        precondition(!prompts.isEmpty, "A Jazz exercise needs at least one prompt")
        self.promptKind = promptKind
        self.prompts = prompts
    }
}

public struct HanonExercise: Codable, Sendable, Equatable {
    public let prompts: [PracticePrompt]
    public let score: PracticeScoreMetadata

    public init(prompts: [PracticePrompt], score: PracticeScoreMetadata) {
        precondition(!prompts.isEmpty, "A Hanon exercise needs at least one prompt")
        precondition(prompts.allSatisfy { !$0.fingerings.isEmpty }, "Every Hanon prompt needs fingering")
        self.prompts = prompts
        self.score = score
    }
}

public enum PracticeExercise: Codable, Sendable, Equatable {
    case jazz(JazzExercise)
    case hanon(HanonExercise)

    public var experience: PracticeExperience {
        switch self {
        case .jazz: .jazz
        case .hanon: .hanonTechnique
        }
    }

    public var prompts: [PracticePrompt] {
        switch self {
        case let .jazz(exercise): exercise.prompts
        case let .hanon(exercise): exercise.prompts
        }
    }
}

>>>>>>> Stashed changes
public struct PracticePrompt: Codable, Sendable, Equatable {
    public let pitches: [UInt8]

    public init(pitches: [UInt8]) {
        precondition(!pitches.isEmpty, "A practice prompt needs at least one pitch")
        self.pitches = Array(Set(pitches)).sorted()
    }

    public var isChord: Bool { pitches.count > 1 }

    public func accepts(_ pitch: UInt8) -> Bool {
        pitches.contains(pitch)
    }

    public func isSatisfied(by activePitches: Set<UInt8>) -> Bool {
        Set(pitches) == activePitches
    }
<<<<<<< Updated upstream
=======

    public func filtered(for handMode: PracticeHandMode) -> PracticePrompt {
        guard let hand = handMode.hand, !fingerings.isEmpty else { return self }
        let selected = fingerings.filter { $0.hand == hand }
        precondition(!selected.isEmpty, "A hand-isolated prompt needs a note for the selected hand")
        return PracticePrompt(
            pitches: selected.map(\.pitch),
            fingerings: selected,
            noteValue: noteValue
        )
    }

    public func transposed(by semitones: Int) -> PracticePrompt {
        func transposedPitch(_ pitch: UInt8) -> UInt8 {
            let value = Int(pitch) + semitones
            precondition((0...127).contains(value), "Transposed MIDI pitches must remain in range")
            return UInt8(value)
        }
        let transposedPitches = pitches.map(transposedPitch)
        let transposedFingerings = fingerings.map { fingering in
            PracticeFingering(
                pitch: transposedPitch(fingering.pitch),
                hand: fingering.hand,
                finger: fingering.finger
            )
        }
        return PracticePrompt(
            pitches: transposedPitches,
            fingerings: transposedFingerings,
            noteValue: noteValue
        )
    }
}

public struct PracticeLessonGuidance: Codable, Sendable, Equatable {
    public let whyItMatters: String
    public let practicePlan: [String]
    public let listeningFocus: String
    public let successCriterion: String

    public init(
        whyItMatters: String,
        practicePlan: [String],
        listeningFocus: String,
        successCriterion: String
    ) {
        precondition(!practicePlan.isEmpty, "Lesson guidance needs at least one practice step")
        self.whyItMatters = whyItMatters
        self.practicePlan = practicePlan
        self.listeningFocus = listeningFocus
        self.successCriterion = successCriterion
    }
>>>>>>> Stashed changes
}

public struct PracticeLesson: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let objective: String
    public let theory: String
    public let studyGuide: String
    public let practiceInstruction: String
    public let sourceChapters: [Int]
<<<<<<< Updated upstream
    public let prompts: [PracticePrompt]
=======
    public let sourceName: String
    public let guidance: PracticeLessonGuidance?
    public let exercise: PracticeExercise
>>>>>>> Stashed changes
    public let estimatedMinutes: Int

    public init(
        id: String,
        title: String,
        objective: String,
        theory: String = "",
        studyGuide: String = "",
        practiceInstruction: String,
        sourceChapters: [Int],
        pitches: [UInt8],
        estimatedMinutes: Int = 5
    ) {
        precondition(!pitches.isEmpty, "A playable lesson needs at least one pitch")
        self.id = id
        self.title = title
        self.objective = objective
        let resolvedTheory = theory.isEmpty ? objective : theory
        self.theory = resolvedTheory
        self.studyGuide = studyGuide.isEmpty ? resolvedTheory : studyGuide
        self.practiceInstruction = practiceInstruction
        self.sourceChapters = sourceChapters
<<<<<<< Updated upstream
        self.prompts = pitches.map { PracticePrompt(pitches: [$0]) }
=======
        self.sourceName = sourceName
        self.guidance = guidance
        self.exercise = .jazz(JazzExercise(
            promptKind: .melodic,
            prompts: pitches.map { PracticePrompt(pitches: [$0]) }
        ))
>>>>>>> Stashed changes
        self.estimatedMinutes = estimatedMinutes
    }

    public init(
        id: String,
        title: String,
        objective: String,
        theory: String = "",
        studyGuide: String = "",
        practiceInstruction: String,
        sourceChapters: [Int],
<<<<<<< Updated upstream
=======
        sourceName: String = "Chapter",
        guidance: PracticeLessonGuidance? = nil,
        fingeredPrompts: [[PracticeFingering]],
        noteValues: [PracticeNoteValue]? = nil,
        scoreMetadata: PracticeScoreMetadata,
        estimatedMinutes: Int = 5
    ) {
        precondition(!fingeredPrompts.isEmpty, "A fingered lesson needs at least one prompt")
        precondition(fingeredPrompts.allSatisfy { !$0.isEmpty }, "Every fingered prompt needs at least one note")
        precondition(noteValues == nil || noteValues?.count == fingeredPrompts.count)
        self.id = id
        self.title = title
        self.objective = objective
        let resolvedTheory = theory.isEmpty ? objective : theory
        self.theory = resolvedTheory
        self.studyGuide = studyGuide.isEmpty ? resolvedTheory : studyGuide
        self.practiceInstruction = practiceInstruction
        self.sourceChapters = sourceChapters
        self.sourceName = sourceName
        self.guidance = guidance
        let prompts = fingeredPrompts.enumerated().map { index, marks in
            PracticePrompt(
                pitches: marks.map(\.pitch),
                fingerings: marks,
                noteValue: noteValues?[index] ?? .quarter
            )
        }
        self.exercise = .hanon(HanonExercise(prompts: prompts, score: scoreMetadata))
        self.estimatedMinutes = estimatedMinutes
    }

    public init(
        id: String,
        title: String,
        objective: String,
        theory: String = "",
        studyGuide: String = "",
        practiceInstruction: String,
        sourceChapters: [Int],
        sourceName: String = "Chapter",
        guidance: PracticeLessonGuidance? = nil,
>>>>>>> Stashed changes
        chords: [[UInt8]],
        estimatedMinutes: Int = 5
    ) {
        precondition(!chords.isEmpty, "A chord lesson needs at least one prompt")
        self.id = id
        self.title = title
        self.objective = objective
        let resolvedTheory = theory.isEmpty ? objective : theory
        self.theory = resolvedTheory
        self.studyGuide = studyGuide.isEmpty ? resolvedTheory : studyGuide
        self.practiceInstruction = practiceInstruction
        self.sourceChapters = sourceChapters
<<<<<<< Updated upstream
        self.prompts = chords.map(PracticePrompt.init)
=======
        self.sourceName = sourceName
        self.guidance = guidance
        self.exercise = .jazz(JazzExercise(
            promptKind: .chord,
            prompts: chords.map { PracticePrompt(pitches: $0) }
        ))
>>>>>>> Stashed changes
        self.estimatedMinutes = estimatedMinutes
    }

    public var prompts: [PracticePrompt] { exercise.prompts }
    public var experience: PracticeExperience { exercise.experience }
    public var jazzExercise: JazzExercise? {
        guard case let .jazz(exercise) = exercise else { return nil }
        return exercise
    }
    public var hanonExercise: HanonExercise? {
        guard case let .hanon(exercise) = exercise else { return nil }
        return exercise
    }
    public var pitches: [UInt8] { prompts.flatMap(\.pitches) }
    public var promptCount: Int { prompts.count }
    public var isChordExercise: Bool { jazzExercise?.promptKind == .chord }

<<<<<<< Updated upstream
=======
    public var playbackPromptIndices: [Int] {
        guard
            let repeated = hanonExercise?.score.repeatSection,
            repeated.startPromptIndex < prompts.count,
            repeated.endPromptIndex < prompts.count
        else {
            return Array(prompts.indices)
        }
        let prefix = Array(0..<repeated.startPromptIndex)
        let body = (0..<repeated.playbackCount).flatMap { _ in
            Array(repeated.startPromptIndex...repeated.endPromptIndex)
        }
        let suffixStart = repeated.endPromptIndex + 1
        let suffix = suffixStart < prompts.count ? Array(suffixStart..<prompts.count) : []
        return prefix + body + suffix
    }

    public var playbackDurationInQuarterNotes: Double {
        playbackPromptIndices.reduce(0) { $0 + prompts[$1].noteValue.quarterNoteBeats }
    }

    public var scoreMeasureCount: Int {
        guard let promptsPerMeasure = hanonExercise?.score.promptsPerMeasure else { return 1 }
        return Int(ceil(Double(prompts.count) / Double(promptsPerMeasure)))
    }

    public func promptIndices(fromMeasure startMeasure: Int, throughMeasure endMeasure: Int) -> [Int] {
        guard let promptsPerMeasure = hanonExercise?.score.promptsPerMeasure else {
            return Array(prompts.indices)
        }
        let safeStart = min(max(startMeasure, 1), scoreMeasureCount)
        let safeEnd = min(max(endMeasure, safeStart), scoreMeasureCount)
        let startIndex = (safeStart - 1) * promptsPerMeasure
        let endIndex = min(safeEnd * promptsPerMeasure, prompts.count)
        return Array(startIndex..<endIndex)
    }

>>>>>>> Stashed changes
    public var chapterLabel: String {
        let values = sourceChapters.map(String.init).joined(separator: ", ")
        return sourceChapters.count == 1 ? "Chapter \(values)" : "Chapters \(values)"
    }

    public var staffLayout: NotationStaffLayout {
        let hasBassNotes = pitches.contains { $0 < 60 }
        let hasTrebleNotes = pitches.contains { $0 >= 60 }
        if hasBassNotes && hasTrebleNotes { return .grand }
        return hasBassNotes ? .bass : .treble
    }

    public var topicWhyItMatters: String {
        if isChordExercise {
            return "Jazz harmony becomes fluent when a voicing is heard as a complete sound and as several voices moving at once. This exercise connects the chord shape under your hands to its function, color, and destination in a progression."
        }
        return "Melodic fluency depends on recognizing interval direction and tonal pull before searching for individual keys. This exercise builds the link between the sound you expect, the note shown on the staff, and the movement your hand makes."
    }

    public var topicPracticePlan: [String] {
        if isChordExercise {
            return [
                "Read the explanation once, then identify the function or color that changes from one voicing to the next.",
                "Use Hear full exercise in Practice at a slow tempo. Watch each complete chord appear on the staff and keyboard while you listen.",
                "Prepare every chord silently before playing. Press all required notes together, release cleanly, and avoid adding doubled or neighboring notes.",
                practiceInstruction,
                "Repeat the route without a miss, then raise the tempo gradually. Stop increasing it as soon as the attacks stop landing together.",
            ]
        }
        return [
            "Read the explanation once, then sing or imagine the contour before touching the keyboard.",
            "Use Hear full exercise in Practice at a slow tempo. Follow the note on the staff and its matching key as the route plays.",
            "Locate the starting note without guessing, keep the hand relaxed, and use an even attack from note to note.",
            practiceInstruction,
            "Repeat the complete route without a miss, then raise the tempo only while the rhythm and note order remain controlled.",
        ]
    }

    public var topicListeningFocus: String {
        if isChordExercise {
            return "Listen for the chord as one coordinated attack, then follow its inner voices. Notice common tones that remain in place, notes that resolve by step, and the change from tension to release. Uneven attacks can make a correct voicing sound unclear, so let your ear judge timing as well as pitch."
        }
        return "Listen for contour first: whether the line rises, falls, repeats, or changes direction. Then notice the size of each move and which notes feel stable or unresolved. Aim for an even pulse and consistent tone so interval differences—not accidental accents—shape the phrase."
    }

    public var topicSuccessCriterion: String {
        if isChordExercise {
            return "Pass condition: play every displayed voicing as its exact complete pitch set, with no missing or extra notes."
        }
        return "Pass condition: play every displayed note in order, with no substituted or skipped pitches."
    }

    /// Canonical speech-friendly content used for generation and cache invalidation.
    public var narrationScript: String {
        let numberedPlan = topicPracticePlan.enumerated()
            .map { "Step \($0.offset + 1). \($0.element)" }
            .joined(separator: " ")

        let script = """
        \(title). \(objective)
        What you are learning. \(studyGuide)
        Why it matters. \(topicWhyItMatters)
        Exercise brief. \(practiceInstruction) \(topicSuccessCriterion)
        How to practise. \(numberedPlan)
        What to listen for. \(topicListeningFocus)
        """

        return script
            .replacingOccurrences(of: "II–V–I", with: "two five one")
            .replacingOccurrences(of: "ii–V–I", with: "two five one")
            .replacingOccurrences(of: "BPM", with: "beats per minute")
    }

    public var narrationContentHash: String {
        SHA256.hash(data: Data(narrationScript.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

public struct CourseModule: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let summary: String
    public let lessons: [PracticeLesson]

    public init(id: String, title: String, summary: String, lessons: [PracticeLesson]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.lessons = lessons
    }
}

public struct CourseStage: Identifiable, Codable, Sendable, Equatable {
    public let level: CourseLevel
    public let modules: [CourseModule]

    public init(level: CourseLevel, modules: [CourseModule]) {
        self.level = level
        self.modules = modules
    }

    public var id: CourseLevel { level }
    public var lessonCount: Int { modules.reduce(0) { $0 + $1.lessons.count } }
}

public struct PracticeCourse: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let summary: String
    public let experience: PracticeExperience
    public let stages: [CourseStage]

    public init(
        id: String,
        title: String,
        summary: String,
        experience: PracticeExperience,
        stages: [CourseStage]
    ) {
        precondition(stages.flatMap(\.modules).flatMap(\.lessons).allSatisfy { $0.experience == experience })
        self.id = id
        self.title = title
        self.summary = summary
        self.experience = experience
        self.stages = stages
    }

    public var lessonCount: Int { stages.reduce(0) { $0 + $1.lessonCount } }
}

public struct CourseLessonContext: Sendable, Equatable {
    public let courseID: String
    public let courseTitle: String
    public let experience: PracticeExperience
    public let lesson: PracticeLesson
    public let navigation: CourseLessonNavigation

    public var progressKey: String { CourseProgressKey.make(courseID: courseID, lessonID: lesson.id) }
}

public enum CourseProgressKey {
    public static let separator = "::"

    public static func make(courseID: String, lessonID: String) -> String {
        "\(courseID)\(separator)\(lessonID)"
    }

    public static func resolveLegacyLessonID(_ lessonID: String, courses: [PracticeCourse]) -> String? {
        if lessonID.contains(separator) { return lessonID }
        guard let course = courses.first(where: { $0.lesson(id: lessonID) != nil }) else { return nil }
        return make(courseID: course.id, lessonID: lessonID)
    }

    public static func migrate(_ keys: some Sequence<String>, courses: [PracticeCourse]) -> Set<String> {
        Set(keys.compactMap { resolveLegacyLessonID($0, courses: courses) })
    }
}

public struct CourseLessonNavigation: Sendable, Equatable {
    public let level: CourseLevel
    public let chapterNumber: Int
    public let chapterTitle: String
    public let chapterLessons: [PracticeLesson]
    public let previousLesson: PracticeLesson?
    public let nextLesson: PracticeLesson?

    public init(
        level: CourseLevel,
        chapterNumber: Int,
        chapterTitle: String,
        chapterLessons: [PracticeLesson],
        previousLesson: PracticeLesson?,
        nextLesson: PracticeLesson?
    ) {
        self.level = level
        self.chapterNumber = chapterNumber
        self.chapterTitle = chapterTitle
        self.chapterLessons = chapterLessons
        self.previousLesson = previousLesson
        self.nextLesson = nextLesson
    }
}
