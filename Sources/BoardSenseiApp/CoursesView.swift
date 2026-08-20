import MusicCore
import SwiftUI

struct CoursesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text("Practice Courses")
                        .font(.system(size: 32, weight: .semibold))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 22)], spacing: 22) {
                        NavigationLink {
                            JazzCourseView()
                        } label: {
                            CourseCatalogCard(
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

                        CourseCatalogCard(
                            title: "Classical",
                            subtitle: "Technique, repertoire, reading, and interpretation",
                            symbol: "music.note",
                            color: .teal,
                            progress: 0,
                            detail: "Coming soon",
                            isAvailable: false
                        )
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

    private var jazzProgress: Double {
        guard JazzCourseCatalog.course.lessonCount > 0 else { return 0 }
        let completed = JazzCourseCatalog.course.stages
            .flatMap(\.modules)
            .flatMap(\.lessons)
            .filter(model.isCompleted)
            .count
        return Double(completed) / Double(JazzCourseCatalog.course.lessonCount)
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

private struct JazzCourseView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedLevel: CourseLevel = .beginner
    @State private var expandedModuleIDs: Set<String> = [JazzCourseCatalog.beginner.modules[0].id]

    private let course = JazzCourseCatalog.course

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
            Text("\(completedCount)/\(stage.lessonCount) complete")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .help(selectedLevel.summary)
    }

    private func moduleDisclosure(_ module: CourseModule, number: Int) -> some View {
        let isExpanded = expandedModuleIDs.contains(module.id)

        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
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
                    NavigationLink {
                        TopicView(lesson: lesson, level: selectedLevel, color: levelColor)
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
        HStack(spacing: 14) {
            Image(systemName: model.isCompleted(lesson) ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(model.isCompleted(lesson) ? Color.green : levelColor.opacity(0.65))
                .frame(width: 32)
                .accessibilityLabel(model.isCompleted(lesson) ? "Completed" : "Not completed")
            VStack(alignment: .leading, spacing: 4) {
                Text("\(number). \(lesson.title)").font(.headline)
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

    private var levelColor: Color {
        AppTheme.accent
    }
}

private struct TopicView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var narration = LessonNarrationService()
    let lesson: PracticeLesson
    let level: CourseLevel
    let color: Color

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Label(level.rawValue, systemImage: "graduationcap.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(color)
                    Spacer()
                    if model.isCompleted(lesson) {
                        Label("Completed", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(lesson.title)
                        .font(.system(size: 32, weight: .semibold))
                    Text(lesson.objective)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                narrationControls

                detailCard("What you are learning", systemImage: "book.closed.fill") {
                    Text(lesson.studyGuide)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                detailCard("Why it matters", systemImage: "lightbulb.fill") {
                    Text(lesson.topicWhyItMatters)
                        .lineSpacing(4)
                }

                detailCard("Exercise brief", systemImage: "target") {
                    Text(lesson.practiceInstruction)
                        .font(.body.weight(.medium))

                    Divider()

                    Label(lesson.topicSuccessCriterion, systemImage: "checkmark.seal")
                        .foregroundStyle(.secondary)
                }

                detailCard("How to practise", systemImage: "list.number") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(lesson.topicPracticePlan.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.bold().monospacedDigit())
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(color, in: Circle())
                                Text(step)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                detailCard("What to listen for", systemImage: "ear.fill") {
                    Text(lesson.topicListeningFocus)
                        .lineSpacing(4)
                }

                detailCard(lesson.isChordExercise ? "Your chord route" : "Your note route", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], alignment: .leading, spacing: 10) {
                        ForEach(Array(lesson.prompts.enumerated()), id: \.offset) { index, prompt in
                            VStack(spacing: 3) {
                                Text(prompt.pitches.map(noteName).joined(separator: " + "))
                                    .font(.headline.monospaced())
                                Text("\(index + 1)").font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(minWidth: 48)
                            .padding(.vertical, 9)
                            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                HStack {
                    Label(lesson.chapterLabel, systemImage: "book.closed")
                    Spacer()
                    Label("About \(lesson.estimatedMinutes) minutes", systemImage: "clock")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Button {
                    narration.stop()
                    model.startLesson(lesson)
                } label: {
                    Label(model.isCompleted(lesson) ? "Practice Again" : "Start Practice", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(color)
            }
            .padding(28)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Topic")
        .onDisappear { narration.stop() }
    }

    private var narrationControls: some View {
        HStack(spacing: 14) {
            Image(systemName: narration.state == .speaking ? "waveform.circle.fill" : "waveform.circle")
                .font(.system(size: 30))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 3) {
                Text("Listen to topic")
                    .font(.headline)
                Text("\(narration.sourceDescription(lessonID: lesson.id, contentHash: lesson.narrationContentHash)) · about \(narrationMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                narration.toggle(
                    lessonID: lesson.id,
                    contentHash: lesson.narrationContentHash,
                    text: lesson.narrationScript
                )
            } label: {
                Label(narrationButtonTitle, systemImage: narrationButtonSymbol)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Reads the complete topic explanation and preparation guide aloud")

            if narration.state != .idle {
                Button("Stop", systemImage: "stop.fill") {
                    narration.stop()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.28), lineWidth: 1)
        }
    }

    private var narrationButtonTitle: String {
        switch narration.state {
        case .idle: "Listen"
        case .speaking: "Pause"
        case .paused: "Resume"
        }
    }

    private var narrationButtonSymbol: String {
        switch narration.state {
        case .idle: "play.fill"
        case .speaking: "pause.fill"
        case .paused: "play.fill"
        }
    }

    private var narrationMinutes: Int {
        max(1, Int(ceil(Double(lesson.narrationScript.split(whereSeparator: \.isWhitespace).count) / 155)))
    }

    private func detailCard<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

}
