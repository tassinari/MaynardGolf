# 04 — New Round

**Artboard:** New round
**Entry:** Home › "New round" (full-screen cover).
**Exit:** "Cancel" → Home. "Tee off" → Hole play (hole 1).

## 1. Overview
A Chalk 50 screen with a `DSNavigationBar` (Cancel / "NEW ROUND"), a **Holes** choice (9 / 18), a **Tees** grid, a **Players** multi-select list and a sticky "Tee off" button. It replaces the v1 `NewGameView` + `TeeSelectorView`.

## 2. Navigation bar
| ID | Requirement |
|----|-------------|
| NR-NAV-01 | Leading `NeutralPillButton` "Cancel" dismisses with no changes. If any selection changed, *inferred*: no confirmation needed (nothing is saved yet). |
| NR-NAV-02 | Centered title "NEW ROUND". A trailing 76 pt spacer keeps the title centered. |
| NR-NAV-03 | The bar is translucent Chalk @ 92 % + 16 pt blur. Content scrolls underneath it. |

## 3. Holes section (9 / 18)
Maynard GC is a **9-hole course**. An 18-hole round plays the 9 holes twice. *There's no wire for this control yet; it uses the standard segmented control.*

| ID | Requirement |
|----|-------------|
| NR-HOL-01 | `SectionHeader` "HOLES" above the Tees section, then a full-width `DSSegmented` with "9 holes" and "18 holes". Accessibility label "Number of holes". |
| NR-HOL-02 | Default: the last value used (stored in `SettingsStore` as `lastHoleCount`), falling back to **9**. |
| NR-HOL-03 | Choosing **18** builds the round from holes 1–9 followed by holes 1–9 again, numbered **10–18**. Holes 10–18 reuse par, yardage, green coordinates and aerial from holes 1–9. |
| NR-HOL-04 | Handicaps come from the official scorecard ([course-maynard-gc.md](course-maynard-gc.md) §3). **18 holes:** holes 1–9 use the front values (2, 10, 12, 6, 4, 18, 14, 8, 16) and holes 10–18 use the back values (1, 11, 13, 5, 3, 17, 7, 9, 15). **9 holes:** the 1–9 rank of the front values (1, 5, 6, 3, 2, 9, 7, 4, 8). |
| NR-HOL-05 | Tee card yardage (NR-TEE-06) and the round's par update live: 9 holes → front-nine totals, 18 → double. |
| NR-HOL-06 | The CTA label includes the hole count: "Tee off · 18 holes · Blue tees". |
| NR-HOL-07 | The hole count is stored on `Round.holeCount` and can't be changed after tee off. |

## 4. Tees section
| ID | Requirement |
|----|-------------|
| NR-TEE-01 | `SectionHeader` "TEES". |
| NR-TEE-02 | A 2-column grid (gap 8) of `TeeCard`s, one per tee on the course. |
| NR-TEE-03 | `TeeCard` (a `SelectableCard` button) shows a `TeeDot` + tee name (Inter 600 15), total yardage "{6,412} yds" (Sofia 700 22, grouped thousands, unit from Settings) and "Rating / slope {71.4} / {129}" (Caption 12). |
| NR-TEE-04 | Exactly one tee is selected (single-select). The selected card has a 2 pt Lake 600 inner stroke. Others have a 1 pt Card Border. Accessibility: `isSelected` trait. |
| NR-TEE-05 | The initial selection is the Settings › Default tees value, falling back to the first tee. |
| NR-TEE-06 | Yardage = the sum of hole yardages for that tee across the holes in the round (e.g. Blue 3,013 for 9 / 6,026 for 18). Rating and slope come from the course data, per tee (Blue / White 68.2 / 123, Yellow / Red 71.5 / 124 for 18 holes; 9 holes show half the rating with the same slope). |

## 5. Players section
| ID | Requirement |
|----|-------------|
| NR-PLY-01 | Header "PLAYERS · {selected} OF 4" (the count is Sofia 600 15, Moss 600) with trailing `TintedButton` "＋ Add player". |
| NR-PLY-02 | `CardContainer` listing **all** players as checkbox rows: avatar 40, name, "HCP {index}" caption, trailing 28 pt circular check (filled Lake 600 with a white check when selected, 2 pt Chalk 300 ring when not). Accessibility role checkbox / `isSelected`. |
| NR-PLY-03 | Maximum **4** players. Once 4 are selected, unselected rows fade to 50 % opacity and ignore taps. VoiceOver announces "Maximum of 4 players". |
| NR-PLY-04 | Default selection: the players from the most recent round (up to 4). Nothing is preselected on a fresh install. *Inferred.* No player is treated as the device owner. |
| NR-PLY-05 | Order: most recently played first, then alphabetical by first name. |
| NR-PLY-06 | "Add player" presents **Add player** as a sheet. On Create, the new player is added to the list and auto-selected if fewer than 4 are selected. |
| NR-PLY-07 | With no players, show an inline empty state prompting "Add player". |

## 6. Tee off button
| ID | Requirement |
|----|-------------|
| NR-CTA-01 | `StickyBottomCTA` with a full-width 56 pt `PrimaryButton` "Tee off · {9 \| 18} holes · {Tee} tees". The label updates live with the hole count and the selected tee. |
| NR-CTA-02 | Disabled when 0 players are selected (*inferred*). |
| NR-CTA-03 | On tap: create a `Round` (course, date, **holeCount**, tee, weather snapshot, `PersonRound` per player in selection order with that tee), save it, dismiss, and push **Hole play** at hole 1. If "Show at tee off" is on, also present **Local rules**. |
| NR-CTA-04 | Weather: request the current WeatherKit conditions at the course. If that fails, save the round without weather (non-blocking). |
| NR-CTA-05 | A save failure shows a localized alert and keeps the screen open. |

## 7. Data
| ID | Requirement |
|----|-------------|
| NR-DT-01 | `NewRoundViewModel` is injected with `PlayerRepository`, `RoundRepository`, `CourseProvider`, `SettingsStore`, `WeatherService`. |
| NR-DT-02 | The `Tee` model must become course-driven (name, color token, rating, slope) rather than a fixed enum, or the enum gets rating/slope. A data migration from v1 `Tee` is required. Unit-test the migration. |
| NR-DT-03 | `Course` JSON gains per-tee `rating` and `slope`. |

## 8. Accessibility identifiers
`newRound.cancel`, `newRound.holes`, `newRound.tee.{name}`, `newRound.addPlayer`, `newRound.player.{id}`, `newRound.count`, `newRound.teeOff`.

## Open questions
1. ~~Tees?~~ **Resolved:** the official card has Blue, White, Yellow and Red, so the app uses the course data (no Black tees). Rating / slope per tee is in course-maynard-gc.md §2.
2. ~~9 vs 18 holes?~~ **Resolved:** a 9 / 18 choice; 18 plays the 9 holes twice (§3).
3. Should the player order in the selection set the play / leaderboard order?
4. ~~Second-nine stroke indexes?~~ **Resolved:** yes, from the official scorecard (NR-HOL-04).
