# 15 — Round PDF (generated scorecard export)

**Artboards:** Round PDF — landscape (18 holes) · Round PDF — 9 holes · Round detail — share sheet
**Entry:** Round detail › Share (10-round-detail §7). The PDF is the item handed to the iOS share sheet.
**Replaces:** the v1 `RoundDetailView` PDF export.

## 1. Overview
When the user taps Share on Round detail, the app **builds the PDF on the fly** from the round's current data and hands the file to the standard share sheet. From there the system does the rest: AirDrop, Messages, Mail, Notes, Copy, Save to Files, Print, Markup and the Quick Look preview (the artboards show the PDF open in Quick Look with Done / Markup / Share). The app keeps no copy of the PDF: it's never stored in SwiftData, never synced to iCloud and never cached between shares, so it always reflects the latest edits (10-round-detail §6).

The PDF is a **single landscape page** holding a printed scorecard: a header, then a table of HOLE / YARDS / PAR rows and one row per player. There are two layouts: **18 holes** (OUT / IN / TOT / +/− columns) and **9 holes** (TOT / +/−, larger type).

## 2. Page
| ID | Requirement |
|----|-------------|
| RP-PG-01 | One page, **landscape**, always. A round never spills onto a second page (at most 4 players, 18 holes). |
| RP-PG-02 | Page size: a **standard golf scorecard, 11 × 4.25 in (792 × 306 pt)**, landscape, the same in every region. The header and table fill the card inside 18 pt margins. Printing on Letter or A4 uses the system print scaling (fit to page); the app does nothing extra. |
| RP-PG-03 | White page background. The PDF is **always light mode**, whatever the device appearance, and uses a fixed type size (Dynamic Type doesn't change the PDF). |
| RP-PG-04 | **Vector output:** text is real, selectable and searchable text, and lines and marks are vector paths. No rasterized table. The Sofia Sans Condensed and Inter fonts are embedded (subset). |
| RP-PG-05 | No app chrome, avatars, legend, map art, footer or page number. The page holds only the header (§3) and the table (§4). |

## 3. Header
| ID | Requirement |
|----|-------------|
| RP-HD-01 | Left, line 1: an eyebrow label in caps, Sofia Sans Condensed 700 11, tracking 0.16 em, `success` (Rough 600 `#416308`). 18 holes: "MAYNARD GOLF · ROUND SCORECARD". 9 holes: "MAYNARD GOLF · 9-HOLE SCORECARD". |
| RP-HD-02 | Left, line 2: the round date "{Sat, Nov 8, 2026}" (Sofia 700 24, line height 1, `textPrimary`). The date and year are always shown. |
| RP-HD-03 | Right, line 1 (caps, Sofia 600 12, tracking 0.08 em, Moss 600, right-aligned): 18 holes "{BLUE} TEES · PAR {71} · {6,026} YDS". 9 holes "FRONT 9 · {BLUE} TEES · PAR {35} · {3,013} YDS". Par and yards come from course data for the round's tee and hole count (course-maynard-gc). |
| RP-HD-04 | Right, line 2: "TEE TIME {8:40 AM} · {4H 12M} · {SUNNY} {62}°". Leave out "· duration" if it's unknown (as RD-HDR-02), and leave out "· weather" if the round has no weather. The duration uses the same formatter as Round detail, in caps. |
| RP-HD-05 | A 2 pt `success` (Rough 600) rule under the header, 8 pt below the text. |

## 4. Scorecard table
A rounded (radius 6) table with a 1 pt Card Border (`#E4E1D2`), clipped. Columns are separated by 1 pt Hairline (`#EFECE0`) lines.

| ID | Requirement |
|----|-------------|
| RP-TB-01 | **Columns, 18 holes:** label column (86 pt), holes 1–9, **OUT**, holes 10–18, **IN**, **TOT**, **+/−**. Hole columns share the remaining width equally; OUT / IN are 36 pt, TOT / +/− 40 pt (design ratios, scaled to the card width). |
| RP-TB-02 | **Columns, 9 holes:** label column (110 pt), holes 1–9, **TOT**, **+/−** (64 pt each). Type is about 15 % larger than in the 18-hole layout (as in the design). |
| RP-TB-03 | **HOLE row:** Tee Green 50 (`#E6EDD3`) background with a Tee Green 200 (`#C9D6A8`) bottom border. Caps label "HOLE"; hole numbers Sofia 700; the total headers OUT / IN / TOT / +/− on a Bunker 300 (`#E5C48C`) background. |
| RP-TB-04 | **YARDS row:** the round's tee yardage per hole (Sofia 600, smaller), OUT / IN / TOT sums with thousands separators ("3,013"); the +/− cell is empty. Holes 10–18 repeat holes 1–9 (course data). |
| RP-TB-05 | **PAR row:** par per hole, OUT / IN / TOT sums; +/− empty. YARDS and PAR rows use Card Stripe (`#FBFAF5`), with Bunker 100 (`#F4E6C8`) total cells. |
| RP-TB-06 | **Player rows:** one per player in round order (`cardPosition`), white background, separated by Hairline lines. The label is the player's **first name** only (Inter 600 14; 16 in the 9-hole layout), truncated with "…". No avatars or colors. |
| RP-TB-07 | Each hole cell shows the strokes as a **ScoreMark** (25 pt; 27 pt in the 9-hole layout), the same rules as DS-GF-01: ≤ −2 double circle and −1 single circle in Flag 600 (`#C2410C`), par plain, +1 outlined square in Lake 600 (`#1E5AA8`), ≥ +2 filled Lake 600 square with white numerals. Light-mode colors always (RP-PG-03). |
| RP-TB-08 | A hole with no score shows an **empty cell** (no mark, no dash). OUT / IN / TOT add up only the scored holes, and +/− compares that total against par for the **scored holes**, the same rule as `ScorecardModel` (08-scorecard). |
| RP-TB-09 | **Total cells** (OUT, IN, TOT, +/−) for players: Bunker 100 background, Sofia 700 18 (21 in the 9-hole layout). +/− reads "E" for even, "+3" over, "−2" under (a real minus sign U+2212). |
| RP-TB-10 | **Blank rows:** the table always has **4 player rows**, in both layouts. Rounds with fewer than 4 players add empty rows (blank label, blank cells, totals cells still shaded) so the printed card has room to write in. |
| RP-TB-11 | Row heights from the design (18 / 9 holes): HOLE 28 / 32, YARDS 22 / 26, PAR 24 / 28, player 38 / 34 pt, scaled with the column widths so the block fills the card (RP-PG-02). |

## 5. File and export (on the fly)
| ID | Requirement |
|----|-------------|
| RP-EX-01 | The PDF is generated **when Share is tapped**, from a value snapshot of the round (`RoundPDFModel`, §6), never from live `@Model` objects off the main actor (DM-SC-07). |
| RP-EX-02 | Generation runs off the main thread. If it takes longer than 300 ms, the share button shows a progress indicator and is disabled until the sheet appears (RD-SH-05). Target: under 500 ms on the oldest supported iPhone. |
| RP-EX-03 | The file is written to a fresh folder in the app's temporary directory and passed to the share sheet as a file URL (`UIActivityViewController`, or `ShareLink` with a `Transferable` `FileRepresentation`). The folder is deleted when the share sheet closes, and any leftovers are removed on the next app launch. |
| RP-EX-04 | **File name:** "Round · {Course} · {Mon d}.pdf", e.g. "Round · Maynard Golf Club · Nov 8.pdf" (the course is "Maynard Golf Club"). This is also the share sheet and Quick Look title. Characters that aren't allowed in file names ("/", ":") are replaced with "-". If two rounds were played on the same day, the name is the same (each share uses its own temp folder, so names never collide). |
| RP-EX-05 | **PDF metadata:** Title = the file name without ".pdf", Creator = "Maynard Golf {version}", Subject = "Scorecard". No author or device name. |
| RP-EX-06 | The file should be small: under 300 KB for an 18-hole, 4-player round (the design shows 184 KB and 142 KB). |
| RP-EX-07 | If generation fails, show a non-blocking alert, "Couldn't create the PDF. Try again.", with OK. Nothing is shared, and the failure is logged with `os_log` (X-13). |

## 6. Architecture
| ID | Requirement |
|----|-------------|
| RP-AR-01 | **`RoundPDFModel`** (pure value type) built by `RoundPDFModelBuilder` from a `Round` snapshot plus course data: header strings, layout (`.eighteen` / `.nine`), columns, rows (HOLE, YARDS, PAR, players, blank padding), cell values, ScoreMark kinds and totals. It has no UIKit or SwiftUI dependency and is 100 % unit-tested. |
| RP-AR-02 | **`RoundPDFRenderer`** protocol: `func render(_ model: RoundPDFModel, pageSize: PDFPageSize) throws -> Data`. The live implementation draws a SwiftUI `RoundPDFPage` view into a PDF `CGContext` with `ImageRenderer.render(rasterizationScale:renderer:)`, which keeps vector output (RP-PG-04), with `.environment(\.colorScheme, .light)` and a fixed `dynamicTypeSize`. |
| RP-AR-03 | **`RoundPDFExporter`**: takes the builder, renderer, locale (for page size), file system and clock as injected dependencies. `export(round:) async throws -> URL` writes the temp file (§5) and `cleanUp(_:)` removes it. A fake renderer and file system are used in unit tests. |
| RP-AR-04 | `RoundPDFPage` reuses MaynardUI's `ScoreMark` and color tokens, with a **print style** (fixed light palette, point sizes from §3–4). It doesn't reuse the on-screen `ScorecardTable` view. The layout is different, but both read the same `ScorecardModel` totals logic. |
| RP-AR-05 | All strings in the PDF (eyebrows, "HOLE", "YARDS", "PAR", "OUT", "IN", "TOT", "TEES", "TEE TIME", weather names, the error alert) are in the String Catalog. They're English only (X-01), but no strings are hard-coded. |

## 7. Testing
| ID | Test |
|----|------|
| RP-TS-01 | Unit (`RoundPDFModelBuilder`, 100 %): 18-hole 4-player round → 21 data columns and the correct OUT / IN / TOT / +/−; 9-hole 2-player round → 11 data columns plus 2 blank rows; header strings for both layouts; tee yardage and par sums per tee (Blue / White / Yellow / Red); "E" / "+n" / "−n"; unscored holes left empty and excluded from totals; no weather → weather left out; no duration → duration left out; long names truncated in the model hint. |
| RP-TS-02 | Unit: ScoreMark kind for every score-to-par from −3 to +5 (parameterized). |
| RP-TS-03 | Unit (`RoundPDFExporter` with fakes): file name format ("Round · Maynard Golf Club · Nov 8.pdf"), including characters that aren't allowed; the page is 792 × 306 pt for `en_US`, `en_GB` and `fr_FR` alike; the temp folder is created and then removed by `cleanUp`; launch cleanup removes leftovers; renderer errors surface as the export error. |
| RP-TS-04 | Integration (real renderer, read back with **PDFKit**): exactly 1 page; the media box is 792 × 306 pt (11 × 4.25 in); the extracted text contains the eyebrow, the date, "TEE TIME", each player's first name, every total and "OUT" / "IN" / "TOT" (18) or only "TOT" (9); fonts are embedded; the metadata title matches; under 300 KB. |
| RP-TS-05 | Integration: generating the PDF with the device in **dark mode** and at **AX5 Dynamic Type** gives the same text and media box as light mode at the default size (the PDF ignores both). |
| RP-TS-06 | Reference image: page 1 rendered to a bitmap (PDFKit) for the 18-hole and 9-hole fixture rounds is compared with checked-in reference PNGs at a small tolerance. A diff fails the test and writes the diff image as an attachment. |
| RP-TS-07 | Performance: `measure` export of the 18-hole 4-player fixture; the baseline is under 500 ms on the CI simulator. |
| RP-TS-08 | UI test: Round detail › Share → the system share sheet appears (`ActivityListView`); no app alert. Then fault injection (launch argument `-pdfFailure`) → the error alert appears. |
| RP-TS-09 | Coverage: builder 100 %; exporter and renderer ≥ 90 %. |

## 8. Accessibility identifiers
`roundDetail.share` (button), `roundDetail.shareProgress`, `roundPDF.errorAlert`.
