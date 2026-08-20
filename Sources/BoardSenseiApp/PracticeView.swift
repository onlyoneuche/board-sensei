import MusicCore
import SwiftUI

struct PracticeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            PracticeTheme.workspace.ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 10) {
                        header
                        progressCard
                        PracticeStaffView(
                            expectedPitches: model.displayedPitches,
                            feedback: model.displayedFeedback,
                            layout: model.activeLesson.staffLayout,
                            reduceMotion: reduceMotion
                        )
                        .frame(height: staffHeight(for: geometry.size.height))
                        .layoutPriority(1)
                        .quickHelp(
                            "Notation",
                            "The staff follows the active prompt and switches between treble, bass, or grand staff for the lesson range."
                        )
                        feedbackPanel
                        PianoKeyboardView()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .top)
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
                Text("\(staffLabel) · \(model.activeLesson.promptCount) prompts")
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .practicePanel()
    }

    private var progressCard: some View {
        HStack(spacing: 18) {
            ProgressView(value: model.lessonProgress)
                .tint(PracticeTheme.accent)
                .accessibilityLabel("Lesson progress")
                .accessibilityValue("\(model.completedNotes) of \(model.activeLesson.promptCount) prompts")
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
                Text(model.isPreviewPlaying ? "Exercise preview" : model.feedback.title).font(.headline)
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

    private var feedbackColor: Color {
        if model.isPreviewPlaying { return PracticeTheme.accent }
        return switch model.feedback {
        case .waiting: PracticeTheme.accent
        case .correct: .green
        case .incorrect: .orange
        }
    }

    private var feedbackDetail: String {
        if model.isPreviewPlaying {
            let position = (model.previewPromptIndex ?? 0) + 1
            return "Listening at \(model.previewTempoBPM) BPM · Prompt \(position) of \(model.activeLesson.promptCount): \(noteList(model.previewPitches))."
        }
        return switch model.feedback {
        case .waiting:
            model.completedNotes == 0
                ? model.activeLesson.practiceInstruction
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
        if model.isChordPrompt {
            return "Press and hold \(noteList(model.expectedPitches)) together."
        }
        return "Find \(noteName(model.expectedPitch)) on your keyboard."
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
}
