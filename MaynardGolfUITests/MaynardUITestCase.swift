//
//  MaynardUITestCase.swift
//  MaynardGolfUITests
//

import XCTest

/// The base for every UI test (testing-standards §2, #22). It launches the app on an in-memory store with
/// a seed and mocks, finds elements by accessibility identifier only (TS-UI-03), and audits each screen
/// in Light and Dark (TS-UI-05).
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

    /// Dynamic Type sizes, as `UIContentSizeCategory` raw values.
    enum DynamicType: String {
        case large = "UICTContentSizeCategoryL"
        case xLarge = "UICTContentSizeCategoryXL"
        case xxLarge = "UICTContentSizeCategoryXXL"
        case xxxLarge = "UICTContentSizeCategoryXXXL"
        case ax1 = "UICTContentSizeCategoryAccessibilityM"
        case ax2 = "UICTContentSizeCategoryAccessibilityL"
        case ax3 = "UICTContentSizeCategoryAccessibilityXL"
        case ax4 = "UICTContentSizeCategoryAccessibilityXXL"
        case ax5 = "UICTContentSizeCategoryAccessibilityXXXL"
    }

    /// The launch options UI tests use (`LaunchArguments` in the app documents them all).
    struct Options {
        var seed: Seed = .freshInstall
        /// Fixed so dates on screen never change between runs.
        var fixedDate: String? = "2026-06-01T15:00:00Z"
        var weather: String? = "success"
        var location: String?
        var appearance: Appearance?
        /// Passed as iOS's own `-UIPreferredContentSizeCategoryName`, so SwiftUI and UIKit (alerts,
        /// navigation bars) both scale.
        var dynamicType: DynamicType?
        var route: String?
        var flags: [String] = []

        var arguments: [String] {
            var args = ["-uiTestSeed", seed.rawValue]
            if let fixedDate { args += ["-uiTestFixedDate", fixedDate] }
            if let weather { args += ["-uiTestMockWeather", weather] }
            if let location { args += ["-uiTestMockLocation", location] }
            if let appearance { args += ["-uiTestAppearance", appearance.rawValue] }
            if let dynamicType { args += ["-UIPreferredContentSizeCategoryName", dynamicType.rawValue] }
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

    /// Fails unless an element with this identifier appears within the timeout.
    func assertExists(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(id).waitForExistence(timeout: timeout), "\(id) didn't appear", file: file, line: line)
    }

    /// Fails if an element with this identifier is on screen after a short wait.
    func assertMissing(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(element(id).waitForExistence(timeout: 1), "\(id) shouldn't be shown", file: file, line: line)
    }

    /// Taps the element with this identifier, scrolling down to it first if a list hasn't loaded it yet.
    func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(id)
        // Wait up to 1 s for the element (enough for sheet and push animations; a screen that loads slowly
        // on purpose should `assertExists` first). If it's still missing, it's below the fold of a lazy
        // list: swipe up and check again, a second at a time, until the timeout. Then scroll on while it
        // exists but isn't hittable.
        let steps = max(Int(timeout) - 1, 1)
        if !target.waitForExistence(timeout: 1) {
            for _ in 0..<steps where !target.waitForExistence(timeout: 1) { app.swipeUp() }
        }
        for _ in 0..<steps where target.exists && !target.isHittable { app.swipeUp() }
        XCTAssertTrue(target.waitForExistence(timeout: 1), "\(id) didn't appear", file: file, line: line)
        target.tap()
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

    /// Relaunches with `options` in Light and audits, then relaunches in Dark and audits again (TS-UI-04).
    /// It audits what `options` opens at launch, not state reached by earlier taps; `ready` is an
    /// identifier on that screen to wait for.
    func auditAccessibility(_ options: Options, ready: String, excluding excluded: XCUIAccessibilityAuditType = [],
                            file: StaticString = #filePath, line: UInt = #line) throws {
        for appearance in Appearance.allCases {
            var themed = options
            themed.appearance = appearance
            launch(themed)
            assertExists(ready, file: file, line: line)
            try app.performAccessibilityAudit(for: XCUIAccessibilityAuditType.all.subtracting(excluded))
        }
    }

    /// Whether the system is showing an alert (a permission prompt) over the app.
    func systemAlertIsShown(within seconds: TimeInterval = 2) -> Bool {
        XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.waitForExistence(timeout: seconds)
    }
}
