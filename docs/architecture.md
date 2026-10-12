# Architecture

```text
CoreMIDI callback
    -> bounded AsyncStream of normalized events
       -> AppModel on MainActor
          -> AudioService -> live AVAudioUnitSampler
          -> UI state and scoring
          -> C bridge validator
             -> Rust music-core when its dylib is present
             -> deterministic native fallback otherwise

typed CourseLessonContext
          -> fresh PracticeSession
             -> Jazz key transposition + prompt staff + melodic/exact-chord policy
             -> Hanon full score + hand/range/fresh-pair policy
          -> PracticePlaybackTimeline
             -> absolute audio-render sample times
                -> preview sampler MIDI scheduler
             -> pre-rendered click cycle -> metronome player node
             -> observed playhead -> synchronized staff and piano

shared SwiftUI workspace -> transport, feedback, and piano
```

- `Sources/MusicCore` contains platform-independent Swift contracts, the typed course library and practice sessions, the canonical song timeline, MIDI parsing, and test fixtures.
- `Sources/BoardSenseiApp` owns macOS UI and Apple framework integration.
- `Sources/BoardSenseiNarrationTool` is the release-time narration generator; it is not linked into the application.
- `Sources/BoardSenseiApp/Resources/Narration` contains the hash manifest and reviewed, distributable narration assets.
- `Sources/CBoardSenseiBridge` loads the Rust engine through a narrow C ABI without making Rust a prerequisite for contributors.
- `rust/music-core` currently provides deterministic prompt validation: single-note attacks, exact held Jazz chords, fresh paired Hanon attacks, mistakes, and completion state. It does not synthesize sound, own Core Audio, or schedule the current preview transport. MIDI-file import, richer scoring, canonical transport data, and later offline analysis belong there as the portable engine grows.
- `Tests/MusicCoreTests` verifies deterministic parsing and validation.
- [`agent.md`](../agent.md) is the detailed build and contribution guide for coding agents.

## Audio playback and instruments

Live playing and **Hear full exercise** use independent sampler instances, so demonstration note-offs and live note-offs cannot silence one another. The audio engine and all attached nodes remain within one main-actor-owned service for a stable lifecycle; no Apple audio object or captured scheduling block is passed through unchecked detached-task ownership.

Exercise note-on and note-off packets are translated from `PracticePlaybackTimeline` into the preview sampler's local render samples and queued through its `scheduleMIDIEventBlock`. MIDI, the PCM metronome cycle, and the observed staff/piano playhead are all derived from one future host-time origin.

Starting audio is synchronous with transport state publication, while the later task only observes the playhead; this prevents a cancelled Stop or Space action from being followed by deferred playback startup. Each preview generation also receives its own MIDI channel, which Stop silences and mutes so already-queued future packets cannot resume after the transport is cleared.

The samplers first look in `Sources/BoardSenseiApp/Resources/Instruments` for a bundled GM-compatible `BoardSensei.sf2`, then the legacy name `Piano.sf2`. Until a licensed, multi-sampled SoundFont is added, the app identifies and uses the macOS General MIDI bank. The mild EQ and room treatment improve that fallback's presentation, but cannot turn its small sample set into a Logic Pro instrument. Do not commit a third-party SoundFont or a Logic factory-library export without redistribution rights; keep the asset's license beside it and audition every exposed program.

## Design and engineering references

The implementation follows primary platform guidance:

- [CoreMIDI receive callbacks](https://developer.apple.com/documentation/coremidi/midireceiveblock) run on a high-priority thread, so the callback performs bounded parsing and enqueueing only.
- [AVAudioUnitSampler](https://developer.apple.com/documentation/avfaudio/avaudiounitsampler) supports DLS and SF2 instruments.
- [`scheduleMIDIEventBlock`](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/schedulemidieventblock) queues MIDI packets against an audio unit's render sample timeline independently of UI updates.
- [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility) requires alternatives to color-only feedback and appropriate Reduce Motion behavior.
- [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/) informs resizable layouts, keyboard access, and information density.
- [Swift Testing](https://developer.apple.com/documentation/testing) is used for unit tests and works directly with Swift Package Manager.
- [The Rustonomicon FFI guidance](https://doc.rust-lang.org/nomicon/ffi.html) informs the fixed-width C ABI, opaque engine ownership, and no-unwind boundary.
