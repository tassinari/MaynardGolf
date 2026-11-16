//
//  HarnessUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// Self-tests of the UI test harness (#20, #22): every seed launches to its data, and the appearance and
/// Dynamic Type options take effect.
final class HarnessUITests: MaynardUITestCase {
    /// Each seed opens Home on its data: the players shown (cards for 1–2, rows for 3+, at most 4), the
    /// rounds in progress and the recent rounds (3 with a round in progress or summary cards, else 4).
    func testEverySeedLaunchesToItsData() {
        let expected: [(seed: Seed, players: Int, playing: Int, recent: Int)] = [
            (.freshInstall, 0, 0, 0), (.onePlayer, 1, 0, 3), (.twoPlayers, 2, 0, 3), (.noRound, 3, 0, 0),
            (.inProgress, 3, 1, 2), (.twoInProgress, 3, 2, 1), (.fullHistory, 7, 1, 3),
        ]
        for row in expected {
            launch(seed: row.seed)
            waitForHomePlayers(row.players)
            waitForCount("home.inProgressCard", row.playing, exact: true)
            waitForCount("home.rounds.row.", row.recent)
            if row.recent == 0 { assertExists("home.empty.rounds") }
        }
    }

    func testAppearanceOptionTakesEffect() throws {
        launch(Options(seed: .freshInstall, appearance: .dark))
        assertExists("home.empty.players")
        let dark = app.screenshot().image
        launch(Options(seed: .freshInstall, appearance: .light))
        assertExists("home.empty.players")
        let light = app.screenshot().image
        XCTAssertLessThan(Self.brightness(dark), Self.brightness(light) - 0.3)
    }

    func testDynamicTypeOptionTakesEffect() {
        launch(Options(seed: .freshInstall))
        assertExists("home.hero.title")
        let regular = app.staticTexts["home.hero.title"].frame.height
        launch(Options(seed: .freshInstall, dynamicType: .ax3))
        let large = app.staticTexts["home.hero.title"]
        XCTAssertTrue(large.waitForExistence(timeout: timeout))
        XCTAssertGreaterThan(large.frame.height, regular * 1.5)
    }

    /// Average brightness of a screenshot, 0 (black) … 1 (white): the image drawn into one RGBA pixel.
    private static func brightness(_ image: UIImage) -> CGFloat {
        guard let cgImage = image.cgImage else { return 0 }
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn = pixel.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard drawn else { return 0 }
        return (CGFloat(pixel[0]) + CGFloat(pixel[1]) + CGFloat(pixel[2])) / (3 * 255)
    }
}
