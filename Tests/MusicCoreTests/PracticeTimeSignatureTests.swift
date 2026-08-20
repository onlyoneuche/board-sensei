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
}
