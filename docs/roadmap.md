# Scope and roadmap

## Available today

- MIDI device discovery, normalized input, live diagnostics, sustain, and all-notes-off recovery.
- A five-octave piano with MIDI, mouse, and computer-key input, plus accessible treble, bass, and grand-staff notation.
- Jazz and Hanon courses with distinct notation and validation rules in one shared lesson workspace; see [course details](courses.md).
- Exercise demonstrations, repeating playback, a metronome, instrument selection, and scored practice loops.
- Saved lesson progress, mastery records, accuracy personal bests, onboarding, and configurable completion feedback.
- Offline lesson narration with incremental generation and a system-voice fallback.
- Settings for the learning profile, keyboard indicators, and practice preferences.
- Platform-independent music models and a Rust validation engine with a native fallback.

See the [user guide](usage.md) for controls and [architecture](architecture.md) for implementation details. Classical is currently a course placeholder; Hanon Parts II and III await verification.

## Next milestones

1. License, audition, and bundle a GM-compatible multi-sampled SoundFont, then add audio-device and buffer-size selection.
2. Migrate the current local profile and mastery records from UserDefaults to SwiftData when multi-profile support is introduced.
3. Add deterministic lesson generation and richer timing/accuracy scoring in Rust.
4. Import Standard MIDI Files into the canonical tick-based timeline.
5. Add count-in, loop-range selection, and 50/75/100% practice tempo presets.
6. Add MusicXML, then editable audio beat/chord analysis.
