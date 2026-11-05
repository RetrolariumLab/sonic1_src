"""Hash-pinned Core CLI operations with private scratch confined to build."""

from __future__ import annotations
import os
from pathlib import Path
import subprocess
import tempfile
import contextlib
import shutil
import time
from scripts.build.project import ROOT, checked_path, file_sha256, load


def resolve(named: Path | None = None) -> Path:
    spec = load("config/authoring/toolchain.json")["core_cli"]
    path = Path(named or os.environ.get(spec["environment"]) or checked_path(spec["default_path"])).resolve()
    if not path.is_file() or file_sha256(path) not in {spec["sha256"], spec["legacy_sha256"]}:
        raise ValueError("Core CLI SHA-256 differs from the authoring toolchain")
    result = subprocess.run([str(path), "version"], capture_output=True, text=True, check=True, timeout=30)
    if result.stdout.strip() != spec["version"]:
        raise ValueError("Core CLI version differs from the authoring toolchain")
    return path


@contextlib.contextmanager
def scratch(directory: Path):
    base = Path(tempfile.mkdtemp(prefix="nemesis-", dir=directory))
    if not base.resolve().is_relative_to(directory.resolve()):
        raise ValueError("Core scratch escaped its build root")
    try:
        yield base
    finally:
        for attempt in range(10):
            try:
                shutil.rmtree(base)
                break
            except FileNotFoundError:
                break
            except OSError:
                if attempt == 9:
                    raise
                time.sleep(0.05 * (attempt + 1))


def operate(verb: str, plain: bytes, reference: bytes | None = None) -> bytes:
    if verb not in ("decompress", "compress") or (verb == "compress") != (reference is not None):
        raise ValueError("Invalid Nemesis codec operation")
    executable = resolve()
    directory = checked_path("build/tmp")
    directory.mkdir(parents=True, exist_ok=True)
    with scratch(directory) as folder:
        base = Path(folder)
        source = base / "input.bin"
        source.write_bytes(plain)
        output = base / "output.bin"
        args = [str(executable), "nemesis", verb, str(source)]
        if reference is not None:
            ref = base / "reference.nem"
            ref.write_bytes(reference)
            args.append(str(ref))
        result = subprocess.run([*args, str(output)], capture_output=True, text=True, timeout=120)
        if result.returncode:
            raise ValueError(f"Core Nemesis {verb} failed: {result.stderr.strip()[-1200:]}")
        expected = load("config/authoring/toolchain.json")["core_cli"]
        if file_sha256(executable) not in {expected["sha256"], expected["legacy_sha256"]}:
            raise ValueError("Core CLI changed during the codec operation")
        return output.read_bytes()


def decode(data: bytes) -> bytes:
    return operate("decompress", data)


def encode(data: bytes, reference: bytes) -> bytes:
    return operate("compress", data, reference)
