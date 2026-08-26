import Foundation

public struct PracticePlaybackEvent: Sendable, Equatable {
    public let sourcePromptIndex: Int
    public let pitches: [UInt8]
    public let startQuarterNote: Double
    public let stepDurationQuarterNotes: Double
    public let audibleDurationQuarterNotes: Double

    public init(
        sourcePromptIndex: Int,
        pitches: [UInt8],
        startQuarterNote: Double,
        stepDurationQuarterNotes: Double,
        audibleDurationQuarterNotes: Double
    ) {
        precondition(!pitches.isEmpty)
        precondition(startQuarterNote >= 0)
        precondition(stepDurationQuarterNotes > 0)
        precondition(audibleDurationQuarterNotes > 0)
        precondition(audibleDurationQuarterNotes <= stepDurationQuarterNotes)
        self.sourcePromptIndex = sourcePromptIndex
        self.pitches = pitches
        self.startQuarterNote = startQuarterNote
        self.stepDurationQuarterNotes = stepDurationQuarterNotes
        self.audibleDurationQuarterNotes = audibleDurationQuarterNotes
    }
}

public struct PracticePlaybackTimeline: Sendable, Equatable {
    public let events: [PracticePlaybackEvent]
    public let timeSignature: PracticeTimeSignature
    public let durationQuarterNotes: Double
    public let loopDurationQuarterNotes: Double

    public init(events: [PracticePlaybackEvent], timeSignature: PracticeTimeSignature) {
        precondition(!events.isEmpty)
        self.events = events
        self.timeSignature = timeSignature
        durationQuarterNotes = events.map {
            $0.startQuarterNote + $0.stepDurationQuarterNotes
        }.max() ?? 0

        let beatUnitInQuarterNotes = 4.0 / Double(timeSignature.denominator)
        let barQuarterNotes = Double(timeSignature.numerator) * beatUnitInQuarterNotes
        loopDurationQuarterNotes = ceil(durationQuarterNotes / barQuarterNotes) * barQuarterNotes
    }

    public func event(atQuarterNote position: Double, looping: Bool) -> PracticePlaybackEvent? {
        guard position >= 0 else { return nil }
        let localPosition: Double
        if looping, loopDurationQuarterNotes > 0 {
            localPosition = position.truncatingRemainder(dividingBy: loopDurationQuarterNotes)
        } else {
            localPosition = position
        }
        return events.last {
            $0.startQuarterNote <= localPosition
                && localPosition < $0.startQuarterNote + $0.stepDurationQuarterNotes
        }
    }
}

/// Deterministic conversion between musical time and an audio render clock.
///
/// The host app chooses one host-time origin for a preview, then uses this
/// clock for MIDI scheduling and UI observation. Keeping the conversion here
/// prevents the audible and visual transports from developing separate tempo
/// interpretations.
public struct PracticePlaybackClock: Sendable, Equatable {
    public let tempoBeatsPerMinute: Double
    public let sampleRate: Double

    public init(tempoBeatsPerMinute: Double, sampleRate: Double) {
        precondition(tempoBeatsPerMinute > 0)
        precondition(sampleRate > 0)
        self.tempoBeatsPerMinute = tempoBeatsPerMinute
        self.sampleRate = sampleRate
    }

    public var framesPerQuarterNote: Double {
        sampleRate * 60 / tempoBeatsPerMinute
    }

    public func sampleOffset(forQuarterNotes quarterNotes: Double) -> Int64 {
        Int64((quarterNotes * framesPerQuarterNote).rounded())
    }

    public func quarterNotes(forElapsedSeconds elapsedSeconds: Double) -> Double {
        max(0, elapsedSeconds) * tempoBeatsPerMinute / 60
    }
}
