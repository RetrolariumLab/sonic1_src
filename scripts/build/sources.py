"""Tracked assembler selection and input fingerprints shared by builders and audits."""

from pathlib import Path
import subprocess
from scripts.build.project import ROOT, load, file_sha256

PIPELINE = (
    "scripts/run.py",
    "scripts/build/build_rom.py",
    "scripts/build/project.py",
    "scripts/build/sources.py",
    "scripts/build/toolchain.py",
    "scripts/build/split_assets.py",
    "config/revision_profiles.json",
    "config/lint.json",
    "config/toolchain.json",
    "assets/manifest.json",
    "config/build/derived_assets.json",
)


def source_paths() -> list[Path]:
    roots = load("config/lint.json")["assembly"]["paths"]
    tracked = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "-z"])
    return [
        Path(name)
        for raw in tracked.split(b"\0")
        if raw
        for name in [raw.decode()]
        if Path(name).suffix in (".asm", ".s", ".inc")
        and any(name == owner or name.startswith(owner.rstrip("/") + "/") for owner in roots)
    ]


def fingerprint(source_root: Path = ROOT) -> dict:
    paths = source_paths()
    if not paths:
        raise ValueError("No tracked preservation sources selected")
    return dict(
        schema_version=1,
        sources={path.as_posix(): file_sha256(source_root / path) for path in paths},
        pipeline={name: file_sha256(ROOT / name) for name in PIPELINE},
    )
