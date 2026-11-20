# 08 — Scorecard (live, portrait + landscape)

**Artboards:** Scorecard · Scorecard — one player · Scorecard — landscape
**Entry:** Hole play › "Card".
**Exit:** Back (accessibility "Back to hole") → Hole play.

## 1. Overview
A live scorecard for the round in progress. In **portrait** it's a vertical table (holes as rows, players as columns). Rotating to **landscape** gives a horizontal table (holes as columns, players as rows), like a paper card. Both are **read-only**: there's no editing from the scorecard. Scores are entered and changed only in Hole play. Landscape is supported on **this screen only**.

## 2. Header (both orientations)
| ID | Requirement |
|----|-------------|
| SC-HDR-01 | Leading back circle button (accessibility "Back to hole"). |
| SC-HDR-02 | Title "Scorecard" (SF Pro 700). |
| SC-HDR-03 | Status line "PAR {72} · THRU {n}", where `n` = the number of holes where every player has a score. |
| SC-HDR-04 | Date / time line "{Wed, Nov 11} · {9:42 AM}" (the round's start). Landscape shows it on the status line: "PAR 72 · THRU 1 · WED, NOV 11 · 9:42 AM". |
| SC-HDR-05 | `WeatherIcon` with temperature ("62°"), accessibility "Sunny, 62 degrees". Hidden if the round has no weather. |

## 3. Portrait table
| ID | Requirement |
|----|-------------|
| SC-PT-01 | Columns: **HOLE** (40 pt), **PAR** (34 pt), then **four equal-width player display slots**, independent of how many players are present (#204). Actual players fill the slots from left to right in card order; remaining slots have blank headers, score cells and totals (no avatar, name, dot or dash). A lone player occupies the first slot, never a stretched or centered column. |
| SC-PT-02 | The player column header shows a 28 pt avatar, first name and running `ToParText` (under par `underPar`, else Moss 600). The header is pinned while the table scrolls. Blank player slots show nothing. |
| SC-PT-03 | Rows: holes 1–9, then an **OUT** total row, holes 10–18, an **IN** total row and a **TOT** total row (for a **9-hole round**: holes 1–9 and a TOT row only, no OUT/IN. An 18-hole round plays the 9 holes twice and shows 10–18 as the second nine). |
| SC-PT-04 | Hole rows are 40 pt with a hairline top border and alternating white / Card Stripe backgrounds. The **current hole** row is highlighted in Lake 50. Three faint 1 pt vertical lines using semantic `divider` separate the four player slots continuously from header through totals, including blank slots; these lines are decorative and never intercept taps. |
| SC-PT-05 | Real-player score cells use `ScoreMark` (30 pt). Unplayed holes show "·" in Chalk 300; unoccupied player slots remain blank without a score mark. |
| SC-PT-06 | Total rows are 42 pt, Bunker 100 background, Bunker 300 top border, sums in SF Pro 700, Canopy. A segment with no scores yet shows "–". |
| SC-PT-07 | A `ScoreLegend` under the table: Eagle, Birdie, Bogey, Double+. |

## 4. Landscape table
| ID | Requirement |
|----|-------------|
| SC-LS-01 | Grid columns: label (112 pt), holes 1–9, **OUT** (42), holes 10–18, **IN** (42), **TOT** (46). A 9-hole round shows label, 1–9, **TOT** only. |
| SC-LS-02 | Row **HOLE** (34 pt, Tee Green 50 background, hole numbers SF Pro 700 16). Row **PAR** (30 pt, Card Stripe, Moss 600). Then one 46 pt row per player with a 24 pt avatar, first name (ellipsized) and `ScoreMark`s (26 pt). |
| SC-LS-03 | The current hole's column is highlighted in Lake 50 across every row. Total columns use Bunker 300 (header) / Bunker 100 (body). |
| SC-LS-04 | The legend and weather sit in the header row to save vertical space. |
| SC-LS-05 | It fills the width on an iPhone in landscape (hole columns share the space left after the label and total columns). Where 18 holes don't fit, the grid scrolls horizontally. |

## 5. Behavior and data
| ID | Requirement |
|----|-------------|
| SC-BH-01 | Updates live when a score is saved (observation). |
| SC-BH-02 | **Landscape is for this screen only.** The rest of the app (including Round detail, which reuses the table) is portrait-locked. On the Scorecard, rotating the device switches between the portrait and landscape tables automatically (`verticalSizeClass`). |
| SC-BH-05 | Orientation lock: the app declares portrait and both landscapes (`INFOPLIST_KEY_UISupportedInterfaceOrientations` in `Config/App.xcconfig`), and `OrientationController` (in the environment, like the router, and read by `AppDelegate.application(_:supportedInterfaceOrientationsFor:)`) returns `.portrait` everywhere except while the Scorecard is on screen, where it returns `.allButUpsideDown`. The Scorecard calls `allowLandscape()` when it appears and `lockPortrait()` when it goes. |
| SC-BH-06 | Leaving the Scorecard while in landscape (Back) returns to Hole play in **portrait**, with no landscape flash of Hole play: Back calls `lockPortrait()` (a portrait geometry update and a supported-orientations refresh) before it pops; leaving any other way locks on disappear. |
| SC-BH-07 | **Read-only:** cells have no tap action, no context menu and no edit affordance. VoiceOver exposes them as static text (no button trait). |
| SC-BH-03 | `ScorecardViewModel` builds a `ScorecardModel(round:players:course:)` from value snapshots (`RoundSnapshot`, `PlayerSnapshot`) and the course: one column per player in card order (first name, color, photo, scores, running to-par, OUT / IN / TOT through `ScoreFormatter`), the rows (holes 1–9, OUT, 10–18, IN, TOT; 9 holes: 1–9, TOT) with each row's par, the round's par, THRU and the current hole (nil once the round is finished, so Round detail and the PDF show no highlight). A card whose player is missing (only possible for a moment while a deletion syncs) is left out. It's a pure transform with 100 % unit coverage. **The same model is reused by Round detail and PDF export.** `playerSlots` provides four optional columns for portrait display only. `columns`, hole scores and total arrays retain their real player count; blank display slots never create fake player records or scores. Landscape and PDF continue to consume the real columns. |
| SC-BH-04 | The `ScorecardTable` component takes the model plus an orientation, so it can be reused in Round detail (portrait, no current-hole highlight). |

## 6. Accessibility
- Each score cell reads "{Player}, hole {n}, {score}, {score name}". Empty cells read "not played".
- Identifiers: `scorecard.back`, `scorecard.thru`, `scorecard.cell.{hole}.{playerId}`, `scorecard.total.{out|in|tot}.{playerId}`, `scorecard.error.retry`; portrait layout: `scorecard.table`, `scorecard.player.{playerId}` for occupied headers only.
- If the round can't be read, "The scorecard couldn't be loaded." shows with Try again.

