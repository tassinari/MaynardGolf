//
//  RoundHoleBuilder.swift
//  MaynardGolf
//

import Foundation

/// One hole of a round (DM-CD-04): its number in the round (1…18), the course hole it plays, and its
/// handicap for this round length.
struct RoundHole: Equatable, Hashable, Sendable, Identifiable {
    let number: Int
    let source: Hole
    let handicap: Int

    var id: Int { number }
    var par: Int { source.par }
}

/// Builds a round's holes from the 9-hole course (DM-CD-04, CRS-HC-01…03).
enum RoundHoleBuilder {
    /// 18 holes: 1–9 with the front handicaps, 10–18 replaying 1–9 with the back handicaps.
    /// 9 holes: 1–9 with the rank of the front handicaps, 1…9 (calculated, not stored).
    static func holes(course: Course, holeCount: HoleCount) -> [RoundHole] {
        let nine = course.holes
        switch holeCount {
        case .eighteen:
            return nine.map { RoundHole(number: $0.number, source: $0, handicap: $0.handicapFront) }
                + nine.map { RoundHole(number: $0.number + 9, source: $0, handicap: $0.handicapBack) }
        case .nine:
            // A hole's rank is 1 + how many holes have a lower (harder) front handicap.
            return nine.map { hole in
                RoundHole(number: hole.number, source: hole,
                          handicap: nine.filter { $0.handicapFront < hole.handicapFront }.count + 1)
            }
        }
    }

    /// Pars in hole order, for `RoundEntry.toPar(pars:)`.
    static func pars(course: Course, holeCount: HoleCount) -> [Int] {
        holes(course: course, holeCount: holeCount).map(\.par)
    }

    /// Total yards from a tee for a round of this length.
    static func yards(course: Course, holeCount: HoleCount, tee: Tee) -> Int {
        holes(course: course, holeCount: holeCount).reduce(0) { $0 + $1.source.yards(from: tee) }
    }
}
