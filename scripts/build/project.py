"""Manifest ownership, checked paths and atomic output for preservation tools."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def load(path: str) -> dict:
    with (ROOT / path).open(encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict) or value.get("schema_version") != 1:
        raise ValueError(f"Unsupported manifest: {path}")
    return value


def sha1(data: bytes) -> str:
    return hashlib.sha1(data).hexdigest()


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def checked_path(relative: str, base: Path = ROOT) -> Path:
    if not isinstance(relative, str) or not relative or "\\" in relative or ":" in relative:
        raise ValueError(f"Invalid relative path: {relative!r}")
    path = (base / relative).resolve()
    if path == base.resolve() or not path.is_relative_to(base.resolve()):
        raise ValueError(f"Path escapes its owner: {relative}")
    return path


def atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(data)
    temporary.replace(path)


def profiles() -> list[dict]:
    return load("config/revision_profiles.json")["profiles"]


def profile(profile_id: str) -> dict:
    matches = [item for item in profiles() if item["id"] == profile_id]
    if len(matches) != 1:
        raise ValueError(f"Unknown or duplicated profile: {profile_id}")
    return matches[0]


def image(profile_id: str) -> dict:
    image_id = profile(profile_id)["image"]
    return next(item for item in load("assets/manifest.json")["images"] if item["id"] == image_id)


def read_rom(profile_id: str, directory: Path) -> tuple[Path, bytes]:
    spec = image(profile_id)
    path = directory / spec["file"]
    raw = path.read_bytes()
    if len(raw) != spec["size"] or sha1(raw) != spec["sha1"] or sha256(raw) != spec["sha256"]:
        raise ValueError(f"{path.name}: not the accepted {profile_id} input")
    return path, raw


def command(arguments: list[str], *, output: Path | None = None) -> None:
    environment = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    if output is None:
        subprocess.run(arguments, cwd=ROOT, env=environment, check=True)
    else:
        with output.open("ab") as stream:
            subprocess.run(arguments, cwd=ROOT, env=environment, check=True,
                           stdout=stream, stderr=subprocess.STDOUT)
