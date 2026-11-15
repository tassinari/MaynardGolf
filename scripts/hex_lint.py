#!/usr/bin/env python3
"""Color literal lint (00-design-system §3, #3): screens and components use design tokens, never hex or
RGB literals. Scans Swift sources and fails on:

- hex color strings such as "#1E5AA8" or 0x1E5AA8 used as a color;
- `Color(red:` / `UIColor(red:` / `Color(hex:` / `Color(.sRGB, red:` literals.

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
    (re.compile(r'\b(UI)?Color\(\s*(\.sRGB\s*,\s*)?red:'), "RGB color literal"),
    (re.compile(r'\bColor\(\s*hex:'), "hex color initializer"),
]


def swift_files(paths: Iterable[str]) -> List[str]:
    found = []
    for path in paths:
        if os.path.isfile(path) and path.endswith(".swift"):
            found.append(path)
        for dirpath, _, names in os.walk(path):
            found.extend(os.path.join(dirpath, n) for n in names if n.endswith(".swift"))
    return sorted(set(found))


def scan(path: str) -> List[Tuple[int, str, str]]:
    """(line number, kind, line) for every literal in a file; comment lines are skipped."""
    hits = []
    with open(path, encoding="utf-8") as f:
        for number, line in enumerate(f, start=1):
            if line.lstrip().startswith("//"):
                continue
            for pattern, kind in PATTERNS:
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
