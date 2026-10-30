"""Public content inspection, checked document export and owner round trips."""

from __future__ import annotations
import argparse
import json
from pathlib import Path
import time
from scripts.authoring.catalog import Catalog
from scripts.authoring import content
from scripts.build.project import ROOT, atomic_write, checked_path, sha256, file_sha256
from scripts.build.sources import fingerprint


def local_output(path: Path) -> Path:
    target = path.resolve()
    if not any(
        target.is_relative_to((ROOT / name).resolve()) and target != (ROOT / name).resolve()
        for name in ("build", "content/workspace")
    ):
        raise ValueError("Content output must stay beneath build/ or content/workspace/")
    return target


def inputs() -> dict:
    paths = [
        *sorted((ROOT / "scripts/authoring").glob("*.py")),
        ROOT / "scripts/validation/content.py",
        ROOT / "scripts/build/source_listing.py",
        ROOT / "scripts/validation/source_layout.py",
        ROOT / "config/authoring/toolchain.json",
        ROOT / "config/authoring/data_formats.json",
        ROOT / "config/reconstruction/source_layout.json",
    ]
    return dict(
        preservation=fingerprint(), authoring={path.relative_to(ROOT).as_posix(): file_sha256(path) for path in paths}
    )


def roundtrip(catalog: Catalog, output: Path | None = None) -> dict:
    binding = inputs()
    rows = []
    start = time.monotonic()
    for item in catalog.items.values():
        raw, context = catalog.read(item)
        document = content.decode(raw, item, context)
        result, proof = content.encode(document, raw, item, context, destination_profile=item["profile"])
        if result != raw:
            raise ValueError("Zero-edit content differs from original storage")
        row = dict(
            owner=item["id"],
            profile=item["profile"],
            codec=item["codec"],
            source=item["source"],
            input_sha256=sha256(raw),
            size=len(raw),
            **proof,
        )
        rows.append(row)
        if len(rows) % 200 == 0 or len(rows) == len(catalog.items):
            print(f"[CONTENT] Checked {len(rows)}/{len(catalog.items)} owners", flush=True)
        if output is not None and item["source"]["kind"] == "asset":
            atomic_write(checked_path(item["source"]["path"], output), result)
    if inputs() != binding:
        raise ValueError("Content inputs changed during round trips")
    report = dict(
        schema_version=1,
        passed=True,
        inputs=binding,
        owners=len(rows),
        registry_sha256=sha256((ROOT / "config/authoring/data_formats.json").read_bytes()),
        seconds=time.monotonic() - start,
        rows=rows,
    )
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("list", "decode", "encode", "roundtrip"))
    parser.add_argument("--owner")
    parser.add_argument("--document", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--profile")
    args = parser.parse_args()
    try:
        catalog = Catalog()
        if args.action == "list":
            for row in catalog.items.values():
                print(f"{row['id']} [{row['codec']}]")
        elif args.action == "roundtrip":
            destination = local_output(args.output) if args.output else None
            if destination and destination.exists():
                raise ValueError("Round-trip export requires a new output directory")
            report = roundtrip(catalog, destination)
            atomic_write(ROOT / "build/authoring/roundtrip.json", (json.dumps(report, indent=2) + "\n").encode())
            print(f"[OK] Content owner round trips:{report['owners']}")
        else:
            if not args.owner or not args.output:
                raise ValueError("An owner and local output are required")
            item = catalog.select(args.owner)
            raw, context = catalog.read(item)
            destination = local_output(args.output)
            if args.action == "decode":
                result = (json.dumps(content.decode(raw, item, context), indent=2) + "\n").encode()
            else:
                if not args.document or not args.profile:
                    raise ValueError("Encoding requires a document and destination profile")
                result, _ = content.encode(
                    json.loads(args.document.read_text()), raw, item, context, destination_profile=args.profile
                )
            atomic_write(destination, result)
            print(f"[OK] {args.action}:{item['id']}")
    except (OSError, ValueError, KeyError, TypeError, IndexError) as error:
        parser.exit(1, f"error:{error}\n")
    return 0
