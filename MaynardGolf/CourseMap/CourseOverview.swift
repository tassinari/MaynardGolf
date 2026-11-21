//
//  CourseOverview.swift
//  MaynardGolf
//

import CoreGraphics
import Foundation

/// The Course map button's whole-course view (16-hole-map §5, HM-OV-01…03): the camera that turns the course to
/// fill a portrait screen, and a badge per round hole on its fairway. Pure, so it's tested without a map.
enum CourseOverview {
    /// Space the overview keeps its badges' centres out of (HM-OV-01): the top, under Exit and Show my location; the
    /// bottom, above the home indicator; and the sides, wide enough for a badge pair (two 44 pt targets, HM-OV-01).
    /// Fixed points, like the hole cameras' limits (HM-CAM-02), since the map ignores the safe area.
    struct ClearInsets: Equatable, Sendable {
        var top: Double
        var bottom: Double
        var horizontal: Double

        static let standard = ClearInsets(top: 130, bottom: 50, horizontal: 48)
    }

    /// One hole's badge.
    struct Badge: Equatable, Sendable, Identifiable {
        /// The round hole it opens (1…18).
        let roundHole: Int
        /// Where it sits on the master: on the hole's fairway (`badgePoint`).
        let mapPoint: CGPoint
        /// 0 for holes 1–9, 1 for 10–18, which share their course hole with 1–9 and sit beside them (HM-OV-01).
        let slot: Int
        /// The hole on screen (HM-OV-03).
        let isCurrent: Bool
        /// Every player has a score on it (HM-OV-03).
        let isScored: Bool

        var id: Int { roundHole }
    }

    /// The overview's camera (HM-OV-01, #227): the map turned by `rotationDegrees` and cropped to the course, filling
    /// the screen with no ground past the master's edge showing.
    ///
    /// 1. It zooms so the `fill` box (the holes' tees and greens) covers the screen: the tighter side touches its
    ///    edges and the other runs past them, so a tee can be cut off.
    /// 2. It zooms out only as far as it must for every `badges` point to fit inside `insets`, and centres them there.
    /// 3. It never zooms out past the master covering the screen, and slides the centre back onto the master, so the
    ///    screen always shows the map. The map wins over a badge when they can't both have their way.
    ///
    /// With no points it frames the whole master the same way.
    static func camera(master: CourseImagery.Master, rotationDegrees: Double, fill: [CGPoint], badges: [CGPoint],
                       screenSize: CGSize, insets: ClearInsets = .standard) -> ScreenCamera {
        let rotation = rotationDegrees * .pi / 180
        let corners = [CGPoint.zero, CGPoint(x: master.width, y: 0), CGPoint(x: 0, y: master.height),
                       CGPoint(x: master.width, y: master.height)]
        let cropped = fill.isEmpty ? corners : fill
        let fillBox = turnedBox(cropped, by: rotation)
        let badgeBox = turnedBox(badges.isEmpty ? cropped : badges, by: rotation)
        let width = max(screenSize.width, 1), height = max(screenSize.height, 1)
        let clear = CGRect(x: insets.horizontal, y: insets.top, width: max(screenSize.width - 2 * insets.horizontal, 1),
                           height: max(screenSize.height - insets.top - insets.bottom, 1))
        let fills = max(width / max(fillBox.width, 1), height / max(fillBox.height, 1))
        let fitsBadges = min(clear.width / max(badgeBox.width, 1), clear.height / max(badgeBox.height, 1))
        // The turned screen's half extents along the master's axes, per point of zoom: the screen stays on the master
        // while they're within half its size.
        let cosine = abs(cos(rotation)), sine = abs(sin(rotation))
        let halfX = (width * cosine + height * sine) / 2, halfY = (width * sine + height * cosine) / 2
        let covers = max(2 * halfX / max(master.width, 1), 2 * halfY / max(master.height, 1))
        let scale = max(covers, min(fills, fitsBadges))
        // The badges' centre lands on the clear area's centre, which sits `offset` from the screen's middle.
        let offset = CGPoint(x: clear.midX - screenSize.width / 2, y: clear.midY - screenSize.height / 2)
        let wanted = rotate(CGPoint(x: badgeBox.midX - offset.x / scale, y: badgeBox.midY - offset.y / scale), by: -rotation)
        let center = CGPoint(x: clamp(wanted.x, halfX / scale, master.width - halfX / scale),
                             y: clamp(wanted.y, halfY / scale, master.height - halfY / scale))
        return ScreenCamera(center: center, pointsPerMapPixel: scale, rotation: rotation)
    }

    /// The box around `points` (never empty: the camera falls back to the master's corners) once turned by `angle`
    /// radians, in screen axes not yet scaled.
    private static func turnedBox(_ points: [CGPoint], by angle: Double) -> CGRect {
        let turned = points.map { rotate($0, by: angle) }
        let minX = turned.reduce(Double.infinity) { min($0, $1.x) }, maxX = turned.reduce(-Double.infinity) { max($0, $1.x) }
        let minY = turned.reduce(Double.infinity) { min($0, $1.y) }, maxY = turned.reduce(-Double.infinity) { max($0, $1.y) }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// `value` held to `lower…upper`, or their middle when the range is empty (a master smaller than the screen).
    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        lower > upper ? (lower + upper) / 2 : min(max(value, lower), upper)
    }

    /// `point` turned by `angle` radians about the origin (y down, as on screen and on the master).
    private static func rotate(_ point: CGPoint, by angle: Double) -> CGPoint {
        CGPoint(x: point.x * cos(angle) - point.y * sin(angle), y: point.x * sin(angle) + point.y * cos(angle))
    }

    /// What the overview crops to (HM-OV-01): each round hole's tee for the round's tee and its green, for holes
    /// with a camera.
    static func focusPoints(holes: [RoundHole], tee: Tee, imagery: CourseImagery) -> [CGPoint] {
        holes.flatMap { hole -> [CGPoint] in
            guard imagery.camera(forHole: hole.source.number) != nil else { return [] }
            return [mapPoint(hole.source.teeBoxes[tee], master: imagery.master),
                    mapPoint(hole.source.greenCoordinates.center, master: imagery.master)]
        }
    }

    /// Where a hole's badge sits, in the fairway (HM-OV-01, #227): the first approach shot (SL-CD-02), or the green on
    /// a par 3, whose approach shot is on the green anyway.
    static func badgePoint(_ hole: Hole, master: CourseImagery.Master) -> CGPoint {
        guard hole.par > 3, let approach = hole.approachShots.first else {
            return mapPoint(hole.greenCoordinates.center, master: master)
        }
        return mapPoint(approach, master: master)
    }

    /// A GPS coordinate on the master (HM-MAP-01): latitude and longitude map linearly to pixels across
    /// the master's bounds, north at the top.
    static func mapPoint(_ coordinate: Coordinate, master: CourseImagery.Master) -> CGPoint {
        let south = master.boundsSWNE[0], west = master.boundsSWNE[1]
        let north = master.boundsSWNE[2], east = master.boundsSWNE[3]
        let x: Double = (coordinate.longitude - west) / (east - west) * master.width
        let y: Double = (north - coordinate.latitude) / (north - south) * master.height
        return CGPoint(x: x, y: y)
    }

    /// A badge per round hole, in hole order (HM-OV-01, 03), in its fairway (`badgePoint`). Holes without a camera
    /// are left out.
    static func badges(holes: [RoundHole], imagery: CourseImagery, current: Int, isScored: (Int) -> Bool) -> [Badge] {
        holes.compactMap { hole in
            guard imagery.camera(forHole: hole.source.number) != nil else { return nil }
            let point = badgePoint(hole.source, master: imagery.master)
            return Badge(roundHole: hole.number, mapPoint: point, slot: hole.number > 9 ? 1 : 0,
                         isCurrent: hole.number == current, isScored: isScored(hole.number))
        }
    }
}
