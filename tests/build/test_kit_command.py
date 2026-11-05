"""Use one explicit Kit selection in Python wrappers and Make recipes."""

import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts.build.project import ROOT, rltool_command


class KitCommandTests(unittest.TestCase):
    def test_default_and_module_command_are_argument_lists(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(rltool_command(), ["rltool"])
        with patch.dict(os.environ, {"RLTOOL": "python -m retrolarium_kit.cli"}):
            self.assertEqual(rltool_command(), ["python", "-m", "retrolarium_kit.cli"])

    def test_existing_executable_with_spaces_is_one_argument(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="kit command ") as folder:
            tool = Path(folder) / "rltool.exe"
            tool.write_bytes(b"synthetic tool fixture")
            with patch.dict(os.environ, {"RLTOOL": str(tool)}):
                self.assertEqual(rltool_command(), [str(tool)])
