//
//  CourseDataTests.swift
//  MaynardGolfTests
//

import CoreGraphics
import Foundation
import Testing
@testable import MaynardGolf

/// 14-shot-lines §6 (#104): tee boxes and approach shots in the course data, their decoding rules and the
/// SL-TS-07 validation of the bundled course.
struct CourseDataTests {
    private let course: Course

    init() throws {
        course = try BundleCourseProvider().course(id: "MaynardGC")
    }

    /// A hole as JSON, with `teeBoxes` and `approachShots` replaced (nil leaves the key out).
    private func holeJSON(par: Int = 4, tees: [String]? = ["blue", "white", "yellow", "red"], approachShots: Int? = 1) -> Data {
        var hole: [String: Any] = [
            "number": 7, "par": par, "handicapFront": 1, "handicapBack": 2,
            "yardage": ["blue": 300, "white": 290, "yellow": 280, "red": 270],
            "greenCoordinates": ["front": ["latitude": 42.0, "longitude": -71.0], "center": ["latitude": 42.1, "longitude": -71.1],
                                 "back": ["latitude": 42.2, "longitude": -71.2]],
        ]
        if let tees {
            hole["teeBoxes"] = Dictionary(uniqueKeysWithValues: tees.enumerated().map {
                ($0.element, ["latitude": 42.0 + Double($0.offset) / 1000, "longitude": -71.0])
            })
        }
        if let approachShots {
            hole["approachShots"] = (0..<approachShots).map { ["latitude": 42.5, "longitude": -71.0 - Double($0) / 1000] }
        }
        return try! JSONSerialization.data(withJSONObject: hole)
    }

    private func decode(_ data: Data) throws -> Hole { try JSONDecoder().decode(Hole.self, from: data) }

    // MARK: Decoding (SL-CD-01, 02)

    /// The new fields decode, and each tee reads its own box.
    @Test func decodesTeeBoxesAndApproachShots() throws {
        let hole = try decode(holeJSON(par: 5, approachShots: 2))
        #expect(hole.teeBoxes[.blue] == Coordinate(latitude: 42.0, longitude: -71.0))
        #expect(hole.teeBoxes[.white] == Coordinate(latitude: 42.001, longitude: -71.0))
        #expect(hole.teeBoxes[.yellow] == Coordinate(latitude: 42.002, longitude: -71.0))
        #expect(hole.teeBoxes[.red] == Coordinate(latitude: 42.003, longitude: -71.0))
        #expect(hole.approachShots.count == 2)
        #expect(hole.approachShots[1] == Coordinate(latitude: 42.5, longitude: -71.001)) // playing order kept
    }

    /// No `teeBoxes`, or a tee missing from them, fails with a typed error naming the hole and tee.
    @Test func aMissingTeeBoxIsATypedError() {
        #expect(throws: CourseDataError.missingTeeBox(hole: 7, tee: .blue)) { try decode(holeJSON(tees: nil)) }
        #expect(throws: CourseDataError.missingTeeBox(hole: 7, tee: .red)) { try decode(holeJSON(tees: ["blue", "white", "yellow"])) }
    }

    /// The approach shots must match the par: two on a par 5, one otherwise; none at all is an error too.
    @Test func approachShotsMatchThePar() throws {
        #expect(throws: CourseDataError.approachShotCount(hole: 7, par: 5, found: 1)) { try decode(holeJSON(par: 5, approachShots: 1)) }
        #expect(throws: CourseDataError.approachShotCount(hole: 7, par: 4, found: 2)) { try decode(holeJSON(par: 4, approachShots: 2)) }
        #expect(throws: CourseDataError.approachShotCount(hole: 7, par: 4, found: 0)) { try decode(holeJSON(approachShots: nil)) }
        #expect(try decode(holeJSON(par: 3, approachShots: 1)).approachShots.count == 1)
        #expect(Hole.approachShotCount(par: 3) == 1 && Hole.approachShotCount(par: 4) == 1 && Hole.approachShotCount(par: 5) == 2)
    }

    /// A course whose hole breaks the rules doesn't load at all: the provider reports the typed error.
    @Test func aBadHoleFailsTheCourse() {
        let json = #"{"id":"X","name":"X","coordinate":{"latitude":42,"longitude":-71},"tees":[],"localRules":[],"holes":[\#(String(decoding: holeJSON(tees: nil), as: UTF8.self))]}"#
        #expect(throws: CourseDataError.missingTeeBox(hole: 7, tee: .blue)) { try JSONDecoder().decode(Course.self, from: Data(json.utf8)) }
    }

    // MARK: SL-TS-07: the bundled course

    /// The tee boxes match the measured coordinates (blue, white, yellow, red per hole).
    @Test func theBundledTeeBoxes() {
        let expected: [[Double]] = [
            [42.442396, -71.451533, 42.442464, -71.451688, 42.442571, -71.451785, 42.442773, -71.452059],
            [42.445651, -71.452347, 42.445534, -71.452209, 42.445116, -71.451874, 42.445070, -71.451834],
            [42.443672, -71.448899, 42.443641, -71.449055, 42.443548, -71.449570, 42.443544, -71.449641],
            [42.443222, -71.450896, 42.443127, -71.450780, 42.442959, -71.450544, 42.442937, -71.450208],
            [42.440897, -71.447848, 42.440991, -71.447876, 42.441152, -71.447862, 42.441223, -71.447898],
            [42.443415, -71.449329, 42.443406, -71.449253, 42.443366, -71.449119, 42.443347, -71.449035],
            [42.443523, -71.447124, 42.443430, -71.447040, 42.443210, -71.446937, 42.442830, -71.447085],
            [42.441953, -71.444323, 42.441932, -71.444457, 42.441745, -71.444804, 42.441687, -71.444957],
            [42.440986, -71.448576, 42.441079, -71.448774, 42.441150, -71.448981, 42.441179, -71.449014],
        ]
        for (hole, row) in zip(course.holes, expected) {
            let boxes = Tee.allCases.map { hole.teeBoxes[$0] }
            #expect(boxes == stride(from: 0, to: 8, by: 2).map { Coordinate(latitude: row[$0], longitude: row[$0 + 1]) }, "hole \(hole.number)")
        }
    }

    /// SL-TS-07: every hole has a camera and an approach shot per its par, and at rest every tee box, approach
    /// shot and pin is on screen, on the smallest, default and largest iPhones (X-19).
    @Test(arguments: [CGSize(width: 375, height: 812), CGSize(width: 402, height: 874), CGSize(width: 440, height: 956)])
    func everyPointIsOnScreenAtRest(screen: CGSize) throws {
        let url = try #require(Bundle.main.url(forResource: "CourseImagery", withExtension: "json")) // the host app's bundle
        let imagery = try JSONDecoder().decode(CourseImagery.self, from: Data(contentsOf: url))
        let bounds = CGRect(origin: .zero, size: screen)
        #expect(course.holes.count == 9)
        for hole in course.holes {
            #expect(hole.approachShots.count == Hole.approachShotCount(par: hole.par), "hole \(hole.number)")
            let camera = try #require(imagery.camera(forHole: hole.number), "hole \(hole.number) has no camera")
            let transform = ScreenCamera(hole: camera, holeImage: imagery.holeImage, screenSize: screen).transform(screenSize: screen)
            let points = Tee.allCases.map { ("\($0.rawValue) tee", hole.teeBoxes[$0]) }
                + hole.approachShots.enumerated().map { ("approach shot \($0.offset + 1)", $0.element) }
                + [("pin", hole.greenCoordinates.center)]
            for (name, coordinate) in points {
                let point = CourseOverview.mapPoint(coordinate, master: imagery.master).applying(transform)
                #expect(bounds.contains(point), "hole \(hole.number): \(name) is off screen at \(point)")
            }
        }
    }

    /// HM-CAM-02 (#186): at rest, on every supported iPhone, every tee box, approach shot and the pin clears Hole
    /// play's controls: 24 pt from the sides, 110 pt below the top and 150 pt above the bottom (74 / 116 without
    /// a home indicator), and the pin 150 pt left of the right edge (the hole card). The limits match
    /// `tools/frame-hole-cameras.py`.
    @Test(arguments: [(375.0, 667.0, false), (375, 812, true), (390, 844, true), (393, 852, true), (402, 874, true),
                      (414, 896, true), (428, 926, true), (430, 932, true), (440, 956, true)])
    func everyPointClearsTheControls(width: Double, height: Double, homeIndicator: Bool) throws {
        let url = try #require(Bundle.main.url(forResource: "CourseImagery", withExtension: "json")) // the host app's bundle
        let imagery = try JSONDecoder().decode(CourseImagery.self, from: Data(contentsOf: url))
        let screen = CGSize(width: width, height: height)
        let (top, bottom): (Double, Double) = homeIndicator ? (110, 150) : (74, 116)
        for hole in course.holes {
            let camera = try #require(imagery.camera(forHole: hole.number))
            let transform = ScreenCamera(hole: camera, holeImage: imagery.holeImage, screenSize: screen).transform(screenSize: screen)
            let points = Tee.allCases.map { ("\($0.rawValue) tee", hole.teeBoxes[$0], false) }
                + hole.approachShots.map { ("approach shot", $0, false) }
                + [("pin", hole.greenCoordinates.center, true)]
            for (name, coordinate, isPin) in points {
                let p = CourseOverview.mapPoint(coordinate, master: imagery.master).applying(transform)
                let right = width - (isPin ? 150 : 24)
                // A hair of slack for the rounding in tools/course-cameras.json.
                #expect(p.x >= 24 - 0.5 && p.x <= right + 0.5, "hole \(hole.number) on \(width)×\(height): \(name) x = \(p.x)")
                #expect(p.y >= top - 0.5 && p.y <= height - bottom + 0.5, "hole \(hole.number) on \(width)×\(height): \(name) y = \(p.y)")
            }
        }
    }
}
