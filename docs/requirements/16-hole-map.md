# 16 — Hole Map (course map, hole cameras and swipe transitions)

**Artboards:** iPhone — Hole 1 (the map at rest). There's no artboard for the transition or the course overview.
**Reference:** `maynard-golf-course-v6-transitions-center.svg` in the course cartography project: the course map with one screen box per hole, an arrow for each camera move, and the extra area each swipe passes over.
**Where:** the base layer of Hole play (07-hole-play §1.1). Shot lines (14-shot-lines) draw on top of it.

## 1. Overview
The hole map isn't nine separate pictures. It's **one map of the whole course**, and each hole is a **camera** looking at part of it: a position, a direction and a zoom. Swiping between holes moves the camera, so the map **pans, rotates and zooms** from one hole to the next, turning around the **middle of the screen**. The app never loads the whole map: it ships pre-cut **hole crops** for the resting views and **transition crops** for each camera move, and keeps only the pieces next to the current hole in memory.

## 2. Course map
| ID | Requirement |
|----|-------------|
| HM-MAP-01 | One north-up **master** image of the whole course (`fullmapFull.png`, 9780 × 7586), in the app's illustrated aerial style, covering 42.440415, −71.453471 (south-west) to 42.446032, −71.443658 (north-east). The master isn't shipped; every image the app shows is cut from it (§6). Its georeference is that bounding box: latitude and longitude map linearly to pixels. |
| HM-MAP-02 | **Sharp at rest:** at rest the screen shows the hole's **hole crop**: the part of the master that hole's camera shows on the largest supported iPhone, cut from the master, rotated upright and sized to the largest phone's screen pixels (about 1320 × 2868, HEIC, about 15 MB decoded). It covers every supported screen shape at rest. |
| HM-MAP-03 | **Memory:** the map layer uses at most 150 MB while a round is open. Decoding the whole master takes about 300 MB (596 MB peak, measured in #128), so it's never loaded. Instead the app loads only the pieces next to the current hole: the current hole crop, both neighbouring hole crops and both **transition crops** (for hole 1: 9 ← 1 and 1 → 2), about 115 MB in total. On arriving at a hole it releases the pieces that are no longer adjacent and loads the new neighbours in the background. |
| HM-MAP-07 | **Transition crops.** Each camera move is fixed, so each transition's image is cut ahead of time: the map-aligned area every frame of that swipe shows on any supported iPhone, at **half the master's resolution** (21–46 MB decoded; 9 → 1 is the largest). It's in motion whenever it's on screen. Half resolution is the starting point; a third (9–21 MB) is the fallback if memory needs it, judged on a device by holding a swipe partway. |
| HM-MAP-08 | **Seamless layering.** During a swipe the transition crop draws underneath, and the hole crops you're leaving and going to draw on top, all through the **same camera**. The sharp crop stays wherever it still covers the screen, and the transition crop shows only in the areas it uncovers, so nothing visibly switches when a swipe starts or ends. Every piece comes from the same master pixels, so they always match. A render test checks that each hole crop lines up with its transition crops at progress 0 and 1. |
| HM-MAP-04 | **No dead space:** the images cover every point the screen can show, at rest and during every transition (1→2 … 8→9, and 9→1 for the second nine). A unit test proves it (HM-TS-03). The master has no holes inside it. **Not met yet:** some views go past the master's edge (iPhone 16 / Pro Max): 7→8 6.4 % of the screen, 1→2 3.3 %, 2→3 2.5 %, hole 9 at rest and 8→9 / 9→1 1.0 %, 4→5 0.9 %, 3→4 touches the edge; on iPhone SE about 40 % less. The master needs extending about 600 px left (y 1300–5100, beside hole 1), 520 px top (x 1100–4600, above holes 1–2), 730 px bottom (x 3000–8800, under holes 9 to 8) and 250 px right (y 4500–7000, beside holes 7–8), in master pixels. Until then those areas are blank, and the crops pick up the new area when they're re-cut. |
| HM-MAP-05 | Dark mode dims the map as in DS-MT-05. There's one set of artwork, not a second dark version. |
| HM-MAP-06 | Accessibility label per hole stays "Aerial view of hole {n}, par {p}" (HP-MAP-01). |

## 3. Hole cameras
| ID | Requirement |
|----|-------------|
| HM-CAM-01 | Each hole has a camera in course data: `center` (the GPS point at the middle of the screen), `heading` (degrees clockwise from north; the direction that points up the screen) and `width` (meters of ground across the screen width). |
| HM-CAM-02 | At rest, the tee is near the bottom of the screen and the green near the top, and both stay clear of the top bar, hole card, map buttons and leaderboard (SL-DR-08). |
| HM-CAM-03 | The same camera data works on every iPhone size: `width` is relative to the screen width, and the visible ground is taller on taller screens. |
| HM-CAM-04 | Holes 10–18 use the cameras of holes 1–9 (CRS-HC-01). |
| HM-CAM-05 | A pure `HoleCamera` type turns a camera plus a view size into a transform (GPS → screen and back). It replaces the per-hole aerial transform in 14-shot-lines §3, so shot lines, the pin and "my location" use the same math. |

## 4. Swipe transition
| ID | Requirement |
|----|-------------|
| HM-TR-01 | Swiping between holes (HP-NAV-01) drives the camera **interactively**: the map follows the finger. Progress 0 → 1 blends the camera's `center` along the straight line between the two holes' centers, the heading the **short way round**, and the width. The map **turns around the middle of the screen**; the tee isn't pinned. |
| HM-TR-02 | Letting go past halfway (or with a flick) finishes the move; otherwise it springs back. The finish takes about 0.5 s with ease-out and never overshoots the rotation. A drag that starts on a target cross moves the target, not the hole (14-shot-lines SL-TG-03). |
| HM-TR-03 | Auto-advance (HP-NAV-02) and the course overview (§5) use the same camera move, about 0.9 s. |
| HM-TR-04 | The shot line, targets, yardage panel and pin fade out when a transition starts, and draw on when the camera settles (SL-MO-01). The hole card crossfades to the new hole at the halfway point (HP-HOLE-03). The top bar, map buttons and leaderboard don't move. |
| HM-TR-05 | For turns of more than 120°, the camera also zooms out by up to 20 % at the midpoint, so the turn reads as flying over the course. This covers hole 4 → 5, which is nearly a U-turn (about 170°); no pair needs a crossfade. |
| HM-TR-06 | **Reduce Motion:** no pan or rotation. The current map crossfades to the next hole's resting view. |
| HM-TR-07 | Smooth on the oldest supported iPhone: no hitches over 16 ms while dragging (checked in Instruments). Nothing is decoded during a swipe: both directions' pieces are already loaded before the finger moves. If a neighbour hasn't finished loading, the swipe waits for it rather than showing a blank. |
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
| HM-CD-01 | `CourseImagery.json` (bundled, generated) lists the master's pixel size and georeference and, per hole, the camera (**center on the master in master pixels, rotation and master pixels per hole-image pixel**, from the stitch registration `course-stitch-v1/stitch.py`, ×2 for the full master), plus each hole crop and transition crop with its file name and **placement on the master** (origin, scale and rotation), so the app positions every piece with the same camera math. GPS (HM-MAP-01) is reached through the georeference. |
| HM-CD-02 | **Cutting script** (`tools/cut-course-map.py`, in the repo): reads the master and the cameras and writes `hole1…9.heic`, `transition-1-2…9-1.heic` and `CourseImagery.json`. It never changes the master. When the master or the stitch changes, the script is re-run; nothing is tuned by hand. Areas past the master's edge are left blank (transparent). |
| HM-CD-03 | Per-hole aerial images and their three control points (14-shot-lines SL-CD-03) are no longer needed: the hole crops are cut from the master. About 25–35 MB of crops ship in the app (to be measured when the script exists), in place of one 7.6 MB map. |

## 7. Testing
| ID | Test |
|----|------|
| HM-TS-01 | Unit (`HoleCamera`, 100 %): GPS ↔ screen round-trip; `center` lands on the middle of the screen; a point `width` meters to the right of the center lands one screen width away; heading 0 / 90 / 180; iPhone SE, 17 and 17 Pro Max sizes. |
| HM-TS-02 | Unit (camera blend, 100 %): progress 0 and 1 equal the two cameras; the center moves on the straight line between the two centers; the heading takes the short way (for example −12° → 108° goes +120°, and 170° → −170° goes +20°); the midpoint zoom-out applies only above 120°. |
| HM-TS-03 | Unit (course data): for every transition, sampled at 60 steps on each device size, all four screen corners fall inside the course map. The tee and green of every hole are inside the visible area at rest and outside the regions covered by controls. |
| HM-TS-04 | UI: swipe from hole 1 to hole 2 → the hole card shows 2 and the shot-line elements exist; a short drag springs back to hole 1; with Reduce Motion the hole still changes. |
| HM-TS-05 | UI: Course map → 9 badges (18 in an 18-hole round) → tap badge 5 → the hole card shows 5; open and close without picking returns to the same hole. |
| HM-TS-06 | Performance: a scripted swipe through all 9 holes stays within the hitch budget (`XCTHitchMetric` / `XCTOSSignpostMetric`), and memory stays under 150 MB (`XCTMemoryMetric`), with no peak above it while pieces load. |
| HM-TS-08 | Unit (cutting output): every transition crop contains every frame of its swipe on iPhone SE, 17 and 17 Pro Max (sampled at 60 steps); every hole crop contains its resting view on all three; `CourseImagery.json` lists 9 hole crops and 9 transition crops whose files exist. |
| HM-TS-09 | Unit (imagery loader, fake decoder injected): at hole n it holds exactly holes n−1, n, n+1 and the two adjacent transitions (wrapping 9 ↔ 1); moving a hole releases the far pieces and requests the new ones; a missing file is an error, not a crash. |
| HM-TS-07 | Manual: every transition checked on a device, in Light and Dark, for alignment of the shot line with the map at rest. |

## 8. Accessibility identifiers
`hole.map`, `hole.map.overview`, `hole.map.badge.{n}`.
