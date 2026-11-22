//
//  ShotTargets.swift
//  MaynardGolf
//

import CoreGraphics
import Foundation

/// One hole's shot line and what can be dragged on it (14-shot-lines §2–3): the round's tee box, the targets in
/// playing order and the pin. Targets start at the course data's approach shots; a par 3 has none, its pin is the
/// target (SL-DR-04, #185). The pin starts at the green center and drags too (SL-TG-08). Nothing is saved
/// (SL-TG-05). Pure, 100 % unit coverage (SL-TS-02, 05).
struct ShotTargets: Equatable, Sendable {
    /// Something on the line that drags and can own the yardage panel (SL-TG-06, 08).
    enum Marker: Equatable, Hashable, Sendable {
        /// Target `n` (0-based, in playing order).
        case target(Int)
        case pin
    }

    /// The round hole (1…18) these targets belong to; a different hole starts over (SL-TG-05).
    let hole: Int
    let par: Int
    /// The round's tee box (SL-DR-02).
    let tee: Coordinate
    /// Where the pin is now: the green center until it's dragged (SL-CD-04, SL-TG-08).
    private(set) var pin: Coordinate
    /// Where the targets are now, in playing order. Empty on a par 3 (SL-DR-04).
    private(set) var targets: [Coordinate]
    /// The marker the yardage panel follows: the one touched last; target 1 when the hole appears, or the pin on a
    /// par 3 (SL-TG-06). `ShotRoute.active` moves it on when GPS drops that target (SL-GP-03).
    private(set) var active: Marker

    init(hole: RoundHole, tee: Tee) {
        self.hole = hole.number
        par = hole.par
        self.tee = hole.source.teeBoxes[tee]
        pin = hole.source.greenCoordinates.center
        targets = Self.starts(par: hole.par, approachShots: hole.source.approachShots)
        active = targets.isEmpty ? .pin : .target(0)
    }

    /// Where a hole's targets start (SL-DR-04, SL-TG-05): none on a par 3, whose pin is the target (#185), otherwise
    /// at the approach shots.
    static func starts(par: Int, approachShots: [Coordinate]) -> [Coordinate] {
        par == 3 ? [] : approachShots
    }

    /// Every point of the line without GPS: tee → each target → pin, as straight legs (SL-DR-02, 03, SL-TS-02).
    var points: [Coordinate] { [tee] + targets + [pin] }

    /// Where `marker` is, or nil for a target that doesn't exist.
    func coordinate(of marker: Marker) -> Coordinate? {
        switch marker {
        case .pin: pin
        case .target(let index): targets.indices.contains(index) ? targets[index] : nil
        }
    }

    /// Makes `marker` the one the panel follows (SL-TG-06). A target that doesn't exist is ignored.
    mutating func activate(_ marker: Marker) {
        if coordinate(of: marker) != nil { active = marker }
    }

    /// Moves a marker (a drag) and makes it the active one (SL-TG-02, 06, 08).
    mutating func move(_ marker: Marker, to coordinate: Coordinate) {
        switch marker {
        case .pin: pin = coordinate
        case .target(let index):
            guard targets.indices.contains(index) else { return }
            targets[index] = coordinate
        }
        active = marker
    }

    /// VoiceOver's adjust (SL-TG-07, 08): moves a marker `yards` along the line. A target goes toward the next point
    /// (the pin, or target 2) or back toward the previous one (the tee, or target 1), stopping there. The pin goes
    /// farther from the point before it (`towardPin`, "longer") or back toward it, stopping there.
    mutating func step(_ marker: Marker, towardPin: Bool, yards: Double = 10) {
        guard let from = coordinate(of: marker) else { return }
        let index = switch marker {
        case .pin: targets.count + 1
        case .target(let index): index + 1
        }
        let previous = points[index - 1]
        let toward: Coordinate, length: Double
        if case .pin = marker, towardPin {
            // Past the pin, along the line from the point before it.
            let leg = YardageCalculator.yards(from: previous, to: from)
            guard leg > 0 else { return }
            toward = Coordinate(latitude: from.latitude + (from.latitude - previous.latitude) * yards / leg,
                                longitude: from.longitude + (from.longitude - previous.longitude) * yards / leg)
            length = yards
        } else {
            toward = towardPin ? points[index + 1] : previous
            length = YardageCalculator.yards(from: from, to: toward)
        }
        guard length > 0 else { return }
        let share = min(1, yards / length)
        move(marker, to: Coordinate(latitude: from.latitude + (toward.latitude - from.latitude) * share,
                                    longitude: from.longitude + (toward.longitude - from.longitude) * share))
    }

    /// The line drawn now (SL-GP-01…05, #185): from the tee, or from the player once they're on the hole and past
    /// the tee, through the targets they haven't reached, to the pin.
    func route(player: Coordinate?) -> ShotRoute {
        ShotRoute(shot: self, player: player)
    }
}

/// The shot line with GPS (SL-GP-01…05, #185): where it starts and which targets it still goes through.
/// Worked out again on every fix, so a target the player walks back away from comes back (SL-GP-03). Pure,
/// 100 % unit coverage (SL-TS-11).
struct ShotRoute: Equatable, Sendable {
    /// The player must be farther than this from the tee for the line to start at them (SL-GP-02).
    static let teeClearance = 30.0
    /// A target this close to the player is reached and leaves the line (SL-GP-03).
    static let targetReach = 50.0
    /// The player counts as on the hole within this many yards of its line (tee → targets → pin, SL-GP-05).
    static let onHole = 75.0

    /// Where the line starts: the tee, or the player (`startsAtPlayer`).
    let start: Coordinate
    /// The line comes from the player's dot, so the tee marker is hidden (SL-GP-02).
    let startsAtPlayer: Bool
    /// The targets still on the line (indexes into `ShotTargets.targets`), in order.
    let targets: [Int]
    /// Every point of the line: start → those targets → pin.
    let points: [Coordinate]
    /// The marker the panel follows: the active one, or, when GPS has dropped it, the next target still on the
    /// line, or the pin (SL-GP-03).
    let active: ShotTargets.Marker

    init(shot: ShotTargets, player: Coordinate?) {
        var reached = 0, from = shot.tee
        // A par 3 keeps the dot apart from its line (SL-GP-04); so does a position off this hole (SL-GP-05).
        if shot.par != 3, let player, Self.distance(from: player, toLine: shot.points) <= Self.onHole {
            if YardageCalculator.yards(from: shot.tee, to: player) > Self.teeClearance { from = player }
            // The farthest target within reach; any before it are behind the player too (SL-GP-03).
            if let last = shot.targets.indices.last(where: { YardageCalculator.yards(from: player, to: shot.targets[$0]) <= Self.targetReach }) {
                reached = last + 1
            }
        }
        start = from
        startsAtPlayer = from != shot.tee
        targets = Array(reached..<shot.targets.count)
        points = [start] + targets.map { shot.targets[$0] } + [shot.pin]
        if case .target(let index) = shot.active, index < reached {
            active = targets.first.map(ShotTargets.Marker.target) ?? .pin
        } else {
            active = shot.active
        }
    }

    /// The shortest distance in yards from `point` to the polyline `line`, on a flat map around `point` (fine over
    /// a golf hole).
    static func distance(from point: Coordinate, toLine line: [Coordinate]) -> Double {
        let metresPerDegree = YardageCalculator.earthRadius * .pi / 180
        let scale = cos(point.latitude * .pi / 180)
        func flat(_ c: Coordinate) -> CGPoint {
            CGPoint(x: (c.longitude - point.longitude) * scale * metresPerDegree, y: (c.latitude - point.latitude) * metresPerDegree)
        }
        let flats = line.map(flat)
        // The line always has a tee and a pin, so at least one leg; a lone point would count as off the hole.
        let metres = zip(flats, flats.dropFirst()).map { a, b in
            let dx = b.x - a.x, dy = b.y - a.y, length = dx * dx + dy * dy
            let t = length == 0 ? 0 : min(max(-(a.x * dx + a.y * dy) / length, 0), 1)
            return hypot(a.x + t * dx, a.y + t * dy)
        }.min() ?? .infinity
        return metres / YardageCalculator.metresPerYard
    }
}

/// Where overlays may sit on screen (SL-TG-04, SL-YD-01). Pure, 100 % unit coverage.
enum ShotLayout {
    /// A target keeps this far from the side edges (SL-TG-04).
    static let sideInset: CGFloat = 24
    /// The panel's center sits this far below the target, plus half its height (SL-YD-01).
    static let panelGap: CGFloat = 30
    /// The panel keeps this far inside the screen edges (SL-YD-01).
    static let panelInset: CGFloat = 12

    /// The playable area: 24 pt in from the sides, below `top` (the hole card and map buttons) and above
    /// `bottom` (the leaderboard). Empty bounds fall back to the whole screen width or height.
    static func playable(screen: CGSize, top: CGFloat, bottom: CGFloat) -> CGRect {
        let minY = min(max(top, 0), screen.height), maxY = max(min(bottom, screen.height), minY)
        return CGRect(x: sideInset, y: minY, width: max(screen.width - 2 * sideInset, 0), height: maxY - minY)
    }

    /// A point held inside `rect`: dragging past a limit stops at it (SL-TG-04).
    static func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, rect.minX), rect.maxX), y: min(max(point.y, rect.minY), rect.maxY))
    }

    /// The yardage panel's center: 30 pt below the target's center (to the panel's top edge), kept 12 pt
    /// inside the screen (SL-YD-01).
    static func panelCenter(target: CGPoint, panel: CGSize, screen: CGSize) -> CGPoint {
        let inside = CGRect(origin: .zero, size: screen).insetBy(dx: panelInset + panel.width / 2, dy: panelInset + panel.height / 2)
        let wanted = CGPoint(x: target.x, y: target.y + panelGap + panel.height / 2)
        guard !inside.isNull else { return CGPoint(x: screen.width / 2, y: screen.height / 2) }
        return clamp(wanted, to: inside)
    }
}

/// What the overlays show (SL-DR-06, SL-MO-04, SL-TS-06): with the setting off only the pin; during a hole
/// transition or over the course overview, nothing.
struct ShotOverlayVisibility: Equatable, Sendable {
    let showsPin: Bool
    let showsRoute: Bool

    /// `showShotLine` is Settings › "Shot line on map"; `isMoving` is a hole transition or the overview.
    init(showShotLine: Bool, isMoving: Bool) {
        showsPin = !isMoving
        showsRoute = showShotLine && !isMoving
    }
}
