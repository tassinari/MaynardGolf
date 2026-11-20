//
//  HoleCamera.swift
//  MaynardGolf
//

import CoreGraphics
import Foundation

/// Where a hole's framing sits on the course master. The framing is the 2048 × 4096 hole-image frame
/// the cameras were registered with; each hole crop is that frame cut from the master.
/// A hole-image pixel `h` lands on map pixel `center + s·R(θ)·(h − imageCenter)`.
struct HoleCamera: Codable, Equatable, Sendable {
    let hole: Int
    /// The hole image's center, in course-map pixels.
    let mapCenter: CGPoint
    /// Rotation from hole-image axes to map axes, degrees (y points down in both).
    let rotationDegrees: Double
    /// Course-map pixels per hole-image pixel.
    let mapPixelsPerHolePixel: Double

    enum CodingKeys: String, CodingKey { case hole, mapCenter, rotationDegrees, mapPixelsPerHolePixel }

    init(hole: Int, mapCenter: CGPoint, rotationDegrees: Double, mapPixelsPerHolePixel: Double) {
        self.hole = hole
        self.mapCenter = mapCenter
        self.rotationDegrees = rotationDegrees
        self.mapPixelsPerHolePixel = mapPixelsPerHolePixel
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let point = try c.decode([Double].self, forKey: .mapCenter)
        guard point.count == 2 else {
            throw DecodingError.dataCorruptedError(forKey: .mapCenter, in: c, debugDescription: "mapCenter needs [x, y]")
        }
        self.init(hole: try c.decode(Int.self, forKey: .hole),
                  mapCenter: CGPoint(x: point[0], y: point[1]),
                  rotationDegrees: try c.decode(Double.self, forKey: .rotationDegrees),
                  mapPixelsPerHolePixel: try c.decode(Double.self, forKey: .mapPixelsPerHolePixel))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(hole, forKey: .hole)
        try c.encode([mapCenter.x, mapCenter.y], forKey: .mapCenter)
        try c.encode(rotationDegrees, forKey: .rotationDegrees)
        try c.encode(mapPixelsPerHolePixel, forKey: .mapPixelsPerHolePixel)
    }
}

/// What the screen shows of the map: the map point at the screen's center, how many screen points
/// one map pixel covers, and the map's rotation on screen. Pure value; drives the map layer.
struct ScreenCamera: Equatable, Sendable {
    var center: CGPoint
    var pointsPerMapPixel: Double
    var rotation: Double // radians, map axes → screen axes

    /// The camera that shows the hole's frame aspect-fill, centered, on a screen of `screenSize`.
    init(hole: HoleCamera, holeImage: CourseImagery.Size, screenSize: CGSize) {
        let fill = max(screenSize.width / holeImage.width, screenSize.height / holeImage.height)
        center = hole.mapCenter
        pointsPerMapPixel = fill / hole.mapPixelsPerHolePixel
        rotation = -hole.rotationDegrees * .pi / 180
    }

    init(center: CGPoint, pointsPerMapPixel: Double, rotation: Double) {
        self.center = center
        self.pointsPerMapPixel = pointsPerMapPixel
        self.rotation = rotation
    }

    /// Map pixel → screen point. The map turns around the middle of the screen.
    func transform(screenSize: CGSize) -> CGAffineTransform {
        let a = pointsPerMapPixel * cos(rotation)
        let b = pointsPerMapPixel * sin(rotation)
        let mid = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
        return CGAffineTransform(a: a, b: b, c: -b, d: a,
                                 tx: mid.x - a * center.x + b * center.y,
                                 ty: mid.y - b * center.x - a * center.y)
    }

    /// Blends two cameras for swipe progress 0…1 (16-hole-map HM-TR-01, 05):
    /// the center moves in a straight line, the rotation takes the short way round, the scale
    /// changes evenly in log space, and turns over 120° zoom out by up to 20 % at the midpoint.
    /// Progress is held to `lowerBound…1`. The default 0 keeps every move between its two holes; a stretch past
    /// an end passes a small negative bound so its spring-back can overshoot (HM-TR-09).
    static func blend(from: ScreenCamera, to: ScreenCamera, progress: Double, lowerBound: Double = 0) -> ScreenCamera {
        let p = min(max(progress, lowerBound), 1)
        let turn = remainder(to.rotation - from.rotation, 2 * .pi)
        let logScale = (1 - p) * log(from.pointsPerMapPixel) + p * log(to.pointsPerMapPixel)
        return ScreenCamera(
            center: CGPoint(x: from.center.x + p * (to.center.x - from.center.x),
                            y: from.center.y + p * (to.center.y - from.center.y)),
            pointsPerMapPixel: exp(logScale) * zoomOut(turn: turn, progress: p),
            rotation: from.rotation + p * turn
        )
    }

    /// 1 for turns of 120° or less; otherwise dips to 0.8 at the midpoint for turns of 180°.
    static func zoomOut(turn: Double, progress: Double) -> Double {
        let degrees = abs(turn) * 180 / .pi
        guard degrees > 120 else { return 1 }
        let strength = min(1, (degrees - 120) / 60)
        return 1 - 0.2 * strength * sin(.pi * progress)
    }
}
