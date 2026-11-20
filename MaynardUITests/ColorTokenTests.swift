//
//  ColorTokenTests.swift
//  MaynardUITests
//

import SwiftUI
import Testing
import UIKit
@testable import MaynardUI

private let light = UITraitCollection(userInterfaceStyle: .light)
private let dark = UITraitCollection(userInterfaceStyle: .dark)

/// 00-design-system §3: every token resolves to its documented value (DS-DM-02/03).
struct ColorTokenTests {
    /// §3.1–3.3, §3.6 primitives, as documented.
    @Test(arguments: [
        (DSColorToken.canopy950, "#0F1A08"), (.canopy800, "#1C2D0C"), (.rough700, "#34431A"), (.rough600, "#416308"),
        (.fairway500, "#507A07"), (.fringe400, "#7E9C2A"), (.green300, "#99AD41"), (.green200, "#C4D88A"),
        (.bunker300, "#E5C48C"), (.bunker100, "#F4E6C8"), (.bunker900, "#2E2818"),
        (.lake600, "#1E5AA8"), (.lake500, "#2F6FC2"), (.lake300, "#7DB4F5"), (.lake200, "#A9D2FF"), (.lake100, "#D4E8FF"),
        (.lake50, "#E3ECF7"), (.flag600, "#C2410C"), (.flag650, "#A8380A"), (.flag400, "#FF9A3C"), (.flag700D, "#B5450E"), (.caution400, "#FFD60A"),
        (.chalk50, "#F7F5EC"), (.chalk200, "#E9E5D6"), (.chalk300, "#CFCBB8"), (.moss400, "#8E9A7C"), (.moss600, "#4E5A3E"),
        (.sage300, "#B8C2A6"), (.white, "#FFFFFF"), (.black, "#000000"), (.cardStripe, "#FBFAF5"), (.hairline, "#EFECE0"), (.borderLine, "#E4E1D2"),
        (.teeGreen50, "#E6EDD3"), (.teeGreen100, "#D4DEB4"), (.teeGreen200, "#C9D6A8"), (.well, "#0B1306"),
        (.darkCard, "#1A2614"), (.raised, "#243220"), (.segmentSelectedDark, "#3A4A33"), (.dividerDark, "#2F3D29"),
        (.toggleOnDark, "#6F9A2E"),
    ])
    func primitives(token: DSColorToken, hex: String) {
        #expect(Contrast.hex(token.uiColor(in: light)) == hex)
        #expect(Contrast.hex(token.uiColor(in: dark)) == hex) // the same in both appearances
    }

    /// §3.7 semantic tokens, Light → Dark (alpha for the translucent ones).
    @Test(arguments: [
        (DSColorToken.background, "#F7F5EC", "#0F1A08"), (.surfaceCard, "#FFFFFF", "#1A2614"), (.surfaceRaised, "#E9E5D6", "#243220"),
        (.textPrimary, "#0F1A08", "#F7F5EC"), (.textSecondary, "#4E5A3E", "#B8C2A6"), (.primaryAction, "#1E5AA8", "#2F6FC2"),
        (.underPar, "#A8380A", "#FF9A3C"), (.surfaceTotals, "#F4E6C8", "#2E2818"), (.textOnTotals, "#0F1A08", "#E5C48C"),
        (.textTertiary, "#8E9A7C", "#8E9A7C"), (.link, "#1E5AA8", "#7DB4F5"), (.tintedFill, "#E3ECF7", "#7DB4F5"),
        (.tintedText, "#1E5AA8", "#7DB4F5"), (.divider, "#EFECE0", "#2F3D29"), (.cardBorder, "#E4E1D2", "#2F3D29"),
        (.tableStripe, "#FBFAF5", "#1A2614"), (.currentHoleHighlight, "#E3ECF7", "#7DB4F5"), (.hazardFill, "#C2410C", "#B5450E"),
        (.success, "#416308", "#C4D88A"), (.toggleOn, "#416308", "#6F9A2E"), (.toggleOff, "#CFCBB8", "#243220"),
        (.segmentTrack, "#E9E5D6", "#243220"), (.segmentSelected, "#FFFFFF", "#3A4A33"), (.scoreUnder, "#C2410C", "#FF9A3C"),
        (.scoreBogeyOutline, "#1E5AA8", "#7DB4F5"), (.scoreDoubleFill, "#1E5AA8", "#2F6FC2"), (.scoreEmpty, "#CFCBB8", "#2F3D29"),
        (.avatarPlaceholder, "#E6EDD3", "#243220"), (.photoDimming, "#FFFFFF", "#B8B8B8"),
        (.onGlassFill, "#FFFFFF", "#FFFFFF"), (.chipFill, "#F4F2EA", "#243220"), (.scrimStroke, "#F7F5EC", "#F7F5EC"),
        (.glassTint, "#0F1A08", "#080D05"), (.glassTintStrong, "#0F1A08", "#080D05"), (.scrim, "#0F1A08", "#0F1A08"),
        (.scrimOpaque, "#1C2D0C", "#1C2D0C"),
        (.playerLake, "#1E5AA8", "#2F6FC2"), (.playerSand, "#E5C48C", "#E5C48C"), (.playerFlag, "#C2410C", "#C2410C"),
        (.playerFairway, "#416308", "#416308"), (.playerMoss, "#8E9A7C", "#8E9A7C"), (.playerOnDark, "#FFFFFF", "#FFFFFF"),
        (.playerOnLight, "#0F1A08", "#0F1A08"),
    ])
    func semantic(token: DSColorToken, lightHex: String, darkHex: String) {
        #expect(Contrast.hex(token.uiColor(in: light)) == lightHex, "\(token) light")
        #expect(Contrast.hex(token.uiColor(in: dark)) == darkHex, "\(token) dark")
    }

    @Test(arguments: [
        (DSColorToken.tintedFill, 1.0, 0.16), (.currentHoleHighlight, 1.0, 0.16), (.glassTint, 0.40, 0.62),
        (.glassTintStrong, 0.48, 0.74), (.scrim, 0.82, 0.82), (.onGlassFill, 0.18, 0.18), (.scrimStroke, 0.28, 0.28), (.scrimOpaque, 1.0, 1.0), (.background, 1.0, 1.0),
    ])
    func alpha(token: DSColorToken, lightAlpha: Double, darkAlpha: Double) {
        #expect(abs(Contrast.components(token.uiColor(in: light)).alpha - lightAlpha) < 0.01)
        #expect(abs(Contrast.components(token.uiColor(in: dark)).alpha - darkAlpha) < 0.01)
    }

    @Test func everyTokenIsInTheCatalogAndListedOnce() {
        #expect(Set(DSColorToken.primitives).union(DSColorToken.semantic) == Set(DSColorToken.allCases))
        #expect(DSColorToken.primitives.count + DSColorToken.semantic.count == DSColorToken.allCases.count)
        for token in DSColorToken.allCases {
            #expect(token.isInAssetCatalog, "\(token) missing")
        }
    }

    @Test func swiftUIAccessUsesTheTokens() {
        // Color.ds members resolve to the same asset as the token.
        let resolved = UIColor(Color.ds.primaryAction).resolvedColor(with: dark)
        #expect(Contrast.hex(resolved) == "#2F6FC2")
        #expect(Contrast.hex(UIColor(Color(DSColorToken.textPrimary)).resolvedColor(with: light)) == "#0F1A08")
    }
}

/// §3.5: player colors and their foregrounds; Lake is the only one that changes in Dark.
struct PlayerPaletteTests {
    @Test(arguments: [
        (PlayerPalette.lake, "#1E5AA8", "#2F6FC2", "#FFFFFF"), (.sand, "#E5C48C", "#E5C48C", "#0F1A08"),
        (.flag, "#C2410C", "#C2410C", "#FFFFFF"), (.fairway, "#416308", "#416308", "#FFFFFF"),
        (.moss, "#8E9A7C", "#8E9A7C", "#0F1A08"),
    ])
    func backgroundsAndForegrounds(color: PlayerPalette, lightHex: String, darkHex: String, foreground: String) {
        #expect(Contrast.hex(color.backgroundToken.uiColor(in: light)) == lightHex)
        #expect(Contrast.hex(color.backgroundToken.uiColor(in: dark)) == darkHex)
        #expect(Contrast.hex(color.foregroundToken.uiColor(in: light)) == foreground)
        // The SwiftUI colors are the same tokens.
        #expect(Contrast.hex(UIColor(color.background).resolvedColor(with: dark)) == darkHex)
        #expect(Contrast.hex(UIColor(color.foreground).resolvedColor(with: light)) == foreground)
    }

    @Test func matchesTheAppsStoredRawValues() {
        #expect(PlayerPalette.allCases.map(\.rawValue) == ["lake", "sand", "flag", "fairway", "moss"])
    }
}
