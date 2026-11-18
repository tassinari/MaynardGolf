//
//  YardageCalculator.swift
//  MaynardGolf
//

import Foundation

/// The yardage panel's two numbers for one target (SL-YD-02, 03): how far the target is, and how far from it
/// to the pin. In yards, unrounded; the panel rounds them.
struct TargetYardage: Equatable, Sendable {
    let toTarget: Double
    let toPin: Double
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

    /// Each target's numbers along tee → target 1 → target 2 → pin (SL-YD-03): TO TARGET from the start of
    /// its leg (the tee for target 1, target 1 for target 2), TO PIN from the target. With a player
    /// position inside `course` (south, west, north, east), the `active` target's TO TARGET is measured
    /// from the player instead (SL-YD-04); a position outside the course is ignored.
    static func yardages(tee: Coordinate, targets: [Coordinate], pin: Coordinate, active: Int = 0,
                         player: Coordinate? = nil, course: [Double]) -> [TargetYardage] {
        let onCourse = player.flatMap { isInside($0, bounds: course) ? $0 : nil }
        return targets.enumerated().map { index, target in
            let start = index == active ? onCourse ?? leg(index, tee: tee, targets: targets) : leg(index, tee: tee, targets: targets)
            return TargetYardage(toTarget: yards(from: start, to: target), toPin: yards(from: target, to: pin))
        }
    }

    /// Where target `index`'s leg starts: the tee, or the target before it.
    private static func leg(_ index: Int, tee: Coordinate, targets: [Coordinate]) -> Coordinate {
        index == 0 ? tee : targets[index - 1]
    }

    /// Whether a coordinate is inside south, west, north, east bounds (the course map's, `boundsSWNE`).
    static func isInside(_ point: Coordinate, bounds: [Double]) -> Bool {
        guard bounds.count == 4 else { return false }
        return (bounds[0]...bounds[2]).contains(point.latitude) && (bounds[1]...bounds[3]).contains(point.longitude)
    }
}
