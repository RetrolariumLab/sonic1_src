"""Extract direct ROM ranges through Kit, then decode the private DAC container."""
from pathlib import Path
from scripts.authoring.kosinski import decode
from scripts.build.project import ROOT, atomic_write, checked_path, command, load, read_rom, sha1


def split(profile_ids: list[str], rom_directory: Path) -> None:
    arguments = ["rltool", "assets", "split"]
    for profile_id in profile_ids:
        path, _ = read_rom(profile_id, rom_directory)
        arguments += ["--image", profile_id, "--rom", f"{profile_id}={path.resolve()}"]
    command(arguments)
    spec = load("config/build/derived_assets.json")
    for container in spec["containers"]:
        if container["image"] not in profile_ids:
            continue
        source = checked_path("data/" + container["path"]).read_bytes()
        decoded = decode(source, max_output=container["decoded_size"])
        if decoded.consumed != len(source) or len(decoded.data) != container["decoded_size"]:
            raise ValueError("DAC container size differs from its pinned profile")
        if sha1(decoded.data) != container["decoded_sha1"]:
            raise ValueError("DAC container decoded hash differs")
        for item in spec["assets"]:
            if item["image"] != container["image"]:
                continue
            start, size = item["offset"], item["size"]
            if start < 0 or size <= 0 or start + size > len(decoded.data):
                raise ValueError(f"Derived range exceeds DAC container: {item['path']}")
            raw = decoded.data[start:start + size]
            if sha1(raw) != item["sha1"]:
                raise ValueError(f"Derived sample hash differs: {item['path']}")
            atomic_write(checked_path("data/" + item["path"]), raw)
    check(profile_ids)


def check(profile_ids: list[str]) -> None:
    arguments = ["rltool", "assets", "check"]
    for profile_id in profile_ids:
        arguments += ["--image", profile_id]
    command(arguments)
    direct = load("assets/manifest.json")["assets"]
    derived = load("config/build/derived_assets.json")["assets"]
    for item in direct + derived:
        if item["image"] not in profile_ids:
            continue
        raw = checked_path("data/" + item["path"]).read_bytes()
        if len(raw) != item["size"] or sha1(raw) != item["sha1"]:
            raise ValueError(f"Extracted asset differs: {item['path']}")
    print(f"[OK] Exact asset hashes: {', '.join(profile_ids)}")
