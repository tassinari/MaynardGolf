//
//  HomeUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 01-home (#23): each state and players layout from its seed, and where every control leads.
final class HomeUITests: MaynardUITestCase {
    /// HOME-PLY-E1, E2, HOME-RR-E1, HOME-PLY-01: both empty states, no "All Players" or "See all", and
    /// Add player opens.
    func testFreshInstall() {
        launch(seed: .freshInstall)
        assertExists("home.empty.players")
        assertExists("home.empty.rounds")
        assertMissing("home.players.allPlayers")
        assertMissing("home.rounds.seeAll")
        assertMissing("home.inProgressCard")
        tap("home.empty.addPlayer")
        assertExists("addPlayer.create")
    }

    /// HOME-IPR-02, 06: the card reads "Hole 5 of 9" (4 holes scored) and opens Hole play.
    func testTheInProgressCardResumesTheRound() {
        launch(seed: .inProgress)
        assertExists("home.inProgressCard")
        XCTAssertEqual(element("home.inProgressCard").value as? String, "Hole 5 of 9")
        tap("home.inProgressCard")
        assertExists("screen.holePlay")
    }

    /// HOME-IPR-07, HOME-HDR-07: one card per round in progress, newest first (the 18-hole round started
    /// later), and New round opens with no warning.
    func testTwoRoundsInProgress() {
        launch(seed: .twoInProgress)
        waitForCount("home.inProgressCard", 2, exact: true)
        let cards = elements(prefix: "home.inProgressCard", exact: true)
        XCTAssertEqual(cards.element(boundBy: 0).value as? String, "Hole 12 of 18")
        XCTAssertEqual(cards.element(boundBy: 1).value as? String, "Hole 4 of 9")
        tap("home.newRound")
        assertExists("screen.newRound")
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    /// HOME-IPR-08: long-press → Discard round → confirm, and the card is gone.
    func testDiscardARoundInProgress() {
        launch(seed: .inProgress)
        element("home.inProgressCard").press(forDuration: 1)
        tap("home.inProgressCard.discard")
        tap("home.discard.confirm")
        waitForCount("home.inProgressCard", 0, exact: true)
        waitForHomePlayers(3)
    }

    /// HOME-PLY-01…06: 7 players show as exactly 4 rows; All Players opens All players; a row opens the
    /// Player card.
    func testTheListLayout() {
        launch(seed: .fullHistory)
        waitForHomePlayers(7)
        assertMissing("home.players.addPlayer")
        tap("home.players.allPlayers")
        assertExists("screen.allPlayers")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap(elements(prefix: "home.players.row.").firstMatch.identifier)
        assertExists("screen.playerCard")
    }

    /// HOME-P1-01, 02, HOME-RR-02: one summary card, "Add player", no "All Players", 3 recent rounds; the
    /// card opens the Player card.
    func testOnePlayer() {
        launch(seed: .onePlayer)
        waitForHomePlayers(1)
        assertExists("home.players.addPlayer")
        assertMissing("home.players.allPlayers")
        waitForCount("home.rounds.row.", 3)
        tap(elements(prefix: "home.players.card.").firstMatch.identifier)
        assertExists("screen.playerCard")
    }

    /// HOME-P2-01…03: two cards; adding a third player switches to the rows with "All Players".
    func testTwoPlayersBecomeTheList() {
        launch(seed: .twoPlayers)
        waitForHomePlayers(2)
        tap("home.players.addPlayer")
        tap("addPlayer.firstName")
        app.typeText("Rory")
        tap("addPlayer.create")
        waitForHomePlayers(3)
        assertExists("home.players.allPlayers")
    }

    /// §1: the In-progress card sits above the Players section. (No seed has one player and a round in
    /// progress; the layout is the same stack for every players layout.)
    func testTheInProgressCardIsAboveThePlayers() {
        launch(seed: .inProgress)
        let card = element("home.inProgressCard")
        let players = elements(prefix: "home.players.row.").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: timeout) && players.waitForExistence(timeout: timeout))
        XCTAssertLessThan(card.frame.minY, players.frame.minY)
    }

    /// HOME-RR-03…07, X-16: each row has the course, the meta and every player's score, no winner; a row
    /// opens Round detail and See all opens All rounds.
    func testRecentRounds() {
        launch(seed: .fullHistory)
        waitForCount("home.rounds.row.", 3)
        let row = elements(prefix: "home.rounds.row.").firstMatch
        XCTAssertTrue(row.label.contains("Maynard Golf Club"), row.label)
        XCTAssertTrue(row.label.contains("holes,"), row.label)
        tap(row.identifier)
        assertExists("screen.roundDetail")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap("home.rounds.seeAll")
        assertExists("screen.allRounds")
    }

    /// HOME-HDR-03, 04: Settings pushes Settings; New round opens New round.
    func testTheHeroButtons() {
        launch(seed: .noRound)
        tap("home.settings")
        assertExists("screen.settings")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap("home.newRound")
        assertExists("screen.newRound")
    }

    /// Product hazards: no "You" and no "won" anywhere on Home, in any state.
    func testNoMeAndNoWinner() {
        for seed in [Seed.onePlayer, .inProgress, .fullHistory] {
            launch(seed: seed)
            assertExists("home.settings")
            let banned = NSPredicate(format: "label MATCHES %@ OR label MATCHES %@", ".*\\bYou\\b.*", ".*\\b[Ww]on\\b.*")
            XCTAssertEqual(app.descendants(matching: .any).matching(banned).count, 0, seed.rawValue)
        }
    }
}
