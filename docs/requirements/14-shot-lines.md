# 14 — Shot Lines, Target and Yardages (hole map overlays)

**Artboard:** iPhone — Hole 1 (the target cross and yardage panel are interactive there). The dark-mode, Players and Enter score artboards may still show the older landing dot; Hole 1 is the reference.
**Where:** the base layer of Hole play (07-hole-play §1.1), drawn over the hole map (16-hole-map).
**Components:** `ShotLine`, `TeeMarker`, `PinMarker`, `TargetMarker`, `YardagePanel` (00-design-system DS-OV-01, 02, 09, 10, 11).
**Setting:** Settings › "Shot line on map" (02-settings SET-OPT-02, default on).

## 1. Overview
Each hole shows a dotted line from the **round's tee box** to a **target cross**, then on to the **pin**. The player **drags the target** to where they want to hit. A small glass **yardage panel** under the target shows two numbers: how far it is **to the target**, and how far from the target **to the pin**. The target starts at the hole's suggested landing point from the course data. A par 5 has two targets (tee shot and layup). A par 3 has none: its line runs straight from the tee to the pin, and the **pin is its target** (#185). The **pin drags on every hole** (the day's pin placement), and its panel shows TO PIN alone. With **Show my location** on, the line follows the player around the hole (§3a).

## 2. Shot line and pin
| ID | Requirement |
|----|-------------|
| SL-DR-01 | **ShotLine:** a Chalk 50 stroke, 2.5 pt wide, dash pattern [2, 8], round caps, 90 % opacity. Same in light and dark mode (the map dims in dark; the line doesn't). |
| SL-DR-02 | The line starts at the **tee box of the round's tee** (`Round.tee`; all players share one tee, NR-CTA-03), marked by a dot in that tee's color (SL-DR-09), goes to each target in order, and ends at the **pin** (the green center until it's dragged, SL-TG-08). With Show my location on, it can start at the player instead and skip targets they've reached (§3a). |
| SL-DR-03 | The legs are **straight** segments (tee → target → pin), as in the design. There are no curves or bend settings. The line redraws live while a target or the pin is dragged, and with each new GPS fix. |
| SL-DR-04 | **By par:** par 3 → **no** target cross: the line is tee → pin, and the pin is the target (dragged like one, SL-TG-08) (#185). Par 4 → one target. Par 5 → **two** targets (tee shot and layup): tee → target 1 → target 2 → pin. Every target, and the pin, is draggable. |
| SL-DR-05 | **PinMarker** at the pin: a 16 pt Flag 400 dot, 3 pt Canopy ring and an 8 pt Flag 400 @ 35 % halo. While the line shows it's draggable (SL-TG-08); with the setting off it's decorative. |
| SL-DR-06 | With Settings › "Shot line on map" **off**, the line, the targets and the yardage panel are hidden. The **PinMarker stays** (it marks the green, not the route), but doesn't drag. |
| SL-DR-07 | Overlays never move to avoid controls. A point under the top bar, hole card, map buttons or leaderboard is still drawn beneath the glass. The hole camera (16-hole-map §3) frames each hole so the tee and pin are visible. |
| SL-DR-08 | The line is decorative and hidden from VoiceOver, and so are the tee marker and, with the setting off, the pin. The draggable pin is an adjustable element (SL-TG-08). The map's accessibility label (HP-MAP-01) stays "Aerial view of hole {n}, par {p}". |
| SL-DR-09 | **TeeMarker** at the start of the line: a 16 pt dot in the round's tee color (Blue = Lake 600, White = white, Yellow = Bunker 300, Red = Flag 600, as `TeeDot`) with a 2.5 pt Chalk 50 ring, or a Moss 400 ring on White so the white dot keeps an edge (as `TeeDot`) (#186). It shows and hides with the line (SL-DR-06, SL-MO-04), is hidden once the line starts at the player (SL-GP-02), and is hidden from VoiceOver (SL-DR-08). |

## 3. Target cross
| ID | Requirement |
|----|-------------|
| SL-TG-01 | **TargetMarker:** a 44 pt crosshair: a ring (13 pt radius) and four ticks in Chalk 50, 2.5 pt, over a Canopy 950 @ 55 % outline (5 pt) so it reads on any turf, with a 5 pt Flag 400 center dot. |
| SL-TG-02 | The target is **draggable**. It follows the finger exactly (the drag is measured in screen space, not the moving target's own, which made it lag and flicker) and the line and yardages update live. A `.selection` haptic fires when the drag starts. |
| SL-TG-03 | A drag must **start on the target** or the pin (hit area 60 × 60 pt). A touch that starts anywhere else on the map is the hole swipe (HP-NAV-01), never a target move. *The artboard moves the target from a touch anywhere; that would block swiping between holes.* |
| SL-TG-04 | While dragged, the target stays inside the playable part of the screen (`ShotLayout.playable`): at least 24 pt from the side edges, below the hole card and map buttons, and above the leaderboard, or above the Out of order button's badge while it shows (HP-OO-08; all measured on screen). Dragging past a limit holds it at the limit. A target's starting point from the course data is drawn where it is, even under the glass (SL-DR-07); it's only held inside once the finger moves, so a tap that doesn't drag leaves it where it is. |
| SL-TG-05 | **Starting position:** each target starts at its landing point from the course data (SL-CD-02), and the pin at the green center. Moving to another hole and back, or reopening the round, puts them back at the start (`ShotTargets` is rebuilt when the hole changes); a score saved on the same hole keeps them where they were dragged. Target and pin positions aren't saved. |
| SL-TG-06 | On a par 5, each of the two targets drags separately, each with its own drag (two fingers at once don't share a starting point). The yardage panel belongs to the target or pin touched last (target 1 when the hole appears; the pin on a par 3). |
| SL-TG-07 | **VoiceOver:** each target is an adjustable element, "Target, {165} yards, {220} to pin". Swiping up or down moves it 10 yards along the line toward the pin or the tee. |
| SL-TG-08 | **Draggable pin** (#185): while the line shows, the pin drags like a target (60 pt hit area, follows the finger, held inside the playable area, `.selection` haptic) to the day's pin placement, and becomes the active marker: its panel shows TO PIN alone (SL-YD-08), and TO PIN on the targets follows it. VoiceOver: an adjustable element "Pin, {152} yards" (`PinMarker(yards:onStep:)`); swiping up moves it 10 yards farther from the point before it, down 10 yards back toward it. |

## 3a. Following the player (GPS, #185)
With Show my location on and a fix on the course (HP-CTL-03), the line follows the player around the hole. The pure `ShotRoute` (`ShotTargets.route(player:)`) works it out again on every fix.

| ID | Requirement |
|----|-------------|
| SL-GP-01 | **Near the tee** (within 30 yards of the round's tee box, `ShotRoute.teeClearance`), the player's dot and the line stay apart: the line starts at the tee. |
| SL-GP-02 | **Past the tee** by more than 30 yards, the line starts at the player's dot instead, and the tee marker is hidden. |
| SL-GP-03 | **Reaching a target:** a target within 50 yards of the player (`ShotRoute.targetReach`) leaves the line, which goes on to the next target or the pin; any earlier target goes too, so the line never runs back to a layup already passed. Walking back out past 50 yards brings it back (nothing is remembered). If the active target leaves, the panel moves to the next target on the line, or the pin. |
| SL-GP-04 | **Par 3:** the dot always stays apart; the line is tee → pin wherever the player is. |
| SL-GP-05 | **Par 5:** rules SL-GP-02 and 03 apply to both targets in order. **Off the hole:** a position more than 75 yards from the hole's line (tee → targets → pin, `ShotRoute.onHole`), for example while looking ahead at another hole, leaves the line as it is without GPS; the dot and SL-YD-04 still apply. |

## 4. Yardage panel
| ID | Requirement |
|----|-------------|
| SL-YD-01 | **YardagePanel:** a Glass surface (radius 18, 150 pt wide, padding 8 / 10) centered 30 pt below the active target or pin and kept at least 12 pt inside the screen edges. It moves with the target. |
| SL-YD-02 | Two columns split by a 1 pt divider (white @ 35 %): a number (SF Pro 700 26) over a caps label (SF Pro 600 10, tracking 0.14 em, Lake 100): **TO TARGET** and **TO PIN**. Whole yards, no unit. The pin's panel has the TO PIN column alone, with no divider (SL-YD-08). |
| SL-YD-03 | **TO TARGET** is the distance from the start of that leg to the target: from the line's start (the round's tee box, or the player, SL-GP-02) for the first target on the line, from the target before it otherwise. **TO PIN** is the distance from that target to the pin. |
| SL-YD-04 | With **Show my location** on and a precise position fix (30 m or better, Precise Location on) inside the course (HP-CTL-03), TO TARGET is measured from the **player's position** to the active target instead, and the player's position shows as a dot on the map. *Inferred; the artboard measures from the tee.* `YardageCalculator.yardages(route:…player:course:)` does the measuring, ignoring a position outside the course map's bounds. Hole play passes the position while Show my location is on (`HolePlayViewModel.playerPosition`, #57). |
| SL-YD-05 | Distances are real ground distances: screen point → GPS through the hole camera (`ShotProjection`) → great-circle (haversine) distance in yards (`YardageCalculator`). They don't depend on screen size or zoom. |
| SL-YD-06 | The panel announces changes politely to VoiceOver when a drag ends ("165 yards to target, 220 to pin"), not on every frame. |
| SL-YD-07 | A par 3 has no target, so no TO TARGET: the pin owns its panel from the start (SL-YD-08, #185). |
| SL-YD-08 | **The pin's panel** (the pin active: dragged last, a par 3, or every target reached, SL-GP-03): **TO PIN** alone, from the last target still on the line; with none, from the player (on the course, SL-YD-04) or else the tee (`ShotYardages.pin`). VoiceOver reads "152 yards to pin" when a drag ends. |

## 5. Projection
| ID | Requirement |
|----|-------------|
| SL-PJ-01 | Tee boxes, landing points and the pin are stored as **GPS coordinates**. |
| SL-PJ-02 | Points are placed on screen through the **hole camera** over the course map (16-hole-map §2–3): GPS → course map → camera → screen. A dragged target goes the other way (screen → GPS) so its yardages are real. |
| SL-PJ-03 | Overlays use the same camera transform as the map, so they stay pinned to the turf on every iPhone size, in light and dark, and while the map is moving. |
| SL-PJ-04 | Projection is the pure `ShotProjection` over the hole's `HoleCamera` at rest (16-hole-map HM-CAM-05) and the master's GPS bounds: `point(for:)` and its inverse `coordinate(for:)`. It's unit-tested without any UI. |
| SL-PJ-05 | Overlays are recomputed when the hole, the view size or a target changes, not on score updates. |

## 6. Course data (additions to `MaynardGC.json`)
| ID | Requirement |
|----|-------------|
| SL-CD-01 | Per hole: `teeBoxes: { blue, white, yellow, red }` in `MaynardGC.json`, one GPS point per tee box, all four required (`Hole.teeBoxes`, a `TeeBoxes`). A missing tee fails decoding with `CourseDataError.missingTeeBox`. |
| SL-CD-02 | Per hole: `approachShots: [Coordinate]` in `MaynardGC.json`, the suggested landing points in playing order, where each target starts: **two on a par 5** (tee shot and layup), **one on every other hole, par 3s included** (`Hole.approachShotCount(par:)`). A different count fails decoding with `CourseDataError.approachShotCount`. A par 3's approach shot is on the green (within 3 yards of its center); it isn't drawn, since a par 3 has no target (SL-DR-04). |
| SL-CD-03 | The map image and each hole's `camera` come from 16-hole-map §6. No per-hole aerial is needed. |
| SL-CD-04 | The pin is `greenCoordinates.center` (already in the course data). A per-day pin position isn't supported. |
| SL-CD-05 | Holes 10–18 of an 18-hole round reuse holes 1–9 (RoundHoleBuilder, CRS-HC-01). |
| SL-CD-06 | **Data collection** for all 9 holes is part of this story: tee boxes (4 × 9) and approach shots. The tee boxes and approach shots in `MaynardGC.json` were measured and added in #104. Later changes can be captured with the calibration tool (§8) or from satellite imagery, then checked on site. |

## 7. Motion
| ID | Requirement |
|----|-------------|
| SL-MO-01 | When a hole settles (tee off, swipe, auto-advance), the line draws on from tee to pin (about 600 ms ease-out), then the targets and the yardage panel fade in. |
| SL-MO-02 | With **Reduce Motion** on, they appear at once. |
| SL-MO-03 | Toggling the setting fades the line, targets and panel in or out (200 ms). |
| SL-MO-04 | Dragging a target redraws at the display's frame rate with no lag behind the finger. During a hole transition, and over the course overview, the overlays (pin included) are hidden (HM-TR-04, `ShotOverlayVisibility`). |

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
| SL-TS-02 | Unit: `ShotLinePath`: tee → each target → pin as straight legs; par 3 → one leg; par 4 → two legs; par 5 → three legs; the path follows a moved target or pin. |
| SL-TS-03 | Unit: tee selection: the path and TO TARGET start at the round's tee box (Blue vs Red give different values). |
| SL-TS-04 | Unit: yardages (`YardageCalculator`, 100 %): known GPS pairs give the expected yards within 1; target 1 and target 2 legs on a par 5; the same target gives the same yards on iPhone SE and Pro Max sizes; with a player position, TO TARGET measures from it; a position outside the course is ignored. |
| SL-TS-05 | Unit: target model: starts at the landing point; clamps to the playable area; resets when the hole changes; the last-touched target or pin owns the panel; VoiceOver adjust moves a target or the pin 10 yards along the line. |
| SL-TS-06 | Unit: settings: line, targets and panel hidden when "Shot line on map" is off; the pin always present. |
| SL-TS-07 | **Course data validation tests** (`CourseDataTests`): every hole has 4 tee boxes, an approach-shot count that matches its par (2 on a par 5, 1 otherwise) and a camera. At rest on **every** supported iPhone, every tee box, approach shot and pin clears Hole play's controls by HM-CAM-02's limits (`everyPointClearsTheControls`): 24 pt from the sides, 110 pt below the top and 150 pt above the bottom (74 / 116 pt without a home indicator), and the pin 150 pt left of the right edge (the hole card). The tests fail if any hole's data is missing or a camera puts a point under the controls. |
| SL-TS-08 | UI (`ShotLineUITests`): the hole shown has `hole.target.1` and `hole.yardage`; dragging `hole.target.1` changes `hole.yardage.toTarget` and moves the target as far as the finger (80 pt, ± 6); a horizontal drag that starts away from the target changes the hole; dragging `hole.pin` shows the TO PIN-only panel and changes `hole.yardage.toPin`; with Show my location on in hole 5's fairway (the location mock), `hole.tee` goes. `hole.shotLine` is hidden from accessibility (SL-DR-08); the route is unit-tested (SL-TS-02, 11). |
| SL-TS-09 | UI: setting off → no `hole.target.1` or `hole.yardage`; hole 2 (par 5) has `hole.target.1` and `hole.target.2`; hole 3 (par 3) has no `hole.target.1` and a panel with `hole.yardage.toPin` alone; leaving a hole and coming back resets the target. |
| SL-TS-11 | Unit (`ShotRouteTests`, 100 %): without a position the line is unchanged; within 30 yards of the tee it starts at the tee, past it at the player; a target within 50 yards leaves (with any before it) and comes back past 50; the panel moves on; a par 3 keeps the tee line; a position more than 75 yards off the hole is ignored; the distance to the line. |
| SL-TS-10 | Preview: hole 1 in light and dark on two device sizes, checked by hand against the artboard. 100 % coverage for `ShotLinePath`, `YardageCalculator` and the target model; ≥ 90 % for the overlay views and calibration logic. |

## 10. Accessibility identifiers
`hole.shotLine`, `hole.tee`, `hole.target.{n}`, `hole.yardage`, `hole.yardage.toTarget`, `hole.yardage.toPin`, `hole.pin`, `hole.myLocation`, `shotLineEditor.*` (debug).
