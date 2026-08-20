import Foundation

public enum ValidationStatus: UInt8, Sendable, Equatable {
    case correct = 0
    case incorrect = 1
    case ignored = 2
    case unavailable = 255
}

public struct ValidationResult: Sendable, Equatable {
    public var status: ValidationStatus
    public var expectedPitch: UInt8
    public var receivedPitch: UInt8
    public var responseTimeMilliseconds: Float

    public init(
        status: ValidationStatus,
        expectedPitch: UInt8,
        receivedPitch: UInt8,
        responseTimeMilliseconds: Float
    ) {
        self.status = status
        self.expectedPitch = expectedPitch
        self.receivedPitch = receivedPitch
        self.responseTimeMilliseconds = responseTimeMilliseconds
    }
}

public struct PracticeEngine: Sendable {
    public private(set) var expectedPitch: UInt8
    private var promptTimestamp: ContinuousClock.Instant

    public init(expectedPitch: UInt8, clock: ContinuousClock = .init()) {
        self.expectedPitch = expectedPitch
        self.promptTimestamp = clock.now
    }

    public mutating func setExpectedPitch(_ pitch: UInt8, clock: ContinuousClock = .init()) {
        expectedPitch = pitch
        promptTimestamp = clock.now
    }

    public mutating func process(
        _ event: NormalizedMIDIEvent,
        clock: ContinuousClock = .init()
    ) -> ValidationResult? {
        guard case let .noteOn(note, velocity, _, _) = event, velocity > 0 else { return nil }
        let duration = promptTimestamp.duration(to: clock.now)
        let components = duration.components
        let milliseconds = Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000

        return ValidationResult(
            status: note == expectedPitch ? .correct : .incorrect,
            expectedPitch: expectedPitch,
            receivedPitch: note,
            responseTimeMilliseconds: Float(max(0, milliseconds))
        )
    }
}

public struct MIDINoteParser: Sendable {
    public init() {}

    public func parse(bytes: [UInt8], timestamp: UInt64) -> [NormalizedMIDIEvent] {
        var events: [NormalizedMIDIEvent] = []
        var index = 0
        var runningStatus: UInt8?

        while index < bytes.count {
            let byte = bytes[index]
            if byte >= 0xF8 {
                index += 1
                continue
            }

            if byte & 0x80 != 0 {
                guard byte < 0xF0 else { break }
                runningStatus = byte
                index += 1
            }

            guard let status = runningStatus else {
                index += 1
                continue
            }

            let command = status & 0xF0
            let channel = status & 0x0F
            let dataLength = (command == 0xC0 || command == 0xD0) ? 1 : 2
            guard index + dataLength <= bytes.count else { break }

            let first = bytes[index] & 0x7F
            let second = dataLength == 2 ? bytes[index + 1] & 0x7F : 0
            index += dataLength

            switch command {
            case 0x80:
                events.append(.noteOff(note: first, velocity: second, channel: channel, timestamp: timestamp))
            case 0x90:
                if second == 0 {
                    events.append(.noteOff(note: first, velocity: 0, channel: channel, timestamp: timestamp))
                } else {
                    events.append(.noteOn(note: first, velocity: second, channel: channel, timestamp: timestamp))
                }
            case 0xB0 where first == 64:
                events.append(.sustain(value: second, channel: channel, timestamp: timestamp))
            case 0xB0:
                events.append(.controlChange(controller: first, value: second, channel: channel, timestamp: timestamp))
            default:
                continue
            }
        }

        return events
    }
}
