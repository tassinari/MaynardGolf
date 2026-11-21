//
//  CourseOverview.swift
//  MaynardGolf
//

import CoreGraphics
import Foundation

/// The Course map button's whole-course view (16-hole-map §5, HM-OV-01…03): the camera that turns the course to
/// fit a portrait screen, and a badge per round hole on its tee. Pure, so it's tested without a map.
enum CourseOverview {
    /// Space the overview keeps its badges out of (HM-OV-01): the top, under Exit and Show my location; the bottom,
    /// above the home indicator; and the sides, wide enough for a badge pair (two 44 pt targets, HM-OV-01).
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
        /// Where it sits on the master: the course hole's tee.
        let mapPoint: CGPoint
        /// 0 for holes 1–9, 1 for 10–18, which share their tee with 1–9 and sit beside them (HM-OV-01).
        let slot: Int
        /// The hole on screen (HM-OV-03).
        let isCurrent: Bool
        /// Every player has a score on it (HM-OV-03).
        let isScored: Bool

        var id: Int { roundHole }
    }

    /// The overview's camera (HM-OV-01, #227): the map turned by `rotationDegrees`, zoomed so every `focus` point
    /// (the holes' tees and greens) fits the screen inside `insets`, and centred in that clear area. With no focus
    /// points it frames the whole master. Keeping every badge on screen comes first: the master doesn't reach far
    /// enough around the course to fill a portrait screen at this turn, so a corner can show past its edge, where
    /// the map's ground shows (HM-MAP-04).
    static func camera(master: CourseImagery.Master, rotationDegrees: Double, focus: [CGPoint], screenSize: CGSize,
                       insets: ClearInsets = .standard) -> ScreenCamera {
        let rotation = rotationDegrees * .pi / 180
        let points = focus.isEmpty
            ? [CGPoint.zero, CGPoint(x: master.width, y: 0), CGPoint(x: 0, y: master.height), CGPoint(x: master.width, y: master.height)]
            : focus
        // The focus box in screen axes (turned, not yet scaled).
        let turned = points.map { rotate($0, by: rotation) }
        let minX = turned.reduce(Double.infinity) { min($0, $1.x) }, maxX = turned.reduce(-Double.infinity) { max($0, $1.x) }
        let minY = turned.reduce(Double.infinity) { min($0, $1.y) }, maxY = turned.reduce(-Double.infinity) { max($0, $1.y) }
        let clear = CGRect(x: insets.horizontal, y: insets.top, width: screenSize.width - 2 * insets.horizontal,
                           height: screenSize.height - insets.top - insets.bottom)
        let scale = min(max(clear.width, 1) / max(maxX - minX, 1), max(clear.height, 1) / max(maxY - minY, 1))
        // The box's centre lands on the clear area's centre, which sits `offset` from the screen's middle.
        let boxCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let offset = CGPoint(x: clear.midX - screenSize.width / 2, y: clear.midY - screenSize.height / 2)
        let center = rotate(CGPoint(x: boxCenter.x - offset.x / scale, y: boxCenter.y - offset.y / scale), by: -rotation)
        return ScreenCamera(center: center, pointsPerMapPixel: scale, rotation: rotation)
    }

    /// `point` turned by `angle` radians about the origin (y down, as on screen and on the master).
    private static func rotate(_ point: CGPoint, by angle: Double) -> CGPoint {
        CGPoint(x: point.x * cos(angle) - point.y * sin(angle), y: point.x * sin(angle) + point.y * cos(angle))
    }

    /// What the overview keeps on screen (HM-OV-01): each round hole's tee for the round's tee (where its badge
    /// sits) and its green, for holes with a camera.
    static func focusPoints(holes: [RoundHole], tee: Tee, imagery: CourseImagery) -> [CGPoint] {
        holes.flatMap { hole -> [CGPoint] in
            guard imagery.camera(forHole: hole.source.number) != nil else { return [] }
            return [mapPoint(hole.source.teeBoxes[tee], master: imagery.master),
                    mapPoint(hole.source.greenCoordinates.center, master: imagery.master)]
        }
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

    /// A badge per round hole, in hole order (HM-OV-01, 03), on the round's tee box from the course data
    /// (SL-CD-01). Holes without a camera are left out.
    static func badges(holes: [RoundHole], tee: Tee, imagery: CourseImagery, current: Int,
                       isScored: (Int) -> Bool) -> [Badge] {
        holes.compactMap { hole in
            guard imagery.camera(forHole: hole.source.number) != nil else { return nil }
            let point = mapPoint(hole.source.teeBoxes[tee], master: imagery.master)
            return Badge(roundHole: hole.number, mapPoint: point, slot: hole.number > 9 ? 1 : 0,
                         isCurrent: hole.number == current, isScored: isScored(hole.number))
        }
    }
}
