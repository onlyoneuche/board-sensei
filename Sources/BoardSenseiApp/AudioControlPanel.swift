import SwiftUI

struct AudioControlPanel: View {
    @ObservedObject var audio: AudioService

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 6) {
                Text("LEVEL")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                VerticalLevelMeter(level: audio.outputLevel)
                instrumentMenu
            }

            VStack(spacing: 6) {
                Text("VOLUME")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                VerticalVolumeSlider(value: $audio.volume)
                Text("\(Int(audio.volume * 100))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(PracticeTheme.raised, in: RoundedRectangle(cornerRadius: 6))
        .overlay { RoundedRectangle(cornerRadius: 6).stroke(PracticeTheme.separator, lineWidth: 1) }
    }

    private var instrumentMenu: some View {
        Menu {
            ForEach(PracticeInstrumentCategory.allCases) { category in
                Section(category.rawValue) {
                    ForEach(PracticeInstrument.allCases.filter { $0.category == category }) { instrument in
                        Button {
                            audio.selectInstrument(instrument)
                        } label: {
                            if instrument == audio.selectedInstrument {
                                Label(instrument.name, systemImage: "checkmark")
                            } else {
                                Text(instrument.name)
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: audio.selectedInstrument.symbol)
                .font(.caption2)
                .foregroundStyle(PracticeTheme.accent)
                .frame(width: 24, height: 18)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Practice sound: \(audio.selectedInstrument.name)")
        .accessibilityLabel("Practice sound")
        .accessibilityValue(audio.selectedInstrument.name)
        .quickHelp(
            "Practice sound",
            "Choose a grand piano, electric piano, synth lead, or synth pad for both live playing and exercise playback."
        )
    }
}

private struct VerticalLevelMeter: View {
    let level: Float
    private let segmentCount = 18

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array((0..<segmentCount).reversed()), id: \.self) { index in
                Capsule()
                    .fill(segmentColor(index).opacity(isLit(index) ? 1 : 0.14))
                    .frame(width: 13, height: 5)
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Output level")
        .accessibilityValue("\(Int(level * 100)) percent")
    }

    private func isLit(_ index: Int) -> Bool {
        level >= Float(index + 1) / Float(segmentCount)
    }

    private func segmentColor(_ index: Int) -> Color {
        if index >= 15 { return .red }
        if index >= 12 { return .yellow }
        return .green
    }
}

private struct VerticalVolumeSlider: View {
    @Binding var value: Float

    var body: some View {
        GeometryReader { geometry in
            let thumbSize: CGFloat = 18
            let usableHeight = geometry.size.height - thumbSize
            let thumbY = (1 - CGFloat(value)) * usableHeight

            ZStack(alignment: .top) {
                Capsule()
                    .fill(Color.secondary.opacity(0.24))
                    .frame(width: 6)
                    .frame(maxHeight: .infinity)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Capsule()
                        .fill(PracticeTheme.accent)
                        .frame(width: 6, height: max(3, CGFloat(value) * usableHeight))
                }

                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay { Circle().stroke(PracticeTheme.accent, lineWidth: 2) }
                    .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(y: thumbY)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        value = Float(min(max(1 - gesture.location.y / geometry.size.height, 0), 1))
                    }
            )
        }
        .frame(width: 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Output volume")
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 0.05, 1)
            case .decrement: value = max(value - 0.05, 0)
            @unknown default: break
            }
        }
    }
}
