//
//  DisplayKindTests.swift
//  MaynardGolfTests
//

import MaynardUI
import Testing
@testable import MaynardGolf

/// The stored weather kinds and tees match the UI library's display kinds by raw value, so a screen
/// turns a stored value into its icon or dot without a hand-written table (DS-GF-05, DS-GF-06).
struct DisplayKindTests {
    @Test(arguments: WeatherKind.allCases)
    func everyWeatherKindHasAnIcon(kind: WeatherKind) {
        #expect(WeatherIcon.Kind(rawValue: kind.rawValue) != nil)
    }

    @Test(arguments: Tee.allCases)
    func everyTeeHasADot(tee: Tee) {
        #expect(TeeDot.Tee(rawValue: tee.rawValue) != nil)
    }

    @Test func theListsMatch() {
        #expect(WeatherKind.allCases.map(\.rawValue) == WeatherIcon.Kind.allCases.map(\.rawValue))
        #expect(Tee.allCases.map(\.rawValue) == TeeDot.Tee.allCases.map(\.rawValue))
    }
}
