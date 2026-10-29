import os
from pathlib import Path
import unittest
from scripts.build.build_rom import compare, fix_header
from scripts.build.project import ROOT, checked_path, image, profiles, read_rom


class PreservationTests(unittest.TestCase):
    def test_header_uses_big_endian_words_and_current_length(self):
        raw = bytes(0x200) + bytes([0x12, 0x34, 0xFF, 0xFE])
        result = fix_header(raw)
        self.assertEqual(result[0x18E:0x190], bytes([0x12, 0x32]))
        self.assertEqual(int.from_bytes(result[0x1A4:0x1A8], "big"), len(raw) - 1)
        self.assertEqual(result[0x200:], raw[0x200:])
        for invalid in (b"", bytes(0x201)):
            with self.assertRaises(ValueError):
                fix_header(invalid)

    def test_compare_reports_an_actual_first_difference(self):
        compare(b"abc", b"abc")
        with self.assertRaisesRegex(ValueError, "0x1"):
            compare(b"adc", b"abc")
        with self.assertRaisesRegex(ValueError, "size"):
            compare(b"a", b"aa")

    def test_paths_cannot_escape_their_owner(self):
        for path in ("../outside", "C:/outside", "a/../../outside", "."):
            with self.subTest(path=path), self.assertRaises(ValueError):
                checked_path(path)
        self.assertEqual(checked_path("build/report.json"), ROOT / "build/report.json")

    def test_all_profiles_have_unique_manifest_images(self):
        ids = [item["id"] for item in profiles()]
        self.assertEqual(set(ids), {"rev00", "rev01", "revxb"})
        self.assertEqual(len(ids), len(set(ids)))
        for item in ids:
            self.assertEqual(image(item)["id"], item)

    def test_optional_user_inputs(self):
        directory = Path(os.environ.get("ROM_DIR", str(ROOT)))
        if not all((directory / image(item["id"])["file"]).is_file() for item in profiles()):
            self.skipTest("Accepted private ROMs are not present; pure build contracts still run")
        for item in profiles():
            read_rom(item["id"], directory)
