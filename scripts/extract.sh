#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(cargo hax --version | sed -n 's/^version=//p')" != "0.4.2" ]]; then
  echo 'Install the pinned tool: cargo install --locked cargo-hax --version 0.4.2' >&2
  exit 1
fi

# No handwritten copy of the Rust implementation is used by the proof.
cargo hax -C --locked --lib ';' into lean
