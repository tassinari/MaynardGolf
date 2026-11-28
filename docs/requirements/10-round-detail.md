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
| RD-TOP-01 | Leading `NeutralPillButton` "‹ Home" when Round detail sits right on Home (from Recent rounds or Round complete), "‹ Rounds" when it came from a list (`RoundDetailViewModel.backTitle(path:)`). Accessibility "Back to previous rounds". |
| RD-TOP-02 | Centered title "Round detail" (SF Pro 700 20, `section` tracking −0.015 em). |
| RD-TOP-03 | Trailing `NeutralPillButton` "Edit" (44 pt, `surfaceRaised`). Opens the round in **Hole play** for editing (§6), disabled until the round has loaded (`roundDetail.edit`). |
| RD-TOP-04 | Trailing 44 pt share circle button (`surfaceRaised`, share glyph), after Edit, accessibility "Share round". Opens the share sheet (§7). Disabled until the round has loaded and while a share is under way (`roundDetail.share`). |
| RD-TOP-05 | The bar is translucent `background` @ 78 % + 16 pt blur; content scrolls underneath. |

## 3. Round header card
A white `CardContainer` (radius 22, padding 16, gap 14) holding the round info and the players strip.

| ID | Requirement |
|----|-------------|
| RD-HDR-01 | Course name (SF Pro 600 20, the card-name style): "Maynard Golf Club", from the course data. |
| RD-HDR-02 | Meta line "{Sat, Nov 8} · Tee time {8:40 AM} · {4h 12m}" (SF Pro 13, `textSecondary`). The duration runs from round start to the last score saved. Leave out "· duration" if it's unknown. |
| RD-HDR-03 | Caps line "{BLUE} TEES · PAR {72} · {6,412} YDS" (SF Pro 600 13, tracking 0.04 em, `textSecondary`). Par and yards are for the round's hole count (9 or 18) and tee. |
| RD-HDR-04 | Trailing weather pill: a `surfaceRaised` capsule with the `WeatherIcon` and the temperature ("62°"). Accessibility "Sunny, 62 degrees". Hidden if the round has no weather. |

## 4. Player results strip
| ID | Requirement |
|----|-------------|
| RD-PL-01 | Inside the header card, under a hairline (12 pt top padding): a 4-column grid (gap 6), one column per player in round order. 1–3 players keep the same column width, centered. |
| RD-PL-02 | Each column: 40 pt `PlayerAvatar`, first name (SF Pro 600 13), gross total (SF Pro 700 26) and `ToParText` (SF Pro 600 14; under par `underPar`, else `textSecondary`). |
| RD-PL-03 | There are **no** badges on the avatars (no WIN, no GHIN). |
| RD-PL-04 | Tapping a player opens their Player card (*inferred*). |

## 5. Scorecard
| ID | Requirement |
|----|-------------|
| RD-SC-01 | Reuses the `ScorecardTable` portrait component (08-scorecard) with `compact: true`, in its own card (radius 18, clipped, on the soft card shadow): a 34 pt Gray 100 (`surfaceRaised`) header row with HOLE / PAR (caps) and the players' first names. Its header, hole rows and totals share the live table’s 8 pt horizontal insets, with HOLE / PAR centered over their values. It has the same four fixed player slots as the live portrait table: real players start at the left and unused headers, score cells and totals are blank (#204, SC-PT-01). |
| RD-SC-02 | Hole rows 38 pt with alternating white / Gray 50 (`tableStripe`) and a hairline top border; OUT / IN / TOT rows 40 pt on `surfaceTotals` with an Orange 300 (`totalsBorder`) top border. A 9-hole round shows holes 1–9 and TOT only. **No** current-hole highlight. Five `tableHeaderBorder` vertical lines continue through the header, hole rows and totals: after HOLE, after PAR and between player slots, including unused slots (SC-PT-04, #283). |
| RD-SC-03 | Only real-player cells render `ScoreMark` (28 pt); unused player slots stay blank. Marks: eagle or better = double circle, birdie = circle (Red), par = plain, bogey = outlined square (Lake), double+ = filled square (Lake). |
| RD-SC-04 | Legend under the table, centered (SF Pro 11, `textSecondary`): Birdie, Bogey, Double+. *Inferred:* Eagle is added only if the round has one. |
| RD-SC-05 | There's no per-player stats block (Birdies / Pars / Bogeys / Front-Back). It isn't drawn in the design. |

## 6. Edit (reopen in Hole play)
| ID | Requirement |
|----|-------------|
| RD-ED-01 | "Edit" pushes **Hole play** for this round in **edit mode** (07-hole-play §5), starting at hole 1. Scores are changed there with the normal Players / Enter score panels. |
| RD-ED-02 | The round stays **completed** while it's edited. Changes save immediately, as during play. Returning from Hole play shows Round detail with updated totals, to-par and scorecard (observation). |
| RD-ED-03 | The round's players, tees and hole count can't be changed through Edit, only scores. |

## 7. Share sheet
| ID | Requirement |
|----|-------------|
| RD-SH-01 | The share button presents the **standard iOS share sheet**: `UIActivityViewController` with the PDF's file URL, presented by UIKit at its own medium detent (expandable to large), never wrapped in a SwiftUI `.sheet`: nested in one, going back to Home afterwards left Home's glass buttons undrawn, dimmed the screen and could crash (#228). Don't build a custom sheet. |
| RD-SH-02 | The shared item is a PDF **generated on the fly** when Share is tapped, named "Round · {Course} · {Mon d}.pdf" (preview header "Round · Maynard Golf Club · Nov 8", "PDF Document · {size}"). Naming, temp-file lifecycle and metadata: 15-round-pdf §5. |
| RD-SH-03 | The PDF is a single landscape page the size of a standard golf scorecard (11 × 4.25 in; 18- and 9-hole layouts), specified in **15-round-pdf**. It doesn't include the on-screen header card or the players strip. |
| RD-SH-04 | The standard actions (AirDrop, Messages, Mail, Notes, Copy, Save to Files, Print, Markup) come from the system. Nothing to build. The share sheet gets the PDF through `RoundPDFItem`: the file URL for every activity, but the PDF's bytes for **Print**, which can't print a file URL from the app's container ("Protected files can only be printed separately", #174). |
| RD-SH-05 | PDF generation starts on tap; if it takes more than 300 ms, a progress indicator replaces the share button until the sheet appears (15-round-pdf RP-EX-02). If it fails, the alert "Couldn't create the PDF. Try again." shows and nothing is shared (RP-EX-07). |

## 8. Data
| ID | Requirement |
|----|-------------|
| RD-DT-01 | `RoundDetailViewModel` is injected with `RoundRepository` and `CourseProvider` (the `RoundPDFExporter` joins with Share, #79). `RoundDetailContent.make(round:players:course:)` builds `courseName`, `metaLine`, `teeLine`, `weather`, `players: [PlayerResult]`, `scorecard: ScorecardModel` and the `legend`; the model rebuilds it on every store change, a round that can't be read shows "This round couldn't be loaded." with Try again, and a round moved to Trash or permanently deleted (on another device, or from All rounds) closes the screen. |
| RD-DT-02 | `Round` has `startedAt` and `finishedAt` (12-data-model DM-RD-05, 06). |
| RD-DT-03 | Player results, to-par and duration formatting have 100 % unit coverage. |

## 9. Accessibility identifiers
`roundDetail.back`, `roundDetail.edit`, `roundDetail.share`, `roundDetail.player.{playerId}`, `roundDetail.scorecard`, `roundDetail.error.retry`.
