#!/usr/bin/env bash
# MaynardGolf build script (story #99). See scripts/README.md.
#
#   scripts/build.sh test        unit + UI tests on the smallest iPhone, UI tests again on the largest,
#                                coverage gate, String Catalog lint
#   scripts/build.sh test-unit   unit tests only (coverage printed, not gated)
#   scripts/build.sh test-ui     UI tests only (coverage printed, not gated)
#   scripts/build.sh lint        build, then String Catalog lint only
#   scripts/build.sh selftest    the build scripts' own unit tests
#
# Options: --device NAME (default "iPhone 17e", the smallest iOS 26 iPhone), --large-device NAME
# (default "iPhone 17 Pro Max"), --one-device (skip the large-device UI run), --os MAJOR[.MINOR]
# (default 26), --udid UDID.
# Exit codes: 0 pass, 1 test failure, 2 coverage below the gate, 3 lint failure, 64 usage error.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$ROOT/scripts"
BUILD="$ROOT/build"
DERIVED="$BUILD/DerivedData"
PROJECT="$ROOT/MaynardGolf.xcodeproj"
SCHEME="MaynardGolf"
CATALOG="$ROOT/MaynardGolf/Localizable.xcstrings"

EXIT_TESTS=1
EXIT_COVERAGE=2
EXIT_LINT=3
EXIT_USAGE=64

usage() {
    sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "$EXIT_USAGE"
}

command="${1:-}"
[[ -z "$command" || "$command" == "-h" || "$command" == "--help" ]] && usage
shift

device="iPhone 17e"
large_device="iPhone 17 Pro Max"
one_device=false
os_version="26"
udid=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --device) device="${2:?--device needs a name}"; shift 2 ;;
        --large-device) large_device="${2:?--large-device needs a name}"; shift 2 ;;
        --one-device) one_device=true; shift ;;
        --os) os_version="${2:?--os needs a version}"; shift 2 ;;
        --udid) udid="${2:?--udid needs a value}"; shift 2 ;;
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

case "$command" in
    selftest)
        selftest || exit "$EXIT_TESTS"
        ;;
    test)
        selftest || exit "$EXIT_TESTS"
        resolve_simulator
        run_tests test; tests=$?
        coverage test; cov=$?
        if [[ $one_device == false ]]; then
            # X-19, TS-UI-06: no screen may rely on one device size, so the UI tests run on the largest
            # iPhone too. Coverage comes from the first run.
            small_udid="$udid"
            udid="$(python3 "$SCRIPTS/simulator.py" --name "$large_device" --os "$os_version")" || exit "$EXIT_TESTS"
            echo "== Simulator: $large_device (iOS $os_version) $udid"
            xcrun simctl bootstatus "$udid" -b > /dev/null || exit "$EXIT_TESTS"
            run_tests test-large -only-testing:MaynardGolfUITests || tests=$EXIT_TESTS
            udid="$small_udid"
        fi
        if [[ $tests != 0 ]] && ! compgen -G "$DERIVED/Build/Intermediates.noindex/*.build/*/MaynardGolf.build/Objects-normal/*/*.stringsdata" > /dev/null; then
            echo "== String Catalog lint: skipped (the build failed, so there are no extracted strings)"
            lint_status=skip
        else
            lint; lint_status=$?
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
        run_tests test-ui -only-testing:MaynardGolfUITests; tests=$?
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
    *)
        echo "Unknown command: $command" >&2
        usage
        ;;
esac
