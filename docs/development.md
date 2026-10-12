# Development

Read [the agent guide](../agent.md) before changing, building, or testing the repository.

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

### Runtime crash trace

Debug builds emit an immediate `[BS-TRACE]` line at AppKit pointer delivery, button-action entry, piano input, narration transitions, audio-engine setup, and every exercise-preview scheduling phase. The trace deliberately does not run inside CoreMIDI receive or audio-render callbacks. Each line is written both to the terminal and to `/tmp/board-sensei-<PID>.log`, so the last successful boundary remains available after a hard crash.

Run normally; diagnostics are enabled by default for `swift run` debug builds:

```sh
swift run BoardSensei
```

The launch trace prints the exact log path. After reproducing a crash, copy the final 40–80 `[BS-TRACE]` lines from the terminal or that file. If the last line is `appkit-event` with no following `button-action`, SwiftUI failed before the application action ran. If `button-action` appears, the subsequent `preview`, `audio`, or `narration` entry identifies how far application code progressed. Set `BOARD_SENSEI_DIAGNOSTICS=0` to disable the debug trace; release builds require `BOARD_SENSEI_DIAGNOSTICS=1` to enable it.

See [architecture](architecture.md) for ownership boundaries and [lesson narration](narration.md) for asset generation.
