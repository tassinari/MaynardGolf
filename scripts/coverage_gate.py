#!/usr/bin/env python3
"""Coverage gate for MaynardGolf (testing-standards TS-UT-02, TS-CI-02, TS-CI-03).

Reads an `xcrun xccov view --report --json` report and the rules in `scripts/coverage.json`, prints
coverage per target and per gated group, and exits non-zero when a group is under its minimum.

    xcrun xccov view --report --json build/test.xcresult > build/coverage.json
    python3 scripts/coverage_gate.py build/coverage.json [--config scripts/coverage.json]
        [--root .] [--markdown build/coverage.md] [--report-only]

Exit codes: 0 pass, 2 a group is under its minimum, its target is missing from the report, none of
the target's files are under the repo root (a path mismatch would otherwise measure nothing), or the
group matched no files and doesn't set `"allowEmpty": true`.
Standard library only, so it runs on the macOS system Python (3.9+).
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import sys
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

EXIT_PASS = 0
EXIT_COVERAGE = 2
#: Where scripts/build.sh keeps DerivedData; files there (GeneratedAssetSymbols.swift) are generated.
GENERATED_PREFIX = "build/"


@dataclass
class FileCoverage:
    path: str  # relative to the repo root
    covered: int
    executable: int

    @property
    def percent(self) -> float:
        return 100.0 * self.covered / self.executable if self.executable else 100.0


@dataclass
class Group:
    """A set of files that must reach `minimum` percent line coverage together."""
    name: str
    target: str
    minimum: float
    include: List[str]
    exclude: List[str] = field(default_factory=list)
    #: A group may match nothing yet (no v2 code in its folder). Off by default, so a glob or path
    #: mismatch fails loudly instead of passing at 0/0 lines.
    allow_empty: bool = False


@dataclass
class GroupResult:
    group: Group
    files: List[FileCoverage]
    target_found: bool
    #: The target has files, but none of its non-generated files (outside build/) are under the repo root.
    paths_outside_root: bool = False

    @property
    def covered(self) -> int:
        return sum(f.covered for f in self.files)

    @property
    def executable(self) -> int:
        return sum(f.executable for f in self.files)

    @property
    def percent(self) -> float:
        return 100.0 * self.covered / self.executable if self.executable else 100.0

    @property
    def problem(self) -> Optional[str]:
        """Why the group can't be measured, or None."""
        if not self.target_found:
            return f"target {self.group.target} is not in the report"
        if self.paths_outside_root:
            return f"no {self.group.target} file is under the repo root (path mismatch?)"
        if not self.files and not self.group.allow_empty:
            return "matched no files (set allowEmpty if that's expected)"
        return None

    @property
    def passed(self) -> bool:
        return self.problem is None and self.percent + 1e-9 >= self.group.minimum


def relative(path: str, root: str) -> Optional[str]:
    """`path` relative to `root`, resolving symlinks on both (`/private/tmp` vs `/tmp`); None if outside."""
    root = os.path.realpath(root).rstrip("/") + "/"
    path = os.path.realpath(path)
    return path[len(root):] if path.startswith(root) else None


def matches(path: str, patterns: List[str]) -> bool:
    """`fnmatch` globs; `*` also crosses `/`, so `Folder/*` covers everything below Folder."""
    return any(fnmatch.fnmatchcase(path, p) for p in patterns)


def load_groups(config: dict) -> List[Group]:
    groups = []
    for raw in config.get("groups", []):
        groups.append(Group(name=raw["name"], target=raw["target"], minimum=float(raw["minimum"]),
                            include=list(raw["include"]), exclude=list(raw.get("exclude", [])),
                            allow_empty=bool(raw.get("allowEmpty", False))))
    if not groups:
        raise ValueError("coverage config has no groups")
    return groups


def target_files(report: dict, target: str, root: str) -> Optional[Tuple[List[FileCoverage], int]]:
    """The target's files under `root` (relative paths), and how many of its files were outside root."""
    for t in report.get("targets", []):
        if t.get("name") == target:
            inside, outside = [], 0
            for f in t.get("files", []):
                rel = relative(f["path"], root)
                if rel is None:
                    outside += 1
                else:
                    inside.append(FileCoverage(rel, int(f["coveredLines"]), int(f["executableLines"])))
            return inside, outside
    return None


def evaluate(report: dict, groups: List[Group], root: str) -> List[GroupResult]:
    results = []
    for g in groups:
        found = target_files(report, g.target, root)
        if found is None:
            results.append(GroupResult(g, [], target_found=False))
            continue
        files, outside = found
        chosen = [f for f in files if matches(f.path, g.include) and not matches(f.path, g.exclude)]
        # Generated sources under build/ are always "inside", so they can't vouch for the real ones.
        sources = [f for f in files if not f.path.startswith(GENERATED_PREFIX)]
        results.append(GroupResult(g, chosen, target_found=True, paths_outside_root=outside > 0 and not sources))
    return results


def target_summary(report: dict) -> Dict[str, float]:
    return {t["name"]: 100.0 * float(t.get("lineCoverage", 0)) for t in report.get("targets", [])}


def format_text(report: dict, results: List[GroupResult]) -> str:
    lines = ["Coverage by target:"]
    for name, pct in sorted(target_summary(report).items()):
        lines.append(f"  {name:<32} {pct:6.2f} %")
    lines.append("")
    lines.append("Coverage gate:")
    for r in results:
        if r.problem:
            lines.append(f"  FAIL {r.group.name}: {r.problem}")
            continue
        mark = "pass" if r.passed else "FAIL"
        lines.append(f"  {mark} {r.group.name:<28} {r.percent:6.2f} % (min {r.group.minimum:g} %, "
                     f"{r.covered}/{r.executable} lines, {len(r.files)} files)")
        if not r.passed:
            for f in sorted(r.files, key=lambda f: f.percent)[:10]:
                if f.percent < r.group.minimum:
                    lines.append(f"         {f.percent:6.2f} %  {f.path}")
    return "\n".join(lines)


def format_markdown(report: dict, results: List[GroupResult]) -> str:
    """Table for the PR description (TS-CI-03)."""
    rows = ["| Coverage | Lines | Minimum | Result |", "|---|---|---|---|"]
    for r in results:
        if r.problem:
            rows.append(f"| {r.group.name} | {r.problem} | {r.group.minimum:g} % | ❌ |")
        else:
            rows.append(f"| {r.group.name} | {r.percent:.1f} % ({r.covered}/{r.executable}) | "
                        f"{r.group.minimum:g} % | {'✅' if r.passed else '❌'} |")
    for name, pct in sorted(target_summary(report).items()):
        rows.append(f"| target `{name}` | {pct:.1f} % | | |")
    return "\n".join(rows) + "\n"


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    here = os.path.dirname(os.path.abspath(__file__))
    parser.add_argument("report", help="xccov JSON report")
    parser.add_argument("--config", default=os.path.join(here, "coverage.json"))
    parser.add_argument("--root", default=os.path.dirname(here), help="repo root, to make paths relative")
    parser.add_argument("--markdown", help="also write a Markdown table here")
    parser.add_argument("--report-only", action="store_true", help="print coverage but always exit 0")
    args = parser.parse_args(argv)

    with open(args.report) as f:
        report = json.load(f)
    with open(args.config) as f:
        groups = load_groups(json.load(f))

    results = evaluate(report, groups, args.root)
    print(format_text(report, results))
    if args.markdown:
        with open(args.markdown, "w") as f:
            f.write(format_markdown(report, results))
    if args.report_only:
        return EXIT_PASS
    return EXIT_PASS if all(r.passed for r in results) else EXIT_COVERAGE


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
