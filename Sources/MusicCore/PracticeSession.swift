public enum PracticePresentation: Sendable, Equatable {
    case jazzPromptStaff
    case hanonFullScore
}

public enum HanonPracticeRegister {
    public static let fiveOctaveKeyboardRange = 36...96
    public static let preferredSemitoneOffset = 12

    public static func semitoneOffset(for prompts: [PracticePrompt]) -> Int {
        let shiftedPitches = prompts.flatMap(\.pitches).map {
            Int($0) + preferredSemitoneOffset
        }
        return shiftedPitches.allSatisfy(fiveOctaveKeyboardRange.contains)
            ? preferredSemitoneOffset
            : 0
    }
}

public struct PracticeSession: Sendable, Equatable {
    public let context: CourseLessonContext
    public private(set) var jazzPracticeKey: JazzPracticeKey
    public let hanonPracticeSemitoneOffset: Int
    public var handMode: PracticeHandMode
    public var startMeasure: Int
    public var endMeasure: Int
    public var automaticTempoProgressionEnabled: Bool
    public var automaticTempoStep: Int

    public init(context: CourseLessonContext, jazzPracticeKey: JazzPracticeKey = .c) {
        self.context = context
        self.jazzPracticeKey = context.experience == .jazz ? jazzPracticeKey : .c
        hanonPracticeSemitoneOffset = context.experience == .hanonTechnique
            ? HanonPracticeRegister.semitoneOffset(for: context.lesson.prompts)
            : 0
        handMode = .both
        startMeasure = 1
        endMeasure = context.lesson.hanonExercise?.scoreMeasureCount(for: context.lesson.promptCount) ?? 1
        automaticTempoProgressionEnabled = false
        automaticTempoStep = 5
    }

    public var presentation: PracticePresentation {
        switch context.experience {
        case .jazz: .jazzPromptStaff
        case .hanonTechnique: .hanonFullScore
        }
    }

    public var supportsFocusedPractice: Bool { context.experience == .hanonTechnique }
    public var supportsKeySelection: Bool { context.experience == .jazz }

    /// Supplies the complete Hanon score in the fitted practice register while
    /// retaining the source score's timing and fingering metadata.
    public var hanonPracticeExercise: HanonExercise? {
        guard case let .hanon(exercise) = context.lesson.exercise else { return nil }
        return HanonExercise(
            prompts: context.lesson.prompts.indices.map { fullPrompt(at: $0) },
            score: exercise.score
        )
    }

    public var measureCount: Int {
        guard let exercise = context.lesson.hanonExercise else { return 1 }
        return exercise.scoreMeasureCount(for: context.lesson.promptCount)
    }

    public var promptIndices: [Int] {
        guard supportsFocusedPractice else { return Array(context.lesson.prompts.indices) }
        return context.lesson.promptIndices(fromMeasure: startMeasure, throughMeasure: endMeasure)
    }

    public var isFocusedSelection: Bool {
        supportsFocusedPractice
            && (handMode != .both || startMeasure != 1 || endMeasure != measureCount)
    }

    public var isFullMeasureRange: Bool { startMeasure == 1 && endMeasure == measureCount }

    public var staffLayout: NotationStaffLayout {
        guard supportsKeySelection else { return context.lesson.staffLayout }
        let pitches = context.lesson.prompts.indices.flatMap { prompt(at: $0).pitches }
        let hasBassNotes = pitches.contains { $0 < 60 }
        let hasTrebleNotes = pitches.contains { $0 >= 60 }
        if hasBassNotes && hasTrebleNotes { return .grand }
        return hasBassNotes ? .bass : .treble
    }

    @discardableResult
    public mutating func selectJazzPracticeKey(_ key: JazzPracticeKey) -> Bool {
        guard supportsKeySelection else { return false }
        jazzPracticeKey = key
        return true
    }

    /// Returns the source prompt that should be presented as the current target.
    /// A completed pass wraps to its first selected prompt so the score and piano
    /// are ready for repetition even while scoring waits for the next loop boundary.
    public func currentSourcePromptIndex(completedPromptCount: Int) -> Int {
        guard let firstPromptIndex = promptIndices.first else { return 0 }
        guard completedPromptCount >= 0, completedPromptCount < promptIndices.count else {
            return firstPromptIndex
        }
        return promptIndices[completedPromptCount]
    }

    public func fullPrompt(at sourceIndex: Int) -> PracticePrompt {
        let prompt = context.lesson.prompts[sourceIndex]
        switch context.experience {
        case .jazz:
            return prompt.transposed(by: jazzPracticeKey.semitoneOffset)
        case .hanonTechnique:
            return prompt.transposed(by: hanonPracticeSemitoneOffset)
        }
    }

    public func prompt(at sourceIndex: Int) -> PracticePrompt {
        let prompt = fullPrompt(at: sourceIndex)
        return context.experience == .hanonTechnique
            ? prompt.filtered(for: handMode)
            : prompt
    }

    public func validationMode(for prompt: PracticePrompt) -> PracticePromptValidationMode {
        switch context.lesson.exercise {
        case let .jazz(exercise):
            return exercise.promptKind == .chord ? .exactHeldSet : .singleNote
        case .hanon:
            return prompt.pitches.count == 1 ? .singleNote : .freshAttackSet
        }
    }

    public var writtenTimeSignature: PracticeTimeSignature? {
        context.lesson.hanonExercise?.score.timeSignature
    }
}

private extension HanonExercise {
    func scoreMeasureCount(for promptCount: Int) -> Int {
        (promptCount + score.promptsPerMeasure - 1) / score.promptsPerMeasure
    }
}
