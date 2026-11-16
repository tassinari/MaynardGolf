//
//  DistanceFormatting.swift
//  MaynardUI
//

import Foundation

/// The distance unit the app shows (yards by default; meters from Settings, 02-settings).
public enum DistanceUnit: String, CaseIterable, Sendable {
    case yards, meters

    /// Converts a distance in yards (how course data stores it) to this unit, rounded to a whole number.
    public func value(fromYards yards: Int) -> Int {
        switch self {
        case .yards: yards
        case .meters: Int((Double(yards) * 0.9144).rounded())
        }
    }

    /// The short caps unit shown after a value: "YDS" or "M" (DS-CH-01).
    public var abbreviation: String {
        switch self {
        case .yards: String(localized: "yds", bundle: Bundle.maynardUI, comment: "Short unit after a distance in yards, shown in caps.")
        case .meters: String(localized: "m", bundle: Bundle.maynardUI, comment: "Short unit after a distance in meters, shown in caps.")
        }
    }

    /// The spoken form for VoiceOver: "148 yards", "135 meters".
    public func spoken(_ value: Int) -> String {
        switch self {
        case .yards: String(localized: "\(value) yards", bundle: Bundle.maynardUI, comment: "A distance in yards, read by VoiceOver.")
        case .meters: String(localized: "\(value) meters", bundle: Bundle.maynardUI, comment: "A distance in meters, read by VoiceOver.")
        }
    }
}
