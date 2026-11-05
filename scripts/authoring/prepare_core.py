"""Build the pinned native Core from a verified public Git snapshot."""

import argparse
import io
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import tarfile

from scripts.authoring import core_codec
from scripts.build.project import ROOT, atomic_write, checked_path, command, file_sha256, load, sha256


def source_files(payload: bytes) -> dict[str, bytes]:
    files = {}
    with tarfile.open(fileobj=io.BytesIO(payload), mode="r:") as archive:
        for member in archive:
            name = member.name
            checked_path(name, ROOT / "build/dependencies/core-source")
            if ".." in PurePosixPath(name).parts or PurePosixPath(name).as_posix() != name:
                raise ValueError("Core snapshot contains a noncanonical path")
            if not (member.isfile() or member.isdir()) or name in files:
                raise ValueError("Core snapshot contains an unsupported link or duplicate path")
            if member.isfile():
                files[name] = archive.extractfile(member).read()
    if "CMakeLists.txt" not in files:
        raise ValueError("Core snapshot has no build entry point")
    return files


def stage_snapshot(files: dict[str, bytes], destination: Path) -> None:
    if destination.is_symlink() or not destination.resolve().is_relative_to((ROOT / "build").resolve()):
        raise ValueError("Core source snapshot must stay inside build/")
    existing = {path.relative_to(destination).as_posix() for path in destination.rglob("*") if path.is_file()}
    if existing - set(files):
        raise ValueError("Cached Core snapshot contains unexpected files")
    for name, data in files.items():
        path = checked_path(name, destination)
        if path.exists() and path.read_bytes() != data:
            raise ValueError("Cached Core snapshot differs from its pinned revision")
    for name, data in files.items():
        path = checked_path(name, destination)
        if not path.exists():
            atomic_write(path, data)


def prepare(source: Path | None = None) -> Path:
    value = source or os.environ.get("RETROLARIUM_CORE_SOURCE")
    if not value:
        raise ValueError("Set RETROLARIUM_CORE_SOURCE to a public Core checkout containing the pinned commit")
    source = Path(value).resolve()
    spec = load("config/authoring/toolchain.json")
    revision = spec["core_cli"]["source_commit"]
    actual = subprocess.check_output(["git", "rev-parse", revision + "^{commit}"], cwd=source, text=True).strip()
    if actual != revision:
        raise ValueError("Core checkout does not contain the exact dependency commit")
    payload = subprocess.check_output(["git", "archive", "--format=tar", revision], cwd=source)
    files = source_files(payload)
    snapshot = ROOT / "build/dependencies/core-source"
    stage_snapshot(files, snapshot)
    output = checked_path(spec["core_cli"]["default_path"]).parent.parent
    host = spec["host"]
    if os.name != "nt":
        raise ValueError("The pinned native authoring toolchain currently requires Windows")
    command(
        [
            "cmake",
            "-S",
            str(snapshot),
            "-B",
            str(output),
            "-G",
            host["generator"],
            "-A",
            "x64",
            "-T",
            host["toolset"],
            "-DCMAKE_SYSTEM_VERSION=" + host["windows_sdk"],
            "-DCMAKE_CXX_FLAGS_RELEASE=" + host["compiler_flags"] + f' "/pathmap:{ROOT}=sonic1"',
            "-DCMAKE_EXE_LINKER_FLAGS=" + host["linker_flags"],
            "-DCMAKE_STATIC_LINKER_FLAGS=" + host["linker_flags"],
            "-DCMAKE_EXE_LINKER_FLAGS_RELEASE=/INCREMENTAL:NO",
            "-DRETROLARIUM_CORE_BUILD_TESTS=OFF",
            "-DBUILD_TESTING=OFF",
            "-DRETROLARIUM_CORE_BUILD_CLI=ON",
        ]
    )
    command(["cmake", "--build", str(output), "--config", "Release", "--target", "rlcore", "--parallel", "1"])
    executable = core_codec.resolve(checked_path(spec["core_cli"]["default_path"]))
    report = dict(
        schema_version=1,
        source_commit=revision,
        source_archive_sha256=sha256(payload),
        executable=executable.relative_to(ROOT).as_posix(),
        executable_sha256=file_sha256(executable),
        configuration_sha256=file_sha256(ROOT / "config/authoring/toolchain.json"),
    )
    atomic_write(output / "binding.json", (json.dumps(report, indent=2) + "\n").encode())
    return executable


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("prepare", "check"))
    parser.add_argument("--source", type=Path)
    args = parser.parse_args()
    try:
        path = prepare(args.source) if args.action == "prepare" else core_codec.resolve()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(1, f"error: {error}\n")
    print(f"[OK] Pinned native Core: {path}")
    return 0
