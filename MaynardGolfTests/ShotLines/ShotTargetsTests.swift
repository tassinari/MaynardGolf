//
//  ShotTargetsTests.swift
//  MaynardGolfTests
//

import CoreGraphics
import Foundation
import Testing
@testable import MaynardGolf

/// 14-shot-lines §2–3 (#106): the route, the targets' start, moves, VoiceOver steps, layout and visibility (100 %).
struct ShotTargetsTests {
    private let course: Course

    init() throws { course = try BundleCourseProvider().course(id: "MaynardGC") }

    private func targets(_ number: Int, tee: Tee = .white, holeCount: HoleCount = .nine) -> ShotTargets {
        let hole = RoundHoleBuilder.holes(course: course, holeCount: holeCount).first { $0.number == number }!
        return ShotTargets(hole: hole, tee: tee)
    }

    /// SL-TS-02, SL-DR-04, SL-TG-05: tee → targets → pin; a par 4 starts at its approach shot (two legs), a par 5
    /// at both (three legs), a par 3 on the pin (two legs, the second with no length).
    @Test func routesAndStarts() {
        let four = targets(1), five = targets(2), three = targets(3)
        let h1 = course.holes[0], h2 = course.holes[1], h3 = course.holes[2]
        #expect(four.route == [h1.teeBoxes.white, h1.approachShots[0], h1.greenCoordinates.center])
        #expect(five.route == [h2.teeBoxes.white] + h2.approachShots + [h2.greenCoordinates.center])
        #expect(three.targets == [h3.greenCoordinates.center])
        #expect(three.route.count == 3 && three.route[1] == three.route[2])
        #expect(four.active == 0 && four.hole == 1)
        #expect(ShotTargets.starts(par: 3, approachShots: [h1.approachShots[0]], pin: h3.greenCoordinates.center) == [h3.greenCoordinates.center])
    }

    /// SL-TS-03: the line starts at the round's tee box.
    @Test func theRoundsTee() {
        #expect(targets(1, tee: .blue).tee == course.holes[0].teeBoxes.blue)
        #expect(targets(1, tee: .red).tee == course.holes[0].teeBoxes.red)
    }

    /// SL-CD-05: hole 10 of an 18-hole round replays hole 1 and keeps its own number.
    @Test func backNineReplaysTheFront() {
        let ten = targets(10, holeCount: .eighteen)
        #expect(ten.hole == 10 && ten.route == targets(1).route)
    }

    /// SL-TG-02, 06: a move puts the target there and makes it the active one; bad indexes do nothing.
    @Test func movesAndActive() {
        var shot = targets(2)
        let spot = Coordinate(latitude: 42.444, longitude: -71.450)
        shot.move(1, to: spot)
        #expect(shot.targets[1] == spot && shot.active == 1)
        shot.activate(0)
        #expect(shot.active == 0)
        let before = shot
        shot.activate(5)
        shot.move(-1, to: spot)
        shot.step(9, towardPin: true)
        #expect(shot == before)
    }

    /// SL-TG-07: 10 yards toward the pin or the tee along the line, never past the end.
    @Test func voiceOverSteps() {
        var shot = targets(1)
        let start = shot.targets[0]
        shot.step(0, towardPin: true)
        #expect(abs(YardageCalculator.yards(from: start, to: shot.targets[0]) - 10) < 0.1)
        #expect(YardageCalculator.yards(from: shot.targets[0], to: shot.pin) < YardageCalculator.yards(from: start, to: shot.pin))
        shot.step(0, towardPin: false)
        shot.step(0, towardPin: false)
        #expect(YardageCalculator.yards(from: shot.targets[0], to: shot.tee) < YardageCalculator.yards(from: start, to: shot.tee))
        var three = targets(3) // already on the pin: nothing to step toward
        three.step(0, towardPin: true)
        #expect(three.targets[0] == three.pin)
        three.step(0, towardPin: false, yards: 100_000) // a long step stops at the tee
        #expect(three.targets[0] == three.tee)
    }

    /// SL-TG-04: the playable area and clamping.
    @Test func playableAreaAndClamp() {
        let screen = CGSize(width: 402, height: 874)
        let area = ShotLayout.playable(screen: screen, top: 250, bottom: 700)
        #expect(area == CGRect(x: 24, y: 250, width: 354, height: 450))
        #expect(ShotLayout.clamp(CGPoint(x: 0, y: 100), to: area) == CGPoint(x: 24, y: 250))
        #expect(ShotLayout.clamp(CGPoint(x: 500, y: 900), to: area) == CGPoint(x: 378, y: 700))
        #expect(ShotLayout.clamp(CGPoint(x: 200, y: 400), to: area) == CGPoint(x: 200, y: 400))
        // Unmeasured or crossed limits stay inside the screen.
        #expect(ShotLayout.playable(screen: screen, top: -10, bottom: .infinity) == CGRect(x: 24, y: 0, width: 354, height: 874))
        #expect(ShotLayout.playable(screen: screen, top: 600, bottom: 500).height == 0)
        #expect(ShotLayout.playable(screen: CGSize(width: 30, height: 100), top: 0, bottom: 100).width == 0)
    }

    /// SL-YD-01: 30 pt below the target, kept 12 pt inside the screen; a screen too small centers it.
    @Test func panelPosition() {
        let screen = CGSize(width: 402, height: 874), panel = CGSize(width: 150, height: 56)
        #expect(ShotLayout.panelCenter(target: CGPoint(x: 200, y: 300), panel: panel, screen: screen) == CGPoint(x: 200, y: 358))
        #expect(ShotLayout.panelCenter(target: CGPoint(x: 10, y: 850), panel: panel, screen: screen) == CGPoint(x: 87, y: 834))
        #expect(ShotLayout.panelCenter(target: .zero, panel: panel, screen: CGSize(width: 100, height: 40)) == CGPoint(x: 50, y: 20))
    }

    /// SL-TS-06, SL-DR-06, SL-MO-04: off shows only the pin; moving hides everything.
    @Test func visibility() {
        let on = ShotOverlayVisibility(showShotLine: true, isMoving: false)
        #expect(on.showsPin && on.showsRoute)
        let off = ShotOverlayVisibility(showShotLine: false, isMoving: false)
        #expect(off.showsPin && !off.showsRoute)
        let moving = ShotOverlayVisibility(showShotLine: true, isMoving: true)
        #expect(!moving.showsPin && !moving.showsRoute)
    }
}
