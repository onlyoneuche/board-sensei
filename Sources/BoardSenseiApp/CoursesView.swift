import MusicCore
import SwiftUI

struct CoursesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 34) {
                    studioHero
                    learningStatus
                    courseShelf
                }
                .padding(.vertical, 34)
                .frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
            .navigationTitle("Courses")
        }
    }

    private var studioHero: some View {
        VStack(spacing: 14) {
            BoardSenseiMark(size: 156)
                .shadow(color: .black.opacity(0.2), radius: 18, y: 9)

            VStack(spacing: 5) {
                Text("BOARD SENSEI")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(1.2)
                Text("Learn it. Hear it. Play it.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text("Choose your practice path")
                .font(.system(size: 34, weight: .semibold))
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var learningStatus: some View {
        HStack(spacing: 10) {
            if model.practiceStreaksEnabled {
                statusChip(
                    model.practiceDayStreak > 0 ? "\(model.practiceDayStreak)-day rhythm" : "Start a rhythm",
                    symbol: "flame.fill",
                    color: .orange,
                    help: "Your practice rhythm advances on days when you complete a lesson."
                )
            }
            statusChip(
                "\(completedLessonCount) practised",
                symbol: "checkmark.circle.fill",
                color: .green,
                help: "Lessons with at least one completed pass across every course."
            )
            statusChip(
                "\(masteredLessonCount) mastered",
                symbol: "seal.fill",
                color: AppTheme.accent,
                help: "Lessons mastered through accurate repetition."
            )
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func statusChip(_ text: String, symbol: String, color: Color, help: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
            .overlay { Capsule().stroke(color.opacity(0.3), lineWidth: 1) }
            .help(help)
    }

    private var courseShelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(height: 1)
                Image(systemName: "arrow.left.and.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 30, height: 24)
                    .background(AppTheme.accent.opacity(0.1), in: Capsule())
                Rectangle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(height: 1)
            }
            .padding(.horizontal, 32)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Horizontally scrollable course shelf")

            GeometryReader { geometry in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 18) {
                        NavigationLink {
                            JazzCourseView()
                        } label: {
                            CourseCatalogCard(
                                number: "01",
                                title: "Jazz",
                                subtitle: "Harmony, voicings, improvisation, and comping",
                                symbol: "music.quarternote.3",
                                color: AppTheme.accent,
                                progress: jazzProgress,
                                detail: "36 lessons · 3 levels",
                                isAvailable: true
                            )
                        }
                        .buttonStyle(.plain)

<<<<<<< Updated upstream
                        CourseCatalogCard(
                            title: "Classical",
                            subtitle: "Technique, repertoire, reading, and interpretation",
                            symbol: "music.note",
                            color: .teal,
                            progress: 0,
                            detail: "Coming soon",
=======
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
>>>>>>> Stashed changes
                            isAvailable: false
                        )
                    }
                    .padding(.horizontal, max(32, (geometry.size.width - 1_212) / 2))
                    .padding(.vertical, 3)
                }
                .scrollIndicators(.visible)
            }
            .frame(height: 336)
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

<<<<<<< Updated upstream
    private var jazzProgress: Double {
        guard JazzCourseCatalog.course.lessonCount > 0 else { return 0 }
        let completed = JazzCourseCatalog.course.stages
            .flatMap(\.modules)
            .flatMap(\.lessons)
            .filter(model.isCompleted)
=======
    private func progress(for course: PracticeCourse) -> Double {
        guard course.lessonCount > 0 else { return 0 }
        let completed = course.lessons
            .filter { model.isCompleted($0, in: course.id) }
>>>>>>> Stashed changes
            .count
        return Double(completed) / Double(JazzCourseCatalog.course.lessonCount)
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
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(color, in: RoundedRectangle(cornerRadius: 14))
                Spacer()
                Text(number)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 26, weight: .semibold))
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Divider()

            VStack(alignment: .leading, spacing: 9) {
                if isAvailable {
                    HStack {
                        Text(detail)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    ProgressView(value: progress).tint(color)
                } else {
                    HStack {
                        Label(detail, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("COMING SOON")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text(isAvailable ? (progress > 0 ? "CONTINUE" : "START") : "PLANNED")
                        .font(.caption2.bold())
                        .tracking(0.8)
                    Spacer()
                    Image(systemName: isAvailable ? "arrow.right" : "lock.fill")
                        .font(.caption.bold())
                }
                .foregroundStyle(isAvailable ? color : Color.secondary)
            }
        }
        .padding(22)
        .frame(width: 392, height: 314, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    isAvailable
                        ? color.opacity(isHovering ? 0.72 : 0.42)
                        : Color.secondary.opacity(0.2),
                    lineWidth: isAvailable && isHovering ? 1.5 : 1
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .opacity(isAvailable ? 1 : 0.72)
        .scaleEffect(isAvailable && isHovering ? 1.012 : 1)
        .shadow(
            color: .black.opacity(isAvailable && isHovering ? 0.2 : 0.08),
            radius: isAvailable && isHovering ? 14 : 5,
            y: isAvailable && isHovering ? 7 : 3
        )
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isHovering)
        .onHover { hovering in
            isHovering = isAvailable && hovering
        }
        .accessibilityElement(children: .combine)
    }
}

private struct JazzCourseView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedLevel: CourseLevel = .beginner
    @State private var expandedModuleIDs: Set<String> = [JazzCourseCatalog.beginner.modules[0].id]
    @State private var appliedLearnerStartingPoint = false

    private let course = JazzCourseCatalog.course

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
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        .navigationTitle("Jazz Course")
        .onAppear {
            guard !appliedLearnerStartingPoint else { return }
            selectedLevel = preferredCourseLevel
            expandedModuleIDs = Set(stage.modules.first.map { [$0.id] } ?? [])
            appliedLearnerStartingPoint = true
        }
        .onChange(of: selectedLevel) { _, _ in
            expandedModuleIDs = Set(stage.modules.first.map { [$0.id] } ?? [])
        }
    }

    private var courseHeader: some View {
        HStack(alignment: .top, spacing: 22) {
            Image(systemName: "music.quarternote.3")
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
            ForEach(CourseLevel.allCases) { level in
                Text(level.rawValue).tag(level)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("Jazz course level")
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
        .help(selectedLevel.summary)
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
        .background(.background.opacity(0.82), in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(.separator.opacity(0.45)) }
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
