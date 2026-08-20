import Foundation

public typealias Tick = UInt64

public struct Song: Sendable, Equatable {
    public var title: String
    public var ticksPerQuarterNote: UInt16
    public var tempoMap: [TempoEvent]
    public var tracks: [MusicTrack]

    public init(
        title: String,
        ticksPerQuarterNote: UInt16 = 480,
        tempoMap: [TempoEvent] = [.init(tick: 0, beatsPerMinute: 120)],
        tracks: [MusicTrack] = []
    ) {
        self.title = title
        self.ticksPerQuarterNote = ticksPerQuarterNote
        self.tempoMap = tempoMap
        self.tracks = tracks
    }
}

public struct TempoEvent: Sendable, Equatable {
    public var tick: Tick
    public var beatsPerMinute: Double

    public init(tick: Tick, beatsPerMinute: Double) {
        self.tick = tick
        self.beatsPerMinute = beatsPerMinute
    }
}

public struct MusicTrack: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var events: [MusicalEvent]

    public init(id: UUID = UUID(), name: String, events: [MusicalEvent]) {
        self.id = id
        self.name = name
        self.events = events
    }
}

public enum MusicalEvent: Sendable, Equatable {
    case note(NoteEvent)
    case pedal(PedalEvent)
}

public struct NoteEvent: Sendable, Equatable {
    public var pitch: UInt8
    public var startTick: Tick
    public var durationTicks: Tick
    public var velocity: UInt8
    public var notation: WrittenNotation?

    public init(
        pitch: UInt8,
        startTick: Tick,
        durationTicks: Tick,
        velocity: UInt8,
        notation: WrittenNotation? = nil
    ) {
        self.pitch = pitch
        self.startTick = startTick
        self.durationTicks = durationTicks
        self.velocity = velocity
        self.notation = notation
    }
}

public struct PedalEvent: Sendable, Equatable {
    public var startTick: Tick
    public var durationTicks: Tick

    public init(startTick: Tick, durationTicks: Tick) {
        self.startTick = startTick
        self.durationTicks = durationTicks
    }
}

public struct WrittenNotation: Sendable, Equatable {
    public enum Letter: String, Sendable, CaseIterable { case c, d, e, f, g, a, b }
    public enum Accidental: String, Sendable { case flat, natural, sharp }

    public var letter: Letter
    public var accidental: Accidental
    public var octave: Int8

    public init(letter: Letter, accidental: Accidental = .natural, octave: Int8) {
        self.letter = letter
        self.accidental = accidental
        self.octave = octave
    }
}
