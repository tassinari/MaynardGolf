# 09 — Player Card

**Artboards:** Player card · Player card — scrolled to rounds
**Entry:** Home › player row, All players › row.
**Exit:** Back circle (accessibility "Back to players") → previous screen.

## 1. Overview
A scrolling profile for one player. It has a top bar with Edit, a profile card (avatar, name, handicap index), three stat tiles (Avg score, Best and a 9 / 18 **Holes** toggle), a score histogram, a 12-month handicap trend chart and the player's previous rounds, listed by month in the same rows as All rounds. The top bar stays pinned and picks up a blurred background once content scrolls under it.

**Design note:** the main "Player card" artboard still shows Previous rounds as an older list inside one card. That card is **outdated**. Previous rounds follow "Player card — scrolled to rounds" (§7): month groups of `RoundRow`s with a score chip per player.

## 2. Top bar
| ID | Requirement |
|----|-------------|
| PC-TOP-01 | Leading 44 pt back circle button (Chalk 200, chevron-left), accessibility "Back to players". It always goes back (no scroll-to-top behavior). |
| PC-TOP-02 | Title "PLAYER CARD" (Sofia 700 22, tracking 0.06 em), **leading-aligned** next to the back button (not centered). |
| PC-TOP-03 | Trailing `NeutralPillButton` "Edit" (44 pt, Chalk 200). It opens the **Add player form in its Edit configuration** (05-add-player §9): prefilled, title "EDIT PLAYER", button "Save", plus "Delete player". On return the card reflects the changes. After a delete, the card pops back to the previous screen. |
| PC-TOP-04 | The bar is pinned. At the top of the scroll it sits on the page background. Once content scrolls beneath it, it shows Chalk @ 92 % + 16 pt blur with a 1 pt Card Border hairline at the bottom (standard toolbar background behavior, `.toolbarBackground(.automatic)`). Bar height 112 pt including the status bar. |

## 3. Profile card
| ID | Requirement |
|----|-------------|
| PC-HDR-01 | A white `CardContainer` (radius 22, 1 pt Card Border, padding 18, gap 16) in one row: avatar, name, handicap block. |
| PC-HDR-02 | 72 pt `PlayerAvatar`: the photo, or the first initial (Sofia 700 34, white) on the player's color. Accessibility "Photo of {first name}". |
| PC-HDR-03 | Full name (Inter 600 22, line height 1.15), wrapping to two lines, then truncating. There's **no** subtitle (no home club or member-since). |
| PC-HDR-04 | Trailing handicap block, right-aligned: label "HCP INDEX" (Sofia 600 11, tracking 0.14 em, Moss 600) over the index (Sofia 700 44, Lake 600; dark: Lake 300). There's **no** trend line. |
| PC-HDR-05 | The index is the manual index when set, otherwise the calculated index (18-handicap). No manual index and fewer than 3 rounds → "—". Accessibility "Handicap index {8.4}", plus "calculated" for a calculated value. |

## 4. Stat tiles
| ID | Requirement |
|----|-------------|
| PC-ST-01 | A 3-column grid (gap 8) of `StatTile`s: Tee Green 50 background (`statTile` token), radius 16, padding 12/6, centered content. |
| PC-ST-02 | **Avg score**: the value (Sofia 700 28, one decimal, e.g. "78.9") over the caption "Avg score" (Inter 12, Moss 600). The average gross of completed rounds with the selected hole count. |
| PC-ST-03 | **Best**: the lowest gross (e.g. "74") of completed rounds with the selected hole count, over the caption "Best". |
| PC-ST-04 | **Holes**: a compact 2-segment control "9" / "18" over the caption "Holes". Track Tee Green 100 `#D4DEB4` (radius 10, 3 pt padding). The selected segment is white with a soft shadow (radius 8, 30 pt tall, Sofia 700 18, Canopy). The unselected one is transparent, Moss 600. Accessibility: a picker labeled "Holes" with values "9 holes" / "18 holes". |
| PC-ST-05 | The toggle filters **Avg score, Best and the score histogram** (§5). It doesn't affect the handicap index, the handicap chart or Previous rounds. |
| PC-ST-06 | Default selection when the card opens: the hole count this player has **more completed rounds of**. A tie or no rounds → 18. The choice isn't remembered between visits. |
| PC-ST-07 | No completed rounds with the selected count → Avg and Best show "—". |
| PC-ST-08 | There's no Rounds count tile (removed from the design). |

## 5. Score histogram
| ID | Requirement |
|----|-------------|
| PC-HI-01 | A white card (radius 22, padding 16, gap 12) titled "SCORES · LAST 20 ROUNDS" (Sofia 700 18, tracking 0.06 em) with the trailing caption "rounds" (Inter 12, Moss 600). |
| PC-HI-02 | A Swift Charts `BarMark` histogram, 140 pt tall: buckets 2 strokes wide, starting at the minimum score rounded down to even (e.g. 74–75, 76–77 … 84+). The last bucket is open-ended. Lake 600 bars (radius 6 top, 2 bottom), the count above each bar (Sofia 700 14), bucket labels under a hairline (Sofia 600 13, Moss 600). |
| PC-HI-03 | Uses the last 20 completed rounds **with the selected hole count** (PC-ST-05). Up to 6 buckets. Switching the toggle animates the bars. |
| PC-HI-04 | Accessibility summary, e.g. "Histogram of last 20 18-hole round scores: 74–75 two rounds, 76–77 four, …". |
| PC-HI-05 | Fewer than 3 rounds with the selected count → the chart is replaced by the hint "Play 3 rounds to see your score spread" (*inferred*). |

## 6. Handicap trend chart
| ID | Requirement |
|----|-------------|
| PC-HC-01 | A white card titled "HANDICAP · 12 MONTHS" with the trailing range "{11.2} → {8.4}" (Inter 12, Moss 600). |
| PC-HC-02 | A Swift Charts `LineMark` + `AreaMark` (Lake 600 line 2.5 pt, Lake 600 @ 10 % area) of monthly handicap index over the last 12 months, 150 pt tall. Y axis: 3 gridlines (e.g. 12 / 10 / 8). X axis labels: first, middle and last month (DEC / MAY / NOV). |
| PC-HC-03 | The last point has a 5 pt Lake 600 dot with a white ring and a value label above it (Sofia 700 14). |
| PC-HC-04 | The series is the **calculated** index at the end of each month, from `HandicapManager.series` (18-handicap HC-MG-06; nothing is stored). It's shown even when a manual index is set. Not affected by the 9 / 18 toggle. |
| PC-HC-05 | Accessibility summary: "Handicap index fell from 11.2 last December to 8.4 this November". |
| PC-HC-06 | Hidden when there are fewer than 2 data points. |

## 7. Previous rounds (month groups of round rows)
| ID | Requirement |
|----|-------------|
| PC-PR-01 | Header "PREVIOUS ROUNDS" (Sofia 700 22, tracking 0.06 em) with the trailing caption "{n} this year" (Inter 13, Moss 600): the player's completed rounds in the current calendar year. |
| PC-PR-02 | The rounds are grouped by month, exactly as in All rounds (01-home HOME-AR-04): a month header ("NOVEMBER 2026", Sofia 700 17, tracking 0.08 em) over a `CardContainer` (radius 20) of `RoundRow`s separated by hairlines. |
| PC-PR-03 | Each row is the shared `RoundRow` (HOME-RR-03, HOME-AR-05): weekday caps over the day number; "Maynard Golf Club" with trailing meta "{9 \| 18} holes · {Tee}"; one `PlayerScoreChip` per player **in the round** (not only this player), in round order; a trailing chevron. |
| PC-PR-04 | This player's chip looks the same as the others (no highlight). There's no weather, no to-par and no large score on the row. The old 2-column `RoundTile` grid is gone. |
| PC-PR-05 | Each row is one accessibility element, with the same label as in All rounds (HOME-RR-05). |
| PC-PR-06 | The list holds only **completed** rounds this player took part in. Rounds in progress aren't listed here. |
| PC-PR-07 | Newest first, loaded lazily. Unaffected by the 9 / 18 toggle. |
| PC-PR-08 | Tapping a row pushes **Round detail**. |
| PC-PR-09 | There's no search and no swipe-to-delete here. Rounds are deleted only in All rounds (HOME-AR-07). |
| PC-PR-10 | No completed rounds → the section shows "No rounds yet" instead of the list. |

## 8. Scrolled state
| ID | Requirement |
|----|-------------|
| PC-CH-01 | There's **no** separate compact header with avatar or HCP. When scrolled, the same top bar (back, "PLAYER CARD", Edit) stays pinned with its blurred background (PC-TOP-04). |
| PC-CH-02 | ~~Month axis tab under the header~~ **Removed.** In the "scrolled to rounds" artboard, that strip is just the bottom of the handicap chart card scrolling under the bar, not a separate element. |
| PC-CH-03 | ~~Compact back button scrolls to top~~ **Removed.** Back always goes back (PC-TOP-01). |
| PC-CH-04 | ~~Opening scrolled to rounds from "See all"~~ **Removed.** Home › See all opens **All rounds** (01-home §6). |

## 9. Data
| ID | Requirement |
|----|-------------|
| PC-DT-01 | `PlayerCardViewModel` is injected with `PlayerRepository`, `RoundRepository`, `HandicapManager` (18-handicap) and a `Clock`. It exposes `profile`, `holeFilter: HoleCount` (9 / 18), `stats` (avg, best for the filter), `histogram: [Bucket]` (for the filter), `handicapSeries: [Point]`, `roundSections` (month groups of the shared `RoundRow` models from `RoundSummaryBuilder`) and `roundsThisYear`. |
| PC-DT-02 | Stats, the default-filter rule, bucketing and series building are pure functions with 100 % unit coverage (empty, 1 round, 20+ rounds, ties, 9 vs 18 holes, the most-played tie → 18). |
| PC-DT-03 | Builds on the existing `Stats.swift` logic. Refactor it to be testable. The handicap comes from `HandicapManager` (18-handicap). |
| PC-DT-04 | Observes the player and rounds, so returning from Edit or from a deleted round updates the card. |

## 10. Accessibility identifiers
`playerCard.back`, `playerCard.edit`, `playerCard.hcp`, `playerCard.stat.avg`, `playerCard.stat.best`, `playerCard.holes`, `playerCard.histogram`, `playerCard.handicapChart`, `playerCard.roundsThisYear`, `playerCard.round.{id}`.
