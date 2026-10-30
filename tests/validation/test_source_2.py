"""Drafts, weakened inheritance and missing corpus cannot become releases."""

from copy import deepcopy
import unittest
from scripts.build.project import load
from scripts.validation.source_2 import manifest, scaffold


class SourceContentContracts(unittest.TestCase):
    def test_scaffold_checks_public_source_content_and_docs_without_roms(self):
        spec, catalog = scaffold()
        self.assertEqual(spec["release_line"], "2.0")
        self.assertGreater(len(catalog.items), 1000)

    def test_weaker_preservation_inheritance_or_missing_topics_are_rejected(self):
        original = load("config/source_reconstruction_2_0.json")
        for name, value in (
            ("release_commands", ["scaffold-check"]),
            ("required_documents", []),
            ("predecessor", {}),
            ("release_kind", "compatible_minor"),
        ):
            spec = deepcopy(original)
            spec[name] = value
            with self.subTest(field=name), self.assertRaises(ValueError):
                manifest(spec)

    def test_draft_or_unbound_predecessor_cannot_pass_final_audit(self):
        original = load("config/source_reconstruction_2_0.json")
        if original["status"] == "draft":
            with self.assertRaisesRegex(ValueError, "draft"):
                manifest(original, ready=True)
        spec = deepcopy(original)
        spec["status"] = "tag-ready"
        spec["predecessor"]["commit"] = None
        with self.assertRaisesRegex(ValueError, "predecessor commit"):
            manifest(spec, ready=True)

    def test_current_metadata_commit_is_mapped_without_a_hash_self_reference(self):
        from unittest.mock import patch
        from scripts.validation import release_audit

        spec = deepcopy(load("config/source_reconstruction_2_0.json"))
        base = "1" * 40
        head = "2" * 40
        spec["status"] = "tag-ready"
        spec["predecessor"]["commit"] = base
        spec["delta_history"] = dict(base_commit=base, tip="release-commit", commit_count=1)
        for row in spec["delta"]:
            row["commits"] = []
        spec["delta"][-1]["commits"] = ["release-commit"]

        def git(*args):
            if args[0] == "merge-base":
                return base
            if args[0] == "rev-list":
                return head
            if args == ("rev-parse", "HEAD"):
                return head
            raise AssertionError(args)

        with patch.object(release_audit, "git", side_effect=git):
            manifest(spec, ready=True)
            spec["delta"][0]["commits"] = [head]
            with self.assertRaisesRegex(ValueError, "exactly once"):
                manifest(spec, ready=True)

    def test_source_origin_requires_the_accepted_commit_content_and_lines(self):
        from pathlib import Path
        from unittest.mock import patch
        from scripts.validation import source_layout
        from scripts.build.project import sha256

        raw = b"Synthetic preservation procedure\n"
        base = "1" * 40
        spec = dict(
            preservation_baseline_commit=base,
            modules=[
                dict(
                    origin=dict(
                        kind="preserved_span", path="original.asm", lines=[1, 1], preservation_source_sha256=sha256(raw)
                    )
                )
            ],
        )
        with patch.object(source_layout.subprocess, "check_output", return_value=raw):
            source_layout.origins(base, spec)
            spec["modules"][0]["origin"]["lines"] = [1, 2]
            with self.assertRaisesRegex(ValueError, "origin"):
                source_layout.origins(base, spec)
            spec["preservation_baseline_commit"] = "2" * 40
            with self.assertRaisesRegex(ValueError, "predecessor"):
                source_layout.origins(base, spec)

    def test_predecessor_snapshot_must_have_the_complete_preservation_contract(self):
        from scripts.validation.source_2 import predecessor_contract

        original = load("config/source_reconstruction_1_0.json")
        predecessor_contract(original)
        for key, value in (
            ("release_commands", ["lint"]),
            ("requirements", {}),
            ("profiles", []),
            ("release_line", "2.0"),
        ):
            spec = deepcopy(original)
            spec[key] = value
            with self.subTest(field=key), self.assertRaises(ValueError):
                predecessor_contract(spec)
        spec = deepcopy(original)
        spec["artifacts"][0]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "identity"):
            predecessor_contract(spec)
