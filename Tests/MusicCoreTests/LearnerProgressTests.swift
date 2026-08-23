import Testing
@testable import MusicCore

@Suite("Learner progress")
struct LearnerProgressTests {
    @Test("Mastery grows through accurate repetition")
    func masteryProgression() {
        var record = LessonProgressRecord()
        #expect(record.mastery == .introduced)

        record.registerStart()
        let firstAccuracy = record.registerCompletion(promptCount: 8, mistakes: 2)
        #expect(firstAccuracy == 0.8)
        #expect(record.mastery == .practiced)

        record.registerCompletion(promptCount: 8, mistakes: 0)
        record.registerCompletion(promptCount: 8, mistakes: 1)
        #expect(record.mastery == .mastered)
        #expect(record.bestAccuracy == 1)
    }

    @Test("Completion accuracy is safe for malformed counts")
    func safeAccuracy() {
        var record = LessonProgressRecord()
        #expect(record.registerCompletion(promptCount: 0, mistakes: -4) == 1)
        #expect(record.completions == 1)
    }
}
