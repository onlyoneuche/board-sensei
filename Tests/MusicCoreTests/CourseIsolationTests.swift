import Testing
@testable import MusicCore

@Suite("Course practice isolation")
struct CourseIsolationTests {
    @Test("Course contexts carry explicit, matching practice experiences")
    func typedContexts() throws {
        let jazz = try #require(CourseLibrary.context(
            courseID: JazzCourseCatalog.course.id,
            lessonID: "b-step-skip"
        ))
        let hanon = try #require(CourseLibrary.context(
            courseID: HanonCourseCatalog.course.id,
            lessonID: "hanon-01"
        ))

        #expect(jazz.experience == .jazz)
        #expect(jazz.lesson.jazzExercise != nil)
        #expect(jazz.lesson.hanonExercise == nil)
        #expect(hanon.experience == .hanonTechnique)
        #expect(hanon.lesson.hanonExercise != nil)
        #expect(hanon.lesson.jazzExercise == nil)
    }

    @Test("Fresh sessions do not carry Hanon controls into Jazz")
    func sessionSwitching() throws {
        let hanonContext = try #require(CourseLibrary.context(
            courseID: HanonCourseCatalog.course.id,
            lessonID: "hanon-01"
        ))
        var hanon = PracticeSession(context: hanonContext)
        hanon.handMode = .left
        hanon.startMeasure = 3
        hanon.endMeasure = 4
        hanon.automaticTempoProgressionEnabled = true

        let jazzContext = try #require(CourseLibrary.context(
            courseID: JazzCourseCatalog.course.id,
            lessonID: "b-step-skip"
        ))
        let jazz = PracticeSession(context: jazzContext)

        #expect(hanon.presentation == .hanonFullScore)
        #expect(hanon.supportsFocusedPractice)
        #expect(hanon.isFocusedSelection)
        #expect(jazz.presentation == .jazzPromptStaff)
        #expect(!jazz.supportsFocusedPractice)
        #expect(jazz.handMode == .both)
        #expect(jazz.startMeasure == 1)
        #expect(jazz.endMeasure == 1)
        #expect(!jazz.automaticTempoProgressionEnabled)
        #expect(jazz.promptIndices == Array(jazzContext.lesson.prompts.indices))
    }

    @Test("Prompt interpretation is course-specific rather than pitch-count based")
    func validationPolicies() throws {
        let melodic = try #require(CourseLibrary.context(
            courseID: JazzCourseCatalog.course.id,
            lessonID: "b-step-skip"
        ))
        let chord = try #require(CourseLibrary.context(
            courseID: JazzCourseCatalog.course.id,
            lessonID: "b-major-minor"
        ))
        let hanon = try #require(CourseLibrary.context(
            courseID: HanonCourseCatalog.course.id,
            lessonID: "hanon-01"
        ))

        let melodicSession = PracticeSession(context: melodic)
        let chordSession = PracticeSession(context: chord)
        var hanonSession = PracticeSession(context: hanon)

        #expect(melodicSession.validationMode(for: melodicSession.prompt(at: 0)) == .singleNote)
        #expect(chordSession.validationMode(for: chordSession.prompt(at: 0)) == .exactHeldSet)
        #expect(hanonSession.validationMode(for: hanonSession.prompt(at: 0)) == .freshAttackSet)

        hanonSession.handMode = .right
        #expect(hanonSession.prompt(at: 0).pitches.count == 1)
        #expect(hanonSession.validationMode(for: hanonSession.prompt(at: 0)) == .singleNote)
    }

    @Test("A completed pass presents its first selected prompt again")
    func completedPassWrapsPresentation() throws {
        let jazzContext = try #require(CourseLibrary.context(
            courseID: JazzCourseCatalog.course.id,
            lessonID: "b-step-skip"
        ))
        let jazz = PracticeSession(context: jazzContext)
        let jazzFirst = try #require(jazz.promptIndices.first)

        #expect(jazz.currentSourcePromptIndex(completedPromptCount: 0) == jazzFirst)
        #expect(
            jazz.currentSourcePromptIndex(completedPromptCount: jazz.promptIndices.count)
                == jazzFirst
        )

        let hanonContext = try #require(CourseLibrary.context(
            courseID: HanonCourseCatalog.course.id,
            lessonID: "hanon-01"
        ))
        var hanon = PracticeSession(context: hanonContext)
        hanon.startMeasure = 3
        hanon.endMeasure = 4
        let selectionFirst = try #require(hanon.promptIndices.first)

        #expect(selectionFirst > 0)
        #expect(
            hanon.currentSourcePromptIndex(completedPromptCount: hanon.promptIndices.count)
                == selectionFirst
        )
    }

    @Test("Jazz key selection transposes prompts without affecting Hanon")
    func jazzKeyTransposition() throws {
        let jazzContext = try #require(CourseLibrary.context(
            courseID: JazzCourseCatalog.course.id,
            lessonID: "b-major-minor"
        ))
        var jazz = PracticeSession(context: jazzContext)
        let sourcePrompt = jazz.prompt(at: 0)

        let didSelectJazzKey = jazz.selectJazzPracticeKey(.dFlat)
        #expect(didSelectJazzKey)
        #expect(jazz.jazzPracticeKey == .dFlat)
        #expect(jazz.prompt(at: 0).pitches == sourcePrompt.pitches.map { $0 + 1 })
        #expect(jazz.prompt(at: 0).noteValue == sourcePrompt.noteValue)
        #expect(jazz.validationMode(for: jazz.prompt(at: 0)) == .exactHeldSet)
        #expect(JazzPracticeKey.dFlat.noteName(for: 61) == "D♭4")

        let hanonContext = try #require(CourseLibrary.context(
            courseID: HanonCourseCatalog.course.id,
            lessonID: "hanon-01"
        ))
        var hanon = PracticeSession(context: hanonContext, jazzPracticeKey: .b)
        let writtenPrompt = hanon.prompt(at: 0)

        #expect(hanon.jazzPracticeKey == .c)
        let didSelectHanonKey = hanon.selectJazzPracticeKey(.dFlat)
        #expect(!didSelectHanonKey)
        #expect(hanon.prompt(at: 0) == writtenPrompt)
    }

    @Test("Hanon begins in the second visible octave when the complete route fits")
    func hanonKeyboardFriendlyRegister() throws {
        let context = try #require(CourseLibrary.context(
            courseID: HanonCourseCatalog.course.id,
            lessonID: "hanon-01"
        ))
        let session = PracticeSession(context: context)
        let written = context.lesson.prompts[0]
        let practised = session.fullPrompt(at: 0)

        #expect(session.hanonPracticeSemitoneOffset == 12)
        #expect(written.pitches == [36, 48])
        #expect(practised.pitches == [48, 60])
        #expect(practised.fingerings.map(\.pitch) == written.fingerings.map { $0.pitch + 12 })
        #expect(
            session.hanonPracticeExercise?.prompts
                == context.lesson.prompts.indices.map { session.fullPrompt(at: $0) }
        )
    }

    @Test("Every Hanon practice route stays reachable on the five-octave piano")
    func hanonPracticeRange() throws {
        var offsets: [Int] = []
        for lesson in HanonCourseCatalog.course.lessons {
            let context = try #require(CourseLibrary.context(
                courseID: HanonCourseCatalog.course.id,
                lessonID: lesson.id
            ))
            let session = PracticeSession(context: context)
            offsets.append(session.hanonPracticeSemitoneOffset)
            let practicePitches = lesson.prompts.indices.flatMap {
                session.fullPrompt(at: $0).pitches
            }

            #expect(practicePitches.allSatisfy { (36...96).contains($0) })
            #expect([0, 12].contains(session.hanonPracticeSemitoneOffset))
        }

        #expect(offsets.filter { $0 == 12 }.count == 19)
        #expect(offsets.last == 0)
    }

    @Test("Every Jazz exercise fits the practice piano in all selectable keys")
    func transposedJazzRange() {
        let lessons = JazzCourseCatalog.course.stages.flatMap(\.modules).flatMap(\.lessons)

        for lesson in lessons {
            for key in JazzPracticeKey.allCases {
                let pitches = lesson.prompts.flatMap { prompt in
                    prompt.transposed(by: key.semitoneOffset).pitches
                }
                #expect(pitches.allSatisfy { (36...96).contains($0) })
            }
        }
    }

    @Test("Progress keys are namespaced and legacy IDs resolve to their owning course")
    func progressKeys() {
        let jazz = CourseProgressKey.make(courseID: "jazz-piano", lessonID: "shared")
        let hanon = CourseProgressKey.make(courseID: "hanon-technique", lessonID: "shared")

        #expect(jazz != hanon)
        #expect(CourseProgressKey.resolveLegacyLessonID(
            "b-step-skip",
            courses: CourseLibrary.courses
        ) == CourseProgressKey.make(courseID: "jazz-piano", lessonID: "b-step-skip"))
        #expect(CourseProgressKey.resolveLegacyLessonID(
            "hanon-01",
            courses: CourseLibrary.courses
        ) == CourseProgressKey.make(courseID: "hanon-technique", lessonID: "hanon-01"))
        let migrated = CourseProgressKey.migrate(
            ["b-step-skip", "hanon-01", jazz],
            courses: CourseLibrary.courses
        )
        #expect(CourseProgressKey.migrate(migrated, courses: CourseLibrary.courses) == migrated)
    }
}
