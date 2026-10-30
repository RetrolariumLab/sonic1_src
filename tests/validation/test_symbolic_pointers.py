import unittest
from scripts.validation.symbolic_pointers import audit, candidates, raw_equates


class SymbolicPointerTests(unittest.TestCase):
    def test_address_literals_and_aliases_are_not_mistaken_for_symbolic_pointers(self):
        source = "Raw equ $1234\nAlias equ Raw\n lea Raw(pc,d0.w),a0\n jmp Alias\n jsr ($2000).l\n smpsCall $3000\n dc.l $4000\n"
        aliases = raw_equates({"fixture.asm": source})
        found = candidates(source, aliases)
        self.assertEqual(len(found), 5)

    def test_label_expressions_and_register_displacements_remain_symbolic(self):
        source = " lea Table(pc,d0.w),a0\n lea $10(a1),a1\n jmp Handler\n dc.l Table+4\n smpsLoop $00,$10,MusicLoop\n"
        self.assertEqual(candidates(source, {}), [])

    def test_numeric_pc_relative_displacement_is_a_pointer_candidate(self):
        self.assertEqual(len(candidates(" lea $1234(pc,d0.w),a0\n", {})), 1)

    def test_scalar_classification_cannot_cover_another_owner_or_go_stale(self):
        policy = {
            "classified_literals": [
                {"owners": ["math.asm"], "statement": "movea.w #$10,a3", "kind": "scalar", "reason": "Tile height"}
            ],
            "fixed_regions": [],
        }
        report = audit({"math.asm": " movea.w #$10,a3\n"}, policy)
        self.assertEqual(report["raw_pointer_findings"], [])
        for sources in ({"other.asm": " movea.w #$10,a3\n"}, {"math.asm": " rts\n"}):
            with self.assertRaises(ValueError):
                audit(sources, policy)
