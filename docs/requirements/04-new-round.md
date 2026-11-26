# 04 — New Round

**Artboard:** New round
**Entry:** Home › "New round" (full-screen cover).
**Exit:** "Cancel" → Home. "Tee off" → Hole play (hole 1).

## 1. Overview
A `background` (Gray 50) screen with a `DSNavigationBar` (Cancel / "New round"), a **Holes** choice (9 / 18), a **Tees** grid, a **Players** multi-select list and a sticky "Tee off" button. It replaces the v1 `NewGameView` + `TeeSelectorView`.

## 2. Navigation bar
| ID | Requirement |
|----|-------------|
| NR-NAV-01 | Leading `NeutralPillButton` "Cancel" dismisses with no changes and no confirmation (nothing is saved yet). It's disabled while Tee off saves, so a cancelled screen never starts a round. |
| NR-NAV-02 | Centered title "New round". A trailing 76 pt spacer keeps the title centered. |
| NR-NAV-03 | The bar is translucent `background` @ 78 % + 16 pt blur. Content scrolls underneath it. |

## 3. Holes section (9 / 18)
Maynard GC is a **9-hole course**. An 18-hole round plays the 9 holes twice. The control is drawn on the New round artboard.

| ID | Requirement |
|----|-------------|
| NR-HOL-01 | `SectionHeader` "Holes" above the Tees section, then a full-width two-segment `DSSegmented` control ("9 holes", "18 holes"; `segmentTrack` track, the selected segment `segmentSelected`). Accessibility: a picker labeled "Holes to play". |
| NR-HOL-02 | Default: the last value used (stored in `SettingsStore` as `lastHoleCount`). A first-time user sees **9 holes** selected. |
| NR-HOL-03 | Choosing **18** builds the round from holes 1–9 followed by holes 1–9 again, numbered **10–18**. Holes 10–18 reuse par, yardage, green coordinates and aerial from holes 1–9. |
| NR-HOL-04 | Handicaps come from the official scorecard ([course-maynard-gc.md](course-maynard-gc.md) §3). **18 holes:** holes 1–9 use the front values (2, 10, 12, 6, 4, 18, 14, 8, 16) and holes 10–18 use the back values (1, 11, 13, 5, 3, 17, 7, 9, 15). **9 holes:** the 1–9 rank of the front values (1, 5, 6, 3, 2, 9, 7, 4, 8). |
| NR-HOL-05 | Tee card yardage (NR-TEE-06) and the round's par update live: 9 holes → front-nine totals, 18 → double. |
| NR-HOL-06 | The CTA label includes the tee and the hole count: "Tee off · Blue · 18 holes". |
| NR-HOL-07 | The hole count is stored on `Round.holeCount` and can't be changed after tee off. |

## 4. Tees section
| ID | Requirement |
|----|-------------|
| NR-TEE-01 | `SectionHeader` "Tees". |
| NR-TEE-02 | A 2-column grid (gap 8) of `TeeCard`s, one per tee on the course. |
| NR-TEE-03 | `TeeCard` (a `SelectableCard` button) shows a `TeeDot` + tee name (SF Pro 600 15), total yardage "{6,412} yds" (SF Pro 700 22, grouped thousands, always yards) and "Rating / slope {71.4} / {129}" (Caption 12). |
| NR-TEE-04 | Exactly one tee is selected (single-select). The selected card has a 2 pt Blue 500 inner stroke. All rest on the soft card shadow (DS-SH-04). Accessibility: `isSelected` trait. |
| NR-TEE-05 | The initial selection is the Settings › Default tees value, falling back to the first tee. |
| NR-TEE-06 | Yardage = the sum of hole yardages for that tee across the holes in the round (e.g. Blue 3,013 for 9 / 6,026 for 18). Rating and slope come from the course data, per tee (Blue / White 68.2 / 123, Yellow / Red 71.5 / 124 for 18 holes; 9 holes show half the rating with the same slope). |

## 5. Players section
| ID | Requirement |
|----|-------------|
| NR-PLY-01 | Header "Players" with the caps count "· {selected} OF 4" (the count is SF Pro 600 15, `textSecondary`) with trailing `TintedButton` "＋ Add player". |
| NR-PLY-02 | `CardContainer` listing **all** players as checkbox rows: avatar 40, name, "HCP {index}" caption, trailing 28 pt circular check (filled Blue 500 with a white check when selected, 2 pt Gray 300 ring when not). Accessibility role checkbox / `isSelected`. |
| NR-PLY-03 | Maximum **4** players. Once 4 are selected, unselected rows fade to 50 % opacity and ignore taps. VoiceOver announces "Maximum of 4 players". |
| NR-PLY-04 | Default selection: the players from the most recent round (up to 4). Nothing is preselected on a fresh install. *Inferred.* No player is treated as the device owner. |
| NR-PLY-05 | Order: most recently played first, then alphabetical by first name. |
| NR-PLY-06 | "Add player" presents **Add player** as a sheet. On Create, the new player is added to the list and auto-selected if fewer than 4 are selected. |
| NR-PLY-07 | With no players, an inline card reads "Add a player to start a round." over a full-width "＋ Add a player" button that opens Add player. |

## 6. Tee off button
| ID | Requirement |
|----|-------------|
| NR-CTA-01 | `StickyBottomCTA` with a full-width 56 pt `PrimaryButton` "Tee off · {Tee} · {9 \| 18} holes". The label updates live with the selected tee and the hole count. |
| NR-CTA-02 | Disabled when 0 players are selected (*inferred*). |
| NR-CTA-03 | On tap: create a `Round` (course, date, **holeCount**, tee, weather snapshot, the tee on the `Round`, and a `RoundEntry` per player in selection order), save it, dismiss, and push **Hole play** at hole 1. |
| NR-CTA-04 | Weather: request the current WeatherKit conditions at the course, waiting at most 4 seconds. If that fails or takes longer, save the round without weather (non-blocking). |
| NR-CTA-05 | A save failure shows the alert "The round couldn't be started. Try again." with OK and keeps the screen open. Tee off shows a spinner while it saves and ignores a second tap; the holes, tees and players can't be changed meanwhile, and the round uses what was selected when Tee off was tapped. |

## 7. Data
| ID | Requirement |
|----|-------------|
| NR-DT-01 | `NewRoundViewModel` is injected with `PlayerRepository`, `RoundRepository`, `CourseProvider`, `SettingsStore`, `WeatherProviding` and `HandicapManager` (the rows' "HCP" values, HC-MG-01). It saves nothing until Tee off. |
| NR-DT-02 | The tees come from the course data: each `TeeInfo` has the stored `Tee`, a catalog name key, a color token, the rating and the slope. No data migration is needed (12-data-model §8). |
| NR-DT-03 | The course JSON has per-tee `rating` and `slope` (`MaynardGC.json`). |
| NR-DT-04 | If the players or course can't be read, "The players couldn't be loaded." shows with "Try again"; nothing on screen changes until a read succeeds. |

## 8. Accessibility identifiers
`newRound.cancel`, `newRound.holes` (segments `newRound.holes.0` = 9, `newRound.holes.1` = 18), `newRound.tee.{blue|white|yellow|red}`, `newRound.addPlayer`, `newRound.player.{id}`, `newRound.empty`, `newRound.empty.addPlayer`, `newRound.teeOff`, `newRound.saveError.ok`, `newRound.error`, `newRound.error.retry`.
