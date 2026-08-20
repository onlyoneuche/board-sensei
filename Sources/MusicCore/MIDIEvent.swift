import Foundation

public enum NormalizedMIDIEvent: Sendable, Equatable {
    case noteOn(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64)
    case noteOff(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64)
    case sustain(value: UInt8, channel: UInt8, timestamp: UInt64)
    case controlChange(controller: UInt8, value: UInt8, channel: UInt8, timestamp: UInt64)

    public var timestamp: UInt64 {
        switch self {
        case let .noteOn(_, _, _, timestamp),
             let .noteOff(_, _, _, timestamp),
             let .sustain(_, _, timestamp),
             let .controlChange(_, _, _, timestamp):
            timestamp
        }
    }

    public var displayText: String {
        switch self {
        case let .noteOn(note, velocity, channel, _):
            "Note on  \(noteName(note))  velocity \(velocity)  ch \(channel + 1)"
        case let .noteOff(note, _, channel, _):
            "Note off \(noteName(note))  ch \(channel + 1)"
        case let .sustain(value, channel, _):
            "Sustain  \(value >= 64 ? "down" : "up")  ch \(channel + 1)"
        case let .controlChange(controller, value, channel, _):
            "CC \(controller)  value \(value)  ch \(channel + 1)"
        }
    }
}

public func noteName(_ midiPitch: UInt8) -> String {
    let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    let pitch = Int(midiPitch)
    return "\(names[pitch % 12])\((pitch / 12) - 1)"
}
