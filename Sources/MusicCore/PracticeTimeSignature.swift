import Foundation

public struct PracticeTimeSignature: Codable, Hashable, Identifiable, Sendable {
    public let numerator: Int
    public let denominator: Int

    public init(numerator: Int, denominator: Int) {
        precondition(numerator > 0, "A time signature needs at least one beat")
        precondition(denominator == 4 || denominator == 8, "Practice supports quarter-note and eighth-note meters")
        self.numerator = numerator
        self.denominator = denominator
    }

    public var id: String { "\(numerator)/\(denominator)" }
    public var displayName: String { id }

    public func beatDurationMilliseconds(at beatsPerMinute: Int) -> Int {
        let safeTempo = min(max(beatsPerMinute, 1), 400)
        let quarterNoteMilliseconds = 60_000.0 / Double(safeTempo)
        return Int((quarterNoteMilliseconds * 4.0 / Double(denominator)).rounded())
    }

    public func barAlignedBeatCount(forPromptCount promptCount: Int) -> Int {
        guard promptCount > 0 else { return 0 }
        return ((promptCount + numerator - 1) / numerator) * numerator
    }

    public static let common: [PracticeTimeSignature] = [
        .init(numerator: 2, denominator: 4),
        .init(numerator: 3, denominator: 4),
        .init(numerator: 4, denominator: 4),
        .init(numerator: 5, denominator: 4),
        .init(numerator: 6, denominator: 8),
        .init(numerator: 7, denominator: 8),
        .init(numerator: 9, denominator: 8),
        .init(numerator: 12, denominator: 8),
    ]

    public static let fourFour = PracticeTimeSignature(numerator: 4, denominator: 4)
}
