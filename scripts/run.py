"""Stable launcher for the repository's Python commands."""
from pathlib import Path
import importlib
import os
import sys

sys.dont_write_bytecode = True
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("usage: python scripts/run.py <package.module> [arguments]")
    module = importlib.import_module("scripts." + sys.argv.pop(1))
    raise SystemExit(module.main())
