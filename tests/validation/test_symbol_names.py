"""Address names must fail even when all pointer operands are symbolic."""

from copy import deepcopy
import unittest
from scripts.validation.symbol_names import audit
from scripts.validation.symbolic_pointers import audit as pointer_audit


class SymbolNameTests(unittest.TestCase):
    def test_generated_definitions_references_and_local_names_are_rejected(self):
        for name in (
            "loc_1234",
            "BRA_ABCD",
            "sub_1234",
            "locret_71E48",
            ".locret_1234",
            "unk_1234",
            "byte_1234",
            "word_1234",
            "dword_1234",
            "off_1234",
            "zloc_1234",
            "nullsub_1234",
            "jpt_1234",
            "locret_1234.w",
        ):
            for source in (name + ":\n rts\n", " bra.w " + name + "\n", "Alias equ " + name + "\n"):
                with self.subTest(name=name, source=source), self.assertRaisesRegex(ValueError, "Address-generated"):
                    audit({"fixture.s": source})

    def test_comments_strings_and_semantic_local_returns_remain_legal(self):
        source = (
            "; locret_1234: old upstream location\n"
            "Return:\n rts ; sub_1234\n"
            " dc.b \"loc_1234; sub_5678\",'off_1234'\n"
            r' dc.b "escaped \" loc_1234","another \" off_1234"' + "\n"
            " .locret:\n bra.s .locret\n"
            "Hud_1000:\n bgm_Fade equ 1\n"
        )
        self.assertEqual(audit({"fixture.s": source})["address_name_findings"], [])

    def test_inherited_pointer_audit_rejects_a_symbolic_but_address_named_target(self):
        with self.assertRaisesRegex(ValueError, "Address-generated"):
            pointer_audit(
                {"fixture.s": " bra.s locret_1234\nlocret_1234:\n rts\n"},
                {"classified_literals": [], "fixed_regions": []},
            )

    def test_registry_requires_unique_live_definitions_and_completed_renames(self):
        sources = {"fixture.s": "; OldReturn: upstream name\nTrackReturn:\n rts\n"}
        registry = dict(
            schema_version=1,
            baseline=dict(repository="example/source", commit="1" * 40),
            renames=[dict(old="OldReturn", new="TrackReturn", path="fixture.s", reason="Track return")],
            project_additions=[],
        )
        self.assertEqual(audit(sources, registry)["registered_renames"], 1)
        mutations = []
        for key, value in [("new", "Missing"), ("path", "other.s"), ("reason", ""), ("old", "TrackReturn")]:
            changed = deepcopy(registry)
            changed["renames"][0][key] = value
            mutations.append(changed)
        changed = deepcopy(registry)
        changed["renames"] *= 2
        mutations.append(changed)
        changed = deepcopy(registry)
        del changed["renames"]
        mutations.append(changed)
        for changed in mutations:
            with self.subTest(registry=changed), self.assertRaises(ValueError):
                audit(sources, changed)
        for changed in (
            {"fixture.s": sources["fixture.s"] + " bra.w OldReturn\n"},
            {"fixture.s": sources["fixture.s"] + "TrackReturn:\n rts\n"},
            {**sources, "other.s": "TrackReturn:\n rts\n"},
        ):
            with self.subTest(sources=changed), self.assertRaises(ValueError):
                audit(changed, registry)
