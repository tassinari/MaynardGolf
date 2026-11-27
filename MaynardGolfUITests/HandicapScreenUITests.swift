//
//  HandicapScreenUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 19-handicap-screen (#253): what only the running app shows: the Player card's row opening Handicap, the
/// Add score › Add course flow, swipe to delete and a Maynard row opening Round detail. The differentials,
/// which rounds count, the explanation and the validation ranges are unit-tested (`HandicapScreenTests`,
/// `HandicapCalculatorTests`). The `outsideScores` seed: Mark with 3 Maynard rounds and 4 outside scores.
final class HandicapScreenUITests: MaynardUITestCase {
    /// Seven rows in the seed: Mark's three rounds and four outside scores.
    private static let seededRows = 7

    private func openHandicap() {
        launch(Options(seed: .outsideScores, route: "handicap"))
        assertExists("handicap.screen")
        waitForCount("handicap.row.", Self.seededRows)
    }

    /// The first row whose label contains `text`.
    private func row(containing text: String) -> XCUIElement {
        let row = elements(prefix: "handicap.row.").matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: timeout), "no row with \(text)")
        return row
    }

    /// PC-HDR-06, HS-HDR-02: the Player card's index opens Handicap, which shows the same index; Back returns.
    func testThePlayerCardRowOpensHandicap() {
        launch(Options(seed: .outsideScores, route: "playerCard"))
        let index = element("playerCard.handicap")
        XCTAssertTrue(index.waitForExistence(timeout: timeout))
        let cardLabel = index.label
        index.tap()
        assertExists("handicap.screen")
        XCTAssertEqual(element("handicap.index").label, cardLabel)
        waitForCount("handicap.row.", Self.seededRows)
        assertExists("handicap.explanation")
        tap("handicap.back")
        assertExists("screen.playerCard")
    }

    /// HS-AS, HS-AC: Add score › Add course › Save course returns with the course chosen; Save score returns to
    /// Handicap, which lists the new score.
    func testAddACourseThenAScore() {
        openHandicap()
        tap("handicap.addScore")
        assertExists("addScore.screen")
        tap("addScore.addCourse")
        assertExists("addCourse.screen")
        tap("addCourse.name")
        app.typeText("Pine Hollow")
        tap("addCourse.rating")
        app.typeText("70.4")
        tap("addCourse.slope")
        app.typeText("126")
        tap("addCourse.save")
        assertExists("addScore.screen")
        let course = element("addScore.course")
        XCTAssertTrue(course.waitForExistence(timeout: timeout))
        XCTAssertTrue(course.label.contains("Pine Hollow") || (course.value as? String)?.contains("Pine Hollow") == true,
                      "the new course isn't chosen: \(course.label)")
        tap("addScore.score")
        app.typeText("84")
        XCTAssertEqual(element("addScore.score").value as? String, "84")
        XCTAssertTrue(element("addScore.save").isEnabled, "Save score is disabled")
        tap("addScore.save")
        assertMissing("addScore.screen")
        assertExists("handicap.screen")
        // The newest row, at the top (the list builds rows lazily, so a count would miss one below the fold).
        XCTAssertTrue(row(containing: "Pine Hollow").exists)
    }

    /// HS-LS-06: swipe an outside score › Delete › confirm: the row is gone. Maynard rows have no Delete.
    func testSwipeToDeleteAnOutsideScore() {
        openHandicap()
        row(containing: "Cedar Ridge").swipeLeft()
        let delete = elements(prefix: "handicap.delete.").firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: timeout))
        delete.tap()
        tap("handicap.confirmDelete")
        waitForCount("handicap.row.", Self.seededRows - 1)

        row(containing: "Maynard Golf Club").swipeLeft()
        XCTAssertFalse(elements(prefix: "handicap.delete.").firstMatch.waitForExistence(timeout: 1))
    }

    /// HS-LS-05: a Maynard row opens Round detail.
    func testAMaynardRowOpensRoundDetail() {
        openHandicap()
        row(containing: "Maynard Golf Club").tap()
        assertExists("roundDetail.back")
    }

    /// DM-OC-03, HS-AC-04: a name another course has shows the error and stays on Add course.
    func testADuplicateCourseNameStays() {
        launch(Options(seed: .outsideScores, route: "addOutsideScore"))
        tap("addScore.addCourse")
        tap("addCourse.name")
        app.typeText("cedar ridge")
        tap("addCourse.rating")
        app.typeText("71.2")
        tap("addCourse.slope")
        app.typeText("128")
        tap("addCourse.save")
        assertExists("addCourse.name.error")
        assertExists("addCourse.screen")
    }
}
