//
//  CardSwipeTests.swift
//  MaynardGolfTests
//

import Testing
@testable import MaynardGolf

/// HOME-IPR-09 (#211): the In-progress card's swipe follows the finger, opens, closes and asks (100 %).
struct CardSwipeTests {
    private let width = 360.0

    /// The card follows a left swipe from where it rests, never right of closed nor past its own width.
    @Test(arguments: [(-40.0, -40.0), (30.0, 0.0), (-500.0, -360.0), (0.0, 0.0)])
    func followsTheFinger(translation: Double, offset: Double) {
        #expect(CardSwipe().offset(translation: translation, width: width) == offset)
    }

    /// An open card swipes on from its resting place, and a negative width can't push it right.
    @Test func followsFromOpen() {
        var swipe = CardSwipe()
        #expect(swipe.release(translation: -100, velocity: 0, width: width) == .open)
        #expect(swipe.isOpen && swipe.restingOffset == -CardSwipe.actionWidth)
        #expect(swipe.offset(translation: -20, width: width) == -CardSwipe.actionWidth - 20)
        #expect(swipe.offset(translation: 200, width: width) == 0)
        #expect(CardSwipe().offset(translation: -20, width: -5) == 0)
    }

    /// Letting go: short swipes close, past half the action (or a flick) opens, a long swipe asks.
    @Test(arguments: [
        (-20.0, 0.0, CardSwipe.Release.close),
        (-50.0, 0.0, .open),
        (-20.0, -400.0, .open),      // a flick
        (-80.0, 600.0, .close),      // flung back
        (-216.0, 0.0, .discard),     // 60 % of 360
        (-215.0, 0.0, .open),
    ])
    func release(translation: Double, velocity: Double, outcome: CardSwipe.Release) {
        var swipe = CardSwipe()
        #expect(swipe.release(translation: translation, velocity: velocity, width: width) == outcome)
        #expect(swipe.isOpen == (outcome == .open))
    }

    /// An unmeasured card (width 0) never full-swipes; it can still open.
    @Test func unmeasuredCard() {
        var swipe = CardSwipe()
        #expect(swipe.release(translation: -60, velocity: 0, width: 0) == .close) // clamped to 0 wide
        #expect(!swipe.isOpen)
    }

    /// A tap, the uncovered action or a cancelled swipe closes an open card; a swipe right closes it too.
    @Test func closes() {
        var swipe = CardSwipe()
        _ = swipe.release(translation: -100, velocity: 0, width: width)
        swipe.close()
        #expect(swipe == CardSwipe())
        _ = swipe.release(translation: -100, velocity: 0, width: width)
        #expect(swipe.release(translation: 80, velocity: 0, width: width) == .close)
    }
}
