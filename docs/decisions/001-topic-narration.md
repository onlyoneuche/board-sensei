# ADR 001: Content-addressed Topic narration

- Status: Accepted
- Date: 2026-08-19

## Context

Topic pages contain fixed, authored educational material. The macOS system speech voice is useful as an accessibility fallback but does not meet the desired teaching quality. Calling a cloud TTS service from the application would add latency, recurring runtime cost, network dependency, privacy concerns, and an API-key distribution problem. Bundling a complete local neural TTS runtime would substantially increase application size and native integration complexity.

Lesson text will change over time. A recording that no longer matches its visible lesson is a correctness defect, not merely a stale cache entry. Musical terms also need a speech-specific representation: for example, visible “II–V–I” should be narrated as “two five one.”

## Decision

1. `PracticeLesson.narrationScript` is the canonical speech-friendly source. Topic UI sections and narration derive from the same platform-neutral lesson data.
2. `PracticeLesson.narrationContentHash` is the lowercase SHA-256 digest of the exact UTF-8 narration script.
3. Studio narration is generated outside the app with the free, local Kyutai Pocket TTS model and its native 24 kHz mono PCM/WAV output is committed as an application resource. Pocket TTS is a content-production dependency, not an application runtime dependency.
4. `Resources/Narration/manifest.json` maps a stable lesson ID to its content hash, content-addressed filename, voice ID, voice license, model configuration, and generation date.
5. The app plays a bundled recording only when the manifest schema is supported, the lesson ID exists, the hash matches, and the referenced file exists. Otherwise it labels and uses `AVSpeechSynthesizer` as the fallback.
6. `BoardSenseiNarrationTool` compares hashes and generates only missing or changed lessons. It exposes lesson counts, Pocket TTS output, and an elapsed-time heartbeat because Pocket TTS does not report a reliable per-lesson percentage. It stages each recording in macOS's per-user temporary directory, atomically saves the completed asset, and checkpoints the manifest after each lesson so a long catalog run can resume safely. `--dry-run` previews work, `--lesson` scopes editorial iteration, and `--check` is the release gate; an asset without voice, model, or license metadata is treated as stale.
7. Generation requires no account, API key, or paid service. A custom voice must be accompanied by an explicit license identifier so distribution rights remain reviewable.
8. Narration controls exist only on Topic pages. Playback stops before entering Practice or when the Topic page disappears.

The generator follows Pocket TTS's official [CLI](https://kyutai-labs.github.io/pocket-tts/CLI%20Commands/generate/) through `uvx`. The code is MIT licensed and the model is CC BY 4.0. Voice licenses vary: the default Alba voice is CC BY 4.0, while the official voice repository also contains both permissive and noncommercial sources. Noncommercial voices must not be used for a distributable commercial build.

## Content-change workflow

1. Edit lesson content or speech normalization.
2. Run `swift run BoardSenseiNarrationTool --dry-run` to see invalidated lessons.
3. Generate the changed lesson and listen to the complete file.
4. Correct pronunciation through the canonical narration script or an approved pronunciation dictionary; do not patch spoken wording only in the generated file.
5. Commit the new content-addressed WAV and manifest together, including any required attribution.
6. Run `swift run BoardSenseiNarrationTool --check` before release.

Old manifest entries can never play against new text because their hashes differ. Old unreferenced audio files may be removed during normal repository maintenance after the replacement has been reviewed.

## Consequences

Benefits:

- Studio-quality, instant, offline playback with deterministic wording.
- No production API secret, paid generation service, runtime TTS dependency, or per-listen charge.
- Incremental regeneration and an explicit release-time freshness check.
- A functional accessibility fallback during development and partial asset rollout.

Costs:

- Uncompressed WAV audio increases release size, the first generation downloads model data, and each result requires editorial review. A future release compressor must be optional until its output has been verified on every supported build environment.
- Content changes that affect narration require a newly generated asset.
- A voice or model migration invalidates editorial consistency even when text hashes remain unchanged; use `--force` to regenerate the catalog and review it as a deliberate release change.

## Alternatives considered

- Live Apple speech: minimal integration but insufficient voice quality; retained only as fallback.
- Hosted commercial TTS generation: can offer polished voices but rejected because it introduces recurring cost and account dependency.
- Runtime cloud TTS calls: rejected because a desktop client cannot safely hold a service credential and playback would depend on the network.
- Bundled Pocket TTS runtime: rejected because its official Python/PyTorch runtime is too heavy for the current native Swift distribution. It is used only as an offline authoring tool.
- Kokoro through sherpa-onnx: viable future local runtime with a native Swift path, but less expressive than editorially generated studio assets for fixed course content.
