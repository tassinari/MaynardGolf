# scripts

Command-line tools for building and testing MaynardGolf (story #99). They run on a Mac with Xcode
and the macOS system Python 3 (standard library only; nothing to install).

## Prerequisites
- Xcode with an **iOS 27** simulator runtime and an **iPhone 18 Pro** simulator (the app targets iOS
  26, X-12). Any other device works with `--device` / `--os`.
- `python3` (the one in `/usr/bin` is fine).

## `build.sh`

```sh
scripts/build.sh test        # self-tests, unit + UI tests on iPhone 18 Pro, coverage gate, lint
scripts/build.sh test-unit   # unit tests only; coverage is printed, not gated
scripts/build.sh test-ui     # UI tests only; coverage is printed, not gated
scripts/build.sh lint        # build, then String Catalog lint only
scripts/build.sh selftest    # this folder's own unit tests
```

Options: `--device NAME` (default `iPhone 18 Pro`), `--os MAJOR[.MINOR]` (default `27`, the newest
installed 27.x runtime), `--udid UDID` to name an exact simulator, and `--devices "NAME,NAME"` to
also run the UI tests on each of those devices (newest runtime that has it), for example
`--devices "iPhone 17e,iPhone 18 Pro Max"` to check the smallest and largest screens (X-19).

`test` is what runs before every PR (TS-CI-01). Its steps:
1. **Self-tests** of these scripts (`python3 -m unittest`).
2. **Unit and UI tests** in one `xcodebuild test` run on iPhone 18 Pro, with coverage on, plus the
   UI tests on each `--devices` device if given. Logs and result bundles go to `build/test.log` /
   `build/test.xcresult` (and `build/test-<device>.*`). Tests come from the shared
   test plan `MaynardGolf.xctestplan` (coverage on, targets run one at a time).
3. **Coverage gate** (`coverage_gate.py`): prints coverage per target and per gated group, and
   fails when a group is under its minimum (TS-UT-02, TS-CI-02). It also writes
   `build/test-coverage.md`, a table to paste into the PR description (TS-CI-03). The old table
   is deleted first, and the script only points you at it when tests and coverage passed.
4. **Color literal lint** (`hex_lint.py`): fails on hex color strings and `Color(red:)` /
   `UIColor(red:)` literals in `MaynardGolf/` and `MaynardUI/` (tests aren't scanned). Colors come
   from the MaynardUI tokens (00-design-system §3).
5. **String Catalog lint** (`catalog_lint.py`): fails on strings used in code but missing from
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
| 3 | String Catalog or color literal lint failed |
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
