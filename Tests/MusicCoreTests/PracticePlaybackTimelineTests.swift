import Testing
@testable import MusicCore

@Suite("Practice playback timeline")
struct PracticePlaybackTimelineTests {
    @Test("Events retain their prompt identity across playback")
    func resolvesActiveEvent() {
        let timeline = makeTimeline()

        #expect(timeline.event(atQuarterNote: 0, looping: false)?.sourcePromptIndex == 4)
        #expect(timeline.event(atQuarterNote: 0.99, looping: false)?.pitches == [60, 64, 67])
        #expect(timeline.event(atQuarterNote: 1, looping: false)?.sourcePromptIndex == 9)
        #expect(timeline.event(atQuarterNote: 2, looping: false) == nil)
    }

    @Test("Loop length is padded to the next complete bar")
    func padsLoopToBar() {
        let timeline = makeTimeline()

        #expect(timeline.durationQuarterNotes == 2)
        #expect(timeline.loopDurationQuarterNotes == 4)
        #expect(timeline.event(atQuarterNote: 3.5, looping: true) == nil)
    }

    @Test("Loop playback wraps its visual prompt to the first event")
    func wrapsVisualPrompt() {
        let timeline = makeTimeline()

        #expect(timeline.event(atQuarterNote: 4, looping: true)?.sourcePromptIndex == 4)
        #expect(timeline.event(atQuarterNote: 5.25, looping: true)?.sourcePromptIndex == 9)
        #expect(timeline.event(atQuarterNote: 4, looping: false) == nil)
    }

    @Test("Compound meter aligns loops using its written bar length")
    func alignsCompoundMeter() {
        let timeline = PracticePlaybackTimeline(
            events: [
                PracticePlaybackEvent(
                    sourcePromptIndex: 0,
                    pitches: [60],
                    startQuarterNote: 0,
                    stepDurationQuarterNotes: 2,
                    audibleDurationQuarterNotes: 1.5
                )
            ],
            timeSignature: PracticeTimeSignature(numerator: 6, denominator: 8)
        )

        #expect(timeline.durationQuarterNotes == 2)
        #expect(timeline.loopDurationQuarterNotes == 3)
    }

    @Test("One clock maps tempo to matching audio samples and visual position")
    func keepsRenderAndVisualTimeAligned() {
        let clock = PracticePlaybackClock(
            tempoBeatsPerMinute: 120,
            sampleRate: 48_000
        )

        #expect(clock.framesPerQuarterNote == 24_000)
        #expect(clock.sampleOffset(forQuarterNotes: 3.5) == 84_000)
        #expect(clock.quarterNotes(forElapsedSeconds: 1.75) == 3.5)
    }

    private func makeTimeline() -> PracticePlaybackTimeline {
        PracticePlaybackTimeline(
            events: [
                PracticePlaybackEvent(
                    sourcePromptIndex: 4,
                    pitches: [60, 64, 67],
                    startQuarterNote: 0,
                    stepDurationQuarterNotes: 1,
                    audibleDurationQuarterNotes: 0.76
                ),
                PracticePlaybackEvent(
                    sourcePromptIndex: 9,
                    pitches: [62],
                    startQuarterNote: 1,
                    stepDurationQuarterNotes: 1,
                    audibleDurationQuarterNotes: 0.76
                ),
            ],
            timeSignature: .fourFour
        )
    }
}
