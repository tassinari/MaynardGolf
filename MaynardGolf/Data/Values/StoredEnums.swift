//
//  StoredEnums.swift
//  MaynardGolf
//

import Foundation

// Enums stored in models by raw value (12-data-model §4). Raw values are part of the stored format
// and synced to CloudKit, so they NEVER change (DM-EN-05); a snapshot test pins them (DM-TS-21).
// An unknown raw value, for example one written by a newer build, reads as the documented default.

/// A player's color (DM-EN-01). Maps to design tokens (DS-CL-*). Default: `.lake`.
enum PlayerColor: String, CaseIterable, Codable, Sendable {
    case lake, sand, flag, fairway, moss

    static let fallback: PlayerColor = .lake

    /// The stored raw value, or `.lake` when it's unknown (DM-EN-05).
    init(storedValue: String) {
        self = PlayerColor(rawValue: storedValue) ?? .fallback
    }
}

/// How many holes a round has (DM-EN-02). Default: `.nine`.
enum HoleCount: Int, CaseIterable, Codable, Sendable {
    case nine = 9
    case eighteen = 18

    static let fallback: HoleCount = .nine

    /// The stored raw value, or `.nine` when it's unknown (DM-EN-05).
    init(storedValue: Int) {
        self = HoleCount(rawValue: storedValue) ?? .fallback
    }
}

/// The tee a round is played from (DM-EN-03); matches `TeeInfo.id` in the course data. Default: `.white`.
enum Tee: String, CaseIterable, Codable, Sendable {
    case blue, white, yellow, red

    static let fallback: Tee = .white

    /// The stored raw value, or `.white` when it's unknown (DM-EN-05).
    init(storedValue: String) {
        self = Tee(rawValue: storedValue) ?? .fallback
    }
}

/// The app's five weather kinds (DM-EN-04). Default: `.cloudy`.
enum WeatherKind: String, CaseIterable, Codable, Sendable {
    case sunny, partlyCloudy, cloudy, rain, windy

    static let fallback: WeatherKind = .cloudy

    /// The stored raw value, or `.cloudy` when it's unknown (DM-EN-05).
    init(storedValue: String) {
        self = WeatherKind(rawValue: storedValue) ?? .fallback
    }

    /// Decoding never fails: an unknown kind in stored weather reads as `.cloudy`.
    init(from decoder: Decoder) throws {
        self.init(storedValue: try decoder.singleValueContainer().decode(String.self))
    }
}
