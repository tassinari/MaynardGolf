//
//  PlayerCardTests.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
import Testing
@testable import MaynardGolf

// MARK: - Stats (PC-ST, PC-DT-02)

/// 09-player-card §4: Avg and Best per hole count, the default filter and the index's VoiceOver label.
@MainActor
struct PlayerCardStatsTests {
    private let context: ModelContext
    private let me = UUID()

    init() throws { context = try makeInMemoryContext() }

    private func score(_ gross: Int, _ holeCount: HoleCount, daysAgo: Int = 0) -> PlayerRoundScore {
        PlayerRoundScore(id: UUID(), date: ModelFixtures.daysAgo(daysAgo), holeCount: holeCount, gross: gross)
    }

    /// Completed rounds this player is in, newest first, with their gross; rounds in progress and other
    /// players' rounds are left out.
    @Test func scoresAreCompletedRoundsNewestFirst() throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let ann = ModelFixtures.player("Ann", in: context)
        let old = try ModelFixtures.completedRound(players: [mark, ann], holeCount: .nine, startedAt: ModelFixtures.daysAgo(10), in: context)
        let new = try ModelFixtures.completedRound(players: [ann, mark], holeCount: .eighteen, startedAt: ModelFixtures.daysAgo(1), in: context)
        let theirs = try ModelFixtures.completedRound(players: [ann], startedAt: ModelFixtures.daysAgo(2), in: context)
        let playing = try ModelFixtures.inProgressRound(players: [mark], thru: 3, startedAt: ModelFixtures.daysAgo(0), in: context)
        let scores = PlayerCardStats.scores(for: mark.id, in: [old, new, theirs, playing].map(RoundSnapshot.init))
        #expect(scores.map(\.id) == [new.id, old.id])
        #expect(scores.map(\.holeCount) == [.eighteen, .nine])
        #expect(scores[0].gross == new.sortedEntries[1].grossTotal)
        #expect(scores[1].gross == old.sortedEntries[0].grossTotal)
        #expect(scores[0].date == ModelFixtures.daysAgo(1))
    }

    /// Two rounds on the same date keep one order (by id), whatever order they came in.
    @Test func sameDateOrderIsStable() throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let a = RoundSnapshot(try ModelFixtures.completedRound(players: [mark], in: context))
        let b = RoundSnapshot(try ModelFixtures.completedRound(players: [mark], in: context))
        #expect(PlayerCardStats.scores(for: mark.id, in: [a, b]) == PlayerCardStats.scores(for: mark.id, in: [b, a]))
    }

    /// PC-ST-06: more 9s → 9, more 18s → 18, a tie or none → 18.
    @Test(arguments: [
        ([HoleCount](), HoleCount.eighteen),
        ([.nine], .nine),
        ([.eighteen], .eighteen),
        ([.nine, .eighteen], .eighteen),
        ([.nine, .nine, .eighteen], .nine),
        ([.nine, .eighteen, .eighteen], .eighteen),
    ])
    func defaultHoleCount(_ counts: [HoleCount], expected: HoleCount) {
        #expect(PlayerCardStats.defaultHoleCount(counts.map { score(40, $0) }) == expected)
    }

    /// PC-ST-02, 03, 07: Avg (one decimal) and Best of the selected count only; "—" with none.
    @Test func statsPerHoleCount() {
        let scores = [score(80, .eighteen), score(77, .eighteen), score(80, .eighteen), score(41, .nine), score(39, .nine)]
        let eighteen = PlayerCardStats.stats(scores, holeCount: .eighteen)
        #expect(eighteen.average == 79 && eighteen.best == 77)
        #expect(eighteen.averageText(locale: Locale(identifier: "en_US")) == "79.0" && eighteen.bestText == "77")
        let nine = PlayerCardStats.stats(scores, holeCount: .nine)
        #expect(nine.average == 40 && nine.best == 39)
        let none = PlayerCardStats.stats([score(41, .nine)], holeCount: .eighteen)
        #expect(none == PlayerScoreStats(average: nil, best: nil))
        #expect(none.averageText() == "—" && none.bestText == "—")
        #expect(PlayerCardStats.stats([], holeCount: .nine).best == nil)
        #expect(PlayerCardStats.gross(scores, holeCount: .nine) == [41, 39])
    }

    /// One round: Avg and Best are its score.
    @Test func oneRound() {
        let stats = PlayerCardStats.stats([score(83, .eighteen)], holeCount: .eighteen)
        #expect(stats.averageText(locale: Locale(identifier: "en_US")) == "83.0" && stats.bestText == "83")
    }

    /// PC-HDR-05: "Handicap index 8.4", plus "calculated" for a calculated value; none reads as no index.
    @Test func handicapLabel() {
        let en = Locale(identifier: "en_US")
        #expect(PlayerCardStats.handicapAccessibilityLabel(PlayerHandicap(index: 8.4, source: .manual, roundsUsed: 0), locale: en)
            == "Handicap index 8.4")
        #expect(PlayerCardStats.handicapAccessibilityLabel(PlayerHandicap(index: 8.4, source: .calculated, roundsUsed: 5), locale: en)
            == "Handicap index 8.4, calculated")
        #expect(PlayerCardStats.handicapAccessibilityLabel(PlayerHandicap(index: -2.1, source: .manual, roundsUsed: 0), locale: en)
            == "Handicap index +2.1")
        #expect(PlayerCardStats.handicapAccessibilityLabel(.none, locale: en) == "No handicap index")
    }
}

// MARK: - The view model (PC-DT-01, 04)

/// A store, repositories on it and a handicap manager over the same data.
@MainActor
struct PlayerCardStore {
    let context: ModelContext
    let players: SwiftDataPlayerRepository
    let rounds: SwiftDataRoundRepository
    let tracker: ModelChangeTracker

    init() throws {
        context = try makeInMemoryContext()
        tracker = ModelChangeTracker(context: context)
        let clock = FixedClock(now: ModelFixtures.referenceDate)
        players = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: clock)
        rounds = SwiftDataRoundRepository(context: context, tracker: tracker, clock: clock)
    }

    /// A manager reading this store's players and rounds, with the real calculator.
    func handicaps() throws -> HandicapManager {
        HandicapManager(source: PlayerCardStoreSource(context: context),
                        calculator: HandicapCalculator(course: try BundleCourseProvider().course(id: AppDependencies.courseID)),
                        clock: FixedClock(now: ModelFixtures.referenceDate), retryDelays: [])
    }

    func model(_ id: UUID, players: PlayerRepository? = nil, handicaps: HandicapManager? = nil) throws -> PlayerCardViewModel {
        PlayerCardViewModel(playerID: id, players: players ?? self.players, rounds: rounds, handicaps: try handicaps ?? self.handicaps())
    }
}

/// Snapshots read from a test's main context.
@MainActor
final class PlayerCardStoreSource: HandicapDataSource {
    let context: ModelContext
    init(context: ModelContext) { self.context = context }
    func handicapSnapshots() async throws -> (players: [PlayerSnapshot], rounds: [RoundSnapshot]) {
        (try context.fetch(FetchDescriptor<Player>()).map(PlayerSnapshot.init), try context.fetch(FetchDescriptor<Round>()).map(RoundSnapshot.init))
    }
}

/// A player repository whose reads fail on demand.
@MainActor
final class FlakyCardPlayers: PlayerRepository {
    let base: PlayerRepository
    var fail = false
    struct Failure: Error {}

    init(_ base: PlayerRepository) { self.base = base }
    func allPlayers() throws -> [Player] { if fail { throw Failure() }; return try base.allPlayers() }
    func recentPlayers(limit: Int?) throws -> [Player] { try base.recentPlayers(limit: limit) }
    func search(_ text: String) throws -> [Player] { try base.search(text) }
    func create(firstName: String, lastName: String, color: PlayerColor, photoData: Data?, manualIndex: Double?) throws -> Player {
        try base.create(firstName: firstName, lastName: lastName, color: color, photoData: photoData, manualIndex: manualIndex)
    }
    func update(_ player: Player, _ change: (Player) throws -> Void) throws { try base.update(player, change) }
    func delete(_ player: Player) throws { try base.delete(player) }
    func changes() -> AsyncStream<ModelChanges> { base.changes() }
}

@MainActor
struct PlayerCardViewModelTests {
    /// PC-HDR, PC-ST: the profile, the default filter, stats that follow the toggle, the index from the manager.
    @Test func profileStatsAndToggle() async throws {
        let store = try PlayerCardStore()
        let mark = ModelFixtures.player("Mark", "Tassinari", color: .flag, in: store.context)
        for day in 0..<3 { try ModelFixtures.completedRound(players: [mark], holeCount: .nine, startedAt: ModelFixtures.daysAgo(day + 1), seed: day, in: store.context) }
        try ModelFixtures.completedRound(players: [mark], holeCount: .eighteen, startedAt: ModelFixtures.daysAgo(9), in: store.context)
        try store.context.save()
        let handicaps = try store.handicaps()
        let model = try store.model(mark.id, handicaps: handicaps)
        model.load()
        #expect(model.profile == .init(firstName: "Mark", fullName: "Mark Tassinari", color: .flag, photoData: nil))
        #expect(model.avatar == nil) // no photo: the initial
        #expect(model.holeFilter == .nine) // more 9s (PC-ST-06)
        let nines = model.stats
        model.holeFilter = .eighteen
        #expect(model.stats != nines)
        #expect(model.stats.best == mark.entries?.first { $0.round?.holeCount == .eighteen }?.grossTotal)
        model.load() // a reload keeps the user's choice
        #expect(model.holeFilter == .eighteen)
        // The index comes from the manager: "—" until it has run, then calculated.
        #expect(model.handicapText == "—" && model.handicapAccessibilityLabel == "No handicap index")
        await handicaps.refresh()
        #expect(model.handicap.source == .calculated)
        #expect(model.handicapAccessibilityLabel.hasSuffix(", calculated"))
        #expect(model.handicapText == model.handicap.displayText())
    }

    /// PC-ST-06, 07: no rounds → 18 selected, "—" stats.
    @Test func noRounds() throws {
        let store = try PlayerCardStore()
        let ann = ModelFixtures.player("Ann", in: store.context)
        let model = try store.model(ann.id)
        model.load()
        #expect(model.holeFilter == .eighteen)
        #expect(model.stats.averageText() == "—" && model.stats.bestText == "—")
        #expect(model.profile?.fullName == "Ann")
    }

    /// A player who's gone closes the card; an unreadable store shows Try again and recovers.
    @Test func missingAndFailures() throws {
        let store = try PlayerCardStore()
        let missing = try store.model(UUID())
        missing.load()
        #expect(missing.isMissing && missing.profile == nil)

        let ann = ModelFixtures.player("Ann", in: store.context)
        let flaky = FlakyCardPlayers(store.players)
        let model = try store.model(ann.id, players: flaky)
        flaky.fail = true
        model.load()
        #expect(model.loadError == "This player couldn't be loaded." && model.profile == nil)
        flaky.fail = false
        model.load()
        #expect(model.loadError == nil && model.profile?.firstName == "Ann")
    }

    /// PC-DT-04: an edit saved elsewhere (the Edit form) shows through the change stream.
    @Test func followsChanges() async throws {
        let store = try PlayerCardStore()
        let ann = try store.players.create(firstName: "Ann", lastName: "", color: .moss, photoData: nil, manualIndex: nil)
        let model = try store.model(ann.id)
        let observing = Task { await model.observe() }
        let deadline = ContinuousClock.now + .seconds(2)
        while model.profile == nil, ContinuousClock.now < deadline { await Task.yield() }
        try store.players.update(ann) { try $0.rename(first: "Annie", last: "Lee") }
        let later = ContinuousClock.now + .seconds(2)
        while model.profile?.fullName != "Annie Lee", ContinuousClock.now < later { await Task.yield() }
        observing.cancel()
        #expect(model.profile?.fullName == "Annie Lee")
    }

    /// The app's dependencies build a working model.
    @Test func liveDependencies() throws {
        let dependencies = AppDependencies.preview(.onePlayer)
        let mark = try #require(try dependencies.players.allPlayers().first)
        let model = PlayerCardViewModel(playerID: mark.id, dependencies: dependencies)
        model.load()
        #expect(model.profile?.firstName == "Mark" && model.holeFilter == .nine)
    }
}

// MARK: - Navigation

/// PC-TOP-03, AP-ED-07: closing the card goes back to the screen it was opened from, once.
@MainActor
struct PlayerCardRouterTests {
    @Test func closeReturnsToThePreviousScreen() {
        let id = UUID()
        let router = Router(path: [.allPlayers, .playerCard(id), .roundDetail(UUID())])
        router.close(.playerCard(id))
        #expect(router.path == [.allPlayers])
        router.close(.playerCard(id)) // already closed: nothing more is popped
        #expect(router.path == [.allPlayers])
    }
}
