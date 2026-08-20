import Testing
@testable import MusicCore

@Suite("Jazz course catalog")
struct JazzCourseCatalogTests {
    @Test("Catalog has three progressive stages and 36 playable lessons")
    func catalogShape() {
        let course = JazzCourseCatalog.course

        #expect(course.stages.map(\.level) == [.beginner, .intermediate, .advanced])
        #expect(course.stages.allSatisfy { $0.modules.count == 4 })
        #expect(course.lessonCount == 36)
    }

    @Test("Lesson identifiers are unique and exercises are valid")
    func lessonIntegrity() {
        let lessons = JazzCourseCatalog.course.stages.flatMap(\.modules).flatMap(\.lessons)
        let identifiers = Set(lessons.map(\.id))

        #expect(identifiers.count == lessons.count)
        #expect(lessons.allSatisfy { !$0.pitches.isEmpty })
        #expect(lessons.allSatisfy { !$0.theory.isEmpty })
        #expect(lessons.allSatisfy { !$0.studyGuide.isEmpty })
        #expect(lessons.allSatisfy { $0.studyGuide.count > $0.theory.count })
        #expect(lessons.allSatisfy { !$0.narrationScript.isEmpty })
        #expect(lessons.allSatisfy { $0.narrationContentHash.count == 64 })
        #expect(Set(lessons.map(\.narrationContentHash)).count == lessons.count)
        #expect(lessons.allSatisfy { lesson in lesson.pitches.allSatisfy { (0...127).contains($0) } })
        #expect(lessons.allSatisfy { lesson in lesson.sourceChapters.allSatisfy { (1...23).contains($0) } })
        #expect(lessons.allSatisfy { JazzCourseCatalog.lesson(id: $0.id) == $0 })
    }

    @Test("Narration is speech friendly and content-addressed")
    func narrationContent() throws {
        let lesson = try #require(JazzCourseCatalog.lesson(id: "b-first-251"))
        let originalHash = lesson.narrationContentHash

        #expect(lesson.narrationScript.contains("two five one"))
        #expect(!lesson.narrationScript.contains("II–V–I"))

        let changedLesson = PracticeLesson(
            id: lesson.id,
            title: lesson.title,
            objective: lesson.objective + " Updated.",
            theory: lesson.theory,
            studyGuide: lesson.studyGuide,
            practiceInstruction: lesson.practiceInstruction,
            sourceChapters: lesson.sourceChapters,
            chords: lesson.prompts.map(\.pitches)
        )
        #expect(changedLesson.narrationContentHash != originalHash)
    }

    @Test("Lessons select notation from their pitch range")
    func adaptiveStaffLayout() throws {
        let trebleLesson = try #require(JazzCourseCatalog.lesson(id: "b-step-skip"))
        let bassLesson = try #require(JazzCourseCatalog.lesson(id: "b-first-251"))
        let grandStaffLesson = try #require(JazzCourseCatalog.lesson(id: "a-upper-colors"))

        #expect(trebleLesson.staffLayout == .treble)
        #expect(bassLesson.staffLayout == .bass)
        #expect(grandStaffLesson.staffLayout == .grand)
    }

    @Test("Chord prompts require the complete voicing and reject added notes")
    func chordPromptMatching() throws {
        let lesson = try #require(JazzCourseCatalog.lesson(id: "b-major-minor"))
        let prompt = try #require(lesson.prompts.first)

        #expect(lesson.isChordExercise)
        #expect(prompt.accepts(64))
        #expect(!prompt.isSatisfied(by: [60, 64]))
        #expect(prompt.isSatisfied(by: [60, 64, 67]))
        #expect(!prompt.isSatisfied(by: [60, 64, 67, 71]))
    }

    @Test("Lesson navigation follows course order and exposes the current chapter")
    func lessonNavigation() throws {
        let first = try #require(JazzCourseCatalog.navigation(forLessonID: "b-step-skip"))
        #expect(first.previousLesson == nil)
        #expect(first.nextLesson?.id == "b-major-minor")
        #expect(first.chapterNumber == 1)
        #expect(first.chapterLessons.map(\.id) == ["b-step-skip", "b-major-minor", "b-inversions"])

        let levelBoundary = try #require(JazzCourseCatalog.navigation(forLessonID: "b-transpose"))
        #expect(levelBoundary.nextLesson?.id == "i-guide-chain")

        let last = try #require(JazzCourseCatalog.navigation(forLessonID: "a-personal-etude"))
        #expect(last.previousLesson?.id == "a-four-note-cells")
        #expect(last.nextLesson == nil)
    }
}
