# 18 — Handicap (calculator and data manager)

**Scope:** non-UI. How a player's handicap index is worked out, kept up to date and handed to every screen that shows it.
**Used by:** Home players (HOME-PLY-02), New round (NR-PLY-02), Players sheet (HP-PS-03), All players (AL-LS-01), Player card (PC-HDR-04…05, PC-HC-01…06), Add player (AP-HC-01…04).
**Replaces:** the v1 `Player.handicap` extension in `Handicap.swift`.

## 1. Overview
A player's index is the **manual index** typed in Add player when there is one, otherwise a **calculated index** worked out from their completed rounds using the World Handicap System (WHS). The calculated index is never stored. A `HandicapManager` keeps every player's current index up to date and is the only place screens get it from, so all screens always show the same number.

## 2. Which index is shown
| ID | Requirement |
|----|-------------|
| HC-SRC-01 | **Manual first:** if `Player.handicapIndex` is set (AP-HC-02), that's the player's index everywhere. |
| HC-SRC-02 | **Otherwise calculated** from the player's completed rounds (§3). |
| HC-SRC-03 | Fewer than 3 usable rounds and no manual index → **no index**. Screens show "—". |
| HC-SRC-04 | The result is a `PlayerHandicap` value: `index: Double?`, `source: .manual / .calculated / .none`, and `roundsUsed: Int`. Screens format it; they never calculate. |
| HC-SRC-05 | Wherever the index is shown, a calculated value looks the same as a manual one, but its accessibility label adds "calculated" ("Handicap index 8.4, calculated"). |
| HC-SRC-06 | Plus handicaps are stored negative and shown with a leading "+" ("+2.1"). Values are shown with one decimal. |

## 3. Calculation (WHS)
| ID | Requirement |
|----|-------------|
| HC-CA-01 | Rounds used: the player's **completed** rounds, newest first. Rounds in progress don't count. |
| HC-CA-02 | **Score differential** per round = (113 ÷ slope) × (adjusted gross − course rating), using the rating and slope of the **tee the player played** (course-maynard-gc §2). |
| HC-CA-03 | **Adjusted gross** caps each hole at net double bogey: par + 2 + strokes received on that hole. Strokes received come from the player's index at the time and the hole's handicap for the round's hole count (CRS-HC-01…02). Before the player has any index, each hole is capped at par + 5. |
| HC-CA-04 | **9-hole rounds** count. *Proposed:* two 9-hole rounds, oldest first, are combined into one 18-hole differential (WHS method); an unpaired 9-hole round waits for the next one. See open question 1. |
| HC-CA-05 | **Index** = from the most recent 20 differentials, using the WHS table: 3 rounds → lowest 1 − 2.0; 4 → lowest 1 − 1.0; 5 → lowest 1; 6 → average of lowest 2 − 1.0; 7–8 → average of lowest 2; 9–11 → lowest 3; 12–14 → lowest 4; 15–16 → lowest 5; 17–18 → lowest 6; 19 → lowest 7; 20 → lowest 8. |
| HC-CA-06 | Rounded to one decimal (half up), capped at 54.0. |
| HC-CA-07 | Rounds with a missing hole score don't count (a completed round normally has all of them). |
| HC-CA-08 | `HandicapCalculator` is a pure, injected type: rounds + course data in, `PlayerHandicap` out. No SwiftData, no dates from the system clock. |

## 4. Keeping it up to date (data manager)
| ID | Requirement |
|----|-------------|
| HC-MG-01 | `HandicapManager` (`@Observable`, injected) holds the current `PlayerHandicap` for every player and is the **only** source screens use. |
| HC-MG-02 | It recalculates a player when one of their rounds completes, is edited (Hole play edit mode) or is deleted, when their manual index is set or cleared, and when iCloud sync brings in changed rounds. Only the affected players are recalculated. |
| HC-MG-03 | Screens update through observation: no reload, no notification. |
| HC-MG-04 | Calculation runs off the main actor on value snapshots (DM-SC-07) and finishes in under 50 ms for a player with 200 rounds. |
| HC-MG-05 | On launch, it calculates every player once, in the background. Until a player's value is ready, screens show "—" without a spinner. |
| HC-MG-06 | **History:** `series(for:months:)` returns the calculated index at the end of each of the last N months, using only rounds played up to that date. It feeds the Player card chart (PC-HC-04), which always shows calculated values. |
| HC-MG-07 | Nothing is stored. The manager can always rebuild every value from the rounds. |

## 5. Testing
| ID | Test |
|----|------|
| HC-TS-01 | Unit (`HandicapCalculator`, 100 % branches): every row of the WHS table (3 … 20 rounds, and more than 20 uses the newest 20); fewer than 3 → no index; rounding; the 54.0 cap. |
| HC-TS-02 | Unit: differentials use the played tee's rating and slope (Blue 68.2 / 123 vs Yellow 71.5 / 124 give different results). |
| HC-TS-03 | Unit: adjusted gross: net double bogey with strokes received, using 9- and 18-hole hole handicaps; par + 5 before any index. |
| HC-TS-04 | Unit: 9-hole rounds per the chosen method (HC-CA-04), including an unpaired round. |
| HC-TS-05 | Unit: manual index wins; clearing it falls back to calculated; source and accessibility suffix ("calculated") are correct; plus-handicap formatting. |
| HC-TS-06 | Unit (`HandicapManager`, fakes): recalculates only the affected player on round complete, edit, delete, manual change and sync import; observers see the new value; launch calculation; the 50 ms budget (`measure`). |
| HC-TS-07 | Unit: monthly series: values at each month end use only earlier rounds; months with too few rounds give no point. |
| HC-TS-08 | UI: seed a player with 3+ rounds and no manual index → Home, New round, All players and the Player card all show the same number, and its label contains "calculated". |
| HC-TS-09 | UI: Round detail › Edit → lower a score → Done → the player's index on the Player card changes. Delete a round in All rounds → it changes again. |
| HC-TS-10 | UI: Edit player → enter 5.0 → Save → every screen shows 5.0 without "calculated"; clear it → the calculated value returns. |

## Open questions
1. **9-hole rounds:** combine two 9-hole rounds into one 18-hole differential (official WHS, proposed above), or double a single 9-hole score (what v1 did; simpler, but not official)?
