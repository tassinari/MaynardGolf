#!/usr/bin/env python3
"""Cut the course master into the pieces the app ships (16-hole-map HM-MAP-02/07, HM-CD-01/02).

For every hole it writes a **hole crop**: the hole's 2048 x 4096 camera frame, cut from the master,
rotated upright and sized for the largest supported iPhone. For every swipe (1->2 ... 8->9, 9->1)
it writes a **transition crop**: the map-aligned area that any frame of that swipe shows on any
supported iPhone, at a fraction of the master's resolution. It also writes the **overview**: the
whole master, north up, at a sixth of its resolution, for the Course map button (HM-OV-01).
`CourseImagery.json` records where every piece sits on the master so the app can draw it through the
hole cameras.

The master is only read, never changed. Areas past the master's edge come out transparent.

Usage:
    python3 -m venv .venv && .venv/bin/pip install -r tools/requirements.txt
    .venv/bin/python tools/cut-course-map.py /path/to/fullmapFull.png

To add or refresh only the overview, leaving the other files and their placements untouched:
    .venv/bin/python tools/cut-course-map.py /path/to/fullmapFull.png --overview-only

If the master was extended, pass how far the old image moved inside the new one and the new bounds:
    ... --shift 600 520 --bounds 42.4400 -71.4540 42.4462 -71.4434
"""

from __future__ import annotations

import argparse
import cmath
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image
import pillow_heif

Image.MAX_IMAGE_PIXELS = None
pillow_heif.register_heif_opener()

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CAMERAS = ROOT / "tools" / "course-cameras.json"
DEFAULT_OUT = ROOT / "MaynardGolf" / "CourseImagery"

# Supported iPhone screens (iOS 18+): width and height in points, and pixels per point.
SCREENS = [
    (375, 667, 2),   # SE 2nd/3rd gen
    (375, 812, 3),   # 12/13 mini
    (390, 844, 3),   # 12/13/14, 16e
    (393, 852, 3),   # 14 Pro/15/16
    (402, 874, 3),   # 16 Pro/17
    (414, 896, 3),   # 11 Pro Max, XS Max (11/XR are 2x; 3x is the larger need)
    (428, 926, 3),   # 12/13 Pro Max, 14 Plus
    (430, 932, 3),   # 14 Pro Max/15 Plus/16 Plus
    (440, 956, 3),   # 16 Pro Max/17 Pro Max
]
STEPS = 240          # progress samples per swipe when measuring its area
PAD = 2              # extra master pixels around each transition crop


@dataclass(frozen=True)
class Camera:
    hole: int
    center: complex          # master pixels
    rotation_degrees: float  # hole-image axes -> master axes
    mppp: float              # master pixels per hole-image pixel


# ---------------------------------------------------------------- camera math (mirrors ScreenCamera)

def fill_scale(screen_w: float, screen_h: float, hole_w: float, hole_h: float) -> float:
    """Screen points per hole-image pixel when the hole frame is drawn aspect-fill."""
    return max(screen_w / hole_w, screen_h / hole_h)


def screen_factor(cam: Camera, k: float) -> complex:
    """w in screen = C + w * (M - center): scale and rotation from master to screen."""
    return (k / cam.mppp) * cmath.exp(-1j * math.radians(cam.rotation_degrees))


def zoom_out(turn: float, p: float) -> float:
    degrees = abs(math.degrees(turn))
    if degrees <= 120:
        return 1.0
    return 1 - 0.2 * min(1.0, (degrees - 120) / 60) * math.sin(math.pi * p)


def blend(a: Camera, b: Camera, p: float, k: float) -> tuple[complex, complex]:
    """Camera center and screen factor at swipe progress p (HM-TR-01, HM-TR-05)."""
    wa, wb = screen_factor(a, k), screen_factor(b, k)
    turn = math.remainder(cmath.phase(wb) - cmath.phase(wa), 2 * math.pi)
    log_scale = (1 - p) * math.log(abs(wa)) + p * math.log(abs(wb))
    w = math.exp(log_scale) * zoom_out(turn, p) * cmath.exp(1j * (cmath.phase(wa) + p * turn))
    return a.center + p * (b.center - a.center), w


def visible_corners(center: complex, w: complex, screen_w: float, screen_h: float) -> list[complex]:
    mid = complex(screen_w / 2, screen_h / 2)
    return [center + (s - mid) / w for s in (0, screen_w, complex(screen_w, screen_h), complex(0, screen_h))]


# ---------------------------------------------------------------- pieces

def placement(file: str, image: Image.Image, origin: complex, rotation_degrees: float, scale: float) -> dict:
    """Where a piece sits on the master: pixel (x, y) -> origin + scale * R(rotation) * (x, y)."""
    return {
        "file": file,
        "width": image.width,
        "height": image.height,
        "mapOrigin": [round(origin.real, 4), round(origin.imag, 4)],
        "rotationDegrees": rotation_degrees,
        "mapPixelsPerPixel": round(scale, 8),
    }


def hole_crop(master: Image.Image, cam: Camera, hole_w: int, hole_h: int) -> tuple[Image.Image, dict]:
    """The hole's camera frame, upright, at the largest phone's pixel density (never above the master's)."""
    need = max(fill_scale(w, h, hole_w, hole_h) * s for w, h, s in SCREENS)  # device px per hole px
    out_w = round(hole_w * min(need, cam.mppp))
    out_h = round(out_w * hole_h / hole_w)
    # First resample at about one master pixel per output pixel, then shrink with a good filter.
    mid_w = max(out_w, round(hole_w * cam.mppp))
    mid_h = round(mid_w * hole_h / hole_w)
    theta = math.radians(cam.rotation_degrees)
    rot = cmath.exp(1j * theta)
    origin = cam.center - cam.mppp * rot * complex(hole_w / 2, hole_h / 2)
    s = cam.mppp * hole_w / mid_w
    coeffs = (s * math.cos(theta), -s * math.sin(theta), origin.real,
              s * math.sin(theta), s * math.cos(theta), origin.imag)
    image = master.transform((mid_w, mid_h), Image.Transform.AFFINE, coeffs,
                             resample=Image.Resampling.BICUBIC, fillcolor=(0, 0, 0, 0))
    if (out_w, out_h) != (mid_w, mid_h):
        image = image.resize((out_w, out_h), Image.Resampling.LANCZOS)
    scale = cam.mppp * hole_w / out_w
    return image, placement(f"hole{cam.hole}.heic", image, origin, cam.rotation_degrees, scale)


def swipe_area(a: Camera, b: Camera, hole_w: int, hole_h: int) -> tuple[float, float, float, float]:
    """Bounding box, in master pixels, of everything any frame of a -> b shows on any supported screen."""
    xs, ys = [], []
    for w_pt, h_pt, _ in SCREENS:
        k = fill_scale(w_pt, h_pt, hole_w, hole_h)
        for i in range(STEPS + 1):
            center, w = blend(a, b, i / STEPS, k)
            for c in visible_corners(center, w, w_pt, h_pt):
                xs.append(c.real)
                ys.append(c.imag)
    return min(xs), min(ys), max(xs), max(ys)


def transition_crop(master: Image.Image, a: Camera, b: Camera, hole_w: int, hole_h: int,
                    divisor: int) -> tuple[Image.Image, dict]:
    """The swipe's area, clipped to the master and map-aligned, at 1/divisor of the master's resolution."""
    x0, y0, x1, y1 = swipe_area(a, b, hole_w, hole_h)
    x0, y0 = max(0, math.floor(x0) - PAD), max(0, math.floor(y0) - PAD)
    x1, y1 = min(master.width, math.ceil(x1) + PAD), min(master.height, math.ceil(y1) + PAD)
    if x1 <= x0 or y1 <= y0:
        raise SystemExit(f"transition {a.hole}->{b.hole} never shows the master")
    out_w, out_h = math.ceil((x1 - x0) / divisor), math.ceil((y1 - y0) / divisor)
    region = master.crop((x0, y0, x0 + out_w * divisor, y0 + out_h * divisor))  # past the edge -> transparent
    image = region.resize((out_w, out_h), Image.Resampling.LANCZOS) if divisor > 1 else region
    return image, placement(f"transition-{a.hole}-{b.hole}.heic", image, complex(x0, y0), 0.0, float(divisor))


# ---------------------------------------------------------------- output

def save_heic(image: Image.Image, path: Path, quality: int) -> int:
    alpha = np.asarray(image.getchannel("A"))
    final = image if alpha.min() < 255 else image.convert("RGB")
    final.save(path, format="HEIF", quality=quality)
    return path.stat().st_size


def load_cameras(path: Path, shift: complex) -> tuple[dict, list[Camera]]:
    data = json.loads(path.read_text())
    cams = [Camera(h["hole"], complex(*h["mapCenter"]) + shift, float(h["rotationDegrees"]),
                   float(h["mapPixelsPerHolePixel"])) for h in data["holes"]]
    cams.sort(key=lambda c: c.hole)
    if [c.hole for c in cams] != list(range(1, len(cams) + 1)):
        raise SystemExit(f"{path}: holes must be numbered 1...n")
    return data, cams


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("master", type=Path, help="the course master image (read only)")
    p.add_argument("--cameras", type=Path, default=DEFAULT_CAMERAS)
    p.add_argument("--out", type=Path, default=DEFAULT_OUT)
    p.add_argument("--transition-divisor", type=int, default=2, choices=[1, 2, 3, 4],
                   help="transition crops at 1/N of the master's resolution (default 2, half)")
    p.add_argument("--quality", type=int, default=75, help="HEIC quality (default 75)")
    p.add_argument("--overview-divisor", type=int, default=6,
                   help="how many master pixels per overview pixel (default 6: about 1630 px wide)")
    p.add_argument("--overview-only", action="store_true",
                   help="write only overview.heic and its entry in the existing CourseImagery.json")
    p.add_argument("--shift", type=float, nargs=2, metavar=("X", "Y"), default=(0.0, 0.0),
                   help="where the cameras' master now sits inside an extended master, in pixels")
    p.add_argument("--bounds", type=float, nargs=4, metavar=("S", "W", "N", "E"),
                   help="GPS bounds of an extended master")
    return p.parse_args(argv)


def overview(master: Image.Image, divisor: int) -> tuple[Image.Image, dict]:
    """The whole master, north up, scaled down by `divisor` (HM-OV-01)."""
    image = master.resize((round(master.width / divisor), round(master.height / divisor)), Image.LANCZOS)
    return image, placement("overview.heic", image, 0j, 0.0, master.width / image.width)


def write_overview(master: Image.Image, args: argparse.Namespace, manifest: dict) -> int:
    image, place = overview(master, args.overview_divisor)
    size = save_heic(image, args.out / place["file"], args.quality)
    manifest["overview"] = place
    print(f"overview: {image.width}x{image.height}, {size / 1e6:.1f} MB file, "
          f"{image.width * image.height * 4 / 1e6:.0f} MB decoded")
    return size


def main(argv: list[str]) -> None:
    args = parse_args(argv)
    if args.overview_only:
        path = args.out / "CourseImagery.json"
        manifest = json.loads(path.read_text())
        master = Image.open(args.master)
        master.load()
        master = master.convert("RGBA")
        if [master.width, master.height] != [manifest["master"]["width"], manifest["master"]["height"]]:
            raise SystemExit("the master's size doesn't match CourseImagery.json: re-cut everything instead")
        write_overview(master, args, manifest)
        path.write_text(json.dumps(manifest, indent=2) + "\n")
        return
    shift = complex(*args.shift)
    data, cams = load_cameras(args.cameras, shift)
    hole_w, hole_h = int(data["holeImage"]["width"]), int(data["holeImage"]["height"])

    master = Image.open(args.master)
    master.load()
    master = master.convert("RGBA")
    expected = (data["master"]["width"], data["master"]["height"])
    resized = master.size != tuple(expected)
    if resized and (shift == 0 or args.bounds is None):
        raise SystemExit(f"master is {master.width}x{master.height} but the cameras are for "
                         f"{expected[0]}x{expected[1]}: pass --shift and --bounds for an extended master")
    bounds = list(args.bounds) if args.bounds else data["master"]["boundsSWNE"]

    args.out.mkdir(parents=True, exist_ok=True)
    holes, transitions, total_bytes, total_decoded = [], [], 0, 0

    for cam in cams:
        image, place = hole_crop(master, cam, hole_w, hole_h)
        size = save_heic(image, args.out / place["file"], args.quality)
        total_bytes += size
        total_decoded += image.width * image.height * 4
        holes.append({"camera": {"hole": cam.hole,
                                 "mapCenter": [round(cam.center.real, 4), round(cam.center.imag, 4)],
                                 "rotationDegrees": cam.rotation_degrees,
                                 "mapPixelsPerHolePixel": cam.mppp},
                      "image": place})
        print(f"hole {cam.hole}: {image.width}x{image.height}, {size / 1e6:.1f} MB file, "
              f"{image.width * image.height * 4 / 1e6:.0f} MB decoded")

    for a in cams:
        b = cams[a.hole % len(cams)]
        image, place = transition_crop(master, a, b, hole_w, hole_h, args.transition_divisor)
        size = save_heic(image, args.out / place["file"], args.quality)
        total_bytes += size
        total_decoded += image.width * image.height * 4
        transitions.append({"from": a.hole, "to": b.hole, "image": place})
        print(f"{a.hole}->{b.hole}: {image.width}x{image.height}, {size / 1e6:.1f} MB file, "
              f"{image.width * image.height * 4 / 1e6:.0f} MB decoded")

    manifest = {
        "generatedBy": "tools/cut-course-map.py",
        "master": {"width": master.width, "height": master.height, "boundsSWNE": bounds},
        "holeImage": {"width": hole_w, "height": hole_h},
        "transitionDivisor": args.transition_divisor,
        "holes": holes,
        "transitions": transitions,
    }
    total_bytes += write_overview(master, args, manifest)
    (args.out / "CourseImagery.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"\n{len(holes)} hole crops + {len(transitions)} transition crops: "
          f"{total_bytes / 1e6:.1f} MB in the app, {total_decoded / 1e6:.0f} MB if all were decoded at once")
    if resized:
        print("The master changed size: update tools/course-cameras.json with the shifted cameras and bounds.")


if __name__ == "__main__":
    main(sys.argv[1:])
