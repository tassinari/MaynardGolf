# scripts

Command-line tools for building and testing MaynardGolf (story #99). They run on a Mac with Xcode
and the macOS system Python 3 (standard library only; nothing to install).

## Prerequisites
- Xcode with an **iOS 26** simulator runtime and an **iPhone 17** simulator (X-12). Any other
  device works with `--device`.
- `python3` (the one in `/usr/bin` is fine).

## `build.sh`

```sh
scripts/build.sh test        # self-tests, unit + UI tests (smallest and largest iPhone), coverage, lint
scripts/build.sh test-unit   # unit tests only; coverage is printed, not gated
scripts/build.sh test-ui     # UI tests only; coverage is printed, not gated
scripts/build.sh lint        # build, then String Catalog lint only
scripts/build.sh selftest    # this folder's own unit tests
```

Options: `--device NAME` (default `iPhone 17e`, the smallest iOS 26 iPhone), `--large-device NAME`
(default `iPhone 17 Pro Max`), `--one-device` to skip the large-device run, `--os MAJOR[.MINOR]`
(default `26`, which picks the newest installed 26.x runtime), `--udid UDID` to name an exact simulator.

`test` is what runs before every PR (TS-CI-01). Its steps:
1. **Self-tests** of these scripts (`python3 -m unittest`).
2. **Unit and UI tests** in one `xcodebuild test` run on the smallest iPhone, with coverage on, then
   the **UI tests again on the largest** (X-19, TS-UI-06). Logs and result bundles go to
   `build/test.log` / `build/test.xcresult` and `build/test-large.*`. Tests come from the shared
   test plan `MaynardGolf.xctestplan` (coverage on, targets run one at a time).
3. **Coverage gate** (`coverage_gate.py`): prints coverage per target and per gated group, and
   fails when a group is under its minimum (TS-UT-02, TS-CI-02). It also writes
   `build/test-coverage.md`, a table to paste into the PR description (TS-CI-03). The old table
   is deleted first, and the script only points you at it when tests and coverage passed.
4. **String Catalog lint** (`catalog_lint.py`): fails on strings used in code but missing from
   `Localizable.xcstrings`, and on catalog entries that are stale or no longer used. An entry
   without a translator comment is a warning (X-01). It's skipped, and says so, when the build
   failed.

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
  handicap calculator) in the story that creates it.
- A group that matches **no files fails**, unless it sets `"allowEmpty": true`. "v2 app code"
  sets it only until the first v2 source file lands; remove it then.
- The gate also fails when none of a target's files are under the repo root. Paths are compared
  after resolving symlinks, so a path mismatch can't pass at 0/0 lines.

Coverage counts unit and UI tests together, which is why only `test` is gated.

## Other scripts
- `coverage_gate.py REPORT.json [--config] [--root] [--markdown FILE] [--report-only]`
- `catalog_lint.py --catalog FILE --derived-data DIR [--target MaynardGolf] [--fix]` reads the
  `*.stringsdata` files Xcode writes while building. It counts only files in the target's
  `MaynardGolf.SwiftFileList` (the compiler's input), so leftovers from deleted or moved files
  don't count. `--fix` adds strings found in code (with the code's comment) and removes unused
  ones, keeping `manual` entries (keys looked up at run time, such as local rules). Run it after a
  build, then add a translator comment to anything new.
- `simulator.py [--name] [--os]` prints the UDID `build.sh` uses.

Their tests and fixture reports are in `scripts/tests/`.

## Coming next
`build.sh release` (version bump, archive, TestFlight upload) is #98.
