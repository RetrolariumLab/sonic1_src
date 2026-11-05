"""Keep real memory owners connected to their grammar and historical witnesses."""

from copy import deepcopy
import unittest
from unittest.mock import patch

from scripts.build.project import ROOT, load
from scripts.validation import memory_contracts as codec


class MemoryContractTests(unittest.TestCase):
    def test_every_real_owner_matches_its_current_contract(self):
        codec.check()

    def test_stale_phase_contract_fails_on_the_real_source(self):
        original = load(codec.CONFIG)
        changed = deepcopy(original)
        changed["owners"][0]["declarations"]["phases"][0] = "$FF0010"
        with patch.object(codec, "load", return_value=changed), self.assertRaisesRegex(ValueError, "contract differs"):
            codec.check()

    def test_missing_owner_or_profile_symbol_cannot_weaken_the_witness(self):
        original = load(codec.CONFIG)
        missing_owner = deepcopy(original)
        missing_owner["owners"].pop()
        missing_symbol = deepcopy(original)
        missing_symbol["owners"][0]["symbols"]["rev00"].pop("v_ram_start")
        for changed in (missing_owner, missing_symbol):
            with (
                self.subTest(changed=changed),
                patch.object(codec, "load", return_value=changed),
                self.assertRaises(ValueError),
            ):
                codec.check()

    def test_ram_rejects_cpu_code_initialized_storage_and_hidden_includes(self):
        template = "phase $FF0000\nField: ds.w 1\n{}\ndephase\n!org 0\n"
        codec.memory_model(template.format(""))
        for body in ("nop", "dc.w 0", "ds.w 1,0", 'include "hidden.s"', "phase $FF1000", "cpu 68000"):
            with self.subTest(body=body), self.assertRaises(ValueError):
                codec.memory_model(template.format(body))

    def test_ram_rejects_unclosed_structures_conditions_and_phases(self):
        for text in ("phase $FF0000\nField: ds.w 1", "S struct DOTS\nField: ds.b 1", "if Revision=0\n", "else\n"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                codec.memory_model(text)

    def test_ram_struct_fields_have_qualified_identities(self):
        model = codec.memory_model("S struct DOTS\nField: ds.b 1\nendstruct\n")
        self.assertEqual(model["names"], ["S.Field", "S.len"])

    def test_an_unreviewed_primitive_override_is_rejected(self):
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory(dir=ROOT / "build") as folder:
            path = Path(folder) / "override.inc"
            path.write_text("ds macro\n dc.b 0\n endm\n")
            with (
                patch.object(codec, "source_paths", return_value=[path.relative_to(ROOT)]),
                self.assertRaisesRegex(ValueError, "redefinition"),
            ):
                codec.check()

    def test_z80_rejects_instruction_and_cursor_context_changes(self):
        valid = "save\n!org 0\ncpu Z80\nnop\nrestore\npadding off\n!org (DACDriver+Size_of_DAC_driver_guess)\n"
        codec.z80_model(valid)
        for text in (
            valid.replace("nop", "move.w d0,d1"),
            valid.replace("cpu Z80", "cpu 68000"),
            valid.replace("restore\n", ""),
            valid.replace("!org 0", "!org $100"),
            valid + "nop\n",
        ):
            with self.subTest(text=text), self.assertRaises(ValueError):
                codec.z80_model(text)

    def test_listing_witness_preserves_struct_names_and_normalizes_ram_width(self):
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory(dir=ROOT / "build") as folder:
            path = Path(folder) / "fixture.lst"
            path.write_text(" Field : FFFFFFFFFFFF1234 C | S.Field : 8 - |\n")
            self.assertEqual(codec.listing_symbols(path), {"Field": 0xFF1234, "S.Field": 8})
            path.write_text(" Field : 10 - |\n Field : 12 - |\n")
            with self.assertRaisesRegex(ValueError, "Conflicting"):
                codec.listing_symbols(path)
