//
//  LocationService.swift
//  MaynardGolf
//

import CoreLocation
import Foundation
import Observation

/// Yards to a green's front, center and back (HP-CTL-03).
struct GreenDistances: Equatable, Sendable {
    let front: Int
    let center: Int
    let back: Int

    /// Distances from `position` to each point of the green, rounded to the yard.
    static func from(_ position: Coordinate, to green: GreenCoordinates) -> GreenDistances {
        GreenDistances(front: yards(from: position, to: green.front),
                       center: yards(from: position, to: green.center),
                       back: yards(from: position, to: green.back))
    }

    /// Great-circle distance in yards.
    static func yards(from a: Coordinate, to b: Coordinate) -> Int {
        let meters = CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
        return Int((meters / 0.9144).rounded())
    }
}

/// Whether the app may use location.
enum LocationAuthorization: Equatable, Sendable {
    case notDetermined, denied, granted
}

/// The user's position on the course (HP-CTL-03). Injected; nothing asks for permission until
/// `requestAuthorization()` is called from a tap (X-17).
@MainActor
protocol LocationProviding: AnyObject {
    var authorization: LocationAuthorization { get }
    var position: Coordinate? { get }
    /// True after a failed fix (no GPS, airplane mode, permission revoked) until the next good one. A
    /// failure also clears `position`, so a stale coordinate is never shown as current (HP-CTL-03).
    var isUnavailable: Bool { get }
    /// Shows the system prompt if it hasn't been answered yet.
    func requestAuthorization()
    func startUpdating()
    func stopUpdating()
}

/// CoreLocation.
@Observable
@MainActor
final class LiveLocationService: NSObject, LocationProviding, CLLocationManagerDelegate {
    private(set) var authorization: LocationAuthorization = .notDetermined
    private(set) var position: Coordinate?
    private(set) var isUnavailable = false
    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        authorization = Self.authorization(manager.authorizationStatus)
    }

    func requestAuthorization() { manager.requestWhenInUseAuthorization() }
    func startUpdating() { manager.startUpdatingLocation() }
    func stopUpdating() { manager.stopUpdatingLocation() }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated { authorization = Self.authorization(status) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last?.coordinate else { return }
        let coordinate = Coordinate(latitude: last.latitude, longitude: last.longitude)
        MainActor.assumeIsolated {
            position = coordinate
            isUnavailable = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // `.locationUnknown` is transient: Core Location keeps trying, so keep the last fix.
        if (error as? CLError)?.code == .locationUnknown { return }
        MainActor.assumeIsolated {
            isUnavailable = true
            position = nil
        }
    }

    nonisolated static func authorization(_ status: CLAuthorizationStatus) -> LocationAuthorization {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }
}

/// A deterministic location service (`-uiTestMockLocation granted|denied`).
@Observable
@MainActor
final class MockLocationService: LocationProviding {
    private(set) var authorization: LocationAuthorization
    private(set) var position: Coordinate?
    private let answer: LocationAuthorization
    private let fixedPosition: Coordinate?
    private(set) var isUpdating = false

    /// No fix while granted and given no position.
    var isUnavailable: Bool { isUpdating && authorization == .granted && fixedPosition == nil }

    /// `answer` is what the "user" picks when asked; `position` is where they stand once granted.
    init(answer: LocationAuthorization, position: Coordinate?, authorization: LocationAuthorization = .notDetermined) {
        self.answer = answer
        self.fixedPosition = position
        self.authorization = authorization
    }

    func requestAuthorization() {
        if authorization == .notDetermined { authorization = answer }
    }

    func startUpdating() {
        isUpdating = true
        position = authorization == .granted ? fixedPosition : nil
    }

    func stopUpdating() { isUpdating = false }
}
