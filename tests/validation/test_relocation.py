import unittest
from scripts.validation.relocation import duplicate_returns, replace_padding


class RelocationTests(unittest.TestCase):
    def test_global_procedure_tail_is_padded_but_local_continuation_is_not(self):
        source = "Main:\n rts\n.local:\n rts\nNext:\n rte\n"
        rewritten, inserted, kept = duplicate_returns(source)
        self.assertEqual(len(inserted), 2)
        self.assertEqual(len(kept), 1)
        self.assertIn("rte ; unreachable relocation probe word", rewritten)
        self.assertEqual(rewritten.count("unreachable relocation probe word"), 2)

    def test_pc_indexed_instruction_table_keeps_its_slot_width(self):
        source = "Table:\n rts\n bra.w Target\nTarget:\n rts\n"
        rewritten, inserted, kept = duplicate_returns(source)
        self.assertIn("Table:\n rts\n bra.w Target", rewritten)
        self.assertEqual(len(kept), 1)
        self.assertEqual(len(inserted), 1)

    def test_padding_requires_one_declared_reservoir(self):
        self.assertIn("($40-2)", replace_padding(" dcb.b $40,$FF\n", "$40", "($40-2)"))
        for text in ("", " dcb.b $40,$FF\n dcb.b $40,$FF\n"):
            with self.assertRaises(ValueError):
                replace_padding(text, "$40", "0")
