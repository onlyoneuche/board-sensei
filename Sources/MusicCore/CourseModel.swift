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

public struct PracticePrompt: Codable, Sendable, Equatable {
    public let pitches: [UInt8]
    public let fingerings: [PracticeFingering]
    public let noteValue: PracticeNoteValue

    public init(
        pitches: [UInt8],
        fingerings: [PracticeFingering] = [],
        noteValue: PracticeNoteValue = .quarter
    ) {
        precondition(!pitches.isEmpty, "A practice prompt needs at least one pitch")
        self.pitches = Array(Set(pitches)).sorted()
        precondition(
            fingerings.isEmpty || Set(fingerings.map(\.pitch)) == Set(pitches),
            "Fingerings must describe every pitch in the prompt"
        )
        self.fingerings = fingerings.sorted {
            if $0.pitch == $1.pitch { return $0.hand.rawValue < $1.hand.rawValue }
            return $0.pitch < $1.pitch
        }
        self.noteValue = noteValue
    }

    public var isChord: Bool { pitches.count > 1 }

    public func accepts(_ pitch: UInt8) -> Bool {
        pitches.contains(pitch)
    }

    public func isSatisfied(by activePitches: Set<UInt8>) -> Bool {
        Set(pitches) == activePitches
    }

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
}

public struct PracticeLesson: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let objective: String
    public let theory: String
    public let studyGuide: String
    public let practiceInstruction: String
    public let sourceChapters: [Int]
    public let sourceName: String
    public let guidance: PracticeLessonGuidance?
    public let prompts: [PracticePrompt]
    public let scoreMetadata: PracticeScoreMetadata?
    public let estimatedMinutes: Int

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
        pitches: [UInt8],
        scoreMetadata: PracticeScoreMetadata? = nil,
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
        self.sourceName = sourceName
        self.guidance = guidance
        self.prompts = pitches.map { PracticePrompt(pitches: [$0]) }
        self.scoreMetadata = scoreMetadata
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
        fingeredPrompts: [[PracticeFingering]],
        noteValues: [PracticeNoteValue]? = nil,
        scoreMetadata: PracticeScoreMetadata? = nil,
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
        self.prompts = fingeredPrompts.enumerated().map { index, marks in
            PracticePrompt(
                pitches: marks.map(\.pitch),
                fingerings: marks,
                noteValue: noteValues?[index] ?? .quarter
            )
        }
        self.scoreMetadata = scoreMetadata
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
        chords: [[UInt8]],
        scoreMetadata: PracticeScoreMetadata? = nil,
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
        self.sourceName = sourceName
        self.guidance = guidance
        self.prompts = chords.map { PracticePrompt(pitches: $0) }
        self.scoreMetadata = scoreMetadata
        self.estimatedMinutes = estimatedMinutes
    }

    public var pitches: [UInt8] { prompts.flatMap(\.pitches) }
    public var promptCount: Int { prompts.count }
    public var isChordExercise: Bool { prompts.contains(where: \.isChord) }

    public var playbackPromptIndices: [Int] {
        guard
            let repeated = scoreMetadata?.repeatSection,
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
        guard let promptsPerMeasure = scoreMetadata?.promptsPerMeasure else { return 1 }
        return Int(ceil(Double(prompts.count) / Double(promptsPerMeasure)))
    }

    public func promptIndices(fromMeasure startMeasure: Int, throughMeasure endMeasure: Int) -> [Int] {
        guard let promptsPerMeasure = scoreMetadata?.promptsPerMeasure else {
            return Array(prompts.indices)
        }
        let safeStart = min(max(startMeasure, 1), scoreMeasureCount)
        let safeEnd = min(max(endMeasure, safeStart), scoreMeasureCount)
        let startIndex = (safeStart - 1) * promptsPerMeasure
        let endIndex = min(safeEnd * promptsPerMeasure, prompts.count)
        return Array(startIndex..<endIndex)
    }

    public var chapterLabel: String {
        let values = sourceChapters.map(String.init).joined(separator: ", ")
        return sourceChapters.count == 1 ? "\(sourceName) \(values)" : "\(sourceName)s \(values)"
    }

    public var staffLayout: NotationStaffLayout {
        let hasBassNotes = pitches.contains { $0 < 60 }
        let hasTrebleNotes = pitches.contains { $0 >= 60 }
        if hasBassNotes && hasTrebleNotes { return .grand }
        return hasBassNotes ? .bass : .treble
    }

    public var topicWhyItMatters: String {
        if let guidance { return guidance.whyItMatters }
        if isChordExercise {
            return "Jazz harmony becomes fluent when a voicing is heard as a complete sound and as several voices moving at once. This exercise connects the chord shape under your hands to its function, color, and destination in a progression."
        }
        return "Melodic fluency depends on recognizing interval direction and tonal pull before searching for individual keys. This exercise builds the link between the sound you expect, the note shown on the staff, and the movement your hand makes."
    }

    public var topicPracticePlan: [String] {
        if let guidance { return guidance.practicePlan }
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
        if let guidance { return guidance.listeningFocus }
        if isChordExercise {
            return "Listen for the chord as one coordinated attack, then follow its inner voices. Notice common tones that remain in place, notes that resolve by step, and the change from tension to release. Uneven attacks can make a correct voicing sound unclear, so let your ear judge timing as well as pitch."
        }
        return "Listen for contour first: whether the line rises, falls, repeats, or changes direction. Then notice the size of each move and which notes feel stable or unresolved. Aim for an even pulse and consistent tone so interval differences—not accidental accents—shape the phrase."
    }

    public var topicSuccessCriterion: String {
        if let guidance { return guidance.successCriterion }
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
    public let title: String
    public let summary: String
    public let modules: [CourseModule]

    public init(
        level: CourseLevel,
        title: String? = nil,
        summary: String? = nil,
        modules: [CourseModule]
    ) {
        self.level = level
        self.title = title ?? level.rawValue
        self.summary = summary ?? level.summary
        self.modules = modules
    }

    public var id: CourseLevel { level }
    public var lessonCount: Int { modules.reduce(0) { $0 + $1.lessons.count } }
}

public struct PracticeCourse: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let summary: String
    public let stages: [CourseStage]

    public init(id: String, title: String, summary: String, stages: [CourseStage]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.stages = stages
    }

    public var lessonCount: Int { stages.reduce(0) { $0 + $1.lessonCount } }

    public var lessons: [PracticeLesson] {
        stages.flatMap(\.modules).flatMap(\.lessons)
    }

    public func lesson(id: String) -> PracticeLesson? {
        lessons.first { $0.id == id }
    }

    public func navigation(forLessonID id: String) -> CourseLessonNavigation? {
        guard let globalIndex = lessons.firstIndex(where: { $0.id == id }) else { return nil }

        for stage in stages {
            for (chapterIndex, module) in stage.modules.enumerated() where module.lessons.contains(where: { $0.id == id }) {
                return CourseLessonNavigation(
                    level: stage.level,
                    stageTitle: stage.title,
                    chapterNumber: chapterIndex + 1,
                    chapterTitle: module.title,
                    chapterLessons: module.lessons,
                    previousLesson: globalIndex > lessons.startIndex ? lessons[globalIndex - 1] : nil,
                    nextLesson: globalIndex < lessons.index(before: lessons.endIndex) ? lessons[globalIndex + 1] : nil
                )
            }
        }
        return nil
    }
}

public struct CourseLessonNavigation: Sendable, Equatable {
    public let level: CourseLevel
    public let stageTitle: String
    public let chapterNumber: Int
    public let chapterTitle: String
    public let chapterLessons: [PracticeLesson]
    public let previousLesson: PracticeLesson?
    public let nextLesson: PracticeLesson?

    public init(
        level: CourseLevel,
        stageTitle: String? = nil,
        chapterNumber: Int,
        chapterTitle: String,
        chapterLessons: [PracticeLesson],
        previousLesson: PracticeLesson?,
        nextLesson: PracticeLesson?
    ) {
        self.level = level
        self.stageTitle = stageTitle ?? level.rawValue
        self.chapterNumber = chapterNumber
        self.chapterTitle = chapterTitle
        self.chapterLessons = chapterLessons
        self.previousLesson = previousLesson
        self.nextLesson = nextLesson
    }
}
