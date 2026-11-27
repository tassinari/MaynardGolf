"""Unit tests for scripts/hex_lint.py (#3)."""

import io
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import hex_lint  # noqa: E402


class HexLintTests(unittest.TestCase):
    def run_on(self, source):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "View.swift")
            with open(path, "w") as f:
                f.write(source)
            out = io.StringIO()
            with redirect_stdout(out):
                code = hex_lint.main([tmp])
        return code, out.getvalue()

    def test_tokens_pass(self):
        code, out = self.run_on('Text("Hi").foregroundStyle(Color.ds.textPrimary)\n')
        self.assertEqual(code, hex_lint.EXIT_PASS, out)

    def test_literals_fail(self):
        for line in ['let c = Color(red: 0.1, green: 0.2, blue: 0.3)\n', 'let u = UIColor(red: 1, green: 0, blue: 0, alpha: 1)\n',
                     'let s = "#1E5AA8"\n', 'let h = Color(hex: "1E5AA8")\n', 'let p = Color(.sRGB, red: 1, green: 1, blue: 1)\n',
                     'let w = Color(white: 0.5)\n', 'let q = Color(hue: 0.3, saturation: 1, brightness: 1)\n',
                     'let d = Color(.displayP3, red: 1, green: 0, blue: 0)\n', 'let e = UIColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1)\n',
                     'let g = UIColor(white: 0.2, alpha: 1)\n']:
            code, out = self.run_on(line)
            self.assertEqual(code, hex_lint.EXIT_LINT, line)
            self.assertIn("View.swift:1", out)

    def test_palette_fails_outside_the_tokens(self):
        for line in ['Text("Hi").foregroundStyle(Color.palette.blue500)\n', 'let c = Color(palette: .gray900)\n',
                     'let p = DSPaletteColor.red500\n']:
            code, out = self.run_on(line)
            self.assertEqual(code, hex_lint.EXIT_LINT, line)
            self.assertIn("palette color", out)

    def test_palette_is_allowed_in_the_tokens_and_catalog(self):
        for folder in ("Tokens", "Catalog"):
            path = os.path.join(hex_lint.ROOT, "MaynardUI", folder, "X.swift")
            self.assertTrue(hex_lint.palette_allowed(path), folder)
        self.assertFalse(hex_lint.palette_allowed(os.path.join(hex_lint.ROOT, "MaynardUI", "Components", "X.swift")))

    def test_comments_are_ignored(self):
        code, _ = self.run_on('// Lake 600 is "#1E5AA8"\nlet x = 1\n')
        self.assertEqual(code, hex_lint.EXIT_PASS)

    def test_default_paths_scan_the_repo_cleanly(self):
        out = io.StringIO()
        with redirect_stdout(out):
            code = hex_lint.main([])
        self.assertEqual(code, hex_lint.EXIT_PASS, out.getvalue())


if __name__ == "__main__":
    unittest.main()
