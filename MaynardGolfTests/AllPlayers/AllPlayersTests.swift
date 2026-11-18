//
//  AllPlayersTests.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
import Testing
@testable import MaynardGolf

/// 11-all-players: filtering, sorting, the count, the round counts and delete (AL-DT-01, #80).
@MainActor
struct AllPlayersTests {
    private typealias F = ModelFixtures
    private let context: ModelContext
    private let players: SwiftDataPlayerRepository
    private let rounds: SwiftDataRoundRepository

    init() throws {
        context = try makeInMemoryContext()
        let tracker = ModelChangeTracker(context: context)
        players = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: FixedClock(now: TestDates.teeOff))
        rounds = SwiftDataRoundRepository(context: context, tracker: tracker, clock: FixedClock(now: TestDates.teeOff))
    }

    private func model() -> AllPlayersViewModel {
        let model = AllPlayersViewModel(players: players, rounds: rounds, handicaps: HandicapManager(source: NoHandicapSource(), calculator: nil, clock: FixedClock(now: TestDates.teeOff)))
        model.load()
        return model
    }

    private func row(_ first: String, _ last: String = "", rounds: Int = 0) -> AllPlayersViewModel.Row {
        AllPlayersViewModel.Row(id: UUID(), firstName: first, lastName: last, color: .lake, photoData: nil, roundCount: rounds)
    }

    // MARK: Pure rules

    /// AL-SR-02, AL-LS-04: live, case- and diacritic-insensitive on first, last and full name; A–Z by first
    /// then last name; an empty or blank query keeps everyone.
    @Test func filterAndSort() {
        let rows = [row("Tiger", "Woods"), row("José", "María"), row("Mark", "Zed"), row("Mark", "Adams"), row("Scottie", "Scheffler")]
        #expect(AllPlayersViewModel.filter(rows, query: "").map(\.fullName) == ["José María", "Mark Adams", "Mark Zed", "Scottie Scheffler", "Tiger Woods"])
        #expect(AllPlayersViewModel.filter(rows, query: "  ").count == 5)
        #expect(AllPlayersViewModel.filter(rows, query: "sc").map(\.firstName) == ["Scottie"])
        #expect(AllPlayersViewModel.filter(rows, query: "JOSE").map(\.firstName) == ["José"]) // case and diacritics
        #expect(AllPlayersViewModel.filter(rows, query: "maria").map(\.firstName) == ["José"]) // last name
        #expect(AllPlayersViewModel.filter(rows, query: "mark a").map(\.lastName) == ["Adams"]) // full name
        #expect(AllPlayersViewModel.filter(rows, query: "zzz").isEmpty)
    }

    /// AL-SR-03: "8 PLAYERS", or "1 OF 8 PLAYERS" while searching; singular for one.
    @Test func countLabel() {
        #expect(AllPlayersViewModel.countLabel(shown: 8, total: 8, isFiltering: false) == "8 PLAYERS")
        #expect(AllPlayersViewModel.countLabel(shown: 1, total: 1, isFiltering: false) == "1 PLAYER")
        #expect(AllPlayersViewModel.countLabel(shown: 1, total: 8, isFiltering: true) == "1 OF 8 PLAYERS")
    }

    /// A row's full name falls back to the first name.
    @Test func fullName() {
        #expect(row("Chris").fullName == "Chris")
        #expect(row(" Mark ", " Tassinari ").fullName == "Mark Tassinari")
    }

    // MARK: The model

    /// AL-LS-02, AL-SR-03, 04: rows with round counts, the count while searching, and no results.
    @Test func loadAndSearch() throws {
        let mark = F.player("Mark", "Tassinari", in: context)
        F.player("Scottie", "Scheffler", in: context)
        try F.completedRound(players: [mark], in: context)
        try F.completedRound(players: [mark], in: context)
        let model = model()
        #expect(model.rows.map(\.firstName) == ["Mark", "Scottie"])
        #expect(model.rows.map(model.subtitle) == ["2 rounds", "0 rounds"])
        #expect(model.countLabel == "2 PLAYERS")
        #expect(!model.hasNoPlayers && !model.isEmptyResult)
        #expect(model.handicap(model.rows[0]) == .none && model.avatar(model.rows[0]) == nil)
        model.query = "sc"
        #expect(model.rows.map(\.firstName) == ["Scottie"])
        #expect(model.countLabel == "1 OF 2 PLAYERS")
        model.query = " zzz "
        #expect(model.isEmptyResult)
        #expect(model.noResultsMessage == "No players match “zzz”")
    }

    /// AL-DT-02: no players at all shows the empty state.
    @Test func noPlayers() {
        let model = model()
        #expect(model.hasNoPlayers && model.rows.isEmpty && model.countLabel == "0 PLAYERS")
    }

    /// AL-LS-06: delete asks first, naming the rounds that go too; confirming removes the player.
    @Test func delete() throws {
        let mark = F.player("Mark", in: context)
        F.player("Ann", in: context)
        try F.completedRound(players: [mark], in: context)
        let model = model()
        let markRow = try #require(model.rows.first { $0.firstName == "Mark" })
        model.requestDelete(markRow)
        #expect(model.deleteRequest == .confirm(id: markRow.id, title: "Delete Mark?", message: "Their 1 round will also be removed.")) // plural variation
        model.deleteRequest = nil // the alert's dismissal may clear this first; the id still deletes
        model.confirmDelete(id: markRow.id)
        #expect(model.deleteRequest == nil)
        #expect(model.rows.map(\.firstName) == ["Ann"])
        model.requestDelete(model.rows[0])
        #expect(model.deleteRequest == .confirm(id: model.rows[0].id, title: "Delete Ann?", message: nil)) // no rounds, no message
        model.confirmDelete(id: model.rows[0].id)
        #expect(model.hasNoPlayers)
    }

    /// AL-LS-06: a player in a round in progress can't be deleted, and says why.
    @Test func deleteBlockedDuringARound() throws {
        let mark = F.player("Mark", in: context)
        try F.inProgressRound(players: [mark], thru: 2, in: context)
        let model = model()
        model.requestDelete(model.rows[0])
        #expect(model.deleteRequest == .blocked(title: "Delete Mark?", reason: "Finish or delete their round in progress first."))
        #expect(model.rows.count == 1) // a blocked delete offers no Delete button
        #expect(AllPlayersViewModel.DeleteRequest.blocked(title: "t", reason: "r").id == "blocked.t")
        #expect(AllPlayersViewModel.DeleteRequest.confirm(id: mark.id, title: "t", message: nil).id == "confirm.\(mark.id)")
    }

    /// Failures: unreadable players show Try again; unreadable rounds block a delete; a failed delete alerts.
    @Test func failures() throws {
        F.player("Mark", in: context)
        let failing = FailingRepositories(players: players, rounds: rounds)
        let model = AllPlayersViewModel(players: failing, rounds: failing, handicaps: HandicapManager(source: NoHandicapSource(), calculator: nil, clock: FixedClock(now: TestDates.teeOff)))
        failing.failReads = true
        model.load()
        #expect(model.loadError == "The players couldn't be loaded." && !model.hasNoPlayers)
        failing.failReads = false
        model.load()
        #expect(model.loadError == nil && model.rows.count == 1)
        failing.failInProgress = true
        model.requestDelete(model.rows[0])
        #expect(model.deleteRequest == .blocked(title: "Delete Mark?", reason: "Their rounds couldn't be read, so they can't be deleted right now."))
        failing.failInProgress = false
        failing.failDelete = true
        model.requestDelete(model.rows[0])
        model.confirmDelete(id: model.rows[0].id)
        #expect(model.deleteError == "The player couldn't be deleted. Try again.")
    }

    /// The live dependencies and the change stream.
    @Test func dependenciesAndChanges() async {
        let dependencies = AppDependencies.preview(.twoPlayers)
        let model = AllPlayersViewModel(dependencies: dependencies)
        let observing = Task { await model.observe() }
        let deadline = ContinuousClock.now + .seconds(2)
        while model.rows.count != 2, ContinuousClock.now < deadline { await Task.yield() }
        // A player added elsewhere (Add player, AL-NAV-03) shows through the change stream.
        try? dependencies.players.create(firstName: "Ann", lastName: "", color: .moss, photoData: nil, manualIndex: nil)
        let later = ContinuousClock.now + .seconds(2)
        while model.rows.count != 3, ContinuousClock.now < later { await Task.yield() }
        observing.cancel()
        #expect(model.rows.map(\.firstName) == ["Ann", "Mark", "Scottie"])
    }

    /// A player deleted elsewhere between the swipe and the confirmation: nothing to delete.
    @Test func confirmAfterThePlayerIsGone() throws {
        let mark = F.player("Mark", in: context)
        let model = model()
        let id = model.rows[0].id
        model.requestDelete(model.rows[0])
        try players.delete(mark)
        model.confirmDelete(id: id)
        #expect(model.deleteError == nil)
    }
}

/// A handicap source with nobody, for tests that don't look at indexes.
private struct NoHandicapSource: HandicapDataSource {
    func handicapSnapshots() async throws -> (players: [PlayerSnapshot], rounds: [RoundSnapshot]) { ([], []) }
}

/// Repositories that fail on demand around the real ones.
@MainActor
private final class FailingRepositories: PlayerRepository, RoundRepository {
    let players: PlayerRepository
    let rounds: RoundRepository
    var failReads = false
    var failInProgress = false
    var failDelete = false
    struct Failure: Error {}

    init(players: PlayerRepository, rounds: RoundRepository) {
        self.players = players
        self.rounds = rounds
    }

    func allPlayers() throws -> [Player] { if failReads { throw Failure() }; return try players.allPlayers() }
    func recentPlayers(limit: Int?) throws -> [Player] { try players.recentPlayers(limit: limit) }
    func search(_ text: String) throws -> [Player] { try players.search(text) }
    func create(firstName: String, lastName: String, color: PlayerColor, photoData: Data?, manualIndex: Double?) throws -> Player {
        try players.create(firstName: firstName, lastName: lastName, color: color, photoData: photoData, manualIndex: manualIndex)
    }
    func update(_ player: Player, _ change: (Player) throws -> Void) throws { try players.update(player, change) }
    func delete(_ player: Player) throws { if failDelete { throw Failure() }; try players.delete(player) }
    func inProgress() throws -> [Round] { if failInProgress { throw Failure() }; return try rounds.inProgress() }
    func recentCompleted(limit: Int?) throws -> [Round] { try rounds.recentCompleted(limit: limit) }
    func rounds(for player: Player) throws -> [Round] { try rounds.rounds(for: player) }
    func allRounds(offset: Int, limit: Int) throws -> [Round] { try rounds.allRounds(offset: offset, limit: limit) }
    func round(id: UUID) throws -> Round? { try rounds.round(id: id) }
    func create(players: [Player], holeCount: HoleCount, tee: Tee, weather: WeatherSnapshot?) throws -> Round {
        try rounds.create(players: players, holeCount: holeCount, tee: tee, weather: weather)
    }
    func saveScore(_ strokes: Int, hole: Int, for entry: RoundEntry) throws { try rounds.saveScore(strokes, hole: hole, for: entry) }
    func setCurrentHole(_ hole: Int, for round: Round) throws { try rounds.setCurrentHole(hole, for: round) }
    func delete(_ round: Round) throws { try rounds.delete(round) }
    func changes() -> AsyncStream<ModelChanges> { players.changes() }
}
