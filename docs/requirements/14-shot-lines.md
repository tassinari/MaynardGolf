# 14 — Shot Lines (hole map overlays)

**Artboards:** iPhone — Hole 1 · Applied — Hole 1 · Applied — Hole 1, dark mode
**Where:** the base layer of Hole play (07-hole-play §1.1), drawn over the full-screen hole aerial.
**Components:** `ShotLine`, `PinMarker`, `LandingMarker` (00-design-system DS-OV-01…03).
**Setting:** Settings › "Shot line on map" (02-settings SET-OPT-02, default on).

## 1. Overview
Each hole's aerial shows the intended route: a dotted line from the **round's tee box** to a **landing point** in the fairway, then on to the **pin**, with a small Lake dot at the landing point and a Flag dot at the pin. In the design, hole 1 (par 4) draws `M tee Q control landing T pin`, two smooth quadratic segments joined at the landing point. It shows **no** yardage labels, hazard callouts or distance card (those were removed from v2).

## 2. What's drawn
| ID | Requirement |
|----|-------------|
| SL-DR-01 | **ShotLine:** a Chalk 50 stroke, 2.5 pt wide, dash pattern [2, 8], round caps, 90 % opacity. Same in light and dark mode (the aerial dims in dark; the line doesn't). |
| SL-DR-02 | The line starts at the **tee box of the round's tee** (`PersonRound.teeID`; all players share one tee, NR-CTA-03), passes **through** each landing point, and ends at the **pin** (green center). |
| SL-DR-03 | The path is smooth: one quadratic segment per leg, C1-continuous at each landing point (the second leg's control point is the reflection of the first, as SVG `T`). Each leg's curvature comes from an optional per-hole `bend` (a signed offset, −1…1, default 0 = straight) so doglegs follow the fairway. |
| SL-DR-04 | **LandingMarker** at each landing point: a 6–7 pt Lake 200 (`#A9D2FF`) dot with a 2.5–3 pt Canopy ring. No label. |
| SL-DR-05 | **PinMarker** at the pin: a 16–18 pt Flag 400 dot, 3 pt Canopy ring and an 8–9 pt Flag 400 @ 35 % halo. |
| SL-DR-06 | **By par:** par 3 → tee straight to pin, no landing marker. Par 4 → one landing point. Par 5 → one or two landing points (tee shot and layup), per course data. *Inferred* from the single par-4 example. |
| SL-DR-07 | With Settings › "Shot line on map" **off**, the ShotLine and LandingMarkers are hidden. The **PinMarker stays** (it marks the green, not the route). *Inferred.* |
| SL-DR-08 | Overlays never cover controls. If a projected point falls under the top bar, hole card, map buttons or leaderboard, it's still drawn (it's under the glass), but no marker is moved. The aerial's framing (§3) is chosen so the tee and pin are visible. |
| SL-DR-09 | Overlays are decorative: hidden from VoiceOver. The aerial's accessibility label (HP-MAP-01) stays "Aerial view of hole {n}, par {p}". |

## 3. Projection (GPS → aerial image → screen)
| ID | Requirement |
|----|-------------|
| SL-PJ-01 | All overlay points are stored as **GPS coordinates** (so the same data serves "Show my location", HP-CTL-03). |
| SL-PJ-02 | Each hole's aerial is **georeferenced** in course data by three control points: the GPS coordinates of three known pixel positions in the image (e.g. top-left, top-right, bottom-left). An **affine transform** maps GPS → image pixels. The aerials are north-up or rotated so tee is at the bottom and green at the top; the affine handles rotation and scale. |
| SL-PJ-03 | Image → screen uses the same aspect-fill mapping as the image view (scale = max(screenW/imageW, screenH/imageH), centered), so overlays stay pinned to the turf on every iPhone size and in light / dark mode. |
| SL-PJ-04 | Projection is a pure, injected `HoleProjection` (`init(georeference:imageSize:viewSize:)`, `screenPoint(for: Coordinate) -> CGPoint`). It's unit-tested without any UI. |
| SL-PJ-05 | Recomputed only when the hole or the view size changes, not on score updates (leaderboard changes don't redraw the map). |

## 4. Course data (additions to `MaynardGC.json`)
| ID | Requirement |
|----|-------------|
| SL-CD-01 | Per hole: `teeCoordinates: { blue, white, yellow, red }` (one GPS point per tee box). |
| SL-CD-02 | Per hole: `landingPoints: [Coordinate]` (0 for par 3, 1 for par 4, 1–2 for par 5), and optional `bends: [Double]` (one per leg). |
| SL-CD-03 | Per hole: `aerial: { imageName, pixelSize, controlPoints: [{ pixel: [x, y], coordinate }] ×3 }`. Replaces `holeIconName` for the map (the v1 `hole1…hole9` image sets can stay for icons). |
| SL-CD-04 | The pin is `greenCoordinates.center` (already in v1 data). A per-day pin position isn't supported. |
| SL-CD-05 | Holes 10–18 of an 18-hole round reuse holes 1–9 (RoundHoleBuilder, CRS-HC-01). |
| SL-CD-06 | **Data collection** for all 9 holes is part of this story: tee boxes (4 × 9), landing points, bends, and the aerial control points. It can be captured on the course with the calibration tool (§6) or from satellite imagery, then checked on site. |

## 5. Motion
| ID | Requirement |
|----|-------------|
| SL-MO-01 | When a hole appears (tee off, swipe, auto-advance), the line draws on from tee to pin (`trim(from: 0, to: 1)`, about 600 ms ease-out), then the markers fade in. |
| SL-MO-02 | With **Reduce Motion** on, the line and markers appear at once (no draw-on). |
| SL-MO-03 | Toggling the setting fades the line in or out (200 ms). |
| SL-MO-04 | Rendering uses SwiftUI `Canvas` (or `Shape` + `Path`) and stays at 60 fps (120 on ProMotion) while swiping between holes. |

## 6. Calibration tool (debug builds only)
| ID | Requirement |
|----|-------------|
| SL-CT-01 | A DEBUG-only overlay editor on Hole play (enabled with launch argument `-shotLineEditor`). It shows the tee, landing and pin handles; dragging them updates the points live, and a "bend" slider adjusts each leg. |
| SL-CT-02 | "Use my location" sets the selected handle to the current GPS position (for on-course capture of tee boxes and landing points). |
| SL-CT-03 | "Export" copies the hole's JSON fragment (§4) to the pasteboard for pasting into `MaynardGC.json`. |
| SL-CT-04 | Compiled out of Release builds (`#if DEBUG`). Never shipped to TestFlight testers outside the developer. |

## 7. Data and testing
| ID | Requirement |
|----|-------------|
| SL-TS-01 | Unit: `HoleProjection` affine solve from 3 control points; the control points map back exactly; a known 4th point (e.g. green center) lands within 2 px; rotated aerials. |
| SL-TS-02 | Unit: aspect-fill image → screen mapping for iPhone SE, 17, 17 Pro Max sizes (wider-than-image and taller-than-image cases). |
| SL-TS-03 | Unit: `ShotLinePath` builder: starts at the tee, passes through each landing point, ends at the pin; par 3 → one straight leg; bend 0 → straight legs; C1 continuity at the joint (tangents match). |
| SL-TS-04 | Unit: tee selection: the path starts at the round's tee box (Blue vs Red produce different starts). |
| SL-TS-05 | Unit: settings: line and landing markers hidden when "Shot line on map" is off; the pin marker always present. |
| SL-TS-06 | **Course data validation test:** every hole has 4 tee coordinates, the landing-point count is valid for its par, bends match the leg count, 3 control points, and every projected tee / landing / pin point falls inside the aerial image. The test fails if any hole's data is missing. |
| SL-TS-07 | UI test: Hole play shows `hole.shotLine`, `hole.landing.{n}`, `hole.pin`; with the setting off only `hole.pin` exists; swipe to hole 3 (par 3) → no landing marker. |
| SL-TS-08 | Snapshot / preview: hole 1 in light and dark on two device sizes (`#Preview`s), checked by hand against the design. |
| SL-TS-09 | 100 % coverage for `HoleProjection` and `ShotLinePath`; ≥ 90 % for the overlay views and calibration logic. |

## 8. Accessibility identifiers
`hole.shotLine`, `hole.landing.{n}`, `hole.pin`, `shotLineEditor.*` (debug).

## Open questions
1. Does each par 5 need one landing point or two (tee shot and layup)?
2. With "Shot line on map" off, should the pin marker stay (as specified) or hide too?
