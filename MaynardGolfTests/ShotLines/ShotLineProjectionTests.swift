//
//  ShotLineProjectionTests.swift
//  MaynardGolfTests
//

import CoreGraphics
import CoreLocation
import Foundation
import Testing
@testable import MaynardGolf

/// The bundled course and map manifest, read once per test.
struct ShotLineFixtures {
    let course: Course
    let imagery: CourseImagery

    init() throws {
        course = try BundleCourseProvider().course(id: "MaynardGC")
        let url = try #require(Bundle.main.url(forResource: "CourseImagery", withExtension: "json")) // the host app's bundle
        imagery = try JSONDecoder().decode(CourseImagery.self, from: Data(contentsOf: url))
    }

    func projection(hole: Int, screen: CGSize = CGSize(width: 402, height: 874)) throws -> ShotProjection {
        ShotProjection(master: imagery.master, hole: try #require(imagery.camera(forHole: hole)), holeImage: imagery.holeImage,
                       screenSize: screen)
    }
}

private func distance(_ a: CGPoint, _ b: CGPoint) -> Double { hypot(a.x - b.x, a.y - b.y) }

/// 14-shot-lines §5 (#105): GPS ↔ screen through the hole camera.
struct ShotProjectionTests {
    private let data: ShotLineFixtures

    init() throws { data = try ShotLineFixtures() }

    /// SL-TS-01: each hole's tee, approach shots and green center land where the camera math says (within
    /// 1 px), and screen → GPS → screen round-trips within 0.5 px.
    @Test func everyHoleProjectsAndRoundTrips() throws {
        let screen = CGSize(width: 402, height: 874)
        for hole in data.course.holes {
            let projection = try data.projection(hole: hole.number, screen: screen)
            let camera = try #require(data.imagery.camera(forHole: hole.number))
            let transform = ScreenCamera(hole: camera, holeImage: data.imagery.holeImage, screenSize: screen).transform(screenSize: screen)
            for coordinate in [hole.teeBoxes.white] + hole.approachShots + [hole.greenCoordinates.center] {
                let expected = CourseOverview.mapPoint(coordinate, master: data.imagery.master).applying(transform)
                let point = projection.point(for: coordinate)
                #expect(distance(point, expected) <= 1, "hole \(hole.number)")
                #expect(distance(projection.point(for: projection.coordinate(for: point)), point) <= 0.5, "hole \(hole.number)")
            }
        }
    }

    /// The master's corners map back to the bounds' corners.
    @Test func mapPointsBackToCoordinates() {
        let master = data.imagery.master
        let northWest = ShotProjection.coordinate(forMapPoint: .zero, master: master)
        #expect(abs(northWest.latitude - master.boundsSWNE[2]) < 1e-9 && abs(northWest.longitude - master.boundsSWNE[1]) < 1e-9)
        let southEast = ShotProjection.coordinate(forMapPoint: CGPoint(x: master.width, y: master.height), master: master)
        #expect(abs(southEast.latitude - master.boundsSWNE[0]) < 1e-9 && abs(southEast.longitude - master.boundsSWNE[3]) < 1e-9)
    }

    /// SL-TS-03: Blue and Red tees start the line in different places and give different TO TARGET values.
    @Test func theRoundsTeeStartsTheLine() throws {
        let hole = data.course.holes[0]
        let projection = try data.projection(hole: 1)
        #expect(distance(projection.point(for: hole.teeBoxes.blue), projection.point(for: hole.teeBoxes.red)) > 5)
        let course = data.imagery.master.boundsSWNE
        let blue = YardageCalculator.yardages(tee: hole.teeBoxes.blue, targets: hole.approachShots, pin: hole.greenCoordinates.center, course: course)
        let red = YardageCalculator.yardages(tee: hole.teeBoxes.red, targets: hole.approachShots, pin: hole.greenCoordinates.center, course: course)
        #expect(blue[0].toTarget - red[0].toTarget > 10) // the blue box is further back
        #expect(blue[0].toPin == red[0].toPin)
    }
}

/// 14-shot-lines §4 (#105): yardages (100 %).
struct YardageCalculatorTests {
    private let data: ShotLineFixtures

    init() throws { data = try ShotLineFixtures() }

    /// SL-TS-04: known pairs within a yard: 0.001° of latitude, and every hole's tee to pin against
    /// CoreLocation's ellipsoid distance.
    @Test func knownDistances() {
        let a = Coordinate(latitude: 42.443, longitude: -71.449)
        #expect(abs(YardageCalculator.yards(from: a, to: Coordinate(latitude: 42.444, longitude: -71.449)) - 121.6) < 1)
        #expect(YardageCalculator.yards(from: a, to: a) == 0)
        for hole in data.course.holes {
            let tee = hole.teeBoxes.white, pin = hole.greenCoordinates.center
            let metres = CLLocation(latitude: tee.latitude, longitude: tee.longitude).distance(from: CLLocation(latitude: pin.latitude, longitude: pin.longitude))
            #expect(abs(YardageCalculator.yards(from: tee, to: pin) - metres / 0.9144) < 1, "hole \(hole.number)")
        }
    }

    /// SL-YD-03: on the par 5, target 1 measures from the tee and target 2 from target 1; both to the pin.
    @Test func parFiveLegs() throws {
        let hole = try #require(data.course.holes.first { $0.par == 5 })
        let (t1, t2, pin, tee) = (hole.approachShots[0], hole.approachShots[1], hole.greenCoordinates.center, hole.teeBoxes.white)
        let yards = YardageCalculator.yardages(tee: tee, targets: [t1, t2], pin: pin, course: data.imagery.master.boundsSWNE)
        #expect(yards == [TargetYardage(toTarget: YardageCalculator.yards(from: tee, to: t1), toPin: YardageCalculator.yards(from: t1, to: pin)),
                          TargetYardage(toTarget: YardageCalculator.yards(from: t1, to: t2), toPin: YardageCalculator.yards(from: t2, to: pin))])
    }

    /// SL-YD-05: a target at the same spot gives the same yards on the smallest and largest screens.
    @Test func screenSizeDoesntChangeTheYards() throws {
        let hole = data.course.holes[0]
        let yards = try [CGSize(width: 375, height: 667), CGSize(width: 440, height: 956)].map { size in
            let projection = try data.projection(hole: 1, screen: size)
            let target = projection.coordinate(for: projection.point(for: hole.approachShots[0]))
            return YardageCalculator.yards(from: hole.teeBoxes.white, to: target)
        }
        #expect(abs(yards[0] - yards[1]) < 0.01)
    }

    /// SL-YD-04: with a position on the course, the active target's TO TARGET is from the player; the other
    /// target and TO PIN don't change; a position off the course, or bad bounds, is ignored.
    @Test func fromThePlayersPosition() throws {
        let hole = try #require(data.course.holes.first { $0.par == 5 })
        let bounds = data.imagery.master.boundsSWNE
        let tee = hole.teeBoxes.white, pin = hole.greenCoordinates.center
        let player = Coordinate(latitude: (bounds[0] + bounds[2]) / 2, longitude: (bounds[1] + bounds[3]) / 2)
        let base = YardageCalculator.yardages(tee: tee, targets: hole.approachShots, pin: pin, course: bounds)
        let mine = YardageCalculator.yardages(tee: tee, targets: hole.approachShots, pin: pin, active: 1, player: player, course: bounds)
        #expect(mine[1].toTarget == YardageCalculator.yards(from: player, to: hole.approachShots[1]))
        #expect(mine[0] == base[0] && mine[1].toPin == base[1].toPin)
        let away = Coordinate(latitude: 40.7, longitude: -74.0)
        #expect(YardageCalculator.yardages(tee: tee, targets: hole.approachShots, pin: pin, active: 1, player: away, course: bounds) == base)
        #expect(!YardageCalculator.isInside(player, bounds: [1, 2]))
    }
}
