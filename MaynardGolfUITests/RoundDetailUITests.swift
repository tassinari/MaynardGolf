//
//  RoundDetailUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 10-round-detail (#75): opened from Home's Recent rounds.
final class RoundDetailUITests: MaynardUITestCase {
    /// RD-HDR, RD-PL-01…03, RD-SC-01, RD-TOP-01: header, a result per player with no winner, the scorecard
    /// and its totals; Back returns Home.
    func testFromHome() {
        launch(seed: .twoPlayers)
        waitForCount("home.rounds.row.", 3)
        tap(elements(prefix: "home.rounds.row.").firstMatch.identifier)
        assertExists("roundDetail.scorecard")
        waitForCount("roundDetail.player.", 2)
        XCTAssertGreaterThan(elements(prefix: "scorecard.total.tot.").count, 0)
        let banned = NSPredicate(format: "label MATCHES %@", ".*\\b([Ww]on|WIN)\\b.*")
        XCTAssertEqual(app.descendants(matching: .any).matching(banned).count, 0)
        tap("roundDetail.back")
        assertExists("home.settings")
    }

    /// RD-PL-04: a player opens their Player card.
    func testAPlayerOpensTheirCard() {
        launch(Options(seed: .onePlayer, route: "roundDetail"))
        tap(elements(prefix: "roundDetail.player.").firstMatch.identifier)
        assertExists("screen.playerCard")
    }

    /// The system share sheet (`ActivityListView`), however iOS nests it.
    private var shareSheet: XCUIElement { app.otherElements["ActivityListView"].firstMatch }

    /// RD-SH-01…02, RP-TS-08, RP-EX-03: Share opens the system share sheet with the PDF, and Share works
    /// again after the sheet is closed (each share makes a fresh file). Both layouts reach the sheet.
    func testShareOpensTheShareSheet() {
        for seed in [Seed.twoPlayers, .fullHistory] { // 9-hole rounds, then a mix with 18 holes
            launch(Options(seed: seed, route: "roundDetail"))
            assertExists("roundDetail.scorecard")
            tap("roundDetail.share")
            XCTAssertTrue(shareSheet.waitForExistence(timeout: timeout), "the share sheet didn't open (\(seed))")
            XCTAssertEqual(app.alerts.count, 0)
            // The sheet opens at the medium detent; a tap on the dimmed screen above it closes it.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
            XCTAssertTrue(shareSheet.waitForNonExistence(timeout: timeout), "the share sheet didn't close (\(seed))")
            XCTAssertTrue(element("roundDetail.share").waitForExistence(timeout: timeout))
            tap("roundDetail.share")
            XCTAssertTrue(shareSheet.waitForExistence(timeout: timeout), "Share didn't work a second time (\(seed))")
        }
    }

    /// RD-SH-01, #228: after the share sheet closes, Back returns to a working Home. With the system sheet
    /// wrapped in a SwiftUI sheet, this pop often crashed SwiftUI's glass rendering (2 of 3 runs) and otherwise
    /// left Home's glass buttons undrawn; no pauses, since the crash came on a quick Back.
    func testBackAfterSharingReturnsHome() {
        launch(seed: .twoPlayers)
        waitForCount("home.rounds.row.", 3)
        tap(elements(prefix: "home.rounds.row.").firstMatch.identifier)
        assertExists("roundDetail.scorecard")
        tap("roundDetail.share")
        XCTAssertTrue(shareSheet.waitForExistence(timeout: timeout), "the share sheet didn't open")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        XCTAssertTrue(shareSheet.waitForNonExistence(timeout: timeout), "the share sheet didn't close")
        tap("roundDetail.back")
        assertExists("home.settings")
        tap("home.settings")
        assertExists("screen.settings")
    }

    /// RP-EX-07, RP-TS-08: when the PDF can't be made, the alert shows and nothing is shared.
    func testShareFailureShowsTheAlert() {
        launch(Options(seed: .twoPlayers, route: "roundDetail", flags: ["-uiTestMockPDF", "fail"]))
        tap("roundDetail.share")
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: timeout), "the error alert didn't show")
        XCTAssertFalse(shareSheet.exists)
        tap("roundPDF.errorAlert.ok")
        XCTAssertTrue(element("roundDetail.share").waitForExistence(timeout: timeout))
    }

    /// RD-SH-05, RP-EX-02, RP-TS-08: a slow PDF shows progress in place of the button until the sheet appears.
    func testSlowShareShowsProgress() {
        launch(Options(seed: .twoPlayers, route: "roundDetail", flags: ["-uiTestMockPDF", "slow"]))
        tap("roundDetail.share")
        assertExists("roundDetail.shareProgress")
        XCTAssertTrue(shareSheet.waitForExistence(timeout: timeout))
        XCTAssertFalse(element("roundDetail.shareProgress").exists)
    }

    /// RD-ED-01…03, HP-ED-01, 02 (#87): Edit opens Hole play on hole 1 with Done instead of Exit; a changed
    /// score shows on Round detail after Done.
    func testEditChangesTheRound() {
        launch(Options(seed: .onePlayer, route: "roundDetail"))
        let player = elements(prefix: "roundDetail.player.").firstMatch
        XCTAssertTrue(player.waitForExistence(timeout: timeout))
        let before = player.label
        tap("roundDetail.edit")
        assertExists("hole.done")
        assertMissing("hole.exit")
        let holeCard = element("hole.infoCard")
        XCTAssertTrue(holeCard.waitForExistence(timeout: timeout))
        XCTAssertTrue(holeCard.label.hasPrefix("Hole 1,"), holeCard.label)
        tap("hole.leaderboard") // one player: straight to Enter score, from the saved score (HP-ED-01)
        tap("score.increase")
        tap("score.save")
        assertMissing("hole.panel")
        XCTAssertTrue(holeCard.label.hasPrefix("Hole 1,"), holeCard.label) // no auto-advance (HP-ED-03)
        tap("hole.done")
        XCTAssertTrue(player.waitForExistence(timeout: timeout))
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", before), object: player)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: timeout), .completed, "Round detail still reads \(before)")
    }
}
