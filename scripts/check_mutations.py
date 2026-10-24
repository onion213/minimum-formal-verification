#!/usr/bin/env python3
"""Show that changing Rust invalidates the proof, without editing the checkout."""

from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PROOFS = Path("proofs/lean")
PROOF = "MinimumFormalVerification/Verification/ProofObligations.lean"


def run(args: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=cwd, text=True, capture_output=True, timeout=300)


def require_success(result: subprocess.CompletedProcess[str]) -> None:
    if result.returncode:
        raise SystemExit(result.stdout + result.stderr)


def main() -> None:
    # Establish that the toolchain and the original proof really work first.
    require_success(run(["bash", "scripts/prove.sh"], ROOT))
    print("PASS: original implementation is proved", flush=True)
    original = (ROOT / "src/lib.rs").read_text()
    mutations = {
        "reject_equal_balance": ("amount <= balance", "amount < balance"),
        "add_instead_of_subtract": ("balance - amount", "balance + amount"),
    }
    with tempfile.TemporaryDirectory(prefix="formal-verification-") as tmp:
        for name, (before, after) in mutations.items():
            if original.count(before) != 1:
                raise SystemExit(f"Mutation location changed: {before}")
            case = Path(tmp) / name
            shutil.copytree(
                ROOT, case,
                ignore=shutil.ignore_patterns(".git", ".lake", "target", "__pycache__"),
            )
            # Reuse downloaded dependencies; each copy has its own build outputs.
            (case / PROOFS / ".lake").mkdir()
            (case / PROOFS / ".lake/packages").symlink_to(
                ROOT / PROOFS / ".lake/packages", target_is_directory=True,
            )
            (case / "src/lib.rs").write_text(original.replace(before, after))
            require_success(run(["bash", "scripts/extract.sh"], case))
            result = run([
                "lake", "build",
                "MinimumFormalVerification.Verification.ProofObligations",
            ], case / PROOFS)
            output = result.stdout + result.stderr
            # Network/installation errors do not count as proof rejections.
            if result.returncode == 0 or f"error: {PROOF}:" not in output:
                raise SystemExit(f"Unexpected result for {name}:\n{output}")
            print(f"PASS: Lean rejected {name}", flush=True)
            for line in output.splitlines():
                if line.startswith(f"error: {PROOF}:"):
                    print(f"  {line}", flush=True)
    print("PASS: both incorrect Rust implementations were rejected")


if __name__ == "__main__":
    main()
