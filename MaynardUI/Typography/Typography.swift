//
//  Typography.swift
//  MaynardUI
//

import SwiftUI
import UIKit

/// The type styles (00-design-system §4). All are the system font, SF Pro (DS-TY-01): the system picks
/// SF Pro Display or Text from the size. Each style scales with Dynamic Type relative to the nearest text
/// style (DS-TY-02). Apply with `.dsFont(.title)`, which follows the environment's Dynamic Type size, so
/// previews and UI tests can set it.
public enum DSTextStyle: String, CaseIterable, Sendable {
    /// Display 72, bold: "Hole 7".
    case display
    /// Title XL 44, bold: the Home hero.
    case titleXL
    /// Numeral 40, semibold, tabular: "148 · 162 · 175".
    case numeral
    /// Title 28, bold: sheet titles.
    case title
    /// Section 22, bold, caps with +0.06 em tracking: "PLAYERS".
    case section
    /// Label 13, semibold, caps with +0.12 em tracking: "TO PIN".
    case label
    /// Label 11, semibold caps: small chips and captions over imagery.
    case labelSmall
    /// Body 16, regular: running text, rows, buttons.
    case body
    /// Body 16, semibold: emphasized rows and button titles.
    case bodyEmphasized
    /// Caption 13, regular: secondary text.
    case caption
    /// Chip numeral 24, bold, tabular: the value on `YardageChip` (DS-CH-01). Caps at XXXL (X-07).
    case chipNumeral
    /// Score numeral 16, bold, tabular: the score on `PlayerScoreChip` (DS-CH-08). Caps at XXXL (X-07).
    case scoreNumeral
    /// Card name 20, semibold: the player's name on `PlayerSummaryCard` (DS-CN-13).
    case cardName
    /// Date day 22, bold, tabular: the day number on `RoundRow` (DS-CN-04). Caps at XXXL (X-07).
    case dateDay
    /// Hole stat 26, bold, tabular: "PAR 4" on `HoleInfoCard` and the `YardagePanel` numbers. Caps at XXXL.
    case holeStat
    /// Hole yards 21, semibold, tabular: "380 YDS" on `HoleInfoCard`. Caps at XXXL.
    case holeYards
    /// Hole handicap 17, semibold, tabular: "HCP 7" on `HoleInfoCard`. Caps at XXXL.
    case holeHandicap
    /// Label 10, semibold caps with +0.14 em tracking: "TO PIN" on `YardagePanel` (SL-YD-02).
    case labelMicro

    /// Point size at the default (Large) content size.
    public var size: CGFloat {
        switch self {
        case .display: 72
        case .titleXL: 44
        case .numeral: 40
        case .title: 28
        case .section: 22
        case .label, .caption: 13
        case .labelSmall: 11
        case .body, .bodyEmphasized, .scoreNumeral: 16
        case .chipNumeral: 24
        case .cardName: 20
        case .dateDay: 22
        case .holeStat: 26
        case .holeYards: 21
        case .holeHandicap: 17
        case .labelMicro: 10
        }
    }

    public var weight: Font.Weight {
        switch self {
        case .display, .titleXL, .title, .section, .chipNumeral, .scoreNumeral, .dateDay, .holeStat: .bold
        case .numeral, .label, .labelSmall, .bodyEmphasized, .cardName, .holeYards, .holeHandicap, .labelMicro: .semibold
        case .body, .caption: .regular
        }
    }

    /// The text style it scales with.
    public var relativeTo: UIFont.TextStyle {
        switch self {
        case .display, .titleXL: .largeTitle
        case .numeral, .title: .title1
        case .chipNumeral, .cardName: .title3
        case .dateDay, .holeStat: .title2
        case .holeYards: .title3
        case .holeHandicap: .headline
        case .labelMicro: .caption2
        case .section: .title2
        case .label, .labelSmall, .caption: .caption1
        case .body, .bodyEmphasized, .scoreNumeral: .body
        }
    }

    /// Caps tracking in em for label styles (DS-TY-03), nil for the rest.
    public var capsTracking: CGFloat? {
        switch self {
        case .section: 0.06
        case .label, .labelSmall: 0.12
        case .labelMicro: 0.14
        default: nil
        }
    }

    /// Whether the style is a tabular numeral.
    public var isNumeral: Bool {
        [.numeral, .chipNumeral, .scoreNumeral, .dateDay, .holeStat, .holeYards, .holeHandicap].contains(self)
    }

    /// The largest content size the style grows to: numerals stop at XXXL (X-07), so big score and
    /// yardage figures don't push the layout apart; everything else grows to AX5.
    public var maximumCategory: UIContentSizeCategory {
        isNumeral ? .extraExtraExtraLarge : .accessibilityExtraExtraExtraLarge
    }

    /// The size at a Dynamic Type content size (UIFontMetrics, so it matches system scaling), capped at
    /// `maximumCategory`.
    public func scaledSize(for category: UIContentSizeCategory) -> CGFloat {
        let capped = category > maximumCategory ? maximumCategory : category
        return UIFontMetrics(forTextStyle: relativeTo)
            .scaledValue(for: size, compatibleWith: UITraitCollection(preferredContentSizeCategory: capped))
    }

    /// The font at a content size.
    public func font(for category: UIContentSizeCategory = .large) -> Font {
        .system(size: scaledSize(for: category), weight: weight)
    }
}

public extension UIContentSizeCategory {
    /// The UIKit category for a SwiftUI Dynamic Type size.
    init(_ size: DynamicTypeSize) {
        switch size {
        case .xSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .xLarge: self = .extraLarge
        case .xxLarge: self = .extraExtraLarge
        case .xxxLarge: self = .extraExtraExtraLarge
        case .accessibility1: self = .accessibilityMedium
        case .accessibility2: self = .accessibilityLarge
        case .accessibility3: self = .accessibilityExtraLarge
        case .accessibility4: self = .accessibilityExtraExtraLarge
        case .accessibility5: self = .accessibilityExtraExtraExtraLarge
        @unknown default: self = .large
        }
    }
}

/// Caps with tracking scaled to the label's Dynamic Type size.
struct DSLabelModifier: ViewModifier {
    let tracking: CGFloat
    let style: DSTextStyle
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content.textCase(.uppercase)
            .tracking(DSTextStyle.trackingPoints(em: tracking, style: style, category: UIContentSizeCategory(dynamicTypeSize)))
    }
}

extension DSTextStyle {
    /// Letter-spacing in points for an em value at a content size.
    static func trackingPoints(em: CGFloat, style: DSTextStyle, category: UIContentSizeCategory) -> CGFloat {
        em * style.scaledSize(for: category)
    }
}

/// Applies a style at the environment's Dynamic Type size; label styles also get caps and tracking, unless `caps` is
/// off (a sentence-case title in a caps style keeps its tracking).
struct DSFontModifier: ViewModifier {
    let style: DSTextStyle
    let caps: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let size = style.scaledSize(for: UIContentSizeCategory(dynamicTypeSize))
        let styled = content.font(.system(size: size, weight: style.weight))
        if let tracking = style.capsTracking {
            styled.textCase(caps ? .uppercase : nil).tracking(tracking * size)
        } else if style.isNumeral {
            styled.monospacedDigit()
        } else {
            styled
        }
    }
}

public extension View {
    /// Sets a design-system type style (DS-TY-02). `caps: false` keeps a caps style's size, weight and tracking in
    /// the text's own case, e.g. Hole play's "Hole 3" title in `.section` (HP-PS-02). An outer `.textCase(nil)`
    /// can't do that: the modifier's own `.uppercase` sits closer to the text and wins.
    func dsFont(_ style: DSTextStyle, caps: Bool = true) -> some View {
        modifier(DSFontModifier(style: style, caps: caps))
    }

    /// Uppercase with letter-spacing in em, for caps labels; source strings stay sentence case (DS-TY-03).
    /// The spacing follows Dynamic Type with the label size, like `.dsFont(.label)`.
    func dsLabel(tracking: CGFloat = 0.12, style: DSTextStyle = .label) -> some View {
        modifier(DSLabelModifier(tracking: tracking, style: style))
    }

    /// Tabular figures, so scores and yardages line up and don't jump (DS-TY-04).
    func dsNumeric() -> some View {
        monospacedDigit()
    }
}
