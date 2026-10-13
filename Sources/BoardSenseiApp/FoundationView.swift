import SwiftUI

struct FoundationView: View {
    private let layers: [(String, String, String)] = [
        ("Native experience", "SwiftUI + SpriteKit", "macwindow.on.rectangle"),
        ("Apple integration", "CoreMIDI + AVAudioEngine", "pianokeys"),
        ("Course isolation", "Typed contexts + practice sessions", "square.stack.3d.up"),
        ("Stable boundary", "Small C ABI bridge", "arrow.left.arrow.right"),
        ("Portable engine", "Rust music-core", "gearshape.2"),
        ("Canonical timeline", "Ticks, tempo maps, tracks, events", "timeline.selection"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StudioPageHeader(
                    eyebrow: "Under the keys", title: "Foundation",
                    detail: "Built to grow past drills. A native workspace, a portable music engine, and one canonical timeline."
                )
                StudioRule()

                ForEach(Array(layers.enumerated()), id: \.offset) { index, layer in
                    HStack(spacing: 18) {
                        Image(systemName: layer.2)
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 54, height: 54)
                            .background(AppTheme.inset)
                            .overlay { Rectangle().strokeBorder(AppTheme.line) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(layer.0).font(.headline)
                            Text(layer.1).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("0\(index + 1)")
                            .font(.system(size: 28, weight: .light).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(18)
                    .studioPanel()
                }

                VStack(alignment: .leading, spacing: 12) {
                    StudioSectionLabel(title: "Real-time contract")
                    Divider()
                    Text("The CoreMIDI callback only normalizes and enqueues bounded events. It never touches the UI, database, file system, network, model inference, or audio render graph.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }
                .padding(20)
                .studioPanel()
            }
            .padding(28)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.canvas)
        .navigationTitle("Foundation")
    }
}
