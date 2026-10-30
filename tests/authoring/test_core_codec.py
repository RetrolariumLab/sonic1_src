"""Exercise the real pinned CLI on a synthetic Nemesis stream and reject drift."""

from pathlib import Path
import tempfile
import unittest
from scripts.authoring import core_codec
from scripts.build.project import ROOT


class CoreCodecTests(unittest.TestCase):
    def setUp(self):
        try:
            self.tool = core_codec.resolve()
        except (OSError, ValueError):
            self.skipTest("Pinned Core CLI is unavailable on this host; the full content gate requires it")

    def test_synthetic_inline_patterns_roundtrip_through_the_real_core(self):
        bits = ("111111" + "111" + "0000") * 8
        stream = bytes.fromhex("0001ff") + int(bits, 2).to_bytes(len(bits) // 8, "big")
        plain = core_codec.decode(stream)
        self.assertEqual(plain, bytes(32))
        encoded = core_codec.encode(plain, stream)
        self.assertEqual(core_codec.decode(encoded), plain)

    def test_changed_executable_is_rejected_before_execution(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="core-hash-test-") as directory:
            path = Path(directory) / "changed.exe"
            path.write_bytes(self.tool.read_bytes() + b"x")
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                core_codec.resolve(path)

    def test_transient_windows_directory_lock_is_retried_and_cleaned(self):
        from unittest.mock import patch
        from scripts.authoring import core_codec

        original = core_codec.shutil.rmtree
        attempts = []

        def remove(path):
            attempts.append(path)
            if len(attempts) == 1:
                raise OSError("Transient Windows directory lock")
            return original(path)

        directory = ROOT / "build/tmp"
        directory.mkdir(parents=True, exist_ok=True)
        with patch.object(core_codec.shutil, "rmtree", side_effect=remove):
            with core_codec.scratch(directory) as temporary:
                target = temporary
                (temporary / "synthetic.txt").write_text("Synthetic fixture")
        self.assertFalse(target.exists())
        self.assertEqual(len(attempts), 2)
