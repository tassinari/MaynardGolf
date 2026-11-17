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
}
