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
///
/// Conforming types are `Observable`: Hole play learns the answer to the permission prompt, and new fixes, by
/// observing `authorization` and `position` (#208's review).
@MainActor
protocol LocationProviding: AnyObject, Observable {
    var authorization: LocationAuthorization { get }
    /// The latest fix accurate enough to measure from (`LocationFix.isPrecise`), or nil: no fix yet, a failed
    /// one, updates stopped, or Approximate location.
    var position: Coordinate? { get }
    /// The user allowed only Approximate location (Precise Location off): fixes are kilometres out, so there's
    /// no `position` (HP-CTL-03).
    var isApproximate: Bool { get }
    /// True after a failed fix (no GPS, airplane mode, permission revoked) until the next good one. A
    /// failure also clears `position`, so a stale coordinate is never shown as current (HP-CTL-03).
    var isUnavailable: Bool { get }
    /// Shows the system prompt if it hasn't been answered yet.
    func requestAuthorization()
    func startUpdating()
    func stopUpdating()
}

/// Which Core Location fixes are good enough to measure a yardage from (HP-CTL-03, SL-YD-04).
enum LocationFix {
    /// The largest horizontal uncertainty accepted, in metres (about 33 yards). The first Wi-Fi and cell fixes after
    /// starting are often 65 m or worse, which would mislead a club choice.
    static let maxAccuracy = 30.0

    /// Whether a fix with this `horizontalAccuracy` is used: it's valid (not negative) and within `maxAccuracy`.
    static func isPrecise(horizontalAccuracy: Double) -> Bool {
        horizontalAccuracy >= 0 && horizontalAccuracy <= maxAccuracy
    }
}

/// CoreLocation.
@Observable
@MainActor
final class LiveLocationService: NSObject, LocationProviding, CLLocationManagerDelegate {
    private(set) var authorization: LocationAuthorization = .notDetermined
    private(set) var position: Coordinate?
    private(set) var isUnavailable = false
    private(set) var isApproximate = false
    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        authorization = Self.authorization(manager.authorizationStatus)
        isApproximate = manager.accuracyAuthorization == .reducedAccuracy
    }

    func requestAuthorization() { manager.requestWhenInUseAuthorization() }
    func startUpdating() { manager.startUpdatingLocation() }

    /// Stops updates and forgets the last fix, so turning location on again later never measures from where the
    /// player stood before (#208's review).
    func stopUpdating() {
        manager.stopUpdatingLocation()
        position = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let approximate = manager.accuracyAuthorization == .reducedAccuracy
        MainActor.assumeIsolated {
            authorization = Self.authorization(status)
            isApproximate = approximate
            if approximate { position = nil }
        }
    }

    /// Keeps the latest fix only when it's precise enough (`LocationFix`) and Precise Location is on; a vague fix
    /// leaves the last good one in place.
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last, manager.accuracyAuthorization == .fullAccuracy,
              LocationFix.isPrecise(horizontalAccuracy: last.horizontalAccuracy) else { return }
        let coordinate = Coordinate(latitude: last.coordinate.latitude, longitude: last.coordinate.longitude)
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
    /// `-uiTestMockLocation approximate`: granted, but with Precise Location off.
    let isApproximate: Bool
    private let answer: LocationAuthorization
    private let fixedPosition: Coordinate?
    private(set) var isUpdating = false

    /// No fix while granted and given no position.
    var isUnavailable: Bool { isUpdating && authorization == .granted && fixedPosition == nil }

    /// `answer` is what the "user" picks when asked; `position` is where they stand once granted.
    init(answer: LocationAuthorization, position: Coordinate?, authorization: LocationAuthorization = .notDetermined,
         isApproximate: Bool = false) {
        self.answer = answer
        self.isApproximate = isApproximate
        self.fixedPosition = position
        self.authorization = authorization
    }

    func requestAuthorization() {
        if authorization == .notDetermined { authorization = answer }
    }

    func startUpdating() {
        isUpdating = true
        position = authorization == .granted && !isApproximate ? fixedPosition : nil
    }

    /// Stops and forgets the fix, like the live service.
    func stopUpdating() {
        isUpdating = false
        position = nil
    }
}
