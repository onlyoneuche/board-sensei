import Foundation

public enum LessonMastery: String, Codable, CaseIterable, Sendable {
    case introduced
    case practiced
    case mastered

    public var title: String {
        switch self {
        case .introduced: "Introduced"
        case .practiced: "Practised"
        case .mastered: "Mastered"
        }
    }
}

public struct LessonProgressRecord: Codable, Equatable, Sendable {
    public private(set) var practiceStarts: Int
    public private(set) var completions: Int
    public private(set) var bestAccuracy: Double
    public private(set) var lastAccuracy: Double?

    public init(
        practiceStarts: Int = 0,
        completions: Int = 0,
        bestAccuracy: Double = 0,
        lastAccuracy: Double? = nil
    ) {
        self.practiceStarts = max(0, practiceStarts)
        self.completions = max(0, completions)
        self.bestAccuracy = min(max(bestAccuracy, 0), 1)
        self.lastAccuracy = lastAccuracy.map { min(max($0, 0), 1) }
    }

    public var mastery: LessonMastery {
        if completions >= 3, bestAccuracy >= 0.9 { return .mastered }
        if completions > 0 { return .practiced }
        return .introduced
    }

    public mutating func registerStart() {
        practiceStarts += 1
    }

    @discardableResult
    public mutating func registerCompletion(promptCount: Int, mistakes: Int) -> Double {
        let safePrompts = max(1, promptCount)
        let safeMistakes = max(0, mistakes)
        let accuracy = Double(safePrompts) / Double(safePrompts + safeMistakes)
        completions += 1
        lastAccuracy = accuracy
        bestAccuracy = max(bestAccuracy, accuracy)
        return accuracy
    }
}
