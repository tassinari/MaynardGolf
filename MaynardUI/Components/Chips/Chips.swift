//
//  Chips.swift
//  MaynardUI
//

import SwiftUI
import UIKit

/// A distance on a Scrim tile: value plus caps unit (DS-CH-01). Takes yards (course data) and shows the
/// injected unit.
public struct YardageChip: View {
    private let yards: Int
    private let unit: DistanceUnit

    public init(yards: Int, unit: DistanceUnit = .yards) {
        self.yards = yards
        self.unit = unit
    }

    public var body: some View {
        let value = unit.value(fromYards: yards)
        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.xxs) {
            Text(verbatim: "\(value)").dsFont(.chipNumeral).foregroundStyle(Color.ds.onImagery)
            Text(verbatim: unit.abbreviation).dsFont(.labelSmall).foregroundStyle(Color.ds.onImageryTertiary)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .dsScrim(cornerRadius: DSRadius.chip)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: unit.spoken(value)))
    }
}

/// An Orange 300 capsule with a Red dot and a caps label: "BUNKER · 245 CARRY" (DS-CH-02).
public struct HazardChip: View {
    private let text: Text

    public init(_ text: Text) { self.text = text }

    public var body: some View {
        HStack(spacing: DSSpacing.xs) {
            Circle().fill(Color.ds.hazardFill).frame(width: 8, height: 8).accessibilityHidden(true)
            text.dsFont(.labelSmall).foregroundStyle(Color.ds.onHazardChip)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(Capsule().fill(Color.ds.hazardChipFill))
        .accessibilityElement(children: .combine)
    }
}

/// An Ink capsule with an Orange flag icon and "PIN 148" (DS-CH-03).
public struct PinChip: View {
    private let yards: Int
    private let unit: DistanceUnit

    public init(yards: Int, unit: DistanceUnit = .yards) {
        self.yards = yards
        self.unit = unit
    }

    public var body: some View {
        let value = unit.value(fromYards: yards)
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "flag.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.ds.markerAccent)
                .accessibilityHidden(true)
            Text(verbatim: Self.text(value)).dsFont(.labelSmall).foregroundStyle(Color.ds.onImagery)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(Capsule().fill(Color.ds.imageryBackdrop))
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: Self.spoken(value, unit: unit)))
    }

    /// "Pin 148" (shown in caps).
    public nonisolated static func text(_ value: Int) -> String {
        String(localized: "Pin \(value)", bundle: Bundle.maynardUI, comment: "Distance to the pin on a chip, shown in caps.")
    }

    /// "Pin, 148 yards".
    public nonisolated static func spoken(_ value: Int, unit: DistanceUnit) -> String {
        String(localized: "Pin, \(unit.spoken(value))", bundle: Bundle.maynardUI, comment: "VoiceOver label of the pin distance chip.")
    }
}

/// A status capsule; today only "IN PROGRESS" (DS-CH-04): Orange 500 with an Ink dot.
public struct StatusPill: View {
    public enum Status: CaseIterable, Sendable {
        case inProgress

        public var text: String {
            switch self {
            case .inProgress: String(localized: "In progress", bundle: Bundle.maynardUI, comment: "Status of a round still being played, shown in caps.")
            }
        }
    }

    private let status: Status

    public init(_ status: Status) { self.status = status }

    public var body: some View {
        HStack(spacing: DSSpacing.xs) {
            Circle().fill(Color.ds.onStatus).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(verbatim: status.text).dsFont(.labelSmall).foregroundStyle(Color.ds.onStatus)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xxs)
        .background(Capsule().fill(Color.ds.statusFill))
        .accessibilityElement(children: .combine)
    }
}

/// A 30 pt rounded square with a rule number (DS-CH-07), for local rules. The square has a fixed size, so
/// its number is fixed too; the rule text beside it scales.
public struct NumberChip: View {
    private let number: Int

    public init(_ number: Int) { self.number = number }

    public var body: some View {
        Text(verbatim: "\(number)")
            .font(.system(size: 17, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Color.ds.success)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.ds.surfaceRaised))
            .accessibilityHidden(true) // the rule card reads "Rule {n}. {text}" (LR-RC-04)
    }
}

/// A player's gross score on a `RoundRow` (DS-CH-08), in one of the row's layouts (`Style`, chosen by
/// `RoundRow.ChipLayout`): a tile with the first name over the score for three or four players, or a wide chip
/// with the avatar, the name and the score for one or two (the All rounds — variation board, iPhone C). The
/// round's lowest gross gets `chipHighlight` in place of `chipFill`; the solo chip has no fill.
public struct PlayerScoreChip: View {
    /// How the chip is drawn.
    public enum Style: Sendable, Equatable, CaseIterable {
        /// Name over score, up to 70 pt wide so the row's chips share one line equally (three or four players).
        case tile
        /// `tile`, as wide as the name: for wrapping at accessibility sizes, so no name is cut off (DS-TY-06).
        case tileFitting
        /// One player: 44 pt avatar, name and a 22 pt score across the row, no fill.
        case solo
        /// Two players: `solo`'s chip on a fill with a 20 pt score; the two share the row.
        case split

        /// Whether the chip shows the avatar and spans its share of the row.
        public var isWide: Bool { self == .solo || self == .split }
    }

    private let name: String
    private let score: Int
    private let isLowest: Bool
    private let style: Style
    private let color: PlayerPalette
    private let photo: UIImage?

    /// `color` and `photo` draw the avatar on the wide styles; tiles have none.
    public init(name: String, score: Int, isLowest: Bool = false, style: Style = .tile,
                color: PlayerPalette = .moss, photo: UIImage? = nil) {
        self.name = name
        self.score = score
        self.isLowest = isLowest
        self.style = style
        self.color = color
        self.photo = photo
    }

    public var body: some View {
        Group {
            if style.isWide { wide } else { tile }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: Self.accessibilityLabel(name: name, score: score)))
    }

    private var fill: Color { isLowest ? Color.ds.chipHighlight : Color.ds.chipFill }

    private var tile: some View {
        VStack(spacing: 1) {
            Text(verbatim: name).dsFont(.caption).fontWeight(.semibold).lineLimit(1).minimumScaleFactor(style == .tile ? 0.8 : 1)
            Text(verbatim: "\(score)").dsFont(.chipScore)
        }
        .foregroundStyle(Color.ds.textPrimary)
        .padding(.vertical, DSSpacing.xs)
        .padding(.horizontal, DSSpacing.xxs)
        .frame(minWidth: 0, maxWidth: style == .tile ? 70 : nil)
        .background(RoundedRectangle(cornerRadius: DSRadius.chipTile, style: .continuous).fill(fill))
    }

    private var wide: some View {
        HStack(spacing: DSSpacing.sm) {
            PlayerAvatar(name: name, color: color, photo: photo, size: .m)
            Text(verbatim: name).dsFont(.bodyEmphasized).lineLimit(1).minimumScaleFactor(0.8) // DS-TY-06
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: "\(score)").dsFont(style == .solo ? .dateDay : .chipScoreWide)
        }
        .foregroundStyle(Color.ds.textPrimary)
        .padding(.leading, DSSpacing.xs)
        .padding(.trailing, DSSpacing.ml)
        .padding(.vertical, DSSpacing.xs)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(RoundedRectangle(cornerRadius: DSRadius.chipTile, style: .continuous)
            .fill(style == .solo ? Color.clear : fill))
    }

    /// "{name}, {score}".
    public nonisolated static func accessibilityLabel(name: String, score: Int) -> String {
        String(localized: "\(name), \(score)", bundle: Bundle.maynardUI, comment: "VoiceOver label of a player's score chip: name and gross score.")
    }
}
