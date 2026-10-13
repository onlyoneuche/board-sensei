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

Rust is the portable home for canonical music data, deterministic exercise generation, matching, scoring, transport data, and offline analysis. At present its runtime contribution is prompt validation and score state; Swift still constructs the preview timeline and AVFAudio schedules and renders it.

- Keep `rust/music-core` free of AppKit, SwiftUI, CoreMIDI, and AVFAudio concepts.
- Represent authoritative musical time with ticks/beats plus a tempo map, not seconds alone.
- Keep real-time validation deterministic and allocation-bounded.
- Add unit tests beside every new rule or state transition.
- Do not route CoreMIDI or audio-render callbacks through Rust merely to increase Rust usage. Move a responsibility only when a portable deterministic core benefits it, and keep Apple audio-device and render ownership in Swift.

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

Treat an `AVAudioEngine` and its attached nodes as one ownership domain. Keep the current graph inside the `@MainActor`-isolated `AudioService`; never move those objects or a captured `scheduleMIDIEventBlock` through `@unchecked Sendable` into a detached task. Keep live and preview sampler instances separate so concurrent playing cannot share note-off or voice state. Never call `AVAudioUnitSampler.startNote` from an ad-hoc background queue, and never schedule preview notes with `Task.sleep`, timers, SwiftUI animation completion, or main-run-loop callbacks. Precompute a `PracticePlaybackTimeline`, convert it to absolute audio-render sample times, fetch and invoke the preview sampler's MIDI scheduling block locally within `AudioService`, and let the UI observe the render playhead. Refill a looping schedule before its queued horizon expires. If ownership later needs to leave the main actor, introduce an explicitly isolated audio executor that owns the complete graph for its entire lifetime rather than transferring existing Apple audio objects between executors.

## Product and design rules

- Preserve a native, resizable macOS experience with useful keyboard access.
- The staff and next required action must stay readable during animation.
- Use semantic/system colors where practical and test light, dark, and increased-contrast appearances.
- Never communicate correctness with color alone; pair it with text, shape, and a symbol.
- Read `accessibilityReduceMotion` and replace energetic motion with static or fading feedback.
- Give every custom musical visualization a useful accessibility label and value.
- A MIDI keyboard must not be required for development; maintain simulated input controls.
- When a MIDI device is connected, MIDI Lab mirrors incoming notes on a read-only five-octave keyboard. Reuse the Practice keyboard geometry, but keep this monitor free of lesson targets, note labels, shortcut labels, and pointer input.
- Do not copy another learning product's artwork or layout. Preserve Board Sensei's own visual identity.
- Keep the visual system consistent across Courses, onboarding, lesson guides, Practice, MIDI Lab, Foundation, and Settings: small-radius flat panels, fine rules, generous content spacing, and restrained musical linework. Follow system light/dark appearance, including notation ink; never force Practice into dark mode. Decorative notation must be hidden from accessibility and ignore pointer input.
- Use flat semantic colors; do not introduce color gradients. Materials may be used sparingly for native macOS depth, but content hierarchy must not depend on decorative effects.
- Use the standard macOS system font and default design consistently. Reserve monospaced variants for MIDI values, note routes, tempo, counters, and other data.
- Keep persistent labels concise. Move nonessential control explanations into contextual Quick Help with the shared `.quickHelp(title, detail)` modifier; keep accessibility labels even when visible picker labels are hidden. The modifier must use native help or an AppKit-owned tracking bridge—never mutate the shared observable app model synchronously from SwiftUI `onHover`, because controls that change identity under the pointer can leave a stale hover responder and crash.
- First launch uses a replayable four-step onboarding flow: goal, experience, optional MIDI setup, and one playable first note. It must never require MIDI or lock course access.
- Keep gamification tied to learning evidence: Introduced on lesson entry, Practised after completion, and Mastered after three completions with best accuracy of at least 90%. Do not add coins, lives, punitive missed-day messaging, or unrelated XP.
- Completion celebrations must respect both the app preference and `accessibilityReduceMotion`. Completion audio is a dedicated, locally synthesized high-register chime sequence, remains independent of the selected practice instrument, stays optional, and must be cancelled when practice or preview state changes.
- Never interrupt a completed player with a blocking success modal. Keep pass results inline so the staff and keyboard remain usable, and offer manual repeat, scored practice looping, and learner-controlled Next navigation there.
- Pin pass results directly above the practice piano, outside the scrolling notation region, so completion actions remain visible without scrolling at every supported window height.
- When a pass completes, immediately present its first selected prompt again on the staff and piano. Keep scoring paused until the learner explicitly repeats or the practice-loop clock reaches beat one.
- The Board Sensei mark is a compact side-profile grand piano and seated learner, crossed by one studio-blue guidance gesture. Keep its bundled source asset, Dock icon, onboarding identity, and navigation lockup visually consistent; preserve the solid off-white presentation tile for light/dark contrast, and do not add a mascot without an explicit product decision.
- Treat Courses as the welcoming studio home: center a larger existing brand mark, keep learning status compact, and present course cards in a horizontally scrollable shelf that remains useful at narrow and wide window sizes. Preserve the Classical placeholder until its curriculum is implemented.
- Prefer visual affordances over persistent explanatory text for familiar interactions such as horizontal scrolling. Preserve explicit accessibility labels and hints even when the visible instruction is only an icon, partial card, divider, or other spatial cue.

## Course authoring

- Define platform-neutral course structures in `Sources/MusicCore/CourseModel.swift` and register every catalog in `CourseLibrary.swift`.
- Every course declares one typed `PracticeExperience`, and every lesson carries the matching typed exercise payload. Do not infer behavior from lesson IDs, optional metadata, pitch count, or catalog lookup inside UI/session code.
- Keep course and lesson IDs stable. Progress is stored under `courseID::lessonID`; renaming either identifier discards the learner's stored completion for that lesson.
- Every current lesson must have at least one MIDI pitch, a concise objective, an actionable practice instruction, and one or more source chapter numbers.
- Keep pitches in MIDI's `0...127` range. Jazz uses the `pitches:` initializer for melodic prompts and `chords:` for simultaneous voicings. Hanon uses its fingered-prompt initializer and required score metadata. Never infer a chord merely because a prompt contains multiple pitches.
- Launch lessons through `CourseLessonContext` so navigation, persistence, presentation, and validation retain the owning course. Construct a fresh `PracticeSession` on every lesson change; never carry Hanon hand/range/tempo state into Jazz.
- Keep the workspace shell, MIDI/audio services, transport, result strip, and piano shared. Compose course-specific notation and controls from `PracticePresentation`: Jazz owns the adaptive prompt staff, while Hanon owns the complete score and focused-practice controls.
- Configure matching explicitly: Jazz melodic prompts use single-note attacks, Jazz chords use exact held sets, Hanon both-hands prompts use fresh attacks within 120 ms, and isolated Hanon hands use single-note attacks. Keep Rust and the native bridge fallback behavior identical.
- Author Jazz prompt pitches relative to C and keep tonal instructions functional rather than hard-coded to C note names. `JazzPracticeKey` transposes prompts inside `PracticeSession`; the selected key must drive notation spelling, staff layout, piano targets, route labels, preview playback, and validator configuration together. It must never alter Hanon's register.
- Preserve Hanon's verified catalog pitches as written source data. `PracticeSession` may move the complete Hanon route up one octave when every shifted note fits the shared C2–C7 piano, and must otherwise retain the written register. Apply one offset to both hands, then project the selected Both/Right/Left hand mode through the score payload, route labels, piano targets, fingering, preview, validation, and completion count. Presentation code must not recover the unfiltered source prompt after the session has selected a hand. Changing hand mode or measure range must be silent, discard the prior scheduled-preview sampler generation, reset the playhead to the first selected source prompt, and wait for an explicit **Hear full exercise** action.
- Every lesson needs both a short, original `theory` summary and a distinct, more detailed `studyGuide` explanation. Keep both separate from the actionable exercise instruction; the unified class guide presents the detailed material while `theory` remains available for concise contexts.
- Opening a course lesson enters one unified lesson/practice workspace. Its resizable, vertically scrollable left guide owns the complete explanation, purpose, preparation plan, listening goals, success criteria, narration, preview, and route; the right workspace owns live progress, staff, feedback, and keyboard.
- Lesson narration prefers a hash-verified bundled recording and uses the retained native `AVSpeechSynthesizer` only as a missing/stale-asset fallback. `LessonNarrationService` must stop either source when changing lessons, starting exercise preview, or leaving class mode.
- `PracticeLesson.narrationScript` is the canonical generation input. Normalize musical language there rather than altering display copy. Its SHA-256 hash is the cache key and must match `Resources/Narration/manifest.json` before recorded audio can play.
- Generate narration only through `BoardSenseiNarrationTool`. It discovers every registered catalog through `CourseLibrary`, supports `--course` for a scoped batch without pruning other courses, runs Pocket TTS locally through `uvx`, retains its native 24 kHz mono WAV output, regenerates changed lessons only, and writes content-addressed filenames atomically. Keep subprocess progress visible and checkpoint the manifest after every completed lesson so catalog generation is safely resumable. A custom voice must include `--voice-license`; use only voices licensed for the intended distribution and retain required attribution. Run `--check` across the complete library before a release and manually review pronunciation, artifacts, loudness, and bundled size before committing generated audio.
- Keep the live Practice workspace visually neutral and studio-like. Use `AppTheme` and `PracticeTheme` for appearance-aware paper and graphite surfaces, fine panel borders, compact section labels, and active-state blue; reserve green and orange for semantic success and warning feedback. Course-level colors must not bleed into Practice mode.
- Use `AppTheme.accent` for interactive emphasis throughout every screen. Do not introduce purple or indigo; reserve green, orange, and red for meaningful status or feedback.
- Piano note state must fill the complete key, retain a contrasting label and border, and preserve a non-color cue through its state symbol and accessibility value. Expected and pressed/preview colors are user preferences stored through `KeyboardIndicatorPreferences`; expose them in the shared Settings view and keep reset defaults within the studio-blue family.
- Exercise playback is non-scoring: **Hear full exercise** is the sole play/stop action, and its adjacent repeat icon toggles whether that playback cycles. Build its immutable event list in `PracticePlaybackTimeline`. Choose one future host-time origin, convert that origin into the preview sampler's local render-sample domain, start the PCM metronome at the same host time, and derive the observed playhead from that host clock. Start audio synchronously before publishing an active transport; a task may observe playback but must never own deferred startup. Never feed preview events through the practice validator or completion counters. Main-actor stalls may delay only visual updates, never already queued audible notes.
- Space is a global stop-only shortcut while demonstration or loop playback is active. Handle it at the AppKit event boundary before focused SwiftUI controls can reinterpret Space as activation; consume it only when preview playback is active, and otherwise preserve normal keyboard behavior and the labeled A–K piano shortcuts.
- Stop preview playback on lesson reset, lesson change, and class exit so no sampler notes or animation state can leak into another screen.
- The metronome toggle only arms clicks; it must never start a standalone clock. Render preview clicks into one PCM buffer at the selected tempo and written meter, and play or loop it through the retained `AVAudioPlayerNode` from the same host-time origin as the scheduled MIDI packets. Do not reintroduce `AVAudioSequencer`/`AVMusicTrack` runtime construction: the macOS 26 crash trace and automated Hanon smoke showed freed framework state during `AVMusicTrack.addEvent`. Restart an active preview when tempo or loop mode changes so the PCM cycle and note schedule stay aligned. Keep one MIDI-independent volume across preview and scored-practice clicks. Queue practice-loop pass resets inside its clock on beat zero; pad demonstration-cycle repetitions to the next complete measure so every repetition restarts on beat one.
- Practice instruments are zero-based General MIDI programs grouped by `PracticeInstrument`. Load the chosen program into both live and preview samplers, send all-notes-off before switching, fall back from an incompatible bundled SF2 to the system DLS bank, persist the successful selection, and apply one program consistently to live, simulated, preview, and loop notes. A release SoundFont belongs in `Resources/Instruments` as `BoardSensei.sf2` with its license and attribution; it must be GM-compatible and every exposed program must be auditioned. Never bundle Logic Pro factory assets.
- Treat BPM as quarter-note tempo and scale beat duration by the time-signature denominator. Accent beat zero of every bar and test timing math in `PracticeTimeSignatureTests`.
- Staff selection is derived from the lesson's complete pitch range: pitches below middle C use bass, pitches at or above middle C use treble, and lessons spanning both use a grand staff. Add an explicit notation override only when pedagogy requires one.
- Course material inspired by a copyrighted source must be newly written. Reference chapter concepts; do not copy prose, notation, exercises, song transcriptions, artwork, or long lists from the source.
- Update `JazzCourseCatalogTests` when the expected number of stages, modules, or lessons changes.
- Keep in-class Previous/Next ordering derived from the catalog rather than duplicated in UI state. Chapter menus remain chapter-scoped; boundary navigation may continue into the adjacent chapter or level.

## Testing expectations

For an interactive crash, use the built-in `[BS-TRACE]` boundary log before changing architecture speculatively. Debug builds write synchronously to stderr and `/tmp/board-sensei-<PID>.log`. Reproduce once, compare the last `appkit-event` with `button-action`, and then follow the `preview`, `audio`, `narration`, or `piano-input` phases. Never add diagnostic file I/O to the CoreMIDI receive callback or an audio render callback. Disable the trace with `BOARD_SENSEI_DIAGNOSTICS=0` when measuring latency.

At minimum, cover:

- MIDI running status and velocity-zero note-on behavior.
- Note, chord, and timing validation success and failure paths.
- Hanon-to-Jazz and Jazz-to-Hanon session switching, presentation isolation, fresh paired attacks, and course-namespaced progress migration.
- Jazz transposition across all 12 keys, exact-chord policy retention, playable MIDI range, Hanon isolation from the Jazz key, and Hanon practice-register fitting without mutating its verified catalog.
- FFI null/ownership edge cases.
- Tempo-map and tick/sample conversion at tempo changes.
- Preview-timeline event identity, compound-meter bar alignment, loop wraparound, and end padding. Audio/UI integration smoke tests must confirm that window resizing and concurrent live notes do not interrupt a scheduled preview.
- Device disconnect and all-notes-off behavior when those services change.

Use Swift Testing for library/service tests. Use XCTest only where UI or Objective-C/C integration requires it. Tests must not require a physical MIDI controller or audio output device.

## Feature order

1. Keep the MIDI-to-feedback vertical slice healthy.
2. Add persistence and deterministic exercise generation.
3. Add Standard MIDI File import and transport.
4. Add chords, timing, count-in, loop-range selection, and performance scoring.
5. Add MusicXML.
6. Add editable audio beat/chord analysis.
7. Treat mixed-audio polyphonic transcription as research, not an MVP dependency.

## Primary references

- [CoreMIDI callback behavior](https://developer.apple.com/documentation/coremidi/midireceiveblock)
- [AVAudioUnitSampler](https://developer.apple.com/documentation/avfaudio/avaudiounitsampler)
- [Audio-unit MIDI scheduling](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/schedulemidieventblock)
- [Apple accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Apple motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion)
- [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/)
- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Rust FFI guidance](https://doc.rust-lang.org/nomicon/ffi.html)
