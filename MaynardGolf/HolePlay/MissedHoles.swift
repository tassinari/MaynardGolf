//
//  MissedHoles.swift
//  MaynardGolf
//

import Foundation

/// The Out of order rules (07-hole-play §1.7, #192): which earlier hole is missing a score, and where
/// auto-advance goes once a hole is complete. Pure, 100 % unit coverage (HP-OO-01, 06).
enum MissedHoles {
    /// The lowest hole before `current` that isn't complete, or nil when every earlier hole is (HP-OO-01). The
    /// hole shown and the holes after it never count. `isComplete` says whether every player has a score on a hole.
    static func lowest(before current: Int, isComplete: (Int) -> Bool) -> Int? {
        (1..<max(current, 1)).first { !isComplete($0) }
    }

    /// Where auto-advance goes after `hole` became complete (HP-OO-06, HP-NAV-02): the next hole after it that
    /// isn't complete, else the lowest that isn't. Nil when every hole of the round is complete. In normal play
    /// the next hole has no scores yet, so this is `hole + 1`.
    static func advanceTarget(after hole: Int, holeCount: Int, isComplete: (Int) -> Bool) -> Int? {
        let later = hole < holeCount ? Array((hole + 1)...holeCount) : []
        return later.first { !isComplete($0) } ?? (1...max(holeCount, 1)).first { $0 != hole && !isComplete($0) }
    }
}
