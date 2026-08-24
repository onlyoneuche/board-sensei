import MusicCore
import SwiftUI

struct PracticeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            PracticeTheme.workspace.ignoresSafeArea()

            GeometryReader { geometry in
                VStack(spacing: 10) {
                    ScrollView {
                        VStack(spacing: 10) {
                            header
                            progressCard
                            completeScoreStrip
                            if !model.isHanonLesson {
                                PracticeStaffView(
                                    expectedPitches: model.displayedPitches,
                                    fingerings: model.displayedFingerings,
                                    feedback: model.displayedFeedback,
                                    layout: model.activeLesson.staffLayout,
                                    reduceMotion: reduceMotion
                                )
                                .frame(height: staffHeight(for: geometry.size.height))
                                .layoutPriority(1)
                                .quickHelp(
                                    "Notation",
                                    "The staff follows the active prompt, shows supplied finger numbers, and switches between treble, bass, or grand staff for the lesson range."
                                )
                            }
                            feedbackPanel
                            if let result = model.lessonCompletionResult {
                                LessonCompletionPanel(result: result)
                                    .id(result.id)
                                    .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        .frame(maxWidth: .infinity)
                    }

                    PianoKeyboardView()
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                }
            }
        }
        .navigationTitle("Practice")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text(model.activeLesson.title)
                    .font(.system(size: 28, weight: .semibold))
                Text("\(staffLabel) · \(model.practicePromptCount) selected prompts")
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if let mastery = model.mastery(for: model.activeLesson) {
                Label(mastery.title, systemImage: masterySymbol(mastery))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(mastery == .mastered ? AppTheme.accent : Color.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PracticeTheme.raised, in: RoundedRectangle(cornerRadius: 5))
                    .accessibilityLabel("Lesson status: \(mastery.title)")
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .practicePanel()
    }

    private var progressCard: some View {
        HStack(spacing: 18) {
            ProgressView(value: model.lessonProgress)
                .tint(PracticeTheme.accent)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: model.lessonProgress)
                .accessibilityLabel("Lesson progress")
                .accessibilityValue("\(model.completedNotes) of \(model.practicePromptCount) prompts")
            Label("\(model.streak)", systemImage: "flame.fill")
                .foregroundStyle(.orange)
                .accessibilityLabel("Current streak: \(model.streak)")
            Label("\(model.mistakes)", systemImage: "heart.slash.fill")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Mistakes: \(model.mistakes)")
            Button("Reset", systemImage: "arrow.counterclockwise") { model.resetLesson() }
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .practicePanel()
        .quickHelp(
            "Lesson progress",
            "Tracks completed prompts, your current correct streak, mistakes, and lesson reset."
        )
    }

    private var feedbackPanel: some View {
        HStack(spacing: 14) {
            Image(systemName: model.feedback.symbol)
                .font(.title2)
                .foregroundStyle(feedbackColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(previewTitle).font(.headline)
                Text(feedbackDetail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if model.isChordPrompt && !model.isPreviewPlaying {
                Button("Play shown chord", systemImage: "hand.raised.fingers.spread") {
                    model.simulateChord(model.expectedPitches)
                }
                .buttonStyle(.bordered)
                .help("Simulate the displayed chord without a MIDI keyboard")
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(PracticeTheme.panel, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7).stroke(PracticeTheme.separator, lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(feedbackColor)
                .frame(width: 3)
                .padding(.vertical, 1)
        }
        .accessibilityElement(children: .combine)
        .quickHelp("Prompt feedback", "Shows the current target, mistakes, and whether the complete note or chord prompt matched.")
    }

    private var completeScoreStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Complete score", systemImage: "music.quarternote.3")
                    .font(.headline)
                Spacer()
                Text(scoreSummary)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            PracticeScoreView(
                lesson: model.activeLesson,
                activePromptIndex: activeScoreIndex,
                completedPromptIndices: model.completedSourcePromptIndices
            )
            .frame(height: 430)
        }
        .padding(12)
        .practicePanel()
        .quickHelp(
            "Complete score",
            "The complete exercise uses standard grand-staff notation with stems, beams, barlines, repeats, note values, and a finger number on every written note. Finger 1 is the thumb and finger 5 is the little finger."
        )
    }

    private var scoreSummary: String {
        guard let metadata = model.activeLesson.scoreMetadata else {
            return "\(model.activeLesson.promptCount) written note groups"
        }
        let repeatText = metadata.repeatSection == nil ? "" : " · repeat ×2"
        return "\(metadata.timeSignature.displayName) · \(model.activeLesson.promptCount) groups\(repeatText)"
    }

    private var feedbackColor: Color {
        if model.isPreviewPlaying { return PracticeTheme.accent }
        return switch model.feedback {
        case .waiting: PracticeTheme.accent
        case .correct: .green
        case .incorrect: .orange
        }
    }

    private var previewTitle: String {
        guard model.isPreviewPlaying else { return model.feedback.title }
        return model.isExerciseLoopEnabled ? "Practice loop" : "Exercise preview"
    }

    private var feedbackDetail: String {
        if model.isPreviewPlaying {
            let position = (model.previewPromptIndex ?? 0) + 1
            if model.previewPromptIndex == nil {
                return "Listening at \(model.previewTempoBPM) BPM · Completing the current measure."
            }
            return "Listening at \(model.previewTempoBPM) BPM · Score prompt \(position): \(noteList(model.previewPitches))."
        }
        return switch model.feedback {
        case .waiting:
            model.completedNotes == 0
                ? "\(model.activeLesson.practiceInstruction) \(promptInstruction)"
                : promptInstruction
        case let .correct(notes):
            model.isActiveLessonComplete
                ? "Lesson complete — your course progress has been saved."
                : "\(noteList(notes)) matched. Next: \(noteList(model.expectedPitches))."
        case let .incorrect(expected, received):
            "\(noteName(received)) is outside this prompt. Play \(noteList(expected))."
        }
    }

    private var promptInstruction: String {
        let fingering = model.displayedFingerings
            .map { "\($0.hand.abbreviatedName) finger \($0.finger) on \(noteName($0.pitch))" }
            .joined(separator: " and ")
        if model.isChordPrompt {
            return "Press and hold \(noteList(model.expectedPitches)) together.\(fingering.isEmpty ? "" : " Use \(fingering).")"
        }
        return "Find \(noteName(model.expectedPitch)) on your keyboard.\(fingering.isEmpty ? "" : " Use \(fingering).")"
    }

    private var activeScoreIndex: Int {
        model.previewPromptIndex ?? model.currentSourcePromptIndex
    }

    private func noteList(_ pitches: [UInt8]) -> String {
        pitches.map(noteName).joined(separator: pitches.count > 1 ? " + " : "")
    }

    private var staffLabel: String {
        switch model.activeLesson.staffLayout {
        case .treble: "Treble clef"
        case .bass: "Bass clef"
        case .grand: "Grand staff"
        }
    }

    private func staffHeight(for availableHeight: CGFloat) -> CGFloat {
        max(340, availableHeight - 520)
    }

    private func masterySymbol(_ mastery: LessonMastery) -> String {
        switch mastery {
        case .introduced: "circle.dotted"
        case .practiced: "checkmark.circle.fill"
        case .mastered: "seal.fill"
        }
    }

}
