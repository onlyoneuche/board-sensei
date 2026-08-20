import CBoardSenseiBridge
import Foundation
import MusicCore

final class RustPracticeValidator {
    private var engine: OpaquePointer?

    init(expectedPitch: UInt8) {
        engine = bs_bridge_engine_create(expectedPitch)
    }

    deinit {
        bs_bridge_engine_destroy(engine)
    }

    var isUsingRust: Bool {
        bs_bridge_engine_uses_rust(engine)
    }

    func setExpectedPitch(_ pitch: UInt8) {
        bs_bridge_engine_set_expected(engine, pitch)
    }

    func validate(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64) -> ValidationResult {
        let result = bs_bridge_engine_process_note(engine, note, velocity, channel, timestamp)
        return ValidationResult(
            status: ValidationStatus(rawValue: result.status) ?? .unavailable,
            expectedPitch: result.expected_pitch,
            receivedPitch: result.received_pitch,
            responseTimeMilliseconds: result.response_time_ms
        )
    }
}
