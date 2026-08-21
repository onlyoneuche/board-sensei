import MusicCore
import SwiftUI

struct PianoKeyboardView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var hasKeyboardFocus: Bool
    @AppStorage(KeyboardIndicatorPreferences.expectedKey)
    private var expectedIndicatorHex = KeyboardIndicatorPreferences.defaultExpectedHex
    @AppStorage(KeyboardIndicatorPreferences.activeKey)
    private var activeIndicatorHex = KeyboardIndicatorPreferences.defaultActiveHex

    private let minimumKeyboardWidth: CGFloat = 1_080
    private let keyboardHeight: CGFloat = 190

    private var allKeys: [PianoKey] {
        (36...96).map { note in
            PianoKey(
                note: UInt8(note),
                shortcut: Self.shortcuts[UInt8(note)],
                isBlack: Self.blackPitchClasses.contains(note % 12)
            )
        }
    }

    private var whiteKeys: [PianoKey] { allKeys.filter { !$0.isBlack } }
    private var blackKeys: [PianoKey] { allKeys.filter(\.isBlack) }

    private static let blackPitchClasses: Set<Int> = [1, 3, 6, 8, 10]
    private static let shortcuts: [UInt8: String] = [
        60: "A", 61: "W", 62: "S", 63: "E", 64: "D", 65: "F",
        66: "T", 67: "G", 68: "Y", 69: "H", 70: "U", 71: "J", 72: "K",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Five-octave practice piano").font(.headline)
                Spacer()
                Label(
                    hasKeyboardFocus ? "Computer keys active" : "Click piano to enable keys",
                    systemImage: hasKeyboardFocus ? "keyboard.fill" : "keyboard"
                )
                .font(.caption)
                .foregroundStyle(hasKeyboardFocus ? PracticeTheme.accent : Color.secondary)
            }

            HStack(spacing: 14) {
                GeometryReader { available in
                    ScrollView(.horizontal) {
                        pianoSurface(width: max(available.size.width, minimumKeyboardWidth))
                    }
                    .scrollIndicators(.hidden)
                }
                .frame(height: keyboardHeight)

                AudioControlPanel(audio: model.audio)
                    .frame(width: 104, height: keyboardHeight)
            }
            .focusable()
            .focused($hasKeyboardFocus)
            .focusEffectDisabled()
            .onAppear { hasKeyboardFocus = true }
            .onTapGesture { hasKeyboardFocus = true }
            .onKeyPress(phases: [.down, .up]) { keyPress in
                guard let key = key(for: keyPress.characters) else { return .ignored }
                if keyPress.phase == .down {
                    press(key)
                } else if keyPress.phase == .up {
                    release(key)
                }
                return .handled
            }
            .accessibilityLabel("Five-octave practice piano with output level and volume")
            .accessibilityHint("Use a MIDI controller, the labeled computer keys, or interact with individual piano keys.")
            .quickHelp(
                "Practice piano",
                "Use a MIDI controller, click and hold a key, or use A–K around middle C. Highlighted keys match the staff prompt."
            )
        }
        .padding(14)
        .practicePanel()
    }

    private func pianoSurface(width: CGFloat) -> some View {
        let spacing: CGFloat = 1.5
        let whiteWidth = (width - spacing * CGFloat(whiteKeys.count - 1)) / CGFloat(whiteKeys.count)
        let blackWidth = whiteWidth * 0.66

        return ZStack(alignment: .topLeading) {
            HStack(spacing: spacing) {
                ForEach(whiteKeys) { key in
                    keyView(key)
                        .frame(width: whiteWidth, height: keyboardHeight)
                }
            }

            ForEach(blackKeys) { key in
                let precedingWhiteKeys = whiteKeys.filter { $0.note < key.note }.count
                keyView(key)
                    .frame(width: blackWidth, height: keyboardHeight * 0.62)
                    .offset(
                        x: CGFloat(precedingWhiteKeys) * (whiteWidth + spacing)
                            - blackWidth / 2 - spacing / 2
                    )
                    .zIndex(2)
            }
        }
        .frame(width: width, height: keyboardHeight)
        .background(Color.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func keyView(_ key: PianoKey) -> some View {
        PianoKeyView(
            key: key,
            isActive: model.activeNotes.contains(key.note) || model.previewPitches.contains(key.note),
            isExpected: model.displayedPitches.contains(key.note),
            expectedIndicatorColor: KeyboardIndicatorPreferences.color(
                from: expectedIndicatorHex,
                fallback: KeyboardIndicatorPreferences.defaultExpectedHex
            ),
            activeIndicatorColor: KeyboardIndicatorPreferences.color(
                from: activeIndicatorHex,
                fallback: KeyboardIndicatorPreferences.defaultActiveHex
            ),
            onPress: { press(key) },
            onRelease: { release(key) },
            onAccessibleActivate: { model.simulate(note: key.note) }
        )
    }

    private func key(for characters: String) -> PianoKey? {
        guard let character = characters.uppercased().first else { return nil }
        return allKeys.first { $0.shortcut?.first == character }
    }

    private func press(_ key: PianoKey) {
        hasKeyboardFocus = true
        model.beginSimulatedNote(note: key.note)
    }

    private func release(_ key: PianoKey) {
        model.endSimulatedNote(note: key.note)
    }
}

private struct PianoKey: Identifiable, Equatable {
    let note: UInt8
    let shortcut: String?
    let isBlack: Bool
    var id: UInt8 { note }
}

private struct PianoKeyView: View {
    let key: PianoKey
    let isActive: Bool
    let isExpected: Bool
    let expectedIndicatorColor: Color
    let activeIndicatorColor: Color
    let onPress: () -> Void
    let onRelease: () -> Void
    let onAccessibleActivate: () -> Void
    @State private var isPointerDown = false

    var body: some View {
        ZStack(alignment: .bottom) {
            keyShape
                .fill(keyFillColor)
                .shadow(color: .black.opacity(key.isBlack ? 0.34 : 0.16), radius: 2, y: 2)

            keyShape
                .stroke(keyBorderColor, lineWidth: isActive || isExpected ? 2 : 1)

            VStack(spacing: 4) {
                if isActive || isExpected {
                    Image(systemName: isActive ? "circle.inset.filled" : "scope")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(labelColor)
                }
                if shouldShowNoteName {
                    Text(noteName(key.note)).font(.system(size: 9, weight: .bold))
                }
                if let shortcut = key.shortcut {
                    Text(shortcut)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(labelColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                }
            }
            .foregroundStyle(labelColor)
            .padding(.bottom, key.isBlack ? 7 : 9)
        }
        .contentShape(Rectangle())
        .scaleEffect(isActive ? CGSize(width: 0.98, height: 0.975) : CGSize(width: 1, height: 1), anchor: .top)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPointerDown else { return }
                    isPointerDown = true
                    onPress()
                }
                .onEnded { _ in
                    guard isPointerDown else { return }
                    isPointerDown = false
                    onRelease()
                }
        )
        .onDisappear {
            if isPointerDown {
                isPointerDown = false
                onRelease()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(noteName(key.note))\(key.shortcut.map { ", computer key \($0)" } ?? "")")
        .accessibilityValue(isActive ? "Pressed" : isExpected ? "Expected note" : "Not pressed")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onAccessibleActivate() }
    }

    private var keyShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: key.isBlack ? 5 : 4)
    }

    private var keyFillColor: Color {
        if isActive { return activeIndicatorColor }
        if isExpected { return expectedIndicatorColor }
        return key.isBlack ? .black : .white
    }

    private var keyBorderColor: Color {
        if isActive || isExpected { return labelColor.opacity(0.72) }
        return key.isBlack ? Color.white.opacity(0.16) : Color.black.opacity(0.35)
    }

    private var labelColor: Color {
        if isActive { return KeyboardIndicatorPreferences.contrastingText(for: activeIndicatorColor) }
        if isExpected { return KeyboardIndicatorPreferences.contrastingText(for: expectedIndicatorColor) }
        return key.isBlack ? .white : .black
    }

    private var shouldShowNoteName: Bool {
        key.shortcut != nil || (!key.isBlack && Int(key.note) % 12 == 0)
    }
}
