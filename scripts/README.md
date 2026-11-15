# scripts

Command-line tools for building and testing MaynardGolf (story #99). They run on a Mac with Xcode
and the macOS system Python 3 (standard library only; nothing to install).

## Prerequisites
- Xcode with an **iOS 26** simulator runtime and an **iPhone 17** simulator (X-12). Any other
  device works with `--device`.
- `python3` (the one in `/usr/bin` is fine).

## `build.sh`

```sh
scripts/build.sh test        # self-tests, unit + UI tests, coverage gate, String Catalog lint
scripts/build.sh test-unit   # unit tests only; coverage is printed, not gated
scripts/build.sh test-ui     # UI tests only; coverage is printed, not gated
scripts/build.sh lint        # build, then String Catalog lint only
scripts/build.sh selftest    # this folder's own unit tests
```

Options: `--device NAME` (default `iPhone 17`), `--os MAJOR[.MINOR]` (default `26`, which picks the
newest installed 26.x runtime), `--udid UDID` to name an exact simulator.

`test` is what runs before every PR (TS-CI-01). Its steps:
1. **Self-tests** of these scripts (`python3 -m unittest`).
2. **Unit and UI tests** in one `xcodebuild test` run, with coverage on. The log and result
   bundle go to `build/test.log` and `build/test.xcresult`. Test targets run one at a time
   (the scheme turns off parallel clones).
3. **Coverage gate** (`coverage_gate.py`): prints coverage per target and per gated group, and
   fails when a group is under its minimum (TS-UT-02, TS-CI-02). It also writes
   `build/test-coverage.md`, a table to paste into the PR description (TS-CI-03).
4. **String Catalog lint** (`catalog_lint.py`): fails on strings used in code but missing from
   `Localizable.xcstrings`, and on catalog entries that are stale or no longer used. An entry
   without a translator comment is a warning (X-01).

A failed self-test stops the run. After that, every step runs even when an earlier one fails,
then a summary prints. **Exit codes:**

| Code | Meaning |
|---|---|
| 0 | everything passed |
| 1 | a test failed (or a self-test, or the build) |
| 2 | coverage is below the gate |
| 3 | String Catalog lint failed |
| 64 | usage error |

When more than one step fails, the lowest code wins. Everything the script writes is under
`build/`, which git ignores.

## `coverage.json`
The gate's rules. Each group names an xccov target, a minimum percentage and `include` /
`exclude` globs relative to the repo root (`fnmatch`; `*` also crosses `/`).

- **v2 app code**: all Swift under `MaynardGolf/` at **90 %**, excluding preview data and the
  app entry point.
- Add a group at **100 %** for each pure-logic folder (formatters, scorecard model, score entry,
  handicap calculator) as its story creates it. A group with no files yet passes.

Coverage counts unit and UI tests together, which is why only `test` is gated.

## Other scripts
- `coverage_gate.py REPORT.json [--config] [--root] [--markdown FILE] [--report-only]`
- `catalog_lint.py --catalog FILE --derived-data DIR [--target MaynardGolf]` reads the
  `*.stringsdata` files Xcode writes while building, skipping leftovers from deleted files.
- `simulator.py [--name] [--os]` prints the UDID `build.sh` uses.

Their tests and fixture reports are in `scripts/tests/`.

## Coming next
`build.sh release` (version bump, archive, TestFlight upload) is #98.
