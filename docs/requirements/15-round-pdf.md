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
| RP-PG-04 | **Vector output:** text is real, selectable and searchable text, and lines and marks are vector paths. No rasterized table. Text is set in the system font (SF Pro), embedded as a subset by Core Graphics, so the PDF looks the same on any device or computer. |
| RP-PG-05 | No app chrome, avatars, legend, map art, footer or page number. The page holds only the header (§3) and the table (§4). |

## 3. Header
| ID | Requirement |
|----|-------------|
| RP-HD-01 | Left, line 1: an eyebrow label in caps, SF Pro 700 11, tracking 0.04 em, Green 500 (`#248A3D`). 18 holes: "MAYNARD GOLF CLUB · ROUND SCORECARD". 9 holes: "MAYNARD GOLF CLUB · 9-HOLE SCORECARD". |
| RP-HD-02 | Left, line 2: the round date "{Sat, Nov 8, 2026}" (SF Pro 700 24, line height 1, `textPrimary`). The date and year are always shown. |
| RP-HD-03 | Right, line 1 (caps, SF Pro 600 12, tracking −0.015 em, Gray 500, right-aligned): 18 holes "{BLUE} TEES · PAR {70} · {6,026} YDS". 9 holes "FRONT 9 · {BLUE} TEES · PAR {35} · {3,013} YDS". Par and yards come from course data for the round's tee and hole count (course-maynard-gc). |
| RP-HD-04 | Right, line 2: "TEE TIME {8:40 AM} · {4H 12M} · {SUNNY} {62}°". Leave out "· duration" if it's unknown (as RD-HDR-02), and leave out "· weather" if the round has no weather. The duration uses the same formatter as Round detail, in caps. |
| RP-HD-05 | A 2 pt Green 500 rule under the header, 8 pt below the text. |

## 4. Scorecard table
A rounded (radius 6) table with a 1 pt Separator (`#E5E5EA`) border, clipped. Columns are separated by 1 pt Hairline (`#F0F0F3`) lines.

| ID | Requirement |
|----|-------------|
| RP-TB-01 | **Columns, 18 holes:** label column (86 pt), holes 1–9, **OUT**, holes 10–18, **IN**, **TOT**, **+/−**. Hole columns share the remaining width equally; OUT / IN are 36 pt, TOT / +/− 40 pt (design ratios, scaled to the card width). |
| RP-TB-02 | **Columns, 9 holes:** label column (110 pt), holes 1–9, **TOT**, **+/−** (64 pt each). Type is about 15 % larger than in the 18-hole layout (as in the design). |
| RP-TB-03 | **HOLE row:** Gray 100 (`#E8E8ED`) background with a Gray 300 (`#C7C7CC`) bottom border. Caps label "HOLE"; hole numbers SF Pro 700; the total headers OUT / IN / TOT / +/− on an Orange 300 (`#FFCF85`) background. |
| RP-TB-04 | **YARDS row:** the round's tee yardage per hole (SF Pro 600, smaller), OUT / IN / TOT sums with thousands separators ("3,013"); the +/− cell is empty. Holes 10–18 repeat holes 1–9 (course data). |
| RP-TB-05 | **PAR row:** par per hole, OUT / IN / TOT sums; +/− empty. YARDS and PAR rows use Gray 50 (`#F5F5F7`), with Orange 100 (`#FFEBCC`) total cells. |
| RP-TB-06 | **Player rows:** one per player in round order (`cardPosition`), white background, separated by Hairline lines. The label is the player's **first name** only (SF Pro 600 14; 16 in the 9-hole layout), truncated with "…". No avatars or colors. |
| RP-TB-07 | Each hole cell shows the strokes as a **`PrintScoreMark`** (25 pt; 27 pt in the 9-hole layout), the same rules as DS-GF-01: ≤ −2 double circle and −1 single circle in Red 500 (`#E5352B`), par plain, +1 outlined square in Blue 500 (`#0071E3`), ≥ +2 filled Blue 500 square with white numerals. Light-mode colors always (RP-PG-03). The numeral takes the mark's color (Red 500 under par, Blue 500 for a bogey, white on the filled square, `MarkStyle.printForeground`), as the artboards show. |
| RP-TB-08 | A hole with no score shows an **empty cell** (no mark, no dash). OUT / IN / TOT add up only the scored holes, and +/− compares that total against par for the **scored holes**, the same rule as `ScorecardModel` (08-scorecard). |
| RP-TB-09 | **Total cells** (OUT, IN, TOT, +/−) for players: Orange 100 background, SF Pro 700 18 (21 in the 9-hole layout). +/− reads "E" for even, "+3" over, "−2" under (a real minus sign U+2212). |
| RP-TB-10 | **Blank rows:** the table always has **4 player rows**, in both layouts. Rounds with fewer than 4 players add empty rows (blank label, blank cells, totals cells still shaded) so the printed card has room to write in. |
| RP-TB-11 | Row heights from the design (18 / 9 holes): HOLE 28 / 32, YARDS 22 / 26, PAR 24 / 28, player 38 / 34 pt, scaled with the column widths so the block fills the card (RP-PG-02). |

## 5. File and export (on the fly)
| ID | Requirement |
|----|-------------|
| RP-EX-01 | The PDF is generated **when Share is tapped**, from a value snapshot of the round (`RoundPDFModel`, §6), never from live `@Model` objects off the main actor (DM-SC-07). |
| RP-EX-02 | The model is built off the main actor; the page is drawn on the main actor, which `ImageRenderer` requires (tens of milliseconds, RP-TS-07). If making the PDF takes longer than 300 ms, the share button is replaced by a progress indicator (`roundDetail.shareProgress`) until the sheet appears; the button is disabled while a share is under way, and a second tap is ignored (RD-SH-05). Target: under 500 ms on the oldest supported iPhone. |
| RP-EX-03 | The file is written to a fresh folder, `{tmp}/RoundPDF/{UUID}/`, and passed as a file URL to the system share sheet (`UIActivityViewController`, presented by UIKit at the medium detent, RD-SH-01). The folder is deleted when the share ends: an activity finished, the sheet was dismissed, or the sheet is gone (Print closes it before its panel opens, so a cancelled print also ends the share, #228; an activity cancelled back to a sheet still up, like Mail, doesn't), and anything left under `{tmp}/RoundPDF` is removed at the next launch (`AppDependencies.make`). |
| RP-EX-04 | **File name:** "Round · {Course} · {Mon d}.pdf", e.g. "Round · Maynard Golf Club · Nov 8.pdf" (the course is "Maynard Golf Club"). This is also the share sheet and Quick Look title. Characters that aren't allowed in file names ("/", ":") are replaced with "-". If two rounds were played on the same day, the name is the same (each share uses its own temp folder, so names never collide). |
| RP-EX-05 | **PDF metadata:** Title = the file name without ".pdf", Creator = "Maynard Golf {version}", Subject = "Scorecard". No author or device name. |
| RP-EX-06 | The file should be small: under 300 KB for an 18-hole, 4-player round (the design shows 184 KB and 142 KB). |
| RP-EX-07 | If generation fails, show a non-blocking alert, "Couldn't create the PDF. Try again.", with OK. Nothing is shared, and the failure is logged with `os_log` (X-13). |

## 6. Architecture
| ID | Requirement |
|----|-------------|
| RP-AR-01 | **`RoundPDFModel`** (pure value type) built by `RoundPDFModelBuilder.build(round:players:course:locale:calendar:)` from `RoundSnapshot` / `PlayerSnapshot` values plus course data: header strings (final text, in caps where the page prints caps), the title (RP-EX-04), layout (`.eighteen` / `.nine`), columns, rows (HOLE, YARDS, PAR, players, blank padding), cell values (empty, text or a score with its ScoreMark kind) and totals, which come from `ScorecardModel` so the PDF adds up like the on-screen scorecard. It has no UIKit or SwiftUI dependency and is 100 % unit-tested. |
| RP-AR-02 | **`RoundPDFRendering`** protocol: `func render(_ model: RoundPDFModel, metadata: RoundPDFMetadata) async throws -> Data`. The page size is fixed (`RoundPDFPage.size`, 792 × 306 pt, RP-PG-02), so it isn't a parameter. The live `LiveRoundPDFRenderer` draws a SwiftUI `RoundPDFPage` into a PDF `CGContext` with `ImageRenderer.render(rasterizationScale:renderer:)`, which keeps vector output and embeds fonts (RP-PG-04), and writes Title / Creator / Subject into the document info (RP-EX-05). The page sets `.environment(\.colorScheme, .light)` and `.dynamicTypeSize(.large)` itself, so the surrounding environment can't change it. `ImageRenderer` runs on the main actor; drawing the page takes tens of milliseconds (RP-TS-07). |
| RP-AR-03 | **`RoundPDFExporter`**: takes the renderer, file system (`RoundPDFFileSystem`), app version, locale, calendar and a folder-id maker as injected dependencies (live by default; on `AppDependencies.pdf`). `export(round:players:course:) async throws -> URL` builds the model, renders it and writes the temp file (§5); `cleanUp(_:)` removes a share's folder and `removeLeftovers()` the whole `{tmp}/RoundPDF`. The page size is fixed (RP-PG-02), so the locale only formats the strings. Unit tests use a fake renderer and file system. |
| RP-AR-04 | `RoundPDFPage` uses MaynardUI's **`PrintScoreMark`** (the `ScoreMark` shapes and tokens at a fixed size, numerals in the mark's color, DS-GF-01) and color primitives (Green 500, Gray 500, Gray 100 / 300, Orange 100 / 300, Gray 50, Hairline, Separator, Gray 900) at the point sizes in §3–4 (`RoundPDFMetrics`). It doesn't reuse the on-screen `ScorecardTable` view; the layout is different, but both read the same `ScorecardModel` totals logic. |
| RP-AR-05 | All strings in the PDF (eyebrows, "HOLE", "YARDS", "PAR", "OUT", "IN", "TOT", "TEES", "TEE TIME", weather names, the error alert) are in the String Catalog. They're English only (X-01), but no strings are hard-coded. |

## 7. Testing
| ID | Test |
|----|------|
| RP-TS-01 | Unit (`RoundPDFModelBuilder`, 100 %): 18-hole 4-player round → 22 data columns (holes 1–18, OUT, IN, TOT, +/−) and the correct sums; 9-hole 2-player round → 11 data columns plus 2 blank rows; header strings for both layouts; tee yardage and par sums per tee (Blue / White / Yellow / Red); "E" / "+n" / "−n"; unscored holes left empty and excluded from totals; no weather → weather left out; no duration → duration left out; a player with no scores has empty totals and +/−; player labels are the whole first name (the page truncates it, RP-TB-06). |
| RP-TS-02 | Unit: ScoreMark kind for every score-to-par from −3 to +5 (parameterized). |
| RP-TS-03 | Unit (`RoundPDFExporter` with fakes): file name format ("Round · Maynard Golf Club · Nov 8.pdf"), including characters that aren't allowed; the exporter renders the same fixed 792 × 306 pt page for `en_US`, `en_GB` and `fr_FR`; the temp folder is created and then removed by `cleanUp`; launch cleanup removes leftovers; renderer errors surface as the export error. Also: a write failure removes the half-made folder; a failed removal is logged, not thrown. |
| RP-TS-04 | Integration (real renderer, read back with **PDFKit**): exactly 1 page; the media box is 792 × 306 pt (11 × 4.25 in); the extracted text contains the eyebrow, the date, "TEE TIME", each player's first name, every total and "OUT" / "IN" / "TOT" (18) or only "TOT" (9); fonts are embedded; the metadata title matches; under 300 KB. |
| RP-TS-05 | Integration: `RoundPDFPage` wrapped in a **dark** color scheme and **AX5 Dynamic Type** renders the same text, media box and pixels as the page on its own (`LiveRoundPDFRenderer.pdfData(for:metadata:)`); the page ignores both. |
| RP-TS-06 | Reference image: page 1 drawn to a 2× bitmap (PDFKit) for the 18-hole and 9-hole fixture rounds (`RoundPDFModel.preview`) is compared with the reviewed PNGs in `MaynardGolfTests/Fixtures/PDF/`, which are test-target resources read from the bundle (so the test runs on CI). More than 0.5 % of pixels differing (by more than 24 / 255 in a channel) fails the test and attaches the actual image. A missing reference is written to that folder in the source tree and the test fails, so a new or changed reference is always looked at against the artboard before it's checked in. |
| RP-TS-07 | Performance: rendering the 18-hole 4-player page, best of 3 after a warm-up, is under 500 ms on the CI simulator (a `ContinuousClock` check; Swift Testing has no `measure`). |
| RP-TS-08 | UI test: Round detail › Share → the system share sheet appears (`ActivityListView`); no app alert; closing it and tapping Share again opens it again (a fresh file each time), for 9- and 18-hole rounds. With `-uiTestMockPDF fail` the error alert appears and nothing is shared; with `-uiTestMockPDF slow` (1.5 s) the share button shows `roundDetail.shareProgress` until the sheet appears. Unit tests cover the same states in `RoundDetailViewModel` (progress only after the delay, a second tap ignored, cleanup when the sheet closes). |
| RP-TS-09 | Coverage: builder 100 %; exporter and renderer ≥ 90 %. |

## 8. Accessibility identifiers
`roundDetail.share` (button), `roundDetail.shareProgress`, `roundPDF.errorAlert.ok` (the error alert's OK; SwiftUI alerts take no identifier, so UI tests find the alert itself as `app.alerts`).
