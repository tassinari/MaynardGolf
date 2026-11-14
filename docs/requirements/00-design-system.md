# 00 — Design System & UI Library ("Fairway Overlay")

**Artboards:** Design system — palette, type, components · Design system — dark mode · Applied — Hole 1 · Applied — Hole 1, dark mode
**Platform:** iOS 26 and later only. Light and Dark appearance are both required.
**Deliverable:** a `MaynardUI` Swift package (or framework target) that every v2 screen builds on, plus a SwiftUI preview/catalog screen in DEBUG builds.

## 1. Purpose

Base greens are sampled from the course aerial. Overlays use colors the turf never contains (lake blue, flag orange), plus bunker sand and chalk, so labels stand apart from turf in both hue and lightness. The library makes those decisions reusable and testable.

## 2. Brand assets

| ID | Requirement |
|----|-------------|
| DS-BR-01 | The app icon is the orange **M** on golf-ball dimples. It's shown at 120/60/40 pt with the iOS continuous corner radius (27/13.5/9) and a soft shadow. |
| DS-BR-02 | The library header label reads "DESIGN SYSTEM · V1" and the wordmark reads "Fairway Overlay" (catalog screen only). |
| DS-BR-03 | The launch screen is the `background` color (Chalk 50 / Canopy 950) with no logo or text, so the hand-off to Home is seamless. The app icon ships in Light, Dark and Tinted variants (iOS 26 icon format). |

## 3. Color tokens

All colors **must** be exposed as `Color` tokens backed by Asset Catalog color sets. Screens must not use hex literals.

There are two layers:
- **Primitive tokens** (§3.1–3.3, §3.6) are fixed palette values, such as `Color.ds.lake600`.
- **Semantic tokens** (§3.7), such as `Color.ds.surfaceCard` or `Color.ds.underPar`, have a **Light** and a **Dark** value in their color set. They switch automatically with the system appearance.

Screens and components **must** use semantic tokens. A primitive may be used directly only where the color is the same in both appearances (for example, player colors other than Lake, or overlays on photos).

### 3.1 Course — sampled from photo

| Token | Hex | Usage |
|-------|-----|-------|
| Canopy 950 | `#0F1A08` | Primary text on light, tree shadow, darkest surface |
| Canopy 800 | `#1C2D0C` | Tree line, dark screen background behind imagery |
| Rough 700 | `#34431A` | Deep rough, body text on light cards (secondary) |
| Rough 600 | `#416308` | First cut, toggle "on" track, player color "Fairway" |
| Fairway 500 | `#507A07` | Fairway |
| Fringe 400 | `#7E9C2A` | Stripe light |
| Green 300 | `#99AD41` | Putting surface |
| Bunker 300 | `#E5C48C` | Sand; hazard chips, player color "Sand", total rows border |

### 3.2 Overlay — contrast colors

| Token | Hex | Usage |
|-------|-----|-------|
| Lake 600 | `#1E5AA8` | **Primary action**, links, selected state, bogey marks |
| Lake 200 | `#A9D2FF` | Accent on dark (labels such as "PAR 4 · HCP 3", "LANDING") |
| Lake 100 (inferred) | `#D4E8FF` | Secondary label on glass (HCP, hole subtitle) |
| Lake 50 (inferred) | `#E3ECF7` | Tinted button background, current-hole row highlight |
| Flag 600 | `#C2410C` | Pin, hazard, birdie/eagle marks, player color "Flag" |
| Flag 650 | `#A8380A` | Under-par numbers on light backgrounds (AA-safe orange). Semantic token: `underPar` (Light). |
| Flag 400 | `#FF9A3C` | Marker on photo, under-par numbers on dark/glass, IN PROGRESS pill |
| Scrim | Canopy 950 @ 82 % + 12 pt backdrop blur | Chips/cards over imagery |
| Bunker 100 | `#F4E6C8` | Light card, OUT/IN/TOT rows, tertiary button |
| Chalk 50 | `#F7F5EC` | App background on light screens; text on dark |
| Moss 400 | `#8E9A7C` | Muted text on dark, chevrons, placeholder text, player color "Moss" |

### 3.3 Neutral support tokens (observed in screens)

| Token | Hex | Usage |
|-------|-----|-------|
| Moss 600 | `#4E5A3E` | Secondary text/captions on light |
| Card | `#FFFFFF` | Card surface |
| Card Stripe | `#FBFAF5` | Alternating table row |
| Hairline | `#EFECE0` | Row separators inside cards |
| Card Border | `#E4E1D2` | 1 pt inset card border |
| Chalk 200 | `#E9E5D6` | Neutral pill button (Cancel/Back), disabled button |
| Chalk 300 | `#CFCBB8` | Toggle off track, unchecked ring, sheet grabber, empty score "·" |
| Tee Green 50 | `#E6EDD3` | Avatar placeholder background, HOLE header row (landscape), stat tiles |
| Tee Green 100 | `#D4DEB4` | Segment track inside Tee Green 50 stat tiles (Player card Holes toggle) |
| Tee Green 200 | `#C9D6A8` | Bottom border of the Round detail scorecard header row |

### 3.4 Readable pairings (must be honored)

| Pairing | Contrast |
|---------|----------|
| Chalk on Canopy | 16.4 : 1 |
| Lake 200 on Canopy | 11.4 : 1 |
| Flag 400 on Canopy | 8.5 : 1 |
| Canopy on Bunker | 9.8 : 1 |
| White on Lake 600 | 6.8 : 1 |
| White on Flag 600 | 5.2 : 1 |

| ID | Requirement |
|----|-------------|
| DS-CL-01 | **Never** put text directly on turf imagery. Chalk on Fairway 500 is only 4.7 : 1, and mowing stripes lower it further. Always place a Scrim, Glass, Canopy chip or Bunker card under copy. |
| DS-CL-02 | A unit test **must** assert the WCAG contrast ratio of each pairing above (calculated from the token values) is ≥ the documented value − 0.1. |

### 3.5 Player colors

The player color palette replaces `ColorValues` and **must** map to tokens with a matching foreground:

| Name | Background (Light) | Background (Dark) | Initial / foreground |
|------|-----------|-----------|-----------|
| Lake | Lake 600 | **Lake 500** | White |
| Sand | Bunker 300 | Bunker 300 | Canopy 950 |
| Flag | Flag 600 | Flag 600 | White |
| Fairway | Rough 600 | Rough 600 | White |
| Moss | Moss 400 | Moss 400 | Canopy 950 |

Player colors are flat and keep their light values in Dark mode. The one exception is Lake, which moves to Lake 500 **everywhere, including avatars on photo/glass screens such as the Hole play leaderboard**. The dark Hole 1 artboard still shows Lake 600 on the leaderboard avatar; ignore that.

DS-CL-03: Existing `ColorValues` (red, blue, green, yellow, orange) **must** migrate to the new palette without data loss: red→Flag, blue→Lake, green→Fairway, yellow→Sand, **orange→Flag**.

### 3.6 Dark mode palette (from "Design system — dark mode")

This is the night version of the same system. Surfaces come from the tree-shadow greens, Chalk becomes the text color, and Lake and Flag step up a shade so they still read on dark green.

| Token | Hex | Usage |
|-------|-----|-------|
| Background | `#0F1A08` (Canopy 950) | Page background (replaces Chalk 50) |
| Well | `#0B1306` | Inset or recessed area behind cards |
| Card | `#1A2614` | Card surface (replaces White) |
| Raised / pressed | `#243220` | Neutral pill buttons, segmented track, pressed rows (replaces Chalk 200 `#E9E5D6`) |
| Segment selected | `#3A4A33` | Selected segment of a segmented control |
| Divider | `#2F3D29` | Hairlines and card borders (replaces `#EFECE0` / `#E4E1D2`) |
| Sage 300 | `#B8C2A6` | Secondary text (replaces Moss 600) |
| Moss 400 | `#8E9A7C` | Tertiary text, chevrons, placeholders |
| Lake 500 | `#2F6FC2` | Primary buttons, selected state, hole-number badge, filled double-bogey mark (replaces Lake 600) |
| Lake 300 | `#7DB4F5` | Links, text buttons, bogey square outline |
| Lake 300 @ 16 % | `rgba(125,180,245,0.16)` | Tinted button background (replaces Lake 50) |
| Flag 400 | `#FF9A3C` | Under-par numbers, birdie/eagle circles (replaces Flag 650 `#A8380A`) |
| Flag 700D | `#B5450E` | Hazard fill behind white text (replaces Flag 600 as a fill). The designer's board calls it "Flag 650"; it's renamed to avoid a clash with the light under-par color. Semantic token: `hazardFill` (Dark). |
| Bunker 900 | `#2E2818` | OUT/IN/TOT total rows (replaces Bunker 100) |
| Bunker 300 (Sand) | `#E5C48C` | Text on Bunker 900 |
| Green 200 | `#C4D88A` | Success indicators |
| Toggle on | `#6F9A2E` | `DSToggle` on-track (replaces Rough 600) |

### 3.7 Semantic tokens (light → dark)

Every component **must** use these tokens. The first eight rows come straight from the designer's light → dark mapping table. The rest are worked out from the "Components in dark" panel and are approved as written.

| Semantic token | Light | Dark |
|----------------|-------|------|
| `background` | Chalk 50 `#F7F5EC` | Canopy 950 `#0F1A08` |
| `surfaceCard` | White `#FFFFFF` | Card `#1A2614` |
| `surfaceRaised` | Chalk 200 `#E9E5D6` | Raised `#243220` |
| `textPrimary` | Canopy 950 `#0F1A08` | Chalk 50 `#F7F5EC` |
| `textSecondary` | Moss 600 `#4E5A3E` | Sage 300 `#B8C2A6` |
| `primaryAction` | Lake 600 `#1E5AA8` | Lake 500 `#2F6FC2` |
| `underPar` | Flag 650 `#A8380A` | Flag 400 `#FF9A3C` |
| `surfaceTotals` | Bunker 100 `#F4E6C8` | Bunker 900 `#2E2818` |
| `textOnTotals` | Canopy 950 | Bunker 300 `#E5C48C` |
| `textTertiary` | Moss 400 `#8E9A7C` | Moss 400 `#8E9A7C` |
| `link` | Lake 600 `#1E5AA8` | Lake 300 `#7DB4F5` |
| `tintedFill` | Lake 50 `#E3ECF7` | Lake 300 @ 16 % |
| `tintedText` | Lake 600 | Lake 300 |
| `divider` | Hairline `#EFECE0` | Divider `#2F3D29` |
| `cardBorder` | Card Border `#E4E1D2` | Divider `#2F3D29` |
| `tableStripe` | Card Stripe `#FBFAF5` | Card `#1A2614` (no stripe) |
| `currentHoleHighlight` | Lake 50 `#E3ECF7` | Lake 300 @ 16 % |
| `hazardFill` | Flag 600 `#C2410C` | Flag 700D `#B5450E` |
| `success` | Rough 600 `#416308` | Green 200 `#C4D88A` |
| `toggleOn` | Rough 600 `#416308` | `#6F9A2E` |
| `toggleOff` | Chalk 300 `#CFCBB8` | Raised `#243220` |
| `segmentTrack` / `segmentSelected` | Chalk 200 / White | Raised `#243220` / `#3A4A33` |
| `scoreUnder` (birdie/eagle marks) | Flag 600 `#C2410C` | Flag 400 `#FF9A3C` |
| `scoreBogeyOutline` | Lake 600 | Lake 300 `#7DB4F5` |
| `scoreDoubleFill` | Lake 600 | Lake 500 `#2F6FC2` |
| `scoreEmpty` | Chalk 300 `#CFCBB8` | Divider `#2F3D29` |
| `avatarPlaceholder` | Tee Green 50 `#E6EDD3` | Raised `#243220` |

### 3.8 Dark readable pairings (must be honored; ratios measured on Card)

| Pairing | Contrast |
|---------|----------|
| Chalk 50 on Card | 14.4 : 1 |
| Sage 300 on Card | 8.5 : 1 |
| Moss 400 on Card | 5.3 : 1 |
| Lake 300 on Card | 7.3 : 1 |
| Flag 400 on Card | 7.5 : 1 |
| Sand on Bunker 900 | 8.8 : 1 |
| White on Lake 500 | 5.0 : 1 |
| White on Flag 700D | 5.5 : 1 |

| ID | Requirement |
|----|-------------|
| DS-DM-01 | The app **must** support Light and Dark appearance and follow the system setting. There is **no** in-app appearance override. |
| DS-DM-02 | Every semantic token in §3.7 **must** have both a Light and a Dark value in its Asset Catalog color set. |
| DS-DM-03 | A unit test **must** resolve every semantic token in both `UITraitCollection(userInterfaceStyle:)` styles and assert the documented hex values. |
| DS-DM-04 | A unit test **must** assert every dark pairing in §3.8 meets its documented ratio, within 0.1. |
| DS-DM-05 | Photo screens with liquid glass (Hole play, Players sheet, Enter score sheet, Home hero) keep the same layout and text colors in both modes. In Dark mode the aerial photo **is dimmed** and the glass tint deepens (DS-MT-05). The board note "stay the same in both modes" refers to layout and text only. |
| DS-DM-06 | Images and icons that carry color (weather icons, app icon) **must** be checked on both backgrounds. Weather icons use semantic strokes. |

## 4. Typography

| Style | Font | Weight | Size | Notes |
|-------|------|--------|------|-------|
| Display 72 | Sofia Sans Condensed | 700 | 72 | Line height 1.0, e.g. "Hole 7" |
| Title XL | Sofia Sans Condensed | 700 | 44 | Home hero "Maynard Golf" |
| Numeral 40 | Sofia Sans Condensed | 600 | 40 | Tabular numbers ("148 · 162 · 175") |
| Title | Sofia Sans Condensed | 700 | 28 | Sheet titles ("Local rules") |
| Section | Sofia Sans Condensed | 700 | 20–22 | Caps, +0.06 em tracking ("PLAYERS") |
| Label 14 caps | Sofia Sans Condensed | 600 | 10–15 | Caps, +0.12–0.14 em tracking ("TO PIN") |
| Body 16 | Inter | 400–600 | 15–17 | Running text, rows, buttons |
| Caption 13 | Inter | 400 | 12–13 | Moss 600 secondary text |

| ID | Requirement |
|----|-------------|
| DS-TY-01 | Bundle Sofia Sans Condensed (500/600/700) and Inter (400/500/600) and register them in `Info.plist` (`UIAppFonts`). Check the OFL licenses and add them to About › Licenses. |
| DS-TY-02 | Expose styles as `Font.ds.display`, `.numeral`, `.section`, `.label`, `.body`, `.caption`, etc. Each scales with Dynamic Type (`relativeTo:`). |
| DS-TY-03 | Label styles apply uppercase and letter-spacing through a `ViewModifier` (`.dsLabel()`), not hard-coded strings. Localized source strings stay sentence-case. |
| DS-TY-04 | Numbers use tabular figures (`.monospacedDigit()`). |
| DS-TY-05 | Rule of thumb: Sofia Sans Condensed for numbers and caps labels, Inter for words. |

## 5. Shape, spacing, elevation

| ID | Requirement |
|----|-------------|
| DS-SH-01 | Radii tokens: chips 10, tiles 14, cards 16, list cards 20, round cards 24, sheets 36–44, buttons pill (capsule). |
| DS-SH-02 | Spacing scale: 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24. Screen side gutter is 16. |
| DS-SH-03 | Touch targets: 48 pt primary, 44 pt minimum. |
| DS-SH-04 | Cards use a 1 pt inset border (Card Border) and no drop shadow. |
| DS-SH-05 | Scrim adds a 12 pt backdrop blur on live photos. |

## 6. Materials

| ID | Requirement |
|----|-------------|
| DS-MT-01 | **Glass surface** **must** use the system Liquid Glass API (`.glassEffect(_:in:)`, `GlassEffectContainer`, `.buttonStyle(.glass)` where it fits), tinted to match the design. The app is iOS 26-only, so there is **no** fallback material. Light-mode target look: highlight gradient (white 30 % → 8 % → 14 %) over Canopy 950 @ 30–48 %, blur 22–26 pt with 180 % saturation, 1 pt white 28 % inner stroke and a top specular highlight. |
| DS-MT-02 | **Scrim surface**: Canopy 950 @ 82–86 % plus 12 pt blur. |
| DS-MT-03 | Text on glass carries a subtle shadow (0 1 2 Canopy @ 55 %) to protect contrast over bright imagery. |
| DS-MT-04 | Respect *Reduce Transparency*. The system Liquid Glass handles this automatically. Custom scrims fall back to opaque Canopy 800. |
| DS-MT-05 | **Dark mode on photo screens** (from "Applied — Hole 1, dark mode"): the aerial photo is dimmed to about 72 % brightness and 90 % saturation. Glass tint deepens to `#080D05` @ 62 % (the leaderboard to 74 %), with a fainter highlight gradient (white 14 % → 3 % → 6 %), a 14 % white inner stroke and a 28 % top highlight. Text on glass, the shot line, the pin marker and the landing dot don't change. The hole-number badge uses `primaryAction` (Lake 500). |
| DS-MT-06 | The glass tint and photo dimming are tokens (`glassTint`, `glassTintStrong`, `photoDimming`) that resolve per appearance, so the hole view needs no `colorScheme` branching. |

## 7. Components (all live in MaynardUI)

Each component **must** have SwiftUI previews and appear in the DEBUG component catalog. Any logic (formatting, state mapping) must have unit tests.

### 7.1 Buttons
| ID | Component | Spec |
|----|-----------|------|
| DS-BT-01 | `PrimaryButton` | Capsule, Lake 600 fill, white Inter 600 15–17 pt, height 48–56. Full-width variant. Disabled = Chalk 200 fill + Moss 600 text. |
| DS-BT-02 | `ScrimButton` | Capsule, Scrim fill, Chalk text, 1 pt Chalk @ 28 % inner stroke (e.g. "View card"). |
| DS-BT-03 | `TertiaryButton` | Capsule, Bunker 100 fill, Canopy text (e.g. "Club up", "Card"). |
| DS-BT-04 | `TintedButton` | Capsule, Lake 50 fill, Lake 600 text, optional leading "+" icon (e.g. "Add player", "Add"). Height 40–44. |
| DS-BT-05 | `NeutralPillButton` | Capsule, Chalk 200 fill, Canopy text (Cancel / Back / Home). Optional leading chevron. |
| DS-BT-06 | `GlassPillButton` | Glass capsule, Chalk text + leading icon, 44 pt (Exit, Card, New round). |
| DS-BT-07 | `GlassIconButton` | Glass circle, 44 or 52 pt, icon only, **requires** an accessibility label (Settings, Course map, Show my location). |
| DS-BT-08 | `TextLinkButton` | Lake 600 Inter 600 15 pt, no background, 44 pt hit area ("All Players", "See all"). |
| DS-BT-09 | `CircleIconButton` | 44 pt circle, Chalk 200 (light) or white @ 18 % (glass) fill, chevron-down close icon. |

### 7.2 Identity
| ID | Component | Spec |
|----|-----------|------|
| DS-ID-01 | `PlayerAvatar` | Circle, sizes 24/28/40/44/48/60/104. Shows the photo if there is one, otherwise the first initial in Sofia Sans Condensed 700 on the player color (foreground from §3.5). Accessibility label "Photo of {name}". |
| DS-ID-02 | `HoleNumberBadge` | Lake 600 circle (36/60 pt) with a white hole number. |
| DS-ID-03 | `AvatarPicker` | 104 pt avatar with a 34 pt Lake 600 camera badge, bottom-right, ringed in Chalk. Wraps `PhotosPicker` and the camera. |

### 7.3 Chips, badges and tags
| ID | Component | Spec |
|----|-----------|------|
| DS-CH-01 | `YardageChip` | Scrim, radius 10, value (Sofia 700 22–26) plus "YDS" unit (Sofia 600 11–12, Moss 400). |
| DS-CH-02 | `HazardChip` | Bunker 300 capsule, Flag 600 dot, caps label ("BUNKER · 245 CARRY"). |
| DS-CH-03 | `PinChip` | Canopy 950 capsule, Flag 400 flag icon + caps text ("PIN 148"). |
| DS-CH-04 | `StatusPill` | Flag 400 capsule, Canopy dot, "IN PROGRESS". |
| DS-CH-05 | ~~`TagChip`~~ | Removed: local rules no longer have tags. |
| DS-CH-06 | ~~`ResultBadge`~~ | Removed: no avatar badges remain (WIN and GHIN were both dropped). |
| DS-CH-07 | `NumberChip` | 30 pt rounded square (r 9), Tee Green 50 with a Rough 600 number (Sofia 700 17), for local rules. |
| DS-CH-08 | `PlayerScoreChip` | Capsule (Chalk `#F4F2EA`; dark: Raised), padding 3 / 9 / 3 / 3: a 22 pt avatar dot (photo, or initial in Sofia 700 12 on the player's color) and the gross score (Sofia 700 16). Used in `RoundRow`. |

### 7.4 Containers and lists
| ID | Component | Spec |
|----|-----------|------|
| DS-CN-01 | `CardContainer` | White, radius 20, 1 pt Card Border, inner padding 14–16, rows separated by Hairline. |
| DS-CN-02 | `SectionHeader` | Caps Sofia 700 20–22 title plus an optional trailing `TextLinkButton` or `TintedButton`. Optional "· N OF M" subtitle. |
| DS-CN-03 | `PlayerRow` | Avatar 40, name (Inter 600 16), optional subtitle (Caption), trailing "HCP" label over value, optional chevron, optional checkbox. Height 62–64. |
| DS-CN-04 | `RoundRow` | Date block (caps label 11 + day 22: month on Home, weekday in All rounds), course name with trailing meta ("18 holes · Blue"), a wrapping row of `PlayerScoreChip`s, trailing chevron. Top-aligned, 14 pt vertical padding, 66 pt minimum height. No winner, weather or to-par. |
| DS-CN-05 | `RoundTile` | Grid tile (white, r 20, padding 14): date + weather icon / temperature, large score (Sofia 700 48), tees + to-par (Sofia 700 23). No course name. |
| DS-CN-06 | `StatTile` | Tee Green 50 tile (r 16): big number (Sofia 700 28) + caption (Inter 12, Moss 600). A variant hosts a compact `DSSegmented` (Tee Green 100 track) in place of the number. |
| DS-CN-07 | `EmptyStateView` | Built on `ContentUnavailableView`: icon, title, body, optional action. |
| DS-CN-08 | `SettingsRow` | Label + hint + trailing accessory (Toggle / segmented / value + chevron). |
| DS-CN-09 | `DSToggle` | Standard `Toggle` with a Rough 600 on-tint and Chalk 300 off track (52×32). |
| DS-CN-10 | `DSSegmented` | Standard `Picker(.segmented)` themed: Chalk 200 track, white selected segment. |
| DS-CN-11 | `FormFieldCard` | Grouped text fields with caps labels above the input and placeholder in Moss 400. |
| DS-CN-12 | `SelectableCard` | Card with a selected state (2 pt Lake 600 inner stroke) used by `TeeCard`. |

### 7.5 Navigation and sheets
| ID | Component | Spec |
|----|-----------|------|
| DS-NV-01 | `DSNavigationBar` | 104 pt translucent Chalk @ 92 % + blur bar, leading `NeutralPillButton`, centered caps title (Sofia 700 20), optional trailing action. Built on `.toolbar` / `NavigationStack` and styled. |
| DS-NV-02 | `GlassSheet` | Bottom sheet built on `.sheet` + `.presentationDetents`: glass background, radius 44, 8 pt inset, grabber 40×5. |
| DS-NV-03 | `LightSheet` | Full-height Chalk sheet, radius 36 top, grabber, title + subtitle header with a close button, bottom hairline. |
| DS-NV-04 | `StickyBottomCTA` | Primary button pinned to the bottom with a Chalk fade gradient behind it. |

### 7.6 Golf-specific display
| ID | Component | Spec |
|----|-----------|------|
| DS-GF-01 | `ScoreMark` | Score numeral styled by score relative to par: **≤ −2** double circle in `scoreUnder`; **−1** single circle in `scoreUnder`; **0** plain `textPrimary`; **+1** square outline in `scoreBogeyOutline`; **≥ +2** square filled with `scoreDoubleFill`, white text; **empty** "·" in `scoreEmpty`. Size 26–30. In Dark mode the marks become Flag 400 circles, Lake 300 outline squares and Lake 500 filled squares. The double-circle gap ring uses `surfaceCard`, not white. |
| DS-GF-02 | `ScoreLegend` | Row of swatches + labels: Eagle, Birdie, Bogey, Double+. |
| DS-GF-03 | `ToParText` | Shows "E", "+n" or "−n" (true minus sign U+2212). On app surfaces: under par = `underPar`, par/over = `textSecondary` (`textPrimary` where the design shows it bold, e.g. the dark-mode player list). On glass and photo surfaces, in both modes: under par = Flag 400, par/over = Chalk or Lake 100. |
| DS-GF-04 | `ScoreNameBadge` | Capsule with the score name (ACE, ALBATROSS, EAGLE, BIRDIE, PAR, BOGEY, DOUBLE, TRIPLE, OVER, UNDER). Under par = Flag 600, par = Chalk, over = Lake 600. |
| DS-GF-05 | `WeatherIcon` | Icons for sunny, partly cloudy, cloudy, rain, windy, plus an optional "62°". Maps from WeatherKit conditions. Accessibility label "{Condition}, {n} degrees". |
| DS-GF-06 | `TeeDot` | 14 pt circle in the tee color. White tees get a Moss 400 1.5 pt ring. |
| DS-GF-07 | `HoleInfoCard` | Glass card: `HoleNumberBadge` 60 + "PAR n" / "nnn YDS" / "HCP n" stack. |
| DS-GF-08 | `ScoreFormatter` (logic) | Pure functions: to-par string, score name, mark style, OUT/IN/TOT sums, "thru N". **Must** reach 100 % unit-test coverage. |

### 7.7 Course overlay components

Only the overlays on "Applied — Hole 1" (light and dark) are part of v2: `ShotLine`, `PinMarker` and `LandingMarker`. **Removed:** `DistanceCard`, `YardageMarker`, `HazardCallout`, `TeeLabel`, `HoleTitleChip` and the landing callout. Don't build them.
| ID | Component | Spec |
|----|-----------|------|
| DS-OV-01 | `ShotLine` | Dotted Chalk line (2 pt dash / 8–10 gap, round caps, 90 % opacity) from tee to pin along a quadratic path. Can be turned off in Settings ("Shot line on map"). |
| DS-OV-02 | `PinMarker` | 16–18 pt Flag 400 dot, 3 pt Canopy ring, 8–9 pt Flag 400 @ 35 % halo. |
| DS-OV-03 | `LandingMarker` | 6–7 pt Lake 200 dot with a 2.5–3 pt Canopy ring. No callout. |
| ~~DS-OV-04~~ | ~~`YardageMarker`~~ | **Removed.** |
| ~~DS-OV-05~~ | ~~`HazardCallout`~~ | **Removed.** |
| ~~DS-OV-06~~ | ~~`TeeLabel`~~ | **Removed.** |
| ~~DS-OV-07~~ | ~~`DistanceCard`~~ | **Removed.** Not part of v2. Don't build it. |
| ~~DS-OV-08~~ | ~~`HoleTitleChip`~~ | **Removed.** |

Overlay components place themselves by **map coordinate → screen point** projection that's injected as a protocol, so they can be unit tested without a map.

## 8. Catalog and quality

| ID | Requirement |
|----|-------------|
| DS-QA-01 | A DEBUG-only "Component Catalog" screen lists every component in every state. |
| DS-QA-02 | Every component has `#Preview`s for default, disabled/selected, large Dynamic Type, **and Light and Dark appearance**. |
| DS-QA-03 | Unit tests cover all token values, contrast pairs, formatters and component state mapping (≥ 90 % library coverage, 100 % for `ScoreFormatter`). |
| DS-QA-04 | UI tests check the catalog renders and that each interactive component is reachable by VoiceOver identifier, in **both** Light and Dark appearance. |
| DS-QA-05 | The catalog has an appearance switch (preview only) so you can review Light and Dark side by side. |

