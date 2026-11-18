//
//  ShotTargets.swift
//  MaynardGolf
//

import CoreGraphics
import Foundation

/// One hole's shot line and its draggable targets (14-shot-lines §2–3): the round's tee box, the targets in
/// playing order and the pin. Targets start at the course data's approach shots, or on the pin for a par 3
/// (SL-DR-04, SL-TG-05), and aren't saved. Pure, 100 % unit coverage (SL-TS-02, 05).
struct ShotTargets: Equatable, Sendable {
    /// The round hole (1…18) these targets belong to; a different hole starts over (SL-TG-05).
    let hole: Int
    /// The round's tee box (SL-DR-02).
    let tee: Coordinate
    /// The green center (SL-CD-04).
    let pin: Coordinate
    /// Where the targets are now, in playing order.
    private(set) var targets: [Coordinate]
    /// The target the yardage panel follows: the one touched last, target 1 when the hole appears (SL-TG-06).
    private(set) var active = 0

    init(hole: RoundHole, tee: Tee) {
        self.hole = hole.number
        self.tee = hole.source.teeBoxes[tee]
        pin = hole.source.greenCoordinates.center
        targets = Self.starts(par: hole.par, approachShots: hole.source.approachShots, pin: pin)
    }

    /// Where a hole's targets start (SL-DR-04, SL-TG-05): on the pin for a par 3, otherwise at the approach
    /// shots.
    static func starts(par: Int, approachShots: [Coordinate], pin: Coordinate) -> [Coordinate] {
        par == 3 ? [pin] : approachShots
    }

    /// The line's points: tee → each target → pin, as straight legs (SL-DR-02, 03, SL-TS-02).
    var route: [Coordinate] { [tee] + targets + [pin] }

    /// Makes `index` the target the panel follows (SL-TG-06). Out-of-range indexes are ignored.
    mutating func activate(_ index: Int) {
        if targets.indices.contains(index) { active = index }
    }

    /// Moves a target (a drag) and makes it the active one (SL-TG-02, 06).
    mutating func move(_ index: Int, to coordinate: Coordinate) {
        guard targets.indices.contains(index) else { return }
        targets[index] = coordinate
        active = index
    }

    /// VoiceOver's adjust (SL-TG-07): moves a target `yards` along its line, toward the next point (the pin, or
    /// target 2) or back toward the previous one (the tee, or target 1), stopping there.
    mutating func step(_ index: Int, towardPin: Bool, yards: Double = 10) {
        guard targets.indices.contains(index) else { return }
        let from = targets[index]
        let to = route[towardPin ? index + 2 : index]
        let length = YardageCalculator.yards(from: from, to: to)
        guard length > 0 else { return }
        let share = min(1, yards / length)
        move(index, to: Coordinate(latitude: from.latitude + (to.latitude - from.latitude) * share,
                                   longitude: from.longitude + (to.longitude - from.longitude) * share))
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
