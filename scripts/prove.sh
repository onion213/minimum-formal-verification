#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/extract.sh
cd proofs/lean
lake build MinimumFormalVerification
# Explicitly check the proof and its axiom audit, even if a root import is removed.
lake build MinimumFormalVerification.Verification.Audit
lake env lean -DwarningAsError=true MinimumFormalVerification/Verification/Audit.lean
