# 17 — Round Complete

**Artboard:** Round complete.
**Entry:** Hole play, when the last hole has a score for every player (07-hole-play HP-NAV-03).
**Exit:** "View scorecard" → Round detail. "Done" → Home.

## 1. Overview
A short summary shown once, when a round finishes: the date and round facts, each player's final score, and two buttons. It replaces the v1 `RoundCompleteView`.

## 2. Behavior
| ID | Requirement |
|----|-------------|
| RC-BH-01 | Shown as a full-screen cover (`SheetRoute.roundComplete`) over Hole play about 600 ms after the final score is saved, so the last score is seen (auto-advance between holes has no pause, #171), whether or not auto-advance is on. Hole play presents it when a save's outcome is `.finished`. |
| RC-BH-02 | Before it appears, the round is marked complete and `finishedAt` is set (12-data-model). If the app quits while the screen is showing, the round is already complete: Home shows no in-progress card for it and it's in Recent rounds. |
| RC-BH-03 | It's never shown twice for the same round: Hole play presents it only for the save that completes the round (`.finished`), and a later edit of a complete round can't produce that. Edit mode (HP-ED-04, #87) doesn't exist yet; when it does, it mustn't present it. |
| RC-BH-04 | A `.success` haptic fires when it appears. No sound and no confetti. |
| RC-BH-05 | Swipe-down is disabled; the user leaves with one of the two buttons. |

## 3. Content
| ID | Requirement |
|----|-------------|
| RC-CT-01 | Centered header, 72 pt below the top safe area: a 64 pt Tee Green 50 circle with a Rough 600 check mark (decorative); the title "Round complete" (Title, SF Pro 700 28); "{Sat, Nov 8} · Maynard Golf Club" (Body, `textSecondary`); and the caps line "{BLUE} TEES · {18} HOLES · {4H 12M}" (Label, `textSecondary`; the duration, from tee off to the last score, is left out if unknown). |
| RC-CT-02 | A white `CardContainer` (radius 22) with one 72 pt row per player in round order, separated by hairlines: 48 pt `PlayerAvatar`, first name (SF Pro 600 17), then `ToParText` (SF Pro 600 18; under par `underPar`, otherwise Moss 600) and the gross total (SF Pro 700 30) right-aligned. |
| RC-CT-03 | **No winner, ranking, trophy or "won" text.** Players stay in round order. |
| RC-CT-04 | At the bottom: a 56 pt `PrimaryButton` "View scorecard" that opens **Round detail** for this round; its back button then returns to Home. |
| RC-CT-05 | Under it, a 50 pt `TertiaryButton` "Done" (Bunker 100; accessibility "Back to home") that dismisses to Home. |
| RC-CT-06 | Light and Dark from the semantic tokens; Dynamic Type to AX3 (the player rows scroll if needed). |

## 4. Data and testing
| ID | Requirement |
|----|-------------|
| RC-DT-01 | `RoundCompleteContent.make(round:players:course:)` builds the header strings and player rows from value snapshots with the shared `RoundSummaryBuilder`: pure, 100 % unit coverage (1–4 players, 9 / 18 holes, no duration). `RoundCompleteViewModel` reads the round by id, builds the content and plays the haptic once; if the round can't be read it shows "The round's scores couldn't be shown, but they're saved." with Try again, and both buttons still work. |
| RC-TS-01 | Unit: completion is detected only when every player has a score on every hole; `finishedAt` is set once (so `isComplete` turns true); edit mode never triggers it. |
| RC-TS-02 | UI: score the last hole for every player → Round complete shows each player's total → View scorecard → Round detail → back → Home with no in-progress card. |
| RC-TS-03 | UI: Done → Home; the round is the first row of Recent rounds. No element contains "won". |

## 5. Accessibility identifiers
`roundComplete.sheet`, `roundComplete.player.{playerId}`, `roundComplete.viewScorecard`, `roundComplete.done`, `roundComplete.error`, `roundComplete.error.retry`.
