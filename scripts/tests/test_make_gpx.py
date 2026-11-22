"""Unit tests for tools/make-gpx.py (#245)."""

import importlib.util
import os
import tempfile
import unittest
from datetime import timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("make_gpx", ROOT / "tools" / "make-gpx.py")
make_gpx = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(make_gpx)

TEE = {"latitude": 42.0, "longitude": -71.0}
APPROACH = {"latitude": 42.001, "longitude": -71.0}
GREEN = {"latitude": 42.002, "longitude": -71.0}
COURSE = {
    "coordinate": {"latitude": 42.5, "longitude": -71.5},
    "holes": [
        {"number": 1, "teeBoxes": {"white": TEE, "red": APPROACH}, "approachShots": [APPROACH],
         "greenCoordinates": {"center": GREEN}},
        {"number": 2, "teeBoxes": {"white": APPROACH}, "approachShots": [], "greenCoordinates": {"center": GREEN}},
    ],
}


class MakeGPXTests(unittest.TestCase):
    def test_distance(self):
        # 0.001° of latitude is about 111 m.
        self.assertAlmostEqual(make_gpx.metres(TEE, APPROACH), 111.2, delta=0.1)

    def test_a_walk_reaches_each_point_at_walking_pace(self):
        times = [time for _, time in make_gpx.walk([TEE, APPROACH, GREEN])]
        leg = make_gpx.metres(TEE, APPROACH) / make_gpx.WALK_SPEED  # about 79 s; times round the total, not each leg
        self.assertEqual(times, [make_gpx.START, make_gpx.START + timedelta(seconds=round(leg)),
                                 make_gpx.START + timedelta(seconds=round(2 * leg))])

    def test_a_course_coordinate_and_three_files_a_hole(self):
        files = make_gpx.files(COURSE, "white")
        self.assertEqual(sorted(files), ["Course.gpx", "Hole 1 Green.gpx", "Hole 1 Tee.gpx", "Hole 1 Walk.gpx",
                                         "Hole 2 Green.gpx", "Hole 2 Tee.gpx", "Hole 2 Walk.gpx"])
        self.assertIn('<wpt lat="42.5000000" lon="-71.5000000">', files["Course.gpx"])
        self.assertNotIn("<time>", files["Hole 1 Tee.gpx"])
        walk = files["Hole 1 Walk.gpx"]
        self.assertEqual(walk.count("<wpt "), 3)  # tee, approach, green
        self.assertEqual(walk.count("<time>"), 3)
        self.assertEqual(files["Hole 2 Walk.gpx"].count("<wpt "), 2)  # no approach shot

    def test_the_tee_and_walk_start_from_the_white_tee(self):
        files = make_gpx.files(COURSE)
        self.assertIn('lat="42.0000000"', files["Hole 1 Tee.gpx"])
        self.assertTrue(files["Hole 1 Walk.gpx"].split("<wpt ")[1].startswith('lat="42.0000000"'))

    def test_a_course_without_white_tees_is_an_error(self):
        course = {**COURSE, "holes": [{**COURSE["holes"][0], "teeBoxes": {"red": TEE}}]}
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "course.json"
            path.write_text(__import__("json").dumps(course))
            with open(os.devnull, "w") as quiet, _redirect(quiet), self.assertRaises(SystemExit):
                make_gpx.main(["--course", str(path), "--output", folder])

    def test_check_finds_missing_stale_and_extra_files(self):
        with tempfile.TemporaryDirectory() as folder:
            course = Path(folder) / "course.json"
            course.write_text(__import__("json").dumps(COURSE))
            output = Path(folder) / "Simulation"
            args = ["--course", str(course), "--output", str(output)]
            with open(os.devnull, "w") as quiet, _redirect(quiet):
                self.assertEqual(make_gpx.main(args + ["--check"]), 1)  # nothing written yet
                self.assertEqual(make_gpx.main(args), 0)
                self.assertEqual(make_gpx.main(args + ["--check"]), 0)
                (output / "Hole 1 Tee.gpx").write_text("edited")
                self.assertEqual(make_gpx.main(args + ["--check"]), 1)
                make_gpx.main(args)
                (output / "Hole 9 Tee.gpx").write_text("old")
                self.assertEqual(make_gpx.main(args + ["--check"]), 1)
                make_gpx.main(args)  # removes the extra file
                self.assertFalse((output / "Hole 9 Tee.gpx").exists())

    def test_the_committed_files_match_the_course_data(self):
        with open(os.devnull, "w") as quiet, _redirect(quiet):
            self.assertEqual(make_gpx.main(["--check"]), 0, "run python3 tools/make-gpx.py and commit Simulation/")

    def test_every_simulation_file_is_in_the_xcode_project(self):
        # A file on disk but not in the Simulation group never shows in Xcode's Simulate Location menu.
        project = (ROOT / "MaynardGolf.xcodeproj" / "project.pbxproj").read_text()
        missing = [path.name for path in (ROOT / "Simulation").iterdir()
                   if path.suffix in {".gpx", ".md"} and f'path = "{path.name}";' not in project]
        self.assertEqual(missing, [], "add these to the Simulation group (no target)")


def _redirect(stream):
    import contextlib

    class Both(contextlib.ExitStack):
        def __enter__(self):
            super().__enter__()
            self.enter_context(contextlib.redirect_stdout(stream))
            self.enter_context(contextlib.redirect_stderr(stream))
            return self
    return Both()


if __name__ == "__main__":
    unittest.main()
