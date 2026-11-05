"""Prove real palette edits reach private ROMs and change only their owned bytes."""

import json
from pathlib import Path
import shutil
import tempfile

from scripts.authoring import content
from scripts.authoring.catalog import Catalog
from scripts.authoring.cli import inputs
from scripts.build.build_rom import build
from scripts.build.project import ROOT, atomic_write, checked_path, load, profiles, sha1, sha256

REPORT = "build/authoring/edited-containers.json"


def changed_ranges(before: bytes, after: bytes) -> list[dict]:
    if len(before) != len(after):
        raise ValueError("Edited image changes its fixed allocation")
    ranges = []
    start = None
    for index, (left, right) in enumerate(zip(before, after)):
        if left != right and start is None:
            start = index
        elif left == right and start is not None:
            ranges.append(dict(start=start, end=index))
            start = None
    if start is not None:
        ranges.append(dict(start=start, end=len(before)))
    return ranges


def expected_image(original: bytes, offset: int, before: bytes, after: bytes) -> bytes:
    if len(original) < 0x200 or len(original) & 1:
        raise ValueError("Cartridge checksum requires an even image with a complete header")
    if not before or len(before) != len(after) or before == after or offset < 0x200 or offset & 1:
        raise ValueError("Palette proof must change a bounded, aligned non-header allocation")
    if original[offset : offset + len(before)] != before:
        raise ValueError("Palette extraction does not match its original ROM allocation")
    output = bytearray(original)
    output[offset : offset + len(after)] = after
    # Independent cartridge-format arithmetic, separate from build_rom.fix_header.
    checksum = sum((output[index] << 8) | output[index + 1] for index in range(0x200, len(output), 2)) & 0xFFFF
    output[0x18E:0x190] = checksum.to_bytes(2, "big")
    return bytes(output)


def edit(catalog: Catalog, profile_id: str) -> dict:
    name = f"{profile_id}/palette/Sonic.bin"
    item = catalog.select(f"{profile_id}:{name}")
    if item["codec"] != "palette" or item["source"]["kind"] != "asset" or item.get("compression") is not None:
        raise ValueError("Palette probe must use its uncompressed manifest-owned resource")
    raw, context = catalog.read(item)
    document = content.decode(raw, item, context)
    document["model"][1]["red"] ^= 1
    encoded, proof = content.encode(document, raw, item, context, destination_profile=profile_id)
    if proof["unchanged"] or encoded == raw or len(encoded) != len(raw):
        raise ValueError("Palette proof made no bounded edit")
    reference = catalog.built(profile_id)["raw"]
    expected = expected_image(reference, context["offset"], raw, encoded)
    return dict(
        profile=profile_id,
        path=name,
        original=raw,
        encoded=encoded,
        reference=reference,
        expected=expected,
        offset=context["offset"],
    )


def check() -> dict:
    binding = inputs()
    catalog = Catalog()
    parent = ROOT / "build/authoring"
    parent.mkdir(parents=True, exist_ok=True)
    workspace = Path(tempfile.mkdtemp(prefix="palette-edit-", dir=parent))
    report = dict(
        schema_version=1, passed=False, inputs=binding, workspace=workspace.relative_to(ROOT).as_posix(), cases=[]
    )
    atomic_write(ROOT / REPORT, (json.dumps(report, indent=2) + "\n").encode())
    for selected in profiles():
        key = selected["id"]
        change = edit(catalog, key)
        shutil.copytree(ROOT / "data" / key, workspace / "data" / key)
        atomic_write(checked_path(change["path"], workspace / "data"), change["encoded"])
        target = build(
            key,
            asset_root=workspace / "data",
            output_root=workspace / "artifacts" / key,
            edited_assets={change["path"]: change["encoded"]},
        )
        result = target.read_bytes()
        if result != change["expected"]:
            raise ValueError("Edited build changes bytes outside its independently predicted ROM")
        if (ROOT / "data" / change["path"]).read_bytes() != change["original"]:
            raise ValueError("Canonical palette changed during the private edit proof")
        report["cases"].append(
            dict(
                profile=key,
                asset=change["path"],
                offset=change["offset"],
                artifact=target.relative_to(ROOT).as_posix(),
                sha256=sha256(result),
                changed_ranges=changed_ranges(change["reference"], result),
            )
        )
        print(f"[OK] Nonzero palette edit rebuilt {key} with only its predicted asset/checksum bytes")
    if inputs() != binding:
        raise ValueError("Authoring inputs changed during edited builds")
    report["passed"] = True
    atomic_write(ROOT / REPORT, (json.dumps(report, indent=2) + "\n").encode())
    return audit()


def audit() -> dict:
    report = load(REPORT)
    if report.get("passed") is not True or report.get("inputs") != inputs():
        raise ValueError("Edited container evidence is incomplete or stale")
    cases = report.get("cases", [])
    if [row["profile"] for row in cases] != [row["id"] for row in profiles()]:
        raise ValueError("Edited container evidence must cover every revision exactly once")
    workspace = checked_path(report["workspace"])
    if not workspace.is_relative_to((ROOT / "build/authoring").resolve()):
        raise ValueError("Edited evidence workspace escaped its private owner")
    catalog = Catalog()
    for row in cases:
        change = edit(catalog, row["profile"])
        target = checked_path(row["artifact"])
        if not target.is_relative_to(workspace) or target != workspace / "artifacts" / row["profile"] / "sonic1.bin":
            raise ValueError("Edited artifact does not belong to its profile workspace")
        result = target.read_bytes()
        for owners in catalog.assets.values():
            for asset in owners.values():
                if asset["image"] != row["profile"]:
                    continue
                payload = checked_path(asset["path"], workspace / "data").read_bytes()
                if asset["path"] == change["path"]:
                    valid = payload == change["encoded"]
                else:
                    valid = len(payload) == asset["size"] and sha1(payload) == asset["sha1"]
                if not valid:
                    raise ValueError("Private edited export changed after the accepted build")
        receipt = json.loads(target.with_name("inputs.json").read_text())
        expected_receipt = dict(
            report["inputs"]["preservation"], edited_assets={change["path"]: sha256(change["encoded"])}
        )
        if receipt != expected_receipt:
            raise ValueError("Edited build receipt differs from its source and asset binding")
        if (
            row["asset"] != change["path"]
            or row["offset"] != change["offset"]
            or result != change["expected"]
            or row["sha256"] != sha256(result)
            or row["changed_ranges"] != changed_ranges(change["reference"], result)
        ):
            raise ValueError("Edited ROM proof differs from the exact expected bytes")
    return report


def main():
    check()
    print("[OK] Nonzero edited-container proofs for all three revisions")
    return 0
