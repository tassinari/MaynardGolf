//
//  HandicapUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 18-handicap (#125): every screen that shows an index reads it from `HandicapManager`, and a calculated
/// index is announced as "calculated" (HC-SRC-05). All players and the Player card join these checks when
/// they're built (phase 4); edit mode and deleting a round (HC-TS-09) come with them.
final class HandicapUITests: MaynardUITestCase {
    /// The row or card with this identifier prefix for a player, found by the seed's first name (seed data,
    /// not localized text), since list order isn't what these tests are about.
    private func row(_ prefix: String, named name: String) -> XCUIElement {
        elements(prefix: prefix).matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    /// The "HCP 8.4" part of a row's label, so two screens' values can be compared.
    private func index(in label: String) -> String? {
        label.range(of: #"(\+?\d+\.\d|—)"#, options: .regularExpression).map { String(label[$0]) }
    }

    /// HC-TS-08: a player with rounds and no manual index has the same calculated value on Home and on New
    /// round, and both rows say "calculated"; a manual index doesn't.
    func testCalculatedIndexIsTheSameAndLabeled() {
        launch(seed: .twoPlayers) // Mark: no manual index, 3 rounds; Scottie: manual +2.1
        waitForHomePlayers(2)
        let mark = row("home.players.card.", named: "Mark"), scottie = row("home.players.card.", named: "Scottie")
        XCTAssertTrue(mark.label.contains("calculated"), mark.label)
        XCTAssertFalse(scottie.label.contains("calculated"), scottie.label)
        let homeIndex = index(in: mark.label)
        XCTAssertNotNil(homeIndex, mark.label)

        tap("home.newRound")
        waitForCount("newRound.player.", 2)
        let markRow = row("newRound.player.", named: "Mark")
        XCTAssertEqual(markRow.value as? String, "calculated", markRow.label)
        XCTAssertEqual(index(in: markRow.label), homeIndex, markRow.label)
        XCTAssertNotEqual(row("newRound.player.", named: "Scottie").value as? String, "calculated")
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

    /// HC-TS-10: Mark starts calculated; a manual 5.0 shows on Home and New round without "calculated".
    /// Clearing it again needs a way back into Edit (Player card, #69), so that half is a unit test for now
    /// (HandicapCalculatorTests, HC-TS-05).
    func testManualIndexWins() {
        launch(seed: .onePlayer) // Mark: 3 rounds, no manual index
        waitForHomePlayers(1)
        let card = elements(prefix: "home.players.card.").element(boundBy: 0)
        XCTAssertTrue(card.label.contains("calculated"), card.label) // the starting state this test changes

        // Player card (#69) isn't built yet, so edit through the deep link.
        launch(Options(seed: .onePlayer, route: "editPlayer"))
        setManualIndex("5.0")
        waitForLabel(of: card, containing: "5.0")
        XCTAssertFalse(card.label.contains("calculated"), card.label)
        tap("home.newRound")
        let row = elements(prefix: "newRound.player.").element(boundBy: 0)
        XCTAssertTrue(row.waitForExistence(timeout: timeout))
        XCTAssertTrue(row.label.contains("5.0"), row.label)
        XCTAssertNotEqual(row.value as? String, "calculated")
    }

    /// Replaces the handicap field's text in the open Edit player sheet and saves.
    private func setManualIndex(_ text: String) {
        assertExists("addPlayer.save")
        let field = element("addPlayer.handicap")
        field.tap()
        let existing = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + text)
        tap("addPlayer.save")
        assertMissing("addPlayer.save")
    }

    private func waitForLabel(of element: XCUIElement, containing text: String) {
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [match], timeout: timeout), .completed, element.label)
    }
}
