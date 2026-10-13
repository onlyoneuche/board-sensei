import MusicCore
import SwiftUI

struct CoursesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    studioHero
                    learningStatus
                    courseShelf
                }
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
            .background(AppTheme.canvas.ignoresSafeArea())
            .navigationTitle("Courses")
        }
    }

    private var studioHero: some View {
        VStack(spacing: 18) {
            HStack {
                StudioSectionLabel(title: "Your practice studio")
                Spacer()
                Label("Jazz & technique", systemImage: "pianokeys")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            StudioRule()
            HStack(spacing: 28) {
                CourseArtwork()
                    .frame(maxWidth: 180)
                VStack(spacing: 12) {
                    BoardSenseiMark(size: 112)
                    Text("Choose your practice path")
                        .font(.system(size: 30, weight: .medium))
                    Text("Learn it. Hear it. Play it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: true, vertical: false)
                CourseArtwork(technique: true)
                    .frame(maxWidth: 180)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .combine)
    }

    private var learningStatus: some View {
        HStack(spacing: 0) {
            if model.practiceStreaksEnabled {
                statusMetric(
                    "Practice rhythm", value: "\(model.practiceDayStreak)", unit: "DAYS",
                    symbol: "flame", color: .orange,
                    help: "Your practice rhythm advances on days when you complete a lesson."
                )
                Divider().padding(.vertical, 16)
            }
            statusMetric(
                "Practised", value: "\(completedLessonCount)", unit: "LESSONS",
                symbol: "checkmark.circle", color: .green,
                help: "Lessons with at least one completed pass across every course."
            )
            Divider().padding(.vertical, 16)
            statusMetric(
                "Mastered", value: "\(masteredLessonCount)", unit: "LESSONS",
                symbol: "seal", color: AppTheme.accent,
                help: "Lessons mastered through accurate repetition."
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .studioPanel()
        .padding(.horizontal, 32)
        .accessibilityElement(children: .contain)
    }

    private func statusMetric(
        _ title: String, value: String, unit: String,
        symbol: String, color: Color, help: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StudioSectionLabel(title: title)
                Spacer()
                Image(systemName: symbol).font(.caption).foregroundStyle(color)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value).font(.system(size: 32, weight: .light).monospacedDigit())
                Text(unit).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(help)
        .accessibilityElement(children: .combine)
    }

    private var courseShelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                StudioSectionLabel(title: "Course library")
                Spacer()
                Image(systemName: "arrow.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Horizontally scrollable course shelf")

            GeometryReader { geometry in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 16) {
                        NavigationLink {
                            CourseDetailView(
                                course: JazzCourseCatalog.course,
                                symbol: "music.quarternote.3",
                                usesLearnerStartingPoint: true
                            )
                        } label: {
                            CourseCatalogCard(
                                number: "01",
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
                                number: "02",
                                title: "Hanon Technique",
                                subtitle: "Finger independence, evenness, dexterity, and control",
                                symbol: "figure.strengthtraining.traditional",
                                color: AppTheme.accent,
                                progress: progress(for: HanonCourseCatalog.course),
                                detail: "20 verified lessons · Part I",
                                isAvailable: true
                            )
                        }
                        .buttonStyle(.plain)

                        CourseCatalogCard(
                            number: "03",
                            title: "Classical",
                            subtitle: "Reading, repertoire, phrasing, and expressive technique",
                            symbol: "music.note.list",
                            color: AppTheme.accent,
                            progress: 0,
                            detail: "Curriculum in development",
                            isAvailable: false
                        )
                    }
                    .padding(.horizontal, max(32, (geometry.size.width - 1_112) / 2))
                    .padding(.vertical, 3)
                }
                .scrollIndicators(.visible)
            }
            .frame(height: 354)
        }
    }

    private var completedLessonCount: Int {
        CourseLibrary.courses.reduce(0) { count, course in
            count + course.lessons.filter { model.isCompleted($0, in: course.id) }.count
        }
    }

    private var masteredLessonCount: Int {
        CourseLibrary.courses.reduce(0) { count, course in
            count + course.lessons.filter { model.mastery(for: $0, in: course.id) == .mastered }.count
        }
    }

    private func progress(for course: PracticeCourse) -> Double {
        guard course.lessonCount > 0 else { return 0 }
        let completed = course.lessons
            .filter { model.isCompleted($0, in: course.id) }
            .count
        return Double(completed) / Double(course.lessonCount)
    }
}

private struct CourseCatalogCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    let number: String
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    let progress: Double
    let detail: String
    let isAvailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text(number)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(isAvailable ? color : Color.secondary)
            }
            CourseArtwork(technique: number == "02", available: isAvailable)
                .frame(height: 78)
                .background(AppTheme.inset)
                .overlay { Rectangle().strokeBorder(AppTheme.line, lineWidth: 0.5) }
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 24, weight: .medium))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(detail).font(.caption)
                    Spacer()
                    if isAvailable {
                        Text("\(Int(progress * 100))%")
                            .font(.caption.monospacedDigit())
                    }
                }
                .foregroundStyle(.secondary)
                if isAvailable {
                    ProgressView(value: progress).tint(color)
                        .accessibilityLabel("\(title) course progress")
                        .accessibilityValue("\(Int(progress * 100)) percent")
                }
                StudioRule()
                HStack {
                    Text(isAvailable ? (progress > 0 ? "CONTINUE" : "START COURSE") : "COMING SOON")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                    Spacer()
                    Image(systemName: isAvailable ? "arrow.up.right" : "lock")
                        .font(.caption)
                }
                .foregroundStyle(isAvailable ? color : Color.secondary)
            }
        }
        .padding(20)
        .frame(width: 360, height: 334, alignment: .topLeading)
        .studioPanel()
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.radius)
                .strokeBorder(isHovering ? color : Color.clear, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isHovering)
        .onHover { hovering in isHovering = isAvailable && hovering }
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
        stage.modules.flatMap(\.lessons).filter { model.isCompleted($0, in: course.id) }.count
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
        .background(AppTheme.canvas.ignoresSafeArea())
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
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(levelColor)
                .frame(width: 72, height: 72)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                .overlay { RoundedRectangle(cornerRadius: AppTheme.radius).strokeBorder(AppTheme.line) }

            VStack(alignment: .leading, spacing: 8) {
                Text(course.title)
                    .font(.system(size: 32, weight: .medium))
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
            .filter { model.mastery(for: $0, in: course.id) == .mastered }
            .count
    }

    private var learningSummary: some View {
        HStack(spacing: 18) {
            summaryMetric(
                "Practised",
                value: "\(course.lessons.filter { model.isCompleted($0, in: course.id) }.count)",
                symbol: "checkmark.circle.fill"
            )
            Divider().frame(height: 38)
            summaryMetric(
                "Mastered",
                value: "\(course.lessons.filter { model.mastery(for: $0, in: course.id) == .mastered }.count)",
                symbol: "seal.fill"
            )
            Divider().frame(height: 38)
            summaryMetric("Milestones", value: "\(model.unlockedAchievements.count)", symbol: "flag.checkered")
            Spacer()
        }
        .padding(16)
        .studioPanel()
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
        let completedLessons = module.lessons.filter { model.isCompleted($0, in: course.id) }

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
                        .foregroundStyle(levelColor)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.inset)
                        .overlay { Rectangle().strokeBorder(AppTheme.line) }
                    VStack(alignment: .leading, spacing: 4) {
                        StudioSectionLabel(title: "Chapter \(number)")
                        Text(module.title).font(.system(size: 18, weight: .medium))
                    }
                    Spacer()
                    Label(
                        "\(completedLessons.count)/\(module.lessons.count)",
                        systemImage: completedLessons.count == module.lessons.count ? "checkmark.circle.fill" : "circle.dotted"
                    )
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(completedLessons.count == module.lessons.count ? Color.green : Color.secondary)
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
                        model.startLesson(course: course, lesson: lesson)
                    } label: {
                        lessonRow(lesson, number: index + 1)
                    }
                    .buttonStyle(.plain)
                    if index < module.lessons.count - 1 { Divider().padding(.leading, 64) }
                }
            }
        }
        .studioPanel()
    }

    private func lessonRow(_ lesson: PracticeLesson, number: Int) -> some View {
        let mastery = model.mastery(for: lesson, in: course.id)
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
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
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
