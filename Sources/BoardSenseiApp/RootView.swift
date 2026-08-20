import MusicCore
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.isPracticeMode {
                PracticeSessionRootView()
            } else {
                standardNavigation
            }
        }
        .fontDesign(.default)
        .tint(AppTheme.accent)
    }

    private var standardNavigation: some View {
        NavigationSplitView {
            List(AppModel.Destination.allCases, selection: $model.destination) { destination in
                Label(destination.rawValue, systemImage: destination.symbol)
                    .tag(destination)
                    .padding(.vertical, 5)
            }
            .navigationTitle("Board Sensei")
            .safeAreaInset(edge: .bottom) {
                MIDIStatusCard()
                    .padding(12)
            }
        } detail: {
            switch model.destination ?? .courses {
            case .courses: CoursesView()
            case .midiLab: MIDIDiagnosticsView()
            case .architecture: FoundationView()
            }
        }
    }
}

private struct PracticeSessionRootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            practiceTopBar
            Rectangle().fill(PracticeTheme.strongSeparator).frame(height: 1)
            NavigationSplitView {
                LessonGuideSidebar()
                    .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 370)
            } detail: {
                PracticeView()
            }
        }
        .tint(PracticeTheme.accent)
        .preferredColorScheme(.dark)
    }

    private var practiceTopBar: some View {
        HStack(spacing: 8) {
            Label(model.activeLesson.title, systemImage: "pianokeys")
                .font(.headline)
                .lineLimit(1)
            Spacer()
            MetronomeTransportControls()
            Divider().frame(height: 22)
            navigationButton("Courses", symbol: "graduationcap.fill", destination: .courses)
            navigationButton("MIDI Lab", symbol: "pianokeys", destination: .midiLab)
            navigationButton("Foundation", symbol: "square.3.layers.3d", destination: .architecture)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(PracticeTheme.toolbar)
    }

    private func navigationButton(
        _ title: String,
        symbol: String,
        destination: AppModel.Destination
    ) -> some View {
        Button {
            model.leavePractice(for: destination)
        } label: {
            Label(title, systemImage: symbol)
        }
        .buttonStyle(.borderless)
        .quickHelp(title, "Leave class mode and open \(title). Your lesson completion remains saved.")
    }
}

private struct MetronomeTransportControls: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 9) {
            Button {
                model.setMetronomeEnabled(!model.isMetronomeEnabled)
            } label: {
                Image(systemName: "metronome")
                    .foregroundStyle(model.isMetronomeEnabled ? Color.white : Color.secondary)
                    .frame(width: 26, height: 26)
                    .background(model.isMetronomeEnabled ? PracticeTheme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help(model.isMetronomeEnabled ? "Turn metronome off" : "Turn metronome on")

            Circle()
                .fill(beatIndicatorColor)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)

            Button {
                model.setPreviewTempo(model.previewTempoBPM - 5)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.borderless)
            .help("Decrease tempo")

            Text("\(model.previewTempoBPM) BPM")
                .font(.caption.monospacedDigit().bold())
                .frame(minWidth: 58)

            Button {
                model.setPreviewTempo(model.previewTempoBPM + 5)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Increase tempo")

            Menu(model.metronomeSignature.displayName) {
                ForEach(PracticeTimeSignature.common) { signature in
                    Button {
                        model.setMetronomeSignature(signature)
                    } label: {
                        if signature == model.metronomeSignature {
                            Label(signature.displayName, systemImage: "checkmark")
                        } else {
                            Text(signature.displayName)
                        }
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 48)
            .help("Time signature")

            Image(systemName: "speaker.wave.1.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { Double(model.metronomeVolume) },
                    set: { model.setMetronomeVolume(Float($0)) }
                ),
                in: 0...1
            )
            .frame(width: 72)
            .accessibilityLabel("Metronome volume")
            .accessibilityValue("\(Int(model.metronomeVolume * 100)) percent")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(PracticeTheme.panel, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(PracticeTheme.separator, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .quickHelp(
            "Metronome and tempo",
            "Toggle the click, change BPM or meter, and set click volume. Exercise preview starts with this transport on beat one."
        )
    }

    private var beatIndicatorColor: Color {
        guard model.isMetronomeEnabled, model.metronomeBeatIndex != nil else {
            return Color.secondary.opacity(0.25)
        }
        return model.metronomeBeatIndex == 0 ? .orange : PracticeTheme.accent
    }
}

private struct LessonGuideSidebar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("CURRENT LESSON")
                        .font(.caption2.bold())
                        .foregroundStyle(PracticeTheme.accent)
                    Text(model.activeLesson.title)
                        .font(.title2.bold())
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PracticeTheme.toolbar)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(PracticeTheme.strongSeparator).frame(height: 1)
                }

                if let navigation = model.activeLessonNavigation {
                    chapterLessonMenu(navigation)
                }

                guideSection("Key concept", symbol: "lightbulb.fill") {
                    Text(model.activeLesson.theory)
                }
                .quickHelp("Key concept", "The short idea to keep in mind while playing. The Topic page contains the full explanation, preparation guide, and narration.")

                guideSection("Exercise", symbol: model.activeLesson.isChordExercise ? "rectangle.stack.fill" : "music.note") {
                    Text(model.activeLesson.practiceInstruction)

                    VStack(spacing: 10) {
                        Button {
                            model.toggleExercisePreview()
                        } label: {
                            Label(
                                model.isPreviewPlaying ? "Stop exercise" : "Hear full exercise",
                                systemImage: model.isPreviewPlaying ? "stop.fill" : "play.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        HStack {
                            Image(systemName: "metronome")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(model.previewTempoBPM) BPM")
                                .font(.caption.monospacedDigit().bold())
                            Spacer()
                        }

                        Slider(
                            value: Binding(
                                get: { Double(model.previewTempoBPM) },
                                set: { model.setPreviewTempo(Int($0.rounded())) }
                            ),
                            in: 50...180,
                            step: 5
                        )
                        .accessibilityLabel("Exercise preview tempo")
                        .accessibilityValue("\(model.previewTempoBPM) beats per minute")
                    }
                    .padding(12)
                    .background(PracticeTheme.inset, in: RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(PracticeTheme.separator, lineWidth: 1)
                    }
                    .quickHelp(
                        "Exercise preview",
                        "Hear the full exercise without changing your score. The staff and piano follow every preview prompt."
                    )
                }

                guideSection("Lesson route", symbol: "list.number") {
                    ForEach(Array(model.activeLesson.prompts.enumerated()), id: \.offset) { index, prompt in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: routeSymbol(at: index))
                                .foregroundStyle(routeColor(at: index))
                            Text(prompt.pitches.map(noteName).joined(separator: " + "))
                                .font(.caption.monospaced())
                        }
                    }
                }
                .quickHelp("Lesson route", "Shows prompt order, completed prompts, and the currently playing preview prompt.")

                Label(model.activeLesson.chapterLabel, systemImage: "text.book.closed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
            }
        }
        .background(PracticeTheme.sidebar)
        .navigationTitle("Class guide")
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
    }

    private func guideSection<Content: View>(
        _ title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(PracticeTheme.panel)
        .overlay(alignment: .top) {
            Rectangle().fill(PracticeTheme.separator).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(PracticeTheme.strongSeparator).frame(height: 1)
        }
    }

    private func routeSymbol(at index: Int) -> String {
        if model.isPreviewPlaying && model.previewPromptIndex == index { return "speaker.wave.2.fill" }
        return index < model.completedNotes ? "checkmark.circle.fill" : "circle"
    }

    private func routeColor(at index: Int) -> Color {
        if model.isPreviewPlaying && model.previewPromptIndex == index { return PracticeTheme.accent }
        return index < model.completedNotes ? .green : .secondary
    }

    private func chapterLessonMenu(_ navigation: CourseLessonNavigation) -> some View {
        Menu {
            ForEach(navigation.chapterLessons) { lesson in
                Button {
                    model.startLesson(lesson)
                } label: {
                    if lesson.id == model.activeLesson.id {
                        Label(lesson.title, systemImage: "location.fill")
                    } else if model.isCompleted(lesson) {
                        Label(lesson.title, systemImage: "checkmark.circle.fill")
                    } else {
                        Text(lesson.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(navigation.level.rawValue.uppercased()) · CHAPTER \(navigation.chapterNumber)")
                        .font(.caption2.bold())
                        .foregroundStyle(PracticeTheme.accent)
                    Text(navigation.chapterTitle)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(PracticeTheme.raised, in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(PracticeTheme.separator, lineWidth: 1)
            }
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Choose a lesson in \(navigation.chapterTitle)")
        .quickHelp(
            "Chapter lessons",
            "Open this menu to jump directly to another lesson in \(navigation.chapterTitle)."
        )
    }

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            QuickHelpPanel()
            lessonNavigationBar
        }
        .background(PracticeTheme.toolbar)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private var lessonNavigationBar: some View {
        if let navigation = model.activeLessonNavigation {
            HStack(spacing: 10) {
                lessonNavigationButton(
                    "Previous",
                    symbol: "chevron.left",
                    lesson: navigation.previousLesson
                )
                lessonNavigationButton(
                    "Next",
                    symbol: "chevron.right",
                    lesson: navigation.nextLesson,
                    iconAfterTitle: true
                )
            }
            .padding(12)
            .overlay(alignment: .top) { Divider() }
        }
    }

    private func lessonNavigationButton(
        _ title: String,
        symbol: String,
        lesson: PracticeLesson?,
        iconAfterTitle: Bool = false
    ) -> some View {
        Button {
            if let lesson { model.startLesson(lesson) }
        } label: {
            HStack(spacing: 6) {
                if !iconAfterTitle { Image(systemName: symbol) }
                Text(title)
                if iconAfterTitle { Image(systemName: symbol) }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(lesson == nil)
        .help(lesson.map { "Open \($0.title)" } ?? "No \(title.lowercased()) lesson")
        .quickHelp(
            "\(title) lesson",
            lesson.map { "Open \($0.title)." } ?? "There is no \(title.lowercased()) lesson in the course sequence."
        )
    }
}

private struct QuickHelpPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(model.quickHelpContent?.title ?? "Quick Help", systemImage: "questionmark.circle")
                .font(.caption.bold())
            Text(model.quickHelpContent?.detail ?? model.activeLesson.objective)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 72, alignment: .topLeading)
        .background(PracticeTheme.panel)
    }
}

private struct MIDIStatusCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: model.selectedDeviceID == nil ? "pianokeys.inverse" : "pianokeys")
                .foregroundStyle(model.selectedDeviceID == nil ? Color.secondary : Color.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.selectedDeviceID == nil ? "MIDI offline" : "MIDI connected")
                    .font(.caption.bold())
                Text(model.connectionMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
