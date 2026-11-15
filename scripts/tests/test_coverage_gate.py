"""Unit tests for scripts/coverage_gate.py over fixture xccov reports (#97)."""

import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import coverage_gate  # noqa: E402

FIXTURES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")


def fixture(name):
    return os.path.join(FIXTURES, name)


def run(report, *extra):
    out = io.StringIO()
    with redirect_stdout(out):
        code = coverage_gate.main([fixture(report), "--config", fixture("coverage-config.json"), "--root", "/repo", *extra])
    return code, out.getvalue()


class CoverageGateTests(unittest.TestCase):
    def test_passes_when_every_group_meets_its_minimum(self):
        code, out = run("xccov-pass.json")
        self.assertEqual(code, coverage_gate.EXIT_PASS)
        self.assertIn("pass v2 app code", out)
        self.assertIn("pass data model", out)

    def test_excluded_files_do_not_count(self):
        # Preview data (0 %) and the app entry point are excluded: 182/190 lines = 95.8 %.
        with open(fixture("xccov-pass.json")) as f:
            report = json.load(f)
        with open(fixture("coverage-config.json")) as f:
            groups = coverage_gate.load_groups(json.load(f))
        result = coverage_gate.evaluate(report, groups, "/repo")[0]
        self.assertEqual([f.path for f in result.files],
                         ["MaynardGolf/Data/Player.swift", "MaynardGolf/Home/HomeViewModel.swift"])
        self.assertAlmostEqual(result.percent, 100 * 182 / 190)

    def test_fails_below_the_threshold_and_lists_the_worst_files(self):
        code, out = run("xccov-fail.json")
        self.assertEqual(code, coverage_gate.EXIT_COVERAGE)
        self.assertIn("FAIL v2 app code", out)
        self.assertIn("MaynardGolf/Home/Uncovered.swift", out)
        self.assertLess(out.index("Uncovered.swift"), out.index("HomeViewModel.swift"))

    def test_a_missing_target_fails(self):
        code, out = run("xccov-no-app.json")
        self.assertEqual(code, coverage_gate.EXIT_COVERAGE)
        self.assertIn("target MaynardGolf.app is not in the report", out)

    def test_report_only_never_fails(self):
        code, _ = run("xccov-fail.json", "--report-only")
        self.assertEqual(code, coverage_gate.EXIT_PASS)

    def test_writes_a_markdown_table_for_the_pr(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "coverage.md")
            run("xccov-fail.json", "--markdown", path)
            with open(path) as f:
                table = f.read()
        self.assertIn("| v2 app code | 60.0 % (120/200) | 90 % | ❌ |", table)
        self.assertIn("| target `MaynardGolf.app` | 60.0 % | | |", table)

    def test_a_group_with_no_files_passes(self):
        groups = [coverage_gate.Group("nothing yet", "MaynardGolf.app", 100, ["MaynardGolf/Formatters/*"])]
        with open(fixture("xccov-pass.json")) as f:
            result = coverage_gate.evaluate(json.load(f), groups, "/repo")[0]
        self.assertTrue(result.passed)
        self.assertEqual(result.executable, 0)

    def test_a_config_without_groups_is_an_error(self):
        with self.assertRaises(ValueError):
            coverage_gate.load_groups({"groups": []})


if __name__ == "__main__":
    unittest.main()
