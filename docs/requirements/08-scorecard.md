# 08 — Scorecard (live, portrait + landscape)

**Artboards:** Scorecard · Scorecard — landscape
**Entry:** Hole play › "Card".
**Exit:** Back (accessibility "Back to hole") → Hole play.

## 1. Overview
A live scorecard for the round in progress. In **portrait** it's a vertical table (holes as rows, players as columns). Rotating to **landscape** gives a horizontal table (holes as columns, players as rows), like a paper card. Both are **read-only**: there's no editing from the scorecard. Scores are entered and changed only in Hole play. Landscape is supported on **this screen only**.

## 2. Header (both orientations)
| ID | Requirement |
|----|-------------|
| SC-HDR-01 | Leading back circle button (accessibility "Back to hole"). |
| SC-HDR-02 | Title "Scorecard" (Sofia 700). |
| SC-HDR-03 | Status line "PAR {72} · THRU {n}", where `n` = the number of holes where every player has a score. |
| SC-HDR-04 | Date / time line "{Wed, Nov 11} · {9:42 AM}" (the round's start). Landscape shows it on the status line: "PAR 72 · THRU 1 · WED, NOV 11 · 9:42 AM". |
| SC-HDR-05 | `WeatherIcon` with temperature ("62°"), accessibility "Sunny, 62 degrees". Hidden if the round has no weather. |

## 3. Portrait table
| ID | Requirement |
|----|-------------|
| SC-PT-01 | Columns: **HOLE** (40 pt), **PAR** (34 pt), then one equal-width column per player (up to 4). |
| SC-PT-02 | The player column header shows a 28 pt avatar, first name and running `ToParText` (under par `underPar`, else Moss 600). The header is pinned while the table scrolls. |
| SC-PT-03 | Rows: holes 1–9, then an **OUT** total row, holes 10–18, an **IN** total row and a **TOT** total row (for a **9-hole round**: holes 1–9 and a TOT row only, no OUT/IN. An 18-hole round plays the 9 holes twice and shows 10–18 as the second nine). |
| SC-PT-04 | Hole rows are 40 pt with a hairline top border and alternating white / Card Stripe backgrounds. The **current hole** row is highlighted in Lake 50. |
| SC-PT-05 | Score cells use `ScoreMark` (30 pt). Unplayed = "·" in Chalk 300. |
| SC-PT-06 | Total rows are 42 pt, Bunker 100 background, Bunker 300 top border, sums in Sofia 700 Canopy. A segment with no scores yet shows "–". |
| SC-PT-07 | A `ScoreLegend` under the table: Eagle, Birdie, Bogey, Double+. |

## 4. Landscape table
| ID | Requirement |
|----|-------------|
| SC-LS-01 | Grid columns: label (112 pt), holes 1–9, **OUT** (42), holes 10–18, **IN** (42), **TOT** (46). A 9-hole round shows label, 1–9, **TOT** only. |
| SC-LS-02 | Row **HOLE** (34 pt, Tee Green 50 background, hole numbers Sofia 700 16). Row **PAR** (30 pt, Card Stripe, Moss 600). Then one 46 pt row per player with a 24 pt avatar, first name (ellipsized) and `ScoreMark`s (26 pt). |
| SC-LS-03 | The current hole's column is highlighted in Lake 50 across every row. Total columns use Bunker 300 (header) / Bunker 100 (body). |
| SC-LS-04 | The legend and weather sit in the header row to save vertical space. |
| SC-LS-05 | It fits on an iPhone in landscape without horizontal scrolling. Smaller devices may scroll horizontally with the label column pinned. |

## 5. Behavior and data
| ID | Requirement |
|----|-------------|
| SC-BH-01 | Updates live when a score is saved (observation). |
| SC-BH-02 | **Landscape is for this screen only.** The rest of the app (including Round detail, which reuses the table) is portrait-locked. On the Scorecard, rotating the device switches between the portrait and landscape tables automatically (`verticalSizeClass`). |
| SC-BH-05 | Orientation lock: the target allows portrait + landscape, and an injected `OrientationController` (backing `UIApplicationDelegate.application(_:supportedInterfaceOrientationsFor:)`) returns `.portrait` everywhere except while the Scorecard is on screen, where it returns `.allButUpsideDown`. |
| SC-BH-06 | Leaving the Scorecard while in landscape (Back) returns to Hole play in **portrait** (`requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))`), with no landscape flash of Hole play. |
| SC-BH-07 | **Read-only:** cells have no tap action, no context menu and no edit affordance. VoiceOver exposes them as static text (no button trait). |
| SC-BH-03 | `ScorecardViewModel` builds a `ScorecardModel` (rows / columns, totals, thru, current hole) from a `Round`. It's a pure transform with 100 % unit coverage. **The same model is reused by Round detail and PDF export.** |
| SC-BH-04 | The `ScorecardTable` component takes the model plus an orientation, so it can be reused in Round detail (portrait, no current-hole highlight). |

## 6. Accessibility
- Each score cell reads "{Player}, hole {n}, {score}, {score name}". Empty cells read "not played".
- Identifiers: `scorecard.back`, `scorecard.thru`, `scorecard.cell.{hole}.{playerId}`, `scorecard.total.{out|in|tot}.{playerId}`.

