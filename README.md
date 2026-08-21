# Board Sensei

Board Sensei is a native macOS piano-practice trainer. It discovers a MIDI keyboard, normalizes incoming events, plays them through a local sampler, and validates each note against an animated treble-clef exercise.

The current repository includes a 36-lesson Jazz Course, live MIDI diagnostics, audio monitoring, a SpriteKit staff, a canonical song model, and a Rust practice-engine ABI. The app remains usable without Rust installed by falling back to the small native bridge implementation.

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later, with Command Line Tools selected
- Swift 6 or later
- Optional: the current stable Rust toolchain from [rustup](https://rustup.rs/)
- Optional but recommended: a USB or Bluetooth MIDI keyboard

## Run it

From the repository root:

```sh
swift test
swift run BoardSensei
```

`swift run` stays attached to the terminal while the graphical application is open. Quit Board Sensei with **Command-Q** (or stop it with **Control-C**) to return to the shell prompt.

The Practice screen includes on-screen test keys, so a physical controller is not required to exercise the full validation flow.

To activate the Rust engine:

```sh
./scripts/build-rust.sh
swift run BoardSensei
```

Run the app from the repository root so the bridge can find `rust/target/release/libboard_sensei_music.dylib`. If launching elsewhere, set `BOARD_SENSEI_RUST_LIB` to that library's absolute path.

Run every available check with:

```sh
./scripts/verify.sh
```

The script always runs Swift tests. It also runs Rust tests and Clippy when `cargo` is installed.

## Using the app

1. Open **Courses** and select the **Jazz** card. The Classical card is a placeholder for a future course.
2. Choose Beginner, Intermediate, or Advanced, expand a chapter, and select a lesson.
3. Review its objective, note route, practice focus, and related source chapters.
4. Select **Start Practice** to enter class mode. Theory, exercise instructions, and the prompt route appear in the left guide while other destinations move to the top bar.
5. Use the class transport to turn the metronome on, set its independent volume, choose a common time signature, and adjust tempo from 50–180 BPM.
6. Use **Hear full exercise** in the class guide to preview the complete exercise. If enabled, the metronome and exercise restart together on beat one and remain synchronized while the staff, piano, and lesson route follow playback without changing the score.
7. Play each highlighted note or complete chord voicing with a MIDI keyboard or the on-screen five-octave piano. Chord prompts also provide **Play shown chord** for hardware-free practice.
8. Use **Previous** and **Next** at the bottom of the class guide, or open the chapter menu to jump directly to any lesson in the current chapter.
9. Open a lesson's **Topic page** before starting: it provides the full concept explanation, why it matters, a step-by-step preparation plan, listening guidance, pass condition, and complete route.
10. Choose **Listen to topic** to hear the bundled studio narration. If a current recording is unavailable, the player identifies and uses the Mac system voice as a fallback. It supports pause, resume, and stop and ends automatically when you leave the page.
11. During Practice, use the compact class guide for the key concept and immediate playing instructions without leaving the instrument view.
12. Completed lessons are saved automatically on this Mac and shown as ticks on the course path.
13. Open **MIDI Lab** to select a device, inspect normalized events, or recover from a stuck note with **Panic**.

The sampler first looks for a bundled `Piano.sf2`. Until a licensed SoundFont is added, it uses the system General MIDI bank when available. Do not commit a third-party SoundFont without confirming redistribution rights.

## Topic narration

Topic narration is generated ahead of release with the free, local [Kyutai Pocket TTS](https://github.com/kyutai-labs/pocket-tts) model and bundled as its native 24 kHz mono WAV audio. The shipped app makes no TTS network call and contains no service credential or Python runtime. Each lesson exposes one canonical, speech-friendly `narrationScript` and SHA-256 content hash. `manifest.json` records that hash alongside the generated file, voice, voice license, model configuration, and generation date. The app plays a recording only when its hash matches the current script; otherwise it reports and uses the system-voice fallback.

Generation requires [`uv`](https://docs.astral.sh/uv/getting-started/installation/). Pocket TTS supports Python 3.10 through 3.14, but `uvx` creates and manages that environment independently of the system Python. The first real generation downloads the model; subsequent runs reuse the local cache.

The complete 36-lesson catalog can take several minutes to synthesize on CPU. The generator displays lesson-level progress (`[current/total]`) and an elapsed-time heartbeat every ten seconds. Pocket TTS does not expose a trustworthy percentage within one lesson, so the heartbeat is intentionally time-based. Its own output remains visible, and the manifest is saved after every completed lesson, so an interrupted run can be resumed by running the same command again.

Each lesson is first written under macOS's per-user temporary directory, commonly `/var/folders/.../T`. This staging file prevents a failed or interrupted synthesis from leaving a corrupt course asset. After Pocket TTS succeeds, the generator atomically saves the WAV under `Sources/BoardSenseiApp/Resources/Narration`, updates the manifest, and deletes the temporary directory.

Preview which lessons are missing or stale:

```sh
swift run BoardSenseiNarrationTool --dry-run
```

Generate only missing or changed lessons with the default Alba voice:

```sh
swift run BoardSenseiNarrationTool
```

Generate or review one lesson while tuning pronunciation:

```sh
swift run BoardSenseiNarrationTool --lesson i-altered --force
```

Before release, require a complete matching asset set:

```sh
swift run BoardSenseiNarrationTool --check
```

The default `alba` voice is distributed under CC BY 4.0 and is recorded as such in the manifest. A custom Pocket TTS voice can be a built-in name, local file, or supported URL, but its license must be supplied explicitly:

```sh
swift run BoardSenseiNarrationTool \
  --voice /path/to/reviewed-voice.wav \
  --voice-license CC0-1.0 \
  --force
```

Use only voices whose terms permit the intended app distribution. In particular, do not ship output derived from Pocket TTS voices marked noncommercial in the [official voice repository](https://huggingface.co/kyutai/tts-voices). The model is CC BY 4.0; Pocket TTS code is MIT licensed. Review generated speech for jazz terminology, note names, pacing, artifacts, and consistent loudness before committing an audio asset. See [ADR 001](docs/decisions/001-topic-narration.md) for the full decision and invalidation design.

## Jazz Course

The Jazz Course has three stages, each containing four modules and twelve short exercises:

- **Beginner:** intervals and triads, the major-key map, shell voicings and suspensions, then basic extensions and transposition.
- **Intermediate:** guide-tone motion, tritone substitution, chord-scale fluency, modal and quartal colors, upper structures, and pentatonic application.
- **Advanced:** altered harmony, advanced voicing movement, stride and bebop language, Latin-jazz cells, comping, and integrated improvisation practice.

The curriculum map is based on the concepts and chapter progression in Mark Levine's *The Jazz Piano Book*. All lesson names, theory summaries, objectives, instructions, and playable exercises in the app are original teaching material. The book itself is not bundled or reproduced; learners should use their own lawful copy for the referenced reading.

## Architecture

```text
CoreMIDI callback
    -> bounded AsyncStream of normalized events
    -> AppModel
       -> AVAudioUnitSampler
       -> C bridge
          -> Rust music-core when its dylib is present
          -> deterministic native fallback otherwise
       -> SwiftUI + SpriteKit feedback
```

- `Sources/MusicCore` contains platform-independent Swift contracts, the canonical song timeline, MIDI parsing, and test fixtures.
- `Sources/BoardSenseiApp` owns macOS UI and Apple framework integration.
- `Sources/BoardSenseiNarrationTool` is the release-time narration generator; it is not linked into the application.
- `Sources/BoardSenseiApp/Resources/Narration` contains the hash manifest and reviewed, distributable narration assets.
- `Sources/CBoardSenseiBridge` loads the Rust engine through a narrow C ABI without making Rust a prerequisite for contributors.
- `rust/music-core` is the portable engine. MIDI-file import, transport, scoring, and later analysis belong here.
- `Tests/MusicCoreTests` verifies deterministic parsing and validation.
- [`agent.md`](agent.md) is the detailed build and contribution guide for coding agents.

## Current scope

Implemented:

- Hot-plug-aware MIDI source discovery and selection
- Note-on, note-off, sustain, and control-change normalization
- Bounded event delivery outside CoreMIDI's high-priority callback
- Live diagnostics with the latest 100 events
- Local sampler playback, live output metering, volume control, and all-notes-off recovery
- Interactive five-octave piano spanning MIDI C2–C7, with mouse, MIDI, and computer-key input
- Animated, accessible treble-clef exercise
- Correct/incorrect validation, streak, mistakes, and lesson progress
- A three-stage Jazz Course with 12 modules and 36 playable lessons
- Persistent per-lesson completion progress
- Card-based course catalog with a Classical-course placeholder
- Collapsible Jazz chapters with saved completion ticks
- Lesson-aware treble, bass, or grand-staff notation
- Simultaneous chord prompts with full-voicing staff and keyboard highlighting
- Verbose, optionally narrated Topic pages paired with a compact in-class key-concept sidebar
- Content-addressed studio narration with incremental generation and a safe system-voice fallback
- Full-exercise audio preview with persisted tempo selection and synchronized staff/piano highlighting
- Independent metronome toggle and volume with accented downbeats, common time signatures, and preview synchronization
- In-class Previous/Next navigation and a current-chapter lesson picker with completion status
- A consistent studio-blue accent throughout the app, paired with a neutral graphite Practice workspace, Logic-inspired panel shading, thin section separators, compact control surfaces, and contextual Quick Help
- Swift and Rust canonical music-model foundations
- Runtime Rust bridge with a no-toolchain fallback

Next milestones:

1. Bundle a licensed piano SoundFont and add audio-device selection.
2. Persist profiles, settings, and detailed lesson attempts with SwiftData.
3. Add simultaneous chord validation, timing windows, and deterministic lesson generation in Rust.
4. Import Standard MIDI Files into the canonical tick-based timeline.
5. Add transport, count-in, looping, and 50/75/100% practice tempo.
6. Add MusicXML, then editable audio beat/chord analysis.

## Design and engineering references

The implementation follows primary platform guidance:

- [CoreMIDI receive callbacks](https://developer.apple.com/documentation/coremidi/midireceiveblock) run on a high-priority thread, so the callback performs bounded parsing and enqueueing only.
- [AVAudioUnitSampler](https://developer.apple.com/documentation/avfaudio/avaudiounitsampler) supports DLS and SF2 instruments.
- [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility) requires alternatives to color-only feedback and appropriate Reduce Motion behavior.
- [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/) informs resizable layouts, keyboard access, and information density.
- [Swift Testing](https://developer.apple.com/documentation/testing) is used for unit tests and works directly with Swift Package Manager.
- [The Rustonomicon FFI guidance](https://doc.rust-lang.org/nomicon/ffi.html) informs the fixed-width C ABI, opaque engine ownership, and no-unwind boundary.
