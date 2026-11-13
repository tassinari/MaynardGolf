# Testing Standards (v2)

These standards apply to every v2 story. A story isn't done until its tests meet them.

## 1. Unit tests
| ID | Requirement |
|----|-------------|
| TS-UT-01 | Use **Swift Testing** (`import Testing`, `@Test`, `#expect`) for new tests. Existing XCTest tests may stay. |
| TS-UT-02 | **Line coverage ≥ 90 %** for every v2 module / file group: models, ViewModels, services, formatters and MaynardUI logic. Pure logic (formatters, scorecard model, score entry, stats) aims for **100 %**. |
| TS-UT-03 | SwiftData tests use an in-memory `ModelContainer` (as `DataTests` does) with one container per test for isolation. |
| TS-UT-04 | External dependencies (WeatherKit, GHIN, Location, Haptics, Clock, FileManager, UserDefaults) sit behind protocols and are injected. Tests use fakes, never the network. |
| TS-UT-05 | Every model change includes a **migration test** that opens a v1-shaped store and checks the data after migration. |
| TS-UT-06 | Use parameterized tests (`@Test(arguments:)`) for tables: score names, to-par formatting, mark styles, bucketing. |

## 2. UI tests
| ID | Requirement |
|----|-------------|
| TS-UI-01 | XCUITest covers each screen's primary flows and empty / error states. |
| TS-UI-02 | Launch arguments seed deterministic data: `-uiTestSeed {freshInstall|noRound|inProgress|fullHistory}`, `-uiTestMockGHIN`, `-uiTestMockWeather`, `-uiTestFixedDate 2026-11-11T09:42:00Z`. The app uses an in-memory store under UI tests. |
| TS-UI-03 | Elements are found by `accessibilityIdentifier` (listed in each requirements file), never by localized text. |
| TS-UI-04 | Every screen gets an accessibility audit: `XCUIApplication().performAccessibilityAudit()`. |
| TS-UI-05 | UI tests run on iPhone 16 (the default) and the smallest supported iPhone in CI. |

## 3. Visual checks
| ID | Requirement |
|----|-------------|
| TS-VS-01 | Every MaynardUI component and screen has `#Preview`s in default, large Dynamic Type and edge-case data. |
| TS-VS-02 | *Optional:* snapshot tests (e.g. swift-snapshot-testing) for MaynardUI components. Adopting it needs a decision because it's a new dependency. |

## 4. CI gate
| ID | Requirement |
|----|-------------|
| TS-CI-01 | Xcode Cloud (or GitHub Actions) runs unit and UI tests on every PR into `version-2`. |
| TS-CI-02 | Code coverage is enabled in the test plan. A script parses `xccov` output and **fails the build if v2 coverage drops below 90 %**. |
| TS-CI-03 | Coverage is reported in the PR description. |

## 5. Definition of Done (every story)
- [ ] All requirement IDs in the story's requirements file are implemented or have a ticket deferring them.
- [ ] Unit tests ≥ 90 % coverage for new and changed code (100 % for pure logic as noted).
- [ ] UI tests for the primary flows, with accessibility audits passing.
- [ ] All strings in the String Catalog.
- [ ] Previews for every new view.
- [ ] VoiceOver checked by hand. Dynamic Type at AX3 checked.
- [ ] Requirements doc updated if behavior changed.
