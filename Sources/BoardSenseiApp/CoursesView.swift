import MusicCore
import SwiftUI

struct CoursesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Practice Courses")
                            .font(.system(size: 32, weight: .semibold))
                        Spacer()
                        if model.practiceStreaksEnabled, model.practiceDayStreak > 0 {
                            Label("\(model.practiceDayStreak)-day practice rhythm", systemImage: "flame.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 22)], spacing: 22) {
                        NavigationLink {
                            CourseDetailView(
                                course: JazzCourseCatalog.course,
                                symbol: "music.quarternote.3",
                                usesLearnerStartingPoint: true
                            )
                        } label: {
                            CourseCatalogCard(
                                title: "Jazz",
                                subtitle: "Harmony, voicings, improvisation, and comping",
                                symbol: "music.quarternote.3",
                                color: AppTheme.accent,
                                progress: progress(for: JazzCourseCatalog.course),
                                detail: "36 lessons · 3 levels",
                                isAvailable: true
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            CourseDetailView(
                                course: HanonCourseCatalog.course,
                                symbol: "figure.strengthtraining.traditional",
                                usesLearnerStartingPoint: false
                            )
                        } label: {
                            CourseCatalogCard(
                                title: "Hanon Technique",
                                subtitle: "Finger independence, scales, arpeggios, trills, and octaves",
                                symbol: "figure.strengthtraining.traditional",
                                color: AppTheme.accent,
                                progress: progress(for: HanonCourseCatalog.course),
                                detail: "20 verified lessons · Part I",
                                isAvailable: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(32)
                .frame(maxWidth: 1_180)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
            .navigationTitle("Courses")
        }
    }

    private func progress(for course: PracticeCourse) -> Double {
        guard course.lessonCount > 0 else { return 0 }
        let completed = course.lessons
            .filter(model.isCompleted)
            .count
        return Double(completed) / Double(course.lessonCount)
    }
}

private struct CourseCatalogCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    let progress: Double
    let detail: String
    let isAvailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(color, in: RoundedRectangle(cornerRadius: 16))
                Spacer()
                if isAvailable {
                    Image(systemName: "arrow.up.right")
                        .font(.headline)
                        .foregroundStyle(color)
                        .padding(10)
                        .background(color.opacity(0.12), in: Circle())
                } else {
                    Text("COMING SOON")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 26, weight: .semibold))
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if isAvailable {
                ProgressView(value: progress).tint(color)
                HStack {
                    Text(detail)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            } else {
                Label(detail, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(isAvailable ? color.opacity(0.38) : Color.secondary.opacity(0.2), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .opacity(isAvailable ? 1 : 0.72)
        .accessibilityElement(children: .combine)
    }
}

private struct CourseDetailView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedLevel: CourseLevel = .beginner
    @State private var expandedModuleIDs: Set<String> = []
    @State private var appliedLearnerStartingPoint = false

    let course: PracticeCourse
    let symbol: String
    let usesLearnerStartingPoint: Bool

    private var stage: CourseStage {
        course.stages.first { $0.level == selectedLevel } ?? course.stages[0]
    }

    private var completedCount: Int {
        stage.modules.flatMap(\.lessons).filter(model.isCompleted).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                courseHeader
                learningSummary
                stagePicker
                stageProgress
                ForEach(Array(stage.modules.enumerated()), id: \.element.id) { index, module in
                    moduleDisclosure(module, number: index + 1)
                }
            }
            .padding(28)
            .frame(maxWidth: 1_100)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        .navigationTitle(course.title)
        .onAppear {
            guard !appliedLearnerStartingPoint else { return }
            selectedLevel = usesLearnerStartingPoint ? preferredCourseLevel : (course.stages.first?.level ?? .beginner)
            expandedModuleIDs = Set(stage.modules.first.map { [$0.id] } ?? [])
            appliedLearnerStartingPoint = true
        }
        .onChange(of: selectedLevel) { _, _ in
            expandedModuleIDs = Set(stage.modules.first.map { [$0.id] } ?? [])
        }
    }

    private var courseHeader: some View {
        HStack(alignment: .top, spacing: 22) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(levelColor, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 8) {
                Text(course.title)
                    .font(.system(size: 32, weight: .semibold))
                Label("\(course.lessonCount) playable lessons", systemImage: "pianokeys")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(levelColor)
            }
            Spacer(minLength: 0)
        }
        .help(course.summary)
    }

    private var stagePicker: some View {
        Picker("Course level", selection: $selectedLevel) {
            ForEach(course.stages) { stage in
                Text(stage.title).tag(stage.level)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("\(course.title) part")
    }

    private var stageProgress: some View {
        HStack(spacing: 12) {
            ProgressView(value: Double(completedCount), total: Double(stage.lessonCount))
                .tint(levelColor)
            Spacer()
            Text("\(completedCount)/\(stage.lessonCount) complete · \(masteredCount) mastered")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .help(stage.summary)
    }

    private var masteredCount: Int {
        stage.modules
            .flatMap(\.lessons)
            .filter { model.mastery(for: $0) == .mastered }
            .count
    }

    private var learningSummary: some View {
        HStack(spacing: 18) {
            summaryMetric("Practised", value: "\(model.completedLessonIDs.count)", symbol: "checkmark.circle.fill")
            Divider().frame(height: 38)
            summaryMetric(
                "Mastered",
                value: "\(model.lessonRecords.values.filter { $0.mastery == .mastered }.count)",
                symbol: "seal.fill"
            )
            Divider().frame(height: 38)
            summaryMetric("Milestones", value: "\(model.unlockedAchievements.count)", symbol: "flag.checkered")
            Spacer()
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
    }

    private func summaryMetric(_ title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol).foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.headline.monospacedDigit())
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func moduleDisclosure(_ module: CourseModule, number: Int) -> some View {
        let isExpanded = expandedModuleIDs.contains(module.id)

        return VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    if isExpanded { expandedModuleIDs.remove(module.id) }
                    else { expandedModuleIDs.insert(module.id) }
                }
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    Text("\(number)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(levelColor, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CHAPTER \(number)")
                            .font(.caption2.bold())
                            .foregroundStyle(levelColor)
                        Text(module.title).font(.title3.bold())
                    }
                    Spacer()
                    Label(
                        "\(module.lessons.filter(model.isCompleted).count)/\(module.lessons.count)",
                        systemImage: module.lessons.allSatisfy(model.isCompleted) ? "checkmark.circle.fill" : "circle.dotted"
                    )
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(module.lessons.allSatisfy(model.isCompleted) ? Color.green : Color.secondary)
                }
                .contentShape(Rectangle())
                .padding(18)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Chapter \(number), \(module.title)")
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(isExpanded ? "Collapse chapter" : "Expand chapter")
            .help(module.summary)

            if isExpanded {
                Divider()
                ForEach(Array(module.lessons.enumerated()), id: \.element.id) { index, lesson in
                    Button {
                        model.startLesson(lesson)
                    } label: {
                        lessonRow(lesson, number: index + 1)
                    }
                    .buttonStyle(.plain)
                    if index < module.lessons.count - 1 { Divider().padding(.leading, 64) }
                }
            }
        }
        .background(.background.opacity(0.82), in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(.separator.opacity(0.45)) }
    }

    private func lessonRow(_ lesson: PracticeLesson, number: Int) -> some View {
        let mastery = model.mastery(for: lesson)
        return HStack(spacing: 14) {
            Image(systemName: lessonSymbol(mastery))
                .font(.title2)
                .foregroundStyle(lessonColor(mastery))
                .frame(width: 32)
                .accessibilityLabel(mastery?.title ?? "Not started")
            VStack(alignment: .leading, spacing: 4) {
                Text("\(number). \(lesson.title)").font(.headline)
                if let mastery {
                    Text(mastery.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Label("\(lesson.estimatedMinutes) min", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(16)
        .help(lesson.objective)
    }

    private func lessonSymbol(_ mastery: LessonMastery?) -> String {
        switch mastery {
        case .introduced: "circle.dotted"
        case .practiced: "checkmark.circle.fill"
        case .mastered: "seal.fill"
        case nil: "circle"
        }
    }

    private func lessonColor(_ mastery: LessonMastery?) -> Color {
        switch mastery {
        case .introduced: levelColor.opacity(0.72)
        case .practiced: .green
        case .mastered: AppTheme.accent
        case nil: levelColor.opacity(0.48)
        }
    }

    private var levelColor: Color {
        AppTheme.accent
    }

    private var preferredCourseLevel: CourseLevel {
        switch model.learnerExperience {
        case .beginner: .beginner
        case .intermediate: .intermediate
        case .advanced: .advanced
        }
    }
}
