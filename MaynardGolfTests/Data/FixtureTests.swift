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
        (.inProgress, 3, 2, 1), (.twoInProgress, 3, 1, 2),
    ])
    func dataSetsHaveWhatTheirNamesSay(fixture: Fixture, players: Int, completed: Int, inProgress: Int) throws {
        let c = try counts(load(fixture))
        #expect(c.players == players && c.completed == completed && c.inProgress == inProgress)
    }

    @Test func fullHistoryCoversEveryCase() throws {
        let context = try load(.fullHistory)
        let players = try context.fetch(FetchDescriptor<Player>())
        let rounds = try context.fetch(FetchDescriptor<Round>())
        #expect(players.count == 6)
        #expect(players.allSatisfy { ($0.entries ?? []).count >= 20 })
        #expect(rounds.allSatisfy { $0.isComplete })
        #expect(Set(rounds.map(\.holeCount)) == Set(HoleCount.allCases))
        #expect(Set(rounds.map(\.tee)) == Set(Tee.allCases))
        #expect(Set(rounds.compactMap(\.weather?.condition)) == Set(WeatherKind.allCases))
        #expect(rounds.contains { $0.weather == nil })
        #expect(Set(rounds.map { ($0.entries ?? []).count }) == [1, 2, 3, 4])
        #expect(players.contains { $0.firstName == "José" }) // a diacritic
        #expect(players.contains { $0.hasManualHandicap } && players.contains { !$0.hasManualHandicap })
        for round in rounds { try round.validateInvariants() }
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
                ["freshInstall", "onePlayer", "twoPlayers", "noRound", "inProgress", "twoInProgress", "fullHistory"])
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
