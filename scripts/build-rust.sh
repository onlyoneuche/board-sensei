#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
cargo build --manifest-path "$repo_root/rust/Cargo.toml" --release

library="$repo_root/rust/target/release/libboard_sensei_music.dylib"
if [[ ! -f "$library" ]]; then
    print -u2 "Expected Rust library was not produced: $library"
    exit 1
fi

print "Built $library"
