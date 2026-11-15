#!/usr/bin/env python3
"""String Catalog lint for MaynardGolf (X-01).

Compares the strings the compiler extracted from the app's Swift sources (`*.stringsdata`, written
during a build) with `Localizable.xcstrings`:

- **missing**: used in code but not in the catalog;
- **stale**: in the catalog, marked stale by Xcode, or no longer used in code
  (entries Xcode marks `manual`, for keys built at run time, are kept);
- **no comment** (warning only): an entry without a translator comment.

    python3 scripts/catalog_lint.py --catalog MaynardGolf/Localizable.xcstrings \
        --derived-data build/DerivedData [--target MaynardGolf]

Exit codes: 0 pass, 3 missing or stale entries. Standard library only (Python 3.9+).
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import shlex
import sys
from dataclasses import dataclass
from typing import List, Optional, Set, Tuple

EXIT_PASS = 0
EXIT_LINT = 3
TABLE = "Localizable"


@dataclass
class LintResult:
    missing: List[str]
    stale: List[str]
    uncommented: List[str]
    sources: int

    @property
    def passed(self) -> bool:
        return not self.missing and not self.stale


def unescape(line: str) -> str:
    """One path from a swiftc response file: spaces and quotes are backslash-escapes
    ("Preview\\ Content"). A line shlex can't parse (an unbalanced quote) is used as written."""
    try:
        parts = shlex.split(line)
    except ValueError:
        return line.strip()
    return parts[0] if parts else line.strip()


def compiled_sources(target_dir: str, target: str) -> Optional[Set[str]]:
    """The Swift files the last build compiled for the target, from Xcode's `<target>.SwiftFileList`
    (one per architecture); None if there's no file list."""
    lists = glob.glob(os.path.join(target_dir, "**", f"{target}.SwiftFileList"), recursive=True)
    if not lists:
        return None
    sources: Set[str] = set()
    for path in lists:
        with open(path) as f:
            for line in f:
                if line.strip():
                    sources.add(os.path.realpath(unescape(line)))
    return sources


def extracted_keys(derived_data: str, target: str) -> Tuple[Set[str], int]:
    """Keys in the `Localizable` table from the stringsdata of files the target still compiles.

    Leftovers from files that were deleted, or moved out of the target, stay in DerivedData; the
    compiler's own input list filters them out (falling back to "the file still exists")."""
    keys: Set[str] = set()
    sources = 0
    for target_dir in glob.glob(os.path.join(derived_data, "Build", "Intermediates.noindex", "*.build", "*",
                                             f"{target}.build")):
        compiled = compiled_sources(target_dir, target)
        for path in glob.glob(os.path.join(target_dir, "**", "*.stringsdata"), recursive=True):
            with open(path) as f:
                data = json.load(f)
            source = data.get("source", "")
            if not source.endswith(".swift"):
                continue  # app-intents metadata
            if compiled is not None and os.path.realpath(source) not in compiled:
                continue  # no longer compiled into the target
            if compiled is None and not os.path.exists(source):
                continue  # a deleted file's leftover
            sources += 1
            for entry in data.get("tables", {}).get(TABLE, []):
                keys.add(entry["key"])
    return keys, sources


def lint(catalog: dict, used: Set[str], sources: int) -> LintResult:
    strings = catalog.get("strings", {})
    missing = sorted(k for k in used if k not in strings)
    stale = sorted(k for k, v in strings.items()
                   if v.get("extractionState") == "stale"
                   or (k not in used and v.get("extractionState") != "manual"))
    uncommented = sorted(k for k, v in strings.items() if not v.get("comment"))
    return LintResult(missing, stale, uncommented, sources)


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--derived-data", required=True)
    parser.add_argument("--target", default="MaynardGolf")
    args = parser.parse_args(argv)

    with open(args.catalog) as f:
        catalog = json.load(f)
    used, sources = extracted_keys(args.derived_data, args.target)
    if sources == 0:
        print("String Catalog: no extracted strings found; build the app first", file=sys.stderr)
        return EXIT_LINT
    result = lint(catalog, used, sources)

    print(f"String Catalog: {len(catalog.get('strings', {}))} entries, {len(used)} used in {sources} files")
    for key in result.missing:
        print(f"  MISSING  {key!r} is used in code but not in the catalog")
    for key in result.stale:
        print(f"  STALE    {key!r} is in the catalog but not used")
    for key in result.uncommented:
        print(f"  warning  {key!r} has no translator comment")
    return EXIT_PASS if result.passed else EXIT_LINT


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
