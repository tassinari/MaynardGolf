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
        assertExists("hole.leaderboard")
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
        assertExists("newRound.teeOff")
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

    /// HOME-IPR-02, 08 (#211): the ✕ asks first, then Discard round removes the card.
    func testTheDeleteButtonDiscardsARound() {
        launch(seed: .inProgress)
        tap("home.inProgressCard.delete")
        tap("home.discard.confirm")
        waitForCount("home.inProgressCard", 0, exact: true)
    }

    /// HOME-IPR-08, 09 (#233): removing the top card keeps the other round and closes its layout gap.
    func testSwipeToDiscardARound() {
        launch(seed: .twoInProgress)
        waitForCount("home.inProgressCard", 2, exact: true)
        let cards = elements(prefix: "home.inProgressCard", exact: true)
        let card = cards.element(boundBy: 0)
        let firstY = card.frame.minY
        let remainingValue = cards.element(boundBy: 1).value as? String
        XCTAssertTrue(card.waitForExistence(timeout: timeout))
        // 130 pt: past half the action, short of a full swipe, so the card rests open.
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.6))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -130, dy: 0)))
        tap("home.inProgressCard.swipeDiscard")
        tap("home.discard.confirm")
        waitForCount("home.inProgressCard", 1, exact: true)
        let remaining = element("home.inProgressCard")
        XCTAssertEqual(remaining.value as? String, remainingValue)
        XCTAssertEqual(remaining.frame.minY, firstY, accuracy: 2)
        XCTAssertTrue(remaining.isHittable)
    }

    /// HOME-PLY-01…06: 7 players show as exactly 4 rows; All Players opens All players; a row opens the
    /// Player card.
    func testTheListLayout() {
        launch(seed: .fullHistory)
        waitForHomePlayers(7)
        assertMissing("home.players.addPlayer")
        tap("home.players.allPlayers")
        assertExists("screen.allPlayers")
        tap("allPlayers.back")
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
        assertExists("roundDetail.back")
        tap("roundDetail.back")
        tap("home.rounds.seeAll")
        assertExists("screen.allRounds")
    }

    /// HOME-HDR-03, 04: Settings pushes Settings; New round opens New round.
    func testTheHeroButtons() {
        launch(seed: .noRound)
        tap("home.settings")
        assertExists("screen.settings")
        tap("settings.back")
        tap("home.newRound")
        assertExists("newRound.teeOff")
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
    /// #212: the same two actions remain pinned while scrolling, and the new-round label compacts.
    func testHeaderButtonsStayPinnedWhenScrolled() {
        launch(seed: .fullHistory)
        assertExists("home.settings")
        assertExists("home.newRound")
        let settings = element("home.settings")
        let newRound = element("home.newRound")
        let settingsY = settings.frame.midY
        let newRoundY = newRound.frame.midY
        let expandedWidth = newRound.frame.width
        app.swipeUp()
        XCTAssertTrue(settings.isHittable, "Settings must stay visible after Home scrolls")
        XCTAssertTrue(newRound.isHittable, "New round must stay visible after Home scrolls")
        XCTAssertEqual(settings.frame.midY, settingsY, accuracy: 2)
        XCTAssertEqual(newRound.frame.midY, newRoundY, accuracy: 2)
        assertMissing("home.newRound.title")
        assertExists("navigation.title")
        XCTAssertLessThan(newRound.frame.width, expandedWidth)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Home, pinned compact photo navigation bar"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        tap("home.settings")
        assertExists("screen.settings")
        tap("settings.back")
        tap("home.newRound")
        assertExists("newRound.teeOff")
    }

    /// #212 regression: rubber-banding at the top must keep the actions pinned and restore the hero.
    func testPullingDownKeepsHeaderActionsPinned() {
        launch(seed: .fullHistory)
        assertExists("home.hero.title")
        let settings = element("home.settings")
        let newRound = element("home.newRound")
        let settingsY = settings.frame.midY
        let newRoundY = newRound.frame.midY
        let scroll = element("home.scroll")
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 200)),
                    withVelocity: .slow, thenHoldForDuration: 1)
        assertExists("home.hero.title")
        assertExists("home.newRound.title")
        assertMissing("navigation.title")
        XCTAssertEqual(settings.frame.midY, settingsY, accuracy: 2)
        XCTAssertEqual(newRound.frame.midY, newRoundY, accuracy: 2)
        XCTAssertTrue(settings.isHittable)
        XCTAssertTrue(newRound.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Home after pulling past the top"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        tap("home.newRound")
        assertExists("newRound.teeOff")
    }

    /// #212: returning to the top restores the full action and large title, also over the dimmed photo.
    func testHeaderExpandsAgainAtTheTop() {
        launch(Options(seed: .fullHistory, appearance: .dark))
        assertExists("home.hero.title")
        assertExists("home.newRound.title")
        let expandedWidth = element("home.newRound").frame.width
        assertMissing("navigation.title")
        app.swipeUp()
        waitForCount("home.newRound.title", 0, exact: true)
        assertExists("navigation.title")
        assertMissing("home.hero.title")
        for _ in 0..<5 {
            if element("home.hero.title").exists { break }
            element("home.scroll").swipeDown()
        }
        assertExists("home.hero.title")
        assertExists("home.newRound.title")
        assertMissing("navigation.title")
        XCTAssertEqual(element("home.newRound").frame.width, expandedWidth, accuracy: 2)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Home, expanded photo header in Dark"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

}
