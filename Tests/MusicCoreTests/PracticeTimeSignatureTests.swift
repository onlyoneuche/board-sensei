import Testing
@testable import MusicCore

@Suite("Practice time signatures")
struct PracticeTimeSignatureTests {
    @Test("Beat duration follows tempo and denominator")
    func beatDuration() {
        #expect(PracticeTimeSignature.fourFour.beatDurationMilliseconds(at: 120) == 500)
        #expect(
            PracticeTimeSignature(numerator: 6, denominator: 8)
                .beatDurationMilliseconds(at: 120) == 250
        )
    }

    @Test("Common signatures have stable unique identifiers")
    func commonSignatureIdentifiers() {
        let signatures = PracticeTimeSignature.common
        #expect(Set(signatures.map(\.id)).count == signatures.count)
        #expect(signatures.contains(.fourFour))
    }

    @Test("Exercise loops end on a complete measure")
    func barAlignedLoopLength() {
        #expect(PracticeTimeSignature.fourFour.barAlignedBeatCount(forPromptCount: 6) == 8)
        #expect(PracticeTimeSignature(numerator: 3, denominator: 4).barAlignedBeatCount(forPromptCount: 6) == 6)
        #expect(PracticeTimeSignature.fourFour.barAlignedBeatCount(forPromptCount: 0) == 0)
    }
}
