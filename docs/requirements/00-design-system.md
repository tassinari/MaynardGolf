# 00 — Design System & UI Library ("Fairway C")

**Artboards:** Fairway C — Color · Fairway C — Typography, spacing, elevation · Fairway C — Components (page "Design system C"), applied on every screen of page "iPhone C". *Fairway C replaced the earlier "Fairway Overlay" system (page "Design system"); the screens keep their layouts and change only color, type, elevation and radii. Where a rule below differs from the iPhone (Fairway Overlay) artboards, the iPhone C artboard wins.*
**Platform:** iOS 26 and later only. Light and Dark appearance are both required.
**Deliverable:** a `MaynardUI` **framework target** in the app project (`MaynardUI/`, tests in `MaynardUITests/`) that every v2 screen builds on, plus a SwiftUI catalog screen in DEBUG builds (`ComponentCatalogView`, opened with `-uiTestCatalog`). *Why a framework, not a Swift package: Xcode doesn't report code coverage for a local package's sources, and the coverage gate needs it (TS-UT-02).* Colors are `DSColorToken` cases backed by `MaynardUI/Resources/Colors.xcassets`; Xcode's generated asset symbols are off for the framework because they clash with the token names.

## 1. Purpose

"A clean white canvas with one confident blue. Everything else is quiet gray, so a single tap target always reads first." Fairway C draws the app the way Apple draws its own: San Francisco type, grouped white cards on a light grey page, pill buttons and frosted bars. Score colors carry meaning: green under par, blue at par, orange for a bogey and red for double bogey or worse. Over the aerial photos, labels sit on glass or a scrim in white, so they stand apart from turf. The library makes those decisions reusable and testable.

## 2. Brand assets

| ID | Requirement |
|----|-------------|
| DS-BR-01 | The app icon is the orange **M** on golf-ball dimples. It's shown at 120/60/40 pt with the iOS continuous corner radius (27/13.5/9) and a soft shadow. |
| DS-BR-02 | The catalog's header label reads "FAIRWAY · DESIGN SYSTEM C" and its title reads "Fairway C" (catalog screen only). |
| DS-BR-03 | The native launch screen uses the approved white golf-ball artwork with the centered orange-and-black M, matte dimple shading and crisp edges. `LaunchScreen.storyboard` displays `LaunchArtwork` edge-to-edge with aspect-fill and a centered crop on different iPhone sizes; the same approved artwork is used in both appearances. It appears only while iOS launches the app, with no artificial splash delay. The app icon ships in Light, Dark and Tinted variants (iOS 26 icon format). |

## 3. Color tokens

All colors **must** be exposed as `Color` tokens backed by Asset Catalog color sets. Screens must not use hex literals.

There are two layers:
- **The palette** (§3.1–3.3): the Fairway C ramps, one value in both appearances (`DSPaletteColor`, `Color.palette.blue500`). It is **internal** to MaynardUI: only the tokens are drawn from it, and only the catalog and tests read it.
- **Semantic tokens** (§3.7): roles, named for what a color is *for* (`Color.ds.surfaceCard`, `Color.ds.onImagery`, `Color.ds.markerAccent`), never what it looks like. Each has a **Light** and a **Dark** value in its color set and switches automatically with the system appearance. Roles that must not change between appearances (text on photos and glass, tees, player colors) simply carry the same value twice.

| ID | Requirement |
|----|-------------|
| DS-CL-04 | Screens and MaynardUI components use **only** semantic tokens (`Color.ds.<role>`), never the palette, a system color or a literal. A new look is a change to color sets in `Colors.xcassets`, not to code; a color with a new purpose gets a new role in `ColorTokens.swift`. The compiler enforces it for the app (the palette is internal) and `scripts/hex_lint.py` for MaynardUI (`Color.palette` / `DSPaletteColor` are allowed only in `MaynardUI/Tokens/` and `MaynardUI/Catalog/`). *Why: the switch to Fairway C touched ~100 call sites that had used palette colors directly.* |

### 3.1 Base colors

| Token | Hex | Usage |
|-------|-----|-------|
| Blue 500 | `#0071E3` | **Primary**: actions, links, par |
| Green 500 | `#248A3D` | Birdie, success |
| Orange 500 | `#FF9F0A` | Bogey, caution; the pin and markers on the map, IN PROGRESS |
| Red 500 | `#E5352B` | Double bogey, delete |
| Teal 500 | `#30B0C7` | Info, counting rounds |

### 3.2 Ramps

| Ramp | 50 | 100 | 200 | 300 | 400 | 500 | 600 | 700 | 900 |
|------|----|-----|-----|-----|-----|-----|-----|-----|-----|
| Blue | `#F0F7FF` | `#E1EFFE` | `#B8D8FA` | `#8DBFF5` | | `#0071E3` base | `#0058B9` pressed | | `#06305E` |
| Gray | `#F5F5F7` | `#E8E8ED` | | `#C7C7CC` | `#AEAEB2` | `#6E6E73` | | `#424245` | `#1D1D1F` ink |
| Green | `#EFFAF2` | `#D7F3DF` | | `#8EDBA5` | `#34C759` | `#248A3D` base | | `#176B2C` | `#0B3D19` |
| Orange | `#FFF7EA` | `#FFEBCC` | | `#FFCF85` | | `#FF9F0A` base | | `#9A5A00` text | `#4D2D00` |
| Red | `#FFF1F0` | `#FFDEDC` | | `#FFA7A1` | | `#E5352B` base | | `#B3231B` | `#5C100B` |

Palette colors are named by ramp and step (`DSPaletteColor.blue50` … `.blue900`, `.gray50` … `.gray900`), plus the dark grays `dark1` … `dark7` (§3.6). Only MaynardUI's tokens, catalog and tests use these names (DS-CL-04).

### 3.3 Support tokens

| Token | Hex | Usage |
|-------|-----|-------|
| Separator | `#E5E5EA` | Hairline outlines (the PDF's PAR row, swatch outlines) |
| Hairline | `#F0F0F3` | Row dividers inside cards |
| Field Fill | `#EEEEF1` | Search field and segmented-control track |
| Yellow 400 | `#F2C94C` | The yellow tee's dot (`teeYellow`) |
| Caution 400 | `#FFD60A` | The warning badge on `GlassIconButton` (Hole play's Out of order button, HP-OO-03) |
| White / Black | `#FFFFFF` / `#000000` | Drawn into roles such as `onImagery`, `onAccent` and `compactTitle` |

### 3.4 Readable pairings (must be honored)

Every text-on-surface pair the app draws, as semantic tokens, measured from the token values (WCAG 2) in each appearance; translucent fills are composited over the card. *The board's own figures run 0.2–1.3 higher (it lists White on Blue 500 at 4.9); these are the computed ratios.* Pairs under 4.5 : 1 carry only bold or 17 pt+ text (AA large).

| Text on surface | Light | Dark |
|-----------------|-------|------|
| `textPrimary` on `background` | 15.4 | 19.2 |
| `textPrimary` on `surfaceCard` | 16.8 | 15.6 |
| `textSecondary` on `surfaceCard` | 5.0 | 5.9 |
| `link` / `emphasis` on `surfaceCard` | 4.6 | 6.8 |
| `underPar` on `surfaceCard` | 6.6 | 10.3 |
| `scoreUnder` on `surfaceCard` | 4.3 | 6.0 |
| `tintedText` on `tintedFill` | 5.8 | 7.5 |
| `textOnTotals` on `surfaceTotals` | 14.4 | 11.4 |
| `onAccent` on `primaryAction` / `scoreNameOver` | 4.6 | 4.6 |
| `onAccent` on `hazardFill` | 4.3 | 4.3 |
| `onAccent` on `scoreNameUnder` | 6.6 | 6.6 |
| `onScoreNamePar` on `scoreNamePar` | 16.8 | 16.8 |
| `onStatus` on `statusFill` | 8.1 | 8.1 |
| `onWarningBadge` on `warningBadge` | 11.9 | 11.9 |
| `onHazardChip` on `hazardChipFill` | 11.6 | 11.6 |
| `onImagery` / `onImagerySecondary` / `onImageryUnderPar` on `imageryBackdrop` | 16.8 / 11.4 / 7.5 | the same |
| `playerOnDark` on Lake / Flag / Fairway / Moss (initials ≥ 14 pt bold, large text) | 4.6 / 4.3 / 4.3 / 5.0 | the same |
| `playerOnLight` on Sand | 11.6 | 11.6 |
| `compactTitle` on `background` | 19.2 | 19.2 |

| ID | Requirement |
|----|-------------|
| DS-CL-01 | **Never** put text directly on turf imagery; mowing stripes make its contrast unpredictable. Always place a Scrim, Glass or an Ink chip under copy. Text on glass and photos is white, secondary labels Blue 200, under-par numbers Green 400. |
| DS-CL-02 | A unit test **must** assert the WCAG contrast ratio of each pairing above, in both appearances (calculated from the token values), is ≥ the documented value − 0.1. |

### 3.5 Player colors

The player color palette **must** map to tokens with a matching foreground. The stored names (`PlayerColor` raw values) stay as they were, so no data changes:

| Name | Background | Initial / foreground |
|------|-----------|-----------|
| Lake | Blue 500 `#0071E3` | White |
| Sand | Orange 300 `#FFCF85` | Ink |
| Flag | Red 500 `#E5352B` | White |
| Fairway | Green 500 `#248A3D` | White |
| Moss | Gray 500 `#6E6E73` | White |

Player colors are flat and keep their value in Dark mode, on every surface.

DS-CL-03: The old `ColorValues` (red, blue, green, yellow, orange) are replaced by the player palette (`PlayerPalette`, matching the stored `PlayerColor` raw values). There's no data to convert (12-data-model §8), so there's no mapping from the old values.

### 3.6 Dark mode palette (from "Design system C Dark" and "iPhone C Dark")

A true-black page with Apple's dark grays stepping up for surfaces. Fills keep their light color (a Blue 500 button stays Blue 500); color used **as text or a line** steps up to a brighter shade so it reads on black.

| Value | Hex | Usage |
|-------|-----|-------|
| Page | `#000000` | Background, table stripes, `PlayerScoreChip` capsules, the swatch ring |
| Dark 1 (Card) | `#1C1C1E` | Cards, grouped lists, fields; a 1 pt white @ 6 % outline instead of a shadow |
| Dark 2 (Raised) | `#2C2C2E` | Neutral pills, segmented track, tiles, table headers, avatar placeholder |
| Dark 3 / Dark 4 | `#38383A` / `#3A3A3C` | Dividers and card borders / toggle off track |
| Dark 5 | `#48484A` | Scorecard header border, empty check ring |
| Dark 6 | `#636366` | Selected segment, tertiary text, chevrons, empty score "·" |
| Dark 7 | `#98989D` | Secondary text, captions, placeholders |
| Dark 8 | `#D1D1D6` | Chart legend text |
| Blue 400 | `#5AA9F5` | Links, blue text and chart lines (`link`, `emphasis`), bogey outline, Double+ fill (both appearances), Scores by Hole par bars |
| Dark blue tint / wash | `#0B2A4A` / `#0B2038` | Tinted buttons and the current hole / rows that count toward the index |
| Blue 300 | `#8DBFF5` | Tinted button text |
| Green 300 | `#8EDBA5` | Under-par numbers |
| Red 400 | `#FF6961` | Birdie and eagle circles |
| Orange 900 | `#4D2D00` | OUT / IN / TOT rows (text `textPrimary`) |

*Not taken from the dark boards, because they look like leftovers of converting the light boards: player avatars with dark initials (`#1C1C1E`, `#3A3A3C`) on bright colors, the Add player swatches in brighter player colors while avatars elsewhere keep theirs, a black white-tee dot on New round, the portrait Scorecard and Local rules boards still drawn light, and unchanged glass and photos on the hole screens. The app keeps the player and tee colors in both appearances, draws every scorecard in the dark palette, and keeps Dark's photo dimming and deeper glass (DS-MT-05).*

### 3.7 Semantic tokens (light → dark)

Every component **must** use these tokens.

| Semantic token | Light | Dark |
|----------------|-------|------|
| `background` | Gray 50 `#F5F5F7` | `#000000` |
| `surfaceCard` | White | `#1C1C1E` |
| `surfaceRaised` | Gray 100 `#E8E8ED` | `#2C2C2E` |
| `textPrimary` | Ink (Gray 900) `#1D1D1F` | `#F5F5F7` |
| `textSecondary` | Gray 500 `#6E6E73` | `#98989D` |
| `textTertiary` | Gray 400 `#AEAEB2` | `#636366` |
| `primaryAction` | Blue 500 `#0071E3` | `#0071E3` |
| `underPar` | Green 700 `#176B2C` | `#8EDBA5` |
| `surfaceTotals` | Orange 100 `#FFEBCC` | `#4D2D00` |
| `totalsBorder` | Orange 300 `#FFCF85` | `#9A5A00` |
| `textOnTotals` | Ink | `#F5F5F7` |
| `link` | Blue 500 | `#5AA9F5` |
| `tintedFill` | Blue 100 `#E1EFFE` | `#0B2A4A` |
| `tintedText` | Blue 600 `#0058B9` | `#8DBFF5` |
| `divider` | Hairline `#F0F0F3` | `#38383A` |
| `cardBorder` | Separator `#E5E5EA` | `#38383A` |
| `cardOutline` (DS-SH-04) | clear | `#FFFFFF` @ 6 % |
| `barTint` (DS-NV-01) | `#F5F5F7` @ 78 % | `#000000` @ 72 % |
| `emphasis` (blue text, values, chart lines, selection outlines) | `#0071E3` | `#5AA9F5` |
| `cardShadow` (DS-SH-04) | Black @ 4 % | clear |
| `tableStripe` | Gray 50 | `#000000` |
| `tableHeaderBorder` (a scorecard header's bottom border, dashed empty boxes and the portrait column lines, SC-PT-04) | Gray 300 `#C7C7CC` | `#48484A` |
| `currentHoleHighlight` | Blue 100 | `#0B2A4A` |
| `countingHighlight` (HS-RD-03) | Blue 50 `#F0F7FF` | `#0B2038` |
| `hazardFill` | Red 500 | `#E5352B` |
| `success` | Green 500 | `#34C759` |
| `toggleOn` | Green 400 `#34C759` | `#34C759` |
| `toggleOff` | Separator `#E5E5EA` | `#3A3A3C` |
| `segmentTrack` / `segmentSelected` | Field Fill `#EEEEF1` / White | `#2C2C2E` / `#636366` |
| `scoreUnder` (birdie/eagle marks) | Red 500 | Red 400 `#FF6961` |
| `scoreBogeyOutline` | Blue 500 | `#5AA9F5` |
| `scoreDoubleFill` | Blue 400 `#5AA9F5` | `#5AA9F5` |
| `scoreEmpty` | Gray 300 | `#636366` |
| `avatarPlaceholder` | Gray 100 | `#2C2C2E` |
| `onGlassFill` (icon buttons on glass, DS-BT-09) | White @ 18 % | `#FFFFFF` @ 18 % |
| `scrimStroke` (Scrim button stroke, DS-BT-02) | White @ 28 % | `#FFFFFF` @ 28 % |
| `chipFill` (`PlayerScoreChip`, DS-CH-08) | Gray 50 | `#000000` |
| `chipHighlight` (the lowest gross, DS-CH-08) | Blue 100 `#E1EFFE` | `#0B2A4A` |
| `photoDimming` (multiplied into aerial photos, DS-MT-05) | White | `#B8B8B8` |
| `glassTint` / `glassTintStrong` (DS-MT-06) | Ink @ 40 % / 48 % | Black @ 62 % / 74 % |
| `scrim` / `scrimOpaque` (DS-MT-02, 04) | Ink @ 82 % / Ink | the same |
| `compactTitle` (HOME-HDR-05) | Black | `#F5F5F7` |
| `onAccent` (text on filled accents) | White | `#FFFFFF` |
| `controlShadow` (selected segment) | Black @ 14 % | `#000000` @ 14 % |
| `swatchRing` (selected swatch gap) | White | `#000000` |
| `statusFill` / `onStatus` (DS-CH-04) | Orange 500 / Ink | the same |
| `hazardChipFill` / `onHazardChip` (DS-CH-02) | Orange 300 / Ink | the same |
| `warningBadge` / `onWarningBadge` (DS-BT-07) | Caution 400 / Ink | the same |
| `scoreNameUnder` / `scoreNamePar` / `onScoreNamePar` / `scoreNameOver` (DS-GF-04) | Red 700 / White / Ink / Blue 500 | the same (on glass) |
| `scoreBinUnder` / `scoreBinPar` / `scoreBinBogey` / `scoreBinDouble` (PC-SH-04) | Green 400 / Blue 500 / Orange 500 / Red 500 | Green 400 / Blue 400 `#5AA9F5` / Orange 500 / Red 500 |
| `chartLegend` (PC-SH-05) | Gray 700 `#424245` | `#D1D1D6` |
| `bestScoreMarker` (PC-LS-05) | Orange 500 | `#FF9F0A` |
| `teeBlue` / `teeWhite` / `teeYellow` / `teeRed` / `teeWhiteRing` (DS-GF-06) | Blue 500 / White / Yellow `#F2C94C` / Red 500 / Gray 300 | the same |
| `placeholderTurf` / `placeholderTurfStripe` / `placeholderSand` (mock photos and previews only) | `#507A07` / `#416308` / Orange 300 | the same |

**Imagery roles** (over photos and glass; the same in both appearances, DS-DM-05):

| Semantic token | Value | Usage |
|----------------|-------|-------|
| `onImagery` | White | Text, icons, rings and the shot line |
| `onImagerySecondary` | Blue 200 `#B8D8FA` | HCP, PAR, TO PIN labels |
| `onImageryTertiary` | Gray 400 | Units on scrims ("YDS") |
| `onImageryUnderPar` | Green 400 | Under-par numbers |
| `onImageryAccent` | Blue 300 (used at 16–50 %) | `HoleScoreChip` fill and borders |
| `onImageryInverse` | Ink | Text on a white fill over imagery |
| `imageryBackdrop` | Ink | Behind photos while they load, dark chips over imagery |
| `imageryShadow` | Black (used at 35–55 %) | Text shadows, dimming, marker outlines |
| `markerAccent` | Orange 500 | Pin, target center, pin chip flag |
| `locationDot` | Blue 500 | The player's position (DS-OV-12) |

### 3.8 Dark readable pairings

The dark column of §3.4.

| ID | Requirement |
|----|-------------|
| DS-DM-01 | The app **must** support Light and Dark appearance and follow the system setting. There is **no** in-app appearance override. |
| DS-DM-02 | Every semantic token in §3.7 **must** have both a Light and a Dark value in its Asset Catalog color set. |
| DS-DM-03 | A unit test **must** resolve every semantic token in both `UITraitCollection(userInterfaceStyle:)` styles and assert the documented hex values. |
| DS-DM-04 | A unit test **must** assert every pairing in §3.4 meets its documented dark ratio, within 0.1. |
| DS-DM-05 | Photo screens with liquid glass (Hole play, Players sheet, Enter score sheet, Home hero) keep the same layout and text colors in both modes. In Dark mode the aerial photo **is dimmed** and the glass tint deepens (DS-MT-05). |
| DS-DM-06 | Images and icons that carry color (weather icons, app icon) **must** be checked on both backgrounds. Weather icons use semantic strokes. |

Home’s compact navigation title uses `compactTitle`: black over the light material, white over the dark one (HOME-HDR-05).

## 4. Typography

The app uses Apple's system font, **SF Pro**, throughout: **SF Pro Display** for numbers and headings (20 pt and up), **SF Pro Text** for words and small caps labels (Fairway C — Typography: "Big, calm headlines; tight tracking up top, open and easy below"). In SwiftUI both come from `Font.system`, which picks the Display or Text optical size from the point size, so code never names a font file. Sizes and weights below are unchanged from the earlier SF Pro / Inter design; in the screen requirements, "SF Pro 700 22" means the system font, bold, 22 pt.

| Style | Font | Weight | Size | Notes |
|-------|------|--------|------|-------|
| Display 72 | SF Pro Display | Bold (700) | 72 | Line height 1.0, e.g. "Hole 7" |
| Title XL | SF Pro Display | Bold (700) | 44 | Home hero "Maynard Golf" |
| Numeral 40 | SF Pro Display | Semibold (600) | 40 | Tabular numbers ("148 · 162 · 175") |
| Title | SF Pro Display | Bold (700) | 28 | Sheet titles ("Local rules") |
| Section | SF Pro Display | Bold (700) | 18–22 | Sentence case, −0.015 em tracking ("Players", screen titles) |
| Label caps | SF Pro Text | Semibold (600) | 10–13 | Caps, +0.04 em tracking ("TO PIN", "HCP INDEX") |
| Body 16 | SF Pro Text | Regular–Semibold (400–600) | 15–17 | Running text, rows, buttons |
| Caption 13 | SF Pro Text | Regular (400) | 12–13 | `textSecondary` (Gray 500) secondary text |

| ID | Requirement |
|----|-------------|
| DS-TY-01 | **No bundled fonts.** Use the system font only (`Font.system(size:weight:)` / text styles). There's no `UIAppFonts` entry, no font files in the bundle and no font license to list. *Why: the design switched from SF Pro + Inter to SF Pro; the system font also gets Dynamic Type, all languages and the Display / Text optical sizes for free.* |
| DS-TY-02 | Styles are `DSTextStyle` cases (`display`, `titleXL`, `numeral`, `title`, `section`, `label`, `labelSmall`, `labelMicro`, `body`, `bodyEmphasized`, `caption`, plus the component numerals `chipNumeral`, `scoreNumeral`, `dateDay`, `holeStat`, `holeYards`, `holeHandicap`, `holeNumeral`, `chipScore`, `chipScoreWide`, `cardName`, `profileName` (600 22, the Player card's name) and `linkCompact` (600 14, a card header's text button)), applied with `.dsFont(.title)`. Each scales with Dynamic Type relative to the nearest text style (`UIFontMetrics`), at the environment's Dynamic Type size, so previews and UI tests can set it. Label styles add caps and +0.04 em tracking and `section` −0.015 em (`DSTextStyle.tracking`, scaled with the size; `.dsLabel()` adds caps and tracking to any style); the numeral styles add tabular digits and stop growing at XXXL (X-07). |
| DS-TY-03 | Only the small label styles (`label`, `labelSmall`, `labelMicro`) are caps (`DSTextStyle.isCaps`); they apply uppercase and letter-spacing through a `ViewModifier` (`.dsFont`, `.dsLabel()`), not hard-coded strings. Localized source strings stay sentence-case. Titles, section headers, card titles and the in-progress card's "Hole 3 of 9" are sentence case. |
| DS-TY-04 | Numbers use tabular figures (`.monospacedDigit()`), so scores, totals and yardages line up and don't jump while they change. |
| DS-TY-05 | Rule of thumb: Display styles (bold or semibold, 20 pt and up) for numbers, headings and the hole card; Text styles for words, rows, buttons and captions. Use the standard width; don't use the condensed or compressed widths of SF Pro. |
| DS-TY-07 | Headings tighten and labels open up: `section` has −0.015 em tracking, the caps labels +0.04 em (Fairway C). The round PDF follows the same rule (RP-HD-01, 03). |
| DS-TY-06 | SF Pro is wider than SF Pro, so every layout that was sized for the condensed font (leaderboard columns, the hole card, score chips, the scorecard and PDF columns) is checked for truncation at the default size and at AX3; text that doesn't fit scales down (`minimumScaleFactor` no lower than 0.8) or wraps, never clips. |

## 5. Shape, spacing, elevation

| ID | Requirement |
|----|-------------|
| DS-SH-01 | Radii tokens (`DSRadius`), continuous curves: chips and badges 8, fields and tiles 12, cells and cards 16, yardage panel 18, list cards and summary card 22, score chip tiles 14, round cards 24, hole card 30, sheets 36–44, buttons pill (capsule). |
| DS-SH-02 | Spacing scale: 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24. Screen side gutter is 16. |
| DS-SH-03 | Touch targets: 48 pt primary, 44 pt minimum. |
| DS-SH-04 | Cards have no border; they rest on a whisper-soft shadow, `.dsCardElevation(cornerRadius:)`: two `cardShadow` layers, 0 1 2 and 0 4 16 (black @ 4 %), cast by a card-colored shape behind the card so its contents cast none. In Dark the shadow is clear and a 1 pt `cardOutline` (white @ 6 %) edges the card instead (Fairway C Dark). A selected card adds a 2 pt Blue stroke. |
| DS-SH-05 | Scrim adds a 12 pt backdrop blur on live photos. |

## 6. Materials

| ID | Requirement |
|----|-------------|
| DS-MT-01 | **Glass surface** **must** use the system Liquid Glass API (`.glassEffect(_:in:)`, `GlassEffectContainer`, `.buttonStyle(.glass)` where it fits), tinted to match the design. The app is iOS 26-only, so there is **no** fallback material. Light-mode target look: highlight gradient (white 30 % → 8 % → 14 %) over Ink @ 30–48 %, blur 22–26 pt with 180 % saturation, 1 pt white 28 % inner stroke and a top specular highlight. |
| DS-MT-02 | **Scrim surface**: Ink (Gray 900) @ 82 % plus 12 pt blur. |
| DS-MT-03 | Text on glass carries a subtle shadow (0 1 2 black @ 55 %) to protect contrast over bright imagery. |
| DS-MT-04 | Respect *Reduce Transparency*. The system Liquid Glass handles this automatically. Custom scrims fall back to opaque Ink. |
| DS-MT-05 | **Dark mode on photo screens** (from "Applied — Hole 1, dark mode"): the aerial photo is dimmed to about 72 % brightness and 90 % saturation. Glass tint deepens to black @ 62 % (the leaderboard to 74 %), with a fainter highlight gradient (white 14 % → 3 % → 6 %), a 14 % white inner stroke and a 28 % top highlight. Text on glass, the shot line, the pin marker and the landing dot don't change. The hole-number badge uses `primaryAction` (Blue 500). |
| DS-MT-06 | The glass tint is a token (`glassTint`, `glassTintStrong`: Ink @ 40 % / 48 % in Light, black @ 62 % / 74 % in Dark), and `MaterialSpec.resolve(colorScheme:reduceTransparency:strong:)` gives the scrim fill, blur, stroke and photo dimming (`.dsPhotoDimming()`), so the hole view needs no `colorScheme` branching. `-uiTestReduceTransparency` forces Reduce Transparency for UI tests (`dsReduceTransparencyOverride`). |

## 7. Components (all live in MaynardUI)

Each component **must** have SwiftUI previews of every state and variant it supports, built from the shared preview data (testing-standards TS-VS-01, 03…05), and appear in the DEBUG component catalog. Any logic (formatting, state mapping) must have unit tests.

### 7.1 Buttons
The capsule buttons are `ButtonStyle`s (`.dsPrimary(height:fullWidth:isLoading:)`, `.dsScrim`, `.dsTertiary`, `.dsTinted`, `.dsNeutralPill`, `.dsGlassPill`, `.dsTextLink`), so they work with `Button`, `NavigationLink` and `ShareLink`; their colors come from one table, `DSButtonKind`. `GlassIconButton` and `CircleIconButton` take their accessibility label as a required first argument.

| ID | Component | Spec |
|----|-----------|------|
| DS-BT-01 | `PrimaryButton` | Capsule, Blue 500 fill, white SF Pro 600 15–17 pt, height 48–56. Full-width variant. Disabled = `surfaceRaised` fill + `textSecondary` text. Loading = a spinner in place of the label; taps are ignored and VoiceOver hears "Loading". Callers also set `.disabled(isLoading)`, since a style can't block VoiceOver activation. Titles wrap to two lines rather than truncate. |
| DS-BT-02 | `ScrimButton` | Capsule, Scrim fill, white text, 1 pt white @ 28 % inner stroke (e.g. "View card"). |
| DS-BT-03 | `TertiaryButton` | Capsule, `tintedFill` (Blue 100) fill, `tintedText` (Blue 600) text (e.g. Round complete's "Done"). |
| DS-BT-04 | `TintedButton` | Capsule, Blue 100 fill, Blue 600 text (`tintedFill` / `tintedText`), optional leading "+" icon (e.g. "Add player", "Add"). Height 40–44. |
| DS-BT-05 | `NeutralPillButton` | Capsule, Gray 100 (`surfaceRaised`) fill, Ink text (Cancel / Back / Home). Optional leading chevron. |
| DS-BT-06 | `GlassPillButton` | Glass capsule, white text + leading icon, 44 pt (Exit, Card, New round). |
| DS-BT-07 | `GlassIconButton` | Glass circle, 44 or 52 pt, icon only, **requires** an accessibility label (Settings, Course map, Show my location, Out of order). An optional `badge: .warning` puts a Caution 400 triangle with an Ink exclamation mark and a 2 pt Ink outline (about 30 × 28 pt) on the top-trailing edge, offset 10 pt outward (HP-OO-03). The badge is decoration: the button's label says what it means. |
| DS-BT-08 | `TextLinkButton` | Blue 500 (`link`) SF Pro 600 16 pt (`bodyEmphasized`), no background, 44 pt hit area ("All Players", "See all"), `.dsTextLink`. The compact variant, `.dsCompactTextLink`, is SF Pro 600 14 (`linkCompact`) for a card header's trailing action ("Show 9 holes", PC-ST-04), with the same hit area. |
| DS-BT-09 | `CircleIconButton` | 44 pt circle, Gray 100 (`surfaceRaised`, light) or white @ 18 % (glass) fill, chevron-down close icon. |

### 7.2 Identity
| ID | Component | Spec |
|----|-----------|------|
| DS-ID-01 | `PlayerAvatar` | Circle, sizes 24/28/40/44 (Hole play's two-player cards)/48/52 (`.leaderboard`, Hole play's one-player card)/60/64 (`PlayerSummaryCard`, DS-CN-13)/96 (`.profile`, the Player card, 44 pt initial)/104. Fixed-size circles, so the initial doesn't follow Dynamic Type. The initial is about 42 % of the circle but never under 14 pt (`AvatarSize.minimumInitialSize`): 14 pt bold is WCAG large text, so white on the Flag and Fairway colors (4.3–4.4 : 1) passes at 3 : 1 even in the scorecard's 24 / 28 pt avatars (X-06). Shows the photo if there is one, otherwise the first initial in SF Pro 700 on the player color (foreground from §3.5). Optional `ringed`: a 3 pt ring (`PlayerAvatar.ringWidth`) in the player's color (`ringToken(for:)`, the palette's `backgroundToken`) hugs the circle, inside the view's frame, which grows by 3 pt on each side (`footprint`); on the initial it reads as a slightly larger circle in the same color. The Player card's profile uses it (PC-HDR-02). Accessibility label "Photo of {name}". |
| DS-ID-02 | `HoleNumberBadge` | Blue 500 circle (36/60 pt) with a white hole number. |
| DS-ID-03 | `AvatarPicker` | 104 pt avatar with a 34 pt Blue 500 camera badge, bottom-right, ringed in the page background. Wraps `PhotosPicker` (images, single selection); no camera. A loading state shows a spinner over the avatar. Its label, `AvatarPickerLabel`, is public, so a screen can put the same look on its own button or menu (Add player's menu once a photo is set, AP-PH-03). |

### 7.3 Chips, badges and tags
| ID | Component | Spec |
|----|-----------|------|
| DS-CH-01 | `YardageChip` | Scrim, radius 8, value (SF Pro 700 24, `DSTextStyle.chipNumeral`, grows with Dynamic Type up to XXXL) plus "YDS" unit (SF Pro 600 11–12, Gray 400). Takes yards (course data) and a `DistanceUnit`, showing meters ("M") when Settings asks for them; VoiceOver reads "148 yards". |
| DS-CH-02 | `HazardChip` | Orange 300 capsule, Red 500 dot, Ink caps label ("BUNKER · 245 CARRY"). |
| DS-CH-03 | `PinChip` | Ink capsule, Orange 500 flag icon + white caps text ("PIN 148"). |
| DS-CH-04 | `StatusPill` | Orange 500 capsule, Ink dot and text, "IN PROGRESS". |
| DS-CH-05 | ~~`TagChip`~~ | Removed: local rules no longer have tags. |
| DS-CH-06 | ~~`ResultBadge`~~ | Removed: no avatar badges remain (WIN and GHIN were both dropped). |
| DS-CH-07 | `NumberChip` | 30 pt rounded square (r 9), Gray 100 (`surfaceRaised`) with a Green 500 (`success`) number (SF Pro 700 17), for local rules. |
| DS-CH-08 | `PlayerScoreChip` | A player's gross on a `RoundRow`, in the style `RoundRow.ChipLayout` picks for the player count (the All rounds — variation board, iPhone C). **Tile** (three or four players): a rounded tile (radius 14, `DSRadius.chipTile`), up to 70 pt wide and sharing the row equally, or as wide as the name at accessibility sizes, where the row's chips wrap (`tileFitting`, DS-CN-04, DS-TY-06): the player's first name (SF Pro 600 13, one line) over the gross score (SF Pro 700 18, `chipScore`, grows up to XXXL), 6 / 4 pt padding, no avatar. **Wide** (one or two players): a 56 pt min-height chip, radius 14, padding 6 leading / 14 trailing / 6 vertical, with a 44 pt `PlayerAvatar` (photo or initial on the player's color), the first name (`bodyEmphasized`, one line, leading, scaling down to 0.8 before it truncates, DS-TY-06) and the gross trailing: `solo` (one player) has no fill and a 22 pt score (`dateDay`); `split` (two players) shares the row equally and has a 20 pt score (`chipScoreWide`). All `textPrimary`. Fill `chipFill` (Gray 50; black in Dark), or `chipHighlight` (Blue 100; `#0B2A4A` in Dark) for the round's lowest gross when two or more players played (`RoundRow.lowestScoreIDs`: every tie; none on a solo round, where there's nothing to compare). VoiceOver reads "{name}, {score}". |

### 7.4 Containers and lists
| ID | Component | Spec |
|----|-----------|------|
| DS-CN-01 | `CardContainer` | White, radius 22, on the soft card shadow (DS-SH-04), inner padding 14–16, rows separated by Hairline. |
| DS-CN-16 | `ContentCard` | White, radius 22, on the soft card shadow (DS-SH-04), even padding on every side (16 by default, 18 for the Player card's profile) and a vertical stack. For content inside a margin (the Player card's profile, Latest Scores and handicap cards); `CardContainer` is for rows that reach the card's edges. |
| DS-CN-02 | `SectionHeader` | Sentence-case SF Pro 700 22 title (`section`) plus an optional trailing `TextLinkButton` or `TintedButton`. Optional caps "· N OF M" subtitle. |
| DS-CN-03 | `PlayerRow` | Avatar 40, name (SF Pro 600 16), optional subtitle (Caption), trailing "HCP" label over value, optional chevron, optional checkbox. Height 62–64. |
| DS-CN-04 | `RoundRow` | As the All rounds — variation, Home — no round in progress and Player card — scrolled to rounds artboards (iPhone C): the date ("Nov 8", `bodyEmphasized`, `DisplayFormatting.roundDate`) with the trailing meta ("18 holes · Blue", `caption`, `textSecondary`), then the `PlayerScoreChip`s in round order, laid out by `RoundRow.ChipLayout`: one player is a `solo` wide chip; two are `split` wide chips side by side (stacked at accessibility sizes, or when either name wouldn't fit beside the other chip at full size, so no name is cut off: `ViewThatFits`); three or four are one row of tiles (at accessibility sizes they take their names' full width and wrap, so no name is cut off); and a chevron centered on the row. Each `RoundRow.Score` carries the player's color and decoded photo for the wide chips' avatars; callers ask their view model's `AvatarCache` only for one- and two-player rows (`RoundSummary.rowScores`). 14 pt vertical padding. No course name (every row is a Maynard round), weather or to-par; the lowest gross is highlighted (DS-CH-08). `showsChevron: false` hides the disclosure indicator for read-only Deleted rounds (#224); normal rows keep it. All rounds can replace the meta with `StatusPill(.inProgress)`. Callers set the accessibility label (HOME-RR-05). |
| ~~DS-CN-05~~ | ~~`RoundTile`~~ | **Removed.** The Player card lists previous rounds with `RoundRow` (DS-CN-04). |
| DS-CN-06 | `StatTile` | Gray 100 (`surfaceRaised`) tile (r 16): big number (SF Pro 700 28) + caption (SF Pro 12, `textSecondary`). A variant hosts a compact `DSSegmented` (`segmentTrack`) in place of the number. |
| DS-CN-13 | `PlayerSummaryCard` | White card (r 22, padding 18): 64 pt avatar, full name (SF Pro 600 20) over "Last played …", trailing "HCP INDEX" over the index (SF Pro 700 40, `emphasis`); a 3-tile `StatTile` row (Avg score, Best, Last round); an optional compact 12-month handicap chart (`PlayerSummaryCard.Chart`: "Handicap · 12 months" (sentence case) with the range, a 70 pt `emphasis` line and 10 % area with a ringed dot on the last point, then the month labels; drawn with 2 points or more). At accessibility sizes the index moves under the name and the tiles stack. One button for the whole card, read as one element with the caller's `accessibilitySummary`. Used on Home for the one-player, two-player and marquee layouts (01-home §4.4–4.5); marquee uses the chart at any total player count. |
| DS-CN-07 | `EmptyStateView` | Built on `ContentUnavailableView`: icon, title, body, optional action. |
| DS-CN-08 | `SettingsRow` | Label + hint + trailing accessory (Toggle / segmented / value + chevron). |
| DS-CN-09 | `DSToggle` | Standard `Toggle` with a Green 400 (`toggleOn`) on-tint (52×32), as `.toggleStyle(.ds)`. The off track is the system grey: SwiftUI can't color it, and a custom switch isn't worth losing the system control's behavior. |
| DS-CN-10 | `DSSegmented` | Field Fill (`segmentTrack`) track, white selected segment with a soft shadow (the compact variant sits on a `StatTile`). Drawn custom because the system segmented picker can't take these colors; VoiceOver gets a standard segmented `Picker` through `accessibilityRepresentation`. |
| DS-CN-11 | `FormFieldCard` | Grouped text fields with caps labels above the input and placeholder in `textSecondary`. Each `Field` sets its keyboard, text content type and capitalization, and can show an inline error under the input (Caption, `underPar`, identifier `{field id}.error`). The field's id is its accessibility identifier. Return moves to the next field; the last one's Return ends editing. |
| DS-CN-14 | `ColorSwatchPicker` | The five player colors as 44 pt swatches in a row, single select: the selected one has a 3 pt white ring inside a 2 pt `textPrimary` ring. Labeled with the color's name (`PlayerPalette.title`), with the selected trait; identifiers `{prefix}.{color}` (AP-CL-01, 02). |
| DS-CN-15 | `DSSearchField` | A 44 pt `surfaceRaised` field, radius 16: magnifier and placeholder in `textSecondary`, `textPrimary` text, a clear button while there is text ("Clear search"). For screens with `dsNavigationBar`, which hides the system bar that `.searchable` draws into (All players, AL-SR-01). |
| DS-CN-12 | `SelectableCard` | Card with a selected state (2 pt `emphasis` inner stroke, over the soft card shadow) used by `TeeCard`. |

### 7.5 Navigation and sheets
| ID | Component | Spec |
|----|-----------|------|
| DS-NV-01 | `DSNavigationBar` | 104 pt translucent `barTint` (Gray 50 @ 78 %, black @ 72 % in Dark) + blur bar, leading `NeutralPillButton`, centered sentence-case title (SF Pro 700 20, `section` tracking), optional trailing action. Options: `titleStyle` and `titleColor` override the default Section typography and foreground; Home uses Body 16 and fixed `black` for its compact title (HOME-HDR-05). `showsTitle: false` hides the title while preserving bar layout (Home’s expanded hero, #212). `background: .systemMaterial(isScrolled:)` is clear at the top and uses Apple’s unmodified `.ultraThinMaterial` once scrolled, without a color wash or hairline (Home, #232). `background: .photo(isScrolled:)` is clear at the top, then uses material and a hairline over a screen-supplied photo, without the standard `background` wash; it uses white shadowed title text. `titleAlignment: .leading` puts the title next to the leading button, and `background: .scrollEdge(isScrolled:)` keeps the bar transparent until content scrolls under it, then shows the blur with a bottom hairline (`DSBarBackground`, the Player card, PC-TOP-02, 04). Added with `.dsNavigationBar(_:titleAlignment:background:showsTitle:leading:trailing:)`, which hides the system bar and pins this one in the top safe area of a `NavigationStack` screen. Hiding the system bar turns off UIKit's edge swipe back, so the modifier turns it on again whenever there's a screen to go back to and no transition is running, and hands the gesture back to UIKit's own delegate once the screen has gone (UI-tested: a full swipe, a swipe released early, and a swipe on the root screen). |
| DS-NV-02 | `GlassSheet` | Bottom sheet built on `.sheet` + `.presentationDetents`: glass background, radius 44, 8 pt inset, grabber 40×5. |
| DS-NV-03 | `LightSheet` | Full-height `background` sheet, radius 36 top, grabber, title + subtitle header with a close button, bottom hairline. |
| DS-NV-04 | `StickyBottomCTA` | Primary button pinned to the bottom with a `background` fade gradient behind it (`.dsStickyBottomCTA { … }`). Sheets: `.dsGlassSheet(isPresented:)` (DS-NV-02) and `LightSheet` + `.dsLightSheet()` (DS-NV-03). |

### 7.6 Golf-specific display
| ID | Component | Spec |
|----|-----------|------|
| DS-GF-01 | `ScoreMark` | `ScoreMark(score:par:size:)`: the score numeral (`scoreNumeral`) styled by score relative to par: **≤ −2** double circle in `scoreUnder`; **−1** single circle in `scoreUnder`; **0** plain `textPrimary`; **+1** square outline in `scoreBogeyOutline`; **≥ +2** square filled with `scoreDoubleFill`, white text; **empty** (nil) "·" in `scoreEmpty`. Size 26–30 (default 28), growing with the numeral up to XXXL. The colors are semantic tokens, so in Dark mode the marks become Red 300 circles, Blue 400 outline squares; the filled square is Blue 400 in both appearances, lighter than the Light bogey outline (#283). The double circle is filled with `surfaceCard`, so the gap between its rings is the card, not white. VoiceOver reads "5, Bogey" or "Not played". For print (the round PDF) `PrintScoreMark(score:style:size:)` draws the same shapes at a fixed size, ignoring Dynamic Type, with the numeral in the mark's color (`MarkStyle.printForeground`: `scoreUnder` for circles, `scoreBogeyOutline` for the square, RP-TB-07). |
| DS-GF-02 | `ScoreLegend` | Row of swatches (the score marks without numerals) + Caption labels: Eagle, Birdie, Bogey, Double+. Wraps on narrow widths; read as one element. |
| DS-GF-03 | `ToParText` | Shows "E", "+n" or "−n" (true minus sign U+2212). On app surfaces: under par = `underPar`, par/over = `textSecondary` (`textPrimary` where the design shows it bold, e.g. the dark-mode player list). On glass and photo surfaces, in both modes: under par = Green 400, par/over = white. `ToParText(value:surface:style:)` with `surface` `.app(emphasized:)` or `.imagery`. VoiceOver reads "Even par", "2 over par", "1 under par". |
| DS-GF-04 | `ScoreNameBadge` | Capsule with the score name (ACE, ALBATROSS, EAGLE, BIRDIE, PAR, BOGEY, DOUBLE, TRIPLE, OVER, UNDER). Label style (caps). Under par = Red 700 `#B3231B` / white (`scoreNameUnder`; the board draws Red 500, which gives the 13 pt label only 4.3 : 1, under X-06's 4.5), par = white / Ink, over = Blue 500 / white (HP-ES-05). Source strings are sentence case ("Birdie"). |
| DS-GF-05 | `WeatherIcon` | SF Symbols for sunny, partly cloudy, cloudy, rain, windy (`sun.max.fill`, `cloud.sun.fill`, `cloud.fill`, `cloud.rain.fill`, `wind`), plus an optional "62°". It takes `WeatherIcon.Kind`, whose raw values match the stored `WeatherKind`; the WeatherKit mapping is `WeatherKind(weatherKit:)` in the data layer (DM-EN-04). Accessibility label "{Condition}, {n} degrees". |
| DS-GF-06 | `TeeDot` | 14 pt circle (scales with Dynamic Type) in the tee color: Blue = Blue 500, White = White, Yellow = Tee Yellow `#F2C94C`, Red = Red 500. White tees get a Gray 300 1.5 pt ring. `TeeDot.Tee` raw values match the stored `Tee`. Hidden from VoiceOver: the tee's name always sits beside it. |
| DS-GF-07 | `HoleInfoCard` | `HoleInfoCard(number:par:yards:handicap:)`: a glass card (radius 30) with `HoleNumberBadge` 60 (numeral 36) and a "PAR n" (`holeStat`, 700 26) / "nnn YDS" (`holeYards`, 600 21) / "HCP n" (`holeHandicap`, 600 17, Blue 200) stack, per HP-HOLE-01. Always yards. Read as one element: "Hole 1, par 4, 380 yards, handicap 7" (identifier `hole.infoCard`). |
| DS-GF-08 | `ScoreFormatter` (logic) | Pure functions: to-par string (`toPar`, `spokenToPar`), score name (`scoreName`, HP-ES-05), mark style (`markStyle`, with its tokens), OUT/IN/TOT sums (`totals`: TOT only for 9 holes; a sum is nil while none of its holes has a score), holes thru (`holesThru`: holes where every player has a score, SC-HDR-03) and "Thru N". **Must** reach 100 % unit-test coverage. |
| DS-GF-09 | `HoleScoreChip` | `HoleScoreChip(score:size:)`: a player's strokes on the hole shown, for Hole play's bottom card (HP-LB-05) and the Players page's score button (HP-PS-03). A Blue 200 bold numeral in a rounded square (Blue 300 @ 16 % fill, 1 pt Blue 300 @ 22 % border). Sizes: `.card` 36 pt (radius 11, numeral 19) on the one- and two-player cards, `.grid` 30 pt (radius 11, numeral 16, "+" 18) in the grid, `.players` 44 pt (radius 13, numeral 21) on the Players page. With no score, a dashed 1.5 pt Blue 300 @ 35 % outline around a "+" (Blue 300 @ 50 %). VoiceOver: "4 on this hole" or "No score yet". |

### 7.7 Course overlay components

The overlays in v2 are the ones on "iPhone — Hole 1": `ShotLine`, `PinMarker`, `TargetMarker` and `YardagePanel`. **Removed:** `LandingMarker`, `DistanceCard`, `YardageMarker`, `HazardCallout`, `TeeLabel`, `HoleTitleChip` and the landing callout. Don't build them.
| ID | Component | Spec |
|----|-----------|------|
| DS-OV-01 | `ShotLine` | Dotted white line (2.5 pt, dash 2 / 8, round caps, 90 % opacity) in **straight** legs: tee → target(s) → pin, one leg per point pair. Takes screen points, or coordinates and an `OverlayProjection`, and an optional `drawn` (0…1, the share drawn from the tee) for the draw-on animation (SL-MO-01). Hidden from VoiceOver (SL-DR-08). |
| DS-OV-02 | `PinMarker` | 17 pt Orange 500 dot, 3 pt Ink ring, 8.5 pt Orange 500 @ 35 % halo. `PinMarker()` is decorative and hidden from VoiceOver (SL-DR-08); `PinMarker(yards:asTarget:onStep:)` is the placeable pin (a tap on it starts Place pin, SL-TG-10): a 60 pt hit area and an adjustable element, "Pin, 152 yards" (SL-TG-08, #185); `asTarget` draws the `TargetMarker` crosshair instead of the dot, when the next shot is to the green (SL-DR-05). Identifier `hole.pin`. |
| ~~DS-OV-03~~ | ~~`LandingMarker`~~ | **Replaced** by `TargetMarker` (DS-OV-09). |
| ~~DS-OV-04~~ | ~~`YardageMarker`~~ | **Removed.** |
| ~~DS-OV-05~~ | ~~`HazardCallout`~~ | **Removed.** |
| ~~DS-OV-06~~ | ~~`TeeLabel`~~ | **Removed.** |
| ~~DS-OV-07~~ | ~~`DistanceCard`~~ | **Removed.** Not part of v2. Don't build it. |
| ~~DS-OV-08~~ | ~~`HoleTitleChip`~~ | **Removed.** |
| DS-OV-09 | `TargetMarker` | A 44 pt draggable crosshair: 13 pt-radius ring and four ticks in white (2.5 pt) over a black @ 55 % outline (5 pt), with a 5 pt Orange 500 center dot. 60 pt hit area. The screen attaches the drag; the marker is a VoiceOver adjustable element ("Target", value "165 yards, 220 to pin") whose increment / decrement steps toward the pin / tee (SL-TG-07). Identifier `hole.target.{n}`. (14-shot-lines §3) |
| DS-OV-10 | `YardagePanel` | Glass surface, radius 18, 150 pt wide: two columns (number in SF Pro 700 26 over a caps label in SF Pro 600 10, Blue 200) split by a hairline: TO TARGET and TO PIN. Sits 30 pt below the active target or pin. `YardagePanel(toTarget:toPin:)` takes measured yards and rounds to whole yards; a nil distance drops its column, so the pin's panel (`toTarget: nil`, SL-YD-08) shows TO PIN alone; it widens rather than wrap at large text sizes. Identifiers `hole.yardage`, `hole.yardage.toTarget`, `hole.yardage.toPin`. (14-shot-lines §4) |
| DS-OV-11 | `TeeMarker` | `TeeMarker(_ tee:)`: where the shot line starts, a 16 pt dot in the tee's color (`TeeDot.Tee.fill`) with a 2.5 pt white ring, or `TeeDot.Tee.ring` (Gray 300) for White, whose dot would otherwise lose its edge. Hidden from VoiceOver (SL-DR-09). |
| DS-OV-12 | `LocationDot` | The player's position on the hole map (HP-CTL-03): a 16 pt Blue 500 dot with a 3 pt White ring and a soft shadow, on a 36 pt Blue 500 @ 22 % halo. *Inferred, like the system's location dot; no artboard draws it.* VoiceOver reads "Your location" (`hole.myLocation`). Takes no touches. |
| DS-OV-13 | `PlacePinLabel` | "Place pin" over the zoomed green after it's tapped (SL-TG-10): white text in the `label` style on the glass surface, radius 18, 8 pt × 16 pt padding. Display only (no touches). Identifier `hole.placePin`. *Not on the artboards; follows the yardage panel's glass.* |

Overlay components place themselves by **map coordinate → screen point** projection that's injected as a protocol (`OverlayProjection`, applied with `.overlayPosition(_:in:)`), so they can be unit tested without a map. The hole camera (#115) implements it.

## 8. Catalog and quality

| ID | Requirement |
|----|-------------|
| DS-QA-01 | A DEBUG-only "Component Catalog" screen lists every component in every state. |
| DS-QA-02 | Every component has `#Preview`s for **every state and variant** it supports (default, pressed, disabled, selected, each size and style, empty and longest content), large Dynamic Type, **and Light and Dark appearance**, using the shared preview data (testing-standards TS-VS-01, 03…05). |
| DS-QA-03 | Unit tests cover all token values, contrast pairs, formatters and component state mapping (≥ 90 % library coverage, 100 % for `ScoreFormatter`). |
| DS-QA-04 | UI tests check the catalog renders and that each interactive component is reachable by VoiceOver identifier, in **both** Light and Dark appearance. |
| DS-QA-05 | The catalog has an appearance switch (preview only) so you can review Light and Dark side by side. |

