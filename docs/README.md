# Maynard Golf v2 — Documentation

This folder holds the product requirements for Maynard Golf v2. Each screen has its own requirements file. The files were inferred from the v2 visual design, the **Fairway Overlay** canvas (claude.ai/artifact/S7TQE9RtU8K2aRWSNeDvz3), and you can add detail to them over time.

## Requirements index

| # | Document | Design artboard(s) | GitHub story |
|---|----------|--------------------|--------------|
| 00 | [Design system & UI library](requirements/00-design-system.md) | Design system — palette, type, components; Design system — dark mode; Applied — Hole 1 (light + dark) | [#1](https://github.com/tassinari/MaynardGolf/issues/1) UI Library |
| 01 | [Home](requirements/01-home.md) (incl. All rounds) | Home; Home — no round in progress; Home — fresh install | [#23](https://github.com/tassinari/MaynardGolf/issues/23) Home screen |
| 02 | [Settings](requirements/02-settings.md) | Settings | [#29](https://github.com/tassinari/MaynardGolf/issues/29) Settings screen |
| 03 | [Local rules](requirements/03-local-rules.md) | Local rules modal | [#34](https://github.com/tassinari/MaynardGolf/issues/34) Local rules modal |
| 04 | [New round](requirements/04-new-round.md) | New round | [#38](https://github.com/tassinari/MaynardGolf/issues/38) New round screen |
| 05 | [Add player](requirements/05-add-player.md) | Add player | [#42](https://github.com/tassinari/MaynardGolf/issues/42) Add player screen |
| 07 | [Hole play](requirements/07-hole-play.md) | iPhone — Hole 1; Players modal; Enter score modal | [#53](https://github.com/tassinari/MaynardGolf/issues/53) Hole play screen |
| 08 | [Scorecard](requirements/08-scorecard.md) | Scorecard; Scorecard — landscape | [#64](https://github.com/tassinari/MaynardGolf/issues/64) Live scorecard |
| 09 | [Player card](requirements/09-player-card.md) | Player card; Player card — scrolled to rounds | [#69](https://github.com/tassinari/MaynardGolf/issues/69) Player card screen |
| 10 | [Round detail](requirements/10-round-detail.md) | Round detail; Round detail — share sheet | [#75](https://github.com/tassinari/MaynardGolf/issues/75) Round detail screen |
| 11 | [All players](requirements/11-all-players.md) | All players | [#80](https://github.com/tassinari/MaynardGolf/issues/80) All players screen |
| 12 | [Data model (SwiftData schema)](requirements/12-data-model.md) | — (see [data-model.drawio](data-model.drawio)) | [#91](https://github.com/tassinari/MaynardGolf/issues/91) Data model |
| 13 | [iCloud sync (CloudKit backup)](requirements/13-icloud-sync.md) | — | [#96](https://github.com/tassinari/MaynardGolf/issues/96) iCloud backup & sync |
| 14 | [Shot lines, target and yardages](requirements/14-shot-lines.md) | iPhone — Hole 1 | [#108](https://github.com/tassinari/MaynardGolf/issues/108) Shot lines |
| 15 | [Round PDF (scorecard export)](requirements/15-round-pdf.md) | Round PDF — landscape; Round PDF — 9 holes; Round detail — share sheet | [#109](https://github.com/tassinari/MaynardGolf/issues/109) Round PDF export |
| 16 | [Hole map (course map, cameras, swipe transitions)](requirements/16-hole-map.md) | iPhone — Hole 1 (at rest); no artboard for the transition | [#113](https://github.com/tassinari/MaynardGolf/issues/113) Hole map |
| 17 | [Round complete](requirements/17-round-complete.md) | Round complete | [#119](https://github.com/tassinari/MaynardGolf/issues/119) Round complete |
| 18 | [Handicap (calculator and data manager)](requirements/18-handicap.md) | — (non-UI) | [#125](https://github.com/tassinari/MaynardGolf/issues/125) Handicap |
| — | [Course data — Maynard GC](requirements/course-maynard-gc.md) | Official scorecard | [#16](https://github.com/tassinari/MaynardGolf/issues/16) CourseProvider, [#85](https://github.com/tassinari/MaynardGolf/issues/85) 9 / 18 holes |
| — | [Testing standards](requirements/testing-standards.md) | — | [#20](https://github.com/tassinari/MaynardGolf/issues/20) Test infrastructure |

Left out on purpose: the iPhone springboard artboard ("iPhone home screen") and the three **Chalk** variations (Chalk — Hole 1, Chalk — Players modal, Chalk — Enter score modal).

Stories with no requirements file of their own: [#120](https://github.com/tassinari/MaynardGolf/issues/120) App icon & launch screen (DS-BR-01, DS-BR-03), [#99](https://github.com/tassinari/MaynardGolf/issues/99) Build script, [#103](https://github.com/tassinari/MaynardGolf/issues/103) TestFlight, [#121](https://github.com/tassinari/MaynardGolf/issues/121) App Store release and [#122](https://github.com/tassinari/MaynardGolf/issues/122) v1 cleanup.

Shared foundation work (repositories, services, router) is tracked in [#14](https://github.com/tassinari/MaynardGolf/issues/14). All issues are on the [v2 project board](https://github.com/users/tassinari/projects/4).

## Data model diagram

[`data-model.drawio`](data-model.drawio) (open it in draw.io, or in VS Code with the draw.io extension) has two pages:

1. **SwiftData models:** the `@Model` classes `Player`, `PersonRound` and `Round` with their cascade relationships, the Codable value types stored inside them (`Score`, `WeatherSnapshot`), the enums, the bundled read-only course data (`Course`, `TeeInfo`, `Hole`, derived `RoundHole`), `SettingsStore`, and the derived models that are never stored.
2. **How it fits (layers):** Views → `@Observable` ViewModels → injected repositories, services and pure builders → storage (SwiftData container, bundle JSON, UserDefaults, WeatherKit).

## Conventions used in every requirements file

- **Requirement IDs** use the form `<SCREEN>-<AREA>-<NN>` (for example `HOME-HDR-01`). Tests and pull requests should cite them.
- **Must / Should / May** follow RFC 2119 meaning.
- **Inferred** marks behavior the static visual doesn't show but strongly suggests. Confirm or correct these.
- **Open questions** at the end of each file list gaps or conflicts in the design that need a decision.
- There's **no "me" / device-owner concept**. Ignore any "You" labels in the wires.
- Sample data in the visuals (Mark, Scottie, Tiger, Phil, scores, dates, handicaps) is illustrative only. Real data comes from SwiftData.
- Colors and type are referenced by **design-token name** (light-mode names; see X-12 for dark) (for example `Lake 600`, `Canopy 950`). They're defined in [00-design-system.md](requirements/00-design-system.md). Screens must never use raw hex values.

## Cross-cutting requirements (apply to every screen)

| ID | Requirement |
|----|-------------|
| X-01 | All user-facing strings **must** live in the String Catalog (`Localizable.xcstrings`) and be referenced with `String(localized:)` / `LocalizedStringKey`. **v2 ships in English only**; the catalog keeps other languages possible later. |
| X-02 | Screens **must** be composed from the shared UI library (`MaynardUI`). Don't style one-off views when a library component exists. |
| X-03 | Prefer standard SwiftUI/UIKit components (`NavigationStack`, `.sheet` with detents, `Toggle`, `Picker(.segmented)`, `.searchable`, `ShareLink`, `PhotosPicker`, Swift Charts, `ContentUnavailableView`) and theme them, rather than rebuilding them. |
| X-04 | Every interactive element **must** have a touch target of at least 44×44 pt (the design uses 48 pt for primary controls). |
| X-05 | Every interactive element **must** have an accessibility label. Icon-only buttons use the labels given in each file. Decorative images are hidden from accessibility. |
| X-06 | Text **must** meet WCAG AA contrast (4.5:1 for body, 3:1 for 24 pt+). Text never sits directly on turf imagery; always use a Scrim, Glass surface, Canopy chip or Bunker card. |
| X-07 | Layouts **must** support Dynamic Type up to at least AX3 without clipping. Numerals may cap at XXXL. |
| X-08 | ViewModels are `@Observable`, are injected with their dependencies (repositories, services, clock), and hold all presentation logic so it can be unit tested. |
| X-09 | Every new or changed model or ViewModel **must** have unit tests. Coverage for v2 code **must** be ≥ 90 % (see [testing-standards.md](requirements/testing-standards.md)). |
| X-10 | Every screen **must** have XCUITest coverage of its primary flows, using stable `accessibilityIdentifier`s. |
| X-11 | Errors (persistence, network, permissions) **must** show a user-facing, localized message and never crash. |
| X-12 | **iOS 26 only.** Every screen **must** support Light and Dark appearance, following the system setting. Colors come from the semantic tokens in [00-design-system.md §3.7](requirements/00-design-system.md#37-semantic-tokens-light--dark). Screen docs name the light-mode token (e.g. Moss 600, Lake 600, Flag 650), and the implementation uses the matching semantic token. |
| X-13 | **No analytics, crash-reporting or tracking SDKs.** No third-party telemetry of any kind. Logging is `os_log` on device only. The privacy manifest declares no tracking and no collected data types. |
| X-14 | **Multiple rounds can be in progress at once.** Nothing blocks starting a new round while another is incomplete (01-home HOME-HDR-07 / HOME-IPR-07). |
| X-15 | Data is backed up and synced through the user's private **iCloud (CloudKit)** database ([13-icloud-sync.md](requirements/13-icloud-sync.md)). |
| X-16 | The course is shown as **"Maynard Golf Club"** everywhere it's named (Settings, Local rules, rounds lists, Round detail, the PDF). The name comes from the course data (`Course.name`), never from a literal in a view. The app's own name on the Home hero and the Home Screen stays "Maynard Golf". |
| X-17 | Every permission the app asks for has a clear, localized usage description in `Info.plist`: location when in use (distance to the green), camera and photo library (player photos). The app never asks for a permission before the user taps the feature that needs it. |
| X-18 | "v2" is the project name for this rebuild. The app has **never been released** on the App Store; it ships as **version 1.2**, its first public release. There's **no data migration**: every install starts with an empty store, and leftovers from earlier development builds are deleted (12-data-model §8). |
| X-19 | **Device-agnostic layouts.** Version 1.2 ships for iPhone only, but no screen may assume a particular device: use size classes, safe areas and flexible layouts, never hard-coded screen sizes or device checks. iPad versions are planned for later. |

## Deferred decisions
- **New round player order:** whether the order players are selected in New round sets the play / leaderboard order. To be decided later; until then, columns follow selection order (`PersonRound.cardPosition`).
