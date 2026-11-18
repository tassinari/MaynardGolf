//
//  MaynardUITestCase.swift
//  MaynardGolfUITests
//

import XCTest

/// The base for every UI test (testing-standards §2, #22). It launches the app on an in-memory store with
/// a seed and mocks and finds elements by accessibility identifier only (TS-UI-03). Accessibility itself
/// isn't tested (TS-UI-04).
@MainActor
class MaynardUITestCase: XCTestCase {
    /// The named data sets (`Fixture` in the app, DM-TS-01). Keep in step with `Fixture`, and add each new
    /// one to `HarnessUITests.testEverySeedLaunchesToItsData`.
    enum Seed: String {
        case freshInstall, onePlayer, twoPlayers, noRound, inProgress, twoInProgress, fullHistory
    }

    /// `-uiTestAppearance` values; typed so a typo doesn't compile (and silently test the default).
    enum Appearance: String, CaseIterable {
        case light, dark
    }

    /// The launch options UI tests use (`LaunchArguments` in the app documents them all).
    struct Options {
        var seed: Seed = .freshInstall
        /// Fixed so dates on screen never change between runs.
        var fixedDate: String? = "2026-06-01T15:00:00Z"
        var weather: String? = "success"
        var location: String?
        var appearance: Appearance?
        var route: String?
        var flags: [String] = []

        var arguments: [String] {
            var args = ["-uiTestSeed", seed.rawValue]
            if let fixedDate { args += ["-uiTestFixedDate", fixedDate] }
            if let weather { args += ["-uiTestMockWeather", weather] }
            if let location { args += ["-uiTestMockLocation", location] }
            if let appearance { args += ["-uiTestAppearance", appearance.rawValue] }
            if let route { args += ["-uiTestRoute", route] }
            return args + flags
        }
    }

    private(set) var app = XCUIApplication()
    /// How long to wait for an element before failing.
    let timeout: TimeInterval = 5

    override func setUp() async throws {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        app.terminate()
    }

    /// Launches with `options` (a fresh process every time).
    @discardableResult
    func launch(_ options: Options = Options()) -> XCUIApplication {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = options.arguments
        app.launch()
        return app
    }

    /// Launches with a seed and otherwise default options.
    @discardableResult
    func launch(seed: Seed, flags: [String] = []) -> XCUIApplication {
        launch(Options(seed: seed, flags: flags))
    }

    /// The first element with this identifier (a toolbar button and its label can share one).
    func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Every element whose identifier starts with `prefix` (rows named `home.players.row.{id}`), or equals
    /// it with `exact`. Buttons that read as one element hide their children, so each counts once.
    func elements(prefix: String, exact: Bool = false) -> XCUIElementQuery {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: exact ? "identifier == %@" : "identifier BEGINSWITH %@", prefix))
    }

    /// Waits until exactly `count` elements match `prefix` (see `elements(prefix:exact:)`).
    func waitForCount(_ prefix: String, _ count: Int, exact: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        let query = elements(prefix: prefix, exact: exact)
        let predicate = NSPredicate { _, _ in query.count == count }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(prefix): expected \(count), found \(query.count)", file: file, line: line)
    }

    /// Waits until Home shows `count` players: summary cards (1 or 2) or rows (3+, at most 4), or the
    /// empty state for 0 (01-home §1).
    func waitForHomePlayers(_ count: Int, file: StaticString = #filePath, line: UInt = #line) {
        if count == 0 {
            assertExists("home.empty.players", file: file, line: line)
        } else {
            waitForCount(count < 3 ? "home.players.card." : "home.players.row.", min(count, 4), file: file, line: line)
        }
    }

    /// Fails unless an element with this identifier appears within the timeout.
    func assertExists(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(id).waitForExistence(timeout: timeout), "\(id) didn't appear", file: file, line: line)
    }

    /// Fails if an element with this identifier is on screen after a short wait.
    func assertMissing(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(element(id).waitForExistence(timeout: 1), "\(id) shouldn't be shown", file: file, line: line)
    }

    /// Scrolls until the element with this identifier is on screen, without touching it, and returns it.
    /// Waits up to 1 s first (enough for sheet and push animations; a screen that loads slowly on purpose
    /// should `assertExists` first). If it's still missing, it's below the fold of a lazy list: swipe up
    /// slowly (fast swipes skip rows) and check again, up to 24 times. Then scroll on while it exists but
    /// isn't hittable.
    @discardableResult
    func reveal(_ id: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let target = element(id)
        if !target.waitForExistence(timeout: 1) {
            for _ in 0..<24 where !target.waitForExistence(timeout: 0.5) { app.swipeUp(velocity: .slow) }
        }
        for _ in 0..<4 where target.exists && !target.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(target.waitForExistence(timeout: 1), "\(id) didn't appear", file: file, line: line)
        return target
    }

    /// Taps the element with this identifier, scrolling to it first.
    func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        reveal(id, file: file, line: line).tap()
    }

    /// The text of a static text with this identifier.
    func text(_ id: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        let label = app.staticTexts[id]
        XCTAssertTrue(label.waitForExistence(timeout: timeout), "\(id) didn't appear", file: file, line: line)
        return label.label
    }

    /// Waits until the static text with this identifier reads `expected`.
    func waitForText(_ id: String, _ expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label == %@", expected)
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: app.staticTexts[id])],
                                    timeout: timeout)
        XCTAssertEqual(result, .completed, "\(id) never read \"\(expected)\"", file: file, line: line)
    }

    /// Whether the system is showing an alert (a permission prompt) over the app.
    func systemAlertIsShown(within seconds: TimeInterval = 2) -> Bool {
        XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.waitForExistence(timeout: seconds)
    }
}
