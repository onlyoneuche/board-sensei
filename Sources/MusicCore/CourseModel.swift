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
}

public struct PracticeLesson: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let objective: String
    public let theory: String
    public let studyGuide: String
    public let practiceInstruction: String
    public let sourceChapters: [Int]
    public let prompts: [PracticePrompt]
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
        self.prompts = pitches.map { PracticePrompt(pitches: [$0]) }
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
        self.prompts = chords.map(PracticePrompt.init)
        self.estimatedMinutes = estimatedMinutes
    }

    public var pitches: [UInt8] { prompts.flatMap(\.pitches) }
    public var promptCount: Int { prompts.count }
    public var isChordExercise: Bool { prompts.contains(where: \.isChord) }

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
    public let stages: [CourseStage]

    public init(id: String, title: String, summary: String, stages: [CourseStage]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.stages = stages
    }

    public var lessonCount: Int { stages.reduce(0) { $0 + $1.lessonCount } }
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
