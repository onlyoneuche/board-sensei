# Coding-agent build guide

This file is the operational contract for agents working on Board Sensei. Keep it current whenever build commands, architecture, or verification requirements change.

## Start here

1. Read `README.md` and inspect `git status --short`.
2. Preserve unrelated user changes. Never discard or rewrite them to simplify a task.
3. Use the smallest feature slice that leaves the app runnable and testable.
4. Run `./scripts/verify.sh` before handing off. If Rust is unavailable, report that its checks were skipped.

## Build commands

```sh
# Swift library, app, and C bridge
swift build

# Swift unit tests
swift test

# Rust engine (requires rustup/cargo)
./scripts/build-rust.sh

# Rust tests and lints
cargo test --manifest-path rust/Cargo.toml
cargo clippy --manifest-path rust/Cargo.toml --all-targets -- -D warnings

# Launch from the repository root
swift run BoardSensei

# All available non-UI checks
./scripts/verify.sh
```

If the Rust dylib is outside its default location, launch with:

```sh
BOARD_SENSEI_RUST_LIB=/absolute/path/to/libboard_sensei_music.dylib swift run BoardSensei
```

## Ownership boundaries

### Swift app

Swift owns SwiftUI, SpriteKit, CoreMIDI discovery/connection, AVAudioEngine, app lifecycle, accessibility, and future SwiftData persistence.

- Keep Apple-framework types out of `MusicCore` and Rust.
- UI code consumes normalized values and never parses raw MIDI packets.
- Keep views declarative; orchestration belongs in `AppModel` or a focused service.
- Use Swift concurrency and actor isolation for state. Do not silence Sendable errors casually.

### Rust engine

Rust owns canonical music data, transport, exercise generation, matching, scoring, and offline analysis.

- Keep `rust/music-core` free of AppKit, SwiftUI, CoreMIDI, and AVFAudio concepts.
- Represent authoritative musical time with ticks/beats plus a tempo map, not seconds alone.
- Keep real-time validation deterministic and allocation-bounded.
- Add unit tests beside every new rule or state transition.

### FFI boundary

The C ABI is a compatibility boundary, not a place for product logic.

- Use fixed-width integers, `#[repr(C)]` structs, opaque pointers, and explicit create/free functions.
- Never pass Swift or Rust strings, collections, closures, references, or owned buffers directly across the boundary.
- Do not let Rust panics unwind into C/Swift. Release builds use `panic = "abort"`; exported functions must still validate pointer inputs and avoid panics.
- Update both `rust/include/board_sensei.h` and `Sources/CBoardSenseiBridge/include/BoardSenseiBridge.h` when the contract changes.
- Preserve the native fallback unless the repository makes Rust a documented hard prerequisite.

## Real-time rules

CoreMIDI invokes its receive callback on a high-priority thread. Inside that callback:

- Parse only the bytes required to normalize the event.
- Yield to the bounded `AsyncStream` and return.
- Never touch SwiftUI state, AVAudioEngine graphs, files, databases, the network, logging, model inference, or unbounded queues.

Inside any future audio render callback, also forbid allocation, locks, actors/tasks, and Objective-C messaging. Control AVAudioEngine and its sampler outside the render callback.

## Product and design rules

- Preserve a native, resizable macOS experience with useful keyboard access.
- The staff and next required action must stay readable during animation.
- Use semantic/system colors where practical and test light, dark, and increased-contrast appearances.
- Never communicate correctness with color alone; pair it with text, shape, and a symbol.
- Read `accessibilityReduceMotion` and replace energetic motion with static or fading feedback.
- Give every custom musical visualization a useful accessibility label and value.
- A MIDI keyboard must not be required for development; maintain simulated input controls.
- Do not copy another learning product's artwork or layout. Preserve Board Sensei's own visual identity.
- Use flat semantic colors; do not introduce color gradients. Materials may be used sparingly for native macOS depth, but content hierarchy must not depend on decorative effects.
- Use the standard macOS system font and default design consistently. Reserve monospaced variants for MIDI values, note routes, tempo, counters, and other data.
- Keep persistent labels concise. Move nonessential control explanations into contextual Quick Help with the shared `.quickHelp(title, detail)` modifier; keep accessibility labels even when visible picker labels are hidden.

## Course authoring

- Define platform-neutral course structures in `Sources/MusicCore/CourseModel.swift` and catalog content in `JazzCourseCatalog.swift`.
- Keep lesson IDs stable and unique. They are persistence keys; renaming one discards the learner's stored completion for that lesson.
- Every current lesson must have at least one MIDI pitch, a concise objective, an actionable practice instruction, and one or more source chapter numbers.
- Keep pitches in MIDI's `0...127` range. Use the `pitches:` initializer for melodic single-note prompts and the `chords:` initializer for simultaneous voicings. A chord prompt advances only when its exact pitch set is held; do not encode chord lessons as arpeggios.
- Every lesson needs both a short, original `theory` key concept for the in-class guide and a distinct, more detailed `studyGuide` explanation for the Topic page. Keep both separate from the actionable exercise instruction.
- Use the Topic page for context, listening goals, preparation, narration, and success criteria. Keep the live Practice sidebar concise so it remains scannable while the learner is playing.
- Topic narration prefers a hash-verified bundled recording and uses the retained native `AVSpeechSynthesizer` only as a missing/stale-asset fallback. `LessonNarrationService` must stop either source when leaving the Topic page or entering Practice; do not add narration controls to Practice mode.
- `PracticeLesson.narrationScript` is the canonical generation input. Normalize musical language there rather than altering display copy. Its SHA-256 hash is the cache key and must match `Resources/Narration/manifest.json` before recorded audio can play.
- Generate narration only through `BoardSenseiNarrationTool`. It reads credentials from `ELEVENLABS_API_KEY` and `ELEVENLABS_VOICE_ID`, regenerates changed lessons only, writes content-addressed filenames atomically, and never persists the API key. Run `--check` before a release and manually review pronunciation before committing generated audio.
- Keep the live Practice workspace visually neutral and studio-like. Use `PracticeTheme` for graphite surfaces, panel hierarchy, separators, and active-state blue; reserve green and orange for semantic success and warning feedback. Course-level colors must not bleed into Practice mode.
- Use `AppTheme.accent` for interactive emphasis throughout every screen. Do not introduce purple or indigo; reserve green, orange, and red for meaningful status or feedback.
- Exercise preview is non-scoring: send preview notes directly through `AudioService` on its preview channel, expose them as display state, and never feed them through the practice validator or completion counters.
- Stop preview playback on lesson reset, lesson change, and class exit so no sampler notes or animation state can leak into another screen.
- The metronome uses its own `AVAudioPlayerNode`, buffers, MIDI-independent volume, and clock state. Keep it synchronized with preview by scheduling the click and prompt from the same beat loop; do not run competing timers during preview.
- Treat BPM as quarter-note tempo and scale beat duration by the time-signature denominator. Accent beat zero of every bar and test timing math in `PracticeTimeSignatureTests`.
- Staff selection is derived from the lesson's complete pitch range: pitches below middle C use bass, pitches at or above middle C use treble, and lessons spanning both use a grand staff. Add an explicit notation override only when pedagogy requires one.
- Course material inspired by a copyrighted source must be newly written. Reference chapter concepts; do not copy prose, notation, exercises, song transcriptions, artwork, or long lists from the source.
- Update `JazzCourseCatalogTests` when the expected number of stages, modules, or lessons changes.
- Keep in-class Previous/Next ordering derived from the catalog rather than duplicated in UI state. Chapter menus remain chapter-scoped; boundary navigation may continue into the adjacent chapter or level.

## Testing expectations

At minimum, cover:

- MIDI running status and velocity-zero note-on behavior.
- Note, chord, and timing validation success and failure paths.
- FFI null/ownership edge cases.
- Tempo-map and tick/sample conversion at tempo changes.
- Device disconnect and all-notes-off behavior when those services change.

Use Swift Testing for library/service tests. Use XCTest only where UI or Objective-C/C integration requires it. Tests must not require a physical MIDI controller or audio output device.

## Feature order

1. Keep the MIDI-to-feedback vertical slice healthy.
2. Add persistence and deterministic exercise generation.
3. Add Standard MIDI File import and transport.
4. Add chords, timing, count-in, looping, and performance scoring.
5. Add MusicXML.
6. Add editable audio beat/chord analysis.
7. Treat mixed-audio polyphonic transcription as research, not an MVP dependency.

## Primary references

- [CoreMIDI callback behavior](https://developer.apple.com/documentation/coremidi/midireceiveblock)
- [AVAudioUnitSampler](https://developer.apple.com/documentation/avfaudio/avaudiounitsampler)
- [Apple accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Apple motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion)
- [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/)
- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Rust FFI guidance](https://doc.rust-lang.org/nomicon/ffi.html)
