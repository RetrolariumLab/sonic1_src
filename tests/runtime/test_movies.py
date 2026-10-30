from copy import deepcopy
import unittest
from scripts.runtime.movies import controller_movie, validate_check


class MovieContracts(unittest.TestCase):
    def fixture(self):
        scenario = {
            "id": "attract",
            "machine": "genesis",
            "frames": 120,
            "checkpoint_step": 60,
            "cells": ["mode", "zone"],
            "required_states": [{"mode": 8, "zone": 0}],
        }
        spec = {
            "schema": "retrolarium.movie-check",
            "schema_version": 1,
            "machine": "genesis",
            "frames": [60, "end"],
            "cells": {"mode": {"address": "0xfff600", "length": 1}, "zone": {"address": "0xfffe10", "length": 1}},
            "expected": {"60": {"mode": "04", "zone": "00"}, "end": {"mode": "08", "zone": "00"}},
        }
        return spec, scenario

    def test_missing_trace_data_or_unreached_scenes_cannot_pass(self):
        original, scenario = self.fixture()
        validate_check(original, scenario)
        cases = []
        value = deepcopy(original)
        del value["expected"]["60"]
        cases.append(value)
        value = deepcopy(original)
        del value["expected"]["end"]["zone"]
        cases.append(value)
        value = deepcopy(original)
        value["expected"]["end"]["mode"] = "04"
        cases.append(value)
        value = deepcopy(original)
        value["expected"]["end"]["mode"] = "0008"
        cases.append(value)
        value = deepcopy(original)
        value["cells"]["mode"]["tolerance"] = 100
        cases.append(value)
        for spec in cases:
            with self.subTest(spec=spec), self.assertRaises(ValueError):
                validate_check(spec, scenario)

    def test_attract_movie_is_no_input_and_ending_setup_uses_only_controller_frames(self):
        for profile_id in ("rev00", "rev01", "revxb"):
            for name, duration in (("attract", 15000), ("ending", 18000)):
                data = controller_movie(profile_id, {"id": name, "frames": duration}).decode()
                rows = [line.split() for line in data.split("---\n", 1)[1].splitlines()]
                self.assertEqual(sum(int(row[0]) for row in rows), duration)
                self.assertTrue(all(len(row) == 3 and row[2] == "00" for row in rows))
                if name == "attract":
                    self.assertTrue(all(row[1] == "00" for row in rows))
                else:
                    self.assertTrue(any(int(row[1], 16) for row in rows))


class EmulatorIsolationTests(unittest.TestCase):
    def test_checked_binary_is_staged_without_executing_or_writing_to_its_source(self):
        from pathlib import Path
        import tempfile
        from unittest.mock import patch
        from scripts.build.project import ROOT, sha256
        from scripts.runtime import movies

        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="emulator-stage-test-") as folder:
            root = Path(folder)
            native = root / "external/consoles.exe"
            native.parent.mkdir()
            payload = b"synthetic non-executable fixture"
            native.write_bytes(payload)
            marker = native.parent / "existing.cfg"
            marker.write_bytes(b"keep")
            expected = sha256(payload)
            with (
                patch.object(movies, "load", return_value={"emulator": {"sha256": expected}}),
                patch.object(movies, "processes", return_value=[]),
                patch.object(movies, "checked_path", side_effect=lambda name: root / name),
            ):
                staged = movies.emulator(native)
            self.assertEqual(staged.read_bytes(), payload)
            self.assertEqual(staged, root / "build/emulator/consoles.exe")
            self.assertEqual(marker.read_bytes(), b"keep")


class ProcessOwnershipTests(unittest.TestCase):
    def test_ownership_survives_hidden_command_lines_and_parent_exit(self):
        from scripts.runtime.movies import remember_owned, owned_leftovers

        owned = {}
        rows = [{"ProcessId": 10, "Created": "time-one", "Ancestors": [20, 30]}]
        remember_owned(rows, 30, owned)
        orphan = [{"ProcessId": 10, "Created": "time-one", "Ancestors": [20]}]
        self.assertEqual(owned_leftovers(orphan, owned), orphan)
        reused = [{"ProcessId": 10, "Created": "time-two", "Ancestors": [99]}]
        self.assertEqual(owned_leftovers(reused, owned), [])
        unrelated = [{"ProcessId": 11, "Created": "time-one", "Ancestors": [99]}]
        self.assertEqual(owned_leftovers(unrelated, owned), [])
