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
    /// The whole master, north up and scaled down, for the Course map button (HM-OV-01). Optional so a
    /// manifest from before the overview still reads.
    let overview: ImagePlacement?
    /// How far the Course map turns the overview on screen, in degrees (map axes to screen axes, the
    /// `ScreenCamera.rotation` convention), so the course fits a portrait iPhone: -105 puts the clubhouse at the
    /// bottom and the course running up the screen, as on the design's Course map artboard (HM-OV-01, #227).
    /// Written by `tools/cut-course-map.py --overview-rotation`; nil (an older manifest) is north up.
    let overviewRotationDegrees: Double?

    var holeCount: Int { holes.count }

    /// The overview's turn in degrees: `overviewRotationDegrees`, or 0 (north up) for an older manifest (HM-OV-01).
    var overviewRotation: Double { overviewRotationDegrees ?? 0 }

    func camera(forHole hole: Int) -> HoleCamera? {
        holes.first { $0.camera.hole == hole }?.camera
    }

    func placement(for piece: CourseImagePiece) -> ImagePlacement? {
        switch piece {
        case .hole(let number):
            holes.first { $0.camera.hole == number }?.image
        case .transition(let from):
            transitions.first { $0.from == from }?.image
        case .overview:
            overview
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

/// One loadable piece: a hole crop, or the transition crop for the swipe from `from` to the next course
/// hole (`transition-{from}-{next}.heic`, with 9 → 1 for the second nine of an 18-hole round).
enum CourseImagePiece: Hashable, Sendable {
    case hole(Int)
    case transition(from: Int)
    /// The whole course, north up, at a sixth of the master's resolution (HM-OV-01).
    case overview

    /// The transition crop used between two neighbouring course holes, in either direction.
    static func transition(between a: Int, and b: Int, holeCount: Int) -> CourseImagePiece {
        b == a % holeCount + 1 ? .transition(from: a) : .transition(from: b)
    }

    /// What must be in memory at round hole `current` (HM-MAP-03): its crop first, then the crops of the
    /// round holes before and after it and the two transitions to them. Rounds don't wrap, so hole 1 has
    /// no previous and the last hole no next; in an 18-hole round, holes 10…18 replay course holes 1…9,
    /// so 9 → 10 is the 9 → 1 transition (HM-TR-08, HM-CAM-04).
    static func window(around current: Int, in holes: [RoundHole], courseHoleCount: Int) -> [CourseImagePiece] {
        let course = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0.source.number) })
        guard let here = course[current] else { return [] }
        var pieces: [CourseImagePiece] = [.hole(here)]
        for neighbour in [current + 1, current - 1] {
            guard let there = course[neighbour] else { continue }
            pieces.append(.hole(there))
            pieces.append(.transition(between: here, and: there, holeCount: courseHoleCount))
        }
        return pieces
    }
}
