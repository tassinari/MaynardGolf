# Maynard Golf v2 — Documentation

This folder holds the product requirements for Maynard Golf v2. Each screen has its own requirements file. The files were inferred from the v2 visual design, the **Fairway Overlay** canvas (claude.ai/artifact/S7TQE9RtU8K2aRWSNeDvz3), and you can add detail to them over time.

## Requirements index

| # | Document | Design artboard(s) | GitHub story |
|---|----------|--------------------|--------------|
| 00 | [Design system & UI library](requirements/00-design-system.md) | Design system — palette, type, components; Applied — overlays on the hole | UI Library |
| 01 | [Home](requirements/01-home.md) | Home; Home — no round in progress; Home — fresh install | Home screen |
| 02 | [Settings](requirements/02-settings.md) | Settings | Settings screen |
| 03 | [Local rules](requirements/03-local-rules.md) | Local rules modal | Local rules modal |
| 04 | [New round](requirements/04-new-round.md) | New round | New round screen |
| 05 | [Add player](requirements/05-add-player.md) | Add player | Add player screen |
| 06 | [Link GHIN](requirements/06-link-ghin.md) | Link GHIN | Link GHIN screen |
| 07 | [Hole play](requirements/07-hole-play.md) | iPhone — Hole 1; Players modal; Enter score modal | Hole play screen |
| 08 | [Scorecard](requirements/08-scorecard.md) | Scorecard; Scorecard — landscape | Live scorecard |
| 09 | [Player card](requirements/09-player-card.md) | Player card; Player card — scrolled to rounds | Player card screen |
| 10 | [Round detail](requirements/10-round-detail.md) | Round detail; Round detail — share sheet | Round detail screen |
| 11 | [All players](requirements/11-all-players.md) | All players | All players screen |
| — | [Testing standards](requirements/testing-standards.md) | — | Test infrastructure |

Left out on purpose: the iPhone springboard artboard ("iPhone home screen") and the three **Chalk** variations (Chalk — Hole 1, Chalk — Players modal, Chalk — Enter score modal).

## Conventions used in every requirements file

- **Requirement IDs** use the form `<SCREEN>-<AREA>-<NN>` (for example `HOME-HDR-01`). Tests and pull requests should cite them.
- **Must / Should / May** follow RFC 2119 meaning.
- **Inferred** marks behavior the static visual doesn't show but strongly suggests. Confirm or correct these.
- **Open questions** at the end of each file list gaps or conflicts in the design that need a decision.
- Sample data in the visuals (Mark, Scottie, Tiger, Phil, scores, dates, handicaps) is illustrative only. Real data comes from SwiftData.
- Colors and type are referenced by **design-token name** (for example `Lake 600`, `Canopy 950`). They're defined in [00-design-system.md](requirements/00-design-system.md). Screens must never use raw hex values.

## Cross-cutting requirements (apply to every screen)

| ID | Requirement |
|----|-------------|
| X-01 | All user-facing strings **must** live in the String Catalog (`Localizable.xcstrings`) and be referenced with `String(localized:)` / `LocalizedStringKey`. |
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
| X-12 | Supports Light appearance as designed. Dark Mode behavior is an open question (see 00-design-system). |
