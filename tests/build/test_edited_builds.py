"""Private asset probes cannot weaken canonical builds or overwrite their outputs."""

from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts.build import build_rom
from scripts.build.project import ROOT


class EditedBuildGuards(unittest.TestCase):
    def test_edits_require_the_correct_owner_size_and_separate_output(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as folder:
            root = Path(folder)
            canonical = root / "data/fixture.bin"
            canonical.parent.mkdir()
            canonical.write_bytes(b"original")
            exports = root / "export/fixture.bin"
            exports.parent.mkdir()
            exports.write_bytes(b"modified")
            owners = dict(assets=[dict(image="rev01", path="fixture.bin")])
            cases = (
                ({"fixture.bin": b"modified"}, None),
                ({"fixture.bin": b"modified"}, root / "build/artifacts/rev01"),
                ({"other.bin": b"modified"}, root / "build/authoring/probe"),
                ({"fixture.bin": b"short"}, root / "build/authoring/probe"),
            )
            for changes, destination in cases:
                with (
                    self.subTest(changes=changes, destination=destination),
                    patch.object(build_rom, "ROOT", root),
                    patch.object(build_rom, "profile", return_value={"image": "rev01"}),
                    patch.object(build_rom, "fingerprint", return_value={}),
                    patch.object(build_rom, "check"),
                    patch.object(build_rom, "load", return_value=owners),
                    self.assertRaises(ValueError),
                ):
                    build_rom.build("rev01", asset_root=root / "export", output_root=destination, edited_assets=changes)

    def test_modified_export_is_rejected_by_the_default_preservation_path(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as folder:
            root = Path(folder)
            for prefix, data in (("data", b"original"), ("export", b"modified")):
                path = root / prefix / "fixture.bin"
                path.parent.mkdir()
                path.write_bytes(data)
            with (
                patch.object(build_rom, "ROOT", root),
                patch.object(build_rom, "profile", return_value={"image": "rev01"}),
                patch.object(build_rom, "fingerprint", return_value={}),
                patch.object(build_rom, "check"),
                patch.object(build_rom, "load", return_value=dict(assets=[dict(image="rev01", path="fixture.bin")])),
                self.assertRaisesRegex(ValueError, "differs"),
            ):
                build_rom.build("rev01", asset_root=root / "export")
