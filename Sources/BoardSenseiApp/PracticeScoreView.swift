import MusicCore
import SwiftUI

struct PracticeScoreView: View {
    let exercise: HanonExercise
    let lessonTitle: String
    let activePromptIndex: Int
    let completedPromptIndices: Set<Int>

    private var systems: [ScoreSystem] {
        let promptsPerMeasure = exercise.score.promptsPerMeasure
        let measuresPerSystem = exercise.score.measuresPerSystem
        var measures: [ScoreMeasure] = []
        var promptIndex = 0
        while promptIndex < exercise.prompts.count {
            let end = min(promptIndex + promptsPerMeasure, exercise.prompts.count)
            measures.append(ScoreMeasure(
                number: measures.count + 1,
                prompts: (promptIndex..<end).map { ScorePrompt(index: $0, prompt: exercise.prompts[$0]) }
            ))
            promptIndex = end
        }
        return stride(from: 0, to: measures.count, by: measuresPerSystem).map { start in
            let end = min(start + measuresPerSystem, measures.count)
            return ScoreSystem(number: start / measuresPerSystem, measures: Array(measures[start..<end]))
        }
    }

    private var activeSystem: Int {
        let promptsPerSystem = exercise.score.promptsPerMeasure * exercise.score.measuresPerSystem
        return max(0, activePromptIndex / promptsPerSystem)
    }

    var body: some View {
        ScrollViewReader { proxy in
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(spacing: 12) {
                        ForEach(systems) { system in
                            ScoreSystemView(
                                system: system,
                                metadata: exercise.score,
                                activePromptIndex: activePromptIndex,
                                completedPromptIndices: completedPromptIndices,
                                canvasWidth: max(1_040, geometry.size.width - 16)
                            )
                            .frame(width: max(1_040, geometry.size.width - 16), height: 238)
                            .id(system.number)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: activeSystem) { _, newSystem in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(newSystem, anchor: .center)
                    }
                }
            }
        }
        .background(PracticeTheme.panel, in: RoundedRectangle(cornerRadius: 7))
        .overlay { RoundedRectangle(cornerRadius: 7).stroke(PracticeTheme.separator, lineWidth: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Complete engraved score for \(lessonTitle)")
    }
}

struct ScorePrompt: Sendable {
    let index: Int
    let prompt: PracticePrompt
}

struct ScoreMeasure: Sendable {
    let number: Int
    let prompts: [ScorePrompt]
}

struct ScoreSystem: Identifiable, Sendable {
    let number: Int
    let measures: [ScoreMeasure]
    var id: Int { number }
}

struct ScoreSystemView: View {
    let system: ScoreSystem
    let metadata: PracticeScoreMetadata
    let activePromptIndex: Int
    let completedPromptIndices: Set<Int>
    let canvasWidth: CGFloat

    private let staffSpacing: CGFloat = 8
    private let upperBottomLineY: CGFloat = 82
    private let lowerBottomLineY: CGFloat = 174
    private let staffStartX: CGFloat = 92
    private let rightInset: CGFloat = 18

    var body: some View {
        Canvas { context, size in
            drawBackground(context: &context, size: size)
            drawSystemFurniture(context: &context, size: size)
            drawMeasures(context: &context, size: size)
        }
        .accessibilityLabel("Score system \(system.number + 1), measures \(measureRangeLabel)")
    }

    private var measureRangeLabel: String {
        guard let first = system.measures.first?.number, let last = system.measures.last?.number else { return "" }
        return first == last ? "\(first)" : "\(first) through \(last)"
    }

    private func drawBackground(context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(PracticeTheme.panel))
    }

    private func drawSystemFurniture(context: inout GraphicsContext, size: CGSize) {
        let endX = size.width - rightInset
        for line in 0..<5 {
            let upperY = upperBottomLineY - CGFloat(line) * staffSpacing
            let lowerY = lowerBottomLineY - CGFloat(line) * staffSpacing
            strokeLine(context: &context, from: CGPoint(x: staffStartX, y: upperY), to: CGPoint(x: endX, y: upperY), width: 1)
            strokeLine(context: &context, from: CGPoint(x: staffStartX, y: lowerY), to: CGPoint(x: endX, y: lowerY), width: 1)
        }

        context.draw(
            Text("𝄞").font(.system(size: 51)).foregroundStyle(scoreInk),
            at: CGPoint(x: 55, y: 65),
            anchor: .center
        )
        context.draw(
            Text("𝄢").font(.system(size: 39)).foregroundStyle(scoreInk),
            at: CGPoint(x: 57, y: 159),
            anchor: .center
        )
        context.draw(
            Text("{").font(.system(size: 114, design: .serif)).foregroundStyle(scoreInk),
            at: CGPoint(x: 17, y: 111),
            anchor: .center
        )

        if system.number == 0 {
            let signature = metadata.timeSignature
            let signatureText = Text("\(signature.numerator)\n\(signature.denominator)")
                .font(.system(size: 19, weight: .bold, design: .serif))
                .foregroundStyle(scoreInk)
            context.draw(signatureText, at: CGPoint(x: 79, y: 66), anchor: .center)
            context.draw(signatureText, at: CGPoint(x: 79, y: 158), anchor: .center)
        }
    }

    private func drawMeasures(context: inout GraphicsContext, size: CGSize) {
        guard !system.measures.isEmpty else { return }
        let availableWidth = size.width - staffStartX - rightInset
        let measureWidth = availableWidth / CGFloat(system.measures.count)

        for (offset, measure) in system.measures.enumerated() {
            let startX = staffStartX + CGFloat(offset) * measureWidth
            let endX = startX + measureWidth
            drawBarline(context: &context, x: startX, measure: measure, atStart: true)
            drawMeasureNumber(context: &context, number: measure.number, x: startX + 5)
            drawMeasure(context: &context, measure: measure, startX: startX, endX: endX)
            drawBarline(context: &context, x: endX, measure: measure, atStart: false)
        }
    }

    private func drawMeasure(
        context: inout GraphicsContext,
        measure: ScoreMeasure,
        startX: CGFloat,
        endX: CGFloat
    ) {
        let count = max(1, measure.prompts.count)
        let usableStart = startX + 13
        let usableEnd = endX - 10
        let step = (usableEnd - usableStart) / CGFloat(count)
        let marks: [RenderedMark] = measure.prompts.enumerated().flatMap { position, scorePrompt in
            let x = usableStart + (CGFloat(position) + 0.5) * step
            return scorePrompt.prompt.fingerings.map { fingering in
                RenderedMark(
                    promptIndex: scorePrompt.index,
                    pitch: fingering.pitch,
                    hand: fingering.hand,
                    finger: fingering.finger,
                    noteValue: scorePrompt.prompt.noteValue,
                    x: x,
                    y: noteY(for: fingering.pitch)
                )
            }
        }

        for hand in [PianoHand.right, .left] {
            drawBeamGroup(context: &context, marks: marks.filter { $0.hand == hand })
        }
        for mark in marks {
            drawNote(context: &context, mark: mark)
        }
    }

    private func drawBeamGroup(context: inout GraphicsContext, marks: [RenderedMark]) {
        let beamed = marks.filter { $0.noteValue == .sixteenth }
        guard beamed.count > 1, let first = beamed.first, let last = beamed.last else { return }
        let beamY = first.hand == .right
            ? min(first.y, last.y) - 30
            : max(first.y, last.y) + 30
        let endBeamY = beamY + (last.y - first.y) * 0.18

        for mark in beamed {
            let progress = last.x == first.x ? 0 : (mark.x - first.x) / (last.x - first.x)
            let targetY = beamY + (endBeamY - beamY) * progress
            let stemX = mark.x + (mark.hand == .right ? 5.2 : -5.2)
            strokeLine(context: &context, from: CGPoint(x: stemX, y: mark.y), to: CGPoint(x: stemX, y: targetY), width: 1.4)
        }
        let firstStemX = first.x + (first.hand == .right ? 5.2 : -5.2)
        let lastStemX = last.x + (last.hand == .right ? 5.2 : -5.2)
        strokeLine(context: &context, from: CGPoint(x: firstStemX, y: beamY), to: CGPoint(x: lastStemX, y: endBeamY), width: 4.2)
        let secondOffset: CGFloat = first.hand == .right ? 6 : -6
        strokeLine(
            context: &context,
            from: CGPoint(x: firstStemX, y: beamY + secondOffset),
            to: CGPoint(x: lastStemX, y: endBeamY + secondOffset),
            width: 4.2
        )
    }

    private func drawNote(context: inout GraphicsContext, mark: RenderedMark) {
        let color = noteColor(promptIndex: mark.promptIndex)
        drawLedgerLines(context: &context, mark: mark, color: color)
        let rect = CGRect(x: mark.x - 5.8, y: mark.y - 3.7, width: 11.6, height: 7.4)
        let head = Path(ellipseIn: rect)
        if mark.noteValue == .half || mark.noteValue == .whole {
            context.fill(head, with: .color(PracticeTheme.panel))
            context.stroke(head, with: .color(color), lineWidth: 1.8)
        } else {
            context.fill(head, with: .color(color))
        }

        if mark.noteValue != .sixteenth {
            let stemX = mark.x + (mark.hand == .right ? 5.2 : -5.2)
            let stemEnd = mark.y + (mark.hand == .right ? -28 : 28)
            strokeLine(context: &context, from: CGPoint(x: stemX, y: mark.y), to: CGPoint(x: stemX, y: stemEnd), color: color, width: 1.4)
        }

        let fingerY = mark.hand == .right ? mark.y - 15 : mark.y + 15
        context.draw(
            Text(String(mark.finger)).font(.system(size: 8, weight: .bold)).foregroundStyle(color),
            at: CGPoint(x: mark.x, y: fingerY),
            anchor: .center
        )
    }

    private func drawLedgerLines(context: inout GraphicsContext, mark: RenderedMark, color: Color) {
        let bottomLinePitch: UInt8 = mark.pitch >= 60 ? 64 : 43
        let bottomY = mark.pitch >= 60 ? upperBottomLineY : lowerBottomLineY
        let step = diatonicIndex(mark.pitch) - diatonicIndex(bottomLinePitch)
        if step <= -2 {
            for ledger in stride(from: -2, through: step, by: -2) {
                let y = bottomY - CGFloat(ledger) * staffSpacing / 2
                strokeLine(context: &context, from: CGPoint(x: mark.x - 8, y: y), to: CGPoint(x: mark.x + 8, y: y), color: color, width: 1)
            }
        } else if step >= 10 {
            for ledger in stride(from: 10, through: step, by: 2) {
                let y = bottomY - CGFloat(ledger) * staffSpacing / 2
                strokeLine(context: &context, from: CGPoint(x: mark.x - 8, y: y), to: CGPoint(x: mark.x + 8, y: y), color: color, width: 1)
            }
        }
    }

    private func drawBarline(context: inout GraphicsContext, x: CGFloat, measure: ScoreMeasure, atStart: Bool) {
        strokeLine(context: &context, from: CGPoint(x: x, y: 50), to: CGPoint(x: x, y: 174), width: 1)
        guard let repeated = metadata.repeatSection else { return }
        let firstPrompt = measure.prompts.first?.index
        let lastPrompt = measure.prompts.last?.index
        let isRepeatStart = atStart && firstPrompt == repeated.startPromptIndex
        let isRepeatEnd = !atStart && lastPrompt == repeated.endPromptIndex
        guard isRepeatStart || isRepeatEnd else { return }

        let thickX = x + (isRepeatStart ? 4 : -4)
        strokeLine(context: &context, from: CGPoint(x: thickX, y: 50), to: CGPoint(x: thickX, y: 174), width: 3)
        let dotX = x + (isRepeatStart ? 10 : -10)
        for y in [66.0, 74.0, 158.0, 166.0] {
            context.fill(Path(ellipseIn: CGRect(x: dotX - 1.8, y: y - 1.8, width: 3.6, height: 3.6)), with: .color(scoreInk))
        }
    }

    private func drawMeasureNumber(context: inout GraphicsContext, number: Int, x: CGFloat) {
        context.draw(
            Text(String(number)).font(.system(size: 8, weight: .medium).monospacedDigit()).foregroundStyle(Color.white.opacity(0.55)),
            at: CGPoint(x: x, y: 29),
            anchor: .leading
        )
    }

    private func noteY(for pitch: UInt8) -> CGFloat {
        let bottomPitch: UInt8 = pitch >= 60 ? 64 : 43
        let bottomY = pitch >= 60 ? upperBottomLineY : lowerBottomLineY
        return bottomY - CGFloat(diatonicIndex(pitch) - diatonicIndex(bottomPitch)) * staffSpacing / 2
    }

    private func diatonicIndex(_ pitch: UInt8) -> Int {
        let degreeByPitchClass = [0: 0, 2: 1, 4: 2, 5: 3, 7: 4, 9: 5, 11: 6]
        let midi = Int(pitch)
        return (midi / 12) * 7 + (degreeByPitchClass[midi % 12] ?? 0)
    }

    private func noteColor(promptIndex: Int) -> Color {
        if promptIndex == activePromptIndex { return PracticeTheme.accent }
        if completedPromptIndices.contains(promptIndex) { return .green }
        return scoreInk
    }

    private var scoreInk: Color { Color.white.opacity(0.92) }

    private func strokeLine(
        context: inout GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        color: Color = Color.white.opacity(0.86),
        width: CGFloat
    ) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(color), lineWidth: width)
    }
}

private struct RenderedMark: Sendable {
    let promptIndex: Int
    let pitch: UInt8
    let hand: PianoHand
    let finger: UInt8
    let noteValue: PracticeNoteValue
    let x: CGFloat
    let y: CGFloat
}
