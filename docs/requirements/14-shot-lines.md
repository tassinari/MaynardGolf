# 14 — Shot Lines, Target and Yardages (hole map overlays)

**Artboard:** iPhone — Hole 1 (the target cross and yardage panel are interactive there). The dark-mode, Players and Enter score artboards may still show the older landing dot; Hole 1 is the reference.
**Where:** the base layer of Hole play (07-hole-play §1.1), drawn over the hole map (16-hole-map).
**Components:** `ShotLine`, `PinMarker`, `TargetMarker`, `YardagePanel` (00-design-system DS-OV-01, 02, 09, 10).
**Setting:** Settings › "Shot line on map" (02-settings SET-OPT-02, default on).

## 1. Overview
Each hole shows a dotted line from the **round's tee box** to a **target cross**, then on to the **pin**. The player **drags the target** to where they want to hit. A small glass **yardage panel** under the target shows two numbers: how far it is **to the target**, and how far from the target **to the pin**. The target starts at the hole's suggested landing point from the course data. A par 5 has two targets (tee shot and layup). A par 3 has none: the line goes straight to the pin.

## 2. Shot line and pin
| ID | Requirement |
|----|-------------|
| SL-DR-01 | **ShotLine:** a Chalk 50 stroke, 2.5 pt wide, dash pattern [2, 8], round caps, 90 % opacity. Same in light and dark mode (the map dims in dark; the line doesn't). |
| SL-DR-02 | The line starts at the **tee box of the round's tee** (`PersonRound.teeID`; all players share one tee, NR-CTA-03), goes to each target in order, and ends at the **pin** (green center). |
| SL-DR-03 | The legs are **straight** segments (tee → target → pin), as in the design. There are no curves or bend settings. The line redraws live while a target is dragged. |
| SL-DR-04 | **By par:** par 3 → tee straight to pin, no target. Par 4 → one target. Par 5 → **two** targets (tee shot and layup): tee → target 1 → target 2 → pin. |
| SL-DR-05 | **PinMarker** at the pin: a 16 pt Flag 400 dot, 3 pt Canopy ring and an 8 pt Flag 400 @ 35 % halo. |
| SL-DR-06 | With Settings › "Shot line on map" **off**, the line, the targets and the yardage panel are hidden. The **PinMarker stays** (it marks the green, not the route). |
| SL-DR-07 | Overlays never move to avoid controls. A point under the top bar, hole card, map buttons or leaderboard is still drawn beneath the glass. The hole camera (16-hole-map §3) frames each hole so the tee and pin are visible. |
| SL-DR-08 | The line and pin are decorative and hidden from VoiceOver. The map's accessibility label (HP-MAP-01) stays "Aerial view of hole {n}, par {p}". |

## 3. Target cross
| ID | Requirement |
|----|-------------|
| SL-TG-01 | **TargetMarker:** a 44 pt crosshair: a ring (13 pt radius) and four ticks in Chalk 50, 2.5 pt, over a Canopy 950 @ 55 % outline (5 pt) so it reads on any turf, with a 5 pt Flag 400 center dot. |
| SL-TG-02 | The target is **draggable**. It follows the finger and the line and yardages update live. A `.selection` haptic fires when the drag starts. |
| SL-TG-03 | A drag must **start on the target** (hit area 60 × 60 pt). A touch that starts anywhere else on the map is the hole swipe (HP-NAV-01), never a target move. *The artboard moves the target from a touch anywhere; that would block swiping between holes.* |
| SL-TG-04 | The target stays inside the playable part of the screen: at least 24 pt from the side edges, below the hole card and map buttons, and above the leaderboard. Dragging past a limit holds it at the limit. |
| SL-TG-05 | **Starting position:** each target starts at its landing point from the course data (SL-CD-02). Moving to another hole and back, or reopening the round, puts it back at the start. Target positions aren't saved. |
| SL-TG-06 | On a par 5, each of the two targets drags separately. The yardage panel belongs to the target touched last (target 1 when the hole appears). |
| SL-TG-07 | **VoiceOver:** each target is an adjustable element, "Target, {165} yards, {220} to pin". Swiping up or down moves it 10 yards along the line toward the pin or the tee. |

## 4. Yardage panel
| ID | Requirement |
|----|-------------|
| SL-YD-01 | **YardagePanel:** a Glass surface (radius 18, 150 pt wide, padding 8 / 10) centered 30 pt below the active target and kept at least 12 pt inside the screen edges. It moves with the target. |
| SL-YD-02 | Two columns split by a 1 pt divider (white @ 35 %): a number (Sofia 700 26) over a caps label (Sofia 600 10, tracking 0.14 em, Lake 100): **TO TARGET** and **TO PIN**. Whole yards, no unit. |
| SL-YD-03 | **TO TARGET** is the distance from the start of that leg to the target: from the round's tee box for target 1, from target 1 for target 2. **TO PIN** is the distance from that target to the pin. |
| SL-YD-04 | With **Show my location** on and a position fix inside the course (HP-CTL-03), TO TARGET is measured from the **player's position** to the active target instead, and the player's position shows as a dot on the map. *Inferred; the artboard measures from the tee.* |
| SL-YD-05 | Distances are real ground distances: screen point → GPS through the hole camera → great-circle distance in yards. They don't depend on screen size or zoom. |
| SL-YD-06 | The panel announces changes politely to VoiceOver when a drag ends ("165 yards to target, 220 to pin"), not on every frame. |
| SL-YD-07 | A par 3 has no target and no panel. The hole card already shows the yardage. |

## 5. Projection
| ID | Requirement |
|----|-------------|
| SL-PJ-01 | Tee boxes, landing points and the pin are stored as **GPS coordinates**. |
| SL-PJ-02 | Points are placed on screen through the **hole camera** over the course map (16-hole-map §2–3): GPS → course map → camera → screen. A dragged target goes the other way (screen → GPS) so its yardages are real. |
| SL-PJ-03 | Overlays use the same camera transform as the map, so they stay pinned to the turf on every iPhone size, in light and dark, and while the map is moving. |
| SL-PJ-04 | Projection is the pure, injected `HoleCamera` (16-hole-map HM-CAM-05). It's unit-tested without any UI. |
| SL-PJ-05 | Overlays are recomputed when the hole, the view size or a target changes, not on score updates. |

## 6. Course data (additions to `MaynardGC.json`)
| ID | Requirement |
|----|-------------|
| SL-CD-01 | Per hole: `teeCoordinates: { blue, white, yellow, red }` (one GPS point per tee box). |
| SL-CD-02 | Per hole: `landingPoints: [Coordinate]`, the suggested starting position of each target: none for a par 3, one for a par 4, **two for a par 5**. |
| SL-CD-03 | The map image and each hole's `camera` come from 16-hole-map §6. No per-hole aerial is needed. |
| SL-CD-04 | The pin is `greenCoordinates.center` (already in the course data). A per-day pin position isn't supported. |
| SL-CD-05 | Holes 10–18 of an 18-hole round reuse holes 1–9 (RoundHoleBuilder, CRS-HC-01). |
| SL-CD-06 | **Data collection** for all 9 holes is part of this story: tee boxes (4 × 9) and landing points. It can be captured on the course with the calibration tool (§8) or from satellite imagery, then checked on site. |

## 7. Motion
| ID | Requirement |
|----|-------------|
| SL-MO-01 | When a hole settles (tee off, swipe, auto-advance), the line draws on from tee to pin (about 600 ms ease-out), then the targets and the yardage panel fade in. |
| SL-MO-02 | With **Reduce Motion** on, they appear at once. |
| SL-MO-03 | Toggling the setting fades the line, targets and panel in or out (200 ms). |
| SL-MO-04 | Dragging a target redraws at the display's frame rate with no lag behind the finger. During a hole transition the overlays are hidden (HM-TR-04). |

## 8. Calibration tool (debug builds only)
| ID | Requirement |
|----|-------------|
| SL-CT-01 | A DEBUG-only editor on Hole play (launch argument `-shotLineEditor`). It shows handles for each tee box, each landing point and the pin; dragging them updates the points live. |
| SL-CT-02 | "Use my location" sets the selected handle to the current GPS position (for capturing tee boxes and landing points on the course). |
| SL-CT-03 | "Export" copies the hole's JSON fragment (§6) to the pasteboard for pasting into `MaynardGC.json`. |
| SL-CT-04 | Compiled out of Release builds (`#if DEBUG`). |

## 9. Testing
| ID | Requirement |
|----|-------------|
| SL-TS-01 | Unit: projection through `HoleCamera`: a tee, a landing point and the green center of each hole land where the camera math says, within 1 px; and screen → GPS → screen round-trips within 0.5 px. |
| SL-TS-02 | Unit: `ShotLinePath`: tee → each target → pin as straight legs; par 3 → one leg; par 5 → three legs; the path follows a moved target. |
| SL-TS-03 | Unit: tee selection: the path and TO TARGET start at the round's tee box (Blue vs Red give different values). |
| SL-TS-04 | Unit: yardages (`YardageCalculator`, 100 %): known GPS pairs give the expected yards within 1; target 1 and target 2 legs on a par 5; the same target gives the same yards on iPhone SE and Pro Max sizes; with a player position, TO TARGET measures from it; a position outside the course is ignored. |
| SL-TS-05 | Unit: target model: starts at the landing point; clamps to the playable area; resets when the hole changes; the last-touched target owns the panel; VoiceOver adjust moves 10 yards along the line. |
| SL-TS-06 | Unit: settings: line, targets and panel hidden when "Shot line on map" is off; the pin always present. |
| SL-TS-07 | **Course data validation test:** every hole has 4 tee coordinates, a landing-point count that matches its par (0 / 1 / 2), a camera, and every tee, landing point and pin inside the screen at rest. The test fails if any hole's data is missing. |
| SL-TS-08 | UI: hole 1 shows `hole.shotLine`, `hole.target.1`, `hole.yardage`, `hole.pin`; dragging `hole.target.1` changes the `hole.yardage` values; a horizontal drag that starts away from the target changes the hole and leaves the target alone. |
| SL-TS-09 | UI: setting off → only `hole.pin` exists; hole 2 (par 5) has `hole.target.1` and `hole.target.2`; hole 3 (par 3) has no target and no panel; leaving a hole and coming back resets the target. |
| SL-TS-10 | Preview: hole 1 in light and dark on two device sizes, checked by hand against the artboard. 100 % coverage for `ShotLinePath`, `YardageCalculator` and the target model; ≥ 90 % for the overlay views and calibration logic. |

## 10. Accessibility identifiers
`hole.shotLine`, `hole.target.{n}`, `hole.yardage`, `hole.yardage.toTarget`, `hole.yardage.toPin`, `hole.pin`, `hole.myLocation`, `shotLineEditor.*` (debug).
