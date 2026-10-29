"""Run Kit's AS house style over .asm sources through disposable .s copies.

Kit's current AS file selector accepts .s/.inc. This adapter changes only the
scratch suffix, leaves Kit/Core untouched, and uses their public CLI for every
format operation. Source formatting is copied back only for the explicit fix.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import shutil
import subprocess
from scripts.build.project import ROOT, atomic_write, command, load


def source_paths() -> list[Path]:
    roots = load("config/lint.json")["assembly"]["paths"]
    tracked = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "-z"])
    selected = []
    for raw in tracked.split(b"\0"):
        if not raw:
            continue
        name = raw.decode()
        path = Path(name)
        if path.suffix not in (".asm", ".s", ".inc"):
            continue
        if any(name == owner or name.startswith(owner.rstrip("/") + "/") for owner in roots):
            selected.append(path)
    return selected


def assembly(*, fix: bool) -> None:
    stage = ROOT / "build/lint-stage"
    if stage.is_symlink() or not stage.resolve().is_relative_to((ROOT / "build").resolve()):
        raise ValueError("Lint staging escaped build/")
    if stage.exists():
        shutil.rmtree(stage)
    sources = source_paths()
    if not sources:
        raise ValueError("No tracked assembler sources selected")
    pairs = []
    for relative in sources:
        target = stage / "sources" / relative.with_suffix(".s")
        atomic_write(target, (ROOT / relative).read_bytes())
        pairs.append((ROOT / relative, target))
    config = load("config/lint.json")
    config["assembly"]["paths"] = ["sources"]
    config.pop("text", None)
    config["code"] = False
    atomic_write(stage / "config/lint.json", (json.dumps(config, indent=2) + "\n").encode())
    arguments = ["rltool", "lint", "--project", str(stage), "--only", "assembly", "--limit", "30"]
    if fix:
        arguments.append("--fix")
    command(arguments)
    if fix:
        for source, target in pairs:
            if source.read_bytes() != target.read_bytes():
                atomic_write(source, target.read_bytes())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fix", action="store_true")
    args = parser.parse_args()
    try:
        assembly(fix=args.fix)
        if args.fix:
            command(["rltool", "format", "--project", str(ROOT)])
        arguments = ["rltool", "lint", "--project", str(ROOT), "--only", "text", "--only", "code", "--limit", "30"]
        if args.fix:
            arguments.append("--fix")
        command(arguments)
        if args.fix:
            assembly(fix=False)
            command(["rltool", "lint", "--project", str(ROOT), "--only", "text", "--only", "code", "--limit", "30"])
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"error: {error}\n")
    return 0
