//
//  CourseOverview.swift
//  MaynardGolf
//

import CoreGraphics
import Foundation

/// The Course map button's whole-course view (16-hole-map §5, HM-OV-01…03): the camera that fits the
/// course on screen north up, and a badge per round hole on its tee. Pure, so it's tested without a map.
enum CourseOverview {
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

    /// The camera that shows the whole master, north up, fitted inside `screenSize` and centred (HM-OV-01).
    static func camera(master: CourseImagery.Master, screenSize: CGSize) -> ScreenCamera {
        let fit = min(screenSize.width / master.width, screenSize.height / master.height)
        return ScreenCamera(center: CGPoint(x: master.width / 2, y: master.height / 2), pointsPerMapPixel: fit, rotation: 0)
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
