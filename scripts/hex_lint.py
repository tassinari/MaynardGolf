#!/usr/bin/env python3
"""Color literal lint (00-design-system §3, #3): screens and components use design tokens, never hex or
RGB literals. Scans Swift sources and fails on:

- hex color strings such as "#1E5AA8";
- palette colors outside MaynardUI's tokens and catalog (DS-CL-04): `Color.palette`, `Color(palette:` and
  `DSPaletteColor`. Screens and components use semantic tokens (`Color.ds.<role>`) only, so a new look is a
  change to color sets. The palette is internal to MaynardUI, so the app can't compile a use anyway; this
  catches MaynardUI's own components;
- color literal initializers: `Color(red:` / `Color(.sRGB, red:` / `Color(.displayP3, red:` /
  `Color(white:` / `Color(hue:` / `Color(hex:` and `UIColor(red:` / `UIColor(white:` /
  `UIColor(hue:` / `UIColor(displayP3Red:`.

Colors live in the MaynardUI asset catalog. Tests are not scanned (they compare against documented hex
values on purpose).

    python3 scripts/hex_lint.py [paths...]     # defaults to MaynardGolf/ and MaynardUI/

Exit codes: 0 pass, 3 literals found. Standard library only (Python 3.9+).
"""

from __future__ import annotations

import os
import re
import sys
from typing import Iterable, List, Tuple

EXIT_PASS = 0
EXIT_LINT = 3
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_PATHS = [os.path.join(ROOT, "MaynardGolf"), os.path.join(ROOT, "MaynardUI")]

PATTERNS = [
    (re.compile(r'"#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?"'), "hex color string"),
    (re.compile(r'\b(UI)?Color\(\s*(\.(sRGB|sRGBLinear|displayP3)\s*,\s*)?(red|white|hue):'), "color literal"),
    (re.compile(r'\bUIColor\(\s*displayP3Red:'), "color literal"),
    (re.compile(r'\bColor\(\s*hex:'), "hex color initializer"),
    (re.compile(r'\bColor\.palette\b|\bColor\(\s*palette:|\bDSPaletteColor\b'), "palette color (use a semantic token)"),
]

# Where the palette may appear: the tokens that are drawn from it, and the catalog that shows it.
PALETTE_ALLOWED = [os.path.join(ROOT, "MaynardUI", "Tokens"), os.path.join(ROOT, "MaynardUI", "Catalog")]


def swift_files(paths: Iterable[str]) -> List[str]:
    found = []
    for path in paths:
        if os.path.isfile(path) and path.endswith(".swift"):
            found.append(path)
        for dirpath, _, names in os.walk(path):
            found.extend(os.path.join(dirpath, n) for n in names if n.endswith(".swift"))
    return sorted(set(found))


def palette_allowed(path: str) -> bool:
    """Whether a file may name palette colors (MaynardUI's tokens and catalog)."""
    full = os.path.abspath(path)
    return any(full.startswith(allowed + os.sep) for allowed in PALETTE_ALLOWED)


def scan(path: str) -> List[Tuple[int, str, str]]:
    """(line number, kind, line) for every literal in a file; comment lines are skipped."""
    hits = []
    with open(path, encoding="utf-8") as f:
        for number, line in enumerate(f, start=1):
            if line.lstrip().startswith("//"):
                continue
            for pattern, kind in PATTERNS:
                if kind.startswith("palette") and palette_allowed(path):
                    continue
                if pattern.search(line):
                    hits.append((number, kind, line.strip()))
    return hits


def main(argv: List[str]) -> int:
    paths = argv or DEFAULT_PATHS
    failures = 0
    files = swift_files(paths)
    for path in files:
        for number, kind, line in scan(path):
            failures += 1
            print(f"  {os.path.relpath(path, ROOT)}:{number}: {kind}: {line}")
    print(f"Color literals: {failures} in {len(files)} Swift files")
    return EXIT_PASS if failures == 0 else EXIT_LINT


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
