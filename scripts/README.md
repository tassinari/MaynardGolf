# scripts

Command-line tools for building and testing MaynardGolf (story #99). They run on a Mac with Xcode
and the macOS system Python 3 (standard library only; nothing to install). `release` also uses `openssl` (built into macOS).

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
scripts/build.sh release     # test, archive, upload to TestFlight (see Release below)
```

Options: `--device NAME` (default `iPhone 18 Pro`), `--os MAJOR[.MINOR]` (default `27`, the newest
installed 27.x runtime), `--udid UDID` to name an exact simulator, and `--devices "NAME,NAME"` to
also run the UI tests on each of those devices (newest runtime that has it), for example
`--devices "iPhone 17e,iPhone 18 Pro Max"` to check the smallest and largest screens (X-19).
`--workers N` runs the UI tests on N clones of the simulator at once (default `3`; `1` runs them one
at a time, which is easier to debug). The unit tests always run on the device itself.

`test` is what runs before every PR (TS-CI-01). Its steps:
1. **Self-tests** of these scripts (`python3 -m unittest`). They include `tools/make-gpx.py`'s, and fail when
   the GPX files in `Simulation/` no longer match the course data (`python3 tools/make-gpx.py` rewrites them).
2. **Unit and UI tests** in one `xcodebuild test` run on iPhone 18 Pro, with coverage on, plus the
   UI tests on each `--devices` device if given. Logs and result bundles go to `build/test.log` /
   `build/test.xcresult` (and `build/test-<device>.*`). Tests come from the shared
   test plan `MaynardGolf.xctestplan` (coverage on). The unit targets run one at a time; the UI tests
   run in parallel on `--workers` clones of the simulator (the plan marks only `MaynardGolfUITests`
   parallelizable). Clones also mean a run never shares a simulator with another checkout's run.
3. **Coverage gate** (`coverage_gate.py`): prints coverage per target and per gated group, and
   fails when a group is under its minimum (TS-UT-02, TS-CI-02). It also writes
   `build/test-coverage.md`, a table to paste into the PR description (TS-CI-03). The old table
   is deleted first, and the script only points you at it when tests and coverage passed.
4. **Color literal lint** (`hex_lint.py`): fails on hex color strings and `Color(red:)` /
   `UIColor(red:)` literals in `MaynardGolf/` and `MaynardUI/` (tests aren't scanned). Colors come
   from the MaynardUI tokens (00-design-system §3).
5. **String Catalog lint** (`catalog_lint.py`), for the app's `Localizable.xcstrings` and MaynardUI's
   `MaynardUI/Resources/Localizable.xcstrings`: fails on strings used in code but missing from
   `Localizable.xcstrings`, and on catalog entries that are stale or no longer used. An entry
   without a translator comment is a warning (X-01). It's skipped, and says so, when the build
   failed.
6. **Pass record:** when everything passed and the tree was clean (by the release rule) from
   start to end, the tree's hash goes in `.git/maynardgolf-tested/`, so `release` can skip testing
   the same source again.

A failed self-test stops the run. After that, every step runs even when an earlier one fails,
then a summary prints. **Exit codes:**

| Code | Meaning |
|---|---|
| 0 | everything passed |
| 1 | a test failed (or a self-test, or the build) |
| 2 | coverage is below the gate |
| 3 | String Catalog or color literal lint failed |
| 4 | release failed: missing key, dirty tree, archive or upload (`release` only) |
| 64 | usage error |

When more than one step fails, the lowest code wins. Everything the script writes is under
`build/`, which git ignores.

## Release (TestFlight, #98)

```sh
scripts/build.sh release --dry-run     # every check, then prints each step; uploads nothing
scripts/build.sh release               # tests, archive, upload, tag, What to Test
scripts/build.sh release --skip-tests  # same, without `build.sh test` (e.g. just ran it)
```

### One-time setup: the App Store Connect API key
1. In App Store Connect › Users and Access › Integrations › App Store Connect API, create a key
   with the **App Manager** role (or use an existing one). Download the `.p8` (only possible once).
2. Keep it **outside the repo** (`*.p8` is also in `.gitignore`; the script refuses a key inside
   the repo):
   ```sh
   mkdir -p ~/.appstoreconnect/private_keys && chmod 700 ~/.appstoreconnect ~/.appstoreconnect/private_keys
   mv ~/Downloads/AuthKey_<KEY_ID>.p8 ~/.appstoreconnect/private_keys/
   chmod 600 ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
   ```
3. Put its values in `~/.appstoreconnect/maynardgolf.env` (mode 600, never committed):
   ```sh
   ASC_KEY_ID=<key id>
   ASC_ISSUER_ID=<issuer id>
   ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8"
   ```
   Variables already in the environment win (handy for CI); `ASC_ENV_FILE` points at another file.
   A missing value or key file fails with exit code 4 and names what's missing.

The Mac also needs the team's signing set up in Xcode (team `N2Z455V6H8`, automatic signing). The
key lets `xcodebuild` create or update the distribution certificate and profiles itself
(`-allowProvisioningUpdates`).

### What `release` does
1. **Key check:** asks App Store Connect for the app (`org.tassinari.MaynardGolf`) with the key.
2. **Clean tree:** refuses any change to a tracked file, and untracked files in `MaynardGolf/`,
   `MaynardUI/`, `Config/` or `scripts/` (they'd change the build). Other untracked files, such as
   Xcode's `xcshareddata/xcodecloud/`, are ignored. A build has to be reproducible from the commit
   it tags. A note prints when you aren't on `version-2`.
3. **Tests:** `build.sh test` (with any `--device` / `--workers` options), unless `--skip-tests`, or
   unless this exact source already passed: every `build.sh test` that passes on a clean tree records
   the tree's hash in `.git/maynardgolf-tested/` (shared by worktrees, never committed). A PR merged
   without other changes on `version-2` has the tree its branch passed with, so the release doesn't
   test it a second time. `--retest` runs the tests anyway. A failure stops the release with that
   step's exit code.
4. **Build number:** `git rev-list --count HEAD`, but always above the newest build already in App
   Store Connect (v1 uploaded builds 1…12). It's passed to `xcodebuild` as
   `CURRENT_PROJECT_VERSION`, so nothing in the repo changes. The marketing version is
   `MARKETING_VERSION` in `Config/App.xcconfig` (1.2, X-18). An existing `build/N` tag stops it.
5. **What to Test notes** (`build/release-notes.txt`): the `feat:` and `fix:` commit subjects since
   the last `build/*` tag, as "New: …" / "Fixed: …" lines (25 at most, then "…and N more").
6. **Archive** a Release build to `build/MaynardGolf.xcarchive` (log: `build/archive.log`).
7. **Export and upload** with `ExportOptions.plist` (`app-store-connect`, `destination = upload`;
   Xcode doesn't touch the build number). Log: `build/upload.log`.
8. **Tag** the commit `build/N` and push the tag.
9. **What to Test:** waits (up to 20 minutes) for App Store Connect to list the build, then sets
   the notes in en-US. If it times out, the upload still counts; paste the notes by hand.

The build then processes in App Store Connect for a while before it shows in TestFlight. It
doesn't stop at "Missing Compliance": `Config/App.xcconfig` sets
`ITSAppUsesNonExemptEncryption = NO` (the app only uses exempt HTTPS and CloudKit encryption). Who gets
it (testers, groups) is set up there, as part of #103.

`asc.py` (the App Store Connect API calls, signed with the key through `openssl`) and `release.py`
(build number, clean-tree rule, notes) are the helpers; both have unit tests here.

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
- `asc.py check|latest-build|whats-new --bundle-id ID …` and `release.py build-number|dirty|notes`:
  the release helpers (`--help` on each).

Their tests and fixture reports are in `scripts/tests/`.
