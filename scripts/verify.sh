#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

cargo fmt --all -- --check
cargo clippy --locked --all-targets -- -D warnings
cargo test --locked
cargo test --locked --release
bash scripts/prove.sh

# Include new/deleted files as well as modifications. `git diff` alone misses
# untracked output. Only generator-owned paths and the lockfile are checked.
generated=(proofs/lean/MinimumFormalVerification/Extraction
           proofs/lean/MinimumFormalVerification/Extraction.lean
           proofs/lean/lake-manifest.json)
if [[ -n "$(git status --porcelain -- "${generated[@]}")" ]]; then
  echo 'Extraction or dependency lock changed. Review and commit these files:' >&2
  git status --short -- "${generated[@]}"
  git diff -- "${generated[@]}"
  exit 1
fi
echo 'Verified: Rust tests, fresh extraction, Lean proofs, axiom audit, and generated files.'
