# 10 — Round Detail (+ Share)

**Artboards:** Round detail · Round detail — share sheet (the PDF itself: Round PDF — landscape, Round PDF — 9 holes, see 15-round-pdf)
**Entry:** Home › Recent rounds row, All rounds › completed round, Player card › round row, after Round complete.
**Exit:** "‹ Rounds" (accessibility "Back to previous rounds") → previous screen.

## 1. Overview
A summary of a completed round: a header card with course / date / tees / weather and a player results strip, the full scorecard and a legend. **Edit** reopens the round in Hole play to change scores. The share button generates a scorecard PDF (15-round-pdf) and opens the standard iOS share sheet. It replaces the v1 `RoundDetailView` and its PDF export.

Rounds are **not** deleted here. Deleting is swipe-to-delete in the All rounds list (01-home HOME-AR-05).

## 2. Top bar
| ID | Requirement |
|----|-------------|
| RD-TOP-01 | Leading `NeutralPillButton` "‹ Rounds" (the label matches the previous screen; *inferred*: "Home" when coming from Home). |
| RD-TOP-02 | Centered caps title "ROUND DETAIL" (Sofia 700 20, tracking 0.06 em). |
| RD-TOP-03 | Trailing `NeutralPillButton` "Edit" (44 pt, Chalk 200). Opens the round in **Hole play** for editing (§6). |
| RD-TOP-04 | Trailing 44 pt share circle button (Chalk 200, share glyph), after Edit, accessibility "Share round". Opens the share sheet (§7). |
| RD-TOP-05 | The bar is translucent Chalk @ 92 % + 16 pt blur; content scrolls underneath. |

## 3. Round header card
A white `CardContainer` (radius 22, padding 16, gap 14) holding the round info and the players strip.

| ID | Requirement |
|----|-------------|
| RD-HDR-01 | Course name (Inter 600 22): "Maynard Golf Club". |
| RD-HDR-02 | Meta line "{Sat, Nov 8} · Tee time {8:40 AM} · {4h 12m}" (Inter 13, Moss 600). The duration runs from round start to the last score saved. Leave out "· duration" if it's unknown. |
| RD-HDR-03 | Caps line "{BLUE} TEES · PAR {72} · {6,412} YDS" (Sofia 600 13, tracking 0.12 em, Moss 600). Par and yards are for the round's hole count (9 or 18) and tee. |
| RD-HDR-04 | Trailing weather pill: Chalk 200 capsule with a 22 pt `WeatherIcon` and the temperature "62°" (Sofia 700 18). Accessibility "Sunny, 62 degrees". Hidden if the round has no weather. |
| RD-HDR-05 | When the round has weather, a caption " Weather" (Inter 11, Moss 600) sits under the header card and links to the legal attribution page (02-settings SET-AB-09). Hidden when the round has no weather. *Inferred; no design.* |

## 4. Player results strip
| ID | Requirement |
|----|-------------|
| RD-PL-01 | Inside the header card, under a hairline (12 pt top padding): a 4-column grid (gap 6), one column per player in round order. 1–3 players keep the same column width, centered. |
| RD-PL-02 | Each column: 40 pt `PlayerAvatar`, first name (Inter 600 13), gross total (Sofia 700 26) and `ToParText` (Sofia 600 14; under par `underPar`, else Moss 600). |
| RD-PL-03 | There are **no** badges on the avatars (no WIN, no GHIN). |
| RD-PL-04 | Tapping a player opens their Player card (*inferred*). |

## 5. Scorecard
| ID | Requirement |
|----|-------------|
| RD-SC-01 | Reuses the `ScorecardTable` portrait component (08-scorecard) in its own white card (radius 18, clipped): a 34 pt header row (Tee Green 50, bottom border Tee Green 200 `#C9D6A8`) with HOLE / PAR (Sofia 600 11 caps) and player first names (Inter 600 12). |
| RD-SC-02 | Hole rows 38 pt with alternating white / Card Stripe and a hairline top border; OUT / IN / TOT rows 40 pt on `surfaceTotals` with a Bunker 300 top border. A 9-hole round shows holes 1–9 and TOT only. **No** current-hole highlight. |
| RD-SC-03 | Score cells use `ScoreMark` (28 pt): eagle or better = double circle, birdie = circle (Flag), par = plain, bogey = outlined square (Lake), double+ = filled square (Lake). |
| RD-SC-04 | Legend under the table, centered (Inter 11, Moss 600): Birdie, Bogey, Double+. *Inferred:* Eagle is added only if the round has one. |
| RD-SC-05 | There's no per-player stats block (Birdies / Pars / Bogeys / Front-Back). It isn't drawn in the design. |

## 6. Edit (reopen in Hole play)
| ID | Requirement |
|----|-------------|
| RD-ED-01 | "Edit" pushes **Hole play** for this round in **edit mode** (07-hole-play §5), starting at hole 1. Scores are changed there with the normal Players / Enter score sheets. |
| RD-ED-02 | The round stays **completed** while it's edited. Changes save immediately, as during play. Returning from Hole play shows Round detail with updated totals, to-par and scorecard (observation). |
| RD-ED-03 | The round's players, tees and hole count can't be changed through Edit, only scores. |

## 7. Share sheet
| ID | Requirement |
|----|-------------|
| RD-SH-01 | The share button presents the **standard iOS share sheet** (`ShareLink` / `UIActivityViewController`). Don't build a custom sheet. |
| RD-SH-02 | The shared item is a PDF **generated on the fly** when Share is tapped, named "Round · {Course} · {Mon d}.pdf" (preview header "Round · Maynard Golf Club · Nov 8", "PDF Document · {size}"). Naming, temp-file lifecycle and metadata: 15-round-pdf §5. |
| RD-SH-03 | The PDF is a single landscape page the size of a standard golf scorecard (11 × 4.25 in; 18- and 9-hole layouts), specified in **15-round-pdf**. It doesn't include the on-screen header card or the players strip. |
| RD-SH-04 | The standard actions (AirDrop, Messages, Mail, Notes, Copy, Save to Files, Print, Markup) come from the system. Nothing to build. |
| RD-SH-05 | PDF generation runs off the main thread with a loading indicator if it takes more than 300 ms. |

## 8. Data
| ID | Requirement |
|----|-------------|
| RD-DT-01 | `RoundDetailViewModel` is injected with `RoundRepository` and `RoundPDFExporter` (15-round-pdf §6). It exposes `header`, `players: [PlayerResult]`, `scorecard: ScorecardModel`, `shareItem`. |
| RD-DT-02 | `Round` gains `startedAt`, `finishedAt` (12-data-model). |
| RD-DT-03 | Player results, to-par and duration formatting have 100 % unit coverage. |

## 9. Accessibility identifiers
`roundDetail.back`, `roundDetail.edit`, `roundDetail.share`, `roundDetail.player.{id}`, `roundDetail.scorecard`.
