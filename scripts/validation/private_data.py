"""Reject private payloads and unapproved binary files across reachable history."""
from __future__ import annotations
import argparse
from pathlib import Path
import subprocess
from scripts.build.project import ROOT, load, sha1, sha256

BINARY_SUFFIXES = {".bin", ".gen", ".smd", ".mdf", ".wav", ".pcm", ".dpcm", ".nem", ".eni", ".kos", ".unc", ".pcx", ".png", ".jpg", ".zip", ".exe"}
PRIVATE_PREFIXES = ("data/", "assets/generated/", "content/workspace/", "build/")


def check_payload(path: str, raw: bytes, asset_hashes: set[str], allowlist: dict[str, str]) -> None:
    if path.startswith(PRIVATE_PREFIXES):
        raise ValueError(f"Private or generated path is tracked: {path}")
    if sha1(raw) in asset_hashes:
        raise ValueError(f"Tracked file matches a private manifest asset: {path}")
    try:
        raw.decode("utf-8-sig")
        binary = b"\x00" in raw
    except UnicodeDecodeError:
        binary = True
    binary = binary or Path(path).suffix.lower() in BINARY_SUFFIXES
    if binary and allowlist.get(path) != sha256(raw):
        raise ValueError(f"Binary file is not explicitly hash-allowlisted: {path}")


def audit_history(root: Path, asset_hashes: set[str], allowlist: dict[str, str]) -> int:
    reachable = subprocess.check_output(["git", "-C", str(root), "rev-list", "--objects", "--all"], text=True)
    entries = {}
    for line in reachable.splitlines():
        oid, _, path = line.partition(" ")
        if path:
            entries.setdefault(oid, set()).add(path)
    staged = subprocess.check_output(["git", "-C", str(root), "ls-files", "--stage", "-z"])
    for record in staged.split(b"\0"):
        if record:
            metadata, path = record.split(b"\t", 1)
            oid = metadata.split()[1].decode()
            entries.setdefault(oid, set()).add(path.decode())
    data = subprocess.check_output(["git", "-C", str(root), "cat-file", "--batch"], input="".join(key + "\n" for key in entries).encode())
    position = count = 0
    for oid, paths in entries.items():
        end = data.index(b"\n", position)
        header = data[position:end].split()
        size = int(header[2]); position = end + 1
        raw = data[position:position + size]; position += size + 1
        if header[1] != b"blob":
            continue
        for path in paths:
            check_payload(path, raw, asset_hashes, allowlist)
        count += 1
    return count


def main() -> int:
    argparse.ArgumentParser(description=__doc__).parse_args()
    direct = load("assets/manifest.json")
    derived = load("config/build/derived_assets.json")
    hashes = {item["sha1"] for item in direct["assets"] + direct["images"] + derived["assets"]}
    hashes |= {item["decoded_sha1"] for item in derived["containers"]}
    allowed = {item["path"]: item["sha256"] for item in load("config/reconstruction/binary_allowlist.json")["files"]}
    try:
        count = audit_history(ROOT, hashes, allowed)
    except ValueError as error:
        raise SystemExit(f"error: {error}") from error
    print(f"[OK] No private payloads or unapproved binaries in {count} reachable/staged blobs")
    return 0
