//
//  SettingsTests.swift
//  MaynardGolfTests
//

import Foundation
import Observation
import Testing
@testable import MaynardGolf

/// SET-DT-01…03, SET-OPT-01…04, NR-HOL-02: defaults, persistence, fallbacks and observation.
@MainActor
struct SettingsStoreTests {
    @Test func defaultsMatchTheDoc() {
        let settings = SettingsStore.inMemory()
        #expect(settings.showToPar)
        #expect(settings.showShotLine)
        #expect(!settings.autoAdvance)
        #expect(settings.defaultTee == .white)
        #expect(settings.lastHoleCount == .nine)
    }

    @Test func keysAreNamespaced() {
        #expect(SettingsStore.Key.allCases.allSatisfy { $0.rawValue.hasPrefix("settings.") })
        #expect(Set(SettingsStore.Key.allCases.map(\.rawValue)).count == SettingsStore.Key.allCases.count)
    }

    /// Every change is written straight away and read back by a new store on the same storage.
    @Test func valuesRoundTrip() {
        let storage = InMemorySettingsStorage()
        let settings = SettingsStore(storage: storage)
        settings.showToPar = false
        settings.showShotLine = false
        settings.autoAdvance = true
        settings.defaultTee = .blue
        settings.lastHoleCount = .eighteen
        let reopened = SettingsStore(storage: storage)
        #expect(!reopened.showToPar)
        #expect(!reopened.showShotLine)
        #expect(reopened.autoAdvance)
        #expect(reopened.defaultTee == .blue)
        #expect(reopened.lastHoleCount == .eighteen)
        #expect(storage.value(forKey: "settings.defaultTee") as? String == "blue")
        #expect(storage.value(forKey: "settings.lastHoleCount") as? Int == 18)
    }

    /// DM-EN-05: unknown or wrongly typed stored values read as the defaults.
    @Test func badStoredValuesReadAsDefaults() {
        let settings = SettingsStore.inMemory([.defaultTee: "black", .lastHoleCount: 27, .showToPar: "yes", .autoAdvance: 1])
        #expect(settings.defaultTee == .white)
        #expect(settings.lastHoleCount == .nine)
        #expect(settings.showToPar)
        #expect(!settings.autoAdvance)
    }

    @Test func userDefaultsStorageRoundTrips() throws {
        let suite = "SettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore.live(defaults: defaults)
        #expect(settings.showToPar)
        settings.showToPar = false
        settings.defaultTee = .red
        #expect(defaults.object(forKey: "settings.showToPar") as? Bool == false)
        let reopened = SettingsStore.live(defaults: defaults)
        #expect(!reopened.showToPar)
        #expect(reopened.defaultTee == .red)
    }

    /// SET-DT-03: other screens see a change through observation.
    @Test func observersSeeChanges() {
        let settings = SettingsStore.inMemory()
        final class Flag: @unchecked Sendable { var fired = false }
        let flag = Flag()
        withObservationTracking { _ = settings.showToPar } onChange: { flag.fired = true }
        settings.showToPar = false
        #expect(flag.fired)
    }

    /// UI tests and previews get in-memory storage (so a test never sees an earlier one's changes); the
    /// app gets UserDefaults.
    @Test func dependenciesPickTheStorage() {
        #expect(AppDependencies.settings(for: LaunchArguments(["-uiTestSeed", "freshInstall"])).storage is InMemorySettingsStorage)
        #expect(AppDependencies.preview(.freshInstall).settings.storage is InMemorySettingsStorage)
        #expect(AppDependencies.settings(for: LaunchArguments([])).storage is UserDefaultsSettingsStorage)
    }
}

/// SET-DT-02, SET-OPT-04, SET-LR-02: the Settings view model.
@MainActor
struct SettingsViewModelTests {
    @Test func valuesPassThroughToTheStore() {
        let settings = SettingsStore.inMemory()
        let model = SettingsViewModel(settings: settings, courses: BundleCourseProvider(), about: about, weather: noWeather)
        model.showToPar = false
        model.showShotLine = false
        model.autoAdvance = true
        model.defaultTee = .yellow
        #expect(!settings.showToPar && !settings.showShotLine && settings.autoAdvance && settings.defaultTee == .yellow)
        #expect(!model.showToPar && !model.showShotLine && model.autoAdvance && model.defaultTee == .yellow)
    }

    @Test func teesAndLocalRulesComeFromTheCourse() throws {
        let model = SettingsViewModel(settings: .inMemory(), courses: BundleCourseProvider(), about: about, weather: noWeather)
        #expect(model.tees.map(\.id) == [.blue, .white, .yellow, .red])
        #expect(model.defaultTeeInfo?.id == .white)
        let summary = try #require(model.localRulesSummary)
        #expect(summary.title == "Maynard Golf Club")
        #expect(summary.subtitle == "12 local rules")
    }

    @Test func aMissingCourseHidesTheTeesAndRules() {
        struct NoCourse: CourseProvider { func course(id: String) throws -> Course { throw CourseError.missingFile(id) } }
        let model = SettingsViewModel(settings: .inMemory(), courses: NoCourse(), about: about, weather: noWeather)
        #expect(model.course == nil)
        #expect(model.tees.isEmpty)
        #expect(model.defaultTeeInfo == nil)
        #expect(model.localRulesSummary == nil)
    }

    @Test func aCourseWithoutRulesHasNoSummary() throws {
        let maynard = try BundleCourseProvider().course(id: "MaynardGC")
        struct Fixed: CourseProvider { let course: Course; func course(id: String) throws -> Course { course } }
        let bare = Course(id: maynard.id, name: maynard.name, coordinate: maynard.coordinate, tees: maynard.tees,
                          holes: maynard.holes, localRules: [])
        #expect(SettingsViewModel(settings: .inMemory(), courses: Fixed(course: bare), about: about, weather: noWeather).localRulesSummary == nil)
    }
}

/// No weather service: the attribution page falls back to the bundled link.
private let noWeather = MockWeatherService(behavior: .failure)

/// A weather service that publishes its attribution page.
private struct PublishingWeather: WeatherProviding {
    let page: URL
    func currentWeather(at coordinate: Coordinate) async throws -> WeatherSnapshot { throw MockWeatherService.Unavailable() }
    func attributionPage() async -> URL? { page }
}

/// A fixed version and device for the view-model tests.
private let about = AboutInfo(info: ["CFBundleShortVersionString": "1.2", "CFBundleVersion": "211"], device: "iPhone18,1", system: "iOS 27.1")

/// SET-AB-02, 04, 07: the version row, the feedback mail and the links.
@MainActor
struct SettingsAboutTests {
    private func model(_ about: AboutInfo = about) -> SettingsViewModel {
        SettingsViewModel(settings: .inMemory(), courses: BundleCourseProvider(), about: about, weather: noWeather)
    }

    /// SET-AB-02: "{version} ({build})", read from the bundle, with "?" for a missing value.
    @Test func versionText() {
        #expect(model().versionText == "1.2 (211)")
        #expect(model(AboutInfo(info: [:], device: "x", system: "y")).versionText == "? (?)")
        #expect(model(AboutInfo(info: nil, device: "x", system: "y")).versionText == "? (?)")
        let live = AboutInfo.live
        #expect(!live.device.isEmpty && live.system.hasPrefix("iOS"))
        #expect(live.version == Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }

    /// SET-AB-04: subject, and a body that ends with the app version and device.
    @Test func feedbackMail() throws {
        let model = model()
        #expect(model.feedbackSubject == "Maynard Golf feedback")
        #expect(model.feedbackBody.hasSuffix("Maynard Golf 1.2 (211) on iPhone18,1, iOS 27.1"))
        let mailto = try #require(model.feedbackMailto)
        let components = try #require(URLComponents(url: mailto, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "mailto" && components.path == "tassinari@yahoo.com")
        #expect(components.queryItems?.first { $0.name == "subject" }?.value == "Maynard Golf feedback")
        #expect(components.queryItems?.first { $0.name == "body" }?.value == model.feedbackBody)
    }

    /// SET-AB-09: Weather data opens WeatherKit's own page when it can be read, else the bundled link.
    @Test func weatherAttributionPage() async throws {
        let offline = model()
        #expect(offline.weatherAttributionPage == AppLinks.weatherAttribution) // before anything is read
        await offline.loadWeatherAttribution()
        #expect(offline.weatherAttributionPage == AppLinks.weatherAttribution)
        let published = try #require(URL(string: "https://example.com/weather-legal"))
        let model = SettingsViewModel(settings: .inMemory(), courses: BundleCourseProvider(), about: about,
                                      weather: PublishingWeather(page: published))
        await model.loadWeatherAttribution()
        #expect(model.weatherAttributionPage == published)
    }

    /// The app's dependencies supply the settings, the course, the about values and the weather service.
    @Test func dependencies() async {
        let dependencies = AppDependencies.preview(.freshInstall)
        let model = SettingsViewModel(dependencies: dependencies)
        #expect(model.about == .preview && model.versionText == "1.2 (211)")
        #expect(model.localRulesSummary?.subtitle == "12 local rules")
        #expect(AppDependencies.about(for: LaunchArguments(["-uiTestSeed", "noRound"])) == .preview)
        #expect(AppDependencies.about(for: LaunchArguments([])) == .live)
    }

    /// SET-AB-05, 07, 09: the links live in AppLinks.
    @Test func links() {
        #expect(AppLinks.supportEmail == "tassinari@yahoo.com")
        #expect(AppLinks.privacyPolicy.absoluteString == "https://maynardgolf.tassinari.org/privacy")
        #expect(AppLinks.weatherAttribution.absoluteString == "https://weatherkit.apple.com/legal-attribution.html")
    }
}
