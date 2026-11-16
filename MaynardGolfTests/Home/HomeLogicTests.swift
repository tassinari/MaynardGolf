//
//  HomeLogicTests.swift
//  MaynardGolfTests
//

import Foundation
import MaynardUI
import SwiftData
import Testing
@testable import MaynardGolf

/// A store with players and rounds made by the test, and repositories on it.
@MainActor
private struct Store {
    let context: ModelContext
    let players: SwiftDataPlayerRepository
    let rounds: SwiftDataRoundRepository

    init() throws {
        context = try makeInMemoryContext()
        let tracker = ModelChangeTracker(context: context)
        let clock = FixedClock(now: TestDates.teeOff)
        players = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: clock)
        rounds = SwiftDataRoundRepository(context: context, tracker: tracker, clock: clock)
    }

    func add(_ names: [String]) -> [Player] {
        names.enumerated().map { ModelFixtures.player($0.element, color: PlayerColor.allCases[$0.offset % 5], in: context) }
    }
}

/// A handicap source with nothing in it (the view model's handicap reads are tested through the manager).
private struct EmptySource: HandicapDataSource {
    func handicapSnapshots() async throws -> (players: [PlayerSnapshot], rounds: [RoundSnapshot]) { ([], []) }
}

private let course = try! BundleCourseProvider().course(id: "MaynardGC")

// MARK: - RoundSummaryBuilder

/// HOME-VM-05, HOME-IPR-02, HOME-RR-03: round summaries (100 %).
@MainActor
struct RoundSummaryBuilderTests {
    @Test(arguments: [1, 2, 3, 4], [HoleCount.nine, .eighteen])
    func everyPlayersGrossAndToPar(count: Int, holeCount: HoleCount) throws {
        let store = try Store()
        let players = store.add(Array(["Mark", "Scottie", "Tiger", "Phil"].prefix(count)))
        let round = try ModelFixtures.completedRound(players: players, holeCount: holeCount, tee: .blue, in: store.context)
        let summary = RoundSummaryBuilder.summary(of: RoundSnapshot(round), players: players.map(PlayerSnapshot.init), course: course)
        let pars = ModelFixtures.pars(for: holeCount)
        #expect(summary.players.map(\.firstName) == Array(["Mark", "Scottie", "Tiger", "Phil"].prefix(count)))
        for (entry, score) in zip(round.sortedEntries, summary.players) {
            #expect(score.gross == entry.grossTotal)
            #expect(score.toPar == entry.grossTotal - pars.reduce(0, +))
        }
        #expect(summary.meta == "\(holeCount.rawValue) holes · Blue")
        #expect(summary.isComplete)
        #expect(summary.currentHole == nil)
        #expect(summary.holeProgress == nil)
    }

    /// HOME-IPR-02: the current hole is the first one not every player has scored.
    @Test func inProgressShowsTheHoleBeingPlayed() throws {
        let store = try Store()
        let players = store.add(["Mark", "Phil"])
        let round = try ModelFixtures.inProgressRound(players: players, thru: 2, holeCount: .nine, in: store.context)
        try round.sortedEntries[0].setStrokes(4, forHole: 3) // Mark is ahead; Phil hasn't scored hole 3
        let summary = RoundSummaryBuilder.summary(of: RoundSnapshot(round), players: players.map(PlayerSnapshot.init), course: course)
        #expect(summary.currentHole == 3)
        #expect(summary.holeProgress == "Hole 3 of 9")
        #expect(!summary.isComplete)
        #expect(summary.players[0].gross == round.sortedEntries[0].grossTotal)
    }

    @Test func currentHoleEdgeCases() {
        #expect(RoundSummaryBuilder.currentHole([[4, nil, nil]], holeCount: .nine) == 2)
        #expect(RoundSummaryBuilder.currentHole([[nil]], holeCount: .nine) == 1)
        #expect(RoundSummaryBuilder.currentHole([[4, 5], [4]], holeCount: .nine) == 2) // a short card counts as unplayed
        #expect(RoundSummaryBuilder.currentHole([Array(repeating: 4, count: 9)], holeCount: .nine) == 9)
        #expect(RoundSummaryBuilder.currentHole([], holeCount: .eighteen) == 1) // no cards
    }

    /// A card whose player is missing is left out; an unknown tee falls back to its raw name.
    @Test func missingPlayersAndTees() throws {
        let store = try Store()
        let players = store.add(["Mark", "Phil"])
        let round = try ModelFixtures.completedRound(players: players, tee: .red, in: store.context)
        let summary = RoundSummaryBuilder.summary(of: RoundSnapshot(round), players: [PlayerSnapshot(players[1])], course: course)
        #expect(summary.players.map(\.firstName) == ["Phil"])
        let mark = PlayerSnapshot(players[0])
        #expect(RoundSummaryBuilder.summary(of: RoundSnapshot(round), players: [mark, mark], course: course).players.count == 1)
        let noTees = Course(id: course.id, name: course.name, coordinate: course.coordinate, tees: [], holes: course.holes,
                            localRules: course.localRules)
        #expect(RoundSummaryBuilder.summary(of: RoundSnapshot(round), players: [], course: noTees).meta == "9 holes · Red")
    }
}

// MARK: - PlayerSummaryBuilder

/// HOME-PC-02, 03, 06…09, HOME-PLY-03: summary-card values and Home's player order (100 %).
@MainActor
struct PlayerSummaryBuilderTests {
    private func day(_ n: Int) -> Date { ModelFixtures.referenceDate.addingTimeInterval(Double(n) * 86_400) }

    @Test func noRoundsYet() throws {
        let store = try Store()
        let mark = try store.players.create(firstName: "Mark", lastName: "Tassinari", color: .moss, photoData: nil, manualIndex: nil)
        let stats = PlayerSummaryBuilder.stats(for: PlayerSnapshot(mark), rounds: [])
        #expect(stats.fullName == "Mark Tassinari")
        #expect(stats.lastPlayed == nil && stats.average == nil && stats.best == nil && stats.lastRound == nil)
        #expect(stats.mainHoleCount == .eighteen) // none → 18
        #expect(PlayerSummaryBuilder.text(stats.average) == "—")
        #expect(PlayerSummaryBuilder.text(stats.best) == "—")
    }

    /// Avg and Best use the hole count with more completed rounds; Last round is the newest, any count;
    /// rounds in progress and other players' rounds don't count.
    @Test func statsByTheMainHoleCount() throws {
        let store = try Store()
        let players = store.add(["Mark", "Phil"])
        let mark = players[0]
        let rounds = try [
            ModelFixtures.round(players: [mark], holeCount: .nine, startedAt: day(1), scores: [[4, 5, 3, 4, 4, 3, 4, 4, 4]], in: store.context), // 35
            ModelFixtures.round(players: [mark], holeCount: .nine, startedAt: day(2), scores: [[5, 5, 3, 4, 4, 3, 4, 4, 4]], in: store.context), // 36
            ModelFixtures.round(players: [mark], holeCount: .eighteen, startedAt: day(3), scores: [Array(repeating: 4, count: 18)], in: store.context), // 72
            ModelFixtures.inProgressRound(players: [mark], thru: 3, startedAt: day(4), in: store.context),
            ModelFixtures.round(players: [players[1]], startedAt: day(5), in: store.context),
        ].map(RoundSnapshot.init)
        let stats = PlayerSummaryBuilder.stats(for: PlayerSnapshot(mark), rounds: rounds)
        #expect(stats.mainHoleCount == .nine)
        #expect(stats.average == 35.5)
        #expect(stats.best == 35)
        #expect(stats.lastRound == 72)
        #expect(stats.lastPlayed == day(3))
        #expect(PlayerSummaryBuilder.text(stats.average, locale: Locale(identifier: "en_US")) == "35.5")
        #expect(PlayerSummaryBuilder.text(stats.best) == "35")
    }

    @Test func aTieUsesEighteen() throws {
        let store = try Store()
        let mark = store.add(["Mark"])[0]
        let rounds = try [
            ModelFixtures.round(players: [mark], holeCount: .nine, startedAt: day(1), in: store.context),
            ModelFixtures.round(players: [mark], holeCount: .eighteen, startedAt: day(2), in: store.context),
        ].map(RoundSnapshot.init)
        #expect(PlayerSummaryBuilder.stats(for: PlayerSnapshot(mark), rounds: rounds).mainHoleCount == .eighteen)
    }

    /// HOME-PC-06…08: the chart needs 2 points; the range and the first / middle / last months.
    @Test func chart() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let en = Locale(identifier: "en_US")
        func point(_ month: Int, _ index: Double) -> PlayerSummaryCard.HandicapPoint {
            PlayerSummaryCard.HandicapPoint(date: utc.date(from: DateComponents(year: 2026, month: month, day: 15))!, index: index)
        }
        #expect(PlayerSummaryBuilder.chart([], locale: en, calendar: utc) == nil)
        #expect(PlayerSummaryBuilder.chart([point(1, 11.2)], locale: en, calendar: utc) == nil)
        let chart = try #require(PlayerSummaryBuilder.chart([point(1, 11.2), point(2, 10.1), point(3, 9), point(4, -0.4)],
                                                            locale: en, calendar: utc))
        #expect(chart.range == "11.2 → +0.4")
        #expect(chart.monthLabels == ["Jan", "Mar", "Apr"])
        #expect(chart.points.count == 4)
        let moved = try #require(PlayerSummaryBuilder.chart([point(1, 11.2), point(2, 10.1), point(3, 9.5), point(4, -0.4)],
                                                            locale: en, calendar: utc))
        #expect(chart != moved) // same range and months, a different point
    }

    /// HOME-PLY-03: by the last round of any kind (newest first), then the rest A–Z by first name, then
    /// full name, ignoring case and accents.
    @Test func homeOrder() throws {
        let store = try Store()
        var lastRound: [UUID: Date] = [:]
        func player(_ first: String, _ last: String = "", played: Int?) throws -> PlayerSnapshot {
            let model = try store.players.create(firstName: first, lastName: last, color: .lake, photoData: nil, manualIndex: nil)
            if let played { lastRound[model.id] = day(played) }
            return PlayerSnapshot(model)
        }
        let players = try [
            player("zed", played: nil), player("Ánne", played: nil), player("Bob", played: 2), player("Cy", played: 5),
            player("Al", "b", played: 3), player("Al", "A", played: 3), player("bea", played: nil), player("Al", "Z", played: nil),
            player("al", "a", played: nil),
        ]
        let ordered = PlayerSummaryBuilder.homeOrder(players, lastRound: lastRound)
        #expect(ordered.map(\.fullName) == ["Cy", "Al A", "Al b", "Bob", "al a", "Al Z", "Ánne", "bea", "zed"])
    }

    /// A round still in progress counts for the order (like `recentPlayers`), not for "Last played".
    @Test func aRoundInProgressCountsForTheOrderOnly() throws {
        let store = try Store()
        let players = store.add(["Bob", "Al"])
        try ModelFixtures.inProgressRound(players: [players[0]], thru: 2, in: store.context)
        let home = HomeViewModel(players: store.players, rounds: store.rounds, settings: .inMemory(),
                                 handicaps: HandicapManager(source: EmptySource(), calculator: nil, clock: FixedClock(now: TestDates.teeOff)),
                                 courses: BundleCourseProvider())
        home.refresh()
        guard case .two(let first, _) = home.playersLayout else { Issue.record("expected two"); return }
        #expect(first.firstName == "Bob")
        #expect(first.lastPlayed == nil) // no completed round yet: "No rounds yet"
    }
}

// MARK: - HomeViewModel

/// HOME-VM-01…04, HOME-RR-02, HOME-IPR-07: states, layouts, recent rounds, errors and live refresh.
@MainActor
struct HomeViewModelTests {
    private func model(_ store: Store, players: PlayerRepository? = nil, rounds: RoundRepository? = nil,
                       settings: SettingsStore = .inMemory()) -> HomeViewModel {
        HomeViewModel(players: players ?? store.players, rounds: rounds ?? store.rounds, settings: settings,
                      handicaps: HandicapManager(source: EmptySource(), calculator: HandicapCalculator(course: course),
                                                 clock: FixedClock(now: TestDates.teeOff)),
                      courses: BundleCourseProvider())
    }

    private func layoutCount(_ layout: HomeViewModel.PlayersLayout) -> Int {
        switch layout {
        case .empty: 0
        case .one: 1
        case .two: 2
        case .list(let rows): rows.count
        }
    }

    @Test func startsLoading() throws {
        #expect(model(try Store()).roundState == .loading)
    }

    @Test func freshInstall() throws {
        let home = model(try Store())
        home.refresh()
        #expect(home.roundState == .freshInstall)
        #expect(home.playersLayout == .empty)
        #expect(home.recentRounds.isEmpty)
        #expect(home.courseName == "Maynard Golf Club")
    }

    /// The players layout follows the player count only (01-home §1): 1, 2, 3 and 8 players.
    @Test(arguments: [(1, 1), (2, 2), (3, 3), (8, 4)])
    func playersLayout(count: Int, shown: Int) throws {
        let store = try Store()
        _ = store.add((0..<count).map { "Player\($0)" })
        let home = model(store)
        home.refresh()
        #expect(home.roundState == .noRound)
        #expect(layoutCount(home.playersLayout) == shown)
        switch (count, home.playersLayout) {
        case (1, .one), (2, .two), (3, .list), (8, .list): break
        default: Issue.record("unexpected layout \(home.playersLayout) for \(count)")
        }
    }

    /// HOME-IPR-07, HOME-RR-02: rounds in progress get a card each (newest first) and Recent rounds shows
    /// 3; without one, a list of players shows 4.
    @Test func inProgressAndRecentRounds() throws {
        let store = try Store()
        let players = store.add(["Mark", "Phil", "Tiger"])
        for day in 1...6 {
            try ModelFixtures.completedRound(players: players, startedAt: ModelFixtures.referenceDate.addingTimeInterval(Double(day) * 86_400),
                                             in: store.context)
        }
        let home = model(store)
        home.refresh()
        #expect(home.roundState == .noRound)
        #expect(home.recentRounds.count == 4)
        #expect(home.recentRounds.map(\.startedAt) == home.recentRounds.map(\.startedAt).sorted(by: >))

        let older = try ModelFixtures.inProgressRound(players: [players[0]], thru: 1, startedAt: ModelFixtures.referenceDate.addingTimeInterval(10 * 86_400),
                                                     in: store.context)
        let newer = try ModelFixtures.inProgressRound(players: [players[1]], thru: 1, startedAt: ModelFixtures.referenceDate.addingTimeInterval(11 * 86_400),
                                                     in: store.context)
        home.refresh()
        guard case .inProgress(let cards) = home.roundState else { Issue.record("expected in progress"); return }
        #expect(cards.map(\.id) == [newer.id, older.id])
        #expect(home.recentRounds.count == 3)
    }

    /// Summary cards (one or two players) also get 3 recent rounds.
    @Test func summaryCardsGetThreeRecentRounds() throws {
        let store = try Store()
        let players = store.add(["Mark", "Phil"])
        for day in 1...5 {
            try ModelFixtures.completedRound(players: players, startedAt: ModelFixtures.referenceDate.addingTimeInterval(Double(day) * 86_400),
                                             in: store.context)
        }
        let home = model(store)
        home.refresh()
        #expect(home.recentRounds.count == 3)
        guard case .two(let first, _) = home.playersLayout else { Issue.record("expected two"); return }
        #expect(first.lastPlayed != nil)
    }

    /// DM-PL-01: two player records sharing an id (a CloudKit duplicate not yet merged) don't crash
    /// Home; the first one shows.
    @Test func duplicatePlayerIdsDontCrash() throws {
        let store = try Store()
        let id = UUID()
        let first = Player(id: id, firstName: "Mark", color: .lake, createdAt: TestDates.teeOff)
        let copy = Player(id: id, firstName: "Mark", color: .lake, createdAt: TestDates.teeOff)
        store.context.insert(first)
        store.context.insert(copy)
        try ModelFixtures.completedRound(players: [first], in: store.context)
        try ModelFixtures.completedRound(players: [copy], startedAt: TestDates.minutes(600), in: store.context)
        let home = model(store)
        home.refresh()
        guard case .one(let only) = home.playersLayout else { Issue.record("expected one card, got \(home.playersLayout)"); return }
        #expect(only.id == id)
        #expect(home.errorMessage == nil)
    }

    /// HOME-VM-04: a failed read keeps what's shown and sets the banner; retrying clears it.
    @Test func errorsShowABannerAndRetry() throws {
        let store = try Store()
        _ = store.add(["Mark"])
        let failing = FlakyPlayers(store.players)
        let home = model(store, players: failing)
        home.refresh()
        #expect(home.errorMessage == nil)
        failing.fails = true
        home.refresh()
        #expect(home.errorMessage == "Your rounds couldn't be loaded.")
        #expect(home.roundState == .noRound) // what was shown stays
        failing.fails = false
        home.refresh()
        #expect(home.errorMessage == nil)
    }

    @Test func passThroughs() throws {
        let store = try Store()
        let mark = store.add(["Mark"])[0]
        let settings = SettingsStore.inMemory([.showToPar: false])
        let home = model(store, settings: settings)
        #expect(!home.showToPar)
        #expect(home.handicap(for: mark.id) == .none)
        #expect(home.chart(for: mark.id) == nil)
        let live = HomeViewModel(dependencies: AppDependencies.preview(.freshInstall))
        live.refresh()
        #expect(live.roundState == .freshInstall)
    }

    /// HOME-VM-02: every change from the store's stream refreshes Home.
    @Test func changesRefresh() async throws {
        let store = try Store()
        let counting = FlakyPlayers(store.players)
        let home = model(store, players: counting, rounds: OneChangeRounds(store.rounds))
        _ = store.add(["Mark"])
        await home.observe() // the rounds stream yields one change, then ends
        #expect(home.roundState == .noRound)
        #expect(counting.reads == 2) // once on start, once for the change
    }
}

/// The store's rounds, with a change stream that yields one change and ends.
@MainActor
private final class OneChangeRounds: RoundRepository {
    private let base: RoundRepository
    init(_ base: RoundRepository) { self.base = base }
    func inProgress() throws -> [Round] { try base.inProgress() }
    func recentCompleted(limit: Int?) throws -> [Round] { try base.recentCompleted(limit: limit) }
    func rounds(for player: Player) throws -> [Round] { try base.rounds(for: player) }
    func allRounds(offset: Int, limit: Int) throws -> [Round] { try base.allRounds(offset: offset, limit: limit) }
    func create(players: [Player], holeCount: HoleCount, tee: Tee, weather: WeatherSnapshot?) throws -> Round {
        try base.create(players: players, holeCount: holeCount, tee: tee, weather: weather)
    }
    func saveScore(_ strokes: Int, hole: Int, for entry: RoundEntry) throws { try base.saveScore(strokes, hole: hole, for: entry) }
    func setCurrentHole(_ hole: Int, for round: Round) throws { try base.setCurrentHole(hole, for: round) }
    func delete(_ round: Round) throws { try base.delete(round) }
    func changes() -> AsyncStream<ModelChanges> {
        AsyncStream { continuation in
            continuation.yield(ModelChanges())
            continuation.finish()
        }
    }
}

/// Players that can be made to fail.
@MainActor
private final class FlakyPlayers: PlayerRepository {
    struct Failure: Error {}
    private let base: PlayerRepository
    var fails = false
    private(set) var reads = 0

    init(_ base: PlayerRepository) { self.base = base }

    func allPlayers() throws -> [Player] {
        reads += 1
        if fails { throw Failure() }
        return try base.allPlayers()
    }

    func recentPlayers(limit: Int?) throws -> [Player] { try base.recentPlayers(limit: limit) }
    func search(_ text: String) throws -> [Player] { try base.search(text) }
    func create(firstName: String, lastName: String, color: PlayerColor, photoData: Data?, manualIndex: Double?) throws -> Player {
        try base.create(firstName: firstName, lastName: lastName, color: color, photoData: photoData, manualIndex: manualIndex)
    }
    func update(_ player: Player, _ change: (Player) throws -> Void) throws { try base.update(player, change) }
    func delete(_ player: Player) throws { try base.delete(player) }
    func changes() -> AsyncStream<ModelChanges> { base.changes() }
}
