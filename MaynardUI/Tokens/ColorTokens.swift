//
//  ColorTokens.swift
//  MaynardUI
//

import SwiftUI
import UIKit

/// The design system's colors as roles (00-design-system §3.7): what a color is *for*, never what it looks
/// like. Each is a color set in `Colors.xcassets` with a Light and a Dark value, so every screen follows the
/// system appearance (DS-DM-01/02). Changing the look means changing color sets, not code.
///
/// These are the only colors outside MaynardUI's tokens: the palette they're drawn from, `DSPaletteColor`, is
/// internal, so the app can't reach a raw color (DS-CL-04). A role with no token yet gets a new token here.
public enum DSColorToken: String, CaseIterable, Sendable {
    // MARK: Surfaces
    /// The page behind cards and lists.
    case background
    /// Cards, grouped lists and sheets.
    case surfaceCard
    /// Neutral pills, tiles, table headers and raised fills.
    case surfaceRaised
    /// Hairline outlines where a border is wanted (cards themselves use `cardShadow`).
    case cardBorder
    /// The soft card shadow (DS-SH-04); clear in Dark.
    case cardShadow
    /// A card's hairline outline: clear in Light, white @ 6 % in Dark, where shadows don't show (DS-SH-04).
    case cardOutline
    /// The tint of `DSNavigationBar`'s blur: Gray 50 @ 78 %, black @ 72 % in Dark (DS-NV-01).
    case barTint
    /// Row dividers inside cards.
    case divider
    // MARK: Text
    /// Body text and titles.
    case textPrimary
    /// Captions, meta lines and secondary values.
    case textSecondary
    /// Placeholders, chevrons and empty-state icons.
    case textTertiary
    /// Text buttons and links.
    case link
    /// Blue as text, values, chart lines and selection outlines (the HCP index, Latest Scores); brighter than `primaryAction` in Dark.
    case emphasis
    /// Home's compact title over the system material (HOME-HDR-05): black in Light, white in Dark.
    case compactTitle
    // MARK: Actions and fills
    /// Primary buttons, selection and the hole-number badge.
    case primaryAction
    /// Text and icons on filled accents (primary buttons, filled score squares, badges).
    case onAccent
    /// Tinted and tertiary button fill.
    case tintedFill
    /// Tinted and tertiary button text.
    case tintedText
    /// Destructive fills behind white text.
    case hazardFill
    /// Success marks and glyphs.
    case success
    /// `StatusPill` fill (IN PROGRESS).
    case statusFill
    /// `StatusPill` text and dot.
    case onStatus
    /// `HazardChip` fill.
    case hazardChipFill
    /// `HazardChip` text.
    case onHazardChip
    /// The warning triangle on `GlassIconButton` (DS-BT-07).
    case warningBadge
    /// The warning badge's outline and mark.
    case onWarningBadge
    // MARK: Controls
    /// `DSToggle` on track.
    case toggleOn
    /// Off tracks and empty check rings.
    case toggleOff
    /// `DSSegmented` track.
    case segmentTrack
    /// `DSSegmented` selected segment.
    case segmentSelected
    /// The selected segment's lift; clear in Dark.
    case controlShadow
    /// The gap ring around a selected color swatch: the card color.
    case swatchRing
    /// An avatar without a photo or color.
    case avatarPlaceholder
    /// `PlayerScoreChip` tile (DS-CH-08).
    case chipFill
    /// The `PlayerScoreChip` tile holding the round's lowest gross (DS-CH-08).
    case chipHighlight
    // MARK: Scores and tables
    /// Under-par numbers on app surfaces.
    case underPar
    /// OUT / IN / TOT rows and columns.
    case surfaceTotals
    /// The top border of total rows.
    case totalsBorder
    /// Text on total rows.
    case textOnTotals
    /// Alternating table rows.
    case tableStripe
    /// A scorecard header's bottom border, dashed empty boxes and the portrait column lines (SC-PT-04).
    case tableHeaderBorder
    /// The current hole's row or column.
    case currentHoleHighlight
    /// Rounds that count toward the index (HS-LS-04).
    case countingHighlight
    /// Birdie and eagle circles.
    case scoreUnder
    /// Bogey squares.
    case scoreBogeyOutline
    /// Double-bogey-or-worse squares.
    case scoreDoubleFill
    /// An unplayed hole's dot.
    case scoreEmpty
    /// `ScoreNameBadge` under par: Red 700, not the board's Red 500, so its 13 pt white label meets 4.5 : 1 (X-06).
    case scoreNameUnder
    /// `ScoreNameBadge` at par.
    case scoreNamePar
    /// Text on the par badge.
    case onScoreNamePar
    /// `ScoreNameBadge` over par.
    case scoreNameOver
    /// Scores by Hole bars under par (PC-SH-04).
    case scoreBinUnder
    /// Scores by Hole bars at par.
    case scoreBinPar
    /// Scores by Hole bars one over par.
    case scoreBinBogey
    /// Scores by Hole bars two or more over par.
    case scoreBinDouble
    /// Chart legend labels (Scores by Hole): Gray 700, light gray in Dark.
    case chartLegend
    /// Latest Scores' best-round point (PC-LS-05).
    case bestScoreMarker
    // MARK: Imagery: over photos and glass, the same in both appearances (DS-DM-05)
    /// Text, icons, rings and the shot line over photos and glass.
    case onImagery
    /// Secondary labels on glass (HCP, PAR, TO PIN).
    case onImagerySecondary
    /// Units and muted labels on scrims.
    case onImageryTertiary
    /// Under-par numbers on glass.
    case onImageryUnderPar
    /// `HoleScoreChip`'s tinted fill and borders (at reduced opacity).
    case onImageryAccent
    /// Text on a white fill over imagery (selected quick pick, badges).
    case onImageryInverse
    /// Behind photos while they load, the hole map's edges and dark chips over imagery.
    case imageryBackdrop
    /// Text shadows, dimming and marker outlines over imagery (at reduced opacity).
    case imageryShadow
    /// The pin, the target's center and the pin chip's flag.
    case markerAccent
    /// The player's position on the map (DS-OV-12).
    case locationDot
    /// Multiplied into aerial photos: white (no change) in Light, 72 % grey in Dark (DS-MT-05).
    case photoDimming
    /// Fill of icon buttons on glass: white @ 18 % (DS-BT-09).
    case onGlassFill
    /// Inner stroke of Scrim buttons: white @ 28 % (DS-BT-02).
    case scrimStroke
    /// Glass tint (DS-MT-06).
    case glassTint
    /// The leaderboard's deeper glass tint.
    case glassTintStrong
    /// Scrim fill (DS-MT-02).
    case scrim
    /// The scrim with Reduce Transparency (DS-MT-04).
    case scrimOpaque
    // MARK: Tees (DS-GF-06)
    /// Blue tees.
    case teeBlue
    /// White tees.
    case teeWhite
    /// Yellow tees.
    case teeYellow
    /// Red tees.
    case teeRed
    /// The ring that keeps a white tee's dot visible.
    case teeWhiteRing
    // MARK: Players (§3.5)
    case playerLake
    case playerSand
    case playerFlag
    case playerFairway
    case playerMoss
    /// Initials on the darker player colors.
    case playerOnDark
    /// Initials on Sand.
    case playerOnLight
    // MARK: Placeholder imagery: mock photos and previews only
    /// Turf in placeholder imagery.
    case placeholderTurf
    /// Mowing stripes in placeholder imagery.
    case placeholderTurfStripe
    /// Bunkers in placeholder imagery.
    case placeholderSand

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

/// The Fairway C palette (00-design-system §3.1–3.3): the Blue, Gray, Green, Orange and Red ramps and a few
/// support colors, one value in both appearances. Internal on purpose: semantic tokens are drawn from it, and
/// only MaynardUI's tokens, catalog and tests read it (DS-CL-04).
enum DSPaletteColor: String, CaseIterable, Sendable {
    case blue50
    case blue100
    case blue200
    case blue300
    case blue500
    case blue600
    case blue900
    case gray50
    case gray100
    case gray300
    case gray400
    case gray500
    case gray700
    case gray900
    case green50
    case green100
    case green300
    case green400
    case green500
    case green700
    case green900
    case orange50
    case orange100
    case orange300
    case orange500
    case orange700
    case orange900
    case red50
    case red100
    case red300
    case red500
    case red700
    case red900
    case teal500
    /// Separator `#E5E5EA`.
    case separator
    /// Hairline `#F0F0F3`.
    case hairline
    /// Field Fill `#EEEEF1`.
    case fieldFill
    /// Yellow `#F2C94C` (the yellow tee).
    case yellow400
    /// Caution `#FFD60A`.
    case caution400
    /// White.
    case white
    /// Black.
    case black
    case dark1
    case dark2
    case dark3
    case dark4
    case dark5
    case dark6
    case dark7
    case blue400
    case darkBlueTint
    case darkBlueWash
    case red400
    case dark8

    /// Whether the asset catalog has a color set for this color.
    var isInAssetCatalog: Bool {
        UIColor(named: rawValue, in: Bundle.maynardUI, compatibleWith: nil) != nil
    }

    /// The color resolved for a trait collection; palette colors are the same in both.
    func uiColor(in traits: UITraitCollection = .current) -> UIColor {
        DSColorToken.resolve(named: rawValue, in: traits)
    }
}

public extension Color {
    /// A design-system color (`Color(.primaryAction)`; usually `Color.ds.primaryAction`).
    init(_ token: DSColorToken) {
        self.init(token.rawValue, bundle: Bundle.maynardUI)
    }

    /// The design-system colors by role: `Color.ds.textPrimary`, `Color.ds.onImagery`, ...
    static let ds = DSColors()
}

extension Color {
    /// A palette color, for MaynardUI's catalog and tests.
    init(palette color: DSPaletteColor) {
        self.init(color.rawValue, bundle: Bundle.maynardUI)
    }

    /// The palette by name (`Color.palette.blue500`), internal to MaynardUI.
    static let palette = DSPalette()
}

/// Named access to every semantic token as a SwiftUI `Color` (DS-CL, DS-DM).
public struct DSColors: Sendable {
    // MARK: Surfaces
    public var background: Color { Color(DSColorToken.background) }
    public var surfaceCard: Color { Color(DSColorToken.surfaceCard) }
    public var surfaceRaised: Color { Color(DSColorToken.surfaceRaised) }
    public var cardBorder: Color { Color(DSColorToken.cardBorder) }
    public var cardShadow: Color { Color(DSColorToken.cardShadow) }
    public var cardOutline: Color { Color(DSColorToken.cardOutline) }
    public var barTint: Color { Color(DSColorToken.barTint) }
    public var divider: Color { Color(DSColorToken.divider) }
    // MARK: Text
    public var textPrimary: Color { Color(DSColorToken.textPrimary) }
    public var textSecondary: Color { Color(DSColorToken.textSecondary) }
    public var textTertiary: Color { Color(DSColorToken.textTertiary) }
    public var link: Color { Color(DSColorToken.link) }
    public var emphasis: Color { Color(DSColorToken.emphasis) }
    public var compactTitle: Color { Color(DSColorToken.compactTitle) }
    // MARK: Actions and fills
    public var primaryAction: Color { Color(DSColorToken.primaryAction) }
    public var onAccent: Color { Color(DSColorToken.onAccent) }
    public var tintedFill: Color { Color(DSColorToken.tintedFill) }
    public var tintedText: Color { Color(DSColorToken.tintedText) }
    public var hazardFill: Color { Color(DSColorToken.hazardFill) }
    public var success: Color { Color(DSColorToken.success) }
    public var statusFill: Color { Color(DSColorToken.statusFill) }
    public var onStatus: Color { Color(DSColorToken.onStatus) }
    public var hazardChipFill: Color { Color(DSColorToken.hazardChipFill) }
    public var onHazardChip: Color { Color(DSColorToken.onHazardChip) }
    public var warningBadge: Color { Color(DSColorToken.warningBadge) }
    public var onWarningBadge: Color { Color(DSColorToken.onWarningBadge) }
    // MARK: Controls
    public var toggleOn: Color { Color(DSColorToken.toggleOn) }
    public var toggleOff: Color { Color(DSColorToken.toggleOff) }
    public var segmentTrack: Color { Color(DSColorToken.segmentTrack) }
    public var segmentSelected: Color { Color(DSColorToken.segmentSelected) }
    public var controlShadow: Color { Color(DSColorToken.controlShadow) }
    public var swatchRing: Color { Color(DSColorToken.swatchRing) }
    public var avatarPlaceholder: Color { Color(DSColorToken.avatarPlaceholder) }
    public var chipFill: Color { Color(DSColorToken.chipFill) }
    public var chipHighlight: Color { Color(DSColorToken.chipHighlight) }
    // MARK: Scores and tables
    public var underPar: Color { Color(DSColorToken.underPar) }
    public var surfaceTotals: Color { Color(DSColorToken.surfaceTotals) }
    public var totalsBorder: Color { Color(DSColorToken.totalsBorder) }
    public var textOnTotals: Color { Color(DSColorToken.textOnTotals) }
    public var tableStripe: Color { Color(DSColorToken.tableStripe) }
    public var tableHeaderBorder: Color { Color(DSColorToken.tableHeaderBorder) }
    public var currentHoleHighlight: Color { Color(DSColorToken.currentHoleHighlight) }
    public var countingHighlight: Color { Color(DSColorToken.countingHighlight) }
    public var scoreUnder: Color { Color(DSColorToken.scoreUnder) }
    public var scoreBogeyOutline: Color { Color(DSColorToken.scoreBogeyOutline) }
    public var scoreDoubleFill: Color { Color(DSColorToken.scoreDoubleFill) }
    public var scoreEmpty: Color { Color(DSColorToken.scoreEmpty) }
    public var scoreNameUnder: Color { Color(DSColorToken.scoreNameUnder) }
    public var scoreNamePar: Color { Color(DSColorToken.scoreNamePar) }
    public var onScoreNamePar: Color { Color(DSColorToken.onScoreNamePar) }
    public var scoreNameOver: Color { Color(DSColorToken.scoreNameOver) }
    public var scoreBinUnder: Color { Color(DSColorToken.scoreBinUnder) }
    public var scoreBinPar: Color { Color(DSColorToken.scoreBinPar) }
    public var scoreBinBogey: Color { Color(DSColorToken.scoreBinBogey) }
    public var scoreBinDouble: Color { Color(DSColorToken.scoreBinDouble) }
    public var chartLegend: Color { Color(DSColorToken.chartLegend) }
    public var bestScoreMarker: Color { Color(DSColorToken.bestScoreMarker) }
    // MARK: Imagery: over photos and glass, the same in both appearances (DS-DM-05)
    public var onImagery: Color { Color(DSColorToken.onImagery) }
    public var onImagerySecondary: Color { Color(DSColorToken.onImagerySecondary) }
    public var onImageryTertiary: Color { Color(DSColorToken.onImageryTertiary) }
    public var onImageryUnderPar: Color { Color(DSColorToken.onImageryUnderPar) }
    public var onImageryAccent: Color { Color(DSColorToken.onImageryAccent) }
    public var onImageryInverse: Color { Color(DSColorToken.onImageryInverse) }
    public var imageryBackdrop: Color { Color(DSColorToken.imageryBackdrop) }
    public var imageryShadow: Color { Color(DSColorToken.imageryShadow) }
    public var markerAccent: Color { Color(DSColorToken.markerAccent) }
    public var locationDot: Color { Color(DSColorToken.locationDot) }
    public var photoDimming: Color { Color(DSColorToken.photoDimming) }
    public var onGlassFill: Color { Color(DSColorToken.onGlassFill) }
    public var scrimStroke: Color { Color(DSColorToken.scrimStroke) }
    public var glassTint: Color { Color(DSColorToken.glassTint) }
    public var glassTintStrong: Color { Color(DSColorToken.glassTintStrong) }
    public var scrim: Color { Color(DSColorToken.scrim) }
    public var scrimOpaque: Color { Color(DSColorToken.scrimOpaque) }
    // MARK: Tees (DS-GF-06)
    public var teeBlue: Color { Color(DSColorToken.teeBlue) }
    public var teeWhite: Color { Color(DSColorToken.teeWhite) }
    public var teeYellow: Color { Color(DSColorToken.teeYellow) }
    public var teeRed: Color { Color(DSColorToken.teeRed) }
    public var teeWhiteRing: Color { Color(DSColorToken.teeWhiteRing) }
    // MARK: Players (§3.5)
    public var playerLake: Color { Color(DSColorToken.playerLake) }
    public var playerSand: Color { Color(DSColorToken.playerSand) }
    public var playerFlag: Color { Color(DSColorToken.playerFlag) }
    public var playerFairway: Color { Color(DSColorToken.playerFairway) }
    public var playerMoss: Color { Color(DSColorToken.playerMoss) }
    public var playerOnDark: Color { Color(DSColorToken.playerOnDark) }
    public var playerOnLight: Color { Color(DSColorToken.playerOnLight) }
    // MARK: Placeholder imagery: mock photos and previews only
    public var placeholderTurf: Color { Color(DSColorToken.placeholderTurf) }
    public var placeholderTurfStripe: Color { Color(DSColorToken.placeholderTurfStripe) }
    public var placeholderSand: Color { Color(DSColorToken.placeholderSand) }
}

/// Named access to the palette, internal to MaynardUI (DS-CL-04).
struct DSPalette: Sendable {
    var blue50: Color { Color(palette: .blue50) }
    var blue100: Color { Color(palette: .blue100) }
    var blue200: Color { Color(palette: .blue200) }
    var blue300: Color { Color(palette: .blue300) }
    var blue500: Color { Color(palette: .blue500) }
    var blue600: Color { Color(palette: .blue600) }
    var blue900: Color { Color(palette: .blue900) }
    var gray50: Color { Color(palette: .gray50) }
    var gray100: Color { Color(palette: .gray100) }
    var gray300: Color { Color(palette: .gray300) }
    var gray400: Color { Color(palette: .gray400) }
    var gray500: Color { Color(palette: .gray500) }
    var gray700: Color { Color(palette: .gray700) }
    var gray900: Color { Color(palette: .gray900) }
    var green50: Color { Color(palette: .green50) }
    var green100: Color { Color(palette: .green100) }
    var green300: Color { Color(palette: .green300) }
    var green400: Color { Color(palette: .green400) }
    var green500: Color { Color(palette: .green500) }
    var green700: Color { Color(palette: .green700) }
    var green900: Color { Color(palette: .green900) }
    var orange50: Color { Color(palette: .orange50) }
    var orange100: Color { Color(palette: .orange100) }
    var orange300: Color { Color(palette: .orange300) }
    var orange500: Color { Color(palette: .orange500) }
    var orange700: Color { Color(palette: .orange700) }
    var orange900: Color { Color(palette: .orange900) }
    var red50: Color { Color(palette: .red50) }
    var red100: Color { Color(palette: .red100) }
    var red300: Color { Color(palette: .red300) }
    var red500: Color { Color(palette: .red500) }
    var red700: Color { Color(palette: .red700) }
    var red900: Color { Color(palette: .red900) }
    var teal500: Color { Color(palette: .teal500) }
    var separator: Color { Color(palette: .separator) }
    var hairline: Color { Color(palette: .hairline) }
    var fieldFill: Color { Color(palette: .fieldFill) }
    var yellow400: Color { Color(palette: .yellow400) }
    var caution400: Color { Color(palette: .caution400) }
    var white: Color { Color(palette: .white) }
    var black: Color { Color(palette: .black) }
    var dark1: Color { Color(palette: .dark1) }
    var dark2: Color { Color(palette: .dark2) }
    var dark3: Color { Color(palette: .dark3) }
    var dark4: Color { Color(palette: .dark4) }
    var dark5: Color { Color(palette: .dark5) }
    var dark6: Color { Color(palette: .dark6) }
    var dark7: Color { Color(palette: .dark7) }
    var blue400: Color { Color(palette: .blue400) }
    var darkBlueTint: Color { Color(palette: .darkBlueTint) }
    var darkBlueWash: Color { Color(palette: .darkBlueWash) }
    var red400: Color { Color(palette: .red400) }
    var dark8: Color { Color(palette: .dark8) }
}
