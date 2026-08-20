//! Platform-independent music, practice, and scoring primitives.
//!
//! The exported C ABI is deliberately narrow. Swift owns Apple framework and UI
//! integration; this crate owns deterministic musical behavior.

pub type Tick = u64;

#[derive(Clone, Debug, PartialEq)]
pub struct Song {
    pub title: String,
    pub ticks_per_quarter_note: u16,
    pub tempo_map: Vec<TempoEvent>,
    pub tracks: Vec<Track>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct TempoEvent {
    pub tick: Tick,
    pub beats_per_minute: f64,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Track {
    pub name: String,
    pub events: Vec<MusicalEvent>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MusicalEvent {
    Note(NoteEvent),
    Pedal(PedalEvent),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct NoteEvent {
    pub pitch: u8,
    pub start_tick: Tick,
    pub duration_ticks: Tick,
    pub velocity: u8,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PedalEvent {
    pub start_tick: Tick,
    pub duration_ticks: Tick,
}

struct PracticeEngine {
    expected_pitch: u8,
}

/// Result layout mirrored by `BoardSenseiBridge.h`.
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct BsValidationResult {
    pub status: u8,
    pub expected_pitch: u8,
    pub received_pitch: u8,
    pub reserved: u8,
    pub response_time_ms: f32,
}

impl BsValidationResult {
    const CORRECT: u8 = 0;
    const INCORRECT: u8 = 1;
    const IGNORED: u8 = 2;
    const UNAVAILABLE: u8 = 255;
}

#[unsafe(no_mangle)]
pub extern "C" fn bs_engine_new(expected_pitch: u8) -> *mut core::ffi::c_void {
    Box::into_raw(Box::new(PracticeEngine { expected_pitch })).cast()
}

/// Releases an engine returned by [`bs_engine_new`].
///
/// # Safety
///
/// A null pointer is accepted. Every non-null pointer must have been returned by
/// `bs_engine_new` and must be released exactly once.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn bs_engine_free(engine: *mut core::ffi::c_void) {
    if !engine.is_null() {
        // SAFETY: The ownership contract is documented above and enforced by the C bridge.
        drop(unsafe { Box::from_raw(engine.cast::<PracticeEngine>()) });
    }
}

/// Updates the expected note for an existing engine.
///
/// # Safety
///
/// A null pointer is accepted. Every non-null pointer must be a live handle
/// returned by [`bs_engine_new`] that has not been released.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn bs_engine_set_expected(
    engine: *mut core::ffi::c_void,
    expected_pitch: u8,
) {
    // SAFETY: `as_mut` checks null; valid non-null pointers follow the engine ownership contract.
    if let Some(engine) = unsafe { engine.cast::<PracticeEngine>().as_mut() } {
        engine.expected_pitch = expected_pitch;
    }
}

/// Validates one normalized MIDI note-on event.
///
/// # Safety
///
/// A null pointer is accepted and produces an unavailable result. Every non-null
/// pointer must be a live handle returned by [`bs_engine_new`].
#[unsafe(no_mangle)]
pub unsafe extern "C" fn bs_engine_process_note(
    engine: *mut core::ffi::c_void,
    pitch: u8,
    velocity: u8,
    _channel: u8,
    _timestamp_ns: u64,
) -> BsValidationResult {
    // SAFETY: `as_ref` checks null; valid non-null pointers follow the engine ownership contract.
    let Some(engine) = (unsafe { engine.cast::<PracticeEngine>().as_ref() }) else {
        return BsValidationResult {
            status: BsValidationResult::UNAVAILABLE,
            expected_pitch: 0,
            received_pitch: pitch,
            reserved: 0,
            response_time_ms: 0.0,
        };
    };

    let status = if velocity == 0 {
        BsValidationResult::IGNORED
    } else if pitch == engine.expected_pitch {
        BsValidationResult::CORRECT
    } else {
        BsValidationResult::INCORRECT
    };

    BsValidationResult {
        status,
        expected_pitch: engine.expected_pitch,
        received_pitch: pitch,
        reserved: 0,
        response_time_ms: 0.0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validates_pitch_through_ffi_contract() {
        let engine = bs_engine_new(60);
        // SAFETY: `engine` was created above and is released once below.
        let correct = unsafe { bs_engine_process_note(engine, 60, 90, 0, 1) };
        // SAFETY: Same valid engine handle.
        let incorrect = unsafe { bs_engine_process_note(engine, 62, 90, 0, 2) };
        assert_eq!(correct.status, BsValidationResult::CORRECT);
        assert_eq!(incorrect.status, BsValidationResult::INCORRECT);
        // SAFETY: This is the single matching release for `engine`.
        unsafe { bs_engine_free(engine) };
    }

    #[test]
    fn null_handle_is_reported_without_panicking() {
        // SAFETY: Null is an explicitly supported input.
        let result = unsafe { bs_engine_process_note(core::ptr::null_mut(), 60, 90, 0, 1) };
        assert_eq!(result.status, BsValidationResult::UNAVAILABLE);
    }
}
