//
//  AppLinks.swift
//  MaynardGolf
//

import Foundation

/// The app's outside links and support address, in one place rather than inline in views (SET-AB-07).
enum AppLinks {
    /// Where Send feedback writes to (SET-AB-04).
    static let supportEmail = "tassinari@yahoo.com"
    /// The privacy policy, opened in Safari (SET-AB-05).
    static let privacyPolicy = URL(string: "https://maynardgolf.tassinari.org/privacy")!
    /// Apple's WeatherKit legal attribution page, required wherever weather data is shown (SET-AB-09).
    static let weatherAttribution = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    /// A `mailto:` link to the support address with a subject and body, for when Mail isn't set up for the
    /// in-app composer (SET-AB-04).
    static func feedbackMailto(subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        return components.url
    }
}
