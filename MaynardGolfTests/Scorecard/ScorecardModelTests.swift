//
//  ScorecardModelTests.swift
//  MaynardGolfTests
//

import Foundation
import MaynardUI
import SwiftData
import Testing
@testable import MaynardGolf

/// SC-BH-03, SC-HDR-03, SC-PT-03, SC-PT-06, SC-LS-01: the scorecard model from fixed rounds.
@MainActor
struct ScorecardModelTests {
    private let course: Course

    init() throws {
        course = try BundleCourseProvider().course(id: "MaynardGC")
    }

    /// A round in a fresh in-memory store, returned as the snapshots the model is built from.
    private func card(holeCount: HoleCount, names: [String] = ["Mark", "Scottie"], thru: Int? = nil,
                      scores: [[Int]]? = nil, weather: WeatherSnapshot? = nil) throws -> ScorecardModel {
        let context = try makeInMemoryContext()
        let players = names.enumerated().map { ModelFixtures.player($0.element, color: PlayerColor.allCases[$0.offset], in: context) }
        let round = try ModelFixtures.round(players: players, holeCount: holeCount, weather: weather, thru: thru,
                                            scores: scores, in: context)
        return ScorecardModel(round: RoundSnapshot(round), players: players.map(PlayerSnapshot.init), course: course)
    }

    private nonisolated static let front: [String] = (1...9).map { "hole.\($0)" }
    private nonisolated static let back: [String] = (10...18).map { "hole.\($0)" }
    private nonisolated static let nineRows: [String] = front + ["total.tot"]
    private nonisolated static let eighteenRows: [String] = front + ["total.out"] + back + ["total.in", "total.tot"]

    /// SC-PT-03: 18 holes → 1–9, OUT, 10–18, IN, TOT; 9 holes → 1–9, TOT.
    @Test(arguments: [(HoleCount.nine, nineRows), (HoleCount.eighteen, eighteenRows)])
    func rowOrder(holeCount: HoleCount, ids: [String]) throws {
        #expect(try card(holeCount: holeCount).rows.map(\.id) == ids)
    }

    /// SC-HDR-03: par 35 for nine holes, 70 for eighteen; total rows carry their segment's par.
    @Test func parsAndTotalRowPars() throws {
        let nine = try card(holeCount: .nine)
        #expect(nine.par == 35)
        let eighteen = try card(holeCount: .eighteen)
        #expect(eighteen.par == 70)
        let totals = eighteen.rows.compactMap { row -> (ScorecardModel.Segment, Int)? in
            if case .total(let segment, let par, _) = row { return (segment, par) }
            return nil
        }
        #expect(totals.map(\.0) == [.out, .in, .tot])
        #expect(totals.map(\.1) == [35, 35, 70])
        // Row 9 is OUT, so row 11 is hole 11, which replays hole 2 (par 5).
        if case .hole(let number, let par, _, _) = eighteen.rows[11] {
            #expect(number == 11 && par == 5)
        } else {
            Issue.record("row 11 should be hole 11")
        }
    }

    /// A finished 18-hole round: every sum and to-par from known scores.
    @Test func finishedEighteenHoleTotals() throws {
        let front = [4, 5, 3, 4, 4, 3, 4, 4, 4] // par
        let back = [5, 6, 4, 5, 5, 4, 5, 5, 5] // bogey every hole
        let model = try card(holeCount: .eighteen, names: ["Mark"], scores: [front + back])
        let column = try #require(model.columns.first)
        #expect(column.totals == ScoreFormatter.Totals(out: 35, in: 44, total: 79))
        #expect(column.toPar == 9)
        #expect(model.thru == 18)
        #expect(model.currentHole == nil) // finished: no highlight (SC-BH-04)
        #expect(model.rows.last == .total(.tot, par: 70, sums: [79]))
    }

    /// An in-progress round: running to-par, THRU, the current hole, blank segments and unplayed holes.
    @Test func inProgressRound() throws {
        let model = try card(holeCount: .eighteen, thru: 3, scores: [[3, 5, 3] + Array(repeating: 4, count: 15),
                                                                     [5, 6, 4] + Array(repeating: 4, count: 15)])
        #expect(model.thru == 3)
        #expect(model.currentHole == 4)
        #expect(model.columns.map(\.toPar) == [-1, 3])
        #expect(model.columns.map(\.totals) == [ScoreFormatter.Totals(out: 11, in: nil, total: 11),
                                                ScoreFormatter.Totals(out: 15, in: nil, total: 15)])
        #expect(model.rows.first { $0.id == "hole.4" } == .hole(number: 4, par: 4, scores: [nil, nil], isCurrent: true))
        #expect(model.rows.first { $0.id == "hole.1" } == .hole(number: 1, par: 4, scores: [3, 5], isCurrent: false))
        #expect(model.rows.first { $0.id == "total.in" } == .total(.in, par: 35, sums: [nil, nil])) // "–"
    }

    /// SC-HDR-03: THRU counts only holes every player has scored.
    @Test func thruNeedsEveryPlayer() throws {
        let context = try makeInMemoryContext()
        let mark = ModelFixtures.player("Mark", in: context)
        let phil = ModelFixtures.player("Phil", in: context)
        let round = try ModelFixtures.round(players: [mark, phil], thru: 0, in: context)
        try round.sortedEntries[0].setStrokes(4, forHole: 1)
        try round.sortedEntries[0].setStrokes(5, forHole: 2)
        try round.sortedEntries[1].setStrokes(4, forHole: 1)
        let model = ScorecardModel(round: RoundSnapshot(round), players: [mark, phil].map(PlayerSnapshot.init), course: course)
        #expect(model.thru == 1)
    }

    /// Columns follow card order and carry the header's details; weather and start come from the round.
    @Test func columnsAndHeader() throws {
        let weather = ModelFixtures.weather(.sunny, temperatureF: 62)
        let model = try card(holeCount: .nine, names: ["Mark", "Scottie", "Tiger"], weather: weather)
        #expect(model.columns.map(\.firstName) == ["Mark", "Scottie", "Tiger"])
        #expect(model.columns.map(\.color) == Array(PlayerColor.allCases.prefix(3)))
        #expect(model.columns.allSatisfy { $0.scores.count == 9 && $0.photoData == nil })
        #expect(model.weather == weather)
        #expect(model.startedAt == ModelFixtures.referenceDate)
        #expect(model.holeCount == .nine)
    }

    /// A card whose player isn't in `players` is left out instead of shown nameless.
    @Test func aCardWithoutItsPlayerIsLeftOut() throws {
        let context = try makeInMemoryContext()
        let mark = ModelFixtures.player("Mark", in: context)
        let phil = ModelFixtures.player("Phil", in: context)
        let round = try ModelFixtures.completedRound(players: [mark, phil], in: context)
        let model = ScorecardModel(round: RoundSnapshot(round), players: [PlayerSnapshot(phil)], course: course)
        #expect(model.columns.map(\.firstName) == ["Phil"])
        #expect(model.rows.allSatisfy {
            switch $0 {
            case .hole(_, _, let scores, _): scores.count == 1
            case .total(_, _, let sums): sums.count == 1
            }
        })
    }

    /// The same player listed twice is matched once (the first copy).
    @Test func duplicatePlayersAreMatchedOnce() throws {
        let context = try makeInMemoryContext()
        let mark = ModelFixtures.player("Mark", in: context)
        let round = try ModelFixtures.completedRound(players: [mark], in: context)
        let snapshot = PlayerSnapshot(mark)
        let model = ScorecardModel(round: RoundSnapshot(round), players: [snapshot, snapshot], course: course)
        #expect(model.columns.map(\.firstName) == ["Mark"])
    }

    /// One to-par rule for the card and the scorecard (`RoundEntry.toPar`).
    @Test func toParCountsOnlyPlayedHoles() {
        #expect(RoundEntry.toPar([3, nil, 5], pars: [4, 4, 4]) == 0)
        #expect(RoundEntry.toPar([], pars: [4]) == 0)
    }

    /// Rows read scores by position: a course whose holes aren't numbered 1… still builds without trapping.
    @Test func rowsReadScoresByPosition() throws {
        let context = try makeInMemoryContext()
        let mark = ModelFixtures.player("Mark", in: context)
        let round = try ModelFixtures.completedRound(players: [mark], in: context)
        let renumbered = course.holes.map { hole in
            Hole(number: hole.number + 100, par: hole.par, yardage: hole.yardage, handicapFront: hole.handicapFront,
                 handicapBack: hole.handicapBack, greenCoordinates: hole.greenCoordinates,
                 teeCoordinates: hole.teeCoordinates, landingPoints: hole.landingPoints)
        }
        let odd = Course(id: course.id, name: course.name, coordinate: course.coordinate, tees: course.tees,
                         holes: renumbered, localRules: course.localRules)
        let model = ScorecardModel(round: RoundSnapshot(round), players: [PlayerSnapshot(mark)], course: odd)
        #expect(model.rows.first == .hole(number: 101, par: 4, scores: [RoundSnapshot(round).entries[0].strokes[0]], isCurrent: false))
    }

    /// A damaged card can't crash the table: short cards are padded, long ones trimmed.
    @Test func scoresAreNormalizedToTheHoleCount() {
        #expect(ScorecardModel.normalized([4, 5], count: 4) == [4, 5, nil, nil])
        #expect(ScorecardModel.normalized([4, 5, 3], count: 2) == [4, 5])
        #expect(ScorecardModel.normalized([], count: 0) == [])
    }
}
