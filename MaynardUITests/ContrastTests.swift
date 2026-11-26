//
//  ContrastTests.swift
//  MaynardUITests
//

import Testing
import UIKit
@testable import MaynardUI

private let light = UITraitCollection(userInterfaceStyle: .light)
private let dark = UITraitCollection(userInterfaceStyle: .dark)

/// DS-CL-02 (§3.4) and DS-DM-04 (§3.8): every readable pairing meets its documented ratio within 0.1 in both
/// appearances, calculated from the token values.
struct ContrastTests {
    /// Every text-on-surface pair the app draws, as semantic tokens, in Light and in Dark (§3.4, §3.8).
    /// Translucent fills are composited over the card first.
    @Test(arguments: [
        (DSColorToken.textPrimary, DSColorToken.background, 15.4, 19.2), (.textPrimary, .surfaceCard, 16.8, 15.6), (.textSecondary, .surfaceCard, 5.0, 5.9),
        (.link, .surfaceCard, 4.6, 6.8), (.emphasis, .surfaceCard, 4.6, 6.8), (.underPar, .surfaceCard, 6.6, 10.3),
        (.scoreUnder, .surfaceCard, 4.3, 6.0), (.tintedText, .tintedFill, 5.8, 7.5), (.textOnTotals, .surfaceTotals, 14.4, 11.4),
        (.onAccent, .primaryAction, 4.6, 4.6), (.onAccent, .hazardFill, 4.3, 4.3), (.onAccent, .scoreNameUnder, 4.3, 4.3),
        (.onAccent, .scoreNameOver, 4.6, 4.6), (.onScoreNamePar, .scoreNamePar, 16.8, 16.8), (.onStatus, .statusFill, 8.1, 8.1),
        (.onWarningBadge, .warningBadge, 11.9, 11.9), (.onHazardChip, .hazardChipFill, 11.6, 11.6), (.onImagery, .imageryBackdrop, 16.8, 16.8),
        (.onImagerySecondary, .imageryBackdrop, 11.4, 11.4), (.onImageryUnderPar, .imageryBackdrop, 7.5, 7.5), (.playerOnDark, .playerLake, 4.6, 4.6),
        (.playerOnDark, .playerFlag, 4.3, 4.3), (.playerOnDark, .playerFairway, 4.3, 4.3), (.playerOnDark, .playerMoss, 5.0, 5.0),
        (.playerOnLight, .playerSand, 11.6, 11.6), (.compactTitle, .background, 19.2, 19.2),
    ])
    func pairings(text: DSColorToken, surface: DSColorToken, lightRatio: Double, darkRatio: Double) {
        for (traits, documented) in [(light, lightRatio), (dark, darkRatio)] {
            let card = DSColorToken.surfaceCard.uiColor(in: traits)
            let ratio = Contrast.ratio(text.uiColor(in: traits), surface.uiColor(in: traits), over: card)
            // DS-CL-02 / DS-DM-04: a floor, at least the documented ratio less 0.1 (the documented values are rounded).
            #expect(ratio >= documented - 0.1, "\(text) on \(surface), \(traits.userInterfaceStyle == .dark ? "dark" : "light"): \(ratio)")
        }
    }

    @Test func knownRatios() {
        #expect(abs(Contrast.ratio(.black, .white) - 21) < 0.01)
        #expect(abs(Contrast.ratio(.white, .white) - 1) < 0.0001)
        #expect(Contrast.ratio(.black, .white) == Contrast.ratio(.white, .black))
    }

    @Test func translucentColorsAreCompositedFirst() {
        // 50 % black over white is mid grey, about 3.9 : 1 against white.
        let half = UIColor(white: 0, alpha: 0.5)
        let ratio = Contrast.ratio(half, .white, over: .white)
        #expect((3.5...4.3).contains(ratio))
        let mixed = Contrast.composite(half, over: .white)
        #expect(abs(mixed.red - 0.5) < 0.01)
    }

    @Test func hexRoundsChannels() {
        #expect(Contrast.hex(UIColor(red: 1, green: 0.5, blue: 0, alpha: 1)) == "#FF8000")
        #expect(Contrast.luminance(red: 1, green: 1, blue: 1) == 1)
    }
}
