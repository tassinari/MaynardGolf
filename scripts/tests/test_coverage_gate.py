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

    def test_a_problem_shows_in_the_markdown_table(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "coverage.md")
            run("xccov-no-app.json", "--markdown", path)
            with open(path) as f:
                self.assertIn("| v2 app code | target MaynardGolf.app is not in the report | 90 % | ❌ |", f.read())

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

    def evaluate_one(self, report_name, group, root="/repo"):
        with open(fixture(report_name)) as f:
            return coverage_gate.evaluate(json.load(f), [group], root)[0]

    def test_an_empty_group_fails_unless_it_allows_it(self):
        strict = coverage_gate.Group("formatters", "MaynardGolf.app", 100, ["MaynardGolf/Formatters/*"])
        result = self.evaluate_one("xccov-pass.json", strict)
        self.assertFalse(result.passed)
        self.assertIn("matched no files", result.problem)
        allowed = coverage_gate.Group("formatters", "MaynardGolf.app", 100, ["MaynardGolf/Formatters/*"],
                                      allow_empty=True)
        self.assertTrue(self.evaluate_one("xccov-pass.json", allowed).passed)

    def test_paths_outside_the_root_fail_even_when_empty_is_allowed(self):
        # A symlinked checkout or a CI workspace path: nothing would be measured, so it must not pass.
        group = coverage_gate.Group("v2 app code", "MaynardGolf.app", 90, ["MaynardGolf/*.swift"], allow_empty=True)
        result = self.evaluate_one("xccov-pass.json", group, root="/somewhere/else")
        self.assertFalse(result.passed)
        self.assertIn("path mismatch", result.problem)
        code, out = run("xccov-pass.json", "--root", "/somewhere/else")
        self.assertEqual(code, coverage_gate.EXIT_COVERAGE)
        self.assertIn("FAIL v2 app code: no MaynardGolf.app file is under the repo root", out)

    def test_generated_files_inside_the_root_dont_hide_a_mismatch(self):
        report = {"targets": [{"name": "MaynardGolf.app", "lineCoverage": 1.0, "files": [
            {"path": "/repo/build/DerivedData/GeneratedAssetSymbols.swift", "coveredLines": 5, "executableLines": 5},
            {"path": "/elsewhere/MaynardGolf/Home.swift", "coveredLines": 0, "executableLines": 50}]}]}
        group = coverage_gate.Group("v2 app code", "MaynardGolf.app", 90, ["MaynardGolf/*.swift"], allow_empty=True)
        result = coverage_gate.evaluate(report, [group], "/repo")[0]
        self.assertFalse(result.passed)
        self.assertIn("path mismatch", result.problem)

    def test_symlinked_roots_resolve(self):
        with tempfile.TemporaryDirectory() as tmp:
            real = os.path.join(tmp, "real")
            os.makedirs(os.path.join(real, "MaynardGolf"))
            link = os.path.join(tmp, "link")
            os.symlink(real, link)
            self.assertEqual(coverage_gate.relative(os.path.join(real, "MaynardGolf", "A.swift"), link),
                             "MaynardGolf/A.swift")
            self.assertIsNone(coverage_gate.relative("/elsewhere/A.swift", link))

    def test_a_config_without_groups_is_an_error(self):
        with self.assertRaises(ValueError):
            coverage_gate.load_groups({"groups": []})


if __name__ == "__main__":
    unittest.main()
