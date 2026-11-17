//
//  RoundCompleteUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 17-round-complete (#119). Opened with the `roundComplete` deep link on the newest round; the end-to-end
/// path from Hole play is `HolePlayUITests.testPlayAWholeRound`.
final class RoundCompleteUITests: MaynardUITestCase {
    private func open() {
        launch(Options(seed: .twoPlayers, route: "roundComplete"))
        assertExists("roundComplete.done")
    }

    /// RC-CT-02, 03, RC-TS-03: a row per player, no "won"; Done → Home with the round first in Recent rounds.
    func testDoneGoesHome() {
        open()
        waitForCount("roundComplete.player.", 2)
        let won = NSPredicate(format: "label MATCHES %@", ".*\\\\b[Ww]on\\\\b.*")
        XCTAssertEqual(app.descendants(matching: .any).matching(won).count, 0)
        tap("roundComplete.done")
        assertExists("home.settings")
        assertMissing("roundComplete.done")
        XCTAssertGreaterThan(elements(prefix: "home.rounds.row.").count, 0)
    }

    /// RC-CT-04: View scorecard opens Round detail, and back returns to Home.
    func testViewScorecard() {
        open()
        tap("roundComplete.viewScorecard")
        assertExists("screen.roundDetail")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        assertExists("home.settings")
    }

    /// RC-BH-05: swiping down doesn't dismiss it.
    func testSwipeDownDoesntDismiss() {
        open()
        app.swipeDown(velocity: .fast)
        assertExists("roundComplete.done")
    }
}
