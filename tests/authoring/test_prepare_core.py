"""Reject archive escapes and drift in the cached pinned Core snapshot."""

import io
from pathlib import Path
import tarfile
import tempfile
import unittest

from scripts.authoring.prepare_core import source_files, stage_snapshot
from scripts.build.project import ROOT


def archive(name="CMakeLists.txt", kind=tarfile.REGTYPE):
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode="w") as stream:
        member = tarfile.TarInfo(name)
        member.type = kind
        member.size = 0
        stream.addfile(member, io.BytesIO())
    return output.getvalue()


class PrepareCoreTests(unittest.TestCase):
    def test_snapshot_requires_a_build_entry_and_rejects_links_and_path_escapes(self):
        self.assertEqual(source_files(archive()), {"CMakeLists.txt": b""})
        for payload in (
            archive("../outside"),
            archive("/absolute"),
            archive("CMakeLists.txt", tarfile.SYMTYPE),
            archive("other.txt"),
        ):
            with self.subTest(payload=payload[:80]), self.assertRaises(ValueError):
                source_files(payload)

    def test_repeat_staging_is_safe_and_changed_or_extra_cache_files_fail(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as folder:
            destination = Path(folder) / "source"
            files = {"CMakeLists.txt": b"source pin", "src/main.cpp": b"int main() {}"}
            stage_snapshot(files, destination)
            stage_snapshot(files, destination)
            (destination / "src/main.cpp").write_bytes(b"changed")
            with self.assertRaisesRegex(ValueError, "differs"):
                stage_snapshot(files, destination)
            (destination / "src/main.cpp").write_bytes(files["src/main.cpp"])
            (destination / "unknown.cpp").write_bytes(b"extra")
            with self.assertRaisesRegex(ValueError, "unexpected"):
                stage_snapshot(files, destination)
