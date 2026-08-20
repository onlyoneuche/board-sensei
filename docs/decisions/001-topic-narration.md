# ADR 001: Content-addressed Topic narration

- Status: Accepted
- Date: 2026-08-19

## Context

Topic pages contain fixed, authored educational material. The macOS system speech voice is useful as an accessibility fallback but does not meet the desired teaching quality. Calling a cloud TTS service from the application would add latency, recurring runtime cost, network dependency, privacy concerns, and an API-key distribution problem. Bundling a complete local neural TTS runtime would substantially increase application size and native integration complexity.

Lesson text will change over time. A recording that no longer matches its visible lesson is a correctness defect, not merely a stale cache entry. Musical terms also need a speech-specific representation: for example, visible “II–V–I” should be narrated as “two five one.”

## Decision

1. `PracticeLesson.narrationScript` is the canonical speech-friendly source. Topic UI sections and narration derive from the same platform-neutral lesson data.
2. `PracticeLesson.narrationContentHash` is the lowercase SHA-256 digest of the exact UTF-8 narration script.
3. Studio narration is generated outside the app with ElevenLabs and committed as `mp3_44100_128` assets. The default model is `eleven_v3`; voice selection is an editorial decision and is supplied by ID at generation time.
4. `Resources/Narration/manifest.json` maps a stable lesson ID to its content hash, content-addressed filename, voice ID, model ID, and generation date.
5. The app plays a bundled recording only when the manifest schema is supported, the lesson ID exists, the hash matches, and the referenced file exists. Otherwise it labels and uses `AVSpeechSynthesizer` as the fallback.
6. `BoardSenseiNarrationTool` compares hashes and generates only missing or changed lessons. `--dry-run` previews work, `--lesson` scopes editorial iteration, and `--check` is the release gate.
7. Credentials exist only in the generator process environment. They are never accepted as command arguments, stored in the manifest, bundled, logged, or committed.
8. Narration controls exist only on Topic pages. Playback stops before entering Practice or when the Topic page disappears.

The HTTP integration follows ElevenLabs’ official [Create speech API](https://elevenlabs.io/docs/api-reference/text-to-speech/convert/) and uses its documented general-playback MP3 format. Generated audio must be covered by the project’s applicable ElevenLabs plan and voice rights before distribution.

## Content-change workflow

1. Edit lesson content or speech normalization.
2. Run `swift run BoardSenseiNarrationTool --dry-run` to see invalidated lessons.
3. Generate the changed lesson and listen to the complete file.
4. Correct pronunciation through the canonical narration script or an approved pronunciation dictionary; do not patch spoken wording only in the generated file.
5. Commit the new content-addressed MP3 and manifest together.
6. Run `swift run BoardSenseiNarrationTool --check` before release.

Old manifest entries can never play against new text because their hashes differ. Old unreferenced audio files may be removed during normal repository maintenance after the replacement has been reviewed.

## Consequences

Benefits:

- Studio-quality, instant, offline playback with deterministic wording.
- No production API secret, runtime service dependency, or per-listen charge.
- Incremental regeneration and an explicit release-time freshness check.
- A functional accessibility fallback during development and partial asset rollout.

Costs:

- Audio increases release size and requires editorial review.
- Content changes that affect narration require a newly generated asset.
- A voice or model migration invalidates editorial consistency even when text hashes remain unchanged; use `--force` to regenerate the catalog and review it as a deliberate release change.

## Alternatives considered

- Live Apple speech: minimal integration but insufficient voice quality; retained only as fallback.
- Runtime ElevenLabs calls: high quality but rejected because a desktop client cannot safely hold the service credential.
- Bundled Pocket TTS: promising local quality but its official Python/PyTorch runtime is too heavy for the current native Swift distribution.
- Kokoro through sherpa-onnx: viable future local runtime with a native Swift path, but less expressive than editorially generated studio assets for fixed course content.
