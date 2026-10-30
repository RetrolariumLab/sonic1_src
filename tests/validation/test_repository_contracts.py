"""The public Make interface and preservation-only source policy."""

from pathlib import Path
import re
import subprocess
import unittest
from scripts.build.project import ROOT


class RepositoryContracts(unittest.TestCase):
    def test_help_names_every_public_action(self):
        makefile = (ROOT / "Makefile").read_text()
        public = set()
        for line in makefile.splitlines():
            if line.startswith(".PHONY:"):
                public.update(line.partition(":")[2].split())
        output = subprocess.check_output(["make", "-C", str(ROOT), "help"], text=True)
        for target in public - {"help"}:
            self.assertIn(target, output)

    def test_community_switches_are_not_executable_source(self):
        flags = re.compile(
            r"\b(?:FixBugs|CheatsEnabled|AllOptimizations|SkipChecksumCheck|ZeroOffsetOptimization|PaddingOptimization|UnusedOptimization|EnableSRAM|BackupSRAM|AddressSRAM|FixMusicAndSFXDataBugs)\b",
            re.IGNORECASE,
        )
        tracked = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "-z"])
        for raw in tracked.split(b"\0"):
            if raw and Path(raw.decode()).suffix in (".asm", ".s", ".inc"):
                path = raw.decode()
                for number, line in enumerate((ROOT / path).read_text().splitlines(), 1):
                    self.assertIsNone(flags.search(line.split(";", 1)[0]), f"{path}:{number}")
