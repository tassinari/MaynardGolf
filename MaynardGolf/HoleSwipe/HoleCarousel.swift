//
//  HoleCarousel.swift
//  MaynardGolf
//

import Foundation

/// Pure wrap-around position over the course's holes.
/// Hole numbers are 1-based; moving past the last hole returns to hole 1, and back from hole 1 goes to the last.
struct HoleCarousel: Equatable {
    let holeCount: Int
    private(set) var current: Int

    init(holeCount: Int = 9, current: Int = 1) {
        precondition(holeCount > 0, "A course needs at least one hole")
        self.holeCount = holeCount
        self.current = Self.wrap(current, count: holeCount)
    }

    /// The hole after the current one, wrapping from the last hole to 1.
    var next: Int { Self.wrap(current + 1, count: holeCount) }

    /// The hole before the current one, wrapping from 1 to the last hole.
    var previous: Int { Self.wrap(current - 1, count: holeCount) }

    mutating func advance() { current = next }

    mutating func goBack() { current = previous }

    private static func wrap(_ hole: Int, count: Int) -> Int {
        ((hole - 1) % count + count) % count + 1
    }
}
