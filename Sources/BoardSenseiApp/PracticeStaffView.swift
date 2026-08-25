import AppKit
import MusicCore
import SpriteKit
import SwiftUI

struct PracticeStaffView: View {
    let expectedPitches: [UInt8]
    let feedback: PracticeFeedback
    let layout: NotationStaffLayout
    let jazzPracticeKey: JazzPracticeKey
    let reduceMotion: Bool
    @State private var scene = PracticeStaffScene()

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay { RoundedRectangle(cornerRadius: 7).stroke(PracticeTheme.separator, lineWidth: 1) }
            .onAppear { updateScene() }
            .onChange(of: expectedPitches) { _, _ in updateScene() }
            .onChange(of: feedback) { _, _ in updateScene() }
            .onChange(of: layout) { _, _ in updateScene() }
            .onChange(of: jazzPracticeKey) { _, _ in updateScene() }
            .onChange(of: reduceMotion) { _, _ in updateScene() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityStaffName)
            .accessibilityValue("Expected \(expectedPitches.map(noteName).joined(separator: " plus ")). \(feedback.title).")
    }

    private var accessibilityStaffName: String {
        switch layout {
        case .treble: "Treble staff"
        case .bass: "Bass staff"
        case .grand: "Grand staff with treble and bass clefs"
        }
    }

    private func updateScene() {
<<<<<<< Updated upstream
        scene.show(pitches: expectedPitches, feedback: feedback, layout: layout, reduceMotion: reduceMotion)
=======
        scene.show(
            pitches: expectedPitches,
            fingerings: fingerings,
            feedback: feedback,
            layout: layout,
            jazzPracticeKey: jazzPracticeKey,
            reduceMotion: reduceMotion
        )
    }

    private var accessibilityValue: String {
        let notes = expectedPitches.map(displayName).joined(separator: " plus ")
        let fingers = fingerings.map { "\($0.hand.abbreviatedName) finger \($0.finger) on \(displayName($0.pitch))" }
            .joined(separator: ", ")
        return "Expected \(notes). \(fingers). \(feedback.title)."
>>>>>>> Stashed changes
    }

    private func displayName(_ pitch: UInt8) -> String {
        jazzPracticeKey.noteName(for: pitch)
    }
}

final class PracticeStaffScene: SKScene {
    private enum Clef {
        case treble
        case bass

        var symbol: String { self == .treble ? "𝄞" : "𝄢" }
        var bottomLinePitch: UInt8 { self == .treble ? 64 : 43 }
    }

    private let content = SKNode()
    private var pitches: [UInt8] = [60]
    private var feedback: PracticeFeedback = .waiting
    private var layout: NotationStaffLayout = .treble
    private var jazzPracticeKey = JazzPracticeKey.c
    private var reduceMotion = false

    override init(size: CGSize = CGSize(width: 900, height: 420)) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
        addChild(content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        view.allowsTransparency = true
        render()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        render()
    }

    func show(
        pitches: [UInt8],
        feedback: PracticeFeedback,
        layout: NotationStaffLayout,
        jazzPracticeKey: JazzPracticeKey,
        reduceMotion: Bool
    ) {
        let feedbackChanged = self.feedback != feedback
        self.pitches = pitches
        self.feedback = feedback
        self.layout = layout
        self.jazzPracticeKey = jazzPracticeKey
        self.reduceMotion = reduceMotion
        render(animateFeedback: feedbackChanged)
    }

    private func render(animateFeedback: Bool = false) {
        content.removeAllChildren()
        guard size.width > 0, size.height > 0 else { return }

        let panel = SKShapeNode(rectOf: size, cornerRadius: 7)
        panel.fillColor = PracticeTheme.panelNSColor
        panel.strokeColor = .clear
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        panel.zPosition = -10
        content.addChild(panel)

        switch layout {
        case .treble:
            drawStaff(clef: .treble, centerY: size.height * 0.55, pitches: pitches, animateFeedback: animateFeedback)
        case .bass:
            drawStaff(clef: .bass, centerY: size.height * 0.55, pitches: pitches, animateFeedback: animateFeedback)
        case .grand:
            drawGrandStaff(animateFeedback: animateFeedback)
        }

        let label = SKLabelNode(text: pitches.map(noteName).joined(separator: " + "))
        label.fontName = NSFont.systemFont(ofSize: 18, weight: .semibold).fontName
        label.fontSize = 18
        label.fontColor = .secondaryLabelColor
        label.position = CGPoint(x: size.width * 0.58, y: max(18, size.height * 0.07))
        content.addChild(label)
    }

<<<<<<< Updated upstream
=======
    private var promptLabel: String {
        pitches.map { pitch in
            let fingering = fingerings.first { $0.pitch == pitch }
            let suffix = fingering.map { " (\($0.hand.abbreviatedName) \($0.finger))" } ?? ""
            return "\(jazzPracticeKey.noteName(for: pitch))\(suffix)"
        }
        .joined(separator: " + ")
    }

>>>>>>> Stashed changes
    private func drawGrandStaff(animateFeedback: Bool) {
        let trebleCenter = size.height * 0.69
        let bassCenter = size.height * 0.34
        drawStaff(
            clef: .treble,
            centerY: trebleCenter,
            pitches: pitches.filter { $0 >= 60 },
            animateFeedback: animateFeedback
        )
        drawStaff(
            clef: .bass,
            centerY: bassCenter,
            pitches: pitches.filter { $0 < 60 },
            animateFeedback: animateFeedback
        )

        let brace = SKLabelNode(text: "{")
        brace.fontName = NSFont(name: "Times New Roman", size: min(190, size.height * 0.34))?.fontName
        brace.fontSize = min(190, size.height * 0.34)
        brace.fontColor = NSColor.labelColor.withAlphaComponent(0.8)
        brace.verticalAlignmentMode = .center
        brace.position = CGPoint(x: size.width * 0.095, y: (trebleCenter + bassCenter) / 2)
        brace.xScale = 0.56
        content.addChild(brace)
    }

    private func drawStaff(clef: Clef, centerY: CGFloat, pitches: [UInt8], animateFeedback: Bool) {
        let lineSpacing = staffLineSpacing
        let startX = size.width * 0.13
        let endX = size.width * 0.9

        for offset in -2...2 {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: startX, y: centerY + CGFloat(offset) * lineSpacing))
            path.addLine(to: CGPoint(x: endX, y: centerY + CGFloat(offset) * lineSpacing))
            let line = SKShapeNode(path: path)
            line.strokeColor = NSColor.labelColor.withAlphaComponent(0.55)
            line.lineWidth = 2
            content.addChild(line)
        }

        let clefNode = SKLabelNode(text: clef.symbol)
        clefNode.fontName = NSFont(name: "Apple Symbols", size: lineSpacing * (clef == .treble ? 4.9 : 3.5))?.fontName
            ?? NSFont.systemFont(ofSize: lineSpacing * 4).fontName
        clefNode.fontSize = lineSpacing * (clef == .treble ? 4.9 : 3.5)
        clefNode.fontColor = .labelColor
        clefNode.verticalAlignmentMode = .center
        clefNode.position = CGPoint(
            x: size.width * 0.2,
            y: centerY + (clef == .treble ? -lineSpacing * 0.3 : lineSpacing * 0.15)
        )
        content.addChild(clefNode)

        let bottomLineY = centerY - lineSpacing * 2
        let sortedPitches = pitches.sorted()
        for (index, pitch) in sortedPitches.enumerated() {
            let step = diatonicDistance(from: clef.bottomLinePitch, to: pitch)
            let noteY = bottomLineY + CGFloat(step) * lineSpacing / 2
            let color = noteColor(for: pitch)
            let noteHead = SKShapeNode(ellipseOf: CGSize(width: lineSpacing * 1.3, height: lineSpacing * 0.88))
            noteHead.fillColor = color
            noteHead.strokeColor = color
            noteHead.position = CGPoint(x: size.width * 0.58 + CGFloat(index % 2) * lineSpacing * 0.28, y: noteY)
            noteHead.zRotation = -.pi / 10
            noteHead.name = "expected-note"
            content.addChild(noteHead)

            if isAccidental(pitch) {
                let accidental = SKLabelNode(text: jazzPracticeKey.prefersFlats ? "♭" : "♯")
                accidental.fontName = NSFont(name: "Times New Roman", size: lineSpacing * 1.35)?.fontName
                    ?? NSFont.systemFont(ofSize: lineSpacing * 1.2).fontName
                accidental.fontSize = lineSpacing * 1.35
                accidental.fontColor = .labelColor
                accidental.horizontalAlignmentMode = .center
                accidental.verticalAlignmentMode = .center
                accidental.position = CGPoint(
                    x: noteHead.position.x - lineSpacing * 0.95,
                    y: noteY
                )
                content.addChild(accidental)
            }

            let stemPath = CGMutablePath()
            stemPath.move(to: CGPoint(x: lineSpacing * 0.58, y: 0))
            stemPath.addLine(to: CGPoint(x: lineSpacing * 0.58, y: lineSpacing * 3.1))
            let stem = SKShapeNode(path: stemPath)
            stem.strokeColor = color
            stem.lineWidth = 3
            noteHead.addChild(stem)

            addLedgerLines(step: step, x: noteHead.position.x, bottomLineY: bottomLineY, spacing: lineSpacing)

            if animateFeedback && !reduceMotion {
                noteHead.setScale(0.72)
                noteHead.run(.sequence([
                    .scale(to: 1.18, duration: 0.12),
                    .scale(to: 1, duration: 0.12),
                ]))
            }
        }
    }

    private var staffLineSpacing: CGFloat {
        switch layout {
        case .grand: min(27, max(18, size.height / 18))
        case .treble, .bass: min(36, max(22, size.height / 10))
        }
    }

    private func noteColor(for pitch: UInt8) -> NSColor {
        switch feedback {
        case .waiting: PracticeTheme.accentNSColor
        case let .correct(notes): notes.contains(pitch) ? .systemGreen : PracticeTheme.accentNSColor
        case .incorrect: .systemOrange
        }
    }

    private func diatonicDistance(from lowerPitch: UInt8, to upperPitch: UInt8) -> Int {
        diatonicIndex(for: upperPitch) - diatonicIndex(for: lowerPitch)
    }

    private func diatonicIndex(for midiPitch: UInt8) -> Int {
        let naturalSteps = [0: 0, 2: 1, 4: 2, 5: 3, 7: 4, 9: 5, 11: 6]
        let midi = Int(midiPitch)
        let octave = midi / 12 - 1
        let pitchClass = midi % 12
        let naturalPitchClass: Int
        if naturalSteps[pitchClass] != nil {
            naturalPitchClass = pitchClass
        } else if jazzPracticeKey.prefersFlats {
            naturalPitchClass = [1: 2, 3: 4, 6: 7, 8: 9, 10: 11][pitchClass] ?? 0
        } else {
            naturalPitchClass = [1: 0, 3: 2, 6: 5, 8: 7, 10: 9][pitchClass] ?? 0
        }
        return octave * 7 + (naturalSteps[naturalPitchClass] ?? 0)
    }

    private func isAccidental(_ pitch: UInt8) -> Bool {
        [1, 3, 6, 8, 10].contains(Int(pitch) % 12)
    }

    private func addLedgerLines(step: Int, x: CGFloat, bottomLineY: CGFloat, spacing: CGFloat) {
        if step <= -2 {
            for ledgerStep in stride(from: -2, through: step, by: -2) {
                addLedgerLine(x: x, y: bottomLineY + CGFloat(ledgerStep) * spacing / 2, spacing: spacing)
            }
        } else if step >= 10 {
            for ledgerStep in stride(from: 10, through: step, by: 2) {
                addLedgerLine(x: x, y: bottomLineY + CGFloat(ledgerStep) * spacing / 2, spacing: spacing)
            }
        }
    }

    private func addLedgerLine(x: CGFloat, y: CGFloat, spacing: CGFloat) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x - spacing, y: y))
        path.addLine(to: CGPoint(x: x + spacing, y: y))
        let line = SKShapeNode(path: path)
        line.strokeColor = NSColor.labelColor.withAlphaComponent(0.55)
        line.lineWidth = 2
        content.addChild(line)
    }
}
