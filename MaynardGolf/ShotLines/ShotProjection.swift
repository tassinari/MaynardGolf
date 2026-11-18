//
//  ShotProjection.swift
//  MaynardGolf
//

import CoreGraphics
import Foundation

/// Places shot-line points on screen and back (14-shot-lines §5): GPS → course master → hole camera →
/// screen, and the reverse for a dragged target (SL-PJ-02). It uses the same camera transform as the map,
/// so overlays stay pinned to the turf on every screen size (SL-PJ-03). Pure, 100 % unit coverage (SL-PJ-04).
struct ShotProjection: Sendable {
    let master: CourseImagery.Master
    let camera: ScreenCamera
    let screenSize: CGSize

    /// The projection for a hole's camera at rest on a screen of `screenSize` (16-hole-map HM-CAM-05).
    init(master: CourseImagery.Master, hole: HoleCamera, holeImage: CourseImagery.Size, screenSize: CGSize) {
        self.init(master: master, camera: ScreenCamera(hole: hole, holeImage: holeImage, screenSize: screenSize), screenSize: screenSize)
    }

    init(master: CourseImagery.Master, camera: ScreenCamera, screenSize: CGSize) {
        self.master = master
        self.camera = camera
        self.screenSize = screenSize
    }

    /// The screen point of a GPS coordinate.
    func point(for coordinate: Coordinate) -> CGPoint {
        CourseOverview.mapPoint(coordinate, master: master).applying(camera.transform(screenSize: screenSize))
    }

    /// The GPS coordinate under a screen point (SL-PJ-02).
    func coordinate(for point: CGPoint) -> Coordinate {
        Self.coordinate(forMapPoint: point.applying(camera.transform(screenSize: screenSize).inverted()), master: master)
    }

    /// The inverse of `CourseOverview.mapPoint`: a master pixel back to latitude and longitude.
    static func coordinate(forMapPoint point: CGPoint, master: CourseImagery.Master) -> Coordinate {
        let south = master.boundsSWNE[0], west = master.boundsSWNE[1]
        let north = master.boundsSWNE[2], east = master.boundsSWNE[3]
        return Coordinate(latitude: north - Double(point.y) / master.height * (north - south),
                          longitude: west + Double(point.x) / master.width * (east - west))
    }
}
