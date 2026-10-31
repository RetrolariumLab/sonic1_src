"""Reject world edits that fit ROM storage but exceed the engine's consumers."""

from copy import deepcopy
import unittest
from scripts.authoring import content, engine_contracts


class EngineContractTests(unittest.TestCase):
    def fixture(self, raw, kind, profile):
        item = dict(
            id="synthetic",
            profile=profile,
            abi="sonic1-md",
            codec=kind,
            address_space="m68000_rom",
            decoded_capacity=len(raw),
            source=dict(kind="asset"),
            compression=None,
        )
        context = dict(slot=len(raw), engine_capacities=dict(respawn=189, blocks=768, chunks=82))
        document = content.decode(raw, item, context)
        return document, item, context

    def encode(self, document, raw, item, context):
        return content.encode(document, raw, item, context, destination_profile=item["profile"])[0]

    def placements(self, xs):
        return b"".join(x.to_bytes(2, "big") + bytes([0, 0, 1, 0]) for x in xs) + b"\xff\xff"

    def test_capacities_follow_canonical_symbols_and_reserved_indices(self):
        symbols = dict(
            v_objstate=0xFFFC00,
            v_objstate_end=0xFFFCC0,
            v_16x16=0xFFB000,
            v_sgfx_buffer=0xFFC800,
            v_256x256=0xFF0000,
            v_256x256_end=0xFFA400,
            chunk_size=512,
        )
        self.assertEqual(engine_contracts.capacities(symbols), dict(respawn=189, blocks=768, chunks=82))
        symbols["v_objstate_end"] -= 1
        self.assertEqual(engine_contracts.capacities(symbols)["respawn"], 188)
        symbols["v_sgfx_buffer"] += 1
        with self.assertRaises(ValueError):
            engine_contracts.capacities(symbols)

    def test_respawn_boundary_is_checked_by_public_export_for_every_profile(self):
        raw = self.placements(range(0, 1600, 8))
        for profile in ("rev00", "rev01", "revxb"):
            with self.subTest(profile=profile):
                document, item, context = self.fixture(raw, "objects", profile)
                for row in document["model"]["records"][:189]:
                    row["remember"] = 1
                self.assertEqual(len(self.encode(document, raw, item, context)), len(raw))
                document["model"]["records"][189]["remember"] = 1
                with self.assertRaisesRegex(ValueError, "respawn allocation"):
                    self.encode(document, raw, item, context)

    def test_new_descending_x_is_rejected_and_equal_x_is_valid(self):
        raw = self.placements([0x100, 0x200])
        for profile in ("rev00", "rev01", "revxb"):
            document, item, context = self.fixture(raw, "objects", profile)
            document["model"]["records"][0]["x"] = 0x300
            with self.assertRaisesRegex(ValueError, "descending X"):
                self.encode(document, raw, item, context)
            document["model"]["records"][0]["x"] = 0x200
            self.assertEqual(len(self.encode(document, raw, item, context)), len(raw))

    def test_retail_inversion_must_keep_its_original_position_and_coordinates(self):
        raw = self.placements([0x100, 0x80, 0x200])
        document, item, context = self.fixture(raw, "objects", "rev00")
        self.assertEqual(self.encode(document, raw, item, context), raw)
        document["model"]["records"][2]["subtype"] = 1
        self.assertNotEqual(self.encode(document, raw, item, context), raw)
        changed = deepcopy(document)
        changed["model"]["records"][1]["x"] = 0x70
        with self.assertRaisesRegex(ValueError, "descending X"):
            self.encode(changed, raw, item, context)
        changed = deepcopy(document)
        changed["model"]["records"] = changed["model"]["records"][2:] + changed["model"]["records"][:2]
        with self.assertRaisesRegex(ValueError, "descending X"):
            self.encode(changed, raw, item, context)
        document["model"]["records"][1]["x"] = 0x100
        self.assertEqual(len(self.encode(document, raw, item, context)), len(raw))

    def test_block_references_must_fit_ram_even_when_the_slot_and_bits_fit(self):
        raw = bytes(512)
        for profile in ("rev00", "rev01", "revxb"):
            document, item, context = self.fixture(raw, "chunks256", profile)
            document["model"][0][0]["block"] = 767
            self.assertEqual(len(self.encode(document, raw, item, context)), 512)
            for index in (768, 1024, 2047):
                document["model"][0][0]["block"] = index
                with self.assertRaisesRegex(ValueError, "block allocation"):
                    self.encode(document, raw, item, context)

    def test_layout_checks_engine_mask_and_one_based_chunk_ids(self):
        raw = bytes([0, 0, 1])
        for profile in ("rev00", "rev01", "revxb"):
            document, item, context = self.fixture(raw, "layout", profile)
            for index in (0, 1, 82, 129, 168, 181, 209):
                document["model"]["rows"][0][0] = index
                self.assertEqual(len(self.encode(document, raw, item, context)), len(raw))
            for index in (83, 128, 210, 211, 255):
                document["model"]["rows"][0][0] = index
                with self.assertRaisesRegex(ValueError, "chunk allocation"):
                    self.encode(document, raw, item, context)

    def test_loop_collision_substitute_must_also_fit_chunk_ram(self):
        raw = bytes([0, 0, 1])
        document, item, context = self.fixture(raw, "layout", "rev00")
        context["engine_capacities"]["chunks"] = 40
        document["model"]["rows"][0][0] = 40
        self.assertEqual(len(self.encode(document, raw, item, context)), len(raw))
        document["model"]["rows"][0][0] = 0xA8
        with self.assertRaisesRegex(ValueError, "chunk allocation"):
            self.encode(document, raw, item, context)
        context["engine_capacities"]["chunks"] = 39
        document["model"]["rows"][0][0] = 39
        self.assertEqual(len(self.encode(document, raw, item, context)), len(raw))
        document["model"]["rows"][0][0] = 0xA7
        with self.assertRaisesRegex(ValueError, "chunk allocation"):
            self.encode(document, raw, item, context)

    def test_short_ending_rows_still_need_valid_chunk_references(self):
        raw = bytes([14, 2]) + bytes(30)
        document, item, context = self.fixture(raw, "ending_layout", "rev00")
        self.assertEqual(self.encode(document, raw, item, context), raw)
        document["model"]["stored_rows"][0][0] = 83
        with self.assertRaisesRegex(ValueError, "chunk allocation"):
            self.encode(document, raw, item, context)

    def test_world_export_fails_closed_without_engine_capacities(self):
        raw = self.placements([0x100])
        document, item, context = self.fixture(raw, "objects", "rev00")
        del context["engine_capacities"]
        with self.assertRaisesRegex(ValueError, "canonical engine capacities"):
            self.encode(document, raw, item, context)
