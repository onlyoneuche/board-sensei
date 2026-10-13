import MusicCore
import SwiftUI

struct MIDIDiagnosticsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                StudioPageHeader(eyebrow: "Instrument connection", title: "MIDI Lab", detail: model.connectionMessage)
                Spacer()
                Button("Panic", systemImage: "exclamationmark.triangle") { model.audio.panic() }
                Button("Disconnect", systemImage: "eject") { model.disconnectMIDI() }
                    .disabled(model.selectedDeviceID == nil)
            }
            .padding(28)
            StudioRule().padding(.horizontal, 28)

            if model.selectedDeviceID != nil {
                MIDIControllerKeyboardView()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .padding(.top, 20)
                    .transition(.opacity)
            }

            HSplitView {
                deviceList.frame(minWidth: 230)
                eventLog.frame(minWidth: 340)
            }
            .padding(24)
        }
        .background(AppTheme.canvas)
        .navigationTitle("MIDI Lab")
    }

    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StudioSectionLabel(title: "Input sources")
                Spacer()
                Image(systemName: "cable.connector").foregroundStyle(AppTheme.accent)
            }
            Divider()
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
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .studioPanel()
    }

    private var eventLog: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StudioSectionLabel(title: "Event monitor")
                Spacer()
                Text("\(model.recentEvents.count) / 100").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
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
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .studioPanel()
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
