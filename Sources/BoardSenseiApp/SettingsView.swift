import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(KeyboardIndicatorPreferences.expectedKey)
    private var expectedHex = KeyboardIndicatorPreferences.defaultExpectedHex
    @AppStorage(KeyboardIndicatorPreferences.activeKey)
    private var activeHex = KeyboardIndicatorPreferences.defaultActiveHex

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    StudioPageHeader(eyebrow: "Studio preferences", title: "Settings", detail: "Make the workspace feel like your instrument.")
                    settingsSection("Keyboard indicators", symbol: "pianokeys") {
                        ColorPicker("Expected notes", selection: expectedColorBinding, supportsOpacity: false)
                        ColorPicker("Pressed and preview notes", selection: activeColorBinding, supportsOpacity: false)

                        indicatorPreview

                        HStack {
                            Text("Changes are saved automatically and applied to every lesson.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Restore Defaults", systemImage: "arrow.counterclockwise") {
                                expectedHex = KeyboardIndicatorPreferences.defaultExpectedHex
                                activeHex = KeyboardIndicatorPreferences.defaultActiveHex
                            }
                        }
                    }

                    settingsSection("Audio", symbol: "speaker.wave.2") {
                        AudioSettingsControls(audio: model.audio)
                    }

                    settingsSection("Learning experience", symbol: "graduationcap") {
                        Picker("Practice goal", selection: learningGoalBinding) {
                            ForEach(LearningGoal.allCases) { goal in
                                Text(goal.rawValue).tag(goal)
                            }
                        }
                        Picker("Starting point", selection: learnerExperienceBinding) {
                            ForEach(LearnerExperience.allCases) { experience in
                                Text(experience.rawValue).tag(experience)
                            }
                        }
                        Toggle("Completion sounds", isOn: celebrationSoundsBinding)
                        Toggle("Animated celebrations", isOn: animatedCelebrationsBinding)
                        Toggle("Practice-day rhythm", isOn: practiceStreaksBinding)

                        HStack {
                            Text("Practice-day rhythm updates only when a lesson is completed.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Run Onboarding Again", systemImage: "sparkles") {
                                model.restartOnboarding()
                            }
                        }
                    }

                    settingsSection("Practice engine", symbol: "cpu") {
                        LabeledContent("Active core", value: model.isUsingRust ? "Rust" : "Native fallback")
                        Text("Build the Rust library before launching to activate the portable engine automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(28)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .background(AppTheme.canvas)
            .tint(AppTheme.accent)
            .toggleStyle(.switch)
            .navigationTitle("Settings")
        }
    }

    private func settingsSection<Content: View>(
        _ title: String, symbol: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: symbol).foregroundStyle(AppTheme.accent)
                StudioSectionLabel(title: title)
            }
            Divider()
            content()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioPanel()
    }

    private var indicatorPreview: some View {
        HStack(spacing: 20) {
            indicatorSample(
                title: "Expected",
                isBlackKey: false,
                indicatorColor: expectedColor,
                note: "C4"
            )
            indicatorSample(
                title: "Pressed / preview",
                isBlackKey: true,
                indicatorColor: activeColor,
                note: "C♯4"
            )
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func indicatorSample(
        title: String,
        isBlackKey: Bool,
        indicatorColor: Color,
        note: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: AppTheme.radius)
                .fill(indicatorColor)
                .frame(width: 76, height: 100)
                .overlay {
                    Text(note)
                        .font(.caption.bold().monospaced())
                        .foregroundStyle(KeyboardIndicatorPreferences.contrastingText(for: indicatorColor))
                        .padding(.top, 62)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.radius)
                        .stroke(isBlackKey ? Color.white.opacity(0.3) : Color.black.opacity(0.45))
                }
        }
    }

    private var expectedColor: Color {
        KeyboardIndicatorPreferences.color(
            from: expectedHex,
            fallback: KeyboardIndicatorPreferences.defaultExpectedHex
        )
    }

    private var activeColor: Color {
        KeyboardIndicatorPreferences.color(
            from: activeHex,
            fallback: KeyboardIndicatorPreferences.defaultActiveHex
        )
    }

    private var expectedColorBinding: Binding<Color> {
        Binding(
            get: { expectedColor },
            set: {
                expectedHex = KeyboardIndicatorPreferences.hex(
                    from: $0,
                    fallback: KeyboardIndicatorPreferences.defaultExpectedHex
                )
            }
        )
    }

    private var activeColorBinding: Binding<Color> {
        Binding(
            get: { activeColor },
            set: {
                activeHex = KeyboardIndicatorPreferences.hex(
                    from: $0,
                    fallback: KeyboardIndicatorPreferences.defaultActiveHex
                )
            }
        )
    }

    private var learningGoalBinding: Binding<LearningGoal> {
        Binding(
            get: { model.learningGoal },
            set: { value in model.chooseLearningGoal(value) }
        )
    }

    private var learnerExperienceBinding: Binding<LearnerExperience> {
        Binding(
            get: { model.learnerExperience },
            set: { value in model.chooseLearnerExperience(value) }
        )
    }

    private var celebrationSoundsBinding: Binding<Bool> {
        Binding(
            get: { model.celebrationSoundsEnabled },
            set: { value in model.setCelebrationSoundsEnabled(value) }
        )
    }

    private var animatedCelebrationsBinding: Binding<Bool> {
        Binding(
            get: { model.animatedCelebrationsEnabled },
            set: { value in model.setAnimatedCelebrationsEnabled(value) }
        )
    }

    private var practiceStreaksBinding: Binding<Bool> {
        Binding(
            get: { model.practiceStreaksEnabled },
            set: { value in model.setPracticeStreaksEnabled(value) }
        )
    }
}

private struct AudioSettingsControls: View {
    @ObservedObject var audio: AudioService

    var body: some View {
        Toggle("Monitor MIDI through app", isOn: $audio.monitoringEnabled)
        LabeledContent("Engine", value: audio.status)
        Button("Stop all notes", systemImage: "exclamationmark.triangle") { audio.panic() }
    }
}
