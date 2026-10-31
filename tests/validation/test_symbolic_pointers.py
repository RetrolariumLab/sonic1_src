import unittest
from scripts.validation.symbolic_pointers import audit, candidates, raw_equates


class SymbolicPointerTests(unittest.TestCase):
    def test_absolute_memory_and_stack_pointer_forms_fail_the_full_audit(self):
        policy = {"classified_literals": [], "fixed_regions": []}
        for source in (
            " move.w ($1234).w,d0",
            " move.w d0,($1234).l",
            " tst.b $1234",
            " movea.l #$1234,sp",
            " move.l #$1234,a7",
            " lea.l $1234,a0",
            "Raw equ $1234+0\n jsr Raw",
            "Head equ Tail+4\nTail equ 1230h\n move.w (Head).l,d0",
            "Raw equ $1234\nRaw equ $5678\nAlias equ Raw+4\n jsr Alias",
            " jp nz,$1234",
            " call z,$1234",
        ):
            with self.subTest(source=source), self.assertRaises(ValueError):
                audit({"fixture.s": source}, policy)

    def test_numeric_expressions_resolve_without_executing_or_inventing_label_values(self):
        source = "Raw equ ($1200 | %110100)\nAlias equ Raw+0\nLabelAlias equ Table+4\nLoop equ Loop\nBad equ 1/0\n"
        aliases = raw_equates({"fixture.s": source})
        self.assertEqual(int(aliases["alias"]), 0x1234)
        self.assertNotIn("labelalias", aliases)
        self.assertNotIn("loop", aliases)
        self.assertNotIn("bad", aliases)
        self.assertEqual(candidates(" jsr LabelAlias", aliases), [])

    def test_memory_register_displacements_and_named_hardware_are_not_rom_literals(self):
        source = "HW equ $C00004\n move.w (HW).l,d0\n move.w $10(a0,d0.w),d1\n move.w d1,(a2)+\n movea.l #Stack,sp\n"
        self.assertEqual(candidates(source, raw_equates({"fixture.s": source})), [])

    def test_z80_immediates_are_not_68000_absolute_memory_operands(self):
        source = " save\n cpu z80\n sub 81h\n and 0Fh\n restore\n move.w ($1234).w,d0\n"
        found = candidates(source, {})
        self.assertEqual(len(found), 1)
        self.assertIn("absolute memory", found[0]["reason"])

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
