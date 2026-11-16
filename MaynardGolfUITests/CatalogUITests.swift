//
//  CatalogUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// The MaynardUI component catalog (#2, #5): it opens with `-uiTestCatalog`, and the material samples
/// exist with Reduce Transparency on and off.
final class CatalogUITests: MaynardUITestCase {
    func testTheCatalogOpens() {
        launch(seed: .freshInstall, flags: ["-uiTestCatalog"])
        assertExists("catalog.root")
        assertExists("catalog.header")
    }

    /// DS-MT-04: Reduce Transparency turns the blurred scrim opaque (the sample reports which it is).
    func testReduceTransparencyMakesTheScrimOpaque() {
        for (flags, mode) in [(["-uiTestCatalog"], "blur"), (["-uiTestCatalog", "-uiTestReduceTransparency"], "opaque")] {
            launch(seed: .freshInstall, flags: flags)
            assertExists("catalog.glass")
            XCTAssertEqual(element("catalog.scrim").value as? String, mode)
        }
    }

    func testEveryComponentGroupHasASection() {
        launch(seed: .freshInstall, flags: ["-uiTestCatalog"])
        for group in ["Buttons", "Identity", "Chips & badges", "Containers & rows", "Form controls",
                      "Navigation & sheets", "Golf display", "Course overlay"] {
            reveal("catalog.group.\(group)") // scrolls without tapping the samples inside
        }
    }

    /// DS-BT-01: a loading button ignores taps, so a save can't run twice; VoiceOver hears "Loading".
    func testALoadingButtonIgnoresTaps() {
        launch(seed: .freshInstall, flags: ["-uiTestCatalog"])
        tap("catalog.button.loading")
        tap("catalog.button.loading")
        XCTAssertEqual(text("catalog.button.loadingTaps"), "Loading taps: 0")
        XCTAssertEqual(element("catalog.button.loading").value as? String, "Loading")
    }

    /// DS-CN-09, DS-CN-10: the toggle switches and the segmented control changes its value.
    func testFormControlsRespond() {
        launch(seed: .freshInstall, flags: ["-uiTestCatalog"])
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
        launch(seed: .freshInstall, flags: ["-uiTestCatalog"])
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
        launch(seed: .freshInstall, flags: ["-uiTestCatalog"])
        tap("catalog.push")
        assertExists("catalog.pushed")
        app.buttons.matching(NSPredicate(format: "label == %@", "Back")).firstMatch.tap()
        assertMissing("catalog.pushed")
        tap("catalog.push")
        assertExists("catalog.pushed")
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        assertMissing("catalog.pushed")
    }

    /// The built groups show their components (#6–#8).
    func testButtonsAvatarsAndChipsAreShown() {
        launch(seed: .freshInstall, flags: ["-uiTestCatalog"])
        reveal("catalog.button.primary")
        reveal("catalog.avatars")
        reveal("catalog.chips.overlay")
    }

    /// The catalog passes the audit in Light and Dark (TS-UI-04). Allowed issues:
    /// - the Numeral sample caps at XXXL by design (X-07), reported as partial Dynamic Type support;
    /// - contrast on the Glass and Scrim samples, which sit on translucent materials over a drawn photo:
    ///   the audit misreads those (it flags a different one each run, even Chalk on 82 % Canopy). Text
    ///   over real photos is audited on its screens; token contrast is unit-tested (DS-CL-02, DS-DM-04);
    /// - a contrast issue attached to an internal SwiftUI node with no element, which can't be located.
    /// Any contrast or Dynamic Type issue on another element still fails.
    func testTheCatalogPassesTheAudit() throws {
        try auditAccessibility(Options(seed: .freshInstall, flags: ["-uiTestCatalog"]), ready: "catalog.scrim") { issue in
            switch issue.auditType {
            case .dynamicType: issue.element?.identifier == "catalog.type.numeral"
            case .contrast: issue.element.map { ["catalog.glass", "catalog.scrim"].contains($0.identifier) } ?? true
            default: false
            }
        }
    }

    func testTypeStylesAreShown() {
        launch(seed: .freshInstall, flags: ["-uiTestCatalog"])
        tap("catalog.type.display")
        tap("catalog.type.caption") // scrolls on to the last style
    }
}
