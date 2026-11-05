"""Require real controller setup and ordered Special Stage entry and return."""

from copy import deepcopy
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from scripts.build.project import ROOT, load
from scripts.runtime import movies
from scripts.runtime.matrix import validate
from scripts.runtime.movies import controller_movie, validate_check


class ExtendedRouteTests(unittest.TestCase):
    def test_unrelated_mame_starting_after_our_completed_run_is_not_our_leak(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as folder:
            root = Path(folder)
            mame = root / "build/emulator/consoles.exe"
            mame.parent.mkdir(parents=True)
            mame.write_bytes(b"synthetic executable fixture")
            runner = SimpleNamespace(pid=30, returncode=0, wait=lambda **kwargs: 0)
            unrelated = [{"ProcessId": 11, "Created": "other-time", "Ancestors": [99]}]
            with (
                patch.object(movies, "checked_path", side_effect=lambda name: root / name),
                patch.object(movies, "processes", side_effect=[[], [], unrelated]),
                patch.object(movies.subprocess, "Popen", return_value=runner),
                patch.object(movies.subprocess, "run") as terminate,
            ):
                movies.invoke("check", root / "fixture.bin", root / "fixture.json", mame, root / "run.log")
                terminate.assert_not_called()

    def test_special_stage_movie_has_exact_duration_and_original_menu_inputs(self):
        for profile in ("rev00", "rev01", "revxb"):
            movie = controller_movie(profile, dict(id="special-stage", frames=8000)).decode()
            rows = [line.split() for line in movie.split("---\n", 1)[1].splitlines()]
            self.assertEqual(sum(int(row[0]) for row in rows), 8000)
            self.assertTrue(all(row[2] == "00" for row in rows))
            self.assertIn(["1", "C0", "00"], rows)
        with self.assertRaisesRegex(ValueError, "duration"):
            controller_movie("rev01", dict(id="special-stage", frames=100))
        with self.assertRaisesRegex(ValueError, "Unknown"):
            controller_movie("rev01", dict(id="unknown", frames=8000))

    def test_matrix_requires_the_special_stage_transition_for_every_profile(self):
        matrix = load("scenarios/runtime_matrix.json")
        validate(matrix)
        changed = deepcopy(matrix)
        changed["profiles"][0]["scenarios"].pop()
        with self.assertRaises(ValueError):
            validate(changed)
        changed = deepcopy(matrix)
        changed["scenarios"][-1]["required_sequence"] = []
        with self.assertRaisesRegex(ValueError, "ordered"):
            validate(changed)

    def test_reversed_reached_states_do_not_prove_a_transition(self):
        scenario = dict(
            machine="genesis",
            frames=120,
            checkpoint_step=60,
            cells=["mode"],
            required_states=[{"mode": 8}],
            required_sequence=[{"mode": 4}, {"mode": 8}],
        )
        spec = dict(
            schema="retrolarium.movie-check",
            schema_version=1,
            machine="genesis",
            frames=[60, "end"],
            cells={"mode": {"address": "0xfff600", "length": 1}},
            expected={"60": {"mode": "04"}, "end": {"mode": "08"}},
        )
        validate_check(spec, scenario)
        scenario["required_sequence"].reverse()
        with self.assertRaisesRegex(ValueError, "ordered"):
            validate_check(spec, scenario)
