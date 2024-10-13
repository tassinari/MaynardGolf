//
//  Weather.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/12/24.
//

import Foundation
import CoreLocation
import WeatherKit

public class WeatherReporter {
    public static let shared = WeatherReporter()
    
    private var cache: Weather?
    
    private init(){}
    
    var formatter: MeasurementFormatter {
           let formatter = MeasurementFormatter()
           formatter.unitStyle = .medium
           formatter.numberFormatter.maximumFractionDigits = 0
           formatter.unitOptions = .providedUnit
           return formatter
    }
    public var temperature : String{
        get async throws{
            formatter.string(from: try await unittemp)
        }
    }
    public var icon : String{
        get async throws{
            conditionSymbol(weather: try await getCondition().currentWeather)
        }
    }
    
    private var unittemp : Measurement<UnitTemperature> {
        get async throws{
            if let cache{
                return cache.currentWeather.temperature.converted(to: .fahrenheit)
            }
            return try await getCondition().currentWeather.temperature.converted(to: .fahrenheit)
        }
    }
    
    func conditionSymbol(weather : CurrentWeather) -> String {
        switch weather.condition{
            
        case .blizzard, .blowingDust, .blowingSnow, .flurries, .freezingDrizzle, .freezingRain, .hail, .frigid, .heavySnow, .sleet,.snow, .wintryMix:
           return "snow"
        case .breezy, .windy:
            return "wind"
        case .clear, .hot, .mostlyClear:
            return "sun.max"
        case .cloudy, .mostlyCloudy:
            return "cloud"
        case .drizzle:
            return "cloud.drizzle"
        case .haze, .foggy, .smoky:
            return "cloud.fog"
        case .heavyRain, .tropicalStorm, .rain:
            return "cloud.heavyrain"
        case .hurricane, .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms, .strongStorms :
            return "cloud.bolt.rain"
        case .partlyCloudy, .sunShowers, .sunFlurries:
            return "cloud.sun"

        @unknown default:
            return "cloud"
        }
    }
    
    private func getCondition() async throws -> Weather{
        let weatherService = WeatherService()
        let maynardGC = CLLocation(latitude: 42.44241, longitude: -71.45150)
        let weather = try await weatherService.weather(for: maynardGC)
        cache = weather
        return weather
    }
}
