#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
swift test --package-path "$repo_root"

if command -v cargo >/dev/null 2>&1; then
    cargo test --manifest-path "$repo_root/rust/Cargo.toml"
    cargo clippy --manifest-path "$repo_root/rust/Cargo.toml" --all-targets -- -D warnings
else
    print "Rust checks skipped: install rustup, then run this script again."
fi
