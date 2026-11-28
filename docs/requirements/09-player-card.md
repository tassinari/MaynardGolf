# 09 — Player Card

**Artboards:** Player card · Player card — scrolled to rounds
**Entry:** Home › player row, All players › row.
**Exit:** Back circle (accessibility "Back to players") → previous screen.

## 1. Overview
A scrolling profile for one player. It has a top bar with Edit, a profile card (a ringed avatar with the handicap index and the name beside it; a tap opens the Handicap screen), a Latest Scores line graph with the **Show 9 holes / Show 18 holes** button and All-time best / Average tiles, a Scores by Hole grid, a Handicap History chart (a tap opens the Handicap screen) and the player's previous rounds, listed by month in the same rows as All rounds. The top bar stays pinned and picks up a blurred background once content scrolls under it.

**Design note:** the main "Player card" artboard still shows Previous rounds as an older list inside one card. That card is **outdated**. Previous rounds follow "Player card — scrolled to rounds" (§7): month groups of `RoundRow`s with a score chip per player.

## 2. Top bar
| ID | Requirement |
|----|-------------|
| PC-TOP-01 | Leading 44 pt back circle (`CircleIconButton`, `surfaceRaised`, chevron-left), accessibility "Back to players", identifier `playerCard.back`. It always goes back, from any scroll position (no scroll-to-top behavior). |
| PC-TOP-02 | Title "Player card" (SF Pro 700 22, `section` tracking −0.015 em), **leading-aligned** next to the back button (not centered): `DSNavigationBar` with `titleAlignment: .leading`. |
| PC-TOP-03 | Trailing `NeutralPillButton` "Edit" (identifier `playerCard.edit`, disabled until the player has loaded). It presents the **Add player form in its Edit configuration** (`SheetRoute.editPlayer`, 05-add-player §9): prefilled, title "Edit player", button "Save", plus "Delete player". On return the card reflects the changes (PC-DT-04). After a delete, the card pops back to the screen it was opened from (`Router.close(.playerCard(id))`). |
| PC-TOP-04 | The bar is pinned (`dsNavigationBar`). At the top of the scroll it's transparent on the page background. Once content scrolls beneath it, it shows `background` @ 78 % + blur with a 1 pt hairline at the bottom (`background: .scrollEdge(isScrolled:)`, fed by `onScrollGeometryChange` through `DSBarBackground.isScrolled`). |

## 3. Profile card
| ID | Requirement |
|----|-------------|
| PC-HDR-01 | One white `ContentCard` (radius 22, on the soft card shadow, padding 18), as the Player card — score graph artboard (iPhone C) draws it: the ringed avatar on the left; on the right, 16 pt away, a column as tall as the avatar's circle with the handicap index (PC-HDR-04) at the top and the full name at the bottom, both trailing-aligned. There's no switch and there are no stats on this card: the 9 / 18 control and All-time best / Average are on Latest Scores (PC-ST-01, 04). At accessibility sizes the avatar, index and name stack, leading. |
| PC-HDR-02 | 96 pt `PlayerAvatar` (`AvatarSize.profile`, `ringed: true`): the photo, decoded at 288 px (96 pt at 3×, `PlayerCardViewModel.avatarPixels`), or the first initial (SF Pro 700 44) on the player's color, inside a 3 pt ring in the player's color (`PlayerPalette.backgroundToken`, e.g. Lake), so the avatar takes 102 pt (DS-ID-01). With the initial the ring reads as a slightly larger circle in the same color. Accessibility "Photo of {full name}". |
| PC-HDR-03 | Full name (SF Pro 600 22, the `profileName` style), trailing-aligned at the bottom of the column beside the avatar, wrapping to two lines, then truncating (no limit and leading at accessibility sizes). There's **no** subtitle (no home club or member-since). |
| PC-HDR-04 | The index block, trailing at the top of the column: "HCP INDEX" (`labelSmall`, caps, `textSecondary`, `PlayerSummaryCard.indexLabel`) centered over the index (`numeral`, tabular, `emphasis`), e.g. "10.1", "+2.1" or "—" (PC-HDR-05). It's the card's one button element, identifier `playerCard.handicap`, labeled with PC-HDR-05's wording. |
| PC-HDR-05 | The index (on the Handicap Index row, PC-HX-01) is the calculated index, or the starting index with fewer than 3 usable rounds (18-handicap HC-SRC-01, 02). No starting index and fewer than 3 rounds → "—". Accessibility "Handicap index {8.4}", "Handicap index {8.4}, calculated" for a calculated value, and "No handicap index" for "—" (`PlayerCardStats.handicapAccessibilityLabel`). |
| PC-HDR-06 | A tap **anywhere on the profile card** (or the index button) pushes the Handicap screen for this player (`Destination.handicap(id)`, 19-handicap-screen). The avatar and name stay separate accessibility elements. |

## 4. All-time best, Average and the 9 / 18 button
| ID | Requirement |
|----|-------------|
| PC-ST-01 | Inside the Latest Scores card (§5), under the graph or its hint: All-time best and Average, two equal tiles side by side 10 pt apart (`PlayerCardStat`), each a centered value over its caption on a `surfaceRaised` tile (radius 14), as the Player card — score graph artboard draws them. |
| PC-ST-02 | **Average**: the value (SF Pro 700 22, the `section` style, tabular, `emphasis`, one decimal, e.g. "78.9") over the caption "Average" (SF Pro 13, `textSecondary`). VoiceOver reads "Average, 78.9"; identifier `playerCard.stat.avg`. The average gross of **all** the player's completed Maynard rounds with the selected hole count, not only the 10 the graph plots. |
| PC-ST-03 | **All-time best**: the lowest gross (styled as PC-ST-02, e.g. "74") of **all** the player's completed Maynard rounds with the selected hole count, over the caption "All-time best"; identifier `playerCard.stat.best`. Shown first, left of Average. |
| PC-ST-04 | **9 / 18 button**: a text button on the trailing side of the Latest Scores header (§5), on the title's baseline: **"Show 9 holes"** while 18 is shown, **"Show 18 holes"** while 9 is (`PlayerCardViewModel.holesButtonTitle`). `link` SF Pro 600 14 (`.dsCompactTextLink`, `linkCompact`), no fill, 44 pt tap target. A tap switches the hole count (`toggleHoles()`), animated. It shows whether or not the other count has rounds (the hint, PC-LS-07, covers an empty series). It's the card's only 9 / 18 control. Identifier `playerCard.holes`; its label is the action. When the title and button don't fit side by side (accessibility sizes) the button goes under the title. |
| PC-ST-05 | The button filters **All-time best, Average and the Latest Scores graph** (§5). It doesn't affect the handicap index, the handicap chart, Scores by Hole (§5a) or Previous rounds. |
| PC-ST-06 | The hole count when the card opens: the one this player has **more completed rounds of**. A tie or no rounds → 18. The choice isn't remembered between visits. |
| PC-ST-07 | No completed rounds with the selected count → All-time best and Average show "—". |
| PC-ST-08 | There's no Rounds count and no Holes tile (both removed from the design). |

## 4a. Handicap Index row (#253)
| ID | Requirement |
|----|-------------|
| PC-HX-01 | ~~Handicap Index row~~ **Removed**: the index is on the profile card (PC-HDR-04), as the Player card — score graph artboard draws it. |
| PC-HX-02 | ~~Row opens Handicap~~ **Moved**: the profile card (PC-HDR-06) and Handicap History (PC-HC-07) open the Handicap screen. |
| PC-HX-03 | ~~Row identifier~~ **Moved**: `playerCard.handicap` is the profile card's index button (PC-HDR-04). |

## 5. Latest Scores (#251)
| ID | Requirement |
|----|-------------|
| PC-LS-01 | Under the profile card, a white `ContentCard` titled "Latest Scores" (the `section` style, sentence case), with no caption, the 9 / 18 button (PC-ST-04) trailing in its header and All-time best / Average (PC-ST-01) under the graph. `LatestScoresCard`. |
| PC-LS-02 | A Swift Charts line graph, 170 pt tall (scales with Dynamic Type), of the last **10** scores **with the selected hole count** (PC-ST-05): the player's completed, non-trashed Maynard rounds recorded in the app, **only**: outside scores entered on the Handicap screen (#252) never appear (#285). Ordered by date (a tie on the date by id), oldest on the left, evenly spaced. A synced duplicate round (same id, DM-RD-01) is plotted once, as All-time best and Average count it. Built by `LatestScores.make` (pure). Switching the hole count (PC-ST-04) animates to the other series. |
| PC-LS-03 | A `LineMark` (`emphasis`, 2.5 pt, round caps and joins) over an `AreaMark` (`emphasis` at 10 %) down to the bottom of the plot, and an 8 pt Blue point on every round. Three whole-number gridlines (`divider`) with leading labels (SF Pro 13, `textSecondary`) that cover every score: from the lowest score, a step reaching the highest in two (74…83 → 74, 79, 84; 74…82 → 74, 78, 82); a spread under 2 is centered with a step of 1 (all 80 → 79, 80, 81), so the lines stay distinct. The plot runs half a step under the bottom gridline (room for the best round's label) to a quarter step over the top one. Up is a worse score. |
| PC-LS-04 | A dashed rule (`textSecondary`, 1.25 pt, 4 on 4 off) at the **average of the plotted rounds**, to one decimal. |
| PC-LS-05 | The **best** round (the lowest score; the newest of a tie) has an 11 pt orange point (`bestScoreMarker`, the same in both appearances) with a 2 pt ring in the card's color, and its score under it (SF Pro 600 16, `underPar`). The **newest** round has the same marker in Blue with its score under it, trailing-aligned, in Blue (the artboard puts both labels under their points). When the newest is also the best, the best styling wins and only one label shows. |
| PC-LS-06 | Three dates under the plot (SF Pro 13, `textSecondary`, caps, "SEP 6"), each under its point: the first round's (starting at it), the middle round's (index count ÷ 2, centered) and the newest's (ending at it). With 2 rounds there's no middle date. The day is formatted in the injected locale and calendar. |
| PC-LS-07 | Fewer than 2 rounds with the selected count → the chart is replaced by the hint "Play 2 rounds to see your latest scores", identifier `playerCard.latestScores.hint`. |
| PC-LS-08 | One accessibility element, identifier `playerCard.latestScores`, reading e.g. "Line graph of the last 10 18-hole scores, from 82 on Sep 6 to 77 on Nov 8, best 74 on Oct 25". |

## 5a. Scores by Hole (#270)
Artboard: "Player card — scores by hole type". The user placed it second, under Latest Scores; the artboard draws it after the handicap chart.

| ID | Requirement |
|----|-------------|
| PC-SH-01 | Directly under Latest Scores (the second card), a white `ContentCard` titled "Scores by Hole" (the `section` style, sentence case). `ScoresByHoleCard`. |
| PC-SH-02 | A 3 × 3 `Grid` (built at once, not lazy), one cell per course hole 1–9: the hole number (`holeNumeral`, SF Pro 700 34, tabular) with "Par {n}" and "Avg {4.5}" beside it (`caption`, `textSecondary`). The par comes from the course data (X-16), not the artboard's sample pars. The average is the mean of the player's scores on the hole, to one decimal in the locale; "—" without any. |
| PC-SH-03 | Under the header, 3–5 equal-width bars 4 pt apart, with no baseline, 58 pt tall at the default size (scales with Dynamic Type), one per score against the hole's par, labelled with the strokes (`caption`, `textSecondary`), e.g. 3, 4, 5, 6, + on a par 4 (#288). Each hole shows only the range the player has made there, but always birdie, par and bogey: a hole of pars and bogeys shows 3 bars. Without an eagle the bins are birdie, par, bogey, double and + (triple or worse), the last two only as far as the player's worst score. With an eagle or better (an ace too), the first bin is eagle and counts anything lower, and double joins + (double or worse), so a hole never shows more than 5. *Why: eagle and ace bins were empty for most players and took room (#288).* The tallest bar of the hole fills the plot and the others are scaled to it; an empty bin draws no bar. Top corners 5 pt, bottom 2 pt, as the Player card — scores by hole type artboard (iPhone C). |
| PC-SH-04 | A bar's colour is its score against the hole's par: under par Green 400 (`scoreBinUnder`), par Blue (`scoreBinPar`), one over (bogey) Orange 500 (`scoreBinBogey`), two or more over Red 500 (`scoreBinDouble`), as Fairway C's hole histogram. The + bin is always two or more over (`scoreBinDouble`). |
| PC-SH-05 | Under the grid, a legend of four 10 pt swatches (radius 3): "Under par", "Par", "Bogey", "Double+" (`caption`, `chartLegend`), on one row or, when they don't fit, stacked; hidden from VoiceOver. "Bogey" and "Double+" are the scorecard legend's strings (MaynardUI `ScoreLegend.Item`). |
| PC-SH-06 | **Data** (`ScoresByHole`, pure, 100 %): the player's completed, non-trashed Maynard rounds of both lengths, a synced duplicate once (DM-RD-01). Holes 10–18 of an 18-hole round replay holes 1–9 (`RoundHoleBuilder`), so they count there. Outside scores have no hole scores and don't count. Every completed round counts; raw strokes, no cap; an unscored hole is skipped. The 9 / 18 button doesn't filter it (PC-ST-05). Built on load, so it follows Edit and deletions (PC-DT-04). |
| PC-SH-07 | No completed round → the card isn't shown (no hint). |
| PC-SH-08 | Each cell is one accessibility element, identifier `playerCard.scoresByHole.hole.{n}`, reading e.g. "Hole 1, par 4, average 4.5: 1 score of 3 and 8 scores of 4" (plural variants; "… of 2 or less" for the eagle bin, except an ace on a par 3, which is "… of 1"; "… of 7 or more" for +). The card is `playerCard.scoresByHole`. |

## 6. Handicap History
| ID | Requirement |
|----|-------------|
| PC-HC-01 | Under Scores by Hole (§5a), or Latest Scores without it, a white `ContentCard` titled "Handicap History" (the `section` style) with a trailing "More" text button (`.dsCompactTextLink`, identifier `playerCard.handicapHistory.more`) on the title's baseline, as the Player card — score graph artboard draws it. No range caption. Card identifier `playerCard.handicapHistory`. |
| PC-HC-02 | A Swift Charts `LineMark` + `AreaMark` (Blue 500 line 2.5 pt, Blue 500 @ 10 % area from the bottom gridline) of the handicap index over a span that **fits the history** (`HandicapTrend.make`), 150 pt tall (scales with Dynamic Type), on a time axis from the first point to now. **Starting out** (the first point under 2 months old): a point at the end of each day with a round, carried to now. **Longer**: a point at each month end from the first point's month, each the index of the last day by then, the current month ending now. **Capped at 2 years** (`HandicapTrend.maxMonths`, 24): older history starts the chart 24 months back with the value it had then. Y axis: 3 whole-number gridlines with leading labels (e.g. 8 / 10 / 12; "+2" for a plus index), at least 1 apart and covering the series (`HandicapTrend.gridlines`). Under the plot: the first, middle and last point's date (caps): "NOV 3" by day, "DEC" by month, "DEC 25" when the chart spans a year or more; first and last with 2 points, one with 1. A lone point (the first index today) sits at the trailing edge. |
| PC-HC-03 | The last point has a 10 pt Blue 500 dot with a white ring and its value above it (SF Pro 600 16), e.g. "8.4". |
| PC-HC-04 | The points are the **calculated** index after each day with a usable round, from `HandicapManager.history` (18-handicap HC-MG-09; nothing is stored). A starting index only seeds the early rounds (HC-CA-14); it's never plotted itself. Not affected by the 9 / 18 toggle. Rebuilt only when the manager's `revision` changes. |
| PC-HC-05 | One accessibility element, identifier `playerCard.handicapChart`, reading the summary (`HandicapTrend.summary`): "Handicap index fell from 11.2 in November 2025 to 8.4 now" ("rose"), "… on November 3 …" by day, "Handicap index has stayed at 8.4 since November 2025", or "Handicap index started at 11.4 on November 27" for one point. |
| PC-HC-06 | **Always shown.** Until the player has a calculated index (3 usable rounds, HC-SRC-01) the chart is replaced by the hint "Handicap will appear here when you play 3 rounds" (`body`, `textSecondary`, centered), identifier `playerCard.handicapChart.hint`. From the first index there's always a chart, one point or more. |
| PC-HC-07 | A tap **anywhere on the card** or on More pushes the Handicap screen for this player (`Destination.handicap(id)`), with or without a chart. |

## 7. Previous rounds (month groups of round rows)
| ID | Requirement |
|----|-------------|
| PC-PR-01 | Header "Previous rounds" (`SectionHeader`, SF Pro 700 22) with the trailing caption "{n} this year" (SF Pro 600 13, `textSecondary`, identifier `playerCard.roundsThisYear`): the player's completed rounds in the current calendar year of the injected clock (`RoundMonthGrouping.countThisYear`). |
| PC-PR-02 | The rounds are grouped by month, exactly as in All rounds (01-home HOME-AR-04): a month header ("NOVEMBER 2026", SF Pro 700 17, tracking 0.04 em) over a `CardContainer` (radius 20) of `RoundRow`s separated by hairlines. |
| PC-PR-03 | Each row is the shared `RoundRow` (HOME-RR-03, HOME-AR-05), as the Player card — scrolled to rounds artboard: the date "{Nov 8}" with trailing meta "{9 \| 18} holes · {Tee}"; one `PlayerScoreChip` per player **in the round** (wide with an avatar for one or two players, a first-name-over-gross tile for three or four, DS-CH-08) (not only this player), in round order; a trailing chevron. |
| PC-PR-04 | This player's chip looks the same as the others; only the round's lowest gross is highlighted (DS-CH-08). There's no weather, no to-par and no large score on the row. The old 2-column `RoundTile` grid is gone. |
| PC-PR-05 | Each row is one accessibility element, with the same label as in All rounds (HOME-RR-05). |
| PC-PR-06 | The list holds only **completed** rounds this player took part in. Rounds in progress aren't listed here. |
| PC-PR-07 | Newest first (a tie on the start is broken by id), built lazily (`LazyVStack`). Unaffected by the 9 / 18 toggle. Grouping is `RoundMonthGrouping.sections` (pure, shared with All rounds); each month header has the identifier `playerCard.month.{yyyymm}`. |
| PC-PR-08 | Tapping a row pushes **Round detail**. |
| PC-PR-09 | There's no search and no swipe-to-delete here. Rounds are deleted only in All rounds (HOME-AR-07). |
| PC-PR-10 | No completed rounds → the section shows "No rounds yet" instead of the list (identifier `playerCard.rounds.empty`). |

## 8. Scrolled state
| ID | Requirement |
|----|-------------|
| PC-CH-01 | There's **no** separate compact header with avatar or HCP. When scrolled, the same top bar (back, "Player card", Edit) stays pinned with its blurred background (PC-TOP-04). |
| PC-CH-02 | ~~Month axis tab under the header~~ **Removed.** In the "scrolled to rounds" artboard, that strip is just the bottom of the handicap chart card scrolling under the bar, not a separate element. |
| PC-CH-03 | ~~Compact back button scrolls to top~~ **Removed.** Back always goes back (PC-TOP-01). |
| PC-CH-04 | ~~Opening scrolled to rounds from "See all"~~ **Removed.** Home › See all opens **All rounds** (01-home §6). |

## 9. Data
| ID | Requirement |
|----|-------------|
| PC-DT-01 | `PlayerCardViewModel` is injected with `PlayerRepository`, `RoundRepository`, `HandicapManager` (18-handicap), `CourseProvider` (the course name and pars on the rows), an `AppClock` (this year) and the calendar and locale (the graph's dates). It exposes `profile`, `holeFilter: HoleCount` (9 / 18), `stats` (avg, best for the filter, Maynard rounds only), `latestScores` (for the filter), `handicapTrend`, `roundSections` (month groups of the shared `RoundSummary`s from `RoundSummaryBuilder`) and `roundsThisYear`. |
| PC-DT-02 | Stats, the default-filter rule, Scores by Hole (`ScoresByHole`) and the Latest Scores and Handicap History series are pure functions with 100 % unit coverage (0, 1, 2, 3, 10 and 25 rounds; rounds on the same day; ties; 9 vs 18 holes; all scores equal; 9-hole and 100+ ranges; the most-played tie → 18). |
| PC-DT-03 | The stat rules live in `PlayerCardStats` (completed rounds newest first, the default hole count, Avg / Best per count), which Home's `PlayerSummaryBuilder.stats` also uses, so the two screens agree. The handicap comes from `HandicapManager` (18-handicap). |
| PC-DT-04 | Observes the player, rounds and outside scores (the repositories' shared change stream), so returning from Edit, a deleted round or an outside score added or deleted on the Handicap screen updates the card (an outside score changes only the index and Handicap History, through `HandicapManager`). A player who no longer exists closes the card (`Router.close`), back to the screen it was opened from. |

## 10. Accessibility identifiers
`playerCard.back`, `playerCard.edit`, `playerCard.profile`, `playerCard.avatar`, `playerCard.name`, `playerCard.handicap`, `playerCard.stat.avg`, `playerCard.stat.best`, `playerCard.holes` (the 9 / 18 button on Latest Scores), `playerCard.latestScores`, `playerCard.latestScores.hint`, `playerCard.scoresByHole`, `playerCard.scoresByHole.hole.{n}`, `playerCard.handicapChart`, `playerCard.roundsThisYear`, `playerCard.round.{id}`, `playerCard.retry`; the screen is `screen.playerCard`.
