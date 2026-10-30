"""Build a timing-preserving relocation probe from a disposable source copy."""

from __future__ import annotations
import argparse
from collections import Counter
from pathlib import Path
import re
import shutil
from scripts.build.build_rom import build
from scripts.build.listing import symbol as listing_symbol
from scripts.build.project import ROOT, atomic_write, checked_path, image, load, profile, profiles, sha256
from scripts.validation.lint_project import source_paths

RETURN = re.compile(r"^\s*(?:[\w.]+:\s*)?(rts|rte)\s*(?:;.*)?$", re.IGNORECASE)
GLOBAL_LABEL = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*:")
MARKER = "unreachable relocation probe word"
PIPELINE_INPUTS = (
    "scripts/run.py",
    "config/revision_profiles.json",
    "assets/manifest.json",
    "config/build/derived_assets.json",
    "config/toolchain.json",
    "config/lint.json",
    "config/relocation/probe.json",
    "scripts/build/build_rom.py",
    "scripts/build/sources.py",
    "scripts/build/listing.py",
    "scripts/build/project.py",
    "scripts/build/toolchain.py",
    "scripts/build/split_assets.py",
    "scripts/validation/relocation.py",
    "scripts/validation/lint_project.py",
)


def pipeline_hashes() -> dict[str, str]:
    return {name: sha256((ROOT / name).read_bytes()) for name in PIPELINE_INPUTS}


def is_terminal(lines: list[str], index: int) -> bool:
    """Local continuation labels and instruction-table slots are not boundaries."""
    following = next((line for line in lines[index + 1 :] if line.split(";", 1)[0].strip()), "")
    code = following.split(";", 1)[0].strip()
    return bool(
        not code
        or GLOBAL_LABEL.match(code)
        or re.match(r"^(include|endif|else|endm|dc\.)\b", code)
        or (following and not following[0].isspace() and not following.startswith("."))
    )


def duplicate_returns(text: str) -> tuple[str, list[dict], list[dict]]:
    lines = text.splitlines()
    output, inserted, continuations = [], [], []
    for index, line in enumerate(lines):
        output.append(line)
        match = RETURN.match(line)
        if not match:
            continue
        site = {"line": index + 1, "instruction": match.group(1).lower()}
        if is_terminal(lines, index):
            output.append(f"                {site['instruction']} ; {MARKER}")
            inserted.append(site)
        else:
            continuations.append(site)
    return "\n".join(output) + "\n", inserted, continuations


def include_line(text: str, path: str) -> str:
    pattern = re.compile(r'^\s*include\s+"' + re.escape(path) + r'"[^\n]*$', re.MULTILINE)
    matches = pattern.findall(text)
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one include of {path}, got {len(matches)}")
    return matches[0]


def apply_layout(source: Path, spec: dict) -> None:
    for move in spec["include_moves"]:
        owner = checked_path(move["owner"], source)
        text = owner.read_text(encoding="utf-8")
        line = include_line(text, move["include"])
        text = text.replace(line, "; Probe placement is declared in config/relocation/probe.json", 1)
        if move.get("placement") == "end":
            text += "\n" + line + "\n"
        else:
            anchor = include_line(text, move["before_include"])
            text = text.replace(anchor, line + "\n" + anchor, 1)
        atomic_write(owner, text.encode())
    for move in spec["table_moves"]:
        owner = checked_path(move["owner"], source)
        text = owner.read_text(encoding="utf-8")
        first = text.index(move["first_label"] + ":")
        last = text.index("\n", text.index(move["last_label"] + ":", first)) + 1
        block = text[first:last]
        text = text[:first] + text[last:]
        position = text.index(move["before_label"] + ":")
        text = text[:position] + block + "\n" + text[position:]
        atomic_write(owner, text.encode())
    for change in spec["branch_widths"]:
        if (change["from"], change["to"], change["cpu"], change["cycles"]) != ("bra.s", "bra.w", "MC68000", 10):
            raise ValueError("Relocation may only relax an equal-cycle unconditional branch")
        owner = checked_path(change["owner"], source)
        text = owner.read_text(encoding="utf-8")
        expression = re.compile(r"\b" + re.escape(change["from"]) + r"(\s+)" + re.escape(change["target"]) + r"\b")
        matches = list(expression.finditer(text))
        if len(matches) != change["occurrences"]:
            raise ValueError("Branch relaxation no longer matches its source contract")
        match = matches[change["replace_occurrence"]]
        text = text[: match.start()] + change["to"] + match.group(1) + change["target"] + text[match.end() :]
        atomic_write(owner, text.encode())
    padding = spec["reclaim_padding"]
    owner = checked_path(padding["owner"], source)
    text = owner.read_text(encoding="utf-8")
    for amount in padding["expressions"]:
        text = replace_padding(text, amount, "0")
    atomic_write(owner, text.encode())
    anchor = spec["sample_anchor"]
    owner = checked_path(anchor["owner"], source)
    text = owner.read_text(encoding="utf-8")
    if text.count(anchor["before_comment"]) != 1:
        raise ValueError("Sample bank boundary marker is ambiguous")
    text = text.replace(anchor["before_comment"], anchor["observation_label"] + ":\n" + anchor["before_comment"])
    atomic_write(owner, text.encode())


def replace_padding(text: str, expression: str, replacement: str) -> str:
    pattern = re.compile(r"(\bdcb\.b\s+)" + re.escape(expression) + r"(,\s*\$FF)")
    text, count = pattern.subn(lambda match: match[1] + replacement + match[2], text)
    if count != 1:
        raise ValueError(f"Padding reservoir {expression} has {count} matches")
    return text


def artifact(profile_id: str) -> Path:
    profile(profile_id)
    return ROOT / "build/relocated" / profile_id / "source/artifacts/sonic1.bin"


def run(profile_id: str) -> Path:
    profile(profile_id)
    spec = load("config/relocation/probe.json")
    destination = checked_path("build/relocated/" + profile_id)
    if destination.exists():
        shutil.rmtree(destination)
    source = destination / "source"
    records, continuations, hashes = [], [], {}
    for relative in source_paths():
        original = (ROOT / relative).read_bytes()
        text, inserted, kept = duplicate_returns(original.decode("utf-8"))
        atomic_write(checked_path(relative.as_posix(), source), text.encode())
        hashes[relative.as_posix()] = sha256(original)
        records += [{"path": relative.as_posix(), **item} for item in inserted]
        continuations += [{"path": relative.as_posix(), **item} for item in kept]
    if not records:
        raise ValueError("Relocation selected no procedure boundaries")
    apply_layout(source, spec)
    output = source / "artifacts"
    initial = build(profile_id, source_root=source, output_root=output)
    anchor = spec["sample_anchor"]
    actual = listing_symbol(output / "entry.lst", anchor["observation_label"])
    suffix = profile_id + "/" + anchor["sample_path"]
    payload = next(item for item in load("assets/manifest.json")["assets"] if item["path"] == suffix)
    delta = actual - payload["offset"]
    padding = spec["audio_padding"]
    expression = padding["expressions"][profile_id]
    capacity = int(expression.replace("$", "0x"), 0)
    if not 0 <= delta <= capacity or delta % 2:
        raise ValueError(f"Relocated growth {delta} does not fit its even padding reservoir {capacity}")
    owner = checked_path(padding["owner"], source)
    text = owner.read_text(encoding="utf-8")
    for amount in sorted(set(padding["expressions"].values())):
        text = replace_padding(text, amount, f"({amount}-{delta})")
    atomic_write(owner, text.encode())
    target = build(profile_id, source_root=source, output_root=output)
    raw = target.read_bytes()
    if len(raw) != image(profile_id)["size"]:
        raise ValueError("Relocation changed the ROM size and checksum-loop cycle count")
    if listing_symbol(output / "entry.lst", anchor["label"]) != payload["offset"]:
        raise ValueError("Relocation changed the fixed sample-bank tail")
    if sha256(raw) == image(profile_id)["sha256"]:
        raise ValueError("Relocation produced the canonical image without moving code")
    lines = (output / "entry.lst").read_text(errors="replace").splitlines()
    active = sum(bool(re.search(r":\s*(4E75|4E73)\s+.*" + MARKER, line)) for line in lines)
    if not active:
        raise ValueError("Listing proves no inserted return instructions")
    import json

    report = {
        "schema_version": 1,
        "profile": profile_id,
        "source_hashes": hashes,
        "pipeline_hashes": pipeline_hashes(),
        "generated_sites": records,
        "internal_returns_and_table_slots": continuations,
        "active_inserted_words": active,
        "module_counts": dict(Counter(item["path"] for item in records)),
        "padding_absorbed": delta,
        "rom_size": len(raw),
        "sha256": sha256(raw),
        "sample_offset": payload["offset"],
    }
    atomic_write(destination / "relocation.json", (json.dumps(report, indent=2) + "\n").encode())
    print(f"[OK] Relocated {profile_id}: {active} active return words; original image size and PCM tail preserved")
    return target


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", default=load("config/revision_profiles.json")["default"])
    parser.add_argument("--all", action="store_true")
    args = parser.parse_args()
    ids = [item["id"] for item in profiles()] if args.all else [args.profile]
    try:
        for selected in ids:
            run(selected)
    except (OSError, ValueError) as error:
        parser.exit(1, f"error: {error}\n")
    return 0
