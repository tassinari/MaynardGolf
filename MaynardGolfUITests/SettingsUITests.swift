//
//  SettingsUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 02-settings and 03-local-rules (#29, #34, #123): the options, Default tees reaching New round, the local
/// rules sheet and About. UI tests start from the default settings every launch (in-memory storage), so
/// persistence across launches is covered by the `SettingsStore` unit tests.
final class SettingsUITests: MaynardUITestCase {
    private func openSettings(_ seed: Seed = .noRound) {
        launch(seed: seed)
        tap("home.settings")
        assertExists("screen.settings")
    }

    /// SET-OPT-01…03, SET-OPT-05: the toggles start at their defaults and switch.
    func testToggles() {
        openSettings()
        let expected = ["settings.toggle.toPar": "1", "settings.toggle.shotLine": "1", "settings.toggle.autoAdvance": "0"]
        for (id, value) in expected {
            let toggle = app.switches[id]
            XCTAssertTrue(toggle.waitForExistence(timeout: timeout), id)
            XCTAssertEqual(toggle.value as? String, value, id)
            toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
            XCTAssertEqual(toggle.value as? String, value == "1" ? "0" : "1", "\(id) didn't switch")
        }
    }

    /// SET-OPT-04, NR-TEE-05: White by default; choosing Blue preselects Blue on New round.
    func testDefaultTeesReachNewRound() {
        openSettings()
        XCTAssertEqual(element("settings.defaultTees").value as? String, "White")
        tap("settings.defaultTees")
        tap("settings.defaultTees.blue")
        XCTAssertEqual(element("settings.defaultTees").value as? String, "Blue")
        tap("settings.back")
        tap("home.newRound")
        assertExists("newRound.tee.blue")
        XCTAssertTrue(element("newRound.tee.blue").isSelected)
    }

    /// SET-LR-02, LR-HDR-*, LR-RC-*: the row shows the course and count; the sheet lists 12 rules in order
    /// and closes.
    func testLocalRules() {
        openSettings()
        XCTAssertTrue(element("settings.localRules").label.contains("12 local rules"), element("settings.localRules").label)
        tap("settings.localRules")
        assertExists("localRules.sheet")
        waitForCount("localRules.rule.", 12)
        XCTAssertTrue(element("localRules.rule.1").label.hasPrefix("Rule 1. USGA Rules govern play"), element("localRules.rule.1").label)
        XCTAssertTrue(reveal("localRules.rule.12").label.hasSuffix("soft spike facility."))
        tap("lightSheet.close")
        assertMissing("localRules.sheet")
        assertExists("screen.settings")
    }

    /// LR-DT-04 (no auto-present): teeing off doesn't show the local rules.
    func testTeeOffDoesntShowTheRules() {
        launch(seed: .twoPlayers) // the last round's players are preselected, so Tee off is enabled
        tap("home.newRound")
        tap("newRound.teeOff")
        assertExists("hole.leaderboard")
        assertMissing("localRules.sheet")
    }

    /// SET-AB-01, 02, 06, 09: About's rows in order with the version, and Weather data opens Safari in the app.
    func testAbout() {
        openSettings()
        XCTAssertTrue(reveal("settings.version").label.contains("1.2 (211)"), element("settings.version").label) // fixed in UI tests
        let ids = ["settings.version", "settings.feedback", "settings.privacy", "settings.rate", "settings.weatherAttribution"]
        // Measure a single scroll position: revealing each row separately can move the later rows
        // above earlier measurements when Options gains another setting (SET-MQ-01).
        reveal("settings.weatherAttribution")
        let rows = ids.map { element($0).frame.minY }
        XCTAssertEqual(rows, rows.sorted(), "About rows out of order")
        XCTAssertTrue(element("settings.weatherAttribution").label.contains("Weather"))
        tap("settings.weatherAttribution")
        // The in-app browser (SET-AB-09); it opens whether or not the page loads.
        let browser = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'BrowserView'")).firstMatch
        XCTAssertTrue(browser.waitForExistence(timeout: timeout * 2), "the in-app browser didn't open")
    }
}
