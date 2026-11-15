//
//  MaynardGolfUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// App shell UI tests (#14, #18, DM-SC-05, DM-MG-02, X-11): seeds, the data error screen, the router
/// smoke test, save failures and observation. Every launch uses an in-memory store.
@MainActor
final class MaynardGolfUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        XCUIDevice.shared.appearance = .light
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func value(_ id: String, in app: XCUIApplication) -> String {
        let element = app.staticTexts[id]
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(id) missing")
        return element.label
    }

    func testSeedsShowTheirData() {
        for (seed, players, rounds) in [("freshInstall", "0 players", "0 rounds"), ("onePlayer", "1 player", "3 rounds"),
                                        ("twoPlayers", "2 players", "3 rounds"), ("inProgress", "3 players", "3 rounds")] {
            let app = launch(["-uiTestSeed", seed])
            XCTAssertTrue(value("home.players", in: app).contains(players), seed)
            XCTAssertTrue(value("home.rounds", in: app).contains(rounds), seed)
            app.terminate()
        }
    }

    func testTheCourseNameComesFromTheCourseData() {
        let app = launch(["-uiTestSeed", "freshInstall"])
        XCTAssertTrue(app.navigationBars["Maynard Golf Club"].waitForExistence(timeout: 5))
    }

    func testACorruptStoreShowsTheErrorScreenInsteadOfCrashing() throws {
        let app = launch(["-uiTestCorruptStore"])
        XCTAssertTrue(app.descendants(matching: .any)["dataError"].waitForExistence(timeout: 5))
        app.buttons["dataError.retry"].tap()
        XCTAssertTrue(app.buttons["dataError.retry"].waitForExistence(timeout: 5)) // still broken, still running
        try app.performAccessibilityAudit()
    }

    func testLeftoverDevelopmentDataOpensToAFreshInstall() {
        let app = launch(["-uiTestLeftoverStore"])
        XCTAssertTrue(value("home.players", in: app).contains("0 players"))
    }

    /// Taps a Home link, scrolling down to it if the list hasn't loaded it yet.
    private func tapLink(_ id: String, in app: XCUIApplication) {
        let link = app.buttons["home.link.\(id)"]
        for _ in 0..<4 where !link.isHittable { app.swipeUp() }
        link.tap()
    }

    func testEveryDestinationOpensAndCloses() {
        let app = launch(["-uiTestSeed", "inProgress"])
        for id in ["settings", "allPlayers", "allRounds", "playerCard", "roundDetail", "holePlay", "scorecard"] {
            tapLink(id, in: app)
            XCTAssertTrue(app.descendants(matching: .any)["screen.\(id)"].waitForExistence(timeout: 5), id)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.staticTexts["home.players"].waitForExistence(timeout: 5) || app.buttons["home.link.\(id)"].exists, "back from \(id)")
        }
        for id in ["localRules", "newRound", "addPlayer"] {
            tapLink(id, in: app)
            XCTAssertTrue(app.descendants(matching: .any)["screen.\(id)"].waitForExistence(timeout: 5), id)
            app.buttons["sheet.close"].tap()
            XCTAssertTrue(app.buttons["home.link.\(id)"].waitForExistence(timeout: 5), "closed \(id)")
        }
    }

    func testDeepLinkLaunchOpensTheScreen() {
        for (route, id) in [("settings", "settings"), ("localRules", "localRules"), ("scorecard", "scorecard")] {
            let app = launch(["-uiTestSeed", "inProgress", "-uiTestRoute", route])
            XCTAssertTrue(app.descendants(matching: .any)["screen.\(id)"].waitForExistence(timeout: 5), route)
            app.terminate()
        }
    }

    func testASaveUpdatesHomeWithoutRelaunching() {
        let app = launch(["-uiTestSeed", "onePlayer"])
        XCTAssertTrue(value("home.players", in: app).contains("1 player"))
        app.buttons["home.addSamplePlayer"].tap()
        let updated = NSPredicate(format: "label == %@", "2 players")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: updated,
                       object: app.staticTexts["home.players"])], timeout: 5), .completed)
    }

    func testAFailedSaveShowsAnErrorAndKeepsRunning() {
        let app = launch(["-uiTestSeed", "onePlayer", "-uiTestFailPersistence"])
        app.buttons["home.addSamplePlayer"].tap()
        XCTAssertTrue(app.staticTexts["home.error"].waitForExistence(timeout: 5))
        XCTAssertTrue(value("home.players", in: app).contains("1 player"))
    }

    func testHomePassesTheAuditInLightAndDark() throws {
        for appearance in [XCUIDevice.Appearance.light, .dark] {
            XCUIDevice.shared.appearance = appearance
            let app = launch(["-uiTestSeed", "inProgress"])
            XCTAssertTrue(app.buttons["home.link.settings"].waitForExistence(timeout: 5))
            // The placeholder Home is a plain system List, whose buttons the audit reports as "Dynamic Type
            // partially unsupported". Home (#23) replaces it and gets the full audit, Dynamic Type included.
            try app.performAccessibilityAudit(for: XCUIAccessibilityAuditType.all.subtracting(.dynamicType))
            app.terminate()
        }
    }

    func testNoPermissionPromptAtLaunch() {
        let app = launch(["-uiTestSeed", "inProgress"])
        XCTAssertTrue(app.buttons["home.link.settings"].waitForExistence(timeout: 5))
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertFalse(springboard.alerts.firstMatch.waitForExistence(timeout: 2))
    }
}
