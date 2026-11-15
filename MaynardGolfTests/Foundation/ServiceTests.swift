//
//  ServiceTests.swift
//  MaynardGolfTests
//

import CoreLocation
import Foundation
import Testing
@testable import MaynardGolf

/// #17: services and their mocks.
@MainActor
struct ServiceTests {
    private let green = GreenCoordinates(front: Coordinate(latitude: 42.44507442441848, longitude: -71.4525247100366),
                                         center: Coordinate(latitude: 42.4452123444219, longitude: -71.45248854240852),
                                         back: Coordinate(latitude: 42.44533159494796, longitude: -71.45241411111073))

    @Test func distancesToTheGreenGrowFrontToBack() {
        // About 150 yards short of hole 1's green, straight south.
        let position = Coordinate(latitude: 42.4439, longitude: -71.4526)
        let d = GreenDistances.from(position, to: green)
        #expect(d.front < d.center && d.center < d.back)
        #expect((120...160).contains(d.front))
    }

    @Test func aKnownDistance() {
        // One minute of latitude is 1,852 m (2,025 yd) to within a fraction of a percent.
        let a = Coordinate(latitude: 42.0, longitude: -71.0)
        let b = Coordinate(latitude: 42.0 + 1.0 / 60, longitude: -71.0)
        #expect(abs(GreenDistances.yards(from: a, to: b) - 2_025) <= 5)
        #expect(GreenDistances.yards(from: a, to: a) == 0)
    }

    @Test(arguments: [(CLAuthorizationStatus.authorizedWhenInUse, LocationAuthorization.granted), (.authorizedAlways, .granted),
                      (.denied, .denied), (.restricted, .denied), (.notDetermined, .notDetermined)])
    func authorizationMaps(status: CLAuthorizationStatus, expected: LocationAuthorization) {
        #expect(LiveLocationService.authorization(status) == expected)
    }

    @Test func mockLocationAnswersOnceAndOnlyGivesAPositionWhenGranted() {
        let here = Coordinate(latitude: 1, longitude: 2)
        let granted = MockLocationService(answer: .granted, position: here)
        #expect(granted.authorization == .notDetermined)
        granted.requestAuthorization()
        granted.startUpdating()
        #expect(granted.authorization == .granted && granted.position == here && granted.isUpdating)
        granted.stopUpdating()
        #expect(!granted.isUpdating)

        let denied = MockLocationService(answer: .denied, position: here)
        denied.requestAuthorization()
        denied.startUpdating()
        #expect(denied.authorization == .denied && denied.position == nil)

        let alreadyDenied = MockLocationService(answer: .granted, position: here, authorization: .denied)
        alreadyDenied.requestAuthorization()
        #expect(alreadyDenied.authorization == .denied) // asked only once
    }

    @Test func theLiveLocationServiceStartsUnaskedOrAsTheSystemSays() {
        let service = LiveLocationService()
        #expect([.notDetermined, .denied, .granted].contains(service.authorization))
        #expect(service.position == nil)
    }

    @Test func weatherMocks() async throws {
        let sunny = ModelFixtures.weather(.sunny)
        #expect(try await MockWeatherService(behavior: .success(sunny)).currentWeather(at: green.center) == sunny)
        await #expect(throws: MockWeatherService.Unavailable.self) {
            try await MockWeatherService(behavior: .failure).currentWeather(at: green.center)
        }
    }

    @Test func clocks() {
        #expect(FixedClock(now: TestDates.teeOff).now == TestDates.teeOff)
        #expect(abs(SystemClock().now.timeIntervalSinceNow) < 5)
    }

    @Test func hapticsPlayOnlyWhenEnabled() {
        final class Counter: HapticPerformer {
            var events: [HapticEvent] = []
            func perform(_ event: HapticEvent) { events.append(event) }
        }
        final class Toggle { var isOn = false }
        let counter = Counter()
        let toggle = Toggle()
        let haptics = HapticsService(performer: counter) { toggle.isOn }
        haptics.play(.success)
        #expect(counter.events.isEmpty) // no-op when disabled
        toggle.isOn = true
        haptics.play(.selection)
        haptics.play(.warning)
        #expect(counter.events == [.selection, .warning])
    }

    @Test func realAndSilentPerformersDontCrash() {
        let real = UIKitHapticPerformer()
        for event in [HapticEvent.selection, .success, .warning] { real.perform(event) }
        SilentHapticPerformer().perform(.success)
    }
}
