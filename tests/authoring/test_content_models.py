"""ROM-independent content ABI, shape, capacity and shared-byte regressions."""

from copy import deepcopy
from dataclasses import replace
import unittest
from scripts.authoring import records, tables, enigma, smps, kosinski_optimal as kosinski
from scripts.authoring.kosinski import decode as kosinski_decode


class RecordContracts(unittest.TestCase):
    def test_word_fields_palette_and_tiles_preserve_reserved_bits(self):
        for kind, raw in [
            ("tile_words", bytes.fromhex("ffff0123")),
            ("palette", bytes.fromhex("f1110eee")),
            ("tiles4bpp", bytes(range(32))),
        ]:
            model = records.decode(raw, kind)
            self.assertEqual(records.encode(model, kind, capacity=len(raw)), raw)
        model = records.decode(bytes(32), "tiles4bpp")
        model[0][0] = 16
        with self.assertRaises(ValueError):
            records.encode(model, "tiles4bpp", capacity=32)

    def test_layout_bounds_and_named_short_ending_remain_distinct(self):
        raw = bytes([1, 1, 1, 2, 3, 4])
        model = records.decode(raw, "layout")
        self.assertEqual(records.encode(model, "layout", capacity=6), raw)
        with self.assertRaises(ValueError):
            records.decode(raw[:-1], "layout")
        model["rows"] = [[1, 2, 3], [4, 5, 6]]
        model["width"] = 3
        with self.assertRaises(ValueError):
            records.encode(model, "layout", capacity=6)
        short = bytes([14, 2]) + bytes(30)
        model = records.decode(short, "ending_layout")
        self.assertEqual(model["read_beyond_owner"], 15)
        with self.assertRaises(ValueError):
            records.decode(short, "layout")
        model["declared_height"] = 2
        with self.assertRaises(ValueError):
            records.encode(model, "ending_layout", capacity=32)

    def test_objects_and_counted_platforms_have_different_headers(self):
        raw = bytes.fromhex("0001c12385ffffff00000000")
        model = records.decode(raw, "objects")
        self.assertEqual(records.encode(model, "objects", capacity=len(raw)), raw)
        self.assertEqual(model["records"][0]["object"], 5)
        model["records"][0]["x"] = 65535
        with self.assertRaises(ValueError):
            records.encode(model, "objects", capacity=len(raw))
        raw = bytes.fromhex("0001000100020003000400050006")
        model = records.decode(raw, "platform_group")
        self.assertEqual(len(model["records"]), 2)
        self.assertEqual(records.encode(model, "platform_group", capacity=len(raw)), raw)
        with self.assertRaises(ValueError):
            records.decode(raw[:-1], "platform_group")

    def test_dpcm_is_reversible_but_unrepresentable_waveform_steps_are_rejected(self):
        raw = bytes.fromhex("1234fedc")
        model = records.decode(raw, "dpcm")
        self.assertEqual(records.encode(model, "dpcm", capacity=4), raw)
        model[0] = 131
        with self.assertRaises(ValueError):
            records.encode(model, "dpcm", capacity=4)
        with self.assertRaises(ValueError):
            records.encode([128], "dpcm", capacity=1)

    def test_demo_and_collision_bounds_are_checked_before_output(self):
        model = records.decode(bytes.fromhex("ff00aaFF"), "demo")
        self.assertEqual(model[1]["frames"], 256)
        model[0]["frames"] = 257
        with self.assertRaises(ValueError):
            records.encode(model, "demo", capacity=4)
        with self.assertRaises(ValueError):
            records.encode([[17] * 16], "collision_heights", capacity=16)


class TableContracts(unittest.TestCase):
    def mapping(self):
        raw = bytes.fromhex("00040005010000000000")
        events = [
            dict(kind="mappingsTable", offset=0),
            dict(kind="mappingsTableEntry.w", offset=0),
            dict(kind="mappingsTableEntry.w", offset=2),
            dict(kind="spriteHeader", offset=4),
            dict(kind="spritePiece", offset=5),
        ]
        return raw, tables.decode_mapping(raw, events, profile="rev00")

    def test_blank_byte_alias_protects_the_shared_coordinate(self):
        raw, model = self.mapping()
        self.assertEqual(model["blank_aliases"], [5])
        self.assertEqual(tables.encode_mapping(model, profile="rev00", capacity=len(raw)), raw)
        model["frames"][0]["pieces"][0]["y"] = 1
        with self.assertRaisesRegex(ValueError, "Shared frame"):
            tables.encode_mapping(model, profile="rev00", capacity=len(raw))

    def test_mapping_unknown_targets_coordinates_and_profile_cannot_be_written(self):
        raw, original = self.mapping()
        for mutation in ("target", "coordinate", "profile"):
            model = deepcopy(original)
            if mutation == "target":
                model["tables"][0]["entries"][0]["target"] = 9
            elif mutation == "coordinate":
                model["frames"][0]["pieces"][0]["x"] = 128
            else:
                model["profile"] = "rev01"
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                tables.encode_mapping(model, profile="rev00", capacity=len(raw))

    def test_dplc_field_limits(self):
        raw = bytes.fromhex("000201ffff")
        events = [
            dict(kind="mappingsTable", offset=0),
            dict(kind="mappingsTableEntry.w", offset=0),
            dict(kind="dplcHeader", offset=2),
        ]
        model = tables.decode_mapping(raw, events, profile="rev01")
        self.assertEqual(tables.encode_mapping(model, profile="rev01", capacity=5), raw)
        model["frames"][0]["pieces"][0]["tiles"] = 17
        with self.assertRaises(ValueError):
            tables.encode_mapping(model, profile="rev01", capacity=5)

    def test_animation_change_and_rewind_stay_within_their_owner(self):
        for raw in (bytes.fromhex("0002050102fd00"), bytes.fromhex("0002050102fe02")):
            model = tables.decode_animation(raw, profile="rev00")
            self.assertEqual(tables.encode_animation(model, profile="rev00", capacity=len(raw)), raw)
            script = model["scripts"][0]
            script["terminal"]["arguments"][0] = 3
            with self.assertRaises(ValueError):
                tables.encode_animation(model, profile="rev00", capacity=len(raw))

    def test_animation_targets_and_fixed_player_slots(self):
        raw = bytes.fromhex("00020501ff00")
        model = tables.decode_animation(raw, profile="rev01")
        self.assertEqual(tables.encode_animation(model, profile="rev01", capacity=6), raw)
        model["entries"][0] = 3
        with self.assertRaises(ValueError):
            tables.encode_animation(model, profile="rev01", capacity=6)
        raw = bytes.fromhex("0002ff01020304ffffff")
        model = tables.decode_animation(raw, profile="rev00", special_player=True)
        self.assertEqual(len(model["scripts"][0]["special_slots"]), 6)
        self.assertEqual(tables.encode_animation(model, profile="rev00", capacity=10), raw)
        model["scripts"][0]["special_slots"].pop()
        with self.assertRaises(ValueError):
            tables.encode_animation(model, profile="rev00", capacity=10)


class StreamContracts(unittest.TestCase):
    def test_enigma_pccvh_counterexample_and_boundaries(self):
        raw = bytes.fromhex("010400000000e1ff")
        doc = enigma.decode(raw)
        self.assertEqual(enigma.words(doc), bytes.fromhex("2001"))
        self.assertEqual(enigma.encode(doc), raw)
        with self.assertRaises(ValueError):
            enigma.decode(raw, max_output=0)
        with self.assertRaises(ValueError):
            enigma.encode(replace(doc, tile_bits=17))
        with self.assertRaises(ValueError):
            enigma.decode(raw[:-1])

    def test_smps_control_flow_and_destination_profile(self):
        raw = bytes.fromhex("000001000101000a0000f200")
        doc = smps.decode(raw, kind="music", profile="rev00")
        self.assertEqual(smps.encode(doc, profile="rev00", capacity=len(raw)), raw)
        with self.assertRaises(ValueError):
            smps.encode(doc, profile="rev01", capacity=len(raw))
        with self.assertRaises(ValueError):
            smps.encode(doc, profile="rev00", capacity=len(raw) - 1)
        broken = bytearray(raw)
        broken[6:8] = b"\xff\xff"
        with self.assertRaises(ValueError):
            smps.decode(bytes(broken), kind="music", profile="rev00")

    def test_smps_fm_voices_are_fields_and_commands_cannot_jump_to_them(self):
        raw = bytes.fromhex("000d01018004000a0000ef00f2") + bytes(25)
        doc = smps.decode(raw, kind="sfx", profile="revxb")
        self.assertEqual(len(doc["voices"]), 1)
        self.assertEqual(smps.encode(doc, profile="revxb", capacity=len(raw)), raw)
        doc["nodes"][0]["opcode"] = 0xF6
        doc["nodes"][0]["arguments"] = [0, 0]
        doc["nodes"][0]["target"] = 13
        with self.assertRaises(ValueError):
            smps.encode(doc, profile="revxb", capacity=len(raw))

    def test_kosinski_descriptor_boundaries_and_compressed_slot_capacity(self):
        for size in (0, 1, 15, 16, 17, 31, 32, 255, 256, 257, 1024):
            raw = bytes(i & 255 for i in range(size))
            packed = kosinski.encode(raw)
            self.assertEqual(kosinski_decode(packed, max_output=max(size, 1)).data, raw)
        with self.assertRaises(ValueError):
            kosinski.encode(bytes(range(32)), capacity=2)
        with self.assertRaises(ValueError):
            kosinski_decode(bytes.fromhex("000000"), max_output=100)


if __name__ == "__main__":
    unittest.main(verbosity=2)
