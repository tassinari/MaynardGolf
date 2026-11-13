# 09 — Player Card

**Artboards:** Player card · Player card — scrolled to rounds
**Entry:** Home › player row, All players › row.
**Exit:** Back circle (accessibility "Back to players" / "Back") → previous screen.

## 1. Overview
A scrolling profile for one player: an identity header with handicap, summary stats, a score histogram, a handicap trend chart and a grid of previous rounds. When scrolled, a compact sticky header appears.

## 2. Top bar
| ID | Requirement |
|----|-------------|
| PC-TOP-01 | Leading back circle button. Centered caps title "PLAYER CARD". |
| PC-TOP-02 | *Inferred:* a trailing "Edit" action opens Add player in Edit mode, with "Delete player" (destructive, confirmation, cascades to their `PersonRound`s as in v1). |

## 3. Profile header
| ID | Requirement |
|----|-------------|
| PC-HDR-01 | A large `PlayerAvatar` (about 88–104 pt), accessibility "Photo of {first name}". |
| PC-HDR-02 | Full name (Sofia 700 / Inter 600, large). |
| PC-HDR-03 | Subtitle "{Home club} · Member since {year}". The year is the player's created date or first round (*inferred*). |
| PC-HDR-04 | A handicap block: "HCP INDEX" label, the index (Sofia 700, large) and a trend line "▼ {2.8} THIS YEAR" (down = improved, Rough 600 / Lake; up = "▲", Flag). Hidden if there's no history. |

## 4. Stat tiles
| ID | Requirement |
|----|-------------|
| PC-ST-01 | Three `StatTile`s in a row: **Rounds** (count), **Avg score** (one decimal, completed 18-hole-equivalent rounds) and **Best** (lowest gross). |
| PC-ST-02 | No rounds → "—" values. |

## 5. Score histogram
| ID | Requirement |
|----|-------------|
| PC-HI-01 | Card titled "SCORES · LAST 20 ROUNDS" with the trailing caption "rounds". |
| PC-HI-02 | A Swift Charts `BarMark` histogram: buckets 2 strokes wide, starting at the minimum score rounded down to even (e.g. 74–75, 76–77 … 84+). The last bucket is open-ended. Lake 600 bars with a top radius of 6 and the count label above each bar. |
| PC-HI-03 | Up to the last 20 completed rounds. Up to 6 buckets. |
| PC-HI-04 | Accessibility summary, e.g. "Histogram of last 20 round scores: 74–75 two rounds, 76–77 four, …". |
| PC-HI-05 | Hidden, with a hint "Play 3 rounds to see your score spread", when there are fewer than 3 rounds (*inferred*). |

## 6. Handicap trend chart
| ID | Requirement |
|----|-------------|
| PC-HC-01 | Card titled "HANDICAP · 12 MONTHS" with the trailing range "{11.2} → {8.4}". |
| PC-HC-02 | A Swift Charts `LineMark` + `AreaMark` (Lake 600 line, Lake @ low-opacity area) of monthly handicap index over the last 12 months. Y axis: 3 gridlines (e.g. 12 / 10 / 8). X axis labels: first, middle and last month (DEC / MAY / NOV). |
| PC-HC-03 | The last point has a 5 pt Lake 600 dot with a white ring and a value label above it. |
| PC-HC-04 | Data comes from `HandicapRevision` history (GHIN sync), falling back to an index computed from rounds (existing `Handicap.swift`). |
| PC-HC-05 | Accessibility summary: "Handicap index fell from 11.2 last December to 8.4 this November". |
| PC-HC-06 | Hidden when there are fewer than 2 data points. |

## 7. Previous rounds
| ID | Requirement |
|----|-------------|
| PC-PR-01 | Header "PREVIOUS ROUNDS" with the trailing caption "{n} this year". |
| PC-PR-02 | A 2-column grid (gap 10) of `RoundTile`s (white, radius 20): date "NOV 8" (Sofia 600 caps, Moss 600), a `WeatherIcon` + temperature (top-right), gross score (Sofia 700 large) + `ToParText` (Sofia 700 18; under par `underPar`), course name and "{Blue tees} · Par {72}". |
| PC-PR-03 | Newest first, paginated / lazy (`LazyVGrid`). |
| PC-PR-04 | Tapping a tile pushes **Round detail**. |
| PC-PR-05 | Weather kinds: sunny, partly cloudy, cloudy, rain, windy. Accessibility "{Condition}, {temp} degrees". |

## 8. Compact sticky header (scrolled state)
| ID | Requirement |
|----|-------------|
| PC-CH-01 | Once the profile header scrolls off, a compact bar fades in: back button, 36–40 pt avatar, full name, and "HCP" over the index on the right. |
| PC-CH-02 | The handicap chart's month axis (DEC / MAY / NOV) stays as a small tab under the compact header, showing context (as in the visual). *Low priority.* |
| PC-CH-03 | The back button in the compact header scrolls to top on the first tap (accessibility "Back to top of player card") and goes back on the second tap. *As drawn. Confirm.* |
| PC-CH-04 | ~~Opening scrolled to rounds from "See all"~~ **Removed.** Home › See all now opens **All rounds** (01-home §6). |

## 9. Data
| ID | Requirement |
|----|-------------|
| PC-DT-01 | `PlayerCardViewModel` is injected with `PlayerRepository`, `RoundRepository` and a `Clock`. It exposes `profile`, `stats`, `histogram: [Bucket]`, `handicapSeries: [Point]`, `rounds: [RoundTileModel]`. |
| PC-DT-02 | Stats, bucketing and series building are pure functions with 100 % unit coverage (empty, 1 round, 20+ rounds, ties, 9 vs 18 holes). |
| PC-DT-03 | Builds on the existing `Stats.swift` / `Handicap.swift` logic. Refactor it to be testable. |

## 10. Accessibility identifiers
`playerCard.back`, `playerCard.edit`, `playerCard.hcp`, `playerCard.stat.rounds`, `playerCard.stat.avg`, `playerCard.stat.best`, `playerCard.histogram`, `playerCard.handicapChart`, `playerCard.round.{id}`, `playerCard.compactHeader`.

## Open questions
1. "Home club" and "Member since": are these new Player fields or derived?
2. Should Avg score / Best include 9-hole rounds (shown separately?) or only 18-hole rounds? Proposal: separate 9- and 18-hole stats, defaulting to 18.
3. Is the compact-header back button meant to scroll to top or go back?
