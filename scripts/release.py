#!/usr/bin/env python3
"""Pure release logic for `build.sh release` (#98): build number, clean-tree check, What to Test notes.

Kept free of network and Xcode so it's unit tested (scripts/tests/test_release.py). `build.sh` feeds
it git output and the latest build number from App Store Connect (asc.py).

    release.py build-number --git-count N --latest N   prints the build number to use
    release.py dirty                                    reads `git status --porcelain -z` on stdin;
                                                        prints what blocks a release, exits 1 if any
    release.py notes                                    reads commit subjects on stdin (newest first);
                                                        prints the What to Test text
"""

import argparse
import sys

# Untracked files here change what's built or how it's exported: the app and MaynardUI use
# folder-synchronized groups, so anything dropped into those folders is compiled or bundled, and
# scripts/ holds the release script and ExportOptions.plist. Untracked files elsewhere (for example
# Xcode's own xcshareddata/xcodecloud) can't change the upload and don't block a release.
BUILD_INPUTS = ("MaynardGolf/", "MaynardUI/", "Config/", "scripts/", "MaynardGolf.xcodeproj/project.pbxproj")

# Conventional-commit types that testers care about, and how each is labelled in the notes.
NOTE_TYPES = {"feat": "New", "fix": "Fixed"}

# App Store Connect's limit for a build's What to Test text.
WHATS_NEW_LIMIT = 4000
MAX_NOTE_LINES = 25


def next_build_number(git_count, latest_uploaded):
    """The build number for this upload: `git rev-list --count HEAD`, so a build maps to a commit,
    but always above the newest build already in App Store Connect (uploads must increase, and v1's
    builds 1…12 are already there). `latest_uploaded` is None when the app has no builds."""
    if git_count < 1:
        raise ValueError("git count must be positive")
    floor = (latest_uploaded or 0) + 1
    return max(git_count, floor)


def blocking_changes(porcelain):
    """The entries of `git status --porcelain -z` that make the tree unfit to release, as "XY path"
    lines: any change to a tracked file, and untracked files inside BUILD_INPUTS. A release must be
    reproducible from the commit it tags. `-z` output is NUL-separated and never quoted, so paths
    with spaces (like `Preview Content/`) match; a rename or copy is followed by its old path."""
    blocking = []
    entries = porcelain.split("\0")
    index = 0
    while index < len(entries):
        entry = entries[index]
        index += 1
        if len(entry) < 4:
            continue
        status, path = entry[:2], entry[3:]
        if "R" in status or "C" in status:
            index += 1  # skip the original path
        if status == "??" and not path.startswith(BUILD_INPUTS):
            continue
        blocking.append(f"{status} {path}")
    return blocking


def whats_new(subjects):
    """What to Test text from commit subjects (newest first): the `feat:` and `fix:` commits, with
    the type replaced by a label and any scope dropped. Other types (docs, refactor, test, chore)
    don't change what testers see. Long lists are cut to MAX_NOTE_LINES with a count of the rest."""
    lines = []
    for subject in subjects:
        subject = subject.strip()
        head, sep, text = subject.partition(":")
        if not sep:
            continue
        kind = head.split("(")[0].rstrip("!").strip().lower()
        if kind in NOTE_TYPES and text.strip():
            lines.append(f"- {NOTE_TYPES[kind]}: {text.strip()}")
    if not lines:
        return "Internal changes only; nothing new to test."
    shown, rest = lines[:MAX_NOTE_LINES], len(lines) - MAX_NOTE_LINES
    if rest > 0:
        shown.append(f"- …and {rest} more")
    text = "\n".join(shown)
    if len(text) > WHATS_NEW_LIMIT:
        text = text[:WHATS_NEW_LIMIT - 1].rsplit("\n", 1)[0] + "\n…"
    return text


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    number = sub.add_parser("build-number")
    number.add_argument("--git-count", type=int, required=True)
    number.add_argument("--latest", type=int, help="newest build number in App Store Connect")
    sub.add_parser("dirty")
    sub.add_parser("notes")
    args = parser.parse_args(argv)

    if args.command == "build-number":
        print(next_build_number(args.git_count, args.latest))
        return 0
    if args.command == "dirty":
        blocking = blocking_changes(sys.stdin.read())
        for line in blocking:
            print(line)
        return 1 if blocking else 0
    print(whats_new(sys.stdin.read().splitlines()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
