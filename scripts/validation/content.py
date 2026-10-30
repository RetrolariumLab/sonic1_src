"""Build preservation images again using only a newly encoded private export."""

import json
from pathlib import Path
import tempfile
from scripts.authoring.catalog import Catalog
from scripts.authoring.cli import roundtrip
from scripts.build import build_rom
from scripts.build.project import ROOT, atomic_write, profiles, image, sha256


def main() -> int:
    parent = ROOT / "build/authoring"
    parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="zero-edit-", dir=parent) as folder:
        base = Path(folder)
        report = roundtrip(Catalog(), base / "data")
        identities = []
        for item in profiles():
            identifier = item["id"]
            target = build_rom.build(identifier, asset_root=base / "data", output_root=base / "artifacts" / identifier)
            raw = target.read_bytes()
            if sha256(raw) != image(identifier)["sha256"]:
                raise ValueError("Zero-edit export rebuild differs from the accepted input")
            identities.append(dict(profile=identifier, size=len(raw), sha256=sha256(raw), byte_identical=True))
        report["rebuilt_profiles"] = identities
        atomic_write(parent / "zero-edit.json", (json.dumps(report, indent=2) + "\n").encode())
    print(f"[OK] Encoded content export rebuilt every preservation profile:{len(identities)}")
    return 0
