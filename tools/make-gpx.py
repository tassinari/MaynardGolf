#!/usr/bin/env python3
"""Write the GPX files that simulate a GPS position on the course (#245).

Xcode's Simulate Location menu (the location arrow in the debug bar, while the app runs from Xcode) lists every
`.gpx` file in the project. Picking one moves the simulator's GPS there, or a connected iPhone's while the app is
running from Xcode, so Show my location and the shot lines measure from it (07-hole-play HP-CTL-03, 14-shot-lines).

From `MaynardGolf/MaynardGC.json` it writes into `Simulation/`:

* `Course.gpx`: the course's own coordinate (where the UI-test location mock stands).
* `Hole N Tee.gpx`: hole N's tee box (`--tee`, white by default).
* `Hole N Green.gpx`: the centre of hole N's green.
* `Hole N Walk.gpx`: a walk from that tee through the hole's approach shots to the green centre at walking pace
  (WALK_SPEED m/s). Xcode moves the position between waypoints by their `<time>`.

The files are in the Xcode project's Simulation group but in no target, so they never ship. After the course data
changes, run it again and commit the files; a hole added or removed also needs its files added to (or removed
from) that group in Xcode. `--check` fails when the files on disk don't match the course data (the build script's
self-tests run it):

    python3 tools/make-gpx.py            # rewrite Simulation/
    python3 tools/make-gpx.py --check    # exit 1 if any file is missing, stale or extra
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COURSE = ROOT / "MaynardGolf" / "MaynardGC.json"
OUTPUT = ROOT / "Simulation"

# A brisk walk in metres per second, so a 400-yard hole takes about 4 minutes.
WALK_SPEED = 1.4
# The walk's first timestamp. Fixed, so the files only change when the course does; Xcode uses only the gaps.
START = datetime(2026, 1, 1, tzinfo=timezone.utc)
EARTH_RADIUS = 6_371_000.0


def metres(a: dict, b: dict) -> float:
    """Great-circle distance between two `{latitude, longitude}` points (haversine)."""
    lat1, lat2 = math.radians(a["latitude"]), math.radians(b["latitude"])
    dlat = lat2 - lat1
    dlon = math.radians(b["longitude"] - a["longitude"])
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 2 * EARTH_RADIUS * math.asin(math.sqrt(h))


def gpx(name: str, points: list[tuple[dict, datetime | None]]) -> str:
    """A GPX document with one waypoint per point; a time on each makes Xcode move between them."""
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<gpx version="1.1" creator="tools/make-gpx.py">']
    for point, time in points:
        lines.append(f'    <wpt lat="{point["latitude"]:.7f}" lon="{point["longitude"]:.7f}">')
        lines.append(f"        <name>{name}</name>")
        if time is not None:
            lines.append(f"        <time>{time.strftime('%Y-%m-%dT%H:%M:%SZ')}</time>")
        lines.append("    </wpt>")
    lines.append("</gpx>")
    return "\n".join(lines) + "\n"


def walk(route: list[dict]) -> list[tuple[dict, datetime]]:
    """Each point of `route` with the time a walker at WALK_SPEED reaches it, from START."""
    timed, elapsed = [], 0.0
    for index, point in enumerate(route):
        if index:
            elapsed += metres(route[index - 1], point) / WALK_SPEED
        timed.append((point, START + timedelta(seconds=round(elapsed))))
    return timed


def files(course: dict, tee: str) -> dict[str, str]:
    """Every file name and its contents, for `course` (the MaynardGC.json shape)."""
    out = {"Course.gpx": gpx("Course", [(course["coordinate"], None)])}
    for hole in course["holes"]:
        number = hole["number"]
        start = hole["teeBoxes"][tee]
        green = hole["greenCoordinates"]["center"]
        out[f"Hole {number} Tee.gpx"] = gpx(f"Hole {number} {tee} tee", [(start, None)])
        out[f"Hole {number} Green.gpx"] = gpx(f"Hole {number} green", [(green, None)])
        route = [start, *hole.get("approachShots", []), green]
        out[f"Hole {number} Walk.gpx"] = gpx(f"Hole {number} walk", walk(route))
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tee", default="white", help="the tee box the Tee and Walk files start from (default white)")
    parser.add_argument("--check", action="store_true", help="only check Simulation/ is up to date; exit 1 if not")
    parser.add_argument("--course", type=Path, default=COURSE, help=argparse.SUPPRESS)
    parser.add_argument("--output", type=Path, default=OUTPUT, help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    course = json.loads(args.course.read_text())
    if not all(args.tee in hole["teeBoxes"] for hole in course["holes"]):
        parser.error(f"not every hole has a {args.tee!r} tee box")
    wanted = files(course, args.tee)
    existing = {path.name for path in args.output.glob("*.gpx")} if args.output.is_dir() else set()

    if args.check:
        stale = [name for name, text in wanted.items()
                 if not (args.output / name).is_file() or (args.output / name).read_text() != text]
        extra = sorted(existing - wanted.keys())
        for name in stale:
            print(f"missing or stale: {name}", file=sys.stderr)
        for name in extra:
            print(f"not from the course data: {name}", file=sys.stderr)
        if stale or extra:
            print("Run python3 tools/make-gpx.py and commit Simulation/.", file=sys.stderr)
            return 1
        return 0

    args.output.mkdir(exist_ok=True)
    for name in sorted(existing - wanted.keys()):
        (args.output / name).unlink()
        print(f"removed {name} (remove it from the Xcode project's Simulation group too)")
    for name, text in wanted.items():
        (args.output / name).write_text(text)
    print(f"wrote {len(wanted)} files to {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
