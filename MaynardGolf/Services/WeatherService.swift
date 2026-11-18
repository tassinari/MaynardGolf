//
//  WeatherService.swift
//  MaynardGolf
//

import CoreLocation
import Foundation
import OSLog
import WeatherKit

/// Current weather at the course, captured at tee off (NR-CTA-04, DM-RD-08).
protocol WeatherProviding: Sendable {
    func currentWeather(at coordinate: Coordinate) async throws -> WeatherSnapshot
    /// WeatherKit's legal attribution page, as Apple publishes it (SET-AB-09); nil when it can't be read.
    func attributionPage() async -> URL?
}

extension WeatherProviding {
    /// Mocks and stubs have none; Settings then opens `AppLinks.weatherAttribution`.
    func attributionPage() async -> URL? { nil }
}

/// WeatherKit. Needs the WeatherKit capability; until it's added, calls fail and the round is
/// saved without weather, as NR-CTA-04 allows.
struct LiveWeatherService: WeatherProviding {
    let clock: AppClock

    func attributionPage() async -> URL? {
        do {
            return try await WeatherKit.WeatherService.shared.attribution.legalPageURL
        } catch {
            Logger(subsystem: "MaynardGolf", category: "Weather")
                .error("WeatherKit attribution couldn't be read: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    func currentWeather(at coordinate: Coordinate) async throws -> WeatherSnapshot {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let current = try await WeatherKit.WeatherService.shared.weather(for: location, including: .current)
        return WeatherSnapshot(condition: WeatherKind(weatherKit: current.condition),
                               temperatureF: Int(current.temperature.converted(to: .fahrenheit).value.rounded()),
                               capturedAt: clock.now)
    }
}

/// A deterministic weather service: always the same snapshot, or always an error (`-uiTestMockWeather`).
struct MockWeatherService: WeatherProviding {
    struct Unavailable: Error {}

    enum Behavior: Sendable {
        case success(WeatherSnapshot)
        case failure
    }

    let behavior: Behavior

    func currentWeather(at coordinate: Coordinate) async throws -> WeatherSnapshot {
        switch behavior {
        case .success(let snapshot): return snapshot
        case .failure: throw Unavailable()
        }
    }
}
