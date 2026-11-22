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
    /// #224: the normal delete retains the round in Trash; a confirmed swipe there permanently removes it.
    func testTrashSingleDeleteRequiresConfirmation() {
        launch(Options(seed: .twoPlayers, route: "allRounds"))
        let id = moveFirstRoundToTrash(remaining: 2)
        tap("allRounds.trash")
        assertExists("screen.deletedRounds")
        let row = element("deletedRounds.row.\(id)")
        XCTAssertTrue(row.waitForExistence(timeout: timeout))
        row.swipeLeft()
        tap("deletedRounds.delete.\(id)")
        tap("deletedRounds.cancelDelete")
        assertExists("deletedRounds.row.\(id)")
        row.swipeLeft()
        tap("deletedRounds.delete.\(id)")
        tap("deletedRounds.confirmDelete")
        assertExists("deletedRounds.empty")
        XCTAssertFalse(element("deletedRounds.emptyTrash").isEnabled)
        tap("deletedRounds.back")
        assertExists("screen.allRounds")
        waitForText("allRounds.count", "2 ROUNDS")
        assertMissing("allRounds.row.\(id)")
    }

    /// #239: Restore returns the same round from Trash to active history without a confirmation.
    func testRestoreDeletedRound() {
        launch(Options(seed: .twoPlayers, route: "allRounds"))
        let id = moveFirstRoundToTrash(remaining: 2)
        tap("allRounds.trash")
        let row = element("deletedRounds.row.\(id)")
        XCTAssertTrue(row.waitForExistence(timeout: timeout))
        row.swipeLeft()
        assertExists("deletedRounds.delete.\(id)")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Deleted round with blue Restore swipe action"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        tap("deletedRounds.restore.\(id)")
        assertExists("deletedRounds.empty")
        tap("deletedRounds.back")
        waitForCount("allRounds.row.", 3)
        assertExists("allRounds.row.\(id)")
        tap("allRounds.row.\(id)")
        assertExists("roundDetail.back")
    }

    /// #224: Cancel keeps every trashed row; confirming empties Trash while preserving active history.
    func testEmptyTrashRequiresConfirmation() {
        launch(Options(seed: .twoPlayers, route: "allRounds"))
        _ = moveFirstRoundToTrash(remaining: 2)
        _ = moveFirstRoundToTrash(remaining: 1)
        tap("allRounds.trash")
        waitForCount("deletedRounds.row.", 2)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Deleted rounds with permanent delete action"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        tap("deletedRounds.emptyTrash")
        tap("deletedRounds.cancelEmptyTrash")
        waitForCount("deletedRounds.row.", 2)
        tap("deletedRounds.emptyTrash")
        tap("deletedRounds.confirmEmptyTrash")
        assertExists("deletedRounds.empty")
        XCTAssertFalse(element("deletedRounds.emptyTrash").isEnabled)
        tap("deletedRounds.back")
        waitForText("allRounds.count", "1 ROUND")
    }

    /// #224: Trash is reachable even with no active history, and cannot offer a destructive empty action.
    func testEmptyTrashNavigation() {
        launch(Options(seed: .freshInstall, route: "allRounds"))
        tap("allRounds.trash")
        assertExists("screen.deletedRounds")
        assertExists("deletedRounds.empty")
        XCTAssertFalse(element("deletedRounds.emptyTrash").isEnabled)
        tap("deletedRounds.back")
        assertExists("screen.allRounds")
        launch(Options(seed: .freshInstall, route: "deletedRounds"))
        assertExists("deletedRounds.empty")
        tap("deletedRounds.back")
        assertExists("screen.allRounds")
    }

    /// #224: deleting the last active round must not strand Trash behind a hidden Home link.
    func testTrashRemainsReachableFromHomeAfterDeletingAllRounds() {
        launch(Options(seed: .onePlayer, route: "allRounds"))
        _ = moveFirstRoundToTrash(remaining: 2)
        _ = moveFirstRoundToTrash(remaining: 1)
        _ = moveFirstRoundToTrash(remaining: 0)
        tap("allRounds.back")
        assertExists("home.rounds.seeAll")
        tap("home.rounds.seeAll")
        assertExists("screen.allRounds")
        tap("allRounds.trash")
        waitForCount("deletedRounds.row.", 3)
    }

    @discardableResult
    private func moveFirstRoundToTrash(remaining: Int) -> String {
        waitForCount("allRounds.row.", remaining + 1)
        let row = elements(prefix: "allRounds.row.").element(boundBy: 0)
        let id = String(row.identifier.dropFirst("allRounds.row.".count))
        row.swipeLeft()
        tap("allRounds.delete.\(id)")
        tap("allRounds.confirmDelete")
        waitForCount("allRounds.row.", remaining)
        return id
    }

}
