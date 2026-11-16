//
//  AddPlayerPhotoUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 05-add-player §3: the avatar's photo flow with `-uiTestMockPhoto` standing in for the system picker
/// (#43, #127).
final class AddPlayerPhotoUITests: MaynardUITestCase {
    private func openAddPlayer(photo: String = "success") {
        launch(seed: .freshInstall, flags: ["-uiTestMockPhoto", photo])
        tap("home.link.addPlayer")
        assertExists("addPlayer.photo")
    }

    private var caption: String { element("addPlayer.photoCaption").label }

    /// AP-PH-02…04, AP-MS-05, 06: Add photo → Move and Scale → zoom → Done → the avatar has the photo and
    /// the caption reads "Change photo"; the player is created with it.
    func testAddAPhoto() {
        openAddPlayer()
        XCTAssertEqual(caption, "Add photo")
        tap("addPlayer.photo")
        assertExists("photoCrop.image")
        assertExists("photoCrop.title")
        element("photoCrop.zoom").adjust(toNormalizedSliderPosition: 0.7)
        tap("photoCrop.done")
        assertMissing("photoCrop.image")
        XCTAssertEqual(caption, "Change photo")
        tap("addPlayer.firstName")
        app.typeText("Rory")
        tap("addPlayer.create")
        waitForText("home.players", "1 player")
    }

    /// AP-PH-03, 07: with a photo set, the avatar offers Choose new / Adjust / Remove; Remove brings the
    /// placeholder back.
    func testThePhotoMenu() {
        openAddPlayer()
        tap("addPlayer.photo")
        tap("photoCrop.done")
        tap("addPlayer.photo")
        assertExists("addPlayer.photoMenu.choose")
        assertExists("addPlayer.photoMenu.adjust")
        tap("addPlayer.photoMenu.remove")
        XCTAssertEqual(caption, "Add photo")
    }

    /// AP-MS-06: Cancel on a new photo leaves the avatar empty; Adjust → Cancel leaves it unchanged.
    func testCancelInMoveAndScale() {
        openAddPlayer()
        tap("addPlayer.photoCaption") // the caption does what the avatar does
        tap("photoCrop.cancel")
        assertMissing("photoCrop.image")
        XCTAssertEqual(caption, "Add photo")

        tap("addPlayer.photo")
        tap("photoCrop.done")
        tap("addPlayer.photo")
        tap("addPlayer.photoMenu.adjust")
        assertExists("photoCrop.image")
        tap("photoCrop.cancel")
        XCTAssertEqual(caption, "Change photo")
    }

    /// AP-PH-08: a photo that can't be loaded shows "Couldn't load that photo" and the avatar stays.
    /// (No permission prompt, AP-PH-05, is guaranteed by the missing photo-library usage key, which
    /// `InfoPlistTests.noUnusedPermissions` checks.)
    func testAFailedLoad() {
        openAddPlayer(photo: "fail")
        tap("addPlayer.photo")
        tap("addPlayer.photoErrorOK")
        XCTAssertEqual(caption, "Add photo")
    }
}
