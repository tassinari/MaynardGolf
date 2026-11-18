#!/usr/bin/env bash
# MaynardGolf build script (story #99). See scripts/README.md.
#
#   scripts/build.sh test        unit + UI tests on one iPhone (iPhone 18 Pro), coverage gate,
#                                String Catalog lint
#   scripts/build.sh test-unit   unit tests only (coverage printed, not gated)
#   scripts/build.sh test-ui     UI tests only (coverage printed, not gated)
#   scripts/build.sh lint        build, then String Catalog lint only
#   scripts/build.sh selftest    the build scripts' own unit tests
#   scripts/build.sh release     test, archive (Release), upload to TestFlight, tag build/N, set What
#                                to Test (#98). --dry-run checks and prints every step, uploads
#                                nothing; --skip-tests skips `test`. Needs the App Store Connect key
#                                (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH, or ~/.appstoreconnect/maynardgolf.env).
#
# Options: --device NAME (default "iPhone 18 Pro"), --os MAJOR[.MINOR] (default 27, the device's
# runtime; the app targets iOS 26), --udid UDID, --devices "NAME,NAME" (test: also run the UI tests
# on each of these, e.g. "iPhone 17e,iPhone 18 Pro Max" for the smallest and largest), --workers N
# (UI tests run on N clones of the simulator at once; default 3, 1 runs them one at a time),
# --retest (release: run the tests even when this source already passed them).
# Exit codes: 0 pass, 1 test failure, 2 coverage below the gate, 3 lint failure, 4 release failure
# (key, dirty tree, archive, upload), 64 usage error.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$ROOT/scripts"
BUILD="$ROOT/build"
DERIVED="$BUILD/DerivedData"
PROJECT="$ROOT/MaynardGolf.xcodeproj"
SCHEME="MaynardGolf"
CATALOG="$ROOT/MaynardGolf/Localizable.xcstrings"
UI_CATALOG="$ROOT/MaynardUI/Resources/Localizable.xcstrings"

EXIT_TESTS=1
EXIT_COVERAGE=2
EXIT_LINT=3
EXIT_RELEASE=4
EXIT_USAGE=64

# Release (#98). The bundle id and team must match the app target and scripts/ExportOptions.plist.
BUNDLE_ID="org.tassinari.MaynardGolf"
ARCHIVE="$BUILD/MaynardGolf.xcarchive"
EXPORT="$BUILD/export"
ASC_ENV_FILE="${ASC_ENV_FILE:-$HOME/.appstoreconnect/maynardgolf.env}"
RELEASE_BRANCH="version-2"

usage() {
    # The header comment, up to the first line that isn't a comment.
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"
    exit "$EXIT_USAGE"
}

command="${1:-}"
[[ -z "$command" || "$command" == "-h" || "$command" == "--help" ]] && usage
shift

device="iPhone 18 Pro"
extra_devices=""
os_version="27"
udid=""
dry_run=0
skip_tests=0
retest=0
workers=3
passthrough=()   # device options, forwarded to `test` when `release` runs it
while [[ $# -gt 0 ]]; do
    case "$1" in
        --device) device="${2:?--device needs a name}"; passthrough+=("$1" "$2"); shift 2 ;;
        --devices) extra_devices="${2:?--devices needs a comma-separated list}"; passthrough+=("$1" "$2"); shift 2 ;;
        --os) os_version="${2:?--os needs a version}"; passthrough+=("$1" "$2"); shift 2 ;;
        --udid) udid="${2:?--udid needs a value}"; passthrough+=("$1" "$2"); shift 2 ;;
        --workers) workers="${2:?--workers needs a number}"; passthrough+=("$1" "$2"); shift 2 ;;
        --retest) retest=1; shift ;;
        --dry-run) dry_run=1; shift ;;
        --skip-tests) skip_tests=1; shift ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

selftest() {
    echo "== Build script self-tests"
    python3 -m unittest discover -s "$SCRIPTS/tests" -t "$ROOT" -q
}

resolve_simulator() {
    if [[ -z "$udid" ]]; then
        udid="$(python3 "$SCRIPTS/simulator.py" --name "$device" --os "$os_version")" || exit "$EXIT_TESTS"
    fi
    echo "== Simulator: $device (iOS $os_version) $udid"
    # Boot and wait until it's fully up: launching into a simulator that is still finishing its
    # first boot fails with "Busy (Application failed preflight checks)".
    xcrun simctl bootstatus "$udid" -b > /dev/null || exit "$EXIT_TESTS"
}

[[ "$workers" =~ ^[1-9][0-9]*$ ]] || { echo "--workers must be a positive number" >&2; usage; }

# UI tests run in parallel on clones of the simulator: the test plan marks only MaynardGolfUITests
# parallelizable, so the unit targets stay on the device itself. Only the worker count is passed:
# `-parallel-testing-enabled YES` would override the plan and spread the unit tests over the busy
# clones too, where timing-sensitive ones fail. Each UI test launches its own app with its own seed,
# so they don't depend on each other. Clones also keep a run off a simulator another checkout uses.
parallel_args() {
    if [[ $workers -gt 1 ]]; then
        echo "-parallel-testing-worker-count $workers"
    else
        echo "-parallel-testing-enabled NO"
    fi
}

# Passing runs are recorded by the source tree they tested, so `release` can skip a second 10-minute
# run of the same code (for example the merge of a PR whose branch already passed). The record lives
# in the repository's own git directory, shared by its worktrees and never committed.
tested_dir() {
    echo "$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/maynardgolf-tested"
}

# The tree hash of HEAD when the working tree is clean (by release.py's rule), else empty.
clean_tree() {
    git -C "$ROOT" status --porcelain -z | python3 "$SCRIPTS/release.py" dirty > /dev/null || return 0
    git -C "$ROOT" rev-parse 'HEAD^{tree}'
}

# run_tests NAME [xcodebuild args…] — runs the tests, keeps the log and result bundle under build/.
run_tests() {
    local name="$1"; shift
    local result="$BUILD/$name.xcresult"
    rm -rf "$result"
    mkdir -p "$BUILD"
    echo "== xcodebuild test ($name), log: build/$name.log"
    xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination "id=$udid" \
        -derivedDataPath "$DERIVED" -enableCodeCoverage YES -resultBundlePath "$result" "$@" \
        > "$BUILD/$name.log" 2>&1
    local status=$?
    # Test counts, failures (trimmed: simulator errors are very long) and the result line.
    grep -E "^(✔|✘) Test run|^[[:space:]]*Executed [0-9]+ tests?, with|: error: |^\*\* TEST" "$BUILD/$name.log" \
        | sed -E -e 's/^[[:space:]]+//' -e 's/ \([0-9.]+\) seconds/ seconds/' | cut -c1-240 | awk '!seen[$0]++' 
    return "$status"
}

coverage() {
    local name="$1"; shift
    # Never leave an earlier run's table behind: it could be pasted into a PR as this run's.
    rm -f "$BUILD/$name-coverage.json" "$BUILD/$name-coverage.md"
    xcrun xccov view --report --json "$BUILD/$name.xcresult" > "$BUILD/$name-coverage.json" || return "$EXIT_COVERAGE"
    python3 "$SCRIPTS/coverage_gate.py" "$BUILD/$name-coverage.json" --markdown "$BUILD/$name-coverage.md" "$@"
}

lint() {
    echo "== String Catalog lint"
    python3 "$SCRIPTS/catalog_lint.py" --catalog "$CATALOG" --derived-data "$DERIVED"
    local catalog=$?
    echo "== String Catalog lint (MaynardUI)"
    python3 "$SCRIPTS/catalog_lint.py" --catalog "$UI_CATALOG" --derived-data "$DERIVED" --target MaynardUI || catalog=$EXIT_LINT
    echo "== Color literal lint"
    python3 "$SCRIPTS/hex_lint.py"
    local colors=$?
    [[ $catalog == 0 && $colors == 0 ]] || return "$EXIT_LINT"
}

summary() {
    local tests="$1" cov="$2" lint_status="$3"
    echo
    echo "== Summary"
    [[ "$tests" == skip ]] || echo "  tests:    $([[ $tests == 0 ]] && echo pass || echo FAIL)"
    [[ "$cov" == skip ]] || echo "  coverage: $([[ $cov == 0 ]] && echo pass || echo FAIL)"
    [[ "$lint_status" == skip ]] || echo "  lint:     $([[ $lint_status == 0 ]] && echo pass || echo FAIL)"
    if [[ "$tests" != skip && "$tests" != 0 ]]; then exit "$EXIT_TESTS"; fi
    if [[ "$cov" != skip && "$cov" != 0 ]]; then exit "$EXIT_COVERAGE"; fi
    if [[ "$lint_status" != skip && "$lint_status" != 0 ]]; then exit "$EXIT_LINT"; fi
    exit 0
}

# ---- release (#98) --------------------------------------------------------------------------

fail_release() { echo "release: $*" >&2; exit "$EXIT_RELEASE"; }

# Prints a command as it will run, with the key's values shown as their variable names.
print_command() {
    local arg out="   \$"
    for arg in "$@"; do
        case "$arg" in
            "${ASC_KEY_ID:-}") out+=' $ASC_KEY_ID' ;;
            "${ASC_ISSUER_ID:-}") out+=' $ASC_ISSUER_ID' ;;
            "${ASC_KEY_PATH:-}") out+=' $ASC_KEY_PATH' ;;
            *) out+=" $(printf '%q' "$arg")" ;;
        esac
    done
    echo "$out"
}

# step DESCRIPTION COMMAND… — prints the command; runs it unless --dry-run.
step() {
    local description="$1"; shift
    echo "== $description"
    print_command "$@"
    [[ $dry_run == 1 ]] && return 0
    "$@"
}

# logged_step LOG DESCRIPTION COMMAND… — like step, with the output in build/LOG.
logged_step() {
    local log="$1" description="$2"; shift 2
    echo "== $description, log: build/$log"
    print_command "$@"
    [[ $dry_run == 1 ]] && return 0
    "$@" > "$BUILD/$log" 2>&1
}

# The key's three values, from the environment or the env file outside the repo. Never echoed.
load_credentials() {
    if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" || -z "${ASC_KEY_PATH:-}" ]] && [[ -f "$ASC_ENV_FILE" ]]; then
        set -a
        # shellcheck disable=SC1090
        source "$ASC_ENV_FILE"
        set +a
    fi
    local missing=()
    for name in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH; do
        [[ -n "${!name:-}" ]] || missing+=("$name")
    done
    [[ ${#missing[@]} == 0 ]] || fail_release "missing ${missing[*]}: set them, or put them in $ASC_ENV_FILE (scripts/README.md, Release)"
    ASC_KEY_PATH="${ASC_KEY_PATH/#\~/$HOME}"
    [[ -f "$ASC_KEY_PATH" ]] || fail_release "ASC_KEY_PATH doesn't exist: $ASC_KEY_PATH"
    case "$(cd "$(dirname "$ASC_KEY_PATH")" && pwd -P)/" in
        "$(cd "$ROOT" && pwd -P)/"*) fail_release "the .p8 key is inside the repo; move it outside (for example ~/.appstoreconnect/private_keys/)" ;;
    esac
}

release() {
    local auth=(-allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH"
                -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
    [[ $dry_run == 1 ]] && echo "== Dry run: checks run, nothing is archived, uploaded or tagged"

    echo "== App Store Connect key"
    python3 "$SCRIPTS/asc.py" check --bundle-id "$BUNDLE_ID" > /dev/null || fail_release "the API key check failed"
    echo "   ok ($BUNDLE_ID)"

    # The commit this release is built from. Checked again before the archive: Xcode or another
    # session can switch the checkout or edit files during the tests (CLAUDE.md, Git safety).
    local head
    head="$(git -C "$ROOT" rev-parse HEAD)" || fail_release "not a git checkout"

    echo "== Clean tree"
    local blocking would_block=0
    if ! blocking="$(git -C "$ROOT" status --porcelain -z | python3 "$SCRIPTS/release.py" dirty)"; then
        echo "$blocking" | sed 's/^/   /'
        if [[ $dry_run == 1 ]]; then
            echo "   (a real release would stop here: commit or stash these first)"
            would_block=1
        else
            fail_release "uncommitted changes; a release must be reproducible from the commit it tags"
        fi
    else
        echo "   ok"
    fi
    local branch
    branch="$(git -C "$ROOT" branch --show-current)"
    [[ "$branch" == "$RELEASE_BRANCH" ]] || echo "   note: releasing from '$branch', not $RELEASE_BRANCH"

    local tree passed
    tree="$(git -C "$ROOT" rev-parse "$head^{tree}")"
    passed="$(cat "$(tested_dir)/$tree" 2>/dev/null || true)"
    if [[ $skip_tests == 1 ]]; then
        echo "== Tests: skipped (--skip-tests)"
    elif [[ $retest == 0 && -n "$passed" ]]; then
        echo "== Tests: this source already passed build.sh test ($passed); --retest runs them again"
    else
        step "Tests (build.sh test)" "${BASH_SOURCE[0]}" test "${passthrough[@]+"${passthrough[@]}"}" || exit $?
    fi

    echo "== Build number"
    local latest count number version
    latest="$(python3 "$SCRIPTS/asc.py" latest-build --bundle-id "$BUNDLE_ID")" || fail_release "couldn't read the latest build"
    count="$(git -C "$ROOT" rev-list --count HEAD)"
    number="$(python3 "$SCRIPTS/release.py" build-number --git-count "$count" ${latest:+--latest "$latest"})" || fail_release "no build number"
    # The app target only: the test targets in the scheme have their own MARKETING_VERSION.
    version="$(xcodebuild -project "$PROJECT" -target MaynardGolf -configuration Release -showBuildSettings 2>/dev/null \
        | awk '$1 == "MARKETING_VERSION" { print $3; exit }')"
    [[ -n "$version" ]] || fail_release "couldn't read MARKETING_VERSION"
    ! git -C "$ROOT" rev-parse -q --verify "refs/tags/build/$number" > /dev/null || fail_release "tag build/$number already exists"
    echo "   version $version, build $number (commits: $count, newest in App Store Connect: ${latest:-none})"

    echo "== What to Test (build/release-notes.txt)"
    local since range
    since="$(git -C "$ROOT" describe --tags --match 'build/*' --abbrev=0 2>/dev/null || true)"
    range="${since:+$since..}HEAD"
    mkdir -p "$BUILD"
    git -C "$ROOT" log --no-merges --format=%s "$range" | python3 "$SCRIPTS/release.py" notes > "$BUILD/release-notes.txt" \
        || fail_release "couldn't write the What to Test notes"
    echo "   since ${since:-the first commit}:"
    sed 's/^/   /' "$BUILD/release-notes.txt"

    if [[ $dry_run == 0 ]]; then
        [[ "$(git -C "$ROOT" rev-parse HEAD)" == "$head" ]] \
            || fail_release "HEAD moved during the release (was ${head:0:9}); start again"
        blocking="$(git -C "$ROOT" status --porcelain -z | python3 "$SCRIPTS/release.py" dirty)" \
            || fail_release "the tree changed during the release; start again:"$'\n'"$blocking"
        rm -rf "$ARCHIVE" "$EXPORT"   # only on a real run: a dry run keeps the last archive
    fi
    logged_step archive.log "Archive (Release)" \
        xcodebuild archive -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
        -destination "generic/platform=iOS" -archivePath "$ARCHIVE" -derivedDataPath "$BUILD/ReleaseDerivedData" \
        CURRENT_PROJECT_VERSION="$number" "${auth[@]}" \
        || { tail -20 "$BUILD/archive.log" >&2; fail_release "archive failed, see build/archive.log"; }
    logged_step upload.log "Export and upload to TestFlight" \
        xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$SCRIPTS/ExportOptions.plist" \
        -exportPath "$EXPORT" "${auth[@]}" \
        || { tail -20 "$BUILD/upload.log" >&2; fail_release "export or upload failed, see build/upload.log"; }

    step "Tag build/$number" git -C "$ROOT" tag -a "build/$number" -m "TestFlight $version ($number)" "$head" \
        || fail_release "couldn't tag"
    step "Push the tag" git -C "$ROOT" push -q origin "build/$number" \
        || echo "   warning: the tag wasn't pushed; run: git push origin build/$number" >&2

    # The upload is done; a notes failure only means pasting them by hand.
    step "Set What to Test (waits for App Store Connect to list the build)" python3 "$SCRIPTS/asc.py" whats-new \
        --bundle-id "$BUNDLE_ID" --version "$version" --build "$number" --notes-file "$BUILD/release-notes.txt" \
        || echo "   warning: What to Test wasn't set; paste build/release-notes.txt in App Store Connect" >&2

    echo
    if [[ $dry_run == 1 ]]; then
        if [[ $would_block == 1 ]]; then
            echo "== Dry run done, but a real release would refuse: the tree isn't clean"
            exit "$EXIT_RELEASE"
        fi
        echo "== Dry run done: $version ($number) would be uploaded"
    else
        echo "== Uploaded $version ($number). It shows in App Store Connect › TestFlight once processed."
    fi
}

case "$command" in
    selftest)
        selftest || exit "$EXIT_TESTS"
        ;;
    test)
        tree_before="$(clean_tree)"
        selftest || exit "$EXIT_TESTS"
        resolve_simulator
        # shellcheck disable=SC2046
        run_tests test $(parallel_args); tests=$?
        coverage test; cov=$?
        if [[ -n "$extra_devices" ]]; then
            # Optional extra UI runs (X-19 checks across sizes). Coverage comes from the first run.
            main_udid="$udid"
            IFS=',' read -r -a names <<< "$extra_devices"
            for name in "${names[@]}"; do
                name="$(echo "$name" | sed 's/^ *//; s/ *$//')"
                if ! udid="$(python3 "$SCRIPTS/simulator.py" --name "$name" --os any)"; then
                    tests=$EXIT_TESTS  # an unknown device fails the run but keeps the lint and summary
                    continue
                fi
                echo "== Simulator: $name $udid"
                xcrun simctl bootstatus "$udid" -b > /dev/null || { tests=$EXIT_TESTS; continue; }
                # shellcheck disable=SC2046
                run_tests "test-$(echo "$name" | tr ' ' '-')" -only-testing:MaynardGolfUITests $(parallel_args) || tests=$EXIT_TESTS
            done
            udid="$main_udid"
        fi
        if [[ $tests != 0 ]] && ! compgen -G "$DERIVED/Build/Intermediates.noindex/*.build/*/MaynardGolf.build/Objects-normal/*/*.stringsdata" > /dev/null; then
            echo "== String Catalog lint: skipped (the build failed, so there are no extracted strings)"
            echo "== Color literal lint"
            python3 "$SCRIPTS/hex_lint.py"; lint_status=$?   # needs no build output
        else
            lint; lint_status=$?
        fi
        if [[ $tests == 0 && $cov == 0 && $lint_status == 0 && -n "$tree_before" && "$(clean_tree)" == "$tree_before" ]]; then
            mkdir -p "$(tested_dir)"
            echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $(git -C "$ROOT" rev-parse --short HEAD) $device" > "$(tested_dir)/$tree_before"
            echo "== Recorded a pass for this source (tree ${tree_before:0:9}); release won't test it again"
        fi
        if [[ $tests == 0 && $cov == 0 ]]; then
            echo "  (Markdown for the PR: build/test-coverage.md)"
        elif [[ -f "$BUILD/test-coverage.md" ]]; then
            echo "  (build/test-coverage.md shows this failing run; don't paste it as a pass)"
        fi
        summary "$tests" "$cov" "$lint_status"
        ;;
    test-unit)
        resolve_simulator
        run_tests test-unit -only-testing:MaynardGolfTests; tests=$?
        coverage test-unit --report-only
        summary "$tests" skip skip
        ;;
    test-ui)
        resolve_simulator
        # shellcheck disable=SC2046
        run_tests test-ui -only-testing:MaynardGolfUITests $(parallel_args); tests=$?
        coverage test-ui --report-only
        summary "$tests" skip skip
        ;;
    lint)
        resolve_simulator
        echo "== xcodebuild build-for-testing, log: build/lint.log"
        mkdir -p "$BUILD"
        xcodebuild build-for-testing -project "$PROJECT" -scheme "$SCHEME" -destination "id=$udid" \
            -derivedDataPath "$DERIVED" > "$BUILD/lint.log" 2>&1 || { echo "Build failed, see build/lint.log"; exit "$EXIT_TESTS"; }
        lint; lint_status=$?
        summary skip skip "$lint_status"
        ;;
    release)
        load_credentials
        release
        ;;
    *)
        echo "Unknown command: $command" >&2
        usage
        ;;
esac
