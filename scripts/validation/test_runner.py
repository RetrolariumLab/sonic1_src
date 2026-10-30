"""Run the complete ROM-independent unit and contract suite."""

import unittest
from scripts.build.project import ROOT


def main() -> int:
    suite = unittest.defaultTestLoader.discover(str(ROOT / "tests"), top_level_dir=str(ROOT))
    return 0 if unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful() else 1
