import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(KeyboardIndicatorPreferences.expectedKey)
    private var expectedHex = KeyboardIndicatorPreferences.defaultExpectedHex
    @AppStorage(KeyboardIndicatorPreferences.activeKey)
    private var activeHex = KeyboardIndicatorPreferences.defaultActiveHex

    var body: some View {
        NavigationStack {
            Form {
                Section("Keyboard indicators") {
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

                Section("Audio") {
                    AudioSettingsControls(audio: model.audio)
                }

                Section("Practice engine") {
                    LabeledContent("Active core", value: model.isUsingRust ? "Rust" : "Native fallback")
                    Text("Build the Rust library before launching to activate the portable engine automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
        }
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
            RoundedRectangle(cornerRadius: 6)
                .fill(indicatorColor)
                .frame(width: 76, height: 100)
                .overlay {
                    Text(note)
                        .font(.caption.bold().monospaced())
                        .foregroundStyle(KeyboardIndicatorPreferences.contrastingText(for: indicatorColor))
                        .padding(.top, 62)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
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
}

private struct AudioSettingsControls: View {
    @ObservedObject var audio: AudioService

    var body: some View {
        Toggle("Monitor MIDI through app", isOn: $audio.monitoringEnabled)
        LabeledContent("Engine", value: audio.status)
        Button("Stop all notes", systemImage: "exclamationmark.triangle") { audio.panic() }
    }
}
