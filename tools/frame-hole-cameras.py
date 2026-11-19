#!/usr/bin/env python3
"""Frame each hole's camera so the shot line's points clear Hole play's controls (16-hole-map HM-CAM-02, #186).

For every hole it takes the camera in `tools/course-cameras.json` and the hole's tee boxes, approach shots and
pin (green center) from `MaynardGolf/MaynardGC.json`, and finds the smallest change to the camera (a shift and,
only when the points don't fit, a zoom out; never a new rotation) after which, on every supported iPhone at
rest:

* every point is at least SIDE pt from the left and right edges;
* every point is at least TOP_CLEAR pt below the top (under the Exit / Card bar) and at least BOTTOM_CLEAR pt
  above the bottom (over the bottom card);
* the pin is left of the hole card (at least HOLE_CARD pt from the right edge);
* everything the screen shows is inside the master, so the crop never has an empty edge.

It rewrites the cameras file in place (or prints the changes with --dry-run). Then re-cut the imagery from
the master, which writes the new cameras into `CourseImagery.json`:

    .venv/bin/python tools/frame-hole-cameras.py
    .venv/bin/python tools/cut-course-map.py /path/to/fullmapFull.png

The same limits are checked by `CourseDataTests` (SL-TS-07), so data or cameras that break them fail the build.
The camera math mirrors `ScreenCamera` and `tools/cut-course-map.py`.
"""

from __future__ import annotations

import argparse
import cmath
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CAMERAS = ROOT / "tools" / "course-cameras.json"
COURSE = ROOT / "MaynardGolf" / "MaynardGC.json"

# Supported iPhone screens in points (as tools/cut-course-map.py), and whether each has a home indicator.
SCREENS = [(375, 667, False), (375, 812, True), (390, 844, True), (393, 852, True), (402, 874, True),
           (414, 896, True), (428, 926, True), (430, 932, True), (440, 956, True)]
SIDE = 24            # pt from the left and right edges (SL-TG-04)
HOLE_CARD = 150      # pt from the right edge that the hole card and map buttons cover (HP-HOLE, HP-CTL)
ZOOM_STEP = 0.005    # how finely the zoom out is searched
GRID = 60            # shifts tried along each axis inside the allowed range, for the master-edge rule


def clears(home_indicator: bool) -> tuple[float, float]:
    """(TOP_CLEAR, BOTTOM_CLEAR) in pt: below the top bar, above the bottom card (its tallest, one player)."""
    return (110.0, 150.0) if home_indicator else (74.0, 116.0)


def map_point(lat: float, lon: float, master: dict) -> complex:
    """A GPS coordinate on the master, as `CourseOverview.mapPoint`."""
    s, w, n, e = master["boundsSWNE"]
    return complex((lon - w) / (e - w) * master["width"], (n - lat) / (n - s) * master["height"])


def fill(screen_w: float, screen_h: float, hole: dict) -> float:
    """Screen pt per hole-image pixel (aspect-fill), as `ScreenCamera`."""
    return max(screen_w / hole["width"], screen_h / hole["height"])


def inside_master(center: complex, theta: float, per_pt: dict, master: dict) -> bool:
    """Whether every screen's visible corners, around `center`, are on the master."""
    rot = cmath.exp(1j * theta)
    for (w, h), pp in per_pt.items():
        for sx in (-1, 1):
            for sy in (-1, 1):
                corner = center + rot * complex(sx * w / 2 * pp, sy * h / 2 * pp)
                if not (0 <= corner.real <= master["width"] and 0 <= corner.imag <= master["height"]):
                    return False
    return True


def frame(cam: dict, holes_points: list[tuple[str, complex]], hole_image: dict, master: dict) -> dict:
    """The smallest shift (and zoom out, if needed) that puts every point inside the limits on every screen."""
    theta = math.radians(cam["rotationDegrees"])
    center = complex(*cam["mapCenter"])
    mppp = cam["mapPixelsPerHolePixel"]
    # Each point in frame axes, relative to the center, in master pixels (x right, y down on screen).
    rel = [(kind, cmath.exp(-1j * theta) * (p - center)) for kind, p in holes_points]
    zoom = 1.0
    while zoom < 3:
        lo_x, hi_x, lo_y, hi_y = -math.inf, math.inf, -math.inf, math.inf
        scales = {}
        for w, h, home in SCREENS:
            top, bottom = clears(home)
            per_pt = mppp * zoom / fill(w, h, hole_image)  # master px per screen pt with this zoom
            scales[(w, h)] = per_pt
            for kind, r in rel:
                # On screen: offset = (r - delta) / per_pt, about the screen's middle; delta is the shift.
                left, right = SIDE - w / 2, (w - HOLE_CARD if kind == "pin" else w - SIDE) - w / 2
                lo_x, hi_x = max(lo_x, r.real - right * per_pt), min(hi_x, r.real - left * per_pt)
                lo_y, hi_y = max(lo_y, r.imag - (h - bottom - h / 2) * per_pt), min(hi_y, r.imag - (top - h / 2) * per_pt)
        if lo_x <= hi_x and lo_y <= hi_y:
            # The allowed shift nearest no shift whose view stays on the master.
            xs = [lo_x + (hi_x - lo_x) * i / GRID for i in range(GRID + 1)] + [min(max(0.0, lo_x), hi_x)]
            ys = [lo_y + (hi_y - lo_y) * i / GRID for i in range(GRID + 1)] + [min(max(0.0, lo_y), hi_y)]
            options = sorted((complex(x, y) for x in xs for y in ys), key=abs)
            for delta in options:
                new_center = center + cmath.exp(1j * theta) * delta
                if inside_master(new_center, theta, scales, master):
                    return {**cam, "mapCenter": [round(new_center.real, 2), round(new_center.imag, 2)],
                            "mapPixelsPerHolePixel": round(mppp * zoom, 5)}
        zoom += ZOOM_STEP
    raise SystemExit(f"hole {cam['hole']}: can't fit its points even zoomed out 3x")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--cameras", type=Path, default=CAMERAS)
    p.add_argument("--course", type=Path, default=COURSE)
    p.add_argument("--dry-run", action="store_true", help="print the changes; don't write")
    args = p.parse_args()
    data = json.loads(args.cameras.read_text())
    course = json.loads(args.course.read_text())
    holes = {h["number"]: h for h in course["holes"]}
    framed = []
    for cam in data["holes"]:
        hole = holes[cam["hole"]]
        pt = lambda c: map_point(c["latitude"], c["longitude"], data["master"])
        points = [("tee", pt(c)) for c in hole["teeBoxes"].values()] + [("approach", pt(c)) for c in hole["approachShots"]]
        points.append(("pin", pt(hole["greenCoordinates"]["center"])))
        new = frame(cam, points, data["holeImage"], data["master"])
        moved = abs(complex(*new["mapCenter"]) - complex(*cam["mapCenter"]))
        print(f"hole {cam['hole']}: shift {moved:6.1f} master px, zoom {new['mapPixelsPerHolePixel'] / cam['mapPixelsPerHolePixel']:.3f}")
        framed.append(new)
    if not args.dry_run:
        data["holes"] = framed
        args.cameras.write_text(json.dumps(data, indent=2) + "\n")
        print(f"wrote {args.cameras}")


if __name__ == "__main__":
    main()
