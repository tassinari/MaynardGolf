# CLAUDE.md

Guidance for Claude Code (and people) working in this repository. Every non-obvious rule
says **why**, and names the issue or PR that produced it where there is one. Keep the
reason when you edit a rule: a rule without one gets "simplified" away.

## Project at a glance

Maynard Golf is an iPhone scorekeeping app for Maynard Golf Club. It is being rebuilt
("v2", the project name). It has **never been released**; v2 ships as **version 1.2**, its
first App Store release (docs/README.md X-18).

- **Source of truth for v2:** `docs/requirements/` (one file per screen or system, every
  requirement has an ID) and `docs/README.md` (index + cross-cutting rules X-01…X-21).
- **Design:** the canvas at https://claude.ai/artifact/S7TQE9RtU8K2aRWSNeDvz3. Artboards
  win over prose when they disagree, unless a requirement says otherwise in italics. The app
  uses the **Fairway C** design system: pages "Design system C" (tokens, type, components) and
  "iPhone C" (every screen). The older pages ("Design system", "iPhone", "B") have the same
  layouts in earlier colors; take layout from any of them, color and type only from C.
- **Work items:** GitHub issues in `tassinari/MaynardGolf`, project "v2" (#4). Each
  `[Story]` issue has sub-issues, acceptance criteria, UI tests and a requirements
  coverage table. Implement a story's sub-issues; cite requirement IDs in PRs.
- **Data model diagram:** `docs/data-model.drawio`.

## Build & Test

**Use `scripts/build.sh`** (details in `scripts/README.md`). It picks an iPhone 18 Pro simulator on
the newest iOS 27 runtime (the app targets iOS 26, X-12), boots it, and keeps logs and result bundles under `build/`.

```bash
scripts/build.sh test        # before every PR: unit + UI tests, coverage gate, String Catalog lint
scripts/build.sh test-unit   # the usual inner loop (coverage printed, not gated)
scripts/build.sh test-ui     # UI tests only (slow; when the change touches UI or flows)
scripts/build.sh lint        # String Catalog lint only
scripts/build.sh release     # TestFlight upload (--dry-run first); key setup in scripts/README.md
```

Exit codes: 0 pass, 1 test failure, 2 coverage below the gate, 3 lint failure, 4 release
failure. The App Store Connect key (`.p8`) and its IDs live in `~/.appstoreconnect/`, never in
the repo. Paste
`build/test-coverage.md` into the PR body (TS-CI-03). For a single suite, call `xcodebuild`
directly with the simulator `scripts/simulator.py` prints:

```bash
xcodebuild test -scheme MaynardGolf -destination "id=$(python3 scripts/simulator.py)" \
  -only-testing:MaynardGolfTests/AppShellTests
```

To try GPS features without the course, run from Xcode and pick a spot (Hole 3 Tee, Hole 3 Walk…) from the
debug bar's Simulate Location arrow; `Simulation/README.md` has the details. Any other coordinate: the Simulator's
Features › Location › Custom Location….

The deployment target lives in `Config/Shared.xcconfig`. New pure-logic folders get a 100 %
group in `scripts/coverage.json` in the story that creates them.

### Testing rules (docs/requirements/testing-standards.md)
- **Swift Testing** (`@Test`, `#expect`) for new tests; parameterized tests for tables.
- **≥ 90 % line coverage** for v2 code, **100 %** for pure logic (formatters, scorecard
  model, score entry, handicap calculator). Report coverage per target, never one blended
  number: view code drowns the signal.
- New or changed models always get unit tests, with an in-memory `ModelContainer`, one per
  test.
- UI tests subclass `MaynardUITestCase`, find elements by `accessibilityIdentifier` (never
  localized text) and launch with a seed and mocks (`Options`).
- **No accessibility testing.** Don't add accessibility audits, Dynamic Type or VoiceOver
  tests, and don't report missing ones in reviews. `accessibilityIdentifier` stays: it's how
  UI tests find elements, not an accessibility check.
- **UI tests run on iPhone 18 Pro only** (the `build.sh` default). Don't run them on every device;
  add `--devices "iPhone 17e,iPhone 18 Pro Max"` only when a change affects layout across sizes.
- **UI tests run in parallel** on 3 clones of the simulator (`--workers N`; `--workers 1` for one at
  a time when debugging). Every UI test must stand alone: its own `launch` and seed, nothing left
  for the next test. *Why: run serially they took 30 minutes, 32 s a test.*
- **UI tests check what only a running app can show**: navigation, sheets, gestures and wiring. A
  rule a view model or pure type decides (validation, limits, defaults, formatting) is unit-tested
  there and not repeated through the UI. Open a screen directly (`-uiTestRoute`,
  `-uiTestCatalogSection`) instead of scrolling or tapping your way to it.
- **Never claim green without the counts.** Quote passed / failed numbers.
- **Flakes:** re-run the failing suite alone before calling it a regression. Hundreds of
  failures across every suite point at the environment (simulator, a concurrent run), not
  the code. Run test suites one at a time.
- **XCUITest lists accessibility-hidden elements** (iOS 27 simulator), and `opacity(0)` or `clipShape` don't remove
  them or shrink a container's frame. A view kept alive while off screen (the score board's pages, #209) sets its
  identifier only while shown, and a tap target's identifier goes on the visible part, not a container that also
  holds hidden content. *Why: `assertMissing` passed and a tap missed the card until this was done.*
- **Distrust tests that pass vacuously** (file not in the target, asserting only that a
  call happened). See a new assertion fail once before trusting it.

## Architecture: MVVM with composition and dependency injection

This is the required architecture for all v2 code.

- **MVVM.** Views are SwiftUI and hold no business logic. Each screen has an `@Observable`
  ViewModel (never `ObservableObject`) that turns model data into display values. Logic
  that can be pure (scorecard model, score entry, handicap, round summaries, PDF model)
  lives in plain value types the ViewModel calls, so it's tested without UI.
- **Composition over inheritance.** Build screens from small views and MaynardUI
  components; build behavior from small types passed in. No base-class ViewModels, no
  subclassing for reuse.
- **Dependency injection.** Every dependency (repositories, `CourseProvider`,
  `HandicapManager`, weather, location, haptics, clock, iCloud, file system, settings) is a
  protocol passed in through `init`, defaulting to the live implementation. One dependency
  container builds the live graph at app start; tests and previews build theirs with fakes.
  No singletons reached from inside a type, no `Date()` or `UserDefaults.standard` in logic.
  *Why: everything must be testable with fakes and previewable with fixed data
  (TS-UT-04, TS-VS-05).*
- **Data:** SwiftData (`MaynardSchemaV1`), synced through the user's private CloudKit
  database. Views get value snapshots, not live `@Model` objects, wherever work happens
  off the main actor (12-data-model DM-SC-07).
- **Updates through observation.** Screens update by observing ViewModels and managers.
  Don't add `NotificationCenter` refreshes; v1's `refreshListener` / `didImport` go away.
- **Error boundaries.** Persistence and service failures are caught at the ViewModel or
  manager, shown with a way to retry, and never swallowed in an empty `catch`.
- **UI library.** Screens use only the `MaynardUI` framework's components and tokens: colors
  as `Color.ds.<role>` (semantic tokens only), type as `.dsFont(.title)`, materials as
  `.dsGlass()` / `.dsScrim()`. No hex or RGB literals and no palette colors: the palette
  (`DSPaletteColor`) is internal to MaynardUI, and `scripts/hex_lint.py` fails on it outside
  `MaynardUI/Tokens/` and `Catalog/` (DS-CL-04). A color with a new purpose gets a new role in
  `ColorTokens.swift` with Light and Dark values; never reach for a raw color, which also breaks
  Dark mode. *Why: changing the look to Fairway C touched ~100 call sites that used palette colors
  directly.* The DEBUG catalog (`-uiTestCatalog`) shows every token and component.
- **Device-agnostic layouts.** iPhone only for 1.2, but no hard-coded screen sizes or
  device checks (X-19).
- Explain **why** before introducing a new protocol, abstraction or pattern.
- Use the `swiftui-pro` skill for any SwiftUI work.

### Where things live (Foundation, #14)
- `MaynardGolf/LaunchScreen.storyboard` and `Assets.xcassets/LaunchArtwork.imageset`: the approved golf-ball/M launch
  artwork (DS-BR-03), aspect-fill to the full screen. `Config/App.xcconfig` selects the storyboard; never add a timed
  in-app splash view.
- `MaynardGolf/App/`: `AppModel` (launch: leftover cleanup, store, error state), `OrientationController` and
  `AppDelegate` (portrait everywhere but the Scorecard, SC-BH-05), `AppDependencies`
  (the container; `.make(container:arguments:)` live or UI-test mocks, `.preview(_:)` for
  previews), `Router` (typed `Destination` stack + `SheetRoute`), `LaunchArguments` (the
  `-uiTest…` options, documented on the type), `RootView`, `Plurals`. Screens read
  `@Environment(\.dependencies)` and `@Environment(Router.self)` to build their view models;
  previews use `.previewDependencies(.fixture)`.
  Router sheets (Add / Edit player, Local rules) are presented by the screen on top of the stack (`RootView`'s
  `routerSheets(depth:)`, matched by stack depth); only the full-screen covers are presented from the root, and
  every `Router` pop (`pop`, `popToRoot`, `close`) takes the popped screen's sheet with it. Never move a sheet back onto the root `NavigationStack`: shown
  over a pushed screen, it left Home's glass buttons undrawn after Back (#240, like the share sheet in #228).
- `MaynardGolf/Data/`: models, persistence, change tracking (12-data-model).
- `MaynardGolf/Repositories/`: `PlayerRepository` / `RoundRepository` / `OutsideScoreRepository` protocols and their
  SwiftData implementations. Only repositories touch `ModelContext`. Outside courses and scores (#252) are
  `OutsideCourse` / `OutsideScore` in `Data/Models/`, with their rules in `Data/Values/OutsideScoreRules.swift`; a score
  copies its course's name, rating and slope when it's saved, so its differential never changes.
- `MaynardGolf/Course/`: `Course`, `CourseProvider`, `RoundHoleBuilder` (read-only course data).
- `MaynardGolf/CourseImagery/`: the course map's hole and transition crops and `CourseImagery.json`,
  generated by `tools/cut-course-map.py` from the course master; its README says how to regenerate them.
- `tools/frame-hole-cameras.py`: frames the hole cameras so tee boxes, approach shots and pins clear the controls
  (HM-CAM-02, #186); then re-cut with `cut-course-map.py`. The course master isn't in the repository.
- `Simulation/`: GPX files for Xcode's Simulate Location menu, one per hole tee, green and tee-to-green walk, plus
  the course coordinate (#245). Generated from `MaynardGC.json` by `tools/make-gpx.py`; never edit them by hand. They're
  in the project's Simulation group but in no target, so they never ship. `selftest` fails when they're stale.
- `MaynardGolf/CourseMap/`: the hole map (16-hole-map): `ScreenCamera` and its blend, the manifest types,
  `BundleCourseImageryLoader`, `CourseImageryStore` (the pieces next to the current hole) and `MapSwipe`.
  `CourseOverview` is the Course map (#227): turned by the manifest's `overviewRotationDegrees` and cropped to fill a
  portrait screen (no ground past the master shows), badges in the fairways kept clear of its controls. While it's browsed (`HolePlayViewModel.isBrowsingOverview`)
  Hole play shows only the map, badges, Exit and Show my location (`CourseOverviewChrome`); an Out of order flight
  through it isn't browsing. Open it inside the same `withAnimation` as `overviewProgress`: opened just before, the map
  jumped with no zoom (#227).
- `MaynardGolf/Services/`: `AppClock`, `WeatherProviding`, `LocationProviding`,
  `HapticsProviding`, each with a live and a mock implementation.
- `MaynardGolf/Handicap/`: `HandicapCalculator` (pure WHS, #86; outside scores count too and `breakdown` lists the
  rounds behind an index, #253) and `HandicapManager` (every player's current index and breakdown, the only source
  screens read; on `AppDependencies.handicaps`, started by `AppNavigation`, #126). The Handicap screen
  (`HandicapView`, pure `HandicapExplanation`), Add score and Add course (`OutsideScoreForms`) are here too
  (19-handicap-screen, #253), pushed from the Player card's profile card or Handicap History card.
- `MaynardGolf/Home/`: `HomeViewModel` (round state, players layout, recent rounds) and the pure
  `RoundSummaryBuilder` / `PlayerSummaryBuilder` shared with All rounds and the Player card (#28).
  `HomeNavigationBar` (#212) pins Settings and New round over the hero photo; scroll geometry switches the
  large hero title / full action label to the bar title / plus icon, using `DSBarBackground.systemMaterial` (Apple’s untinted ultra-thin material, #232).
  The hero draws the photo once and extends it upward during overscroll; never add a separate pinned crop
  behind the bar, which exposes a seam when pulling down (#212).
- `MaynardGolf/Players/`: the Add / Edit player form (`PlayerFormView`, `PlayerFormViewModel`, #42) and its
  photo flow in `Photo/` (`PlayerPhotoModel`, Move and Scale's `PhotoCropModel` / `PhotoCropView`,
  `PhotoEncoder`, and the injected `PhotoLoading` on `AppDependencies.photos`; `-uiTestMockPhoto` mocks it).
- `MaynardGolf/RoundPDF/`: the round PDF (15-round-pdf, #109). `RoundPDFModel` / `RoundPDFModelBuilder` (pure, 100 %)
  turn a round snapshot into the page's header, columns and rows, with totals from `ScorecardModel` (#110).
  `RoundPDFPage` draws it (print style: fixed light primitives and `PrintScoreMark`) and `LiveRoundPDFRenderer` turns
  it into one vector 792 × 306 pt page (#78). Reference images for the fidelity tests are in
  `MaynardGolfTests/Fixtures/PDF/` (test-target resources, read from the bundle so CI can run them). After an intended
  change the test fails and attaches the new page (`<name>-actual.png` in the result bundle): compare it with the
  artboard, copy it over the reference and commit it. A new reference (not yet a resource) is written to that folder
  by the test; add it to `MaynardGolfTests`' resources (RP-TS-06).
  `RoundPDFExporter` (on `AppDependencies.pdf`) writes the PDF to `{tmp}/RoundPDF/{UUID}/` for Round detail's Share and
  removes it when the share ends (`ShareSheetCompletion`); launch clears leftovers. UIKit presents the share sheet
  (`ShareSheetPresenter`); never wrap `UIActivityViewController` in a SwiftUI `.sheet`, which broke Home's glass after Back (#228). `-uiTestMockPDF fail|slow` fakes a failure or a slow PDF (#111, #79).
- `MaynardGolf/AllRounds/`: All rounds (#84): `AllRoundsViewModel` reads every page, searches full player names
  and course names, and reuses `RoundMonthGrouping` / `RoundSummaryBuilder`. Native grouped list sections
  keep rows lazy and support per-round swipe deletion. Load failures retain data; duplicate ids resolve through the same oldest-copy lookup as navigation.
  Normal round deletion marks every copy with `deletedAt` and retains scores (#224). Deleted rounds is a separate
  scope of AllRoundsViewModel/View, reached from the history bar; only its confirmed swipe/delete-all actions
  permanently purge trashed records/cards. Active reads, recency, stats and handicaps exclude Trash. Orphaned
  rounds after player deletion also move to Trash; trashed unfinished rounds do not block deleting a player.
  Trash’s blue Restore swipe action clears `deletedAt` for all copies atomically, preserving scores and progress (#239).
  Validate every copy before restoring; empty playerless orphans stay in Trash. Failed restores retain rows and offer retry.
  Home keeps “See all” available while Trash is nonempty, so deleting the final active round cannot strand it.
  Home’s confirmed discard wraps its synchronous save/refresh in SwiftUI’s default animation, so the card
  removal and surrounding layout animate together, including the final card (#233).
  Failed moves/purges retain all data. Empty/unrelated changes skip
  history reloads; rows receive cached image values instead of photo closures.
- `MaynardGolf/AllPlayers/`: All players (#80): `AllPlayersViewModel` (pure filter / sort / count, 100 %) and
  `AllPlayersView` (search with MaynardUI's `DSSearchField`, swipe-to-delete).
- `MaynardGolf/PlayerCard/`: the Player card (09-player-card, #69). `PlayerCardStats` (pure, 100 %: completed rounds,
  the 9 / 18 default, Avg / Best; Home's `PlayerSummaryBuilder.stats` uses it too), `LatestScores` (pure, 100 %: the last 10
  scores per hole count, Maynard rounds and outside scores merged by date, #251), `ScoresByHole` (pure, 100 %: each hole 1–9's average and score bins from completed rounds of both lengths, #270), `HandicapTrend` (pure, 100 %: Home's chart values plus gridlines, over `HandicapManager.series`) and
  `PlayerCardViewModel`, with the views `PlayerCardView`, `PlayerProfileHeader` (profile card with the index; a tap
  anywhere opens Handicap), `LatestScoresCard` (with the All-time best / Average tiles), `ScoresByHoleCard`, `HandicapTrendCard`
  (Handicap History: always shown, a hint without a chart, a tap opens Handicap) and `PlayerCardRoundsSection` (Previous rounds: month groups of the
  shared `RoundRow`, from `Home/RoundMonthSection.swift`'s `RoundMonthGrouping`, which All rounds reuses). Edit's Delete and a vanished player
  close the card with `Router.close(.playerCard(id))`, back to the screen it came from. The pinned bar is MaynardUI's `dsNavigationBar`
  with a leading title and a `.scrollEdge` background.
- `MaynardGolf/ShotLines/`: the shot lines' pure logic (14-shot-lines, #108, 100 %): `ShotProjection` (GPS ↔ screen
  through the hole camera at rest), `YardageCalculator` (haversine yards, leg rules, from the player's position),
  `ShotTargets` (the draggable targets and pin of the hole shown, kept on `HolePlayViewModel.shot`; a par 3 has no
  target, its pin is the target), `ShotRoute` (the line with GPS: from the player once past the tee, without targets
  within 50 yd, never on a par 3 or off the hole; recomputed per fix, #185), `ShotLayout`
  (playable area, panel position) and `ShotOverlayVisibility`. The view is `HolePlay/ShotLineOverlay.swift`.
- `MaynardGolf/HolePlay/`: Hole play. Exit / Done and the hole card share the top row; the symbol-only Card,
  Course map and Show my location buttons form the row beneath the hole card (#218, HP-TOP-02, HP-HOLE-01, HP-CTL-01).
  `FlippingHoleInfoCard` follows the map’s interpolated progress with a top-to-bottom turn about its horizontal center
  (#238); its face switches only while edge-on, including during release/cancel animations. Never restore the old
  halfway `.id` / slide transition. Keep its perspective at zero so the turn cannot distort horizontal positions.
  The bottom card (`Leaderboard.swift`) has a layout per player count from the pure
  `LeaderboardLayout` (100 %), which also decides what a tap opens and what follows a save. Score entry is no system sheet: the
  card and the panel it grows into are one `ScoreBoard` (#184, #209): five states from the pure `ScoreBoardState` (100 %, the phase is
  `HolePlayViewModel.board`), all pages kept in the view (`LeaderboardPage`, and `ScoreBoardPages.swift`'s Players and Enter score) and sized by
  the page shown, with only 1–2 player avatars drawn over them and moved to their spots (`AvatarSpotView`). With 3–4 players,
  each page draws its own name and avatar; never match or morph these identities between Players and Enter score.
  With 2 players, every saved score returns to the leaderboard; never open the other player’s entry automatically
  (#225, HP-ES-07). Auto-advance still waits for all players to score. Show my location (`toggleLocation()` / `playerPosition` over the injected
  `LocationProviding`, #57) and edit mode for completed rounds (`mode: .edit`, `Destination.editRound`, #87) live in
  `HolePlayViewModel`. The Out of order button goes back to the lowest earlier hole
  missing a score; the pure `MissedHoles` (100 %) decides that and where auto-advance goes, and `MapMotion.jump` flies there (#192).
- `MaynardGolf/Marquee/`: `MarqueeSelection` (pure conflict resolution and picker order), `MarqueePlayerViewModel`
  (selection, observed snapshots, error / retry) and its picker screen / content. `PlayerRepository.setMarquee` owns
  atomic writes; `normalizeMarquee` runs after history passes. `marquee` / `twoPlayersMarquee` are the selected seeds;
  the original seeds keep None. `-uiTestFailMarqueeOnce` makes the first selection fail and Retry succeed.
- `MaynardGolf/Settings/`: `SettingsStore` (observable, over injected `UserDefaults` or in-memory
  storage; on `AppDependencies.settings`), `SettingsViewModel` (#30; the version and device come from
  `AppDependencies.about`, an `AboutInfo`) and `SettingsView` (#29). Outside links and the support address are in `App/AppLinks.swift`
  (SET-AB-07); web links open in the in-app browser through `OpenURLAction.inAppBrowser`. The Local rules
  sheet is `LocalRules/LocalRulesView.swift` (#34). UI tests and previews get
  in-memory defaults.
- **SwiftData gotchas** (both bit us): a `ModelContext` doesn't keep its container alive (keep
  the container), and `rollback()` leaves models in memory showing discarded values until the
  next fetch (use `ModelContext.discardChanges()`). Rolling back a delete that relied on a
  cascade rule crashes SwiftData, so `ModelDeletion` deletes child records explicitly.
- Temporary placeholders (`DestinationPlaceholderView`, `SheetPlaceholderView` in
  `App/PlaceholderViews.swift`) stand in for screens until their stories replace them. Home is real
  (`MaynardGolf/Home/`, #23); UI tests reach screens Home doesn't link to with `-uiTestRoute`.

### Previews
Every SwiftUI view has `#Preview`s for **every state and data variation** it can show,
plus Dark, built from the shared preview data in `Preview Content/`,
which mirrors the UI-test seeds. Previews never touch the network, the real store or the
clock (TS-VS-01, 03…06, X-20).

### v1 leftovers
The v1 Swift code is gone from `main`. What's left of v1 is non-code: image assets in
`Assets.xcassets` (the v1 hole images are gone, replaced by the crops in `MaynardGolf/CourseImagery/`)
and the course data file `MaynardGC.json`,
which v2's course data reuses until its story replaces it. #122 removes the remaining assets.
Don't reintroduce v1 patterns (`NavDestinations`, `NotificationCenter` refreshes, ZIPFoundation).

## Localization
Every user-facing string goes in the String Catalog (`Localizable.xcstrings`, #19) and is
referenced with `String(localized:)` or a `LocalizedStringKey`. Plans, implementations and
PR descriptions **list every new or changed user-facing string** so it can be translated.

## Workflow

### Lifecycle of a change
```
issue ──► fresh base ──► feature branch ──► plan (if non-trivial)
      ──► implement + tests ──► run tests ──► atomic conventional commits
      ──► push ──► PR ──► swift-review posts a PR comment ──► stop: the user decides fixes and merge
```

1. **Start from a fresh base.** v2 work branches from and merges into **`main`**
   (`git checkout main && git pull`). *Why: v2 became `main` on 2026-11-24; the v1 line is
   frozen on the `v1` branch (tag `v1-final`). Don't branch from or merge into `v1`.*
2. **Always a new branch,** named by type and issue: `feat/56-hole-number-card`,
   `fix/63-score-save-race`, `docs/…`. Never commit to `main` or `v1` directly.
3. **Plan before anything non-trivial,** and say why a new pattern is needed.
4. **Implement with tests,** then run them (see Build & Test) before committing.
5. **Commit atomically** with conventional commits (`feat:`, `fix:`, `docs:`,
   `refactor:`, `test:`, `chore:`), one logical change each, with a message that explains
   why.
6. **Open a PR into `main`** when done. The body covers: what changed and why, the
   linked issue (`Closes #n`), the requirement IDs implemented, test results with counts
   and the coverage table from `build/test-coverage.md`, the previews added, the
   documentation added or updated, and **every new or changed user-facing string**.
7. **Review every PR once with the `swift-review` skill** (below), then **stop**. The user reads the review
   and decides what's fixed, whether it's re-reviewed and when it merges. *Why: cost; an unattended
   fix → re-review → merge loop across several stories burned credits fast (2026-11-18).*
8. Before pushing a follow-up, check the PR is still open (`gh pr view <n>`). If it merged,
   start a new branch and PR.
9. **Keep the project board current** (below) when work starts and when its PR merges.

### Project board (v2, #4)
Statuses are Backlog, Open, In Progress and Done. Move items yourself:
- **In Progress** when development starts: the issue's branch is created or a PR is open.
- **Done** when its PR has merged into `main`. Move the story's sub-issues that the
  PR delivered too.

*Why: `Closes #n` closes the issue when the PR merges into `main` (the default branch), but the
board's status field doesn't follow unless the project's "Item closed" workflow sets it, and
sub-issues the PR delivered aren't named in `Closes`.*

```sh
gh project item-list 4 --owner tassinari --limit 200 --format json   # item ids + status
gh project item-edit --project-id PVT_kwHOACJw584Brdr- --id <item id> \
  --field-id PVTSSF_lAHOACJw584Brdr-zhpwT7M \
  --single-select-option-id 47fc9ee4   # In Progress; Done is 98236657
```

### Definition of done: documentation is part of the work
**A feature without documentation, or with documentation that no longer matches the code,
is not done** (docs/README.md X-21). Every story and task lists this as an acceptance
criterion, and a PR isn't ready to merge until it's met. Documentation means:
- **Requirements:** the rows in `docs/requirements/` describe what was actually built.
  Behavior that changed during implementation is changed in the rows (not added as a note)
  in the same PR, along with the story's acceptance criteria.
- **Code:** every new type, and every method or property whose purpose isn't obvious from
  its name, has a `///` doc comment saying what it's for and, where it matters, why. Cite
  the requirement IDs it implements.
- **Diagrams and data:** `docs/data-model.drawio` changes with the models; generated or
  bundled data (for example `CourseImagery.json`) says what produces it.
- **How to work on it:** any new or changed script, tool, build step, test command or
  asset pipeline is documented where people look for it (`--help`, a README next to it,
  and this file when it changes the workflow).
- The PR body names the documentation that was added or updated.

*Why: the requirements docs are the source of truth for v2, and they're only useful if
they match the code; undocumented behavior gets "fixed" back by the next change.*

### Reviews
- **Every PR gets a `swift-review` review, posted as a PR comment**, including an explicit
  pass comment when nothing is wrong. A review that never left the terminal counts as not
  done. Review one PR at a time.
- `swift-review` reads this file first, so a documented decision here isn't a finding.
- Use the built-in `/code-review` on local work before a PR exists.
- Findings are reported, not fixed, unless the user asks for fixes. No re-review unless the user asks.
- **One story at a time, started by the user.** Don't chain stories or pick the next one.

After opening a PR, run its review in the background so the session isn't blocked:

```sh
tmux new-session -d -s "review-$(date +%H%M%S)" -c /Users/tassinari/Developer/MaynardGolf \
  'for pr in {PR NUMBERS}; do echo "=== PR #$pr $(date)" >> /tmp/maynardgolf-review.log; \
   claude -p "/swift-review $pr" \
     --allowedTools "Bash(gh pr view:*)" "Bash(gh pr diff:*)" "Bash(gh pr comment:*)" \
       "Bash(git log:*)" "Bash(git diff:*)" "Bash(git show:*)" "Bash(diff:*)" "Bash(cat:*)" \
       Read Grep Glob Skill \
     >> /tmp/maynardgolf-review.log 2>&1; done'
```

### Git safety
- **Stage files explicitly** (`git add <path>`), then commit. Never `git add -A`,
  `git add docs/` or `git commit -- <dir>`. *Why: the working tree often holds the user's
  own uncommitted edits (`PreviewData.swift`, `MaynardGolf/Specs/`, `xcodecloud/`), and
  staging a whole folder once swept the user's requirement edits into a docs commit
  (PR #83).*
- **Check the branch in the same command as the commit** (`git branch --show-current &&
  git commit …`); Xcode or another session can switch the checkout.
- **Stacked PRs:** check `baseRefName` before merging; one merged right after its base can
  land in a dead branch.
- **Look before you delete or overwrite,** and confirm anything hard to undo or visible to
  others.
- **Build settings go in config files** (xcconfig), not Xcode's UI, which writes inline
  overrides that drift.
- Running `gh` from outside the repo needs `GH_REPO=tassinari/MaynardGolf`.

## Requirements docs conventions
- Each requirement is a table row with an ID (`HOME-RR-03`). Change the row, don't append
  a contradicting note.
- **No "Resolved questions" sections.** When a question is answered, fold the answer into
  the requirement rows and delete the question.
- When behavior changes during implementation, update the requirements file and the
  story's acceptance criteria in the same PR.

## Product hazards
Decisions that look like gaps but aren't. Don't "fix" them.
- **No data migration.** Every install starts with a fresh store (`MaynardGolf.store`);
  leftovers from development builds are deleted. Migration tests start only after 1.2
  ships (X-18, TS-UT-05).
- **No "me" concept.** No "This is me", no "You" labels, no per-user perspective. The planned Marquee Player (#197) is only a Home display preference: one `Player.isMarquee` flag (or None), selected through Settings; it never changes round order. Requirements: HOME-MQ, SET-MQ, DM-PL-11…14. It syncs as player data, not UserDefaults.
- **Portrait scorecards keep four player slots** (#204, SC-PT-01, RD-SC-01). Actual players fill from the
  left; unused slots are blank. Three semantic divider lines separate them. `ScorecardModel.columns`
  and score arrays stay real-player-only; `playerSlots` is display padding, so PDF / landscape data stays unchanged.
- **No winner.** No "won", trophy, ranking or winner logic anywhere; players stay in round
  order. The one exception: a round row with two or more players highlights the chip with the
  round's lowest gross (every tie), as the Fairway C round rows draw it (DS-CH-08, #275). Don't add other ranking cues.
- **Course name comes from data.** "Maynard Golf Club" is read from `Course.name`, never a
  literal in a view. The app name on the Home hero stays "Maynard Golf" (X-16).
- **Handicap only from `HandicapManager`.** Screens never calculate an index. The calculated
  index wins from a player's third usable round; before that the **starting index** (`Player.handicapIndex`,
  typed in Add / Edit player) stands in and seeds those rounds, and Edit player hides the field once there's a
  calculated index (#268). *Why: a typed index that always won hid every new score.* 9-hole rounds use an
  expected score for the unplayed nine (18-handicap, #125).
- **Weather attribution appears only in Settings › About** (SET-AB-09).
- **Permissions** are asked only when the user taps the feature that needs them, with
  localized usage descriptions (X-17, #124).
