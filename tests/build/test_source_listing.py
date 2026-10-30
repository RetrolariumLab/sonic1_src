"""Ownership regressions for nested includes and transformed CPU storage."""

import unittest
from scripts.build.source_listing import Frame, exclusive, complete


class SourceOwnershipTests(unittest.TestCase):
    def test_child_includes_are_subtracted_and_overlap_is_rejected(self):
        parent = Frame("parent", 1, 0, "m68000_rom", children=[dict(start=2, end=4)], end=8)
        ranges = exclusive(parent)
        self.assertEqual([(row["start"], row["end"]) for row in ranges], [(0, 2), (4, 8)])
        complete([*ranges, dict(start=2, end=4)], 8)
        with self.assertRaises(ValueError):
            complete([*ranges, dict(start=1, end=4)], 8)
        parent.children.append(dict(start=3, end=5))
        with self.assertRaises(ValueError):
            exclusive(parent)

    def test_compressed_carrier_and_decoded_samples_use_distinct_spaces(self):
        driver = Frame("driver", 2, 0, "z80", children=[dict(start=2, end=6)], end=6, storage=dict(start=32, end=40))
        ranges = exclusive(driver)
        self.assertEqual(
            [(row["address_space"], row["start"], row["end"]) for row in ranges],
            [("z80", 0, 2), ("m68000_rom", 32, 40)],
        )
        complete([dict(start=0, end=2), dict(start=2, end=6)], 6)
        with self.assertRaises(ValueError):
            complete([dict(start=0, end=2)], 6)

    def test_generated_indexes_are_explicit_and_cannot_hide_emitted_instructions(self):
        from scripts.validation.source_layout import generated_index, origin_interval

        origin = dict(kind="generated_include_index", lines=[])
        self.assertIsNone(origin_interval(origin, 100))
        generated_index('; synthetic wrapper\n include "src/child.asm"\n', {"src/child.asm"})
        for text in ('include "src/child.asm"\nrts\n', 'include "src/missing.asm"\n', "; empty wrapper\n"):
            with self.assertRaises(ValueError):
                generated_index(text, {"src/child.asm"})
        for value in (
            dict(kind="preserved_span", lines=[]),
            dict(kind="generated_include_index", lines=[1, 2]),
            dict(kind="preserved_span", lines=[1, 101]),
        ):
            with self.assertRaises(ValueError):
                origin_interval(value, 100)

    def test_generated_wrapper_still_requires_the_preservation_origin_hash(self):
        from unittest.mock import patch
        from scripts.validation import source_layout
        from scripts.build.project import sha256

        raw = b"Synthetic original source\n"
        base = "1" * 40
        origin = dict(
            kind="generated_include_index", path="original.asm", lines=[], preservation_source_sha256=sha256(raw)
        )
        spec = dict(preservation_baseline_commit=base, modules=[dict(origin=origin)])
        with patch.object(source_layout.subprocess, "check_output", return_value=raw):
            source_layout.origins(base, spec)
            origin["preservation_source_sha256"] = "0" * 64
            with self.assertRaisesRegex(ValueError, "hash"):
                source_layout.origins(base, spec)
