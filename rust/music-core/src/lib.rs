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

const MAX_PROMPT_PITCHES: usize = 16;
const PROMPT_SINGLE_NOTE: u8 = 0;
const PROMPT_EXACT_HELD_SET: u8 = 1;
const PROMPT_FRESH_ATTACK_SET: u8 = 2;

#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct BsPromptConfig {
    pub mode: u8,
    pub pitch_count: u8,
    pub spread_ms: u16,
    pub pitches: [u8; MAX_PROMPT_PITCHES],
}

impl BsPromptConfig {
    fn single(expected_pitch: u8) -> Self {
        let mut pitches = [0; MAX_PROMPT_PITCHES];
        pitches[0] = expected_pitch;
        Self {
            mode: PROMPT_SINGLE_NOTE,
            pitch_count: 1,
            spread_ms: 0,
            pitches,
        }
    }
}

struct PracticeEngine {
    prompt: BsPromptConfig,
    held: [bool; 128],
    attacked: [bool; MAX_PROMPT_PITCHES],
    attack_times: [u64; MAX_PROMPT_PITCHES],
}

impl PracticeEngine {
    fn new(expected_pitch: u8) -> Self {
        Self {
            prompt: BsPromptConfig::single(expected_pitch),
            held: [false; 128],
            attacked: [false; MAX_PROMPT_PITCHES],
            attack_times: [0; MAX_PROMPT_PITCHES],
        }
    }

    fn expected_pitch(&self) -> u8 {
        self.prompt.pitches[0]
    }

    fn expected_index(&self, pitch: u8) -> Option<usize> {
        self.prompt.pitches[..usize::from(self.prompt.pitch_count)]
            .iter()
            .position(|candidate| *candidate == pitch)
    }

    fn clear_attacks(&mut self) {
        self.attacked = [false; MAX_PROMPT_PITCHES];
        self.attack_times = [0; MAX_PROMPT_PITCHES];
    }

    fn result(&self, status: u8, received_pitch: u8) -> BsValidationResult {
        BsValidationResult {
            status,
            expected_pitch: self.expected_pitch(),
            received_pitch,
            reserved: 0,
            response_time_ms: 0.0,
        }
    }
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
    const PARTIAL: u8 = 3;
    const UNAVAILABLE: u8 = 255;
}

#[unsafe(no_mangle)]
pub extern "C" fn bs_engine_new(expected_pitch: u8) -> *mut core::ffi::c_void {
    Box::into_raw(Box::new(PracticeEngine::new(expected_pitch))).cast()
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
        engine.prompt = BsPromptConfig::single(expected_pitch);
        engine.clear_attacks();
    }
}

/// Configures the next prompt without carrying attacks from the previous prompt.
///
/// # Safety
///
/// A null pointer is accepted. Every non-null pointer must be a live handle
/// returned by [`bs_engine_new`] that has not been released.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn bs_engine_configure_prompt(
    engine: *mut core::ffi::c_void,
    config: BsPromptConfig,
) {
    let Some(engine) = (unsafe { engine.cast::<PracticeEngine>().as_mut() }) else {
        return;
    };
    if config.pitch_count == 0
        || usize::from(config.pitch_count) > MAX_PROMPT_PITCHES
        || config.mode > PROMPT_FRESH_ATTACK_SET
        || config.pitches[..usize::from(config.pitch_count)]
            .iter()
            .any(|pitch| *pitch > 127)
    {
        return;
    }
    engine.prompt = config;
    engine.clear_attacks();
}

/// Clears held and in-progress attack state while retaining prompt configuration.
///
/// # Safety
///
/// A null pointer is accepted. Every non-null pointer must be a live engine handle.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn bs_engine_reset(engine: *mut core::ffi::c_void) {
    if let Some(engine) = unsafe { engine.cast::<PracticeEngine>().as_mut() } {
        engine.held = [false; 128];
        engine.clear_attacks();
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
    timestamp_ns: u64,
) -> BsValidationResult {
    // SAFETY: `as_mut` checks null; valid non-null pointers follow the engine ownership contract.
    let Some(engine) = (unsafe { engine.cast::<PracticeEngine>().as_mut() }) else {
        return BsValidationResult {
            status: BsValidationResult::UNAVAILABLE,
            expected_pitch: 0,
            received_pitch: pitch,
            reserved: 0,
            response_time_ms: 0.0,
        };
    };

    if pitch > 127 {
        return engine.result(BsValidationResult::UNAVAILABLE, pitch);
    }

    if velocity == 0 {
        engine.held[usize::from(pitch)] = false;
        return engine.result(BsValidationResult::IGNORED, pitch);
    }

    engine.held[usize::from(pitch)] = true;
    let Some(index) = engine.expected_index(pitch) else {
        engine.clear_attacks();
        return engine.result(BsValidationResult::INCORRECT, pitch);
    };

    if engine.prompt.mode == PROMPT_SINGLE_NOTE {
        return engine.result(BsValidationResult::CORRECT, pitch);
    }

    if engine.prompt.mode == PROMPT_EXACT_HELD_SET {
        let exact = engine.held.iter().enumerate().all(|(note, held)| {
            let expected = engine.prompt.pitches[..usize::from(engine.prompt.pitch_count)]
                .iter()
                .any(|pitch| usize::from(*pitch) == note);
            *held == expected
        });
        return engine.result(
            if exact {
                BsValidationResult::CORRECT
            } else {
                BsValidationResult::PARTIAL
            },
            pitch,
        );
    }

    let spread_ns = u64::from(engine.prompt.spread_ms) * 1_000_000;
    for candidate in 0..usize::from(engine.prompt.pitch_count) {
        if engine.attacked[candidate]
            && timestamp_ns > engine.attack_times[candidate]
            && timestamp_ns - engine.attack_times[candidate] > spread_ns
        {
            engine.attacked[candidate] = false;
        }
    }
    engine.attacked[index] = true;
    engine.attack_times[index] = timestamp_ns;

    let count = usize::from(engine.prompt.pitch_count);
    if engine.attacked[..count].iter().any(|attacked| !attacked) {
        return engine.result(BsValidationResult::PARTIAL, pitch);
    }
    let earliest = engine.attack_times[..count]
        .iter()
        .copied()
        .min()
        .unwrap_or(0);
    let latest = engine.attack_times[..count]
        .iter()
        .copied()
        .max()
        .unwrap_or(0);
    let status = if latest - earliest <= spread_ns {
        BsValidationResult::CORRECT
    } else {
        BsValidationResult::PARTIAL
    };
    engine.clear_attacks();
    engine.result(status, pitch)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn prompt(mode: u8, pitches: &[u8], spread_ms: u16) -> BsPromptConfig {
        let mut config = BsPromptConfig {
            mode,
            pitch_count: u8::try_from(pitches.len()).expect("test prompts fit the fixed ABI"),
            spread_ms,
            pitches: [0; MAX_PROMPT_PITCHES],
        };
        config.pitches[..pitches.len()].copy_from_slice(pitches);
        config
    }

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

    #[test]
    fn exact_held_set_requires_the_complete_jazz_voicing() {
        let engine = bs_engine_new(60);
        // SAFETY: `engine` remains live for all calls in this test.
        unsafe {
            bs_engine_configure_prompt(engine, prompt(PROMPT_EXACT_HELD_SET, &[60, 64, 67], 0));
            assert_eq!(
                bs_engine_process_note(engine, 60, 90, 0, 1).status,
                BsValidationResult::PARTIAL
            );
            assert_eq!(
                bs_engine_process_note(engine, 64, 90, 0, 2).status,
                BsValidationResult::PARTIAL
            );
            assert_eq!(
                bs_engine_process_note(engine, 67, 90, 0, 3).status,
                BsValidationResult::CORRECT
            );
            assert_eq!(
                bs_engine_process_note(engine, 71, 90, 0, 4).status,
                BsValidationResult::INCORRECT
            );
            bs_engine_free(engine);
        }
    }

    #[test]
    fn fresh_attack_set_rejects_stale_hanon_pairs() {
        let engine = bs_engine_new(36);
        // SAFETY: `engine` remains live for all calls in this test.
        unsafe {
            let config = prompt(PROMPT_FRESH_ATTACK_SET, &[36, 48], 120);
            bs_engine_configure_prompt(engine, config);
            assert_eq!(
                bs_engine_process_note(engine, 36, 90, 0, 1_000_000).status,
                BsValidationResult::PARTIAL
            );
            assert_eq!(
                bs_engine_process_note(engine, 48, 90, 0, 100_000_000).status,
                BsValidationResult::CORRECT
            );

            bs_engine_configure_prompt(engine, config);
            assert_eq!(
                bs_engine_process_note(engine, 36, 90, 0, 200_000_000).status,
                BsValidationResult::PARTIAL
            );
            assert_eq!(
                bs_engine_process_note(engine, 48, 90, 0, 321_000_000).status,
                BsValidationResult::PARTIAL
            );
            bs_engine_free(engine);
        }
    }
}
