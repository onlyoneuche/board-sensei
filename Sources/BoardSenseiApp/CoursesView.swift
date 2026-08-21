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
