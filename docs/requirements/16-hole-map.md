# 16 — Hole Map (course map, hole cameras and swipe transitions)

**Artboards:** iPhone — Hole 1 (the map at rest). There's no artboard for the transition or the course overview.
**Reference:** `maynard-golf-course-v5-transitions.svg` in the course cartography project: the course map with one screen box per hole, the tee-to-tee arrows, and the extra area each swipe passes over.
**Where:** the base layer of Hole play (07-hole-play §1.1). Shot lines (14-shot-lines) draw on top of it.

## 1. Overview
The hole map isn't nine separate pictures. It's **one map of the whole course**, and each hole is a **camera** looking at part of it: a position, a direction and a zoom. Swiping between holes moves the camera, so the map **pans, rotates and zooms** from one hole to the next along the line from tee to tee. Because the camera never leaves the course map, there's no empty space mid-swipe.

## 2. Course map
| ID | Requirement |
|----|-------------|
| HM-MAP-01 | One north-up image of the whole course, in the app's illustrated aerial style, covering 42.438322, −71.455789 (south-west) to 42.447523, −71.442745 (north-east). Its georeference is that bounding box: latitude and longitude map linearly to pixels. |
| HM-MAP-02 | **Sharp at rest:** on every supported iPhone, a hole at rest shows at least one map pixel per screen pixel. The smallest hole box (hole 3) sets the map's full resolution. |
| HM-MAP-03 | **Memory:** the map layer uses at most 150 MB while a round is open. A full-resolution bitmap of the whole course is too big to hold in memory, so the map is delivered in one of two ways, chosen in the spike (#114): **(a)** map tiles at several zoom levels, loaded for the visible area; or **(b)** one sharp image per hole for the resting view, over a lower-resolution whole-course image that shows only during a transition. |
| HM-MAP-04 | **No dead space:** the map covers every point the screen can show, at rest and during every transition (1→2 … 8→9, and 9→1 for the second nine). A unit test proves it (HM-TS-03). |
| HM-MAP-05 | Dark mode dims the map as in DS-MT-05. There's one set of artwork, not a second dark version. |
| HM-MAP-06 | Accessibility label per hole stays "Aerial view of hole {n}, par {p}" (HP-MAP-01). |

## 3. Hole cameras
| ID | Requirement |
|----|-------------|
| HM-CAM-01 | Each hole has a camera in course data: `anchor` (GPS of the back tee), `heading` (degrees clockwise from north; the direction that points up the screen), `width` (meters of ground across the screen width) and `anchorScreen` (where the anchor sits on screen, as fractions of the width and height). |
| HM-CAM-02 | At rest, the tee is near the bottom of the screen and the green near the top, and both stay clear of the top bar, hole card, map buttons and leaderboard (SL-DR-08). |
| HM-CAM-03 | The same camera data works on every iPhone size: `width` and `anchorScreen` are relative, and the visible ground is taller on taller screens. |
| HM-CAM-04 | Holes 10–18 use the cameras of holes 1–9 (CRS-HC-01). |
| HM-CAM-05 | A pure `HoleCamera` type turns a camera plus a view size into a transform (GPS → screen and back). It replaces the per-hole aerial transform in 14-shot-lines §3, so shot lines, the pin and "my location" use the same math. |

## 4. Swipe transition
| ID | Requirement |
|----|-------------|
| HM-TR-01 | Swiping between holes (HP-NAV-01) drives the camera **interactively**: the map follows the finger. Progress 0 → 1 blends the anchor along the straight line from this hole's tee to the next hole's tee, the heading the **short way round**, the width, and the anchor's screen position. |
| HM-TR-02 | Letting go past halfway (or with a flick) finishes the move; otherwise it springs back. The finish takes about 0.5 s with ease-out and never overshoots the rotation. |
| HM-TR-03 | Auto-advance (HP-NAV-02) and the course overview (§5) use the same camera move, about 0.9 s. |
| HM-TR-04 | Shot line, landing markers and pin fade out when a transition starts, and draw on when the camera settles (SL-MO-01). The hole card crossfades to the new hole at the halfway point (HP-HOLE-03). The top bar, map buttons and leaderboard don't move. |
| HM-TR-05 | *Inferred:* for turns of more than 120°, the camera also zooms out by up to 20 % at the midpoint, so the turn reads as flying over the course. |
| HM-TR-06 | **Reduce Motion:** no pan or rotation. The current map crossfades to the next hole's resting view. |
| HM-TR-07 | Smooth on the oldest supported iPhone: no hitches over 16 ms while dragging (checked in Instruments), and map loading never blocks the gesture. If part of the map isn't loaded yet, the lower-resolution layer shows, not a blank. |
| HM-TR-08 | In an 18-hole round, hole 9 → 10 moves from camera 9 to camera 1. Swiping is still blocked before hole 1 and after the last hole. |

## 5. Course overview (Course map button)
*Inferred; no design.* This fills in HP-CTL-02.

| ID | Requirement |
|----|-------------|
| HM-OV-01 | The Course map button zooms the camera out to show the whole course, north up, with a numbered badge on each hole's tee (`HoleNumberBadge`; 10–18 show for the second nine of an 18-hole round). |
| HM-OV-02 | Tapping a badge flies the camera to that hole and makes it the current hole. Tapping the button again, or the map, returns to the hole you came from. |
| HM-OV-03 | The current hole's badge is highlighted. Holes where every player has a score show a check. |
| HM-OV-04 | The leaderboard stays visible; the hole card is hidden while the overview is open. |

## 6. Course data
| ID | Requirement |
|----|-------------|
| HM-CD-01 | `MaynardGC.json` gains `courseMap` (image or tile set name, pixel size, the bounding box in HM-MAP-01) and a `camera` per hole (HM-CAM-01). |
| HM-CD-02 | The nine cameras start from the boxes in `maynard-golf-course-v5-transitions.svg` and are then tuned by hand in the calibration tool (14-shot-lines §6, extended to move, turn and zoom the camera). |
| HM-CD-03 | Per-hole aerial images and their three control points (14-shot-lines SL-CD-03) are no longer needed once the course map ships. |

## 7. Testing
| ID | Test |
|----|------|
| HM-TS-01 | Unit (`HoleCamera`, 100 %): GPS ↔ screen round-trip; the anchor lands on `anchorScreen`; a point `width` meters to the right of the anchor lands one screen width away; heading 0 / 90 / 180; iPhone SE, 17 and 17 Pro Max sizes. |
| HM-TS-02 | Unit (camera blend, 100 %): progress 0 and 1 equal the two cameras; the anchor moves on the straight tee-to-tee line; the heading takes the short way (for example −12° → 108° goes +120°, and 170° → −170° goes +20°); the midpoint zoom-out applies only above 120°. |
| HM-TS-03 | Unit (course data): for every transition, sampled at 60 steps on each device size, all four screen corners fall inside the course map. The tee and green of every hole are inside the visible area at rest and outside the regions covered by controls. |
| HM-TS-04 | UI: swipe from hole 1 to hole 2 → the hole card shows 2 and the shot-line elements exist; a short drag springs back to hole 1; with Reduce Motion the hole still changes. |
| HM-TS-05 | UI: Course map → 9 badges (18 in an 18-hole round) → tap badge 5 → the hole card shows 5; open and close without picking returns to the same hole. |
| HM-TS-06 | Performance: a scripted swipe through all 9 holes stays within the hitch budget (`XCTHitchMetric` / `XCTOSSignpostMetric`), and memory stays under 150 MB (`XCTMemoryMetric`). |
| HM-TS-07 | Manual: every transition checked on a device, in Light and Dark, for alignment of the shot line with the map at rest. |

## 8. Accessibility identifiers
`hole.map`, `hole.map.overview`, `hole.map.badge.{n}`.

## Open questions
1. **What stays fixed during the turn:** the tee pinned near the bottom of the screen (as in your arrows), or the middle of the screen? Pinning the tee makes the far end of the view swing wider, so the map has to cover about 25 % more area.
2. **Hole 4 → 5 is nearly a U-turn (about 170°).** Is the zoom-out in HM-TR-05 enough, or should that pair crossfade instead?
3. **Where do the distances to the green show** when "Show my location" is on (HP-CTL-03)? The distance card was removed from the design system.
