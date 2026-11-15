//
//  MaynardGolfUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// App shell UI tests (#14, #18, DM-SC-05, DM-MG-02, X-11, X-16): the data error screen, the router smoke
/// test, observation, save failures and permissions.
final class MaynardGolfUITests: MaynardUITestCase {
    func testTheCourseNameComesFromTheCourseData() {
        launch(seed: .freshInstall)
        XCTAssertTrue(app.navigationBars["Maynard Golf Club"].waitForExistence(timeout: timeout))
    }

    func testACorruptStoreShowsTheErrorScreenInsteadOfCrashing() throws {
        launch(seed: .freshInstall, flags: ["-uiTestCorruptStore"])
        assertExists("dataError")
        tap("dataError.retry")
        assertExists("dataError.retry") // still broken, still running
        try auditAccessibility(Options(flags: ["-uiTestCorruptStore"]), ready: "dataError.retry")
    }

    func testLeftoverDevelopmentDataOpensToAFreshInstall() {
        launch(seed: .freshInstall, flags: ["-uiTestLeftoverStore"])
        XCTAssertEqual(text("home.players"), "0 players")
    }

    func testEveryDestinationOpensAndCloses() {
        launch(seed: .inProgress)
        for id in ["settings", "allPlayers", "allRounds", "playerCard", "roundDetail", "holePlay", "scorecard"] {
            tap("home.link.\(id)")
            assertExists("screen.\(id)")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            assertExists("home.players")
        }
        for id in ["localRules", "newRound", "addPlayer"] {
            tap("home.link.\(id)")
            assertExists("screen.\(id)")
            tap("sheet.close")
            assertMissing("screen.\(id)")
        }
    }

    func testDeepLinkLaunchOpensTheScreen() {
        for (route, id) in [("settings", "settings"), ("localRules", "localRules"), ("scorecard", "scorecard")] {
            launch(Options(seed: .inProgress, route: route))
            assertExists("screen.\(id)")
        }
    }

    func testASaveUpdatesHomeWithoutRelaunching() {
        launch(seed: .onePlayer)
        XCTAssertEqual(text("home.players"), "1 player")
        tap("home.addSamplePlayer")
        waitForText("home.players", "2 players")
    }

    func testAFailedSaveShowsAnErrorAndKeepsRunning() {
        launch(seed: .onePlayer, flags: ["-uiTestFailPersistence"])
        tap("home.addSamplePlayer")
        assertExists("home.error")
        XCTAssertEqual(text("home.players"), "1 player")
    }

    func testHomePassesTheAuditInLightAndDark() throws {
        // The placeholder Home is a plain system List, whose buttons the audit reports as "Dynamic Type
        // partially unsupported". Home (#23) replaces it and gets the full audit, Dynamic Type included.
        try auditAccessibility(Options(seed: .inProgress), ready: "home.link.settings", excluding: .dynamicType)
    }

    func testNoPermissionPromptAtLaunch() {
        launch(seed: .inProgress)
        assertExists("home.link.settings")
        XCTAssertFalse(systemAlertIsShown())
    }
}
