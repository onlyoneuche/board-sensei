import MusicCore
import SwiftUI

struct MIDIDiagnosticsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MIDI Lab").font(.largeTitle.bold())
                    Text(model.connectionMessage).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Panic", systemImage: "exclamationmark.triangle") { model.audio.panic() }
                Button("Disconnect", systemImage: "eject") { model.disconnectMIDI() }
                    .disabled(model.selectedDeviceID == nil)
            }
            .padding(24)

            if model.selectedDeviceID != nil {
                MIDIControllerKeyboardView()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }

            HSplitView {
                deviceList.frame(minWidth: 280)
                eventLog.frame(minWidth: 420)
            }
        }
        .navigationTitle("MIDI Lab")
    }

    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Input sources", systemImage: "cable.connector").font(.headline)
            if model.devices.isEmpty {
                ContentUnavailableView(
                    "No MIDI input",
                    systemImage: "pianokeys.inverse",
                    description: Text("Connect a USB or Bluetooth MIDI keyboard. You can still test the lesson with its on-screen keys.")
                )
            } else {
                List(model.devices) { device in
                    Button { model.connect(to: device.id) } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name).fontWeight(.medium)
                                if let manufacturer = device.manufacturer {
                                    Text(manufacturer).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if model.selectedDeviceID == device.id {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    .accessibilityLabel("Connected")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
        .padding(20)
    }

    private var eventLog: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Latest 100 events", systemImage: "waveform.path.ecg").font(.headline)
                Spacer()
                Text("\(model.recentEvents.count)").monospacedDigit().foregroundStyle(.secondary)
            }
            if model.recentEvents.isEmpty {
                ContentUnavailableView(
                    "Waiting for notes",
                    systemImage: "waveform",
                    description: Text("Play your MIDI keyboard to inspect normalized events.")
                )
            } else {
                List(Array(model.recentEvents.enumerated()), id: \.offset) { _, event in
                    HStack {
                        Image(systemName: icon(for: event)).foregroundStyle(AppTheme.accent)
                        Text(event.displayText).font(.system(.body, design: .monospaced))
                        Spacer()
                        Text("\(event.timestamp)").font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(20)
    }

    private func icon(for event: NormalizedMIDIEvent) -> String {
        switch event {
        case .noteOn: "circle.fill"
        case .noteOff: "circle"
        case .sustain: "pedal.accelerator"
        case .controlChange: "slider.horizontal.3"
        }
    }
}
