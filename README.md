# Board Sensei

Board Sensei is a native macOS piano-practice trainer. It discovers a MIDI keyboard, normalizes incoming events, plays them through a local sampler, and validates notes and chord voicings against animated treble, bass, or grand-staff exercises.

The current repository includes a 36-lesson Jazz Course, a verified 20-lesson Hanon Part I technique course, live MIDI diagnostics, audio monitoring, a SpriteKit staff, a canonical song model, and a Rust practice-engine ABI. The app remains usable without Rust installed by falling back to the small native bridge implementation.

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

1. First launch opens a four-step onboarding flow: choose a practice goal and starting point, connect or skip a MIDI controller, then play middle C for an immediate first feedback moment. **Skip setup** remains available, and onboarding can be replayed later from Settings.
2. Open **Courses** and select **Jazz** or **Hanon Technique**. Jazz initially opens at the level selected during onboarding, while Hanon currently contains the verified Part I exercises.
3. Choose Beginner, Intermediate, or Advanced, expand a chapter, and select a lesson.
4. The lesson opens directly in the unified class workspace. Its scrollable left guide contains the complete explanation, purpose, preparation plan, listening focus, success criterion, narration, exercise preview, and route. Jazz uses its adaptive prompt staff and exact chord rules; Hanon uses its complete written score, fingering, hand selection, and measure-range controls.
5. Drag the divider between the guide and instrument workspace left or right to choose how much room each side receives.
6. In a Jazz lesson, use the **Key** menu beside the metronome to choose any of the 12 tonal centers. The complete exercise is transposed from its C-relative source: staff notation and accidentals, piano targets, note names, route, preview, and MIDI validation all change together. The choice is retained for the next Jazz lesson and never affects Hanon.
7. Use the class transport to arm the metronome, set its independent volume, choose a common time signature, and adjust tempo from 50–180 BPM. Arming the metronome is silent; clicks sound only during exercise playback or the explicit scored practice loop.
8. Use **Hear full exercise** for one complete demonstration. Toggle the adjacent repeat icon before or during playback to cycle that demonstration continuously. The cycle follows the selected tempo, pads each repetition to a complete measure, and restarts on beat one while the metronome, staff, piano, and lesson route remain synchronized without changing the score.
9. Press **Space** while a demonstration or loop is running to stop it. Space is stop-only and does nothing while playback is idle.
10. Choose **Listen** in Lesson narration to hear the bundled studio recording. If a current recording is unavailable, the player identifies and uses the Mac system voice as a fallback. It supports pause, resume, and stop and ends automatically when you change lessons or leave class mode.
11. Play each highlighted Jazz note or exact chord voicing, or each fresh Hanon hand pair, with a MIDI keyboard or the on-screen five-octave piano. Hanon pairs allow 120 ms between hands but must be re-articulated for every written step. Jazz chord prompts also provide **Play shown chord** for hardware-free practice.
12. Select the instrument icon beneath the output meter to choose a grand piano, electric piano, synth lead, or synth pad. The selection is saved and applies to live playing, demonstrations, and loops.
13. Use **Previous** and **Next** at the bottom of the class guide, or open the chapter menu to jump directly to any lesson in the current chapter.
14. Completing a pass shows a compact inline result strip without covering the staff or piano. Choose **Practise again**, start **Loop with metronome** for automatically repeated scored passes aligned to beat one, or continue to the next lesson only when comfortable. Lesson records are saved automatically: entry marks a lesson **Introduced**, one completion marks it **Practised**, and three completions with a best accuracy of at least 90% mark it **Mastered**.
15. A practice-day rhythm updates only on meaningful lesson completion. It, completion sounds, and animated celebrations can each be disabled in Settings; macOS Reduce Motion also suppresses energetic celebration motion.
16. Open **Settings** to change the learning profile, replay onboarding, configure game-feel preferences, or choose the full-key colors used for expected and pressed/preview notes.
17. Open **MIDI Lab** to select a device, inspect normalized events, or recover from a stuck note with **Panic**. Once connected, the lab shows a clean, read-only five-octave keyboard that mirrors incoming note presses without lesson markings or computer-key labels.

The sampler first looks for a bundled `Piano.sf2`. Until a licensed SoundFont is added, it uses the system General MIDI bank when available. Do not commit a third-party SoundFont without confirming redistribution rights.

## Lesson narration

Lesson narration is generated ahead of release with the free, local [Kyutai Pocket TTS](https://github.com/kyutai-labs/pocket-tts) model and bundled as its native 24 kHz mono WAV audio. The shipped app makes no TTS network call and contains no service credential or Python runtime. Each lesson exposes one canonical, speech-friendly `narrationScript` and SHA-256 content hash. `manifest.json` records that hash alongside the generated file, voice, voice license, model configuration, and generation date. The app plays a recording only when its hash matches the current script; otherwise it reports and uses the system-voice fallback.

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

## Hanon Technique Course

The Hanon course contains 20 self-contained Part I lessons. Each lesson presents the complete public-domain pitch route in a scrollable engraved 2/4 grand staff with sixteenth-note beams, barlines, repeat signs, written ending values, and explicit left- and right-hand finger numbers on every note. The verified catalog retains the written pitches. At practice-session time, Board Sensei raises the complete exercise by one octave when it still fits the C2–C7 piano, placing the left hand in the second visible octave; high-reaching exercises remain in their written register so every target stays playable. That one contextual route drives the score, keyboard highlights, note names, preview, fingering, and validation together. Exercise preview follows the written values at quarter-note BPM, performs the repeated body twice, and then plays the written ending. No external score is required. The note routes were checked against the Mutopia Project's machine-readable Part I engraving, while render QA compares pitch contours, staff crossings, fingering, repeats, and endings with the supplied Schirmer pages; those page scans and editorial text are not bundled or reproduced. Parts II and III remain unavailable until their notes and fingerings can receive the same verification.

## Architecture

```text
CoreMIDI callback
    -> bounded AsyncStream of normalized events
    -> AppModel
       -> AVAudioUnitSampler
       -> typed CourseLessonContext
          -> fresh PracticeSession
             -> Jazz key transposition + prompt staff + melodic/exact-chord policy
             -> Hanon full score + hand/range/fresh-pair policy
       -> C bridge validator
          -> Rust music-core when its dylib is present
          -> deterministic native fallback otherwise
       -> shared SwiftUI transport, feedback, and piano
```

- `Sources/MusicCore` contains platform-independent Swift contracts, the typed course library and practice sessions, the canonical song timeline, MIDI parsing, and test fixtures.
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
- Course-namespaced progress with automatic migration from the earlier unscoped Jazz/Hanon keys
- Interactive first-run onboarding with goal, experience, optional MIDI setup, and a playable first feedback moment
- Persistent Introduced/Practised/Mastered lesson records, accuracy personal bests, completion results, milestones, and meaningful practice-day rhythm
- Non-modal pass results with manual repeat, next-lesson control, and beat-one-aligned scored practice looping
- A side-profile grand-piano-and-player mark used for the app icon, onboarding identity, and navigation lockup
- Restrained, Reduce-Motion-aware completion animation and an optional dedicated high-register chime sequence
- Centered studio-home dashboard with learning-status chips and a horizontally scrollable course shelf, including a Classical-course placeholder
- Collapsible Jazz chapters with saved completion ticks
- Lesson-aware treble, bass, or grand-staff notation
- Simultaneous chord prompts with full-voicing staff and keyboard highlighting
- Isolated Jazz and Hanon practice presentations, controls, preview timelines, and validation policies inside one shared workspace
- Persistent 12-key Jazz transposition across notation, piano targets, route, preview playback, and validation, isolated from Hanon's independently fitted C2–C7 practice register
- Rust/native prompt validation modes for single notes, exact Jazz chords, and 120 ms fresh Hanon hand pairs
- Full-key expected and pressed/preview indicators with persistent user-selected colors and automatic label contrast
- A dedicated Settings page shared with the native macOS Settings window, ready for additional preferences
- A unified lesson/practice workspace with a resizable, scrollable guide containing full lesson theory, narration, preview, instructions, and route
- Content-addressed studio narration with incremental generation and a safe system-voice fallback
- One exercise-playback button with an adjacent cycle-mode toggle for continuous, bar-aligned practice loops, persisted tempo, and synchronized staff/piano highlighting
- Stop-only Space shortcut for active demonstration or loop playback
- Silently armed metronome with independent volume, accented downbeats, common time signatures, and clicks restricted to exercise playback or explicit scored practice looping
- Persistent practice-instrument menu with multiple grand pianos, electric pianos, synth leads, and synth pads from compatible SF2/DLS banks
- In-class Previous/Next navigation and a current-chapter lesson picker with completion status
- A consistent studio-blue accent throughout the app, paired with a neutral graphite Practice workspace, Logic-inspired panel shading, thin section separators, compact control surfaces, and contextual Quick Help
- Swift and Rust canonical music-model foundations
- Runtime Rust bridge with a no-toolchain fallback

Next milestones:

1. Bundle a licensed piano SoundFont and add audio-device selection.
2. Migrate the current local profile and mastery records from UserDefaults to SwiftData when multi-profile support is introduced.
3. Add deterministic lesson generation and richer timing/accuracy scoring in Rust.
4. Import Standard MIDI Files into the canonical tick-based timeline.
5. Add count-in, loop-range selection, and 50/75/100% practice tempo presets.
6. Add MusicXML, then editable audio beat/chord analysis.

## Design and engineering references

The implementation follows primary platform guidance:

- [CoreMIDI receive callbacks](https://developer.apple.com/documentation/coremidi/midireceiveblock) run on a high-priority thread, so the callback performs bounded parsing and enqueueing only.
- [AVAudioUnitSampler](https://developer.apple.com/documentation/avfaudio/avaudiounitsampler) supports DLS and SF2 instruments.
- [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility) requires alternatives to color-only feedback and appropriate Reduce Motion behavior.
- [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/) informs resizable layouts, keyboard access, and information density.
- [Swift Testing](https://developer.apple.com/documentation/testing) is used for unit tests and works directly with Swift Package Manager.
- [The Rustonomicon FFI guidance](https://doc.rust-lang.org/nomicon/ffi.html) informs the fixed-width C ABI, opaque engine ownership, and no-unwind boundary.
