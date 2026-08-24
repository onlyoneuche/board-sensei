import MusicCore
import SwiftUI

/// Non-blocking pass feedback that keeps the staff and keyboard available.
struct LessonCompletionPanel: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let result: LessonCompletionResult
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: masterySymbol)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.green)
                    .frame(width: 38, height: 38)
                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                    .scaleEffect(revealed ? 1 : 0.82)

                VStack(alignment: .leading, spacing: 3) {
                    Text(completionTitle)
                        .font(.headline)
                    HStack(spacing: 12) {
                        Text(result.accuracy.formatted(.percent.precision(.fractionLength(0))) + " accuracy")
                        Text("\(result.mistakes) mistakes")
                        Text(result.mastery.title)
                        if model.automaticTempoProgressionEnabled, result.accuracy >= 0.9 {
                            Text("Next: \(model.previewTempoBPM) BPM")
                        }
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if result.personalBest {
                    Label("Personal best", systemImage: "sparkles")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }

            if let achievement = result.newAchievements.first {
                Label("\(achievement.title) — \(achievement.detail)", systemImage: achievement.symbol)
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
            }

            HStack(spacing: 9) {
                if model.isPracticeLoopActive {
                    Button("Stop practice loop", systemImage: "stop.fill") {
                        model.stopPracticeLoop()
                    }
                    .buttonStyle(.bordered)

                    Label("Restarts on beat one", systemImage: "metronome")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Practise again", systemImage: "arrow.counterclockwise") {
                        model.practiseAgain()
                    }
                    .buttonStyle(.bordered)

                    Button("Loop with metronome", systemImage: "repeat") {
                        model.startPracticeLoop()
                    }
                    .buttonStyle(.bordered)
                    .help("Repeat this lesson continuously with the metronome armed")
                }

                Spacer()

                if let nextLesson = model.activeLessonNavigation?.nextLesson {
                    Button("Next lesson", systemImage: "chevron.right") {
                        model.startLesson(nextLesson)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Return to course", systemImage: "graduationcap.fill") {
                        model.leavePractice(for: .courses)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(14)
        .background(PracticeTheme.panel, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.green.opacity(0.55), lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.green)
                .frame(width: 3)
                .padding(.vertical, 1)
        }
        .onAppear {
            guard model.animatedCelebrationsEnabled, !reduceMotion else {
                revealed = true
                return
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                revealed = true
            }
        }
        .accessibilityElement(children: .contain)
        .quickHelp(
            "Completed pass",
            "Repeat once, start a metronome-synchronised practice loop, or continue when the exercise feels comfortable."
        )
    }

    private var masterySymbol: String {
        switch result.mastery {
        case .introduced: "circle.dotted"
        case .practiced: "checkmark.circle.fill"
        case .mastered: "seal.fill"
        }
    }

    private var completionTitle: String {
        let pass = model.isFocusedPracticeSelection ? "Selection complete" : "Pass complete"
        return model.isPracticeLoopActive ? "\(pass) · practice loop active" : pass
    }
}
