"""Public build commands; profile metadata stays in JSON rather than Make."""

import argparse
from pathlib import Path
import shutil
from scripts.build import build_rom, split_assets, toolchain
from scripts.build.project import ROOT, load, profiles, read_rom


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action",
        choices=("split", "check-assets", "inputs", "build", "verify", "verify-all", "verify-toolchain", "clean"),
    )
    parser.add_argument("--profile", default=load("config/revision_profiles.json")["default"])
    parser.add_argument("--rom-dir", type=Path, default=Path("."))
    parser.add_argument("--all", action="store_true")
    args = parser.parse_args()
    ids = (
        [item["id"] for item in profiles()]
        if args.all or args.action in ("split", "verify-all", "inputs")
        else [args.profile]
    )
    try:
        if args.action == "split":
            split_assets.split(ids, args.rom_dir)
        elif args.action == "check-assets":
            split_assets.check(ids)
        elif args.action == "inputs":
            for item in ids:
                read_rom(item, args.rom_dir)
                print(f"[OK] Private input: {item}")
        elif args.action == "verify-toolchain":
            for name in toolchain.resolve():
                print(f"[OK] Pinned toolchain: {name}")
        elif args.action == "build":
            build_rom.build(args.profile)
        elif args.action in ("verify", "verify-all"):
            for item in ids:
                build_rom.verify(item, args.rom_dir)
        elif args.action == "clean":
            for name in ("artifacts", "relocated", "runtime"):
                target = ROOT / "build" / name
                if target.is_symlink() or not target.resolve().is_relative_to((ROOT / "build").resolve()):
                    raise ValueError("Refusing cleanup outside build/")
                if target.exists():
                    shutil.rmtree(target)
            print("[OK] Removed reproducible build outputs")
    except (OSError, ValueError) as error:
        parser.exit(1, f"error: {error}\n")
    return 0
