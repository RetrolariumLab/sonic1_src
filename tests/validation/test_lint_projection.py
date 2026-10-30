"""Regression for AS declarations that must remain in the label field."""

import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from scripts.build.project import ROOT
from scripts.build.toolchain import resolve
from scripts.validation.lint_project import protect_fields, restore_fields, source_paths


class AslProjectionTests(unittest.TestCase):
    def test_every_tracked_assembler_source_is_selected(self):
        tracked = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "-z"])
        expected = {
            Path(raw.decode())
            for raw in tracked.split(b"\0")
            if raw and Path(raw.decode()).suffix in (".asm", ".s", ".inc")
        }
        self.assertEqual(set(source_paths()), expected)

    @unittest.skipUnless(shutil.which("rltool"), "Retrolarium Kit is not installed")
    def test_official_formatting_preserves_actual_assembler_semantics(self):
        try:
            tools = resolve()
        except ValueError as error:
            self.skipTest(str(error))
        source = """                cpu 68000
Value = $10
Counter := 0
twice function x,x*2
Layout struct DOTS
.field ds.w 1
                endstruct
Main:
.local: dc.w twice(Value)
Counter := Counter+1
                dc.w Counter
                END
"""
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="style-test-") as folder:
            root = Path(folder)
            projected, mapping = protect_fields(source)
            (root / "fixture.s").write_bytes(projected.encode())
            (root / "config").mkdir()
            (root / "config/lint.json").write_bytes(
                json.dumps(
                    {
                        "schema": "retrolarium.lint",
                        "schema_version": 1,
                        "assembly": {"dialect": "asl", "paths": ["fixture.s"]},
                        "code": False,
                    }
                ).encode()
            )
            subprocess.run(
                ["rltool", "lint", "--project", folder, "--fix"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
            )
            formatted = restore_fields((root / "fixture.s").read_text(), mapping)
            for name, text in (("before", source), ("after", formatted)):
                (root / f"{name}.asm").write_bytes(text.encode())
                subprocess.run(
                    [str(tools["asl"]), "-xx", "-n", "-q", "-A", "-L", "-U", "-E", "-i", ".", f"{name}.asm"],
                    cwd=root,
                    check=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                )
                conversion = subprocess.run(
                    [str(tools["p2bin"]), "-p=FF", f"{name}.p", f"{name}.bin"],
                    cwd=root,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                )
                self.assertEqual(
                    conversion.returncode,
                    0,
                    conversion.stdout.decode(errors="replace") + str([p.name for p in root.iterdir()]),
                )
            self.assertEqual((root / "before.bin").read_bytes(), bytes.fromhex("00200001"))
            self.assertEqual((root / "before.bin").read_bytes(), (root / "after.bin").read_bytes())
