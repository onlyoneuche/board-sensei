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

    @discardableResult
    func configure(
        pitches: [UInt8],
        mode: PracticePromptValidationMode,
        spreadMilliseconds: UInt16 = 0
    ) -> Bool {
        guard !pitches.isEmpty, pitches.count <= Int(BS_MAX_PROMPT_PITCHES) else { return false }
        return pitches.withUnsafeBufferPointer { buffer in
            bs_bridge_engine_configure_prompt(
                engine,
                mode.rawValue,
                buffer.baseAddress,
                UInt8(buffer.count),
                spreadMilliseconds
            )
        }
    }

    func reset() {
        bs_bridge_engine_reset(engine)
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
