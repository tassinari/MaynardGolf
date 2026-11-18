//
//  AllPlayersUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 11-all-players (#80): search, the count, rows to Player card, Add, swipe-to-delete and the empty state.
final class AllPlayersUITests: MaynardUITestCase {
    private func open(_ seed: Seed) {
        launch(Options(seed: seed, route: "allPlayers"))
        assertExists("screen.allPlayers")
    }

    private func search(_ text: String) {
        let field = element("allPlayers.search")
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        field.tap()
        field.typeText(text)
    }

    /// AL-SR-01…03, AL-LS-04: every player A–Z; "sc" leaves only Scottie and the count follows.
    func testSearch() {
        open(.fullHistory) // 7 players
        waitForCount("allPlayers.row.", 7)
        waitForText("allPlayers.count", "7 PLAYERS")
        search("sc")
        waitForCount("allPlayers.row.", 1)
        XCTAssertTrue(elements(prefix: "allPlayers.row.").firstMatch.label.contains("Scottie"))
        waitForText("allPlayers.count", "1 OF 7 PLAYERS")
    }

    /// AL-SR-04: no match shows the message instead of rows.
    func testNoMatch() {
        open(.fullHistory)
        search("zzz")
        assertExists("allPlayers.noResults")
        waitForCount("allPlayers.row.", 0)
    }

    /// AL-LS-05: a row opens that player's card.
    func testRowOpensThePlayerCard() {
        open(.twoPlayers)
        tap(elements(prefix: "allPlayers.row.").firstMatch.identifier)
        assertExists("screen.playerCard")
    }

    /// AL-NAV-03: Add opens Add player; the new player is in the list on return.
    func testAdd() {
        open(.twoPlayers)
        waitForCount("allPlayers.row.", 2)
        tap("allPlayers.add")
        let first = element("addPlayer.firstName")
        XCTAssertTrue(first.waitForExistence(timeout: timeout))
        first.tap()
        first.typeText("Zoe")
        tap("addPlayer.create")
        waitForCount("allPlayers.row.", 3)
    }

    /// AL-LS-06: swipe, Delete, confirm → the player is gone.
    func testSwipeToDelete() {
        open(.noRound) // three players, no rounds
        waitForCount("allPlayers.row.", 3)
        let row = elements(prefix: "allPlayers.row.").firstMatch
        row.swipeLeft()
        let delete = elements(prefix: "allPlayers.delete.").firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: timeout))
        delete.tap()
        tap("allPlayers.confirmDelete")
        waitForCount("allPlayers.row.", 2)
    }

    /// AL-DT-02: no players at all → the empty state with Add player.
    func testNoPlayers() {
        open(.freshInstall)
        assertExists("allPlayers.empty.addPlayer")
    }
}
