# 18 — Handicap (calculator and data manager)

**Scope:** non-UI. How a player's handicap index is worked out, kept up to date and handed to every screen that shows it.
**Used by:** Home players (HOME-PLY-02), New round (NR-PLY-02), Players sheet (HP-PS-03), All players (AL-LS-01), Player card (PC-HDR-05, PC-HX-01, PC-HC-01…06), Handicap screen (19-handicap-screen), Add player (AP-HC-01…04).
**Replaces:** the v1 `Player.handicap` extension in `Handicap.swift`.

## 1. Overview
A player's index is the **manual index** typed in Add player when there is one, otherwise a **calculated index** worked out from their completed rounds using the World Handicap System (WHS). The calculated index is never stored. A `HandicapManager` keeps every player's current index up to date and is the only place screens get it from, so all screens always show the same number.

## 2. Which index is shown
| ID | Requirement |
|----|-------------|
| HC-SRC-01 | **Manual first:** if `Player.handicapIndex` is set (AP-HC-02), that's the player's index everywhere. |
| HC-SRC-02 | **Otherwise calculated** from the player's completed rounds (§3). |
| HC-SRC-03 | Fewer than 3 usable rounds and no manual index → **no index**. Screens show "—". |
| HC-SRC-04 | The result is a `PlayerHandicap` value: `index: Double?`, `source: .manual / .calculated / .none`, and `roundsUsed: Int` (the usable rounds the calculation looked at, at most the newest 20). Screens format it with `displayText()` (the shared `DisplayFormatting.handicapIndex`); they never calculate. |
| HC-SRC-05 | Wherever the index is shown, a calculated value looks the same as a manual one, but its accessibility label adds "calculated" ("Handicap index 8.4, calculated"). The screens build that label from `source`. `PlayerHandicap.accessibilityNote` gives "calculated" (nil otherwise); Home's player cards put it in their label, and Home's player rows and New round's player rows set it as the row's accessibility value ("Mark, HCP 8.4" + "calculated"). All players and the Player card take it when they're built (phase 4). |
| HC-SRC-06 | Plus handicaps are stored negative and shown with a leading "+" ("+2.1"). Values are shown with one decimal. |

## 3. Calculation (WHS)
| ID | Requirement |
|----|-------------|
| HC-CA-01 | Rounds used: the player's **completed** rounds, newest first. Rounds in progress don't count. |
| HC-CA-02 | **Score differential** per round = (113 ÷ slope) × (adjusted gross − course rating), using the rating and slope of the **tee the player played** (course-maynard-gc §2). |
| HC-CA-03 | **Adjusted gross** caps each hole at net double bogey: par + 2 + strokes received on that hole. Strokes received come from the player's index at the time, as a WHS course handicap (index × slope ÷ 113 + (18-hole rating − par 70), rounded), spread over the holes by the hole's handicap for the round's hole count (CRS-HC-01…02): every hole gets the whole part, the hardest holes one more; a plus handicap gives strokes back from the easiest holes. Before the player has any index, each hole is capped at par + 5. |
| HC-CA-04 | **9-hole rounds** count, each one on its own, by filling in the other nine with an **expected score** from the player's index **before that round** (HC-CA-10; the WHS method since 2024). Its 18-hole differential = the **9-hole differential** actually played (HC-CA-09) + the **expected 9-hole differential** for the unplayed nine = 0.52 × index + 1.2. The result is used exactly like an 18-hole round's differential. |
| HC-CA-05 | **Index** = from the most recent 20 differentials, using the WHS table: 3 rounds → lowest 1 − 2.0; 4 → lowest 1 − 1.0; 5 → lowest 1; 6 → average of lowest 2 − 1.0; 7–8 → average of lowest 2; 9–11 → lowest 3; 12–14 → lowest 4; 15–16 → lowest 5; 17–18 → lowest 6; 19 → lowest 7; 20 → lowest 8. |
| HC-CA-06 | Rounded to one decimal, halves away from zero (8.25 → 8.3; a plus −2.05 → −2.1), capped at 54.0. |
| HC-CA-07 | Rounds with a missing hole score don't count (a completed round normally has all of them). |
| HC-CA-08 | `HandicapCalculator(course:)` is a pure, injected type: rounds (`HandicapRound`: date, hole count, tee, the player's strokes, finished or not; `HandicapRound.rounds(for:in:)` builds them from round snapshots) + course data in, `PlayerHandicap` out. No SwiftData, no dates from the system clock. It walks the usable rounds oldest first, so each round uses the index from before it. `calculatedIndex(rounds:upTo:)` gives the calculated index at a date for the history (HC-MG-06). |
| HC-CA-09 | **9-hole differential** = (113 ÷ slope) × (adjusted 9-hole gross − 9-hole course rating). The 9-hole rating is half the tee's 18-hole rating and the slope is the same (NR-TEE-06). The net-double-bogey cap uses the strokes received on those nine holes (half the course handicap, by the 9-hole hole handicaps, CRS-HC-02). |
| HC-CA-10 | **Which index:** the expected score uses the player's index as it stood **before that round**, not today's, so recalculating history never changes old results: the manual index when the player has one (only the current manual value is kept), otherwise the index calculated from their earlier rounds. Every differential, 18-hole or combined, is rounded to one decimal. |
| HC-CA-11 | **No index yet:** a 9-hole round played before the player has any index uses 54.0 as the index for the expected score, the WHS maximum, so their first rounds still count toward getting an index. |
| HC-CA-12 | **Outside scores** (#253, 12-data-model §3.5) count with the Maynard rounds. Each is a `HandicapRound` with `outside` set (no tee, no hole scores): its differential is (113 ÷ slope) × (gross − rating) with the rating and slope copied onto the score (DM-OS-06), and the posted gross as it is (there are no holes to cap). A 9-hole outside score works like a Maynard nine (HC-CA-04, 09…11): half the rating, the same slope, plus the expected nine from the index before it. It counts as played at the start of its day (DM-OS-04), so it comes before a Maynard round the same day. |
| HC-CA-13 | **Breakdown** (`breakdown(rounds:)`, for the Handicap screen): the newest 20 usable rounds and outside scores, newest first, each with its differential, gross, hole count, tee (Maynard only), course name and whether it's one of the lowest the table averages (between equal differentials the newer counts). Also the calculated index, how many count and the adjustment. Always calculated, like `calculatedIndex`: a manual index changes neither. |

## 4. Keeping it up to date (data manager)
| ID | Requirement |
|----|-------------|
| HC-MG-01 | `HandicapManager` (`@Observable`, on `AppDependencies.handicaps`) holds the current `PlayerHandicap` for every player and is the **only** source screens use: `handicap(for:)` gives a player's value, `.none` until it's ready. |
| HC-MG-02 | It recalculates a player when one of their rounds completes, is edited (Hole play edit mode) or is deleted, when their manual index is set or cleared, and when iCloud sync brings in changed rounds (found through persistent history, 12-data-model DM-SC-09). Only the affected players are recalculated. Local saves and iCloud imports both arrive on the change tracker's stream; after each batch that touches players, rounds, cards or outside scores, the manager reads fresh snapshots (`HandicapDataSource`: the background store, through a fresh context per read so a main-context save is never hidden by cached values) and recalculates only the players whose inputs changed: their manual index, their **finished, non-trashed** rounds or their outside scores (HC-CA-12) (so a stroke saved mid-round recalculates nobody). A player who's gone drops out. If two passes overlap, the newer one's result stands. A failed read is logged, `loadFailed` is set (a screen can offer `refresh()` as "Try again") and the current values stay. |
| HC-MG-03 | Screens update through observation: no reload, no notification. |
| HC-MG-04 | Calculation runs off the main actor (`@concurrent`) on value snapshots (DM-SC-07) and finishes in under 50 ms for a player with 200 rounds. Without course data, manual indexes still show and everyone else shows "—". |
| HC-MG-05 | On launch (`start(changes:)`, from the app shell), it calculates every player once, in the background, retrying a failed read after 1, 5 and 30 seconds. Until a player's value is ready, screens show "—" without a spinner. |
| HC-MG-06 | **History:** `series(for:months:)` returns the calculated index at the end of each of the last N months, oldest first (the current month ends now, from the injected clock), using only rounds and outside scores (HC-CA-12) played up to that date; months with fewer than 3 give no point. It feeds the Player card chart (PC-HC-04), which always shows calculated values. |
| HC-MG-07 | Nothing is stored. The manager can always rebuild every value from the rounds. |
| HC-MG-08 | `breakdown(for:)` serves each player's `HandicapBreakdown` (HC-CA-13), built in the same off-main pass as the index and observed the same way; `.empty` until ready, without course data, or for a player who's gone. |

## 5. Testing
| ID | Test |
|----|------|
| HC-TS-01 | Unit (`HandicapCalculator`, 100 % branches): every row of the WHS table (3 … 20 rounds, and more than 20 uses the newest 20); fewer than 3 → no index; rounding; the 54.0 cap. |
| HC-TS-02 | Unit: differentials use the played tee's rating and slope (Blue 68.2 / 123 vs Yellow 71.5 / 124 give different results). |
| HC-TS-03 | Unit: adjusted gross: net double bogey with strokes received, using 9- and 18-hole hole handicaps; par + 5 before any index. |
| HC-TS-04 | Unit: 9-hole rounds: the 9-hole differential uses half the rating and the same slope; the expected nine is 0.52 × index + 1.2 using the index from **before** the round; the sum is used as an 18-hole differential; a player with no index uses 54.0; a 9-hole round mixed with 18-hole rounds in the best-of table. |
| HC-TS-05 | Unit: manual index wins; clearing it falls back to calculated; source and accessibility suffix ("calculated") are correct; plus-handicap formatting. |
| HC-TS-06 | Unit (`HandicapManager`, fakes): recalculates only the affected player on round complete, edit, delete, manual change and sync import; observers see the new value; launch calculation; the 50 ms budget (`measure`). |
| HC-TS-07 | Unit: monthly series: values at each month end use only earlier rounds; months with too few rounds give no point. |
| HC-TS-08 | UI: seed a player with 3+ rounds and no manual index → Home, New round, All players and the Player card all show the same number, and its label contains "calculated". |
| HC-TS-09 | UI: Round detail › Edit → lower a score → Done → the player's index on the Player card changes. Delete a round in All rounds → it changes again. |
| HC-TS-10 | UI: Edit player → enter 5.0 → Save → every screen shows 5.0 without "calculated"; clear it → the calculated value returns. |
| HC-TS-11 | Unit: outside 18- and 9-hole differentials with their own rating and slope, no hole cap, the expected nine from the index before; outside scores mixed with Maynard rounds in date order; `HandicapRound.outside(for:in:)`. |
| HC-TS-12 | Unit: the breakdown's rows, order, counting flags (table rows, ties, fewer than 3, more than 20) and that a manual index doesn't change it. |
| HC-TS-13 | Unit (`HandicapManager`): adding or deleting an outside score recalculates only its player; breakdowns follow players; the background store reads outside scores; the 50 ms budget with 200 rounds and 100 outside scores. |
