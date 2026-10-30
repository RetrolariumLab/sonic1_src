"""Stable launcher for the repository's Python commands."""

from pathlib import Path
import importlib
import os
import sys

sys.dont_write_bytecode = True
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
ROOT = Path(__file__).resolve().parents[1]
TEMPORARY = ROOT / "build/tmp"
if not TEMPORARY.resolve().is_relative_to(ROOT):
    raise SystemExit("Temporary directory escapes the project")
TEMPORARY.mkdir(parents=True, exist_ok=True)
os.environ.update(TEMP=str(TEMPORARY), TMP=str(TEMPORARY), TMPDIR=str(TEMPORARY))
sys.path.insert(0, str(ROOT))
if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("usage: python scripts/run.py <package.module> [arguments]")
    module = importlib.import_module("scripts." + sys.argv.pop(1))
    raise SystemExit(module.main())
