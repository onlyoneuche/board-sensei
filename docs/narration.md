# Lesson narration

Lesson narration is generated ahead of release with the free, local [Kyutai Pocket TTS](https://github.com/kyutai-labs/pocket-tts) model and bundled as its native 24 kHz mono WAV audio. The shipped app makes no TTS network call and contains no service credential or Python runtime. Each lesson exposes one canonical, speech-friendly `narrationScript` and SHA-256 content hash. `manifest.json` records that hash alongside the generated file, voice, voice license, model configuration, and generation date. The app plays a recording only when its hash matches the current script; otherwise it reports and uses the system-voice fallback.

Generation requires [`uv`](https://docs.astral.sh/uv/getting-started/installation/). Pocket TTS supports Python 3.10 through 3.14, but `uvx` creates and manages that environment independently of the system Python. The first real generation downloads the model; subsequent runs reuse the local cache.

The complete 56-lesson catalog can take several minutes to synthesize on CPU. The generator displays lesson-level progress (`[current/total]`) and an elapsed-time heartbeat every ten seconds. Pocket TTS does not expose a trustworthy percentage within one lesson, so the heartbeat is intentionally time-based. Its own output remains visible, and the manifest is saved after every completed lesson, so an interrupted run can be resumed by running the same command again.

Each lesson is first written under macOS's per-user temporary directory, commonly `/var/folders/.../T`. This staging file prevents a failed or interrupted synthesis from leaving a corrupt course asset. After Pocket TTS succeeds, the generator atomically saves the WAV under `Sources/BoardSenseiApp/Resources/Narration`, updates the manifest, and deletes the temporary directory.

Preview which lessons are missing or stale:

```sh
swift run BoardSenseiNarrationTool --dry-run
```

Generate only missing or changed lessons with the default Alba voice:

```sh
swift run BoardSenseiNarrationTool
```

Generate or check one course without changing the other course's assets:

```sh
swift run BoardSenseiNarrationTool --course hanon-technique
swift run BoardSenseiNarrationTool --course hanon-technique --check
```

Generate or review one lesson while tuning pronunciation:

```sh
swift run BoardSenseiNarrationTool --lesson i-altered --force
```

Before release, require a complete matching asset set across every registered course:

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

Use only voices whose terms permit the intended app distribution. In particular, do not ship output derived from Pocket TTS voices marked noncommercial in the [official voice repository](https://huggingface.co/kyutai/tts-voices). The model is CC BY 4.0; Pocket TTS code is MIT licensed. Review generated speech for jazz terminology, note names, pacing, artifacts, and consistent loudness before committing an audio asset. See [ADR 001](decisions/001-topic-narration.md) for the full decision and invalidation design.
