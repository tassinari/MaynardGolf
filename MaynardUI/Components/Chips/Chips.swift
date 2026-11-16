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
            Text(verbatim: "\(value)").font(.system(size: 24, weight: .bold)).monospacedDigit()
                .foregroundStyle(Color.ds.chalk50)
            Text(verbatim: unit.abbreviation).dsFont(.labelSmall).foregroundStyle(Color.ds.moss400)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .dsScrim(cornerRadius: DSRadius.chip)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: unit.spoken(value)))
    }
}

/// A Bunker capsule with a Flag dot and a caps label: "BUNKER · 245 CARRY" (DS-CH-02).
public struct HazardChip: View {
    private let text: Text

    public init(_ text: Text) { self.text = text }

    public var body: some View {
        HStack(spacing: DSSpacing.xs) {
            Circle().fill(Color.ds.flag600).frame(width: 8, height: 8).accessibilityHidden(true)
            text.dsFont(.labelSmall).foregroundStyle(Color.ds.canopy950)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(Capsule().fill(Color.ds.bunker300))
        .accessibilityElement(children: .combine)
    }
}

/// A Canopy capsule with a flag icon and "PIN 148" (DS-CH-03).
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
            Image(systemName: "flag.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.ds.flag400)
                .accessibilityHidden(true)
            Text(verbatim: Self.text(value)).dsFont(.labelSmall).foregroundStyle(Color.ds.chalk50)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(Capsule().fill(Color.ds.canopy950))
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

/// A status capsule; today only "IN PROGRESS" (DS-CH-04): Flag 400 with a Canopy dot.
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
            Circle().fill(Color.ds.canopy950).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(verbatim: status.text).dsFont(.labelSmall).foregroundStyle(Color.ds.canopy950)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xxs)
        .background(Capsule().fill(Color.ds.flag400))
        .accessibilityElement(children: .combine)
    }
}

/// A 30 pt rounded square with a rule number (DS-CH-07), for local rules.
public struct NumberChip: View {
    private let number: Int

    public init(_ number: Int) { self.number = number }

    public var body: some View {
        Text(verbatim: "\(number)")
            .font(.system(size: 17, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Color.ds.rough600)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.ds.teeGreen50))
            .accessibilityHidden(true) // the rule card reads "Rule {n}. {text}" (LR-RC-04)
    }
}

/// A player's avatar dot and gross score in a capsule (DS-CH-08), used in `RoundRow`.
public struct PlayerScoreChip: View {
    private let name: String
    private let color: PlayerPalette
    private let photo: UIImage?
    private let score: Int

    public init(name: String, color: PlayerPalette, photo: UIImage? = nil, score: Int) {
        self.name = name
        self.color = color
        self.photo = photo
        self.score = score
    }

    public var body: some View {
        HStack(spacing: DSSpacing.xs) {
            PlayerAvatar(name: name, color: color, photo: photo, size: .xxs).accessibilityHidden(true)
            Text(verbatim: "\(score)").font(.system(size: 16, weight: .bold)).monospacedDigit()
                .foregroundStyle(Color.ds.textPrimary)
        }
        .padding(EdgeInsets(top: 3, leading: 3, bottom: 3, trailing: 9))
        .background(Capsule().fill(Color.ds.chipFill))
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: Self.accessibilityLabel(name: name, score: score)))
    }

    /// "{name}, {score}".
    public nonisolated static func accessibilityLabel(name: String, score: Int) -> String {
        String(localized: "\(name), \(score)", bundle: Bundle.maynardUI, comment: "VoiceOver label of a player's score chip: name and gross score.")
    }
}
