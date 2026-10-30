import os
import subprocess
import tempfile
from pathlib import Path
import unittest
from scripts.build.project import ROOT, sha1, sha256
from scripts.validation.private_data import audit_history, check_payload


class PrivateDataTests(unittest.TestCase):
    def test_disguised_ascii_asset_is_rejected_by_content(self):
        with self.assertRaisesRegex(ValueError, "private manifest asset"):
            check_payload("notes.txt", b"synthetic payload", {sha1(b"synthetic payload")}, {})

    def test_binaries_require_an_exact_allowlist_and_assets_cannot_be_allowed(self):
        raw = bytes([0, 1, 2])
        with self.assertRaisesRegex(ValueError, "allowlisted"):
            check_payload("tool.bin", raw, set(), {})
        check_payload("tool.bin", raw, set(), {"tool.bin": sha256(raw)})
        with self.assertRaisesRegex(ValueError, "private manifest asset"):
            check_payload("tool.bin", raw, {sha1(raw)}, {"tool.bin": sha256(raw)})

    def test_deleted_private_blob_remains_a_history_violation(self):
        (ROOT / "build").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="audit-test-") as directory:
            root = Path(directory)

            def git(*args):
                return subprocess.check_output(["git", "-C", directory, *args], stderr=subprocess.STDOUT)

            git("init", "-b", "main")
            git("config", "user.name", "Daniel Oranguthang")
            git("config", "user.email", "75395800+oranguthang@users.noreply.github.com")
            raw = b"synthetic private fixture"
            (root / "notes.txt").write_bytes(raw)
            git("add", "notes.txt")
            git("commit", "-m", "Add synthetic fixture")
            git("rm", "notes.txt")
            git("commit", "-m", "Remove synthetic fixture")
            with self.assertRaisesRegex(ValueError, "private manifest asset"):
                audit_history(root, {sha1(raw)}, {})
