//
//  YardageCalculator.swift
//  MaynardGolf
//

import Foundation

/// The yardage panel's numbers for one target (SL-YD-02, 03): how far the target is, and how far from it to the
/// pin. In yards, unrounded; the panel rounds them.
struct TargetYardage: Equatable, Sendable {
    let toTarget: Double
    let toPin: Double
}

/// Every number the shot line can show (SL-YD-03, 07, 08): each target still on the line, and the pin's own.
struct ShotYardages: Equatable, Sendable {
    /// By target index (`ShotTargets.targets`); targets GPS has dropped have none (SL-GP-03).
    let targets: [Int: TargetYardage]
    /// The pin's panel: from the last target still on the line, or with none, from the player (on the course) or
    /// the tee (SL-YD-08).
    let pin: Double
}

/// Real ground distances for the shot lines (14-shot-lines §4, SL-YD-03…05): great-circle yards between GPS
/// points, so they don't depend on screen size or zoom. Pure, 100 % unit coverage (SL-TS-04).
enum YardageCalculator {
    /// Metres in a yard.
    static let metresPerYard = 0.9144
    /// The Earth's mean radius in metres (the haversine's sphere).
    static let earthRadius = 6_371_008.8

    /// Great-circle distance in yards (haversine).
    static func yards(from a: Coordinate, to b: Coordinate) -> Double {
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1, dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h))) / metresPerYard
    }

    /// The numbers along `route` (SL-YD-03, 04, 08): each target's TO TARGET from the start of its leg (the line's
    /// start for the first target on it, the target before it otherwise), and TO PIN from the target. With a
    /// player position inside `course` (south, west, north, east), the `route.active` target's TO TARGET is from
    /// the player instead (SL-YD-04); a position outside the course is ignored.
    static func yardages(route: ShotRoute, targets: [Coordinate], pin: Coordinate, player: Coordinate? = nil,
                         course: [Double]) -> ShotYardages {
        let onCourse = player.flatMap { isInside($0, bounds: course) ? $0 : nil }
        var numbers: [Int: TargetYardage] = [:]
        var legStart = route.start
        for index in route.targets {
            let target = targets[index]
            let from = route.active == .target(index) ? onCourse ?? legStart : legStart
            numbers[index] = TargetYardage(toTarget: yards(from: from, to: target), toPin: yards(from: target, to: pin))
            legStart = target
        }
        let pinFrom = route.targets.last.map { targets[$0] } ?? onCourse ?? route.start
        return ShotYardages(targets: numbers, pin: yards(from: pinFrom, to: pin))
    }

    /// Whether a coordinate is inside south, west, north, east bounds (the course map's, `boundsSWNE`).
    static func isInside(_ point: Coordinate, bounds: [Double]) -> Bool {
        guard bounds.count == 4 else { return false }
        return (bounds[0]...bounds[2]).contains(point.latitude) && (bounds[1]...bounds[3]).contains(point.longitude)
    }
}
