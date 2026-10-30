"""Reject mismatched destinations and invalid edits before output replacement."""

from copy import deepcopy
import unittest
from scripts.authoring import content, enigma
from scripts.authoring.catalog import Catalog
from scripts.build.project import profiles


class ContentDocumentTests(unittest.TestCase):
    def setUp(self):
        self.profile = profiles()[0]["id"]
        self.item = dict(
            id="synthetic",
            profile=self.profile,
            abi="sonic1-md",
            codec="start_position",
            address_space="m68000_rom",
            decoded_capacity=4,
            source=dict(kind="asset"),
            compression=None,
        )
        self.raw = bytes.fromhex("00010002")
        self.context = dict(slot=4)
        self.doc = content.decode(self.raw, self.item, self.context)

    def test_edit_changes_real_record_bytes(self):
        self.doc["model"]["x"] = 513
        result, proof = content.encode(self.doc, self.raw, self.item, self.context, destination_profile=self.profile)
        self.assertEqual(result, bytes.fromhex("02010002"))
        self.assertFalse(proof["unchanged"])

    def test_foreign_profile_abi_owner_capacity_and_reference_are_rejected(self):
        for field, value in (
            ("abi", "other"),
            ("owner", "other"),
            ("decoded_capacity", 8),
            ("reference_sha256", "0" * 64),
            ("address_space", "z80"),
        ):
            with self.subTest(field=field):
                document = deepcopy(self.doc)
                document[field] = value
                with self.assertRaises(ValueError):
                    content.encode(document, self.raw, self.item, self.context, destination_profile=self.profile)
        other = next(row["id"] for row in profiles() if row["id"] != self.profile)
        with self.assertRaises(ValueError):
            content.encode(self.doc, self.raw, self.item, self.context, destination_profile=other)

    def test_capacity_overflow_does_not_truncate(self):
        self.doc["model"]["x"] = 65536
        with self.assertRaises(ValueError):
            content.encode(self.doc, self.raw, self.item, self.context, destination_profile=self.profile)

    def test_full_enigma_attribute_literals_are_real_reencodings(self):
        plain = bytes.fromhex("ffffa12320010000") * 17
        encoded = content.literal_enigma(plain)
        self.assertEqual(enigma.words(enigma.decode(encoded)), plain)

    def test_public_registry_covers_all_extraction_owners_without_roms(self):
        catalog = Catalog()
        self.assertGreater(len(catalog.items), 1000)
        with self.assertRaises(ValueError):
            catalog.select("nonexistent")

    def test_palette_script_cannot_read_a_neighbour_or_write_outside_palette_ram(self):
        from scripts.authoring import records

        item = dict(codec="palette_cycle", profile=self.profile)
        context = dict(source_palettes=[(32, 48)], palette_ram=(0xFB00, 0xFB80))
        rows = [dict(frames=8, colours=3, source=36, destination=0xFB02)]
        raw = records.encode(rows, "palette_cycle", capacity=8)
        self.assertEqual(content.model_decode(raw, item, context), rows)
        for field, value in (("source", 46), ("destination", 0xFB80), ("destination", 0xFB01)):
            changed = deepcopy(rows)
            changed[0][field] = value
            with self.assertRaises(ValueError):
                content.model_decode(records.encode(changed, "palette_cycle", capacity=8), item, context)

    def test_identical_bytes_do_not_skip_another_owners_capacity(self):
        from types import SimpleNamespace
        from scripts.authoring.cli import roundtrip

        first = deepcopy(self.item)
        first["id"] = "synthetic:first"
        second = deepcopy(self.item)
        second["id"] = "synthetic:second"
        second["decoded_capacity"] = 8
        catalog = SimpleNamespace(
            items={first["id"]: first, second["id"]: second}, read=lambda item: (self.raw, self.context)
        )
        with self.assertRaisesRegex(ValueError, "allocation"):
            roundtrip(catalog)

    def test_identical_palette_scripts_do_not_skip_another_owners_read_boundary(self):
        from types import SimpleNamespace
        from scripts.authoring import records
        from scripts.authoring.cli import roundtrip

        rows = [dict(frames=8, colours=3, source=36, destination=0xFB02)]
        raw = records.encode(rows, "palette_cycle", capacity=8)
        first = dict(self.item, id="synthetic:first", codec="palette_cycle", decoded_capacity=8)
        second = dict(first, id="synthetic:second")

        def read(item):
            bound = (32, 48) if item is first else (32, 40)
            return raw, dict(slot=8, source_palettes=[bound], palette_ram=(0xFB00, 0xFB80))

        catalog = SimpleNamespace(items={first["id"]: first, second["id"]: second}, read=read)
        with self.assertRaisesRegex(ValueError, "source palette"):
            roundtrip(catalog)
