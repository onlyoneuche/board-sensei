import CBoardSenseiBridge
import Foundation
import Testing
@testable import MusicCore

@Suite("Practice engine")
struct PracticeEngineTests {
    @Test("Matching note is correct")
    func matchingNote() {
        var engine = PracticeEngine(expectedPitch: 60)
        let result = engine.process(.noteOn(note: 60, velocity: 90, channel: 0, timestamp: 1))
        #expect(result?.status == .correct)
        #expect(result?.expectedPitch == 60)
    }

    @Test("Different note is incorrect")
    func differentNote() {
        var engine = PracticeEngine(expectedPitch: 60)
        let result = engine.process(.noteOn(note: 62, velocity: 90, channel: 0, timestamp: 1))
        #expect(result?.status == .incorrect)
        #expect(result?.receivedPitch == 62)
    }

    @Test("Note-off does not answer a prompt")
    func ignoresNoteOff() {
        var engine = PracticeEngine(expectedPitch: 60)
        let result = engine.process(.noteOff(note: 60, velocity: 0, channel: 0, timestamp: 1))
        #expect(result == nil)
    }
}

@Suite("C ABI bridge")
struct CBridgeTests {
    @Test("Bridge validates notes and owns its engine handle")
    func bridgeContract() {
        let engine = bs_bridge_engine_create(60)
        defer { bs_bridge_engine_destroy(engine) }

        if ProcessInfo.processInfo.environment["BOARD_SENSEI_EXPECT_RUST"] == "1" {
            #expect(bs_bridge_engine_uses_rust(engine))
        }

        let correct = bs_bridge_engine_process_note(engine, 60, 90, 0, 1)
        let incorrect = bs_bridge_engine_process_note(engine, 62, 90, 0, 2)

        #expect(correct.status == ValidationStatus.correct.rawValue)
        #expect(incorrect.status == ValidationStatus.incorrect.rawValue)
        #expect(incorrect.expected_pitch == 60)
        #expect(incorrect.received_pitch == 62)
    }

    @Test("Bridge keeps Jazz chords exact")
    func exactChordContract() {
        let engine = bs_bridge_engine_create(60)
        defer { bs_bridge_engine_destroy(engine) }
        let pitches: [UInt8] = [60, 64, 67]
        let configured = pitches.withUnsafeBufferPointer {
            bs_bridge_engine_configure_prompt(engine, 1, $0.baseAddress, 3, 0)
        }

        #expect(configured)
        #expect(bs_bridge_engine_process_note(engine, 60, 90, 0, 1).status == ValidationStatus.partial.rawValue)
        #expect(bs_bridge_engine_process_note(engine, 64, 90, 0, 2).status == ValidationStatus.partial.rawValue)
        #expect(bs_bridge_engine_process_note(engine, 67, 90, 0, 3).status == ValidationStatus.correct.rawValue)
        #expect(bs_bridge_engine_process_note(engine, 71, 90, 0, 4).status == ValidationStatus.incorrect.rawValue)
    }

    @Test("Bridge requires fresh paired attacks inside the Hanon window")
    func freshAttackContract() {
        let engine = bs_bridge_engine_create(36)
        defer { bs_bridge_engine_destroy(engine) }
        let pitches: [UInt8] = [36, 48]
        func configure() {
            let configured = pitches.withUnsafeBufferPointer {
                bs_bridge_engine_configure_prompt(engine, 2, $0.baseAddress, 2, 120)
            }
            #expect(configured)
        }

        configure()
        #expect(bs_bridge_engine_process_note(engine, 36, 90, 0, 1_000_000).status == ValidationStatus.partial.rawValue)
        #expect(bs_bridge_engine_process_note(engine, 48, 90, 0, 100_000_000).status == ValidationStatus.correct.rawValue)

        configure()
        #expect(bs_bridge_engine_process_note(engine, 36, 90, 0, 200_000_000).status == ValidationStatus.partial.rawValue)
        #expect(bs_bridge_engine_process_note(engine, 48, 90, 0, 321_000_000).status == ValidationStatus.partial.rawValue)
        #expect(bs_bridge_engine_process_note(engine, 50, 90, 0, 330_000_000).status == ValidationStatus.incorrect.rawValue)
    }

    @Test("Audio meter transfers levels through its atomic handoff")
    func meterContract() {
        let meter = bs_level_meter_create()
        defer { bs_level_meter_destroy(meter) }

        bs_level_meter_store(meter, 0.625)
        #expect(abs(bs_level_meter_load(meter) - 0.625) < 0.0001)
    }
}

@Suite("MIDI byte parser")
struct MIDIParserTests {
    @Test("Velocity-zero note-on becomes note-off")
    func velocityZero() {
        let events = MIDINoteParser().parse(bytes: [0x90, 60, 0], timestamp: 42)
        #expect(events == [.noteOff(note: 60, velocity: 0, channel: 0, timestamp: 42)])
    }

    @Test("Running status and sustain are normalized")
    func runningStatus() {
        let parser = MIDINoteParser()
        let notes = parser.parse(bytes: [0x91, 60, 90, 64, 80], timestamp: 7)
        let pedal = parser.parse(bytes: [0xB1, 64, 127], timestamp: 8)

        #expect(notes.count == 2)
        #expect(notes.first == .noteOn(note: 60, velocity: 90, channel: 1, timestamp: 7))
        #expect(pedal == [.sustain(value: 127, channel: 1, timestamp: 8)])
    }
}
