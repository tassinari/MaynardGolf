//
//  StoredValuesTests.swift
//  MaynardGolfTests
//

import Foundation
import Testing
import WeatherKit
@testable import MaynardGolf

/// DM-TS-20…23: stored values and enums.
struct StoredValuesTests {
    /// DM-TS-21: raw values are the stored format. If this fails, someone renamed a case: don't.
    @Test func rawValuesNeverChange() {
        #expect(PlayerColor.allCases.map(\.rawValue) == ["lake", "sand", "flag", "fairway", "moss"])
        #expect(HoleCount.allCases.map(\.rawValue) == [9, 18])
        #expect(Tee.allCases.map(\.rawValue) == ["blue", "white", "yellow", "red"])
        #expect(WeatherKind.allCases.map(\.rawValue) == ["sunny", "partlyCloudy", "cloudy", "rain", "windy"])
    }

    /// DM-TS-22: unknown raw values read as the documented defaults (DM-EN-05).
    @Test func unknownRawValuesReadAsDefaults() {
        #expect(PlayerColor(storedValue: "purple") == .lake)
        #expect(HoleCount(storedValue: 27) == .nine)
        #expect(Tee(storedValue: "black") == .white)
        #expect(WeatherKind(storedValue: "tornado") == .cloudy)
        #expect(PlayerColor(storedValue: "moss") == .moss)
        #expect(HoleCount(storedValue: 18) == .eighteen)
        #expect(Tee(storedValue: "red") == .red)
        #expect(WeatherKind(storedValue: "rain") == .rain)
    }

    /// DM-TS-20: Codable round trip, with the stored key names pinned.
    @Test func weatherRoundTrips() throws {
        let weather = WeatherSnapshot(condition: .partlyCloudy, temperatureF: 71, capturedAt: TestDates.teeOff)
        let data = try JSONEncoder().encode(weather)
        #expect(try JSONDecoder().decode(WeatherSnapshot.self, from: data) == weather)
        let keys = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any]).keys
        #expect(Set(keys) == ["condition", "temperatureF", "capturedAt"])
    }

    /// DM-TS-20: keys from a newer build are ignored, and an unknown condition reads as cloudy.
    @Test func weatherIgnoresUnknownKeysAndKinds() throws {
        let json = #"{"condition":"hail","temperatureF":40,"capturedAt":0,"windMph":12}"#
        let weather = try JSONDecoder().decode(WeatherSnapshot.self, from: Data(json.utf8))
        #expect(weather == WeatherSnapshot(condition: .cloudy, temperatureF: 40, capturedAt: Date(timeIntervalSinceReferenceDate: 0)))
    }

    /// DM-TS-23: every WeatherKit condition maps to one of the five kinds.
    @Test(arguments: [
        (WeatherCondition.clear, WeatherKind.sunny), (.mostlyClear, .sunny), (.hot, .sunny),
        (.partlyCloudy, .partlyCloudy), (.cloudy, .cloudy), (.mostlyCloudy, .cloudy), (.foggy, .cloudy),
        (.haze, .cloudy), (.drizzle, .rain), (.heavyRain, .rain), (.thunderstorms, .rain), (.snow, .rain),
        (.blizzard, .rain), (.windy, .windy), (.breezy, .windy),
    ])
    func weatherKitConditionsMap(condition: WeatherCondition, kind: WeatherKind) {
        #expect(WeatherKind(weatherKit: condition) == kind)
    }

    @Test(arguments: WeatherCondition.allCases)
    func everyWeatherKitConditionHasAKind(condition: WeatherCondition) {
        #expect(WeatherKind.allCases.contains(WeatherKind(weatherKit: condition)))
    }
}
