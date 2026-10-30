"""Run the single fail-fast preservation gate without reusing old build outputs."""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
from scripts.build.project import ROOT, atomic_write

STEPS = (
    "lint",
    "test",
    "check-inputs",
    "clean",
    "split",
    "verify-all",
    "audit-symbolic",
    "verify-layout",
    "build-relocated-all",
    "runtime-check",
    "release-audit",
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom-dir", type=Path, required=True)
    args = parser.parse_args()
    directory = args.rom_dir.resolve()
    output = ROOT / "build/release"
    output.mkdir(parents=True, exist_ok=True)
    report_path = output / "preservation.json"
    report_path.unlink(missing_ok=True)
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    steps = []
    for step in STEPS:
        print(f"[GATE] {step}", flush=True)
        log = output / f"{step}.log"
        with log.open("wb") as stream:
            result = subprocess.run(
                ["make", step, f"ROM_DIR={directory}"], cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT
            )
        if result.returncode:
            print(log.read_text(errors="replace")[-6000:])
            parser.exit(result.returncode, f"error: preservation gate failed at {step}; read {log.relative_to(ROOT)}\n")
        steps.append(step)
    final = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    if final != head:
        parser.exit(1, "error: Git HEAD changed during the gate\n")
    report = dict(
        schema_version=1, passed=True, commit=head, steps=steps, checked_at=datetime.now(timezone.utc).isoformat()
    )
    atomic_write(report_path, (json.dumps(report, indent=2) + "\n").encode())
    print(f"[OK] Complete preservation gate: {head}")
    return 0
