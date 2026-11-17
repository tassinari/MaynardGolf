"""Unit tests for scripts/release.py (#98)."""

import io
import os
import sys
import unittest
from contextlib import redirect_stdout
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import release  # noqa: E402


class BuildNumberTests(unittest.TestCase):
    def test_the_git_count_when_it_is_above_what_was_uploaded(self):
        self.assertEqual(release.next_build_number(185, 12), 185)

    def test_one_above_the_latest_upload_when_git_is_behind(self):
        self.assertEqual(release.next_build_number(185, 185), 186)
        self.assertEqual(release.next_build_number(10, 300), 301)

    def test_no_uploads_yet(self):
        self.assertEqual(release.next_build_number(1, None), 1)

    def test_a_count_below_one_is_rejected(self):
        with self.assertRaises(ValueError):
            release.next_build_number(0, None)


class BlockingChangesTests(unittest.TestCase):
    def test_a_clean_tree(self):
        self.assertEqual(release.blocking_changes(""), [])

    def test_any_tracked_change_blocks(self):
        porcelain = " M docs/README.md\nA  scripts/new.py\n D README.md\nR  a -> b\n"
        self.assertEqual(len(release.blocking_changes(porcelain)), 4)

    def test_untracked_files_block_only_inside_build_inputs(self):
        porcelain = ("?? MaynardGolf/New.swift\n"
                     "?? MaynardUI/Sources/X.swift\n"
                     "?? Config/Local.xcconfig\n"
                     "?? scripts/ExportOptions.plist\n"
                     "?? MaynardGolf.xcodeproj/xcshareddata/xcodecloud/\n"
                     "?? notes.txt\n")
        self.assertEqual(release.blocking_changes(porcelain),
                         ["?? MaynardGolf/New.swift", "?? MaynardUI/Sources/X.swift", "?? Config/Local.xcconfig",
                          "?? scripts/ExportOptions.plist"])

    def test_the_project_file_is_not_confused_with_its_folder(self):
        self.assertEqual(release.blocking_changes("?? MaynardGolf.xcodeproj/xcuserdata/\n"), [])


class WhatsNewTests(unittest.TestCase):
    def test_features_and_fixes_with_labels_and_scopes_dropped(self):
        subjects = ["feat: hole play screen (#53)", "fix(sync): no duplicate rounds", "docs: update README",
                    "refactor: tidy", "feat!: new store", "Merge pull request #1 from x"]
        self.assertEqual(release.whats_new(subjects),
                         "- New: hole play screen (#53)\n- Fixed: no duplicate rounds\n- New: new store")

    def test_nothing_for_testers(self):
        self.assertEqual(release.whats_new(["chore: bump", "test: more"]),
                         "Internal changes only; nothing new to test.")
        self.assertEqual(release.whats_new([]), "Internal changes only; nothing new to test.")

    def test_empty_descriptions_are_skipped(self):
        self.assertEqual(release.whats_new(["feat:", "feat: real"]), "- New: real")

    def test_long_lists_are_cut_with_a_count(self):
        text = release.whats_new([f"feat: thing {n}" for n in range(30)])
        lines = text.splitlines()
        self.assertEqual(len(lines), release.MAX_NOTE_LINES + 1)
        self.assertEqual(lines[-1], "- …and 5 more")

    def test_the_text_fits_app_store_connect(self):
        text = release.whats_new(["feat: " + "x" * 300 for _ in range(25)])
        self.assertLessEqual(len(text), release.WHATS_NEW_LIMIT)
        self.assertTrue(text.endswith("\n…"))


class CommandLineTests(unittest.TestCase):
    def run_main(self, argv, stdin=""):
        out = io.StringIO()
        with mock.patch("sys.stdin", io.StringIO(stdin)), redirect_stdout(out):
            code = release.main(argv)
        return code, out.getvalue()

    def test_build_number(self):
        self.assertEqual(self.run_main(["build-number", "--git-count", "185", "--latest", "12"]), (0, "185\n"))
        self.assertEqual(self.run_main(["build-number", "--git-count", "5"]), (0, "5\n"))

    def test_dirty(self):
        self.assertEqual(self.run_main(["dirty"], "?? notes.txt\n"), (0, ""))
        self.assertEqual(self.run_main(["dirty"], " M CLAUDE.md\n"), (1, " M CLAUDE.md\n"))

    def test_notes(self):
        self.assertEqual(self.run_main(["notes"], "fix: a\nchore: b\n"), (0, "- Fixed: a\n"))


if __name__ == "__main__":
    unittest.main()
