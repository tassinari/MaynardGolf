//
//  ScorecardModel.swift
//  MaynardGolf
//

import Foundation
import MaynardUI

/// Everything a scorecard table shows, from one round (SC-BH-03): one column per player in card order,
/// the rows (holes, then OUT / IN / TOT), each player's running to-par, the round's par, how many holes
/// everyone has finished and the current hole. A pure transform of value snapshots, so it's tested
/// without a store and reused unchanged by the live Scorecard, Round detail and the PDF (SC-BH-04).
struct ScorecardModel: Equatable, Sendable {
    /// One player's column (SC-PT-02).
    struct Column: Equatable, Sendable, Identifiable {
        /// The card's id (not the player's), so the column keeps a stable identity even if the same player
        /// somehow has two cards.
        let id: UUID
        let playerID: UUID
        let firstName: String
        let color: PlayerColor
        let photoData: Data?
        /// One score per hole of the round, nil = not played.
        let scores: [Int?]
        /// Strokes against par on the holes played so far (the header's `ToParText`).
        let toPar: Int
        /// OUT / IN / TOT; OUT and IN are nil for a 9-hole round, and a sum is nil until it has a score.
        let totals: ScoreFormatter.Totals
    }

    /// A total row's segment; the raw value is its identifier part (`scorecard.total.out.{id}`).
    enum Segment: String, Equatable, Sendable {
        case out, `in`, tot
    }

    /// A table row, top to bottom in portrait (left to right in landscape).
    enum Row: Equatable, Sendable, Identifiable {
        /// A hole: its number in the round, its par and one score per column.
        case hole(number: Int, par: Int, scores: [Int?], isCurrent: Bool)
        /// A total row: the segment, its par and one sum per column (nil shows "–", SC-PT-06).
        case total(Segment, par: Int, sums: [Int?])

        var id: String {
            switch self {
            case .hole(let number, _, _, _): "hole.\(number)"
            case .total(let segment, _, _): "total.\(segment.rawValue)"
            }
        }
    }

    let holeCount: HoleCount
    /// The round's par: 35 for nine holes, 70 for eighteen at Maynard (SC-HDR-03).
    let par: Int
    /// Holes where every player has a score (SC-HDR-03).
    let thru: Int
    /// The hole being played, highlighted (SC-PT-04, SC-LS-03); nil for a finished round, so Round
    /// detail and the PDF show no highlight.
    let currentHole: Int?
    let startedAt: Date
    let weather: WeatherSnapshot?
    let columns: [Column]
    /// Portrait always reserves four positions; nil is a blank column, never a fake player or score (#204).
    static let playerSlotCount = 4
    /// Display padding shared by live and compact portrait tables; real columns remain unpadded.
    var playerSlots: [Column?] {
        (0..<Self.playerSlotCount).map { columns.indices.contains($0) ? columns[$0] : nil }
    }
    let rows: [Row]

    /// Builds the card. `players` may hold anyone; each card is matched to its player by id. A card whose
    /// player isn't there (only possible for a moment while a deletion syncs, since deleting a player
    /// deletes their cards, DM-PL-08) is left out rather than shown nameless.
    init(round: RoundSnapshot, players: [PlayerSnapshot], course: Course) {
        let holes = RoundHoleBuilder.holes(course: course, holeCount: round.holeCount)
        let pars = holes.map(\.par)
        let byID = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let columns: [Column] = round.entries.compactMap { entry in
            guard let playerID = entry.playerID, let player = byID[playerID] else { return nil }
            let scores = Self.normalized(entry.strokes, count: holes.count)
            return Column(id: entry.id, playerID: playerID, firstName: player.firstName, color: player.color,
                          photoData: player.photoData, scores: scores, toPar: RoundEntry.toPar(scores, pars: pars),
                          totals: ScoreFormatter.totals(scores))
        }
        let current = round.isComplete ? nil : round.currentHole

        holeCount = round.holeCount
        par = pars.reduce(0, +)
        thru = ScoreFormatter.holesThru(columns.map(\.scores))
        currentHole = current
        startedAt = round.startedAt
        weather = round.weather
        self.columns = columns
        rows = Self.rows(holes: holes, columns: columns, currentHole: current)
    }

    /// Holes 1–9, OUT, 10–18, IN, TOT for eighteen holes; holes 1–9 and TOT for nine (SC-PT-03, SC-LS-01).
    /// Scores are read by the hole's position in the round, not its number, so course data with odd
    /// numbering can't index past a card.
    private static func rows(holes: [RoundHole], columns: [Column], currentHole: Int?) -> [Row] {
        let holeRows: [Row] = holes.enumerated().map { position, hole in
            .hole(number: hole.number, par: hole.par, scores: columns.map { $0.scores[position] },
                  isCurrent: hole.number == currentHole)
        }
        func parSum(_ part: some Sequence<RoundHole>) -> Int { part.reduce(0) { $0 + $1.par } }
        let total = Row.total(.tot, par: parSum(holes), sums: columns.map(\.totals.total))
        guard holes.count > 9 else { return holeRows + [total] }
        return holeRows.prefix(9)
            + [.total(.out, par: parSum(holes.prefix(9)), sums: columns.map(\.totals.out))]
            + holeRows.dropFirst(9)
            + [.total(.in, par: parSum(holes.dropFirst(9)), sums: columns.map(\.totals.in))]
            + [total]
    }

    /// One score per hole: a card with too few scores is padded with unplayed holes, extra ones dropped,
    /// so a damaged card can't crash the table.
    static func normalized(_ strokes: [Int?], count: Int) -> [Int?] {
        Array((strokes + Array(repeating: nil, count: max(count - strokes.count, 0))).prefix(count))
    }
}
