"""Require every tracked source and every emitted byte to have one semantic owner."""

import argparse
import json
from pathlib import Path
import subprocess
import re
from scripts.build.project import ROOT, atomic_write, load, profiles, image, sha256, checked_path
from scripts.build.listing import symbols
from scripts.build.source_listing import collect, exclusive, complete
from scripts.build.sources import source_paths, fingerprint


def origin_interval(origin: dict, length: int | None = None) -> tuple[int, int] | None:
    kind = origin.get("kind")
    lines = origin.get("lines")
    if kind == "generated_include_index":
        if lines != []:
            raise ValueError("Generated include index must not invent an original line interval")
        return None
    if (
        kind != "preserved_span"
        or not isinstance(lines, list)
        or len(lines) != 2
        or any(type(value) is not int for value in lines)
    ):
        raise ValueError("Source origin requires an explicit preserved span or generated include index")
    first, last = lines
    if not 1 <= first <= last or (length is not None and last > length):
        raise ValueError("Source origin line interval exceeds its preservation owner")
    return first, last


def generated_index(text: str, paths: set[str]) -> None:
    count = 0
    for line in text.splitlines():
        code = line.split(";", 1)[0].strip()
        if not code:
            continue
        include = re.fullmatch(r'include\s+"([^"\n]+)"', code, re.I)
        if not include or include[1] not in paths:
            raise ValueError("Generated source index must contain only registered child includes")
        count += 1
    if not count:
        raise ValueError("Generated source index has no child includes")


def structure() -> dict:
    spec = load("config/reconstruction/source_layout.json")
    rows = spec["modules"]
    paths = [row["path"] for row in rows]
    expected = {path.as_posix() for path in source_paths()}
    if len(paths) != len(set(paths)) or set(paths) != expected:
        raise ValueError("Source layout must own every tracked module exactly once")
    for row in rows:
        path = ROOT / row["path"]
        count = len(path.read_text().splitlines())
        if not all(row.get(key) for key in ("owner", "responsibility", "kind", "origin", "ranges")):
            raise ValueError("Source record lacks owner, responsibility, origin or ranges")
        if count > 900:
            raise ValueError(f"Oversized executable/source module requires a new cohesion review: {row['path']}")
        if (count > 700 or count < 25) and not all(
            row.get("size_exception", {}).get(key) for key in ("kind", "reason")
        ):
            raise ValueError(f"Unreviewed source size: {row['path']}")
        if set(row["ranges"]) != {item["id"] for item in profiles()}:
            raise ValueError("Source range profile matrix differs")
        if origin_interval(row["origin"]) is None:
            if row["kind"] != "include_index" or any(row["ranges"].values()):
                raise ValueError("Generated include index cannot own emitted source bytes")
            generated_index(path.read_text(), set(paths))
    registry = load("config/reconstruction/label_renames.json")
    if registry.get("renames") != []:
        raise ValueError(
            "This baseline preserves imported global names; register and audit any future rename explicitly"
        )
    for row in registry["project_additions"]:
        if not (ROOT / row["path"]).is_file() or row["name"] not in (ROOT / row["path"]).read_text():
            raise ValueError("Added boundary label is missing")
    return spec


def origins(base: str, spec: dict | None = None) -> None:
    spec = spec or structure()
    if spec.get("preservation_baseline_commit") != base:
        raise ValueError("Source layout is not bound to the accepted preservation predecessor")
    checked = {}
    for row in spec["modules"]:
        origin = row["origin"]
        name = origin["path"]
        checked_path(name, ROOT)
        if name not in checked:
            raw = subprocess.check_output(["git", "show", f"{base}:{name}"], cwd=ROOT)
            checked[name] = (sha256(raw), len(raw.decode("utf-8").splitlines()))
        digest, length = checked[name]
        origin_interval(origin, length)
        if digest != origin["preservation_source_sha256"]:
            raise ValueError("Source origin hash differs from the accepted preservation source")


def actual(profile: str, spec: dict | None = None) -> dict:
    spec = spec or structure()
    listing = ROOT / "build/artifacts" / profile / "entry.lst"
    if json.loads(listing.with_name("inputs.json").read_text()) != fingerprint():
        raise ValueError("Source listing is stale; rebuild the preservation profiles")
    if sha256(listing.with_name("sonic1.bin").read_bytes()) != image(profile)["sha256"]:
        raise ValueError("Source ownership requires a canonical preservation image")
    policy = load("config/reconstruction/address_policy.json")
    end_symbol = next(row["decoded_end_symbol"] for row in policy["fixed_regions"] if row["id"] == "dac_driver_ram")
    decoded = symbols(listing, {end_symbol})[end_symbol]
    expected = next(
        row["decoded_size"] for row in load("config/build/derived_assets.json")["containers"] if row["image"] == profile
    )
    if decoded != expected:
        raise ValueError("Decoded Z80 end differs from its checked extraction owner")
    owners = {row["owner"]: decoded for row in spec["transformed_storage"]}
    parsed = collect(listing, owners)
    ranges = {row["path"]: [] for row in spec["modules"]}
    frames = []
    for frame in parsed["frames"]:
        if frame.path not in ranges:
            continue
        ranges[frame.path].extend(exclusive(frame))
        frames.append(
            dict(path=frame.path, start=frame.start, end=frame.end, address_space=frame.space, storage=frame.storage)
        )
    for row in spec["modules"]:
        order = lambda item: (item["address_space"], item["start"], item["end"])
        if sorted(ranges[row["path"]], key=order) != sorted(row["ranges"][profile], key=order):
            raise ValueError(f"Source region moved without updating its owner: {profile}/{row['path']}")
    flat = [part for values in ranges.values() for part in values]
    complete([part for part in flat if part["address_space"] == "m68000_rom"], image(profile)["size"])
    complete([part for part in flat if part["address_space"] == "z80"], decoded)
    return dict(schema_version=1, profile=profile, ranges=ranges, includes=frames, events=parsed["events"])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--structure-only", action="store_true")
    args = parser.parse_args()
    try:
        spec = structure()
        reports = []
        if not args.structure_only:
            for selected in profiles():
                reports.append(actual(selected["id"], spec))
        report = dict(schema_version=1, modules=len(spec["modules"]), profiles=reports)
        atomic_write(ROOT / "build/audits/source-layout.json", (json.dumps(report, indent=2) + "\n").encode())
        print(f"[OK] Semantic source ownership:{len(spec['modules'])}modules,{len(reports)}profile range proofs")
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, f"error:{error}\n")
    return 0
