"""Run Kit's AS house style through protected disposable source copies.

Kit's current AS file selector accepts .s/.inc. This adapter changes only the
scratch suffix for Z80 .asm inputs, leaves Kit/Core untouched, and uses their public CLI for every
format operation. Source formatting is copied back only for the explicit fix.
"""

from __future__ import annotations
import argparse
import json
import re
from pathlib import Path
import shutil
import subprocess
from scripts.build.project import ROOT, atomic_write, command, load
from scripts.build.sources import source_paths


def protect_fields(text: str) -> tuple[str, dict[str, str]]:
    """Preserve AS label fields that Kit otherwise mistakes for mnemonics.

    AS requires assignments, functions, structs and local labels in column zero.
    The projection gives these declarations a temporary explicit global label;
    only whitespace/comment formatting is copied back after exact restoration.
    """
    mapping = {}
    lines = []
    for line in text.splitlines():
        if line and not line[0].isspace() and not line.startswith(";"):
            match = re.match(r"(\S+)(.*)", line)
            head, tail = match.group(1), match.group(2)
            alias = f"StyleField{len(mapping):06d}"
            if alias in text:
                raise ValueError("Style projection label collides with source")
            mapping[alias + ":"] = head
            line = alias + ":" + tail
        lines.append(line)
    return "\n".join(lines) + "\n", mapping


def restore_fields(text: str, mapping: dict[str, str]) -> str:
    for alias, original in mapping.items():
        if text.count(alias) != 1:
            raise ValueError("Style projection changed a declaration")
        text = text.replace(alias, original)
    return text


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
        target = stage / "sources" / (relative.with_suffix(".s") if relative.suffix == ".asm" else relative)
        projected, mapping = protect_fields((ROOT / relative).read_text(encoding="utf-8"))
        atomic_write(target, projected.encode())
        pairs.append((ROOT / relative, target, mapping))
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
        for source, target, mapping in pairs:
            formatted = restore_fields(target.read_text(encoding="utf-8"), mapping).encode()
            if source.read_bytes() != formatted:
                atomic_write(source, formatted)


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
