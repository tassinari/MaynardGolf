import XCTest

/// HOME-AR: full-history reachability, live search, navigation and confirmed deletion.
final class AllRoundsUITests: MaynardUITestCase {
    func testHomeSearchAndOldestRound() {
        launch(seed: .fullHistory)
        tap("home.rounds.seeAll")
        assertExists("screen.allRounds")
        waitForText("allRounds.count", "67 ROUNDS")
        reveal("allRounds.row.00000000-0000-0000-0000-000000000084")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "All rounds, oldest month"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        tap("allRounds.search")
        element("allRounds.search").typeText("sc")
        let count = Int(element("allRounds.count").label.split(separator: " ")[0])!
        XCTAssertGreaterThan(count, 0)
        XCTAssertLessThan(count, 67)
        element("allRounds.search").typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2))
        waitForText("allRounds.count", "67 ROUNDS")
        element("allRounds.search").typeText("zzz")
        assertExists("allRounds.noResults")
        waitForText("allRounds.count", "0 ROUNDS")
        assertMissing("allRounds.filter")
    }

    func testCompletedAndInProgressDestinations() {
        launch(Options(seed: .twoInProgress, route: "allRounds"))
        waitForCount("allRounds.row.", 3)
        tap(elements(prefix: "allRounds.row.").element(boundBy: 0).identifier)
        assertExists("hole.leaderboard")
        launch(Options(seed: .onePlayer, route: "allRounds"))
        waitForCount("allRounds.row.", 3)
        tap(elements(prefix: "allRounds.row.").element(boundBy: 0).identifier)
        assertExists("roundDetail.back")
    }

    func testSwipeDeleteConfirmsAndUpdatesTheCount() {
        launch(Options(seed: .twoPlayers, route: "allRounds"))
        waitForCount("allRounds.row.", 3)
        let row = elements(prefix: "allRounds.row.").element(boundBy: 0)
        let id = String(row.identifier.dropFirst("allRounds.row.".count))
        row.swipeLeft()
        tap("allRounds.delete.\(id)")
        assertExists("allRounds.confirmDelete")
        tap("allRounds.confirmDelete")
        waitForText("allRounds.count", "2 ROUNDS")
        assertMissing("allRounds.row.\(id)")
    }

    func testFailedDeleteKeepsTheRound() {
        launch(Options(seed: .twoPlayers, route: "allRounds", flags: ["-uiTestFailPersistence"]))
        waitForCount("allRounds.row.", 3)
        let row = elements(prefix: "allRounds.row.").element(boundBy: 0)
        let id = String(row.identifier.dropFirst("allRounds.row.".count))
        row.swipeLeft()
        tap("allRounds.delete.\(id)")
        tap("allRounds.confirmDelete")
        assertExists("allRounds.deleteError.ok")
        tap("allRounds.deleteError.ok")
        waitForText("allRounds.count", "3 ROUNDS")
        assertExists("allRounds.row.\(id)")
    }

    func testCancellingDeleteKeepsTheRound() {
        launch(Options(seed: .twoPlayers, route: "allRounds"))
        waitForCount("allRounds.row.", 3)
        let row = elements(prefix: "allRounds.row.").element(boundBy: 0)
        let id = String(row.identifier.dropFirst("allRounds.row.".count))
        row.swipeLeft()
        tap("allRounds.delete.\(id)")
        tap("allRounds.cancelDelete")
        waitForText("allRounds.count", "3 ROUNDS")
        assertExists("allRounds.row.\(id)")
        waitForCount("allRounds.row.", 3)
    }

    func testEmptyHistoryAndBack() {
        launch(Options(seed: .freshInstall, route: "allRounds"))
        assertExists("home.empty.rounds")
        assertMissing("allRounds.search")
        assertMissing("allRounds.count")
        tap("allRounds.back")
        assertExists("home.empty.players")
    }
}
