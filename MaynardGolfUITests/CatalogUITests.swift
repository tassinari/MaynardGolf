//
//  CatalogUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// The MaynardUI component catalog (#2, #5): it opens with `-uiTestCatalog`, and the material samples
/// exist with Reduce Transparency on and off. Each test opens the catalog at the group it checks
/// (`-uiTestCatalogSection`): scrolling the long list to reach a sample took minutes.
final class CatalogUITests: MaynardUITestCase {
    /// `ComponentCatalogView.Group` raw values, the names `-uiTestCatalogSection` takes.
    enum Group: String {
        case buttons = "Buttons", identity = "Identity", chips = "Chips & badges", forms = "Form controls"
        case navigation = "Navigation & sheets", golf = "Golf display", courseOverlay = "Course overlay"
    }

    /// Launches the catalog, scrolled to `group` when one is given.
    func openCatalog(at group: Group? = nil, flags: [String] = []) {
        let section = group.map { ["-uiTestCatalogSection", $0.rawValue] } ?? []
        launch(seed: .freshInstall, flags: ["-uiTestCatalog"] + section + flags)
    }

    func testTheCatalogOpens() {
        openCatalog()
        assertExists("catalog.root")
        assertExists("catalog.header")
    }

    /// DS-MT-04: Reduce Transparency turns the blurred scrim opaque (the sample reports which it is).
    func testReduceTransparencyMakesTheScrimOpaque() {
        for (flags, mode) in [([String](), "blur"), (["-uiTestReduceTransparency"], "opaque")] {
            openCatalog(flags: flags)
            assertExists("catalog.glass")
            XCTAssertEqual(element("catalog.scrim").value as? String, mode)
        }
    }

    /// Opening at a group lands on it, even the last one. Every group gets its section by construction
    /// (a `ForEach` over `Group.allCases`); the group list itself is unit-tested (`ComponentTests.catalogGroups`).
    func testTheCatalogOpensAtAGroup() {
        openCatalog(at: .courseOverlay)
        assertExists("catalog.group.Course overlay")
    }

    /// DS-BT-01: a loading button ignores taps, so a save can't run twice; VoiceOver hears "Loading".
    func testALoadingButtonIgnoresTaps() {
        openCatalog(at: .buttons)
        tap("catalog.button.loading")
        tap("catalog.button.loading")
        XCTAssertEqual(text("catalog.button.loadingTaps"), "Loading taps: 0")
        XCTAssertEqual(element("catalog.button.loading").value as? String, "Loading")
    }

    /// DS-CN-09, DS-CN-10: the toggle switches and the segmented control changes its value.
    func testFormControlsRespond() {
        openCatalog(at: .forms)
        reveal("catalog.segmented.value")
        XCTAssertEqual(text("catalog.segmented.value"), "Unit: yards")
        tap("catalog.segmented.1")
        XCTAssertEqual(text("catalog.segmented.value"), "Unit: meters")
        let toggle = app.switches["catalog.toggle"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: timeout))
        let before = toggle.value as? String
        toggle.tap()
        let changed = NSPredicate(format: "value != %@", before ?? "")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: changed, object: toggle)], timeout: timeout), .completed)
    }

    /// DS-NV-02/03: both sheets open and close.
    func testSheetsOpenAndClose() {
        openCatalog(at: .navigation)
        tap("catalog.openGlassSheet")
        assertExists("catalog.glassSheet")
        app.swipeDown(velocity: .fast)
        assertMissing("catalog.glassSheet")
        tap("catalog.openLightSheet")
        assertExists("catalog.lightSheet")
        tap("lightSheet.close")
        assertMissing("catalog.lightSheet")
    }

    /// DS-NV-01: a screen with the custom bar goes back with its button and with an edge swipe.
    func testCustomBarScreensGoBack() {
        openCatalog(at: .navigation)
        tap("catalog.push")
        assertExists("catalog.pushed")
        tap("catalog.pushed.back")
        assertMissing("catalog.pushed")
        tap("catalog.push")
        assertExists("catalog.pushed")
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        // A swipe released early cancels; the screen stays and its swipe back still works.
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)),
                    withVelocity: .slow, thenHoldForDuration: 0.3)
        assertExists("catalog.pushed")
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        assertMissing("catalog.pushed")
        // A swipe on the root screen does nothing, and pushing still works after it (the gesture's
        // own delegate is back in charge).
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        assertExists("catalog.root")
        assertMissing("catalog.pushed")
        tap("catalog.push") // still on screen: the catalog keeps its scroll position
        assertExists("catalog.pushed")
    }

    /// The built groups show their components (#6–#8).
    func testButtonsAvatarsAndChipsAreShown() {
        openCatalog(at: .buttons)
        reveal("catalog.button.primary")
        reveal("catalog.avatars")
        reveal("catalog.chips.overlay")
    }

    /// #12–#13: the score-mark matrix, the hole card and the overlays are shown, and the target reads its
    /// distances to VoiceOver (SL-TG-07). XCUITest on iOS can't send the adjust action; its mapping to
    /// pin/tee steps is unit-tested (`CourseOverlayTests.adjustSteps`).
    func testGolfDisplayAndOverlaysAreShown() {
        openCatalog(at: .golf)
        reveal("catalog.golf.marks")
        reveal("hole.infoCard")
        let target = reveal("hole.target.1")
        XCTAssertEqual(target.value as? String, "165 yards, 215 to pin")
        assertExists("hole.yardage.toTarget")
        assertExists("hole.yardage.toPin")
    }

    func testTypeStylesAreShown() {
        openCatalog()
        tap("catalog.type.display")
        tap("catalog.type.caption") // scrolls on to the last style
    }
}
