//
//  FixtureTests.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
import Testing
@testable import MaynardGolf

/// DM-TS-01: every named data set contains what its name says.
@MainActor
struct FixtureTests {
    private func load(_ fixture: Fixture) throws -> ModelContext {
        try makeContext(.seeded(fixture))
    }

    private func counts(_ context: ModelContext) throws -> (players: Int, completed: Int, inProgress: Int) {
        (try context.fetchCount(FetchDescriptor<Player>()),
         try context.fetchCount(Round.completedDescriptor),
         try context.fetchCount(Round.inProgressDescriptor))
    }

    @Test(arguments: [
        (Fixture.freshInstall, 0, 0, 0), (.onePlayer, 1, 3, 0), (.twoPlayers, 2, 3, 0), (.noRound, 3, 0, 0),
        (.marquee, 7, 66, 1), (.twoPlayersMarquee, 2, 3, 0),
        (.inProgress, 3, 2, 1), (.twoInProgress, 3, 1, 2), (.outOfOrder, 3, 1, 1),
    ])
    func dataSetsHaveWhatTheirNamesSay(fixture: Fixture, players: Int, completed: Int, inProgress: Int) throws {
        let c = try counts(load(fixture))
        #expect(c.players == players && c.completed == completed && c.inProgress == inProgress)
    }

    @Test func fullHistoryCoversEveryCase() throws {
        let context = try load(.fullHistory)
        let players = try context.fetch(FetchDescriptor<Player>())
        let rounds = try context.fetch(FetchDescriptor<Round>())
        let completed = rounds.filter { $0.isComplete }
        #expect(players.count == 7)
        #expect(players.filter { ($0.entries ?? []).count >= 20 }.count == 6)
        #expect(Set(completed.map(\.holeCount)) == Set(HoleCount.allCases))
        #expect(Set(completed.map(\.tee)) == Set(Tee.allCases))
        #expect(Set(completed.compactMap(\.weather?.condition)) == Set(WeatherKind.allCases))
        #expect(completed.contains { $0.weather == nil })
        #expect(Set(rounds.map { ($0.entries ?? []).count }) == [1, 2, 3, 4])
        #expect(players.contains { $0.firstName == "José" }) // a diacritic
        #expect(players.contains { $0.hasManualHandicap } && players.contains { !$0.hasManualHandicap })
        for round in rounds { try round.validateInvariants() }
    }

    /// TS-UI-08 cases in fullHistory.
    @Test func fullHistoryHasTheSpecialCases() throws {
        let context = try load(.fullHistory)
        let rounds = try context.fetch(FetchDescriptor<Round>())
        // One older round still in progress.
        let playing = rounds.filter { $0.isInProgress }
        #expect(playing.count == 1)
        #expect(playing.first?.startedAt == ModelFixtures.daysAgo(40))
        // A tied round.
        #expect(rounds.contains { round in
            let totals = round.sortedEntries.map(\.grossTotal)
            return round.isComplete && totals.count > 1 && Set(totals).count == 1
        })
        // A player who mostly plays 9 holes.
        let nina = try #require(try context.fetch(FetchDescriptor<Player>()).first { $0.firstName == "Nina" })
        let holeCounts = (nina.entries ?? []).compactMap { $0.round?.holeCount }
        #expect(holeCounts.filter { $0 == .nine }.count == 4 && holeCounts.filter { $0 == .eighteen }.count == 1)
    }

    @Test func dataSetsAreTheSameEveryTime() throws {
        let first = try RoundSnapshotList(load(.fullHistory))
        let second = try RoundSnapshotList(load(.fullHistory))
        #expect(first.scores == second.scores)
    }

    @Test func inProgressRoundsResumeOnTheNextHole() throws {
        let rounds = try load(.twoInProgress).fetch(Round.inProgressDescriptor)
        #expect(Set(rounds.map(\.currentHole)) == [4, 12])
        #expect(Set(rounds.map(\.thru)) == [3, 11])
    }

    /// HP-OO (#192): the out-of-order round is on hole 6, with hole 3 missing the third card and hole 4 empty.
    @Test func outOfOrderHasMissedHoles() throws {
        let round = try #require(try load(.outOfOrder).fetch(Round.inProgressDescriptor).first)
        #expect(round.currentHole == 6)
        let cards = round.sortedEntries
        #expect(cards.map { $0.strokes(forHole: 3) != nil } == [true, true, false])
        #expect(cards.allSatisfy { $0.strokes(forHole: 4) == nil })
        #expect(cards.allSatisfy { card in [1, 2, 5].allSatisfy { card.strokes(forHole: $0) != nil } })
    }

    @Test func scoresAreParPlusZeroToTwo() {
        for seed in 0..<5 {
            for hole in 1...18 {
                let par = ModelFixtures.pars[(hole - 1) % 9]
                #expect((par...par + 2).contains(ModelFixtures.strokes(seed: seed, hole: hole)))
            }
        }
        #expect(ModelFixtures.pars.reduce(0, +) == 35)
        #expect(ModelFixtures.pars(for: .eighteen).count == 18)
    }

    @Test func everyFixtureHasACase() {
        #expect(Fixture.allCases.map(\.rawValue) ==
                ["freshInstall", "onePlayer", "twoPlayers", "noRound", "inProgress", "twoInProgress", "outOfOrder", "fullHistory", "marquee", "twoPlayersMarquee"])
    }
}

/// Scores of every round, newest first, for comparing two loads.
@MainActor
private struct RoundSnapshotList {
    let scores: [[[Int?]]]
    init(_ context: ModelContext) throws {
        scores = try context.fetch(FetchDescriptor<Round>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))
            .map { RoundSnapshot($0).entries.map(\.strokes) }
    }
}
