//
//  RoundEntry.swift
//  MaynardGolf
//

import Foundation
import SwiftData

extension MaynardSchemaV1 {
    /// One player's card in one round (12-data-model §3.3).
    ///
    /// Scores are a plain array, `strokes[hole − 1]`, read and written together and synced as one small
    /// CloudKit field (§1.1). `setStrokes(_:forHole:at:)` is the only write path.
    @Model
    final class RoundEntry {
        /// App-level identity (DM-RE-01); not unique-constrained, for CloudKit.
        var id: UUID = UUID()
        /// Inverse of `Player.entries` (DM-RE-02).
        var player: Player?
        /// Inverse of `Round.entries` (DM-RE-03).
        var round: Round?
        /// 0-based selection order; sets the column order everywhere (DM-RE-04).
        var cardPosition: Int = 0
        /// One element per hole, nil = not played yet (DM-RE-05).
        private(set) var strokes: [Int?] = []

        /// A card with every hole unplayed.
        init(id: UUID = UUID(), cardPosition: Int, holeCount: HoleCount) {
            self.id = id
            self.cardPosition = cardPosition
            self.strokes = Array(repeating: nil, count: holeCount.rawValue)
        }

        /// Records a score (DM-RE-06): 1 … 12 strokes on a hole in the round. Throws `ScoreError` otherwise
        /// and changes nothing. If this was the round's last missing score, the round is complete as of
        /// `date` (DM-RD-06). The array is reassigned so SwiftData records the change.
        func setStrokes(_ value: Int, forHole hole: Int, at date: Date = .now) throws {
            guard (1...12).contains(value) else { throw ScoreError.strokesOutOfRange(value) }
            guard strokes.indices.contains(hole - 1) else { throw ScoreError.holeOutOfRange(hole) }
            var updated = strokes
            updated[hole - 1] = value
            strokes = updated
            round?.completeIfFinished(at: date)
        }

        /// The score on `hole` (1-based), or nil if it isn't played or isn't in the round (DM-RE-07).
        func strokes(forHole hole: Int) -> Int? {
            strokes.indices.contains(hole - 1) ? strokes[hole - 1] : nil
        }

        /// Total strokes on the holes played so far (DM-RE-07).
        var grossTotal: Int { strokes.compactMap { $0 }.reduce(0, +) }

        /// Strokes against par on the holes played so far (DM-RE-07, HP-DT-04). `pars[hole − 1]` is that
        /// hole's par, from the course data (`RoundHoleBuilder`, #16).
        func toPar(pars: [Int]) -> Int {
            Self.toPar(strokes, pars: pars)
        }

        /// The to-par rule, shared by this card and the scorecard (`ScorecardModel`), so Hole play and the
        /// scorecard header can't disagree: strokes minus par on the holes played; unplayed holes count
        /// nothing (DM-RE-07).
        nonisolated static func toPar(_ strokes: [Int?], pars: [Int]) -> Int {
            zip(strokes, pars).reduce(0) { total, pair in total + (pair.0.map { $0 - pair.1 } ?? 0) }
        }

        /// Every hole has a score (DM-RE-07).
        var isComplete: Bool { !strokes.isEmpty && strokes.allSatisfy { $0 != nil } }

        /// Strokes on holes 1–9 played so far (DM-RE-07).
        var front: Int { strokes.prefix(9).compactMap { $0 }.reduce(0, +) }

        /// Strokes on holes 10–18 played so far, or nil for a 9-hole round (DM-RE-07).
        var back: Int? { strokes.count > 9 ? strokes.dropFirst(9).compactMap { $0 }.reduce(0, +) : nil }
    }
}
