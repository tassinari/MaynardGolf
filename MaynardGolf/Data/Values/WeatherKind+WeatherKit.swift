//
//  WeatherKind+WeatherKit.swift
//  MaynardGolf
//

import WeatherKit

extension WeatherKind {
    /// Maps every WeatherKit condition to one of the app's five kinds (DM-EN-04). Precipitation of
    /// any sort, including snow and storms, reads as `.rain`; anything unknown reads as `.cloudy`.
    init(weatherKit condition: WeatherCondition) {
        switch condition {
        case .clear, .mostlyClear, .hot, .frigid:
            self = .sunny
        case .partlyCloudy:
            self = .partlyCloudy
        case .cloudy, .mostlyCloudy, .foggy, .haze, .smoky, .blowingDust:
            self = .cloudy
        case .drizzle, .rain, .heavyRain, .sunShowers, .freezingDrizzle, .freezingRain, .sleet, .hail,
             .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms, .strongStorms,
             .tropicalStorm, .hurricane, .flurries, .sunFlurries, .snow, .heavySnow, .blizzard,
             .blowingSnow, .wintryMix:
            self = .rain
        case .windy, .breezy:
            self = .windy
        @unknown default:
            self = .fallback
        }
    }
}
