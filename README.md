# Board Sensei

A native macOS piano-practice app with Jazz and Hanon courses, interactive notation, MIDI feedback, and offline lesson narration. Practise with a MIDI keyboard or the on-screen piano.

## Quick start

Requires macOS 14+, Xcode 16+ with Command Line Tools selected, and Swift 6+.

From the repository root:

```sh
swift run BoardSensei
```

Quit with **Command-Q** to return to the terminal. Rust is optional; the app includes a native validation fallback.

Run the available checks:

```sh
./scripts/verify.sh
```

## Documentation

- [User guide](docs/usage.md)
- [Development and Rust setup](docs/development.md)
- [All documentation](docs/README.md) — courses, architecture, narration, and roadmap.
- [Agent contribution guide](agent.md)
