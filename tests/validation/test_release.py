from copy import deepcopy
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from scripts.build.project import ROOT, load
from scripts.runtime.matrix import validate as validate_matrix
from scripts.validation.release import STEPS
from scripts.validation.release_audit import validate_manifest


class ReleaseContracts(unittest.TestCase):
    def test_missing_profile_or_weaker_runtime_coverage_is_rejected(self):
        original = load("scenarios/runtime_matrix.json")
        validate_matrix(original)
        cases = []
        spec = deepcopy(original)
        spec["profiles"].pop()
        cases.append(spec)
        spec = deepcopy(original)
        spec["profiles"][0]["scenarios"].pop()
        cases.append(spec)
        spec = deepcopy(original)
        spec["profiles"].append(spec["profiles"][0])
        cases.append(spec)
        spec = deepcopy(original)
        spec["scenarios"][0]["setup"]["ram_patches"] = [{"address": "0xfff600", "value": 8}]
        cases.append(spec)
        for value in cases:
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_matrix(value)

    def test_manifest_facts_and_evidence_cannot_drift(self):
        original = load("config/source_reconstruction_1_0.json")
        validate_manifest(original)
        cases = []
        for key, value in (("release_kind", "baseline"), ("predecessor", {}), ("required_documents", [])):
            spec = deepcopy(original)
            spec[key] = value
            cases.append(spec)
        spec = deepcopy(original)
        spec["artifacts"][0]["sha256"] = "0" * 64
        cases.append(spec)
        spec = deepcopy(original)
        spec["requirements"]["canonical_identity"]["evidence"]["targets"] = ["invented-command"]
        cases.append(spec)
        spec = deepcopy(original)
        spec["profiles"][0]["entrypoint"] = "unrelated.asm"
        cases.append(spec)
        for value in cases:
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_manifest(value)
        self.assertEqual(list(STEPS), original["release_commands"])


@unittest.skipUnless(
    os.environ.get("RUN_RELEASE_SMOKE") == "1",
    "Opt-in full clean-clone gate needs RUN_RELEASE_SMOKE=1 and private ROM_DIR",
)
class PublicReleaseSmoke(unittest.TestCase):
    def test_public_release_command_from_fresh_clone(self):
        directory = os.environ.get("ROM_DIR")
        self.assertTrue(directory, "ROM_DIR is required by the opted-in integration test")
        with tempfile.TemporaryDirectory(prefix="release-smoke-", dir=ROOT / "build") as folder:
            clone = Path(folder) / "source"
            log = ROOT / "build/release-smoke.log"
            environment = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
            environment.pop("RUN_RELEASE_SMOKE", None)
            with log.open("wb") as stream:
                subprocess.run(
                    ["git", "clone", "--no-local", str(ROOT), str(clone)],
                    check=True,
                    stdout=stream,
                    stderr=subprocess.STDOUT,
                )
                subprocess.run(
                    ["git", "remote", "remove", "origin"],
                    cwd=clone,
                    check=True,
                    stdout=stream,
                    stderr=subprocess.STDOUT,
                )
                result = subprocess.run(
                    ["make", "release-check", f"ROM_DIR={Path(directory).resolve()}"],
                    cwd=clone,
                    env=environment,
                    stdout=stream,
                    stderr=subprocess.STDOUT,
                )
            self.assertEqual(result.returncode, 0, log.read_text(errors="replace")[-6000:])
            import json

            evidence = json.loads((clone / "build/release/preservation.json").read_text())
            self.assertTrue(evidence["passed"])
            self.assertEqual(evidence["steps"], list(STEPS))


class HistoryBoundaryContracts(unittest.TestCase):
    def test_real_git_history_audit_rejects_empty_commits(self):
        from unittest.mock import patch
        from scripts.validation import release_audit

        with tempfile.TemporaryDirectory(prefix="history-contract-", dir=ROOT / "build") as folder:
            repo = Path(folder)

            def invoke(*arguments):
                return subprocess.run(["git", *arguments], cwd=repo, check=True, capture_output=True)

            invoke("init", "-b", "main")
            invoke("config", "user.name", "Daniel Oranguthang")
            invoke("config", "user.email", "75395800+oranguthang@users.noreply.github.com")
            (repo / "fixture.txt").write_text("Synthetic history fixture.\n")
            invoke("add", "fixture.txt")
            message = "Record a synthetic history fixture\n\nExercise actual Git objects in the history audit.\n\nKeep the fixture independent of private ROMs and public history.\n\nCo-Authored-By: Codex <noreply@openai.com>"
            invoke("commit", "-m", message)
            with patch.object(release_audit, "ROOT", repo):
                self.assertEqual(release_audit.history(), 1)
            invoke(
                "commit",
                "--allow-empty",
                "-m",
                message.replace("Record a synthetic history fixture", "Insert an intentionally empty fixture commit"),
            )
            with patch.object(release_audit, "ROOT", repo), self.assertRaisesRegex(ValueError, "Empty commit"):
                release_audit.history()

    def test_private_sound_content_is_not_accepted_as_driver_declarations(self):
        source = "\n".join(path.read_text() for path in (ROOT / "src/audio").rglob("*.asm"))
        import re

        self.assertIsNone(re.search(r"^PSG[1-9]:?\s+dc\.b\b", source, re.M | re.I))
        tracked = subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True).splitlines()
        self.assertFalse(any(path.startswith(("sound/music/", "sound/sfx/")) for path in tracked))
