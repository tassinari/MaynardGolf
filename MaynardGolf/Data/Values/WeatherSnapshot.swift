//
//  WeatherSnapshot.swift
//  MaynardGolf
//

import Foundation

/// The weather captured at tee off, stored on `Round` as a Codable value (DM-VT-01).
///
/// Explicit `CodingKeys` keep the stored format independent of the Swift property names, and
/// unknown future keys are ignored when decoding. Temperatures are °F (there's no unit setting).
struct WeatherSnapshot: Codable, Equatable, Hashable, Sendable {
    var condition: WeatherKind
    var temperatureF: Int
    var capturedAt: Date

    enum CodingKeys: String, CodingKey {
        case condition
        case temperatureF
        case capturedAt
    }
}
