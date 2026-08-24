import MusicCore
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if !model.hasCompletedOnboarding {
                OnboardingView()
            } else if model.isPracticeMode {
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
            VStack(spacing: 0) {
                BoardSenseiLockup(markSize: 38)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                List(AppModel.Destination.allCases, selection: $model.destination) { destination in
                    Label(destination.rawValue, systemImage: destination.symbol)
                        .tag(destination)
                        .padding(.vertical, 5)
                }
                .safeAreaInset(edge: .bottom) {
                    MIDIStatusCard()
                        .padding(12)
                }
            }
        } detail: {
            switch model.destination ?? .courses {
            case .courses: CoursesView()
            case .midiLab: MIDIDiagnosticsView()
            case .architecture: FoundationView()
            case .settings: SettingsView()
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
            HSplitView {
                LessonGuideSidebar()
                    .frame(minWidth: 280, idealWidth: 380, maxWidth: 680)
                PracticeView()
                    .frame(minWidth: 560)
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
            navigationButton("Settings", symbol: "gearshape.fill", destination: .settings)
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
            .help(model.isMetronomeEnabled ? "Disarm metronome" : "Arm metronome for playback or practice looping")

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
            "Arm clicks, change BPM or meter, and set click volume. The metronome sounds only during exercise playback or an explicit scored practice loop."
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
    @StateObject private var narration = LessonNarrationService()

    var body: some View {
        ScrollView(.vertical) {
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

                narrationControls

                guideSection("What you are learning", symbol: "book.closed.fill") {
                    Text(model.activeLesson.studyGuide)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                guideSection("Why it matters", symbol: "lightbulb.fill") {
                    Text(model.activeLesson.topicWhyItMatters)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                guideSection("Exercise", symbol: model.activeLesson.isChordExercise ? "rectangle.stack.fill" : "music.note") {
                    Text(model.activeLesson.practiceInstruction)

                    Label(model.activeLesson.topicSuccessCriterion, systemImage: "checkmark.seal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Button {
                                narration.stop()
                                model.toggleExercisePreview()
                            } label: {
                                Label(
                                    model.isPreviewPlaying
                                        ? "Stop exercise"
                                        : (model.isFocusedPracticeSelection ? "Hear selection" : "Hear full exercise"),
                                    systemImage: model.isPreviewPlaying ? "stop.fill" : "play.fill"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                model.toggleExerciseLoopEnabled()
                            } label: {
                                Image(systemName: "repeat")
                                    .foregroundStyle(model.isExerciseLoopEnabled ? Color.white : Color.secondary)
                                    .frame(width: 30, height: 28)
                                    .background(
                                        model.isExerciseLoopEnabled ? PracticeTheme.accent : PracticeTheme.raised,
                                        in: RoundedRectangle(cornerRadius: 5)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help(model.isExerciseLoopEnabled ? "Disable exercise loop" : "Enable exercise loop")
                            .accessibilityLabel("Exercise loop")
                            .accessibilityValue(model.isExerciseLoopEnabled ? "Enabled" : "Disabled")
                        }

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

                        if model.activeLesson.scoreMetadata != nil {
                            Divider()

                            Picker("Hands", selection: Binding(
                                get: { model.practiceHandMode },
                                set: { mode in model.setPracticeHandMode(mode) }
                            )) {
                                ForEach(PracticeHandMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityLabel("Practice hands")

                            HStack(spacing: 8) {
                                Menu("From m. \(model.practiceStartMeasure)") {
                                    ForEach(1...model.activeLessonMeasureCount, id: \.self) { measure in
                                        Button("Measure \(measure)") {
                                            model.setPracticeMeasureRange(
                                                start: measure,
                                                end: max(measure, model.practiceEndMeasure)
                                            )
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)

                                Menu("To m. \(model.practiceEndMeasure)") {
                                    ForEach(model.practiceStartMeasure...model.activeLessonMeasureCount, id: \.self) { measure in
                                        Button("Measure \(measure)") {
                                            model.setPracticeMeasureRange(
                                                start: model.practiceStartMeasure,
                                                end: measure
                                            )
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .menuStyle(.borderlessButton)

                            Toggle(
                                "Raise tempo after ≥90% pass",
                                isOn: Binding(
                                    get: { model.automaticTempoProgressionEnabled },
                                    set: { enabled in model.setAutomaticTempoProgressionEnabled(enabled) }
                                )
                            )
                            .toggleStyle(.switch)
                            .font(.caption)

                            if model.automaticTempoProgressionEnabled {
                                Stepper(
                                    "Tempo step: +\(model.automaticTempoStep) BPM",
                                    value: Binding(
                                        get: { model.automaticTempoStep },
                                        set: { step in model.setAutomaticTempoStep(step) }
                                    ),
                                    in: 1...10
                                )
                                .font(.caption.monospacedDigit())
                            }

                            Text("Measures \(model.practiceStartMeasure)–\(model.practiceEndMeasure) · \(model.practiceHandMode.rawValue) · \(model.practicePromptCount) prompts")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(PracticeTheme.inset, in: RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(PracticeTheme.separator, lineWidth: 1)
                    }
                    .quickHelp(
                        "Exercise playback",
                        "Choose a measure range and one or both hands, set the starting BPM, and optionally raise tempo after passes at 90 percent accuracy or better. The repeat button cycles the selected demonstration."
                    )
                }

                guideSection("How to practise", symbol: "list.number") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(model.activeLesson.topicPracticePlan.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 9) {
                                Text("\(index + 1)")
                                    .font(.caption2.bold().monospacedDigit())
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(PracticeTheme.accent, in: Circle())
                                Text(step)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                guideSection("What to listen for", symbol: "ear.fill") {
                    Text(model.activeLesson.topicListeningFocus)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                guideSection("Full score & fingerings", symbol: "music.note.list") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 124), spacing: 8)], spacing: 8) {
                        ForEach(Array(model.activeLesson.prompts.enumerated()), id: \.offset) { index, prompt in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 5) {
                                    Image(systemName: routeSymbol(at: index))
                                        .foregroundStyle(routeColor(at: index))
                                    Text("\(index + 1)")
                                        .font(.caption2.bold().monospacedDigit())
                                    Spacer(minLength: 0)
                                }
                                Text(prompt.pitches.map(noteName).joined(separator: " + "))
                                    .font(.caption.monospaced().bold())
                                if !prompt.fingerings.isEmpty {
                                    Text(fingeringLabel(for: prompt))
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                routeColor(at: index).opacity(index == activeRouteIndex ? 0.16 : 0.06),
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(routeColor(at: index).opacity(0.35), lineWidth: 1)
                            }
                        }
                    }
                }
                .quickHelp(
                    "Full score and fingerings",
                    "Shows the complete exercise in playing order. LH and RH identify the hand; fingers are numbered 1 for thumb through 5 for little finger."
                )

                Label(model.activeLesson.chapterLabel, systemImage: "text.book.closed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
            }
        }
        .scrollIndicators(.visible)
        .background(PracticeTheme.sidebar)
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
        .onChange(of: model.activeLesson.id) { _, _ in narration.stop() }
        .onDisappear { narration.stop() }
    }

    private var narrationControls: some View {
        guideSection("Lesson narration", symbol: narration.state == .speaking ? "waveform.circle.fill" : "waveform.circle") {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(narration.sourceDescription(lessonID: model.activeLesson.id, contentHash: model.activeLesson.narrationContentHash)) · about \(narrationMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button {
                        if narration.state == .idle, model.isPreviewPlaying {
                            model.toggleExercisePreview()
                        }
                        narration.toggle(
                            lessonID: model.activeLesson.id,
                            contentHash: model.activeLesson.narrationContentHash,
                            text: model.activeLesson.narrationScript
                        )
                    } label: {
                        Label(narrationButtonTitle, systemImage: narrationButtonSymbol)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    if narration.state != .idle {
                        Button("Stop", systemImage: "stop.fill") { narration.stop() }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .quickHelp("Lesson narration", "Listen to the complete lesson explanation. Narration stops when you preview the exercise, change lessons, or leave class mode.")
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
        max(1, Int(ceil(Double(model.activeLesson.narrationScript.split(whereSeparator: \.isWhitespace).count) / 155)))
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
        return model.completedSourcePromptIndices.contains(index) ? "checkmark.circle.fill" : "circle"
    }

    private func routeColor(at index: Int) -> Color {
        if model.isPreviewPlaying && model.previewPromptIndex == index { return PracticeTheme.accent }
        return model.completedSourcePromptIndices.contains(index) ? .green : .secondary
    }

    private var activeRouteIndex: Int {
        model.previewPromptIndex ?? model.currentSourcePromptIndex
    }

    private func fingeringLabel(for prompt: PracticePrompt) -> String {
        prompt.fingerings
            .map { "\($0.hand.abbreviatedName) \($0.finger): \(noteName($0.pitch))" }
            .joined(separator: "  ")
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
                    Text("\(navigation.stageTitle.uppercased()) · CHAPTER \(navigation.chapterNumber)")
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
