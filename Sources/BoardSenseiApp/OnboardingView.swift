import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var landedFirstNote = false

    private let stepCount = 4

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Divider()
                content
                Divider()
                footer
            }
        }
        .frame(minWidth: 860, minHeight: 620)
        .onChange(of: model.activeNotes) { _, notes in
            guard step == 3, notes.contains(60), !landedFirstNote else { return }
            withAnimation(completionAnimation) {
                landedFirstNote = true
            }
        }
        .onChange(of: step) { _, newStep in
            guard newStep == 3, model.activeNotes.contains(60), !landedFirstNote else { return }
            landedFirstNote = true
        }
    }

    private var topBar: some View {
        HStack {
            BoardSenseiLockup(markSize: 40)
            Spacer()
            HStack(spacing: 7) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? AppTheme.accent : Color.secondary.opacity(0.22))
                        .frame(width: index == step ? 26 : 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Onboarding step \(step + 1) of \(stepCount)")
            Spacer()
            Button("Skip setup") { model.completeOnboarding() }
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 26)
        .frame(height: 70)
    }

    private var content: some View {
        Group {
            switch step {
            case 0: goalStep
            case 1: experienceStep
            case 2: midiStep
            default: firstNoteStep
            }
        }
        .id(step)
        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(36)
    }

    private var goalStep: some View {
        onboardingPage(
            eyebrow: "YOUR PRACTICE",
            title: "What would you like to make easier?",
            detail: "This sets your starting context. It never locks courses or features."
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                ForEach(LearningGoal.allCases) { goal in
                    selectionCard(
                        title: goal.rawValue,
                        detail: goal.detail,
                        symbol: goal.symbol,
                        selected: model.learningGoal == goal
                    ) { model.chooseLearningGoal(goal) }
                }
            }
        }
    }

    private var experienceStep: some View {
        onboardingPage(
            eyebrow: "STARTING POINT",
            title: "Where are you today?",
            detail: "We will use this to open the most useful part of the course first."
        ) {
            VStack(spacing: 12) {
                ForEach(LearnerExperience.allCases) { experience in
                    selectionCard(
                        title: experience.rawValue,
                        detail: experience.detail,
                        symbol: experience == .beginner ? "leaf.fill" : experience == .intermediate ? "waveform.path" : "bolt.fill",
                        selected: model.learnerExperience == experience
                    ) { model.chooseLearnerExperience(experience) }
                }
            }
        }
    }

    private var midiStep: some View {
        onboardingPage(
            eyebrow: "INSTRUMENT",
            title: "Connect your keyboard",
            detail: "Board Sensei works with USB and Bluetooth MIDI. You can also practise with the on-screen piano."
        ) {
            VStack(spacing: 14) {
                connectionStatus
                if !model.devices.isEmpty {
                    ForEach(model.devices) { device in
                        Button {
                            model.connect(to: device.id)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "pianokeys")
                                    .font(.title2)
                                    .foregroundStyle(model.selectedDeviceID == device.id ? Color.green : AppTheme.accent)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(device.name).font(.headline)
                                    Text(device.manufacturer ?? "MIDI input")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: model.selectedDeviceID == device.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(model.selectedDeviceID == device.id ? Color.green : Color.secondary)
                            }
                            .padding(16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).stroke(.separator) }
                    }
                }
            }
        }
    }

    private var connectionStatus: some View {
        HStack(spacing: 14) {
            Image(systemName: model.selectedDeviceID == nil ? "cable.connector.slash" : "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(model.selectedDeviceID == nil ? Color.secondary : Color.green)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.selectedDeviceID == nil ? "On-screen piano ready" : "MIDI ready")
                    .font(.headline)
                Text(model.connectionMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var firstNoteStep: some View {
        onboardingPage(
            eyebrow: "FIRST WIN",
            title: landedFirstNote ? "That is the loop." : "Land one note",
            detail: landedFirstNote
                ? "See it, hear it, play it, and get immediate feedback. Your first Jazz lesson is ready."
                : "Play middle C on your MIDI keyboard, or press the key below."
        ) {
            VStack(spacing: 20) {
                Button {
                    model.simulate(note: 60)
                } label: {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(landedFirstNote ? AppTheme.accent : Color.white)
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
                        VStack(spacing: 8) {
                            Image(systemName: landedFirstNote ? "checkmark.circle.fill" : "scope")
                                .font(.title)
                            Text("C4").font(.headline.monospaced())
                        }
                        .foregroundStyle(landedFirstNote ? Color.white : Color.black)
                        .padding(.bottom, 22)
                    }
                    .frame(width: 150, height: 250)
                    .scaleEffect(landedFirstNote && !reduceMotion ? 1.04 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play middle C")

                if landedFirstNote {
                    Label("Immediate feedback received", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .transition(.opacity.combined(with: .scale))
                } else {
                    Text("No MIDI controller is required—every lesson keeps an interactive piano available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func onboardingPage<Content: View>(
        eyebrow: String,
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(eyebrow)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.accent)
                    Text(title)
                        .font(.system(size: 34, weight: .semibold))
                    Text(detail)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                content()
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func selectionCard(
        title: String,
        detail: String,
        symbol: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(selected ? Color.white : AppTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(selected ? AppTheme.accent : AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.headline)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? AppTheme.accent : Color.secondary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? AppTheme.accent : Color.secondary.opacity(0.2), lineWidth: selected ? 2 : 1)
        }
    }

    private var footer: some View {
        HStack {
            Button("Back", systemImage: "chevron.left") { move(to: step - 1) }
                .disabled(step == 0)
            Spacer()
            Button(step == stepCount - 1 ? "Enter Board Sensei" : "Continue") {
                if step == stepCount - 1 { model.completeOnboarding() }
                else { move(to: step + 1) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(step == stepCount - 1 && !landedFirstNote)
        }
        .padding(.horizontal, 26)
        .frame(height: 72)
    }

    private func move(to newStep: Int) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .easeInOut(duration: 0.26)) {
            step = min(max(newStep, 0), stepCount - 1)
        }
    }

    private var completionAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.34, dampingFraction: 0.7)
    }
}
