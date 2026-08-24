import Foundation

/// Verified Part I of Charles-Louis Hanon's public-domain exercises.
/// Every displayed note is stored in the course; no external score is required.
public enum HanonCourseCatalog {
    public static let course = PracticeCourse(
        id: "hanon-technique",
        title: "Hanon Technique Course",
        summary: "Twenty complete Part I exercises with the original pitch routes and both-hand fingering inside every lesson.",
        stages: [partOne]
    )

    public static let partOne = CourseStage(
        level: .beginner,
        title: "Part I",
        summary: "Build evenness and independence with verified notes and fingerings for Exercises 1–20.",
        modules: [
            module(1...5, id: "hanon-foundation-1", title: "Balanced Five-Finger Motion"),
            module(6...10, id: "hanon-foundation-2", title: "Inner-Finger Independence"),
            module(11...15, id: "hanon-foundation-3", title: "Outer-Finger Control"),
            module(16...20, id: "hanon-foundation-4", title: "Connected Agility"),
        ]
    )

    public static var firstLesson: PracticeLesson { partOne.modules[0].lessons[0] }

    public static func lesson(id: String) -> PracticeLesson? { course.lesson(id: id) }

    public static func navigation(forLessonID id: String) -> CourseLessonNavigation? {
        course.navigation(forLessonID: id)
    }

    private struct StudyPattern {
        let ascendingOffsets: [Int]
        let descendingOffsets: [Int]
        let rightAscending: [UInt8]
        let leftAscending: [UInt8]
        let rightDescending: [UInt8]
        let leftDescending: [UInt8]
    }

    private static func module(_ range: ClosedRange<Int>, id: String, title: String) -> CourseModule {
        CourseModule(
            id: id,
            title: title,
            summary: "Develop even attacks and calm coordination in both hands.",
            lessons: range.map(lesson)
        )
    }

    private static func lesson(number: Int) -> PracticeLesson {
        let prompts = verifiedPrompts(number: number)
        let noteValues = Array(repeating: PracticeNoteValue.sixteenth, count: prompts.count - 1) + [.half]
        return PracticeLesson(
            id: String(format: "hanon-%02d", number),
            title: "Exercise \(number): Coordinated Independence",
            objective: "Play Hanon Exercise \(number) with exact notes, synchronized hands, and the displayed fingering.",
            theory: "Finger independence is the ability to shape one attack without unnecessary movement in the neighboring fingers or wrist.",
            studyGuide: "This lesson contains the complete Part I pitch route and a finger number for every left- and right-hand note. Finger 1 is the thumb and finger 5 is the little finger. Read the full route before playing, keep the wrist quiet but free, and preserve one pulse through each position change.",
            practiceInstruction: "Play the complete displayed two-hand exercise evenly. Follow every written finger number; no outside score is required.",
            sourceChapters: [number],
            sourceName: "Hanon Part I",
            guidance: guidance(number: number),
            fingeredPrompts: prompts,
            noteValues: noteValues,
            scoreMetadata: PracticeScoreMetadata(
                timeSignature: .init(numerator: 2, denominator: 4),
                promptsPerMeasure: 8,
                measuresPerSystem: 5,
                repeatSection: .init(startPromptIndex: 0, endPromptIndex: prompts.count - 2)
            ),
            estimatedMinutes: 6
        )
    }

    private static func guidance(number: Int) -> PracticeLessonGuidance {
        PracticeLessonGuidance(
            whyItMatters: "Exercise \(number) isolates a five-finger coordination route so uneven attacks and excess movement are easy to hear.",
            practicePlan: [
                "Set a tempo that lets both hands land together without stiffness.",
                "Read the complete in-app route once before playing; finger 1 is the thumb and finger 5 is the little finger.",
                "Use Hear full exercise and follow the two-hand route from beginning to end.",
                "Play each displayed note group with the marked fingers and equal tone.",
                "Repeat only after the complete route is accurate, then increase by five beats per minute.",
            ],
            listeningFocus: "Listen for exact alignment, equal tone from every finger, and a pulse that stays stable at each position shift.",
            successCriterion: "Pass condition: play every displayed pitch group with no missing or extra notes."
        )
    }

    private static func verifiedPrompts(number: Int) -> [[PracticeFingering]] {
        guard let pattern = patterns[number] else {
            preconditionFailure("Missing verified Hanon Part I data for Exercise \(number)")
        }

        let ascendingBases = bases(number: number, descending: false)
        let descendingBases = bases(number: number, descending: true)
        var lowerPitches = ascendingBases.flatMap { base in
            pattern.ascendingOffsets.map { diatonicPitch(from: base, steps: $0) }
        } + descendingBases.flatMap { base in
            pattern.descendingOffsets.map { diatonicPitch(from: base, steps: $0) }
        } + [36]

        if number == 12 {
            lowerPitches = exercise12LowerPitches
        } else if let overrides = lowerPitchOverrides[number] {
            for (index, pitch) in overrides { lowerPitches[index] = pitch }
        }

        let ascendingCount = ascendingBases.count * 8
        return lowerPitches.enumerated().map { index, lowerPitch in
            if index == lowerPitches.count - 1 && number == 20 {
                return [
                .init(pitch: 36, hand: .left, finger: 5),
                .init(pitch: 48, hand: .left, finger: 1),
                .init(pitch: 52, hand: .right, finger: 1),
                .init(pitch: 60, hand: .right, finger: 5),
                ]
            }
            if index == lowerPitches.count - 1 {
                return fingeredPair(lowerPitch: lowerPitch, leftFinger: 5, rightFinger: 1)
            }
            let position = index % 8
            let descending = index >= ascendingCount
            return fingeredPair(
                lowerPitch: lowerPitch,
                leftFinger: descending ? pattern.leftDescending[position] : pattern.leftAscending[position],
                rightFinger: descending ? pattern.rightDescending[position] : pattern.rightAscending[position]
            )
        }
    }

    private static func fingeredPair(lowerPitch: Int, leftFinger: UInt8, rightFinger: UInt8) -> [PracticeFingering] {
        precondition((0...115).contains(lowerPitch))
        let lower = UInt8(lowerPitch)
        return [
            .init(pitch: lower, hand: .left, finger: leftFinger),
            .init(pitch: lower + 12, hand: .right, finger: rightFinger),
        ]
    }

    private static func diatonicPitch(from base: Int, steps: Int) -> Int {
        let pitchClasses = [0, 2, 4, 5, 7, 9, 11]
        guard let scaleDegree = pitchClasses.firstIndex(of: base % 12) else {
            preconditionFailure("Hanon Part I route contains a non-diatonic base pitch")
        }
        let absoluteDegree = (base / 12) * 7 + scaleDegree + steps
        let octave = absoluteDegree / 7
        let degree = absoluteDegree % 7
        return octave * 12 + pitchClasses[degree]
    }

    private static func bases(number: Int, descending: Bool) -> [Int] {
        if descending {
            switch number {
            case 1: return [67,65,64,62,60,59,57,55,53,52,50,48,47,45,43]
            case 5: return [60,59,57,55,53,52,50,48,47,45,43,41,40,38]
            case 12: return [59,57,55,53,52,50,48,47,45,43,41,40,38,36,36]
            case 13: return [64,62,60,59,57,55,53,52,50,48,47,45,43,41]
            case 17: return [67,65,64,62,60,59,57,55,53,52,50,48,47]
            case 20: return [76,74,72,71,69,67,65,64,62,60,59,57,55,53,52]
            default: return [67,65,64,62,60,59,57,55,53,52,50,48,47,45]
            }
        }
        switch number {
        case 12: return [43,47,48,50,52,53,55,57,59,60,62,64,65,67]
        case 13: return [40,41,43,45,47,48,50,52,53,55,57,59,60,62]
        case 20: return [40,41,43,45,47,48,50,52,53,55,57,59,60,62,64]
        default: return [36,38,40,41,43,45,47,48,50,52,53,55,57,59]
        }
    }

    private static let lowerPitchOverrides: [Int: [Int: Int]] = [
        6: [111: 60, 223: 40],
        9: [222: 38, 223: 40],
        15: [111: 65, 223: 38],
        17: [111: 64, 215: 38],
        20: [119: 67, 239: 41],
    ]

    private static let exercise12LowerPitches: [Int] = {
        let encoded = "KyQoJiQmKCQvJikoJigpJjAoKykoKSsoMiktKykrLSk0Ky8tKy0vKzUtMC8tLzAtNy8yMC8wMi85MDQyMDI0MDsyNTQyNDUyPDQ3NTQ1NzQ+NTk3NTc5NUA3Ozk3OTs3QTk8Ozk7PDlDOz48Ozw+QDtDQEFDQUBDOUE+QEFAPkE3QDw+QD48QDU+Ozw+PDs+NDw5Ozw7OTwyOzc5Ozk3OzA5NTc5NzU5Lzc0NTc1NDctNTI0NTQyNSs0MDI0MjA0KTIvMDIwLzIoMC0vMC8tMCYvKy0vLSsvJC0pKy0rKS0kKygpKykoKSQ="
        guard let data = Data(base64Encoded: encoded) else {
            preconditionFailure("Invalid verified pitch data for Hanon Exercise 12")
        }
        return data.map(Int.init)
    }()

    private static let patterns: [Int: StudyPattern] = [
        1: p([0,2,3,4,5,4,3,2], [0,-2,-3,-4,-5,-4,-3,-2], [1,2,3,4,5,4,3,2], [5,4,3,2,1,2,3,4], [5,4,3,2,1,2,3,4], [1,2,3,4,5,4,3,2]),
        2: p([0,2,5,4,3,4,3,2], [0,-3,-5,-4,-3,-4,-3,-2], [1,2,5,4,3,4,3,2], [5,3,1,2,3,2,3,4], [5,2,1,2,3,2,3,4], [1,3,5,4,3,4,3,2]),
        3: p([0,2,5,4,3,2,3,4], [0,-3,-5,-4,-3,-2,-3,-4], [1,2,5,4,3,2,3,4], [5,3,1,2,3,4,3,2], [5,2,1,2,3,4,3,2], [1,3,5,4,3,2,3,4]),
        4: p([0,1,0,2,5,4,3,2], [0,-1,0,-3,-5,-4,-3,-2], [1,2,1,2,5,4,3,2], [5,4,5,3,1,2,3,4], [5,4,5,2,1,2,3,4], [1,2,1,3,5,4,3,2]),
        5: p([0,5,4,5,3,4,2,3], [0,1,0,2,1,3,2,4], [1,5,4,5,3,4,2,3], [5,1,2,1,3,2,4,3], [1,2,1,3,2,4,3,5], [5,4,5,3,4,2,3,1]),
        6: p([0,5,4,5,3,5,2,5], [0,-5,-4,-5,-3,-5,-2,-5], [1,5,4,5,3,5,2,5], [5,1,2,1,3,1,4,1], [5,1,2,1,3,1,4,1], [1,5,4,5,3,5,2,5]),
        7: p([0,2,1,3,2,4,3,2], [0,-2,-1,-3,-2,-4,-3,-2], [1,3,2,4,3,5,4,3], [5,3,4,2,3,1,3,4], [5,3,4,2,3,1,3,4], [1,3,2,4,3,5,4,3]),
        8: p([0,2,4,5,3,4,2,3], [0,-2,-4,-5,-3,-4,-2,-3], [1,2,4,5,3,4,2,3], [5,4,2,1,3,2,4,3], [5,4,2,1,3,2,4,3], [1,2,4,5,3,4,2,3]),
        9: p([0,2,3,2,4,3,5,4], [0,-2,-3,-2,-4,-3,-5,-4], [1,2,3,2,4,3,5,4], [5,4,3,4,2,3,1,2], [5,4,3,4,2,3,1,2], [1,2,3,2,4,3,5,4]),
        10: p([0,5,4,3,2,3,2,3], [0,-5,-4,-3,-2,-3,-2,-3], [1,5,4,3,2,3,2,3], [5,1,2,3,4,3,4,3], [5,1,2,3,4,3,4,3], [1,5,4,3,2,3,2,3]),
        11: p([0,2,5,4,5,4,3,4], [0,-3,-5,-4,-5,-4,-3,-4], [1,2,5,4,5,4,3,4], [5,3,1,2,1,2,3,2], [5,2,1,2,1,2,3,2], [1,3,5,4,5,4,3,4]),
        12: p([0,-4,-2,-3,-4,-3,-2,-4], [0,5,3,4,5,4,3,5], [5,1,3,2,1,2,3,1], [1,5,3,4,5,4,3,5], [1,5,3,4,5,4,3,5], [5,1,3,2,1,2,3,1]),
        13: p([0,-2,1,-1,2,0,1,2], [0,2,-1,1,0,-2,-1,0], [3,1,4,2,5,3,4,5], [3,5,2,4,1,3,2,1], [3,5,2,4,3,1,3,4], [3,1,4,2,3,5,3,2]),
        14: p([0,1,3,2,3,2,4,3], [0,-1,-3,-2,-3,-2,-4,-3], [1,2,4,3,4,3,5,4], [5,4,2,3,2,3,1,3], [5,4,2,3,2,3,1,3], [1,2,4,3,4,3,5,4]),
        15: p([0,2,1,3,2,4,3,5], [0,-2,-1,-3,-2,-4,-3,-5], [1,2,1,3,2,4,3,5], [5,3,4,2,3,1,2,1], [5,3,4,2,3,1,2,1], [1,2,1,3,2,4,3,5]),
        16: p([0,2,1,2,5,4,3,4], [0,-3,-2,-3,-5,-4,-3,-4], [1,3,2,3,5,4,3,4], [5,3,4,3,1,2,3,2], [5,2,3,2,1,2,3,2], [1,3,2,3,5,4,3,4]),
        17: p([0,2,5,4,6,5,4,5], [0,-3,-5,-4,-6,-5,-4,-6], [1,2,4,3,5,4,3,4], [5,4,2,3,1,2,3,2], [5,3,2,3,1,2,3,1], [1,2,4,3,5,4,3,5]),
        18: p([0,1,3,2,4,3,1,2], [0,-1,-3,-2,-4,-3,-1,-2], [1,2,4,3,5,4,2,3], [5,4,2,3,1,2,4,3], [5,4,2,3,1,2,4,3], [1,2,4,3,5,4,2,3]),
        19: p([0,5,3,4,5,3,2,4], [0,-5,-3,-4,-5,-3,-2,-4], [1,5,3,4,5,3,2,4], [5,1,3,2,1,3,4,2], [5,1,3,2,1,3,4,2], [1,5,3,4,5,3,2,4]),
        20: p([0,2,5,7,5,4,5,3], [0,-2,-5,-7,-5,-6,-5,-7], [1,2,4,5,4,3,4,2], [5,4,2,1,2,3,2,4], [5,4,2,1,3,2,3,1], [1,2,4,5,3,4,3,5]),
    ]

    private static func p(
        _ ascendingOffsets: [Int], _ descendingOffsets: [Int],
        _ rightAscending: [UInt8], _ leftAscending: [UInt8],
        _ rightDescending: [UInt8], _ leftDescending: [UInt8]
    ) -> StudyPattern {
        StudyPattern(
            ascendingOffsets: ascendingOffsets,
            descendingOffsets: descendingOffsets,
            rightAscending: rightAscending,
            leftAscending: leftAscending,
            rightDescending: rightDescending,
            leftDescending: leftDescending
        )
    }
}
