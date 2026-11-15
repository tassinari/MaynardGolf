//
//  CourseImagery.swift
//  MaynardGolf
//

import CoreGraphics
import Foundation

/// The pre-cut course pieces and where each sits on the master, from `CourseImagery.json`
/// (written by `tools/cut-course-map.py`, 16-hole-map HM-CD-01).
struct CourseImagery: Codable, Equatable, Sendable {
    struct Size: Codable, Equatable, Sendable {
        let width: Double
        let height: Double
    }

    struct Master: Codable, Equatable, Sendable {
        let width: Double
        let height: Double
        /// South, west, north, east.
        let boundsSWNE: [Double]
    }

    struct Hole: Codable, Equatable, Sendable {
        let camera: HoleCamera
        let image: ImagePlacement
    }

    struct Transition: Codable, Equatable, Sendable {
        let from: Int
        let to: Int
        let image: ImagePlacement
    }

    let master: Master
    let holeImage: Size
    let holes: [Hole]
    let transitions: [Transition]

    var holeCount: Int { holes.count }

    func camera(forHole hole: Int) -> HoleCamera? {
        holes.first { $0.camera.hole == hole }?.camera
    }

    func placement(for piece: CourseImagePiece) -> ImagePlacement? {
        switch piece {
        case .hole(let number):
            holes.first { $0.camera.hole == number }?.image
        case .transition(let from):
            transitions.first { $0.from == from }?.image
        }
    }
}

/// Where one piece sits on the master: pixel `p` of the piece lands on master pixel
/// `mapOrigin + mapPixelsPerPixel · R(rotation) · p`.
struct ImagePlacement: Codable, Equatable, Sendable {
    let file: String
    /// Pixel size of the piece.
    let width: Double
    let height: Double
    let mapOrigin: CGPoint
    let rotationDegrees: Double
    let mapPixelsPerPixel: Double

    enum CodingKeys: String, CodingKey { case file, width, height, mapOrigin, rotationDegrees, mapPixelsPerPixel }

    init(file: String, width: Double, height: Double, mapOrigin: CGPoint, rotationDegrees: Double, mapPixelsPerPixel: Double) {
        self.file = file
        self.width = width
        self.height = height
        self.mapOrigin = mapOrigin
        self.rotationDegrees = rotationDegrees
        self.mapPixelsPerPixel = mapPixelsPerPixel
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let origin = try c.decode([Double].self, forKey: .mapOrigin)
        guard origin.count == 2 else {
            throw DecodingError.dataCorruptedError(forKey: .mapOrigin, in: c, debugDescription: "mapOrigin needs [x, y]")
        }
        self.init(file: try c.decode(String.self, forKey: .file),
                  width: try c.decode(Double.self, forKey: .width),
                  height: try c.decode(Double.self, forKey: .height),
                  mapOrigin: CGPoint(x: origin[0], y: origin[1]),
                  rotationDegrees: try c.decode(Double.self, forKey: .rotationDegrees),
                  mapPixelsPerPixel: try c.decode(Double.self, forKey: .mapPixelsPerPixel))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(file, forKey: .file)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
        try c.encode([mapOrigin.x, mapOrigin.y], forKey: .mapOrigin)
        try c.encode(rotationDegrees, forKey: .rotationDegrees)
        try c.encode(mapPixelsPerPixel, forKey: .mapPixelsPerPixel)
    }

    var size: CGSize { CGSize(width: width, height: height) }

    /// Piece pixel → master pixel.
    var mapTransform: CGAffineTransform {
        let theta = rotationDegrees * .pi / 180
        let a = mapPixelsPerPixel * cos(theta)
        let b = mapPixelsPerPixel * sin(theta)
        return CGAffineTransform(a: a, b: b, c: -b, d: a, tx: mapOrigin.x, ty: mapOrigin.y)
    }
}

/// One loadable piece: a hole crop, or the transition crop for the swipe from `from` to the next hole.
enum CourseImagePiece: Hashable, Sendable {
    case hole(Int)
    case transition(from: Int)

    /// The transition crop used between two neighbouring holes, in either direction.
    static func transition(between a: Int, and b: Int, holeCount: Int) -> CourseImagePiece {
        b == a % holeCount + 1 ? .transition(from: a) : .transition(from: b)
    }

    /// What must be in memory at `hole` (HM-MAP-03): it, both neighbours, and both swipes out of it.
    /// For hole 1 of 9: holes 9, 1, 2 and the transitions 9 → 1 and 1 → 2.
    static func window(around hole: Int, holeCount: Int) -> Set<CourseImagePiece> {
        guard holeCount > 1 else { return [.hole(hole)] }
        let previous = (hole + holeCount - 2) % holeCount + 1
        let next = hole % holeCount + 1
        return [.hole(previous), .hole(hole), .hole(next), .transition(from: previous), .transition(from: hole)]
    }
}
