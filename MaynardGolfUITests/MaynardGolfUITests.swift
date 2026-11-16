//
//  MaynardGolfUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// App shell UI tests (#14, #18, DM-SC-05, DM-MG-02, X-11, X-16): the data error screen, the router smoke
/// test, observation, save failures and permissions.
final class MaynardGolfUITests: MaynardUITestCase {
    /// X-16: the round rows name the course from the course data.
    func testTheCourseNameComesFromTheCourseData() {
        launch(seed: .onePlayer)
        waitForCount("home.rounds.row.", 3)
        let row = reveal(elements(prefix: "home.rounds.row.").firstMatch.identifier)
        XCTAssertTrue(row.label.contains("Maynard Golf Club"), row.label)
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
        waitForHomePlayers(0)
    }

    /// #18 smoke test through Home's own controls: every pushed screen opens and comes back, and the
    /// sheets open and close. Local rules and the Scorecard aren't on Home; the deep-link test opens them.
    func testEveryDestinationOpensAndCloses() {
        launch(seed: .inProgress)
        waitForHomePlayers(3)
        waitForCount("home.rounds.row.", 2)
        let pushes: [(control: String, screen: String)] = [
            ("home.settings", "settings"), ("home.players.allPlayers", "allPlayers"), ("home.rounds.seeAll", "allRounds"),
            (elements(prefix: "home.players.row.").firstMatch.identifier, "playerCard"),
            (elements(prefix: "home.rounds.row.").firstMatch.identifier, "roundDetail"),
            ("home.inProgressCard", "holePlay"),
        ]
        for (control, screen) in pushes {
            tap(control)
            assertExists("screen.\(screen)")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            assertExists("home.settings")
        }
        tap("home.newRound")
        assertExists("newRound.teeOff")
        tap("newRound.cancel")
        assertMissing("newRound.teeOff")
    }

    func testDeepLinkLaunchOpensTheScreen() {
        for (route, id) in [("settings", "settings"), ("localRules", "localRules"), ("scorecard", "scorecard")] {
            launch(Options(seed: .inProgress, route: route))
            assertExists("screen.\(id)")
        }
    }

    /// HOME-VM-02, HOME-P1-03: a save redraws Home through the change stream, no relaunch.
    func testASaveUpdatesHomeWithoutRelaunching() {
        launch(seed: .onePlayer)
        waitForHomePlayers(1)
        tap("home.players.addPlayer")
        tap("addPlayer.firstName")
        app.typeText("Rory")
        tap("addPlayer.create")
        waitForHomePlayers(2)
    }

    /// X-11, HOME-IPR-08: a failed delete shows an alert and the card stays.
    func testAFailedSaveShowsAnErrorAndKeepsRunning() {
        launch(seed: .inProgress, flags: ["-uiTestFailPersistence"])
        element("home.inProgressCard").press(forDuration: 1)
        tap("home.inProgressCard.discard")
        tap("home.discard.confirm")
        tap("home.discardError.ok")
        assertExists("home.inProgressCard")
    }

    func testNoPermissionPromptAtLaunch() {
        launch(seed: .inProgress)
        assertExists("home.settings")
        XCTAssertFalse(systemAlertIsShown())
    }
}
