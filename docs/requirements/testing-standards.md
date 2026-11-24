# Testing Standards (v2)

These standards apply to every v2 story. A story isn't done until its tests meet them.

## 1. Unit tests
| ID | Requirement |
|----|-------------|
| TS-UT-01 | Use **Swift Testing** (`import Testing`, `@Test`, `#expect`) for new tests. Existing XCTest tests may stay. |
| TS-UT-02 | **Line coverage ≥ 90 %** for every v2 module / file group: models, ViewModels, services, formatters and MaynardUI logic. Pure logic (formatters, scorecard model, score entry, stats) aims for **100 %**. |
| TS-UT-03 | SwiftData tests use an in-memory `ModelContainer` (as `DataTests` does) with one container per test for isolation. |
| TS-UT-04 | External dependencies (WeatherKit, Location, Haptics, Clock, FileManager, UserDefaults) sit behind protocols and are injected. Tests use fakes, never the network. |
| TS-UT-05 | The first release has no migration. **After release**, every schema change includes a migration test that opens a store written by the previous schema version and checks the data. |
| TS-UT-06 | Use parameterized tests (`@Test(arguments:)`) for tables: score names, to-par formatting, mark styles, bucketing. |

## 2. UI tests
| ID | Requirement |
|----|-------------|
| TS-UI-01 | XCUITest covers each screen's primary flows and empty / error states. |
| TS-UI-02 | Launch arguments seed deterministic data: `-uiTestSeed <fixture>` (every `Fixture` case, listed in 12-data-model DM-TS-01: `onePlayer` and `twoPlayers` have rounds and enough history for a handicap chart, `outsideScores` adds outside courses and scores), `-uiTestMockWeather [fail]`, `-uiTestFixedDate 2026-11-11T09:42:00Z`, plus `-uiTestMockLocation granted|denied`, `-uiTestFailPersistence`, `-uiTestCorruptStore`, `-uiTestLeftoverStore` and `-uiTestRoute <screen>`, `-uiTestAppearance light|dark` (all documented on `LaunchArguments`; parsed in Debug builds only). The app uses an in-memory store under any `-uiTest…` argument. |
| TS-UI-07 | Fault and mock arguments, so error and permission states can be UI-tested. In place (#14, #20): `-uiTestFailPersistence`, `-uiTestCorruptStore`, `-uiTestLeftoverStore`, `-uiTestMockLocation granted|denied`, `-uiTestMockWeather success|fail`. Each feature story adds its own: `-uiTestMockPhoto [fail]` (Add player photo, #127), `-uiTestCloud on|signedOut|storageFull|syncError|importing` (iCloud, #96), `-uiTestNoLocalRules` (Local rules, #34), `-pdfFailure` / `-pdfSlow` (Round PDF, #109). All are parsed only in Debug builds (`LaunchArguments`). |
| TS-UI-08 | The seed data includes rounds with 1–4 players, 9- and 18-hole rounds, a round with no weather, a tied round, players with a manual index, a calculated index and no index, a player in a round in progress, and a name with a diacritic. |
| TS-UI-03 | Elements are found by `accessibilityIdentifier` (listed in each requirements file), never by localized text. Every UI test subclasses `MaynardUITestCase` (`launch(_:)`, `tap(_:)`, `assertExists(_:)`, `text(_:)`, `waitForText(_:_:)`, `reveal(_:)`, `systemAlertIsShown()`). The shared test plan `MaynardGolf.xctestplan` runs the test targets with coverage on: the unit targets serially, the UI tests **in parallel** on clones of the simulator (`scripts/build.sh --workers`, default 3), so every UI test must stand alone (its own launch and seed). |
| TS-UI-04 | **Accessibility isn't tested.** No accessibility audits (`performAccessibilityAudit`), Dynamic Type or VoiceOver tests, and reviews don't ask for them (CLAUDE.md). `accessibilityIdentifier` stays: it's how UI tests find elements. |
| TS-UI-05 | UI tests run on **one device, iPhone 18 Pro** (`scripts/build.sh test`'s default). Running them on more devices is opt-in: `--devices "iPhone 17e,iPhone 18 Pro Max"` checks the smallest and largest screens when a change affects layout (X-19). A UI test checks what only a running app can show (navigation, sheets, gestures, wiring); rules a view model or pure type decides are unit-tested there, not repeated through the UI. |
| TS-UI-06 | The primary flow of each screen runs once in Dark appearance (`-uiTestAppearance dark`, through `MaynardUITestCase.Options.appearance`). |

## 3. Visual checks
| ID | Requirement |
|----|-------------|
| TS-VS-01 | **Every view has previews.** Every SwiftUI view in the app and in MaynardUI (screens, sheets, cards, rows, cells, overlays and components) has `#Preview`s. A view with no previews isn't done. |
| TS-VS-03 | **Every possibility is previewed.** A view's previews cover every state it can show: each data state (loading, empty, populated, error), each mode (create / edit, in progress / complete, selected / disabled, sheet open), and each data variation the requirements describe (for example 1–4 players, 9 / 18 holes, par 3 / 4 / 5, no weather, manual / calculated / no index, a plus handicap, a long name with a diacritic, the maximum count). One named `#Preview` per possibility, named after it ("Empty", "9 holes · 4 players"). |
| TS-VS-04 | **Appearance.** Each view also has a Dark preview of its main state (`.preferredColorScheme`), and a landscape preview where it supports landscape. |
| TS-VS-05 | **Preview data, not ad-hoc values.** Previews use the shared preview data in `Preview Content/` (DEBUG only): an in-memory `ModelContainer` and value fixtures built from the **same scenarios as the UI-test seeds** (TS-UI-02, TS-UI-08), plus the dependency container's preview configuration with mock services (weather, location, clock, haptics, iCloud, PDF). Previews never touch the network, the real store, CloudKit or the real clock, and use fixed data (no `random`), so they look the same every time. |
| TS-VS-06 | **Previews build.** Every preview compiles in CI as part of the Debug build, and a story's PR lists its previews. The previews are compared with the artboards in Light and Dark during review. |
| TS-VS-02 | *Optional:* snapshot tests (e.g. swift-snapshot-testing) for MaynardUI components. Adopting it needs a decision because it's a new dependency. |

## 4. CI gate
| ID | Requirement |
|----|-------------|
| TS-CI-01 | `scripts/build.sh test` runs the unit and UI tests on the iOS 26 simulator before every PR into `main`, on the developer's Mac. There's no hosted CI yet (Xcode Cloud or GitHub Actions); the script is written so CI can call it later. |
| TS-CI-02 | Code coverage is on for every test run. `scripts/coverage_gate.py` parses the `xccov` report and **fails the run (exit 2) if v2 coverage drops below 90 %**, or below 100 % for the pure-logic groups in `scripts/coverage.json`. The same run lints the String Catalog for missing and stale entries (exit 3). |
| TS-CI-03 | Coverage is reported in the PR description: `scripts/build.sh test` writes the table to `build/test-coverage.md`. |

## 5. Definition of Done (every story)
- [ ] All requirement IDs in the story's requirements file are implemented or have a ticket deferring them.
- [ ] Unit tests ≥ 90 % coverage for new and changed code (100 % for pure logic as noted).
- [ ] UI tests for the primary flows.
- [ ] All strings in the String Catalog.
- [ ] `#Preview`s for every new or changed view, one per state and data variation it can show, plus Dark, all built from the shared preview data (TS-VS-01, 03…05).
- [ ] Light and Dark appearance checked.
- [ ] Requirements doc updated if behavior changed.
