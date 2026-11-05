"""Assemble one preservation profile and flatten its authentic DAC compression."""

from pathlib import Path
import json
import subprocess
import os
from scripts.build import toolchain
from scripts.build.sources import fingerprint
from scripts.build.project import (
    ROOT,
    atomic_write,
    checked_path,
    command,
    image,
    load,
    profile,
    read_rom,
    sha1,
    sha256,
)
from scripts.build.split_assets import check


def fix_header(raw: bytes) -> bytes:
    if len(raw) < 0x200 or len(raw) % 2:
        raise ValueError("Mega Drive image must have a header and an even byte size")
    result = bytearray(raw)
    result[0x1A4:0x1A8] = (len(result) - 1).to_bytes(4, "big")
    checksum = sum(int.from_bytes(result[i : i + 2], "big") for i in range(0x200, len(result), 2)) & 0xFFFF
    result[0x18E:0x190] = checksum.to_bytes(2, "big")
    return bytes(result)


def build(
    profile_id: str,
    *,
    source_root: Path = ROOT,
    asset_root: Path | None = None,
    output_root: Path | None = None,
    edited_assets: dict[str, bytes] | None = None,
) -> Path:
    selected = profile(profile_id)
    inputs = fingerprint(source_root)
    check([profile_id])
    asset_root = asset_root or ROOT / "data"
    owners = [
        row
        for manifest in ("assets/manifest.json", "config/build/derived_assets.json")
        for row in load(manifest)["assets"]
        if row["image"] == profile_id
    ]
    if edited_assets is not None:
        if (
            not edited_assets
            or not output_root
            or not output_root.resolve().is_relative_to((ROOT / "build/authoring").resolve())
        ):
            raise ValueError("Edited assets require a separate private authoring output")
        allowed = {row["path"] for row in owners}
        if set(edited_assets) - allowed:
            raise ValueError("Edited asset belongs to another profile or storage owner")
        for name, payload in edited_assets.items():
            if not isinstance(payload, bytes) or len(payload) != len(checked_path(name, ROOT / "data").read_bytes()):
                raise ValueError("Edited asset changes its immutable storage footprint")
    asset_hashes = {row["path"]: sha256(checked_path(row["path"], asset_root).read_bytes()) for row in owners}
    for row in owners:
        expected = checked_path(row["path"], ROOT / "data").read_bytes()
        if edited_assets is not None and row["path"] in edited_assets:
            expected = edited_assets[row["path"]]
        if checked_path(row["path"], asset_root).read_bytes() != expected:
            raise ValueError("Preservation export differs from its extracted input")
    tools = toolchain.resolve()
    output = output_root or ROOT / "build/artifacts" / profile_id
    if not output.resolve().is_relative_to((ROOT / "build").resolve()):
        raise ValueError("Build output must stay under build/")
    output.mkdir(parents=True, exist_ok=True)
    entry = output / "entry.asm"
    defines = "".join(f"{key} = {value}\n" for key, value in selected["defines"].items())
    # The generated selector contains no engine copy and is never tracked.
    source = checked_path(load("config/revision_profiles.json")["entrypoint"], source_root)
    entry_text = defines + f'\tinclude "{source.relative_to(source_root).as_posix()}"\n'
    atomic_write(entry, entry_text.encode())
    obj = entry.with_suffix(".p")
    obj.unlink(missing_ok=True)
    target = output / "sonic1.bin"
    target.unlink(missing_ok=True)
    log = output / "build.log"
    atomic_write(log, b"")
    try:
        command(
            [
                str(tools["asl"]),
                "-xx",
                "-n",
                "-q",
                "-A",
                "-L",
                "-U",
                "-E",
                "-i",
                ".",
                "-i",
                Path(os.path.relpath(asset_root / profile_id, source_root)).as_posix(),
                entry.relative_to(source_root).as_posix(),
            ],
            output=log,
            cwd=source_root,
        )
    except subprocess.CalledProcessError as error:
        raise ValueError(f"AS failed; read {entry.with_suffix('.log').relative_to(ROOT)}") from error
    if not obj.is_file():
        raise ValueError(f"AS produced no object; read {log.relative_to(ROOT)}")
    command(
        [str(tools["p2bin"]), "-p=FF", "-z=0,kosinski,Size_of_DAC_driver_guess,after", str(obj), str(target)],
        output=log,
    )
    atomic_write(target, fix_header(target.read_bytes()))
    if {row["path"]: sha256(checked_path(row["path"], asset_root).read_bytes()) for row in owners} != asset_hashes:
        raise ValueError("Private assets changed during assembly")
    if fingerprint(source_root) != inputs:
        raise ValueError("Preservation inputs changed during assembly")
    receipt = dict(inputs)
    if edited_assets is not None:
        receipt["edited_assets"] = {name: sha256(payload) for name, payload in edited_assets.items()}
    atomic_write(output / "inputs.json", (json.dumps(receipt, indent=2) + "\n").encode())
    print(f"[OK] Built {profile_id}: {target.relative_to(ROOT)}")
    return target


def compare(raw: bytes, expected: bytes) -> None:
    if len(raw) != len(expected):
        raise ValueError(f"Image size differs: {len(raw)} rather than {len(expected)}")
    for index, (actual, original) in enumerate(zip(raw, expected)):
        if actual != original:
            raise ValueError(f"First byte difference at 0x{index:X}: {actual:02X} rather than {original:02X}")


def verify(profile_id: str, directory: Path) -> None:
    _, expected = read_rom(profile_id, directory)
    target = build(profile_id)
    raw = target.read_bytes()
    compare(raw, expected)
    spec = image(profile_id)
    if sha1(raw) != spec["sha1"] or sha256(raw) != spec["sha256"]:
        raise ValueError("Built image hash differs")
    report = dict(profile=profile_id, byte_identical=True, size=len(raw), sha1=sha1(raw), sha256=sha256(raw))
    atomic_write(target.parent / "identity.json", (json.dumps(report, indent=2) + "\n").encode())
    print(f"[OK] {profile_id}: byte-for-byte identity, SHA-256 {report['sha256']}")
