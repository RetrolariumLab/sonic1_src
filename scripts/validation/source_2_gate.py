"""Execute the full preservation gate before every extra source/content check."""

import argparse
import json
import subprocess
from pathlib import Path
from scripts.build.project import ROOT, atomic_write
from scripts.validation.source_2 import STEPS


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom-dir", required=True, type=Path)
    args = parser.parse_args()
    output = ROOT / "build/release/source-2"
    output.mkdir(parents=True, exist_ok=True)
    report = output / "gate.json"
    report.unlink(missing_ok=True)
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    steps = []
    for step in STEPS:
        print(f"[GATE] {step}", flush=True)
        log = output / (step + ".log")
        with log.open("wb") as stream:
            result = subprocess.run(
                ["make", step, f"ROM_DIR={args.rom_dir.resolve()}"], cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT
            )
        if result.returncode:
            print(log.read_text(errors="replace")[-6000:])
            parser.exit(result.returncode, f"error:source/content gate failed at{step}\n")
        steps.append(step)
    if subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() != head:
        parser.exit(1, "error:HEAD changed during the source/content gate\n")
    atomic_write(
        report, (json.dumps(dict(schema_version=1, passed=True, commit=head, steps=steps), indent=2) + "\n").encode()
    )
    print(f"[OK] Complete source/content gate:{head}")
    return 0
