"""Unit tests for scripts/catalog_lint.py (#97)."""

import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import catalog_lint  # noqa: E402


class CatalogLintTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = self.tmp.name
        self.derived = os.path.join(root, "DerivedData")
        self.objects = os.path.join(self.derived, "Build", "Intermediates.noindex", "MaynardGolf.build",
                                    "Debug-iphonesimulator", "MaynardGolf.build", "Objects-normal", "arm64")
        os.makedirs(self.objects)
        self.source = os.path.join(root, "Home.swift")
        open(self.source, "w").close()
        self.catalog = os.path.join(root, "Localizable.xcstrings")

    def tearDown(self):
        self.tmp.cleanup()

    def write_stringsdata(self, name, source, keys):
        data = {"source": source, "tables": {"Localizable": [{"key": k, "comment": ""} for k in keys]}, "version": 1}
        with open(os.path.join(self.objects, name + ".stringsdata"), "w") as f:
            json.dump(data, f)

    def write_catalog(self, strings):
        with open(self.catalog, "w") as f:
            json.dump({"sourceLanguage": "en", "strings": strings, "version": "1.0"}, f)

    def run_lint(self):
        out = io.StringIO()
        with redirect_stdout(out), redirect_stderr(out):
            code = catalog_lint.main(["--catalog", self.catalog, "--derived-data", self.derived])
        return code, out.getvalue()

    def test_passes_when_catalog_matches_code(self):
        self.write_stringsdata("Home", self.source, ["Rounds", "New round"])
        self.write_catalog({"Rounds": {"comment": "Section title"}, "New round": {"comment": "Button"}})
        code, out = self.run_lint()
        self.assertEqual(code, catalog_lint.EXIT_PASS, out)

    def test_a_string_missing_from_the_catalog_fails(self):
        self.write_stringsdata("Home", self.source, ["Rounds", "New round"])
        self.write_catalog({"Rounds": {"comment": "Section title"}})
        code, out = self.run_lint()
        self.assertEqual(code, catalog_lint.EXIT_LINT)
        self.assertIn("MISSING  'New round'", out)

    def test_stale_and_unused_entries_fail_but_manual_ones_are_kept(self):
        self.write_stringsdata("Home", self.source, ["Rounds"])
        self.write_catalog({
            "Rounds": {"comment": "Section title"},
            "Old title": {"comment": "Removed", "extractionState": "stale"},
            "Unused": {"comment": "No longer in code"},
            "Hole %lld": {"comment": "Built at run time", "extractionState": "manual"},
        })
        code, out = self.run_lint()
        self.assertEqual(code, catalog_lint.EXIT_LINT)
        self.assertIn("STALE    'Old title'", out)
        self.assertIn("STALE    'Unused'", out)
        self.assertNotIn("'Hole %lld' is in the catalog", out)

    def test_leftovers_from_deleted_files_are_ignored(self):
        self.write_stringsdata("Home", self.source, ["Rounds"])
        self.write_stringsdata("Gone", "/nowhere/Gone.swift", ["Deleted screen"])
        self.write_catalog({"Rounds": {"comment": "Section title"}})
        code, out = self.run_lint()
        self.assertEqual(code, catalog_lint.EXIT_PASS, out)

    def write_file_list(self, sources):
        # Xcode escapes spaces in this response file, as in "Preview\ Content".
        with open(os.path.join(self.objects, "MaynardGolf.SwiftFileList"), "w") as f:
            f.write("".join(path.replace(" ", "\\ ") + "\n" for path in sources))

    def test_files_moved_out_of_the_target_are_ignored(self):
        # Still on disk, but no longer in the compiler's input list: its old strings don't count.
        moved = os.path.join(self.tmp.name, "Moved.swift")
        open(moved, "w").close()
        self.write_stringsdata("Home", self.source, ["Rounds"])
        self.write_stringsdata("Moved", moved, ["Old screen"])
        self.write_file_list([self.source])
        self.write_catalog({"Rounds": {"comment": "Section title"}})
        code, out = self.run_lint()
        self.assertEqual(code, catalog_lint.EXIT_PASS, out)
        self.assertNotIn("Old screen", out)

    def test_paths_with_spaces_match_the_file_list(self):
        folder = os.path.join(self.tmp.name, "Preview Content")
        os.makedirs(folder)
        preview = os.path.join(folder, "PreviewData.swift")
        open(preview, "w").close()
        self.write_stringsdata("PreviewData", preview, ["Sample player"])
        self.write_file_list([preview])
        with open(os.path.join(self.objects, "MaynardGolf.SwiftFileList")) as f:
            self.assertIn("Preview\\ Content", f.read())
        self.write_catalog({"Sample player": {"comment": "Preview name"}})
        code, out = self.run_lint()
        self.assertEqual(code, catalog_lint.EXIT_PASS, out)

    def test_unescaping_response_file_lines(self):
        self.assertEqual(catalog_lint.unescape("/a/Preview\\ Content/B.swift\n"), "/a/Preview Content/B.swift")
        self.assertEqual(catalog_lint.unescape("/a/Mark\\'s\\ Notes/C.swift"), "/a/Mark's Notes/C.swift")
        # An unbalanced quote doesn't crash the lint; the line is used as written.
        self.assertEqual(catalog_lint.unescape("/a/Mark's Notes/C.swift\n"), "/a/Mark's Notes/C.swift")

    def test_without_a_file_list_existing_files_count(self):
        moved = os.path.join(self.tmp.name, "Moved.swift")
        open(moved, "w").close()
        self.write_stringsdata("Moved", moved, ["Old screen"])
        self.write_catalog({})
        code, out = self.run_lint()
        self.assertEqual(code, catalog_lint.EXIT_LINT)
        self.assertIn("MISSING  'Old screen'", out)

    def test_missing_comment_is_only_a_warning(self):
        self.write_stringsdata("Home", self.source, ["Rounds"])
        self.write_catalog({"Rounds": {}})
        code, out = self.run_lint()
        self.assertEqual(code, catalog_lint.EXIT_PASS)
        self.assertIn("warning  'Rounds' has no translator comment", out)

    def test_no_build_output_fails(self):
        self.write_catalog({})
        code, out = self.run_lint()
        self.assertEqual(code, catalog_lint.EXIT_LINT)
        self.assertIn("build the app first", out)


if __name__ == "__main__":
    unittest.main()
