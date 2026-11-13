# 10 — Round Detail (+ Share)

**Artboards:** Round detail · Round detail — share sheet
**Entry:** Home › Recent rounds row, Player card › round tile, after Round complete.
**Exit:** "‹ Rounds" (accessibility "Back to previous rounds") → previous screen.

## 1. Overview
A read-only summary of a completed round: header with course / date / weather, a player results strip, the full scorecard and a legend. The share button exports a PDF through the standard iOS share sheet, with an extra **Post score to GHIN** action. It replaces the v1 `RoundDetailView` and its PDF export.

## 2. Top bar
| ID | Requirement |
|----|-------------|
| RD-TOP-01 | Leading `NeutralPillButton` "‹ Rounds" (the label matches the previous screen; *inferred*: "Home" when coming from Home). |
| RD-TOP-02 | Centered caps title "ROUND DETAIL". |
| RD-TOP-03 | Trailing 44 pt share icon button, accessibility "Share round". Opens the share sheet (§6). |

## 3. Round header
| ID | Requirement |
|----|-------------|
| RD-HDR-01 | Course name (e.g. "Home club"), Sofia 700 large. |
| RD-HDR-02 | Meta line "{Sat, Nov 8} · Tee time {8:40 AM} · {4h 12m}". The duration runs from round start to the last score saved. Leave out "· duration" if it's unknown. |
| RD-HDR-03 | Caps line "{BLUE} TEES · PAR {72} · {6,412} YDS". |
| RD-HDR-04 | `WeatherIcon` + temperature ("62°"), accessibility "Sunny, 62 degrees". |

## 4. Player results strip
| ID | Requirement |
|----|-------------|
| RD-PL-01 | One column per player: 40 pt avatar, first name, gross total (Sofia 700) and `ToParText` (under par `underPar`, else Moss 600). |
| RD-PL-02 | A **WIN** `ResultBadge` on the avatar of the lowest gross total. Ties: every tied player gets WIN (*inferred*). |
| RD-PL-03 | A **GHIN** badge with a check (tooltip / accessibility "Posted to GHIN") on players whose score was posted. |
| RD-PL-04 | Tapping a player opens their Player card (*inferred*). |

## 5. Scorecard
| ID | Requirement |
|----|-------------|
| RD-SC-01 | Reuses the `ScorecardTable` portrait component (see 08-scorecard): HOLE / PAR / players, holes 1–9, OUT, 10–18, IN, TOT. Rows are 38 pt with alternating stripes and **no** current-hole highlight. |
| RD-SC-02 | `ScoreMark` styles as in the design system. Legend: Birdie, Bogey, Double+ (Eagle shown only if one exists, *inferred*). |
| RD-SC-03 | *Inferred (computed in the design but not drawn):* a stats block per player with counts of Birdies, Pars, Bogeys, Double+ and "Front / Back" (e.g. 38 / 39). Include it under the table. |

## 6. Share sheet
| ID | Requirement |
|----|-------------|
| RD-SH-01 | The share button presents the **standard iOS share sheet** (`ShareLink` / `UIActivityViewController`). Don't build a custom sheet. |
| RD-SH-02 | The shared item is a PDF named "Round · {Course} · {Mon d}.pdf" (preview header "Round · Home club · Nov 8", "PDF Document · {size}"). |
| RD-SH-03 | The PDF renders the round header, players strip and full scorecard with the design-system styling (`ImageRenderer` → PDF), on US Letter / A4 per locale. |
| RD-SH-04 | A custom `UIActivity` **"Post score to GHIN"** with the subtitle "{Player} · {score} · {Course}, {Tee} tees". It's shown only when the me-player has a linked GHIN and the round isn't posted yet. It posts through `GHINService.postScore` and marks `PersonRound.postedToGHIN = true`. Success / failure is reported with a toast / alert. |
| RD-SH-05 | The standard actions (AirDrop, Messages, Mail, Copy, Save to Files, Print, Markup) come from the system. Nothing to build. |
| RD-SH-06 | PDF generation runs off the main thread with a loading indicator if it takes more than 300 ms. |

## 7. Data
| ID | Requirement |
|----|-------------|
| RD-DT-01 | `RoundDetailViewModel` is injected with `RoundRepository`, `PDFRenderer`, `GHINService`. It exposes `header`, `players: [PlayerResult]`, `scorecard: ScorecardModel`, `stats`, `shareItem`. |
| RD-DT-02 | `PersonRound` gains `postedToGHIN: Bool` (default false) and `Round` gains `startedAt`, `finishedAt` (migration plus tests). |
| RD-DT-03 | Winner, ties, stats and duration formatting have 100 % unit coverage. |

## 8. Accessibility identifiers
`roundDetail.back`, `roundDetail.share`, `roundDetail.player.{id}`, `roundDetail.winBadge.{id}`, `roundDetail.ghinBadge.{id}`, `roundDetail.scorecard`, `roundDetail.stats`.

## Open questions
1. Should the WIN badge use gross or net (handicap-adjusted) scores?
2. Can GHIN posting be done for players other than "me"?
3. Should a round be deletable / editable from here?
