import Testing
@testable import MusicCore

@Suite("Hanon technique course catalog")
struct HanonCourseCatalogTests {
    @Test("Catalog exposes only the verified twenty-exercise Part I")
    func catalogShape() {
        let course = HanonCourseCatalog.course

        #expect(course.stages.map(\.title) == ["Part I"])
        #expect(course.stages.map(\.lessonCount) == [20])
        #expect(course.stages.allSatisfy { $0.modules.count == 4 })
        #expect(course.lessonCount == 20)
    }

    @Test("Lessons are unique, playable, and reference the matching source exercise")
    func lessonIntegrity() throws {
        let lessons = HanonCourseCatalog.course.lessons

        #expect(Set(lessons.map(\.id)).count == 20)
        #expect(lessons.allSatisfy { $0.staffLayout == .grand })
        #expect(lessons.allSatisfy { lesson in
            lesson.hanonExercise?.score.timeSignature == .init(numerator: 2, denominator: 4)
                && lesson.hanonExercise?.score.promptsPerMeasure == 8
                && lesson.hanonExercise?.score.repeatSection?.startPromptIndex == 0
                && lesson.hanonExercise?.score.repeatSection?.endPromptIndex == lesson.promptCount - 2
                && lesson.prompts.dropLast().allSatisfy { $0.noteValue == .sixteenth }
                && lesson.prompts.last?.noteValue == .half
        })
        #expect(lessons.map(\.promptCount) == [
            233, 225, 225, 225, 225, 225, 225, 225, 225, 225,
            225, 233, 225, 225, 225, 225, 217, 225, 225, 241,
        ])
        #expect(lessons.dropLast().allSatisfy { $0.prompts.allSatisfy { $0.pitches.count == 2 } })
        #expect(lessons.last?.prompts.dropLast().allSatisfy { $0.pitches.count == 2 } == true)
        #expect(lessons.last?.prompts.last?.pitches == [36, 48, 52, 60])
        #expect(lessons.allSatisfy { lesson in
            lesson.prompts.allSatisfy { prompt in
                prompt.fingerings.count == prompt.pitches.count
                    && Set(prompt.fingerings.map(\.hand)) == [.left, .right]
                    && prompt.fingerings.allSatisfy { (1...5).contains($0.finger) }
            }
        })
        #expect(lessons.allSatisfy { !$0.theory.isEmpty && $0.studyGuide.count > $0.theory.count })
        #expect(lessons.allSatisfy { $0.guidance?.practicePlan.count == 5 })
        #expect(lessons.allSatisfy { $0.pitches.allSatisfy { (0...127).contains($0) } })

        for (index, lesson) in lessons.enumerated() {
            let exerciseNumber = index + 1
            #expect(lesson.sourceChapters == [exerciseNumber])
            #expect(lesson.chapterLabel == "Hanon Part I \(exerciseNumber)")
            #expect(HanonCourseCatalog.lesson(id: lesson.id) == lesson)
        }

        let first = try #require(HanonCourseCatalog.navigation(forLessonID: "hanon-01"))
        #expect(first.stageTitle == "Part I")
        #expect(first.previousLesson == nil)
        #expect(first.nextLesson?.id == "hanon-02")

        let last = try #require(HanonCourseCatalog.navigation(forLessonID: "hanon-20"))
        #expect(last.nextLesson == nil)
    }

    @Test("Exercise 1 uses Hanon's written parallel route and separate hand fingering")
    func exerciseOneOpening() throws {
        let lesson = try #require(HanonCourseCatalog.lesson(id: "hanon-01"))
        #expect(lesson.prompts.prefix(8).map(\.pitches) == [
            [36, 48], [40, 52], [41, 53], [43, 55],
            [45, 57], [43, 55], [41, 53], [40, 52],
        ])
        #expect(lesson.prompts.prefix(8).map { $0.fingerings.map(\.finger) } == [
            [5, 1], [4, 2], [3, 3], [2, 4],
            [1, 5], [2, 4], [3, 3], [4, 2],
        ])

        #expect(lesson.prompts[112].pitches == [67, 79])
        #expect(lesson.prompts[112].fingerings.map(\.finger) == [1, 5])
        #expect(lesson.prompts.last?.pitches == [36, 48])
        #expect(lesson.playbackPromptIndices.count == 465)
        #expect(lesson.playbackPromptIndices[231] == 231)
        #expect(lesson.playbackPromptIndices[232] == 0)
        #expect(lesson.playbackPromptIndices.last == 232)
        #expect(lesson.playbackDurationInQuarterNotes == 118)
    }

    @Test("Every Part I pitch group matches the machine-readable reference")
    func completePitchRoutes() {
        let expectedChecksums: [UInt64] = [
            5_635_653_755_583_756_421, 4_296_487_634_981_309_945,
            12_665_384_831_369_286_409, 11_989_724_139_395_291_913,
            14_236_349_859_722_231_545, 977_366_989_377_704_131,
            18_134_087_176_341_503_113, 1_389_360_128_104_106_889,
            10_959_463_028_230_985_705, 13_569_931_457_229_123_401,
            3_837_359_029_776_334_153, 1_422_339_950_984_596_937,
            18_369_360_237_615_631_129, 11_828_872_847_003_347_625,
            8_653_807_281_567_513_989, 105_515_455_526_971_561,
            1_647_499_188_239_027_997, 9_580_911_292_447_270_729,
            8_037_550_225_540_240_601, 5_446_921_980_834_548_055,
        ]

        let actualChecksums = HanonCourseCatalog.course.lessons.map { lesson in
            lesson.prompts.reduce(UInt64(14_695_981_039_346_656_037)) { partial, prompt in
                ([UInt8(prompt.pitches.count)] + prompt.pitches).reduce(partial) { checksum, byte in
                    (checksum ^ UInt64(byte)) &* 1_099_511_628_211
                }
            }
        }
        #expect(actualChecksums == expectedChecksums)
    }

    @Test("Part I complete fingering routes match the independent fixtures")
    func completeFingeringRoutes() {
        let expectedChecksums: [UInt64] = [
            13_058_096_142_919_180_150, 12_921_236_865_622_692_590,
            1_189_138_824_941_983_854, 2_070_462_115_653_268_486,
            17_679_259_722_304_236_954, 14_001_072_844_803_415_716,
            4_558_990_182_612_658_906, 5_537_770_641_689_547_314,
            13_309_296_434_935_584_578, 12_211_808_250_045_536_138,
            4_362_007_705_592_377_862, 2_233_682_236_278_095_794,
            2_168_407_248_875_243_154, 7_704_541_159_848_585_578,
            13_055_585_527_610_679_630, 17_717_257_697_580_222_106,
            2_852_579_794_692_152_921, 9_823_827_457_833_630_610,
            8_165_634_217_314_679_322, 6_137_293_485_966_319_737,
        ]
        let actual = HanonCourseCatalog.course.lessons.map { lesson in
            lesson.prompts.reduce(UInt64(14_695_981_039_346_656_037)) { partial, prompt in
                prompt.fingerings.reduce(mix(partial, UInt8(prompt.fingerings.count))) { checksum, fingering in
                    let withPitch = mix(checksum, fingering.pitch)
                    let withHand = mix(withPitch, fingering.hand == .left ? 0 : 1)
                    return mix(withHand, fingering.finger)
                }
            }
        }
        #expect(actual == expectedChecksums)
    }

    @Test("Measure ranges and isolated hands preserve the written prompts")
    func focusedPracticeSelection() throws {
        let lesson = try #require(HanonCourseCatalog.lesson(id: "hanon-01"))
        #expect(lesson.scoreMeasureCount == 30)
        #expect(lesson.promptIndices(fromMeasure: 3, throughMeasure: 4) == Array(16..<32))
        #expect(lesson.promptIndices(fromMeasure: 30, throughMeasure: 30) == [232])

        let prompt = lesson.prompts[0]
        #expect(prompt.filtered(for: .right).pitches == [48])
        #expect(prompt.filtered(for: .right).fingerings.map(\.finger) == [1])
        #expect(prompt.filtered(for: .left).pitches == [36])
        #expect(prompt.filtered(for: .left).fingerings.map(\.finger) == [5])
    }

    private func mix(_ checksum: UInt64, _ byte: UInt8) -> UInt64 {
        (checksum ^ UInt64(byte)) &* 1_099_511_628_211
    }
}
