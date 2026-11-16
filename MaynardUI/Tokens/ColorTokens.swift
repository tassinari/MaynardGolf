//
//  ColorTokens.swift
//  MaynardUI
//

import SwiftUI
import UIKit

/// Every color in the design system (00-design-system §3), backed by a color set in `Colors.xcassets`.
///
/// Primitives (§3.1–3.3, §3.6) are fixed palette values. Semantic tokens (§3.7, plus the material and
/// player tokens) have a Light and a Dark value and follow the system appearance (DS-DM-01/02).
/// Screens use semantic tokens; a primitive only where the color is the same in both appearances.
public enum DSColorToken: String, CaseIterable, Sendable {
    // MARK: Primitives
    case canopy950
    case canopy800
    case rough700
    case rough600
    case fairway500
    case fringe400
    case green300
    case green200
    case bunker300
    case bunker100
    case bunker900
    case lake600
    case lake500
    case lake300
    case lake200
    case lake100
    case lake50
    case flag600
    case flag650
    case flag400
    case flag700D
    case chalk50
    case chalk200
    case chalk300
    case moss400
    case moss600
    case sage300
    case white
    case cardStripe
    case hairline
    case borderLine
    case teeGreen50
    case teeGreen100
    case teeGreen200
    case well
    case darkCard
    case raised
    case segmentSelectedDark
    case dividerDark
    case toggleOnDark
    // MARK: Semantic (Light / Dark)
    case background
    case surfaceCard
    case surfaceRaised
    case textPrimary
    case textSecondary
    case primaryAction
    case underPar
    case surfaceTotals
    case textOnTotals
    case textTertiary
    case link
    case tintedFill
    case tintedText
    case divider
    case cardBorder
    case tableStripe
    case currentHoleHighlight
    case hazardFill
    case success
    case toggleOn
    case toggleOff
    case segmentTrack
    case segmentSelected
    case scoreUnder
    case scoreBogeyOutline
    case scoreDoubleFill
    case scoreEmpty
    case avatarPlaceholder
    case photoDimming
    case onGlassFill
    case chipFill
    case scrimStroke
    case glassTint
    case glassTintStrong
    case scrim
    case scrimOpaque
    case playerLake
    case playerSand
    case playerFlag
    case playerFairway
    case playerMoss
    case playerOnDark
    case playerOnLight

    /// The primitive palette values (one value in both appearances).
    public static let primitives: [DSColorToken] = [.canopy950, .canopy800, .rough700, .rough600, .fairway500, .fringe400, .green300, .green200, .bunker300, .bunker100, .bunker900, .lake600, .lake500, .lake300, .lake200, .lake100, .lake50, .flag600, .flag650, .flag400, .flag700D, .chalk50, .chalk200, .chalk300, .moss400, .moss600, .sage300, .white, .cardStripe, .hairline, .borderLine, .teeGreen50, .teeGreen100, .teeGreen200, .well, .darkCard, .raised, .segmentSelectedDark, .dividerDark, .toggleOnDark]

    /// The tokens that switch with the appearance.
    public static let semantic: [DSColorToken] = [.background, .surfaceCard, .surfaceRaised, .textPrimary, .textSecondary, .primaryAction, .underPar, .surfaceTotals, .textOnTotals, .textTertiary, .link, .tintedFill, .tintedText, .divider, .cardBorder, .tableStripe, .currentHoleHighlight, .hazardFill, .success, .toggleOn, .toggleOff, .segmentTrack, .segmentSelected, .scoreUnder, .scoreBogeyOutline, .scoreDoubleFill, .scoreEmpty, .avatarPlaceholder, .photoDimming, .onGlassFill, .chipFill, .scrimStroke, .glassTint, .glassTintStrong, .scrim, .scrimOpaque, .playerLake, .playerSand, .playerFlag, .playerFairway, .playerMoss, .playerOnDark, .playerOnLight]

    /// Whether the asset catalog has a color set for this token.
    public var isInAssetCatalog: Bool {
        UIColor(named: rawValue, in: Bundle.maynardUI, compatibleWith: nil) != nil
    }

    /// A named color from the catalog resolved for `traits`, or magenta, so a missing color set shows
    /// loudly instead of crashing.
    static func resolve(named name: String, in traits: UITraitCollection) -> UIColor {
        (UIColor(named: name, in: Bundle.maynardUI, compatibleWith: traits) ?? .magenta).resolvedColor(with: traits)
    }

    /// The color resolved for a trait collection (light or dark), straight from the asset catalog. The
    /// named color is dynamic, so it's resolved explicitly; reading a dynamic color's components would
    /// otherwise use the current appearance.
    public func uiColor(in traits: UITraitCollection = .current) -> UIColor {
        Self.resolve(named: rawValue, in: traits)
    }
}

public extension Color {
    /// A design-system color (`Color(.ds.primaryAction)` style access is `Color.ds.primaryAction`).
    init(_ token: DSColorToken) {
        self.init(token.rawValue, bundle: Bundle.maynardUI)
    }

    /// The design-system palette: `Color.ds.textPrimary`, `Color.ds.lake600`, ...
    static let ds = DSColors()
}

/// Named access to every token as a SwiftUI `Color` (DS-CL, DS-DM).
public struct DSColors: Sendable {
    // MARK: Primitives
    public var canopy950: Color { Color(DSColorToken.canopy950) }
    public var canopy800: Color { Color(DSColorToken.canopy800) }
    public var rough700: Color { Color(DSColorToken.rough700) }
    public var rough600: Color { Color(DSColorToken.rough600) }
    public var fairway500: Color { Color(DSColorToken.fairway500) }
    public var fringe400: Color { Color(DSColorToken.fringe400) }
    public var green300: Color { Color(DSColorToken.green300) }
    public var green200: Color { Color(DSColorToken.green200) }
    public var bunker300: Color { Color(DSColorToken.bunker300) }
    public var bunker100: Color { Color(DSColorToken.bunker100) }
    public var bunker900: Color { Color(DSColorToken.bunker900) }
    public var lake600: Color { Color(DSColorToken.lake600) }
    public var lake500: Color { Color(DSColorToken.lake500) }
    public var lake300: Color { Color(DSColorToken.lake300) }
    public var lake200: Color { Color(DSColorToken.lake200) }
    public var lake100: Color { Color(DSColorToken.lake100) }
    public var lake50: Color { Color(DSColorToken.lake50) }
    public var flag600: Color { Color(DSColorToken.flag600) }
    public var flag650: Color { Color(DSColorToken.flag650) }
    public var flag400: Color { Color(DSColorToken.flag400) }
    public var flag700D: Color { Color(DSColorToken.flag700D) }
    public var chalk50: Color { Color(DSColorToken.chalk50) }
    public var chalk200: Color { Color(DSColorToken.chalk200) }
    public var chalk300: Color { Color(DSColorToken.chalk300) }
    public var moss400: Color { Color(DSColorToken.moss400) }
    public var moss600: Color { Color(DSColorToken.moss600) }
    public var sage300: Color { Color(DSColorToken.sage300) }
    public var white: Color { Color(DSColorToken.white) }
    public var cardStripe: Color { Color(DSColorToken.cardStripe) }
    public var hairline: Color { Color(DSColorToken.hairline) }
    public var borderLine: Color { Color(DSColorToken.borderLine) }
    public var teeGreen50: Color { Color(DSColorToken.teeGreen50) }
    public var teeGreen100: Color { Color(DSColorToken.teeGreen100) }
    public var teeGreen200: Color { Color(DSColorToken.teeGreen200) }
    public var well: Color { Color(DSColorToken.well) }
    public var darkCard: Color { Color(DSColorToken.darkCard) }
    public var raised: Color { Color(DSColorToken.raised) }
    public var segmentSelectedDark: Color { Color(DSColorToken.segmentSelectedDark) }
    public var dividerDark: Color { Color(DSColorToken.dividerDark) }
    public var toggleOnDark: Color { Color(DSColorToken.toggleOnDark) }
    // MARK: Semantic
    public var background: Color { Color(DSColorToken.background) }
    public var surfaceCard: Color { Color(DSColorToken.surfaceCard) }
    public var surfaceRaised: Color { Color(DSColorToken.surfaceRaised) }
    public var textPrimary: Color { Color(DSColorToken.textPrimary) }
    public var textSecondary: Color { Color(DSColorToken.textSecondary) }
    public var primaryAction: Color { Color(DSColorToken.primaryAction) }
    public var underPar: Color { Color(DSColorToken.underPar) }
    public var surfaceTotals: Color { Color(DSColorToken.surfaceTotals) }
    public var textOnTotals: Color { Color(DSColorToken.textOnTotals) }
    public var textTertiary: Color { Color(DSColorToken.textTertiary) }
    public var link: Color { Color(DSColorToken.link) }
    public var tintedFill: Color { Color(DSColorToken.tintedFill) }
    public var tintedText: Color { Color(DSColorToken.tintedText) }
    public var divider: Color { Color(DSColorToken.divider) }
    public var cardBorder: Color { Color(DSColorToken.cardBorder) }
    public var tableStripe: Color { Color(DSColorToken.tableStripe) }
    public var currentHoleHighlight: Color { Color(DSColorToken.currentHoleHighlight) }
    public var hazardFill: Color { Color(DSColorToken.hazardFill) }
    public var success: Color { Color(DSColorToken.success) }
    public var toggleOn: Color { Color(DSColorToken.toggleOn) }
    public var toggleOff: Color { Color(DSColorToken.toggleOff) }
    public var segmentTrack: Color { Color(DSColorToken.segmentTrack) }
    public var segmentSelected: Color { Color(DSColorToken.segmentSelected) }
    public var scoreUnder: Color { Color(DSColorToken.scoreUnder) }
    public var scoreBogeyOutline: Color { Color(DSColorToken.scoreBogeyOutline) }
    public var scoreDoubleFill: Color { Color(DSColorToken.scoreDoubleFill) }
    public var scoreEmpty: Color { Color(DSColorToken.scoreEmpty) }
    public var avatarPlaceholder: Color { Color(DSColorToken.avatarPlaceholder) }
    /// Multiplied into aerial photos: white (no change) in Light, 72 % grey in Dark (DS-MT-05).
    public var photoDimming: Color { Color(DSColorToken.photoDimming) }
    /// Fill of icon buttons on glass: white @ 18 % (DS-BT-09).
    public var onGlassFill: Color { Color(DSColorToken.onGlassFill) }
    /// `PlayerScoreChip` capsule: `#F4F2EA`, Raised in Dark (DS-CH-08).
    public var chipFill: Color { Color(DSColorToken.chipFill) }
    /// Inner stroke of Scrim buttons: Chalk @ 28 % (DS-BT-02).
    public var scrimStroke: Color { Color(DSColorToken.scrimStroke) }
    public var glassTint: Color { Color(DSColorToken.glassTint) }
    public var glassTintStrong: Color { Color(DSColorToken.glassTintStrong) }
    public var scrim: Color { Color(DSColorToken.scrim) }
    public var scrimOpaque: Color { Color(DSColorToken.scrimOpaque) }
    public var playerLake: Color { Color(DSColorToken.playerLake) }
    public var playerSand: Color { Color(DSColorToken.playerSand) }
    public var playerFlag: Color { Color(DSColorToken.playerFlag) }
    public var playerFairway: Color { Color(DSColorToken.playerFairway) }
    public var playerMoss: Color { Color(DSColorToken.playerMoss) }
    public var playerOnDark: Color { Color(DSColorToken.playerOnDark) }
    public var playerOnLight: Color { Color(DSColorToken.playerOnLight) }
}
