//
//  HandicapUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 18-handicap (#125): every screen that shows an index reads it from `HandicapManager`, and a calculated
/// index is announced as "calculated" (HC-SRC-05). All players and the Player card join these checks when
/// they're built (phase 4); edit mode and deleting a round (HC-TS-09) come with them.
final class HandicapUITests: MaynardUITestCase {
    /// The "HCP 8.4" part of a row's label, so two screens' values can be compared.
    private func index(in label: String) -> String? {
        label.range(of: #"(\+?\d+\.\d|—)"#, options: .regularExpression).map { String(label[$0]) }
    }

    /// HC-TS-08: a player with rounds and no manual index has the same calculated value on Home and on New
    /// round, and both rows say "calculated"; a manual index doesn't.
    func testCalculatedIndexIsTheSameAndLabeled() {
        launch(seed: .twoPlayers) // Mark: no manual index, 3 rounds; Scottie: manual +2.1
        waitForHomePlayers(2)
        let cards = elements(prefix: "home.players.card.")
        let mark = cards.element(boundBy: 0), scottie = cards.element(boundBy: 1)
        XCTAssertTrue(mark.label.contains("calculated"), mark.label)
        XCTAssertFalse(scottie.label.contains("calculated"), scottie.label)
        let homeIndex = index(in: mark.label)
        XCTAssertNotNil(homeIndex, mark.label)

        tap("home.newRound")
        waitForCount("newRound.player.", 2)
        let rows = elements(prefix: "newRound.player.")
        let markRow = rows.element(boundBy: 0)
        XCTAssertEqual(markRow.value as? String, "calculated", markRow.label)
        XCTAssertEqual(index(in: markRow.label), homeIndex, markRow.label)
        XCTAssertNotEqual(rows.element(boundBy: 1).value as? String, "calculated")
    }

    /// HC-SRC-03: players with no rounds and no manual index show "—" and nothing calculated, on Home rows.
    func testNoRoundsShowsADash() {
        launch(seed: .noRound) // three players, no rounds; Scottie has a manual index
        waitForHomePlayers(3)
        let rows = elements(prefix: "home.players.row.")
        let mark = rows.element(boundBy: 0)
        XCTAssertTrue(mark.label.contains("—"), mark.label)
        XCTAssertNotEqual(mark.value as? String, "calculated")
    }

    /// HC-TS-10: a manual 5.0 shows instead of the calculated index, without "calculated".
    func testManualIndexWins() {
        launch(Options(seed: .onePlayer, route: "editPlayer"))
        assertExists("addPlayer.save")
        let field = element("addPlayer.handicap")
        field.tap()
        field.typeText("5.0")
        tap("addPlayer.save")
        assertMissing("addPlayer.save")
        let card = elements(prefix: "home.players.card.").element(boundBy: 0)
        let manual = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS '5.0'"), object: card)
        XCTAssertEqual(XCTWaiter.wait(for: [manual], timeout: timeout), .completed, card.label)
        XCTAssertFalse(card.label.contains("calculated"), card.label)
    }
}
