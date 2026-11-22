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

    /// SL-TG-10: zoomed in on the green, its center moves to the focus, everything else spreads `scale` times from
    /// it, and screen → GPS → screen still round-trips; the identity changes nothing.
    @Test func theGreenZoom() throws {
        let projection = try data.projection(hole: 3)
        let hole = try #require(data.course.holes.first { $0.number == 3 })
        let pin = projection.point(for: hole.greenCoordinates.center), tee = projection.point(for: hole.teeBoxes.white)
        let focus = CGPoint(x: 201, y: 450)
        var zoom = GreenZoom()
        zoom.begin(green: pin, focus: focus)
        let zoomed = projection.zoomed(zoom.settled)
        #expect(distance(zoomed.point(for: hole.greenCoordinates.center), focus) < 0.01)
        let spread = zoomed.point(for: hole.teeBoxes.white), s = GreenZoom.scale
        #expect(distance(spread, CGPoint(x: focus.x + (tee.x - pin.x) * s, y: focus.y + (tee.y - pin.y) * s)) < 0.01)
        let finger = CGPoint(x: focus.x + 30, y: focus.y - 12)
        #expect(distance(zoomed.point(for: zoomed.coordinate(for: finger)), finger) < 0.01)
        #expect(distance(projection.zoomed(.identity).point(for: hole.teeBoxes.white), tee) < 0.01)
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
        let blue = data.yardages(hole: 1, tee: .blue, course: course), red = data.yardages(hole: 1, tee: .red, course: course)
        let (b, r) = (try #require(blue.targets[0]), try #require(red.targets[0]))
        #expect(b.toTarget - r.toTarget > 10) // the blue box is further back
        #expect(b.toPin == r.toPin)
    }

    /// SL-YD-08 (#185): a par 3 has no target; the pin's number is from the tee.
    @Test func parThreeMeasuresToThePin() throws {
        let hole = data.course.holes[2]
        let yards = data.yardages(hole: 3, course: data.imagery.master.boundsSWNE)
        #expect(yards.targets.isEmpty)
        #expect(yards.pin == YardageCalculator.yards(from: hole.teeBoxes.white, to: hole.greenCoordinates.center) && yards.pin > 100)
    }
}

extension ShotLineFixtures {
    /// The hole's shot line as it starts.
    func shot(hole number: Int, tee: Tee = .white) -> ShotTargets {
        let hole = RoundHoleBuilder.holes(course: course, holeCount: .nine).first { $0.number == number }!
        return ShotTargets(hole: hole, tee: tee)
    }

    /// The hole's yardages as it starts, with no player.
    func yardages(hole number: Int, tee: Tee = .white, course bounds: [Double]) -> ShotYardages {
        let shot = shot(hole: number, tee: tee)
        return YardageCalculator.yardages(route: shot.route(player: nil), targets: shot.targets, pin: shot.pin, course: bounds)
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

    /// SL-YD-03, 08: on the par 5, target 1 measures from the tee and target 2 from target 1, both to the pin;
    /// the pin's own number is from target 2.
    @Test func parFiveLegs() throws {
        let hole = try #require(data.course.holes.first { $0.par == 5 })
        let (t1, t2, pin, tee) = (hole.approachShots[0], hole.approachShots[1], hole.greenCoordinates.center, hole.teeBoxes.white)
        let yards = data.yardages(hole: hole.number, course: data.imagery.master.boundsSWNE)
        #expect(yards.targets == [0: TargetYardage(toTarget: YardageCalculator.yards(from: tee, to: t1), toPin: YardageCalculator.yards(from: t1, to: pin)),
                                  1: TargetYardage(toTarget: YardageCalculator.yards(from: t1, to: t2), toPin: YardageCalculator.yards(from: t2, to: pin))])
        #expect(yards.pin == YardageCalculator.yards(from: t2, to: pin))
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

    /// SL-YD-04: with a position on the course (here off the hole, so the line keeps both targets), the active
    /// target's TO TARGET is from the player; the other target and TO PIN don't change; a position off the course,
    /// or bad bounds, is ignored.
    @Test func fromThePlayersPosition() throws {
        let hole = try #require(data.course.holes.first { $0.par == 5 })
        let bounds = data.imagery.master.boundsSWNE
        var shot = data.shot(hole: hole.number)
        shot.activate(.target(1))
        let player = Coordinate(latitude: (bounds[0] + bounds[2]) / 2, longitude: (bounds[1] + bounds[3]) / 2)
        let route = shot.route(player: player)
        try #require(route.targets == [0, 1] && !route.startsAtPlayer)
        let base = YardageCalculator.yardages(route: route, targets: shot.targets, pin: shot.pin, course: bounds)
        let mine = YardageCalculator.yardages(route: route, targets: shot.targets, pin: shot.pin, player: player, course: bounds)
        #expect(mine.targets[1]?.toTarget == YardageCalculator.yards(from: player, to: hole.approachShots[1]))
        #expect(mine.targets[0] == base.targets[0] && mine.targets[1]?.toPin == base.targets[1]?.toPin && mine.pin == base.pin)
        let away = Coordinate(latitude: 40.7, longitude: -74.0)
        #expect(YardageCalculator.yardages(route: route, targets: shot.targets, pin: shot.pin, player: away, course: bounds) == base)
        #expect(!YardageCalculator.isInside(player, bounds: [1, 2]))
    }

    /// SL-GP-02, 03, SL-YD-08 (#185): walking the hole, TO TARGET is from the player at the line's start; once the
    /// target is reached the pin's number is from the player.
    @Test func alongTheRoute() throws {
        let bounds = data.imagery.master.boundsSWNE
        let shot = data.shot(hole: 1)
        let fairway = Coordinate(latitude: shot.tee.latitude + (shot.targets[0].latitude - shot.tee.latitude) * 0.5,
                                 longitude: shot.tee.longitude + (shot.targets[0].longitude - shot.tee.longitude) * 0.5)
        let walking = YardageCalculator.yardages(route: shot.route(player: fairway), targets: shot.targets, pin: shot.pin,
                                                 player: fairway, course: bounds)
        #expect(walking.targets[0]?.toTarget == YardageCalculator.yards(from: fairway, to: shot.targets[0]))
        let atTarget = shot.targets[0]
        let reached = YardageCalculator.yardages(route: shot.route(player: atTarget), targets: shot.targets, pin: shot.pin,
                                                 player: atTarget, course: bounds)
        #expect(reached.targets.isEmpty && reached.pin == YardageCalculator.yards(from: atTarget, to: shot.pin))
    }
}
