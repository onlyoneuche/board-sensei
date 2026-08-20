import SwiftUI

struct FoundationView: View {
    private let layers: [(String, String, String)] = [
        ("Native experience", "SwiftUI + SpriteKit", "macwindow.on.rectangle"),
        ("Apple integration", "CoreMIDI + AVAudioEngine", "pianokeys"),
        ("Stable boundary", "Small C ABI bridge", "arrow.left.arrow.right"),
        ("Portable engine", "Rust music-core", "gearshape.2"),
        ("Canonical timeline", "Ticks, tempo maps, tracks, events", "timeline.selection"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Built to grow past drills").font(.largeTitle.bold())
                    Text("The first lesson is intentionally small; the underlying model is ready for MIDI files, MusicXML, transport, looping, and later audio analysis.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(Array(layers.enumerated()), id: \.offset) { index, layer in
                    HStack(spacing: 18) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppTheme.accent.opacity(0.12))
                                .frame(width: 54, height: 54)
                            Image(systemName: layer.2).font(.title2).foregroundStyle(AppTheme.accent)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(layer.0).font(.headline)
                            Text(layer.1).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("0\(index + 1)")
                            .font(.title2.monospacedDigit().bold())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                }

                GroupBox("Real-time contract") {
                    Text("The CoreMIDI callback only normalizes and enqueues bounded events. It never touches the UI, database, file system, network, model inference, or audio render graph.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }
            }
            .padding(28)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Foundation")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
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
        .padding()
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
