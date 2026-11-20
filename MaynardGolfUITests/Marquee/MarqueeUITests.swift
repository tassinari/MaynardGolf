import XCTest

/// SET-MQ / HOME-MQ: navigation and save wiring; defaults, ordering and chart thresholds are unit tested.
final class MarqueeUITests: MaynardUITestCase {
    func testSelectPlayerOutsideOldTopFourThenClearToNone() {
        launch(Options(seed: .fullHistory, route: "settings"))
        tap("settings.marqueePlayer")
        assertExists("screen.marqueePlayer")
        waitForCount("marqueePlayer.player.", 7)
        let jose = element("marqueePlayer.player.00000000-0000-0000-0000-000000000006")
        let id = String(jose.identifier.dropFirst("marqueePlayer.player.".count))
        tap(jose.identifier)
        assertExists("screen.settings")
        XCTAssertEqual(element("settings.marqueePlayer").value as? String, "José María")
        tap("settings.back")
        let card = "home.players.card.\(id)"
        assertExists(card)
        waitForCount("home.players.card.", 1)
        waitForCount("home.players.row.", 3)
        assertMissing("home.players.row.\(id)")
        reveal(card)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).press(forDuration: 0.05,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Marquee player Home"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        tap(card)
        assertExists("playerCard.edit")
        tap("playerCard.back")
        // Home may retain the scroll position; scroll to its hero before opening Settings.
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        tap("home.settings")
        tap("settings.marqueePlayer")
        XCTAssertTrue(element("marqueePlayer.player.\(id)").isSelected)
        tap("marqueePlayer.none")
        XCTAssertEqual(element("settings.marqueePlayer").value as? String, "None")
        tap("settings.back")
        waitForCount("home.players.card.", 0)
        waitForCount("home.players.row.", 4)
    }

    func testFailedSelectionRetriesAndBackDoesNotWrite() {
        launch(Options(seed: .twoPlayersMarquee, route: "settings", flags: ["-uiTestFailMarqueeOnce"]))
        tap("settings.marqueePlayer")
        waitForCount("marqueePlayer.player.", 2)
        let choices = elements(prefix: "marqueePlayer.player.")
        XCTAssertEqual(choices.count, 2)
        let other = choices.allElementsBoundByIndex.first { !$0.isSelected }!
        let id = other.identifier
        tap(id)
        assertExists("marqueePlayer.error")
        XCTAssertFalse(element(id).isSelected)
        tap("marqueePlayer.retry")
        assertExists("screen.settings")
        XCTAssertEqual(element("settings.marqueePlayer").value as? String, "Scottie Scheffler")
        tap("settings.marqueePlayer")
        XCTAssertTrue(element(id).isSelected)
        tap("marqueePlayer.back")
        XCTAssertEqual(element("settings.marqueePlayer").value as? String, "Scottie Scheffler")
        tap("settings.back")
        waitForCount("home.players.card.", 1)
        waitForCount("home.players.row.", 1)
        let row = elements(prefix: "home.players.row.").firstMatch
        tap(row.identifier)
        assertExists("playerCard.edit")
    }

    func testCreatingFirstPlayerDefaultsAndSecondKeepsCompactLayout() {
        launch(seed: .freshInstall)
        tap("home.empty.addPlayer")
        element("addPlayer.firstName").tap()
        element("addPlayer.firstName").typeText("First")
        tap("addPlayer.create")
        waitForCount("home.players.card.", 1)
        tap("home.players.addPlayer")
        element("addPlayer.firstName").tap()
        element("addPlayer.firstName").typeText("Second")
        tap("addPlayer.create")
        waitForCount("home.players.card.", 1)
        waitForCount("home.players.row.", 1)
        app.swipeDown(velocity: .fast)
        tap("home.settings")
        XCTAssertEqual(element("settings.marqueePlayer").value as? String, "First")
    }

    func testDeletedMarqueeLeavesNoneAndFallback() {
        launch(Options(seed: .twoPlayersMarquee, route: "marqueePlayer"))
        waitForCount("marqueePlayer.player.", 2)
        let selected = elements(prefix: "marqueePlayer.player.").allElementsBoundByIndex.first { $0.isSelected }!
        let id = String(selected.identifier.dropFirst("marqueePlayer.player.".count))
        tap("marqueePlayer.back")
        tap("home.players.card.\(id)")
        tap("playerCard.edit")
        tap("addPlayer.delete")
        tap("addPlayer.confirmDelete")
        // The remaining single player uses the original one-card layout, with no promoted marquee.
        waitForCount("home.players.card.", 1)
        app.swipeDown(velocity: .fast)
        tap("home.settings")
        XCTAssertEqual(element("settings.marqueePlayer").value as? String, "None")
    }
}
