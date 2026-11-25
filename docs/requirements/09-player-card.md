# 09 — Player Card

**Artboards:** Player card · Player card — scrolled to rounds
**Entry:** Home › player row, All players › row.
**Exit:** Back circle (accessibility "Back to players") → previous screen.

## 1. Overview
A scrolling profile for one player. It has a top bar with Edit, a profile card (avatar and name), three stat tiles (Avg score, Best and a 9 / 18 **Holes** toggle), a Handicap Index row, a Latest Scores line graph, a Scores by Hole grid, a 12-month handicap trend chart and the player's previous rounds, listed by month in the same rows as All rounds. The top bar stays pinned and picks up a blurred background once content scrolls under it.

**Design note:** the main "Player card" artboard still shows Previous rounds as an older list inside one card. That card is **outdated**. Previous rounds follow "Player card — scrolled to rounds" (§7): month groups of `RoundRow`s with a score chip per player.

## 2. Top bar
| ID | Requirement |
|----|-------------|
| PC-TOP-01 | Leading 44 pt back circle (`CircleIconButton`, Chalk 200, chevron-left), accessibility "Back to players", identifier `playerCard.back`. It always goes back, from any scroll position (no scroll-to-top behavior). |
| PC-TOP-02 | Title "PLAYER CARD" (SF Pro 700 22, tracking 0.06 em), **leading-aligned** next to the back button (not centered): `DSNavigationBar` with `titleAlignment: .leading`. |
| PC-TOP-03 | Trailing `NeutralPillButton` "Edit" (identifier `playerCard.edit`, disabled until the player has loaded). It presents the **Add player form in its Edit configuration** (`SheetRoute.editPlayer`, 05-add-player §9): prefilled, title "EDIT PLAYER", button "Save", plus "Delete player". On return the card reflects the changes (PC-DT-04). After a delete, the card pops back to the screen it was opened from (`Router.close(.playerCard(id))`). |
| PC-TOP-04 | The bar is pinned (`dsNavigationBar`). At the top of the scroll it's transparent on the page background. Once content scrolls beneath it, it shows Chalk @ 92 % + blur with a 1 pt hairline at the bottom (`background: .scrollEdge(isScrolled:)`, fed by `onScrollGeometryChange` through `DSBarBackground.isScrolled`). |

## 3. Profile card
| ID | Requirement |
|----|-------------|
| PC-HDR-01 | A white `ContentCard` (radius 22, 1 pt Card Border, padding 18, gap 16) in one row: avatar and name. The index isn't here: it's the Handicap Index row below the stat tiles (PC-HX-01, #253). |
| PC-HDR-02 | 72 pt `PlayerAvatar` (`AvatarSize.profile`): the photo, decoded at 216 px (72 pt at 3×), or the first initial (SF Pro 700 34) on the player's color. Accessibility "Photo of {full name}". |
| PC-HDR-03 | Full name (SF Pro 600 20, the `cardName` style), wrapping to two lines, then truncating (no limit at accessibility sizes). There's **no** subtitle (no home club or member-since). |
| PC-HDR-04 | ~~Trailing handicap block~~ **Moved** to the Handicap Index row (PC-HX-01), as the Player card — score graph artboard draws it (#253). |
| PC-HDR-05 | The index (on the Handicap Index row, PC-HX-01) is the calculated index, or the starting index with fewer than 3 usable rounds (18-handicap HC-SRC-01, 02). No starting index and fewer than 3 rounds → "—". Accessibility "Handicap index {8.4}", "Handicap index {8.4}, calculated" for a calculated value, and "No handicap index" for "—" (`PlayerCardStats.handicapAccessibilityLabel`). |

## 4. Stat tiles
| ID | Requirement |
|----|-------------|
| PC-ST-01 | A 3-column row (gap 8) of `StatTile`s: Tee Green 50 background, radius 16, padding 12. At accessibility sizes the tiles stack. |
| PC-ST-02 | **Avg score**: the value (SF Pro 700 28, one decimal, e.g. "78.9") over the caption "Avg score" (SF Pro 12, Moss 600). The average gross of completed rounds with the selected hole count. |
| PC-ST-03 | **Best**: the lowest gross (e.g. "74") of completed rounds with the selected hole count, over the caption "Best". |
| PC-ST-04 | **Holes**: the compact `DSSegmented` "9" / "18" over the caption "Holes". Track Tee Green 100; the selected segment is white with a soft shadow, the unselected one transparent. Accessibility: a picker labeled "Holes" with values "9 holes" / "18 holes"; identifier `playerCard.holes` (segments `playerCard.holes.0` / `.1`). |
| PC-ST-05 | The toggle filters **Avg score, Best and Latest Scores** (§5). It doesn't affect the handicap index, the handicap chart, Scores by Hole (§5a) or Previous rounds. |
| PC-ST-06 | Default selection when the card opens: the hole count this player has **more completed rounds of**. A tie or no rounds → 18. The choice isn't remembered between visits. |
| PC-ST-07 | No completed rounds with the selected count → Avg and Best show "—". |
| PC-ST-08 | There's no Rounds count tile (removed from the design). |

## 4a. Handicap Index row (#253)
| ID | Requirement |
|----|-------------|
| PC-HX-01 | Below the stat tiles, a white `ContentCard` row (`HandicapIndexRow`): "Handicap Index" (`bodyEmphasized`), the index (`chipNumeral`, Lake / `primaryAction`; "—" by PC-HDR-05's rule) and a chevron. |
| PC-HX-02 | Tapping it pushes the Handicap screen for this player (`Destination.handicap(id)`, 19-handicap-screen). |
| PC-HX-03 | One button element, identifier `playerCard.handicap`, labeled with PC-HDR-05's wording ("Handicap index 8.4, calculated"). |

## 5. Latest Scores (#251)
| ID | Requirement |
|----|-------------|
| PC-LS-01 | Between the Handicap Index row and the handicap chart, a white `ContentCard` titled "LATEST SCORES" (the `section` style, caps), with no caption. `LatestScoresCard`. |
| PC-LS-02 | A Swift Charts line graph, 170 pt tall (scales with Dynamic Type), of the last **10** scores **with the selected hole count** (PC-ST-05): the player's completed, non-trashed Maynard rounds **and** their outside scores (#252) merged by date (a tie on the date by id; an outside score counts as played at 12:00 UTC on its date, as in HC-CA-12), oldest on the left, evenly spaced. A synced duplicate (same id, DM-RD-01) is plotted once, the oldest copy, as in the handicap (HC-CA-13); Avg score and Best count a duplicate round once too. Built by `LatestScores.make` (pure); Avg score and Best (§4) stay Maynard-only. Switching the toggle animates to the other series. |
| PC-LS-03 | A `LineMark` (Lake 600 / `primaryAction`, 2.5 pt, round caps and joins) over an `AreaMark` (`primaryAction` at 10 %) down to the bottom of the plot, and an 8 pt Lake point on every round. Three whole-number gridlines (`divider`) with leading labels (SF Pro 13, Moss 600 / `textSecondary`) that cover every score: from the lowest score, a step reaching the highest in two (74…83 → 74, 79, 84; 74…82 → 74, 78, 82); a spread under 2 is centered with a step of 1 (all 80 → 79, 80, 81), so the lines stay distinct. The plot runs half a step under the bottom gridline (room for the best round's label) to a quarter step over the top one. Up is a worse score. |
| PC-LS-04 | A dashed rule (Moss 600 / `textSecondary`, 1.25 pt, 4 on 4 off) at the **average of the plotted rounds**, to one decimal. |
| PC-LS-05 | The **best** round (the lowest score; the newest of a tie) has an 11 pt orange point (`flag400`, the same in both appearances) with a 2 pt ring in the card's color, and its score under it (SF Pro 600 16, `underPar`). The **newest** round has the same marker in Lake with its score under it, trailing-aligned, in Lake (the artboard puts both labels under their points). When the newest is also the best, the best styling wins and only one label shows. |
| PC-LS-06 | Three dates under the plot (SF Pro 13, Moss 600, caps, "SEP 6"), each under its point: the first round's (starting at it), the middle round's (index count ÷ 2, centered) and the newest's (ending at it). With 2 rounds there's no middle date. The day is formatted in the injected locale and calendar; an outside score's stored day is read in UTC (DM-OS-04), so it's the date that was picked. |
| PC-LS-07 | Fewer than 2 rounds with the selected count → the chart is replaced by the hint "Play 2 rounds to see your latest scores", identifier `playerCard.latestScores.hint`. |
| PC-LS-08 | One accessibility element, identifier `playerCard.latestScores`, reading e.g. "Line graph of the last 10 18-hole scores, from 82 on Sep 6 to 77 on Nov 8, best 74 on Oct 25". |

## 5a. Scores by Hole (#270)
Artboard: "Player card — scores by hole type". The user placed it second, under Latest Scores; the artboard draws it after the handicap chart.

| ID | Requirement |
|----|-------------|
| PC-SH-01 | Directly under Latest Scores (the second card), a white `ContentCard` titled "SCORES BY HOLE" (the `section` style, caps). `ScoresByHoleCard`. |
| PC-SH-02 | A 3 × 3 `Grid` (built at once, not lazy), one cell per course hole 1–9: the hole number (`title`, tabular) with "Par {n}" and "Avg {4.5}" beside it (`caption`, Moss 600 / `textSecondary`). The par comes from the course data (X-16), not the artboard's sample pars. The average is the mean of the player's scores on the hole, to one decimal in the locale; "—" without any. |
| PC-SH-03 | Under the header, six equal-width bars over a `divider` hairline, 58 pt tall at the default size (scales with Dynamic Type), labelled 2, 3, 4, 5, 6 and + (`labelMicro`). The first bin also counts aces, and + counts 7 and over. The tallest bar of the hole fills the plot and the others are scaled to it; an empty bin draws no bar. Top corners 3 pt, bottom 1 pt. |
| PC-SH-04 | A bar's colour is its score against the hole's par: under par orange (`flag400`), par Lake (`primaryAction`), over par Sage 300 (`sage300`). |
| PC-SH-05 | Under the grid, a legend of three 10 pt swatches: "Under par", "Par", "Over par" (`caption`, `textSecondary`), hidden from VoiceOver. |
| PC-SH-06 | **Data** (`ScoresByHole`, pure, 100 %): the player's completed, non-trashed Maynard rounds of both lengths, a synced duplicate once (DM-RD-01). Holes 10–18 of an 18-hole round replay holes 1–9 (`RoundHoleBuilder`), so they count there. Outside scores have no hole scores and don't count. Every completed round counts; raw strokes, no cap; an unscored hole is skipped. The 9 / 18 toggle doesn't filter it (PC-ST-05). Built on load, so it follows Edit and deletions (PC-DT-04). |
| PC-SH-07 | No completed round → the card isn't shown (no hint). |
| PC-SH-08 | Each cell is one accessibility element, identifier `playerCard.scoresByHole.hole.{n}`, reading e.g. "Hole 1, par 4, average 4.5: 1 score of 3 and 8 scores of 4" (plural variants; "… of 2 or less", "… of 7 or more" for the end bins). The card is `playerCard.scoresByHole`. |

## 6. Handicap trend chart
| ID | Requirement |
|----|-------------|
| PC-HC-01 | Under Scores by Hole (§5a), or Latest Scores without it, a white `ContentCard` titled "HANDICAP · 12 MONTHS" with the trailing range "{11.2} → {8.4}" (SF Pro 13, Moss 600). |
| PC-HC-02 | A Swift Charts `LineMark` + `AreaMark` (Lake 600 line 2.5 pt, Lake 600 @ 10 % area from the bottom gridline) of monthly handicap index over the last 12 months, 150 pt tall (scales with Dynamic Type). Y axis: 3 whole-number gridlines with leading labels (e.g. 8 / 10 / 12; "+2" for a plus index), at least 1 apart and covering the series (`HandicapTrend.gridlines`). Under the plot: the first, middle and last month (DEC / MAY / NOV; first and last with 2 points). |
| PC-HC-03 | The last point has a 10 pt Lake 600 dot with a white ring and its value above it (SF Pro 600 16), e.g. "8.4". |
| PC-HC-04 | The series is the **calculated** index at the end of each month, from `HandicapManager.series` (18-handicap HC-MG-06; nothing is stored). A starting index only seeds the early rounds (HC-CA-14); it's never plotted itself. Not affected by the 9 / 18 toggle. Rebuilt only when the manager's `revision` changes. |
| PC-HC-05 | One accessibility element, identifier `playerCard.handicapChart`, reading the summary: "Handicap index fell from 11.2 last December to 8.4 this November" (shared with Home, `PlayerSummaryBuilder.chartSummary`). |
| PC-HC-06 | Hidden (no card at all) when there are fewer than 2 data points. |

## 7. Previous rounds (month groups of round rows)
| ID | Requirement |
|----|-------------|
| PC-PR-01 | Header "PREVIOUS ROUNDS" (`SectionHeader`, SF Pro 700 22) with the trailing caption "{n} this year" (SF Pro 600 13, Moss 600, identifier `playerCard.roundsThisYear`): the player's completed rounds in the current calendar year of the injected clock (`RoundMonthGrouping.countThisYear`). |
| PC-PR-02 | The rounds are grouped by month, exactly as in All rounds (01-home HOME-AR-04): a month header ("NOVEMBER 2026", SF Pro 700 17, tracking 0.08 em) over a `CardContainer` (radius 20) of `RoundRow`s separated by hairlines. |
| PC-PR-03 | Each row is the shared `RoundRow` (HOME-RR-03, HOME-AR-05): weekday caps over the day number; "Maynard Golf Club" with trailing meta "{9 \| 18} holes · {Tee}"; one `PlayerScoreChip` per player **in the round** (not only this player), in round order; a trailing chevron. |
| PC-PR-04 | This player's chip looks the same as the others (no highlight). There's no weather, no to-par and no large score on the row. The old 2-column `RoundTile` grid is gone. |
| PC-PR-05 | Each row is one accessibility element, with the same label as in All rounds (HOME-RR-05). |
| PC-PR-06 | The list holds only **completed** rounds this player took part in. Rounds in progress aren't listed here. |
| PC-PR-07 | Newest first (a tie on the start is broken by id), built lazily (`LazyVStack`). Unaffected by the 9 / 18 toggle. Grouping is `RoundMonthGrouping.sections` (pure, shared with All rounds); each month header has the identifier `playerCard.month.{yyyymm}`. |
| PC-PR-08 | Tapping a row pushes **Round detail**. |
| PC-PR-09 | There's no search and no swipe-to-delete here. Rounds are deleted only in All rounds (HOME-AR-07). |
| PC-PR-10 | No completed rounds → the section shows "No rounds yet" instead of the list (identifier `playerCard.rounds.empty`). |

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
| PC-DT-01 | `PlayerCardViewModel` is injected with `PlayerRepository`, `RoundRepository`, `OutsideScoreRepository` (the player's outside scores, for Latest Scores), `HandicapManager` (18-handicap), `CourseProvider` (the course name and pars on the rows), an `AppClock` (this year) and the calendar and locale (the graph's dates). It exposes `profile`, `holeFilter: HoleCount` (9 / 18), `stats` (avg, best for the filter, Maynard rounds only), `latestScores` (for the filter), `handicapTrend`, `roundSections` (month groups of the shared `RoundSummary`s from `RoundSummaryBuilder`) and `roundsThisYear`. |
| PC-DT-02 | Stats, the default-filter rule, Scores by Hole (`ScoresByHole`) and the Latest Scores and handicap series are pure functions with 100 % unit coverage (0, 1, 2, 3, 10 and 25 rounds; Maynard and outside scores mixed, the same day too; ties; 9 vs 18 holes; all scores equal; 9-hole and 100+ ranges; the most-played tie → 18). |
| PC-DT-03 | The stat rules live in `PlayerCardStats` (completed rounds newest first, the default hole count, Avg / Best per count), which Home's `PlayerSummaryBuilder.stats` also uses, so the two screens agree. The handicap comes from `HandicapManager` (18-handicap). |
| PC-DT-04 | Observes the player, rounds and outside scores (the repositories' shared change stream), so returning from Edit, a deleted round or an outside score added or deleted on the Handicap screen updates the card. A player who no longer exists closes the card (`Router.close`), back to the screen it was opened from. |

## 10. Accessibility identifiers
`playerCard.back`, `playerCard.edit`, `playerCard.profile`, `playerCard.avatar`, `playerCard.name`, `playerCard.handicap`, `playerCard.stat.avg`, `playerCard.stat.best`, `playerCard.holes`, `playerCard.latestScores`, `playerCard.latestScores.hint`, `playerCard.scoresByHole`, `playerCard.scoresByHole.hole.{n}`, `playerCard.handicapChart`, `playerCard.roundsThisYear`, `playerCard.round.{id}`, `playerCard.retry`; the screen is `screen.playerCard`.
