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
    /// at both (three legs), and a par 3 has no target, its pin is the target (one leg, #185). The panel starts on
    /// target 1, or the pin on a par 3.
    @Test func routesAndStarts() {
        let four = targets(1), five = targets(2), three = targets(3)
        let h1 = course.holes[0], h2 = course.holes[1], h3 = course.holes[2]
        #expect(four.points == [h1.teeBoxes.white, h1.approachShots[0], h1.greenCoordinates.center])
        #expect(five.points == [h2.teeBoxes.white] + h2.approachShots + [h2.greenCoordinates.center])
        #expect(three.targets.isEmpty && three.points == [h3.teeBoxes.white, h3.greenCoordinates.center])
        #expect(four.active == .target(0) && four.hole == 1 && four.par == 4)
        #expect(three.active == .pin)
        #expect(ShotTargets.starts(par: 3, approachShots: h3.approachShots).isEmpty)
        #expect(ShotTargets.starts(par: 4, approachShots: h1.approachShots) == h1.approachShots)
    }

    /// SL-TS-03: the line starts at the round's tee box.
    @Test func theRoundsTee() {
        #expect(targets(1, tee: .blue).tee == course.holes[0].teeBoxes.blue)
        #expect(targets(1, tee: .red).tee == course.holes[0].teeBoxes.red)
    }

    /// SL-CD-05: hole 10 of an 18-hole round replays hole 1 and keeps its own number.
    @Test func backNineReplaysTheFront() {
        let ten = targets(10, holeCount: .eighteen)
        #expect(ten.hole == 10 && ten.points == targets(1).points)
    }

    /// SL-TG-02, 06, 08: a move puts a target or the pin there and makes it the active one; missing targets do
    /// nothing.
    @Test func movesAndActive() {
        var shot = targets(2)
        let spot = Coordinate(latitude: 42.444, longitude: -71.450)
        shot.move(.target(1), to: spot)
        #expect(shot.targets[1] == spot && shot.active == .target(1))
        shot.activate(.target(0))
        #expect(shot.active == .target(0))
        shot.move(.pin, to: spot)
        #expect(shot.pin == spot && shot.active == .pin && shot.coordinate(of: .pin) == spot)
        let before = shot
        shot.activate(.target(5))
        shot.move(.target(-1), to: spot)
        shot.step(.target(9), towardPin: true)
        #expect(shot == before && shot.coordinate(of: .target(2)) == nil)
    }

    /// SL-TG-07: 10 yards toward the pin or the tee along the line, never past the end.
    @Test func voiceOverStepsATarget() {
        var shot = targets(1)
        let start = shot.targets[0]
        shot.step(.target(0), towardPin: true)
        #expect(abs(YardageCalculator.yards(from: start, to: shot.targets[0]) - 10) < 0.1)
        #expect(YardageCalculator.yards(from: shot.targets[0], to: shot.pin) < YardageCalculator.yards(from: start, to: shot.pin))
        shot.step(.target(0), towardPin: false, yards: 100_000) // a long step stops at the tee
        #expect(shot.targets[0] == shot.tee)
        shot.step(.target(0), towardPin: false) // already there: nothing to step toward
        #expect(shot.targets[0] == shot.tee)
    }

    /// SL-TG-08 (#185): the pin steps 10 yards farther from the point before it, or back toward it, stopping there.
    @Test func voiceOverStepsThePin() {
        var shot = targets(3)
        let start = shot.pin
        let length = YardageCalculator.yards(from: shot.tee, to: start)
        shot.step(.pin, towardPin: true)
        #expect(abs(YardageCalculator.yards(from: shot.tee, to: shot.pin) - (length + 10)) < 0.1)
        shot.step(.pin, towardPin: false)
        shot.step(.pin, towardPin: false)
        #expect(abs(YardageCalculator.yards(from: shot.tee, to: shot.pin) - (length - 10)) < 0.1)
        shot.step(.pin, towardPin: false, yards: 100_000) // stops at the tee
        #expect(shot.pin == shot.tee)
        shot.step(.pin, towardPin: true) // on the tee there's no line to extend
        #expect(shot.pin == shot.tee)
        var four = targets(1) // a par 4's pin extends from its target
        let pin = four.pin
        four.step(.pin, towardPin: true)
        #expect(abs(YardageCalculator.yards(from: four.targets[0], to: four.pin) - YardageCalculator.yards(from: four.targets[0], to: pin) - 10) < 0.1)
    }

    /// SL-TG-10: the green zoom is on while the pin is held. Fully zoomed in, the green's center sits at the focus
    /// and the rest spreads `scale` times from it; halfway, it's halfway there; at 1 (or let go) nothing moves. The
    /// points are kept for the zoom out.
    @Test func greenZoom() {
        var zoom = GreenZoom()
        #expect(!zoom.isOn && zoom.scale == 1 && zoom.settled == .identity)
        let green = CGPoint(x: 100, y: 200), focus = CGPoint(x: 200, y: 450)
        zoom.begin(green: green, focus: focus)
        #expect(zoom.isOn && zoom.scale == GreenZoom.scale && zoom.anchor == green && zoom.focus == focus)
        #expect(green.applying(zoom.settled) == focus)
        #expect(CGPoint(x: 110, y: 200).applying(zoom.settled) == CGPoint(x: 200 + 10 * GreenZoom.scale, y: 450))
        #expect(green.applying(zoom.transform(at: (1 + GreenZoom.scale) / 2)) == CGPoint(x: 150, y: 325))
        #expect(zoom.transform(at: 1) == .identity)
        zoom.end()
        #expect(!zoom.isOn && zoom.settled == .identity && zoom.anchor == green && zoom.focus == focus)
    }

    /// SL-TG-04: the playable area and clamping.
    @Test func playableAreaAndClamp() {
        let screen = CGSize(width: 402, height: 874)
        let area = ShotLayout.playable(screen: screen, top: 250, bottom: 700)
        #expect(area == CGRect(x: 24, y: 250, width: 354, height: 450))
        #expect(ShotLayout.clamp(CGPoint(x: 0, y: 100), to: area) == CGPoint(x: 24, y: 250))
        #expect(ShotLayout.clamp(CGPoint(x: 500, y: 900), to: area) == CGPoint(x: 378, y: 700))
        #expect(ShotLayout.clamp(CGPoint(x: 200, y: 400), to: area) == CGPoint(x: 200, y: 400))
        // The map buttons are kept clear: a point on them goes to the nearer free edge, left or below; beside them
        // the row stays playable.
        let buttons = CGRect(x: 200, y: 250, width: 186, height: 56)
        #expect(ShotLayout.clamp(CGPoint(x: 210, y: 260), to: area, avoiding: [buttons]) == CGPoint(x: 200, y: 260))
        #expect(ShotLayout.clamp(CGPoint(x: 300, y: 300), to: area, avoiding: [buttons]) == CGPoint(x: 300, y: 306))
        #expect(ShotLayout.clamp(CGPoint(x: 100, y: 200), to: area, avoiding: [buttons]) == CGPoint(x: 100, y: 250))
        #expect(ShotLayout.clamp(CGPoint(x: 300, y: 100), to: area, avoiding: [buttons]) == CGPoint(x: 300, y: 306))
        #expect(ShotLayout.clamp(CGPoint(x: 300, y: 100), to: area) == CGPoint(x: 300, y: 250))
        // The limit is the Exit button, so the hole card is kept clear too; a point pushed below the card onto the
        // buttons goes on below them.
        let high = ShotLayout.playable(screen: screen, top: 100, bottom: 700)
        let card = CGRect(x: 250, y: 60, width: 136, height: 130), row = CGRect(x: 190, y: 190, width: 196, height: 56)
        #expect(ShotLayout.clamp(CGPoint(x: 150, y: 120), to: high, avoiding: [card, row]) == CGPoint(x: 150, y: 120))
        #expect(ShotLayout.clamp(CGPoint(x: 260, y: 150), to: high, avoiding: [card, row]) == CGPoint(x: 250, y: 150))
        #expect(ShotLayout.clamp(CGPoint(x: 330, y: 180), to: high, avoiding: [card, row]) == CGPoint(x: 330, y: 246))
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

/// 14-shot-lines §3a (#185): where the line starts and which targets it keeps as the player walks the hole
/// (SL-GP-01…05, SL-TS-11, 100 %).
struct ShotRouteTests {
    private let course: Course

    init() throws { course = try BundleCourseProvider().course(id: "MaynardGC") }

    private func shot(_ number: Int) -> ShotTargets {
        let hole = RoundHoleBuilder.holes(course: course, holeCount: .nine).first { $0.number == number }!
        return ShotTargets(hole: hole, tee: .white)
    }

    /// `yards` from `a` toward `b` (or past it), along the straight line.
    private func along(_ a: Coordinate, _ b: Coordinate, yards: Double) -> Coordinate {
        let share = yards / YardageCalculator.yards(from: a, to: b)
        return Coordinate(latitude: a.latitude + (b.latitude - a.latitude) * share,
                          longitude: a.longitude + (b.longitude - a.longitude) * share)
    }

    /// SL-GP-01: without a position the line is tee → targets → pin, as without GPS.
    @Test func withoutAPosition() {
        let four = shot(1)
        let route = four.route(player: nil)
        #expect(!route.pinIsTarget) // SL-DR-05: the target is still ahead
        #expect(route == ShotRoute(shot: four, player: nil))
        #expect(route.start == four.tee && !route.startsAtPlayer && route.targets == [0])
        #expect(route.points == four.points && route.active == .target(0))
    }

    /// SL-GP-01, 02: within 30 yards of the tee the dot stays apart and the line starts at the tee; past that it
    /// starts at the dot (and the tee marker goes).
    @Test func theLineStartsAtThePlayerPastTheTee() {
        let four = shot(1)
        let nearTee = along(four.tee, four.targets[0], yards: 25)
        let near = four.route(player: nearTee)
        #expect(!near.startsAtPlayer && near.start == four.tee && near.points == four.points)
        let fairway = along(four.tee, four.targets[0], yards: 90)
        let walking = four.route(player: fairway)
        #expect(walking.startsAtPlayer && walking.start == fairway)
        #expect(walking.points == [fairway, four.targets[0], four.pin] && walking.targets == [0])
    }

    /// SL-GP-03: within 50 yards of a target it leaves the line, which goes on to the pin, and the panel moves to
    /// the pin; walking back out past 50 yards brings it back.
    @Test func aReachedTargetLeavesTheLine() {
        let four = shot(1)
        let short = along(four.targets[0], four.tee, yards: 40)
        let reached = four.route(player: short)
        #expect(reached.targets.isEmpty && reached.points == [short, four.pin] && reached.active == .pin)
        #expect(reached.pinIsTarget) // SL-DR-05: the next shot is to the green, so the pin is drawn as the target
        let back = along(four.targets[0], four.tee, yards: 60)
        let again = four.route(player: back)
        #expect(again.targets == [0] && again.active == .target(0))
    }

    /// SL-GP-03, SL-GP-05 (par 5): target 1 reached → the line goes on through target 2, which takes the panel;
    /// target 2 reached → both are gone, even when target 1 was never within reach.
    @Test func parFiveDropsTargetsInOrder() {
        let five = shot(2)
        let atFirst = along(five.targets[0], five.tee, yards: 20)
        let first = five.route(player: atFirst)
        #expect(first.targets == [1] && first.active == .target(1))
        #expect(first.points == [atFirst, five.targets[1], five.pin])
        let atSecond = along(five.targets[1], five.pin, yards: 20)
        #expect(YardageCalculator.yards(from: atSecond, to: five.targets[0]) > ShotRoute.targetReach)
        let second = five.route(player: atSecond)
        #expect(second.targets.isEmpty && second.points == [atSecond, five.pin] && second.active == .pin)
        var later = five
        later.activate(.target(1)) // an active target still on the line keeps the panel
        #expect(later.route(player: atFirst).active == .target(1))
        later.activate(.pin)
        #expect(later.route(player: atFirst).active == .pin)
    }

    /// SL-TG-09: a target dragged toward the player stops `keepClear` yards from them in the finger's direction, so
    /// it stays on the line; dropped on the player it doesn't move. On a par 5 dragging target 2 near the player
    /// keeps target 1 too. Without a position, or off the hole, it goes where it's dragged.
    @Test func aDraggedTargetStopsShortOfThePlayer() throws {
        let four = shot(1)
        let fairway = along(four.tee, four.targets[0], yards: 120)
        let near = along(fairway, four.targets[0], yards: 20)
        var dragged = four
        dragged.move(.target(0), to: near, player: fairway)
        let held = dragged.targets[0]
        #expect(abs(YardageCalculator.yards(from: fairway, to: held) - ShotRoute.keepClear) < 0.1)
        #expect(abs(YardageCalculator.yards(from: near, to: held) - (ShotRoute.keepClear - 20)) < 0.1) // same direction
        #expect(dragged.route(player: fairway).targets == [0] && dragged.active == .target(0))
        let far = along(fairway, four.targets[0], yards: 80)
        dragged.move(.target(0), to: far, player: fairway)
        #expect(dragged.targets[0] == far) // outside reach: where it's dragged
        dragged.move(.target(0), to: fairway, player: fairway)
        #expect(dragged.targets[0] == far) // on the player: no direction, it stays
        var free = four
        free.move(.target(0), to: near)
        #expect(free.targets[0] == near)
        var off = four
        off.move(.target(0), to: near, player: shot(5).tee) // off the hole
        #expect(off.targets[0] == near)

        let five = shot(2)
        let between = along(five.targets[0], five.targets[1], yards: 70) // the leg is 140 yards
        var two = five
        two.move(.target(1), to: along(between, five.targets[1], yards: 10), player: between)
        #expect(two.route(player: between).targets == [0, 1] && two.route(player: between).active == .target(1))
        #expect(ShotRoute.clear(of: between, between) == nil)
        _ = try #require(ShotRoute.clear(of: between, five.pin))
    }

    /// SL-GP-04: a par 3 keeps the dot apart: the line stays tee → pin wherever the player is.
    @Test func parThreeKeepsTheDotApart() {
        let three = shot(3)
        let halfway = along(three.tee, three.pin, yards: 80)
        let route = three.route(player: halfway)
        #expect(!route.startsAtPlayer && route.points == [three.tee, three.pin] && route.active == .pin)
        #expect(route.pinIsTarget && three.route(player: nil).pinIsTarget) // SL-DR-05
    }

    /// SL-GP-05: a position more than 75 yards from this hole's line (on another hole) leaves the line alone.
    @Test func aPlayerOnAnotherHoleIsIgnored() {
        let four = shot(1)
        let elsewhere = shot(5).tee
        #expect(ShotRoute.distance(from: elsewhere, toLine: four.points) > ShotRoute.onHole)
        #expect(four.route(player: elsewhere) == four.route(player: nil))
    }

    /// The distance to the line: 0 on it, the perpendicular beside it, the nearest end past it, and a point for a
    /// leg with no length.
    @Test func distanceToTheLine() {
        let a = Coordinate(latitude: 42.44, longitude: -71.45), b = Coordinate(latitude: 42.45, longitude: -71.45)
        let middle = Coordinate(latitude: 42.445, longitude: -71.45)
        #expect(ShotRoute.distance(from: middle, toLine: [a, b]) < 0.01)
        let beside = Coordinate(latitude: 42.445, longitude: -71.449)
        #expect(abs(ShotRoute.distance(from: beside, toLine: [a, b]) - YardageCalculator.yards(from: middle, to: beside)) < 0.5)
        let past = Coordinate(latitude: 42.451, longitude: -71.45)
        #expect(abs(ShotRoute.distance(from: past, toLine: [a, b]) - YardageCalculator.yards(from: b, to: past)) < 0.5)
        #expect(abs(ShotRoute.distance(from: past, toLine: [b, b]) - YardageCalculator.yards(from: b, to: past)) < 0.5)
        #expect(ShotRoute.distance(from: past, toLine: [b]) == .infinity)
    }
}
