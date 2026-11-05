"""Independent cartridge expectations for bounded nonzero edits."""

import unittest
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
from unittest.mock import patch
from scripts.authoring import edited_containers as workflow
from scripts.build.project import ROOT, sha256
from scripts.authoring.edited_containers import changed_ranges, expected_image


class EditedContainerTests(unittest.TestCase):
    def test_changed_palette_updates_only_its_byte_and_the_cartridge_checksum(self):
        original = bytes(1024)
        expected = expected_image(original, 512, bytes(4), b"\x00\x02\x00\x00")
        self.assertEqual(expected[0x18E:0x190], b"\x00\x02")
        self.assertEqual(changed_ranges(original, expected), [dict(start=399, end=400), dict(start=513, end=514)])

    def test_no_edit_wrong_owner_header_and_footprint_changes_fail(self):
        original = bytes(1024)
        for offset, before, after in (
            (512, b"\0", b"\0"),
            (512, b"\1", b"\2"),
            (0, b"\0", b"\2"),
            (513, b"\0", b"\2"),
            (512, b"\0", b"\0\2"),
        ):
            with self.subTest(offset=offset, before=before), self.assertRaises(ValueError):
                expected_image(original, offset, before, after)

    def test_adjacent_changes_and_final_byte_ranges_are_exact(self):
        self.assertEqual(changed_ranges(b"123456", b"1AA45B"), [dict(start=1, end=3), dict(start=5, end=6)])
        with self.assertRaises(ValueError):
            changed_ranges(b"123", b"1234")

    def test_post_build_export_receipt_and_rom_tampering_are_rejected(self):
        parent = ROOT / "build/authoring"
        parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=parent) as folder:
            workspace = Path(folder)
            name = "rev01/palette/Sonic.bin"
            exported = workspace / "data" / name
            exported.parent.mkdir(parents=True)
            exported.write_bytes(b"01")
            target = workspace / "artifacts/rev01/sonic1.bin"
            target.parent.mkdir(parents=True)
            target.write_bytes(b"newrom")
            binding = dict(preservation=dict(schema_version=1))
            receipt = dict(binding["preservation"], edited_assets={name: sha256(b"01")})
            receipt_path = target.with_name("inputs.json")
            receipt_path.write_text(json.dumps(receipt))
            case = dict(
                profile="rev01",
                asset=name,
                offset=512,
                artifact=target.relative_to(ROOT).as_posix(),
                sha256=sha256(b"newrom"),
                changed_ranges=changed_ranges(b"oldrom", b"newrom"),
            )
            report = dict(passed=True, inputs=binding, cases=[case], workspace=workspace.relative_to(ROOT).as_posix())
            change = dict(path=name, offset=512, encoded=b"01", reference=b"oldrom", expected=b"newrom")
            catalog = SimpleNamespace(assets={"manifest": {name: dict(path=name, image="rev01")}})
            with (
                patch.object(workflow, "load", return_value=report),
                patch.object(workflow, "inputs", return_value=binding),
                patch.object(workflow, "profiles", return_value=[dict(id="rev01")]),
                patch.object(workflow, "Catalog", return_value=catalog),
                patch.object(workflow, "edit", return_value=change),
            ):
                workflow.audit()
                for path, original, altered in (
                    (exported, b"01", b"02"),
                    (receipt_path, receipt_path.read_bytes(), b"{}"),
                    (target, b"newrom", b"badrom"),
                ):
                    path.write_bytes(altered)
                    with self.subTest(path=path), self.assertRaises(ValueError):
                        workflow.audit()
                    path.write_bytes(original)
