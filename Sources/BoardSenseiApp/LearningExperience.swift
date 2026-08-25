import Foundation
import MusicCore

enum LearningGoal: String, CaseIterable, Identifiable {
    case jazzFluency = "Jazz fluency"
    case harmony = "Harmony"
    case sightReading = "Sight-reading"
    case freePractice = "Free practice"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .jazzFluency: "music.quarternote.3"
        case .harmony: "rectangle.stack.fill"
        case .sightReading: "music.note.list"
        case .freePractice: "pianokeys"
        }
    }

    var detail: String {
        switch self {
        case .jazzFluency: "Build vocabulary, voice leading, and improvisational confidence."
        case .harmony: "Understand chord color and make voicings feel natural under your hands."
        case .sightReading: "Read the grand staff more quickly and respond without guessing."
        case .freePractice: "Use the piano, MIDI tools, and lessons at your own pace."
        }
    }
}

enum LearnerExperience: String, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: Self { self }

    var detail: String {
        switch self {
        case .beginner: "I am still building note, interval, and chord confidence."
        case .intermediate: "I know common chords and want stronger musical vocabulary."
        case .advanced: "I want demanding voicings, movement, and improvisation practice."
        }
    }
}

enum LearningAchievement: String, Codable, CaseIterable, Identifiable {
    case firstLesson
    case fiveLessons
    case firstMastery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstLesson: "First step"
        case .fiveLessons: "Practice takes shape"
        case .firstMastery: "First mastery"
        }
    }

    var detail: String {
        switch self {
        case .firstLesson: "Completed your first Board Sensei lesson."
        case .fiveLessons: "Practised five different lessons."
        case .firstMastery: "Mastered a lesson through accurate repetition."
        }
    }

    var symbol: String {
        switch self {
        case .firstLesson: "flag.checkered"
        case .fiveLessons: "music.note.list"
        case .firstMastery: "seal.fill"
        }
    }
}

struct LessonCompletionResult: Identifiable, Equatable {
    let id = UUID()
    let lessonID: String
    let lessonTitle: String
    let accuracy: Double
    let mistakes: Int
    let mastery: LessonMastery
    let masteryAdvanced: Bool
    let personalBest: Bool
    let newAchievements: [LearningAchievement]
}

enum LearningExperienceStore {
    private static let legacyRecordsKey = "lessonProgressRecordsV1"
    private static let recordsKey = "courseLessonProgressRecordsV2"
    private static let achievementsKey = "learningAchievementsV1"

    static func loadRecords(defaults: UserDefaults = .standard) -> [String: LessonProgressRecord] {
        guard let data = defaults.data(forKey: recordsKey),
              let records = try? JSONDecoder().decode([String: LessonProgressRecord].self, from: data) else {
            return [:]
        }
        return records
    }

    static func saveRecords(_ records: [String: LessonProgressRecord], defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: recordsKey)
    }

    static func loadLegacyRecords(defaults: UserDefaults = .standard) -> [String: LessonProgressRecord] {
        guard let data = defaults.data(forKey: legacyRecordsKey),
              let records = try? JSONDecoder().decode([String: LessonProgressRecord].self, from: data) else {
            return [:]
        }
        return records
    }

    static func clearLegacyRecords(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: legacyRecordsKey)
    }

    static func loadAchievements(defaults: UserDefaults = .standard) -> Set<LearningAchievement> {
        let rawValues = defaults.stringArray(forKey: achievementsKey) ?? []
        return Set(rawValues.compactMap(LearningAchievement.init(rawValue:)))
    }

    static func saveAchievements(_ achievements: Set<LearningAchievement>, defaults: UserDefaults = .standard) {
        defaults.set(achievements.map(\.rawValue).sorted(), forKey: achievementsKey)
    }
}
