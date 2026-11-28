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
    /// §3.1–3.3 palette, as documented.
    @Test(arguments: [
        (DSPaletteColor.blue50, "#F0F7FF"), (.blue100, "#E1EFFE"), (.blue200, "#B8D8FA"), (.blue300, "#8DBFF5"),
        (.blue500, "#0071E3"), (.blue600, "#0058B9"), (.blue900, "#06305E"), (.gray50, "#F5F5F7"),
        (.gray100, "#E8E8ED"), (.gray300, "#C7C7CC"), (.gray400, "#AEAEB2"), (.gray500, "#6E6E73"),
        (.gray700, "#424245"), (.gray900, "#1D1D1F"), (.green50, "#EFFAF2"), (.green100, "#D7F3DF"),
        (.green300, "#8EDBA5"), (.green400, "#34C759"), (.green500, "#248A3D"), (.green700, "#176B2C"),
        (.green900, "#0B3D19"), (.orange50, "#FFF7EA"), (.orange100, "#FFEBCC"), (.orange300, "#FFCF85"),
        (.orange500, "#FF9F0A"), (.orange700, "#9A5A00"), (.orange900, "#4D2D00"), (.red50, "#FFF1F0"),
        (.red100, "#FFDEDC"), (.red300, "#FFA7A1"), (.red500, "#E5352B"), (.red700, "#B3231B"),
        (.red900, "#5C100B"), (.teal500, "#30B0C7"), (.separator, "#E5E5EA"), (.hairline, "#F0F0F3"),
        (.fieldFill, "#EEEEF1"), (.yellow400, "#F2C94C"), (.caution400, "#FFD60A"), (.white, "#FFFFFF"),
        (.black, "#000000"), (.dark1, "#1C1C1E"), (.dark2, "#2C2C2E"), (.dark3, "#38383A"),
        (.dark4, "#3A3A3C"), (.dark5, "#48484A"), (.dark6, "#636366"), (.dark7, "#98989D"),
        (.blue400, "#5AA9F5"), (.darkBlueTint, "#0B2A4A"), (.darkBlueWash, "#0B2038"), (.red400, "#FF6961"),
        (.dark8, "#D1D1D6"),
    ])
    func primitives(token: DSPaletteColor, hex: String) {
        #expect(Contrast.hex(token.uiColor(in: light)) == hex)
        #expect(Contrast.hex(token.uiColor(in: dark)) == hex) // the same in both appearances
    }

    /// §3.7 semantic tokens, Light → Dark (alpha for the translucent ones).
    @Test(arguments: [
        (DSColorToken.background, "#F5F5F7", "#000000"), (.surfaceCard, "#FFFFFF", "#1C1C1E"), (.surfaceRaised, "#E8E8ED", "#2C2C2E"),
        (.textPrimary, "#1D1D1F", "#F5F5F7"), (.textSecondary, "#6E6E73", "#98989D"), (.textTertiary, "#AEAEB2", "#636366"),
        (.primaryAction, "#0071E3", "#0071E3"), (.underPar, "#176B2C", "#8EDBA5"), (.surfaceTotals, "#FFEBCC", "#4D2D00"),
        (.totalsBorder, "#FFCF85", "#9A5A00"), (.textOnTotals, "#1D1D1F", "#F5F5F7"), (.link, "#0071E3", "#5AA9F5"),
        (.emphasis, "#0071E3", "#5AA9F5"), (.tintedFill, "#E1EFFE", "#0B2A4A"), (.tintedText, "#0058B9", "#8DBFF5"),
        (.divider, "#F0F0F3", "#38383A"), (.cardBorder, "#E5E5EA", "#38383A"), (.cardShadow, "#000000", "#000000"),
        (.cardOutline, "#FFFFFF", "#FFFFFF"), (.barTint, "#F5F5F7", "#000000"), (.tableStripe, "#F5F5F7", "#000000"),
        (.tableHeaderBorder, "#C7C7CC", "#48484A"), (.currentHoleHighlight, "#E1EFFE", "#0B2A4A"), (.countingHighlight, "#F0F7FF", "#0B2038"),
        (.hazardFill, "#E5352B", "#E5352B"), (.success, "#248A3D", "#34C759"), (.toggleOn, "#34C759", "#34C759"),
        (.toggleOff, "#E5E5EA", "#3A3A3C"), (.segmentTrack, "#EEEEF1", "#2C2C2E"), (.segmentSelected, "#FFFFFF", "#636366"),
        (.scoreUnder, "#E5352B", "#FF6961"), (.scoreBogeyOutline, "#0071E3", "#5AA9F5"), (.scoreDoubleFill, "#5AA9F5", "#5AA9F5"),
        (.scoreEmpty, "#C7C7CC", "#636366"), (.avatarPlaceholder, "#E8E8ED", "#2C2C2E"), (.photoDimming, "#FFFFFF", "#B8B8B8"),
        (.onGlassFill, "#FFFFFF", "#FFFFFF"), (.chipFill, "#F5F5F7", "#000000"), (.chipHighlight, "#E1EFFE", "#0B2A4A"),
        (.scrimStroke, "#FFFFFF", "#FFFFFF"), (.glassTint, "#1D1D1F", "#000000"), (.glassTintStrong, "#1D1D1F", "#000000"),
        (.scrim, "#1D1D1F", "#1D1D1F"), (.scrimOpaque, "#1D1D1F", "#1D1D1F"), (.onImagery, "#FFFFFF", "#FFFFFF"),
        (.onImagerySecondary, "#B8D8FA", "#B8D8FA"), (.onImageryTertiary, "#AEAEB2", "#AEAEB2"), (.onImageryUnderPar, "#34C759", "#34C759"),
        (.onImageryAccent, "#8DBFF5", "#8DBFF5"), (.onImageryInverse, "#1D1D1F", "#1D1D1F"), (.imageryBackdrop, "#1D1D1F", "#1D1D1F"),
        (.imageryShadow, "#000000", "#000000"), (.markerAccent, "#FF9F0A", "#FF9F0A"), (.locationDot, "#0071E3", "#0071E3"),
        (.onAccent, "#FFFFFF", "#FFFFFF"), (.statusFill, "#FF9F0A", "#FF9F0A"), (.onStatus, "#1D1D1F", "#1D1D1F"),
        (.hazardChipFill, "#FFCF85", "#FFCF85"), (.onHazardChip, "#1D1D1F", "#1D1D1F"), (.warningBadge, "#FFD60A", "#FFD60A"),
        (.onWarningBadge, "#1D1D1F", "#1D1D1F"), (.scoreNameUnder, "#B3231B", "#B3231B"), (.scoreNamePar, "#FFFFFF", "#FFFFFF"),
        (.onScoreNamePar, "#1D1D1F", "#1D1D1F"), (.scoreNameOver, "#0071E3", "#0071E3"), (.teeBlue, "#0071E3", "#0071E3"),
        (.teeWhite, "#FFFFFF", "#FFFFFF"), (.teeYellow, "#F2C94C", "#F2C94C"), (.teeRed, "#E5352B", "#E5352B"),
        (.teeWhiteRing, "#C7C7CC", "#C7C7CC"), (.scoreBinEagle, "#AF52DE", "#AF52DE"), (.scoreBinBirdie, "#0071E3", "#5AA9F5"), (.scoreBinPar, "#34C759", "#34C759"),
        (.scoreBinBogey, "#FFCC00", "#FFCC00"), (.scoreBinDouble, "#FF9F0A", "#FF9F0A"), (.scoreBinWorse, "#E5352B", "#E5352B"), (.chartLegend, "#424245", "#D1D1D6"),
        (.bestScoreMarker, "#FF9F0A", "#FF9F0A"), (.compactTitle, "#000000", "#F5F5F7"), (.controlShadow, "#000000", "#000000"),
        (.swatchRing, "#FFFFFF", "#000000"), (.placeholderTurf, "#507A07", "#507A07"), (.placeholderTurfStripe, "#416308", "#416308"),
        (.placeholderSand, "#FFCF85", "#FFCF85"), (.playerLake, "#0071E3", "#0071E3"), (.playerSand, "#FFCF85", "#FFCF85"),
        (.playerFlag, "#E5352B", "#E5352B"), (.playerFairway, "#248A3D", "#248A3D"), (.playerMoss, "#6E6E73", "#6E6E73"),
        (.playerOnDark, "#FFFFFF", "#FFFFFF"), (.playerOnLight, "#1D1D1F", "#1D1D1F"),
    ])
    func semantic(token: DSColorToken, lightHex: String, darkHex: String) {
        #expect(Contrast.hex(token.uiColor(in: light)) == lightHex, "\(token) light")
        #expect(Contrast.hex(token.uiColor(in: dark)) == darkHex, "\(token) dark")
    }

    @Test(arguments: [
        (DSColorToken.cardShadow, 0.04, 0.00), (.cardOutline, 0.00, 0.06), (.barTint, 0.78, 0.72), (.onGlassFill, 0.18, 0.18),
        (.scrimStroke, 0.28, 0.28), (.glassTint, 0.40, 0.62), (.glassTintStrong, 0.48, 0.74), (.scrim, 0.82, 0.82),
        (.controlShadow, 0.14, 0.14), (.scrimOpaque, 1.00, 1.00), (.background, 1.00, 1.00),
    ])
    func alpha(token: DSColorToken, lightAlpha: Double, darkAlpha: Double) {
        #expect(abs(Contrast.components(token.uiColor(in: light)).alpha - lightAlpha) < 0.01)
        #expect(abs(Contrast.components(token.uiColor(in: dark)).alpha - darkAlpha) < 0.01)
    }

    @Test func everyTokenIsInTheCatalogAndListedOnce() {
        for token in DSColorToken.allCases {
            #expect(token.isInAssetCatalog, "\(token) missing")
        }
        for color in DSPaletteColor.allCases {
            #expect(color.isInAssetCatalog, "\(color) missing")
        }
        // DS-CL-04: a role and a palette color never share a color set.
        #expect(Set(DSColorToken.allCases.map(\.rawValue)).isDisjoint(with: DSPaletteColor.allCases.map(\.rawValue)))
    }

    @Test func swiftUIAccessUsesTheTokens() {
        // Color.ds members resolve to the same asset as the token.
        let resolved = UIColor(Color.ds.link).resolvedColor(with: dark)
        #expect(Contrast.hex(resolved) == "#5AA9F5")
        #expect(Contrast.hex(UIColor(Color(DSColorToken.textPrimary)).resolvedColor(with: light)) == "#1D1D1F")
    }
}

/// §3.5: player colors and their foregrounds; all are flat and keep their value in Dark.
struct PlayerPaletteTests {
    @Test(arguments: [
        (PlayerPalette.lake, "#0071E3", "#0071E3", "#FFFFFF"), (.sand, "#FFCF85", "#FFCF85", "#1D1D1F"),
        (.flag, "#E5352B", "#E5352B", "#FFFFFF"), (.fairway, "#248A3D", "#248A3D", "#FFFFFF"),
        (.moss, "#6E6E73", "#6E6E73", "#FFFFFF"),
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
