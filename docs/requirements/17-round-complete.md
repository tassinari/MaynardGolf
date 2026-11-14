# 17 — Round Complete

**Artboard:** none yet. Everything here is *inferred* from the v1 `RoundCompleteView` and the v2 rules (no winner, no "me"). It needs a design.
**Entry:** Hole play, when the last hole has a score for every player (07-hole-play HP-NAV-03).
**Exit:** "View scorecard" → Round detail. "Done" → Home.

## 1. Overview
A short summary shown once, when a round finishes: the date and round facts, each player's final score, and two buttons. It replaces the v1 `RoundCompleteView`.

## 2. Behavior
| ID | Requirement |
|----|-------------|
| RC-BH-01 | Shown as a full-screen cover over Hole play about 600 ms after the final score is saved (the same delay as auto-advance), whether or not auto-advance is on. |
| RC-BH-02 | Before it appears, the round is marked complete and `finishedAt` is set (12-data-model). If the app quits while the screen is showing, the round is already complete: Home shows no in-progress card for it and it's in Recent rounds. |
| RC-BH-03 | It's **not** shown in edit mode (HP-ED-04) and never shown twice for the same round. |
| RC-BH-04 | A `.success` haptic fires when it appears. No sound and no confetti. |
| RC-BH-05 | Swipe-down is disabled; the user leaves with one of the two buttons. |

## 3. Content
| ID | Requirement |
|----|-------------|
| RC-CT-01 | Title "Round complete" (Title 28). Under it: "{Sat, Nov 8} · Maynard Golf Club" and the caps line "{BLUE} TEES · {18} HOLES · {4h 12m}" (the duration is left out if unknown). |
| RC-CT-02 | One row per player in round order: 48 pt `PlayerAvatar`, first name, gross total (Sofia 700 28) and `ToParText`. Under par uses `underPar`. |
| RC-CT-03 | **No winner, ranking, trophy or "won" text.** Players stay in round order. |
| RC-CT-04 | `PrimaryButton` "View scorecard" opens **Round detail** for this round; its back button then returns to Home. |
| RC-CT-05 | `TertiaryButton` "Done" (accessibility "Back to home") dismisses to Home. |
| RC-CT-06 | Light and Dark from the semantic tokens; Dynamic Type to AX3 (the player rows scroll if needed). |

## 4. Data and testing
| ID | Requirement |
|----|-------------|
| RC-DT-01 | `RoundCompleteViewModel` takes the round's value snapshot and builds the header strings and player rows with the shared `RoundSummaryBuilder`. Pure, 100 % unit coverage (1–4 players, 9 / 18 holes, no duration). |
| RC-TS-01 | Unit: completion is detected only when every player has a score on every hole; `isComplete` and `finishedAt` are set once; edit mode never triggers it. |
| RC-TS-02 | UI: score the last hole for every player → Round complete shows each player's total → View scorecard → Round detail → back → Home with no in-progress card. |
| RC-TS-03 | UI: Done → Home; the round is the first row of Recent rounds. No element contains "won". |
| RC-TS-04 | UI: accessibility audit in Light and Dark. |

## 5. Accessibility identifiers
`roundComplete.sheet`, `roundComplete.player.{id}`, `roundComplete.viewScorecard`, `roundComplete.done`.

## Open questions
1. This screen needs an artboard. Until then it's built from MaynardUI components as described here.
