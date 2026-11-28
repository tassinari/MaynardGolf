//
//  PlayerCardTests.swift
//  MaynardGolfTests
//

import Foundation
import MaynardUI
import SwiftData
import Testing
import UIKit
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

    /// DM-RD-01: a synced duplicate of a round counts once, the oldest copy, as in the handicap.
    @Test func aDuplicateRoundCountsOnce() throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let original = try ModelFixtures.completedRound(players: [mark], startedAt: ModelFixtures.daysAgo(5), in: context)
        let copy = try ModelFixtures.completedRound(players: [mark], startedAt: ModelFixtures.daysAgo(3), in: context)
        copy.id = original.id
        let scores = PlayerCardStats.scores(for: mark.id, in: [copy, original].map(RoundSnapshot.init))
        #expect(scores.map(\.id) == [original.id])
        #expect(scores[0].date == ModelFixtures.daysAgo(5))
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
        #expect(PlayerCardStats.handicapAccessibilityLabel(PlayerHandicap(index: 8.4, source: .starting, roundsUsed: 0), locale: en)
            == "Handicap index 8.4")
        #expect(PlayerCardStats.handicapAccessibilityLabel(PlayerHandicap(index: 8.4, source: .calculated, roundsUsed: 5), locale: en)
            == "Handicap index 8.4, calculated")
        #expect(PlayerCardStats.handicapAccessibilityLabel(PlayerHandicap(index: -2.1, source: .starting, roundsUsed: 0), locale: en)
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
    let outsideScores: SwiftDataOutsideScoreRepository
    let tracker: ModelChangeTracker

    init() throws {
        context = try makeInMemoryContext()
        tracker = ModelChangeTracker(context: context)
        let clock = FixedClock(now: ModelFixtures.referenceDate)
        players = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: clock)
        rounds = SwiftDataRoundRepository(context: context, tracker: tracker, clock: clock)
        outsideScores = SwiftDataOutsideScoreRepository(context: context, tracker: tracker, clock: clock)
    }

    /// A manager reading this store's players and rounds, with the real calculator.
    func handicaps() throws -> HandicapManager {
        HandicapManager(source: PlayerCardStoreSource(context: context),
                        calculator: HandicapCalculator(course: try BundleCourseProvider().course(id: AppDependencies.courseID)),
                        clock: FixedClock(now: ModelFixtures.referenceDate), retryDelays: [])
    }

    func model(_ id: UUID, players: PlayerRepository? = nil, handicaps: HandicapManager? = nil,
               courses: CourseProvider = BundleCourseProvider()) throws -> PlayerCardViewModel {
        PlayerCardViewModel(playerID: id, players: players ?? self.players, rounds: rounds,
                            handicaps: try handicaps ?? self.handicaps(), courses: courses, clock: FixedClock(now: ModelFixtures.referenceDate),
                            calendar: Self.utc, locale: Locale(identifier: "en_US"))
    }

    /// A fixed calendar for the graph's dates.
    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
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
    func outsideScoreSnapshots() async throws -> [OutsideScoreSnapshot] {
        try context.fetch(FetchDescriptor<OutsideScore>()).map(OutsideScoreSnapshot.init)
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
    func create(firstName: String, lastName: String, color: PlayerColor, photoData: Data?, startingIndex: Double?) throws -> Player {
        try base.create(firstName: firstName, lastName: lastName, color: color, photoData: photoData, startingIndex: startingIndex)
    }
    func update(_ player: Player, _ change: (Player) throws -> Void) throws { try base.update(player, change) }
    func delete(_ player: Player) throws { try base.delete(player) }
    func setMarquee(_ id: UUID?) throws { try base.setMarquee(id) }
    func normalizeMarquee() throws { try base.normalizeMarquee() }
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
        model.toggleHoles() // Latest Scores' button (PC-ST-04)
        #expect(model.holeFilter == .eighteen)
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

    /// PC-HDR-02: the photo is decoded big enough for the 96 pt avatar at 3× (288 px, not a list's 192).
    @Test func thePhotoIsDecodedAtProfileSize() throws {
        let store = try PlayerCardStore()
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 1024), format: {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; return format
        }()).jpegData(withCompressionQuality: 0.8) { context in UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024)) }
        let ann = try store.players.create(firstName: "Ann", lastName: "", color: .moss, photoData: photo, startingIndex: nil)
        let model = try store.model(ann.id)
        model.load()
        let image = try #require(model.avatar)
        #expect(PlayerCardViewModel.avatarPixels == 288)
        #expect(AvatarSize.profile.rawValue == 96)
        #expect(min(image.size.width * image.scale, image.size.height * image.scale) == PlayerCardViewModel.avatarPixels)
        #expect(AvatarCache().pixels == AvatarCache.listPixels) // lists keep the default
        // Previous rounds' avatars decode at list size, separately from the profile's (DS-CN-04).
        let row = try #require(model.avatar(for: ann.id, photo: photo))
        #expect(min(row.size.width * row.scale, row.size.height * row.scale) == AvatarCache.listPixels)
        #expect(model.avatar(for: ann.id, photo: photo) === row) // cached
        #expect(model.avatar(for: ann.id, photo: nil) == nil)
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
        let ann = try store.players.create(firstName: "Ann", lastName: "", color: .moss, photoData: nil, startingIndex: nil)
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

// MARK: - Latest Scores (PC-LS, #251)

/// 09-player-card §5: the series, its limits, best and newest, gridlines, captions and the summary (100 %).
@MainActor
struct LatestScoresTests {
    private static let en = Locale(identifier: "en_US")
    private static let utc = PlayerCardStore.utc
    /// 2026-11-08 12:00 UTC.
    private static let nov8 = Date(timeIntervalSince1970: 1_794_139_200)

    /// `gross` newest last, a week apart, ending on Nov 8.
    private func scores(_ gross: [Int], _ holeCount: HoleCount = .eighteen) -> [PlayerRoundScore] {
        gross.enumerated().map { offset, value in
            PlayerRoundScore(id: UUID(), date: Self.nov8.addingTimeInterval(-Double((gross.count - 1 - offset) * 7) * 86_400),
                             holeCount: holeCount, gross: value)
        }
    }

    private func make(_ scores: [PlayerRoundScore], _ holeCount: HoleCount = .eighteen) -> LatestScores? {
        LatestScores.make(scores, holeCount: holeCount, locale: Self.en, calendar: Self.utc)
    }

    /// PC-LS-02, 07: 0 and 1 rounds show the hint; from 2 the newest 10 at most, oldest first.
    @Test(arguments: [(0, 0), (1, 0), (2, 2), (3, 3), (10, 10), (25, 10)])
    func plotsTheNewestTen(rounds: Int, plotted: Int) {
        let gross = (0..<rounds).map { 70 + $0 % 13 }
        let series = make(scores(gross))
        #expect((series?.points.count ?? 0) == plotted)
        if let series {
            #expect(series.points.map(\.gross) == Array(gross.suffix(10)))
            #expect(series.points.map(\.index) == Array(0..<plotted))
            #expect(series.newestIndex == plotted - 1)
        }
    }

    /// PC-LS-02, PC-ST-05: only the selected hole count, ordered by date, a same-day pair by id.
    @Test func onlyTheSelectedHoleCountByDate() throws {
        let day = Self.nov8
        let id1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let rounds = [PlayerRoundScore(id: id2, date: day, holeCount: .eighteen, gross: 80),
                      PlayerRoundScore(id: UUID(), date: day.addingTimeInterval(-86_400), holeCount: .eighteen, gross: 82),
                      PlayerRoundScore(id: id1, date: day, holeCount: .eighteen, gross: 78),
                      PlayerRoundScore(id: UUID(), date: day, holeCount: .nine, gross: 40)]
        let eighteen = try #require(make(rounds))
        #expect(eighteen.points.map(\.gross) == [82, 78, 80]) // same instant: id 1 before id 2
        #expect(make(rounds, .nine) == nil) // one nine: the hint
    }

    /// PC-LS-05: the best is the lowest, the newest of a tie; the newest gets its own label unless it's the best.
    @Test func bestAndNewest() throws {
        let tie = try #require(make(scores([80, 76, 79, 76, 81])))
        #expect(tie.bestIndex == 3 && tie.best.gross == 76 && tie.newest.gross == 81 && tie.labelsNewest)
        let newestBest = try #require(make(scores([84, 81, 79, 76])))
        #expect(newestBest.bestIndex == 3 && !newestBest.labelsNewest)
    }

    /// PC-LS-03, 04: the average to one decimal; three whole-number gridlines covering every score, distinct
    /// even when every score is equal; the domain leaves room under the bottom line.
    @Test(arguments: [
        ([82, 79, 83, 76, 80, 78, 81, 74, 79, 77], [74, 79, 84], 78.9),
        ([74, 82, 78], [74, 78, 82], 78.0),
        ([80, 80, 80], [79, 80, 81], 80.0),
        ([80, 81], [79, 80, 81], 80.5),
        ([36, 50, 44, 41], [36, 43, 50], 42.8),
        ([104, 117, 99, 112], [99, 108, 117], 108.0),
    ])
    func gridlinesAndAverage(gross: [Int], gridlines: [Int], average: Double) throws {
        let series = try #require(make(scores(gross)))
        #expect(series.gridlines == gridlines && series.average == average)
        #expect(gross.allSatisfy { Double($0) >= series.domain.lowerBound && Double($0) <= series.domain.upperBound })
        #expect(series.domain.lowerBound < Double(gridlines[0]) && series.domain.upperBound > Double(gridlines[2]))
        #expect(series.xDomain == -0.3...(Double(gross.count - 1) + 0.3))
    }

    /// PC-LS-06: first, middle and newest dates; 2 rounds have no middle. A round's day reads in the injected calendar.
    @Test func captions() throws {
        let ten = try #require(make(scores(Array(repeating: 80, count: 10))))
        #expect(ten.captions.map(\.index) == [0, 5, 9])
        #expect(ten.captions.map(\.text) == ["Sep 6", "Oct 11", "Nov 8"])
        let two = try #require(make(scores([80, 81])))
        #expect(two.captions.map(\.text) == ["Nov 1", "Nov 8"])

        var hawaii = Calendar(identifier: .gregorian)
        hawaii.timeZone = TimeZone(identifier: "Pacific/Honolulu")!
        let midnightUTC = Date(timeIntervalSince1970: 1_794_096_000) // Nov 8 00:00 UTC: Nov 7 in Hawaii
        let rounds = [PlayerRoundScore(id: UUID(), date: midnightUTC, holeCount: .eighteen, gross: 80),
                      PlayerRoundScore(id: UUID(), date: midnightUTC.addingTimeInterval(86_400), holeCount: .eighteen, gross: 81)]
        let local = try #require(LatestScores.make(rounds, holeCount: .eighteen, locale: Self.en, calendar: hawaii))
        #expect(local.points.map(\.day) == ["Nov 7", "Nov 8"])
    }

    /// PC-LS-08: the summary names the count, hole count, first, newest and best.
    @Test func accessibilitySummary() throws {
        let series = try #require(make(scores([82, 79, 83, 76, 80, 78, 81, 74, 79, 77])))
        #expect(series.accessibilitySummary
            == "Line graph of the last 10 18-hole scores, from 82 on Sep 6 to 77 on Nov 8, best 74 on Oct 25")
        let nine = try #require(make(scores([44, 41], .nine), .nine))
        #expect(nine.accessibilitySummary == "Line graph of the last 2 9-hole scores, from 44 on Nov 1 to 41 on Nov 8, best 41 on Nov 8")
    }
}

/// PC-ST-04, 05, PC-DT-04: the 9 / 18 button switches the graph, outside scores stay out of it, and it follows the store.
@MainActor
struct PlayerCardLatestScoresTests {
    @Test func theToggleSwitchesTheGraph() throws {
        let store = try PlayerCardStore()
        let mark = ModelFixtures.player("Mark", in: store.context)
        for day in 0..<4 { try ModelFixtures.completedRound(players: [mark], holeCount: .nine, startedAt: ModelFixtures.daysAgo(day + 1), seed: day, in: store.context) }
        try ModelFixtures.completedRound(players: [mark], holeCount: .eighteen, startedAt: ModelFixtures.daysAgo(20), in: store.context)
        let model = try store.model(mark.id)
        model.load()
        #expect(model.holeFilter == .nine)
        #expect(model.latestScores?.points.count == 4 && model.latestScores?.holeCount == .nine)
        model.toggleHoles()
        #expect(model.holeFilter == .eighteen)
        #expect(model.latestScores == nil) // one 18: the hint
        model.toggleHoles() // and back
        #expect(model.holeFilter == .nine && model.latestScores?.points.count == 4)
    }

    /// PC-ST-04: the button's title is the action, the other hole count.
    @Test(arguments: [(HoleCount.eighteen, "Show 9 holes"), (.nine, "Show 18 holes")])
    func holesButtonTitle(showing holeCount: HoleCount, title: String) {
        #expect(PlayerCardViewModel.holesButtonTitle(showing: holeCount) == title)
    }

    /// #285: outside scores from the Handicap screen never join the graph, nor Avg and Best (PC-LS-02, PC-ST-02, 03).
    @Test func outsideScoresStayOutOfTheGraph() throws {
        let store = try PlayerCardStore()
        let mark = ModelFixtures.player("Mark", in: store.context)
        try ModelFixtures.completedRound(players: [mark], holeCount: .eighteen, startedAt: ModelFixtures.daysAgo(20), in: store.context)
        let model = try store.model(mark.id)
        model.load()
        model.holeFilter = .eighteen
        let maynardStats = model.stats
        #expect(model.latestScores == nil)
        let course = try store.outsideScores.addCourse(name: "Cedar Ridge", courseRating: 71.2, slope: 128)
        try store.outsideScores.addScore(for: mark, course: course, gross: 60, holeCount: .eighteen, playedOn: ModelFixtures.daysAgo(2))
        model.load()
        #expect(model.latestScores == nil) // still one Maynard 18: the hint
        #expect(model.stats == maynardStats)
        try ModelFixtures.completedRound(players: [mark], holeCount: .eighteen, startedAt: ModelFixtures.daysAgo(10), seed: 1, in: store.context)
        model.load()
        let series = try #require(model.latestScores)
        #expect(series.points.count == 2 && !series.points.map(\.gross).contains(60))
    }
}

// MARK: - Scores by Hole (PC-SH, #270)

/// PC-SH-02…07: holes 1–9 from both round lengths, the bins and their relation to par, the averages, the scaling and
/// the accessibility text. Pure: snapshots and pars in.
@MainActor
struct ScoresByHoleTests {
    /// Maynard's pars, as `MaynardGC.json` has them: 4 5 3 4 4 3 4 4 4.
    private static let pars = [4, 5, 3, 4, 4, 3, 4, 4, 4]
    private static let en = Locale(identifier: "en_US")
    private let context: ModelContext
    private let mark: Player

    init() throws {
        context = try makeInMemoryContext()
        mark = ModelFixtures.player("Mark", in: context)
    }

    private func round(_ strokes: [Int], players: [Player]? = nil, day: Int = 1) throws -> Round {
        let players = players ?? [mark]
        return try ModelFixtures.round(players: players, holeCount: strokes.count == 18 ? .eighteen : .nine,
                                       startedAt: ModelFixtures.daysAgo(day), scores: players.map { _ in strokes }, in: context)
    }

    private func make(_ rounds: [Round]) -> ScoresByHole? {
        ScoresByHole.make(for: mark.id, rounds: rounds.map(RoundSnapshot.init), pars: Self.pars, locale: Self.en)
    }

    /// PC-SH-07: no completed round, or only one in progress, trashed or someone else's: no card.
    @Test func noCompletedRoundsMakeNoCard() throws {
        #expect(make([]) == nil)
        let ann = ModelFixtures.player("Ann", in: context)
        let theirs = try ModelFixtures.round(players: [ann], scores: [[4, 5, 3, 4, 4, 3, 4, 4, 4]], in: context)
        let playing = try ModelFixtures.inProgressRound(players: [mark], thru: 4, in: context)
        let trashed = try round([4, 5, 3, 4, 4, 3, 4, 4, 4])
        trashed.deletedAt = ModelFixtures.referenceDate
        #expect(make([theirs, playing, trashed]) == nil)
        #expect(ScoresByHole.make(for: mark.id, rounds: [RoundSnapshot(try round([4, 4, 4, 4, 4, 4, 4, 4, 4]))], pars: []) == nil)
    }

    /// PC-SH-02, 04: one nine on the course's pars: every hole has its par, its one score as the average, a single full bar
    /// coloured by the score against par.
    @Test func oneNine() throws {
        let card = try #require(make([try round([4, 6, 2, 4, 5, 3, 4, 3, 4])]))
        #expect(card.holes.map(\.number) == Array(1...9))
        #expect(card.holes.map(\.id) == Array(1...9)) // the grid's identity
        #expect(card.holes.map(\.par) == Self.pars)
        #expect(card.holes.map(\.average) == [4, 6, 2, 4, 5, 3, 4, 3, 4])
        let two = card.holes[1] // a 6 on the par 5
        #expect(two.bins.map(\.count) == [0, 0, 0, 0, 1, 0] && two.bins[4].fraction == 1 && two.bins[4].toPar == .bogey)
        #expect(card.holes[2].bins[0].toPar == .under && card.holes[2].bins[0].count == 1) // a 2 on the par 3
        #expect(card.holes[0].bins[2].toPar == .par)
    }

    /// PC-SH-03: holes 10–18 replay 1–9, so an 18 counts twice on each hole; 9s and 18s mix.
    @Test func eighteensFoldOntoTheNine() throws {
        let eighteen = try round([4, 5, 3, 4, 4, 3, 4, 4, 4, 5, 6, 4, 5, 5, 4, 5, 5, 5], day: 2)
        let nine = try round([6, 5, 3, 4, 4, 3, 4, 4, 4], day: 1)
        let card = try #require(make([eighteen, nine]))
        let one = card.holes[0] // 4, 5 and 6
        #expect(one.bins.map(\.count) == [0, 0, 1, 1, 1, 0])
        #expect(one.average == 5.0 && one.averageText == "5.0")
        #expect(card.holes[1].average == 5.3) // 5, 6, 5 → 5.33
    }

    /// PC-SH-03: the first bin takes aces (and 2s), the last everything from 7; each bin's colour is its score against
    /// the hole's par (par 3, 4 and 5).
    @Test func binsAndTheirRelationToPar() throws {
        let card = try #require(make([try round([4, 5, 1, 4, 9, 3, 4, 4, 4]), try round([4, 5, 2, 4, 7, 3, 4, 4, 4])]))
        #expect(card.holes[2].bins[0].count == 2) // an ace and a 2 on the par 3
        #expect(card.holes[4].bins[5].count == 2 && card.holes[4].bins[5].label == "+") // a 9 and a 7
        #expect(card.holes[0].bins.map(\.label) == ["2", "3", "4", "5", "6", "+"])
        #expect(card.holes[2].bins.map(\.toPar) == [.under, .par, .bogey, .doublePlus, .doublePlus, .doublePlus]) // par 3
        #expect(card.holes[0].bins.map(\.toPar) == [.under, .under, .par, .bogey, .doublePlus, .doublePlus]) // par 4
        #expect(card.holes[1].bins.map(\.toPar) == [.under, .under, .under, .par, .bogey, .doublePlus]) // par 5
        #expect([-1, 0, 1, 2, 6, 7, 8, 30].map(ScoresByHole.binIndex) == [0, 0, 0, 0, 4, 5, 5, 5])
    }

    /// PC-SH-03: the tallest bar of each hole fills the plot and the others are scaled to it; empty bins draw nothing.
    @Test func barsScaleToTheHolesTallest() throws {
        let rounds = try [4, 4, 4, 4, 5, 5, 3].enumerated().map { day, first in try round([first, 5, 3, 4, 4, 3, 4, 4, 4], day: day + 1) }
        let one = try #require(make(rounds)).holes[0]
        #expect(one.bins.map(\.count) == [0, 1, 4, 2, 0, 0])
        #expect(one.bins.map(\.fraction) == [0, 0.25, 1, 0.5, 0, 0])
        #expect(one.average == 4.1) // (4 × 4 + 2 × 5 + 3) / 7 = 4.14
    }

    /// A synced duplicate round counts once (DM-RD-01).
    @Test func aDuplicateRoundCountsOnce() throws {
        let full = RoundSnapshot(try round([3, 5, 3, 4, 4, 3, 4, 4, 4]))
        let card = try #require(ScoresByHole.make(for: mark.id, rounds: [full, full], pars: Self.pars, locale: Self.en))
        #expect(card.holes[0].bins.map(\.count) == [0, 1, 0, 0, 0, 0])
    }

    /// PC-SH-06: one element per hole with its par, average and every score made.
    @Test func accessibilityText() throws {
        let card = try #require(make([try round([4, 5, 1, 4, 8, 3, 4, 4, 4]), try round([4, 5, 3, 4, 8, 3, 4, 4, 4], day: 2),
                                      try round([5, 5, 3, 4, 4, 3, 4, 4, 4], day: 3)]))
        #expect(card.holes[0].accessibilityLabel == "Hole 1, par 4, average 4.3: 2 scores of 4 and 1 score of 5")
        #expect(card.holes[2].accessibilityLabel == "Hole 3, par 3, average 2.3: 1 score of 2 or less and 2 scores of 3")
        #expect(card.holes[4].accessibilityLabel == "Hole 5, par 4, average 6.7: 1 score of 4 and 2 scores of 7 or more")
    }

    /// A hole with no scores (a course hole no round reached) reads "—", with no bars.
    @Test func aHoleWithNoScores() throws {
        let card = try #require(ScoresByHole.make(for: mark.id, rounds: [RoundSnapshot(try round([4, 5, 3, 4, 4, 3, 4, 4, 4]))],
                                                  pars: Self.pars + [4], locale: Self.en))
        let ten = card.holes[9]
        #expect(ten.average == nil && ten.averageText == "—" && ten.bins.allSatisfy { $0.fraction == 0 && $0.count == 0 })
        #expect(ten.accessibilityLabel == "Hole 10, par 4, average —")
    }
}

/// PC-SH-01, 07, PC-ST-05: the view model builds the card on load, without a toggle dependency, and drops it with no
/// completed round.
@MainActor
struct PlayerCardScoresByHoleTests {
    @Test func builtOnLoadAndNotFilteredByTheToggle() throws {
        let store = try PlayerCardStore()
        let mark = ModelFixtures.player("Mark", in: store.context)
        let model = try store.model(mark.id)
        model.load()
        #expect(model.scoresByHole == nil) // no rounds: no card
        try ModelFixtures.completedRound(players: [mark], holeCount: .nine, startedAt: ModelFixtures.daysAgo(3), in: store.context)
        try ModelFixtures.completedRound(players: [mark], holeCount: .eighteen, startedAt: ModelFixtures.daysAgo(2), in: store.context)
        model.load()
        let card = try #require(model.scoresByHole)
        #expect(card.holes.map(\.par) == [4, 5, 3, 4, 4, 3, 4, 4, 4]) // the course data's pars
        #expect(card.holes[0].bins.map(\.count).reduce(0, +) == 3) // one 9 and an 18 (twice)
        model.holeFilter = model.holeFilter == .nine ? .eighteen : .nine
        #expect(model.scoresByHole == card)
    }
}

// MARK: - Handicap trend (PC-HC, #72)

/// 09-player-card §6: the span (days, months, 2 years), gridlines, labels, summary and when the hint shows (100 %).
struct HandicapTrendTests {
    private let en = Locale(identifier: "en_US")
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    /// 2026-11-20 12:00 UTC.
    private var now: Date { utc.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 12))! }

    private func point(_ date: Date, _ index: Double) -> PlayerSummaryCard.HandicapPoint { .init(date: date, index: index) }
    private func ago(_ value: Int, _ component: Calendar.Component) -> Date { utc.date(byAdding: component, value: -value, to: now)! }
    private func make(_ history: [PlayerSummaryCard.HandicapPoint]) -> HandicapTrend? {
        HandicapTrend.make(history, now: now, locale: en, calendar: utc)
    }

    /// PC-HC-02: three whole-number gridlines covering the series, at least 1 apart.
    @Test(arguments: [
        (8.4, 11.2, [8.0, 10, 12]),
        (8.4, 8.4, [8.0, 9, 10]),
        (-3.1, -2.1, [-4.0, -3, -2]),
        (5.0, 15.0, [5.0, 10, 15]),
        (5.0, 14.0, [5.0, 10, 15]),
    ])
    func gridlines(low: Double, high: Double, expected: [Double]) {
        #expect(HandicapTrend.gridlines(low: low, high: high) == expected)
    }

    /// Gridline labels: whole numbers, "+" below zero.
    @Test func gridlineLabels() {
        #expect(HandicapTrend.gridlineLabel(12, locale: en) == "12")
        #expect(HandicapTrend.gridlineLabel(0, locale: en) == "0")
        #expect(HandicapTrend.gridlineLabel(-2, locale: en) == "+2")
    }

    /// PC-HC-06: no calculated index (or only a future one) → nil, the hint.
    @Test func noHistoryIsTheHint() {
        #expect(make([]) == nil)
        #expect(make([point(now.addingTimeInterval(60), 9.0)]) == nil)
    }

    /// PC-HC-02: a history under 2 months old plots its days, carried to now; labels "Nov 1", the summary by day.
    @Test func startingOutPlotsDays() throws {
        let trend = try #require(make([point(ago(10, .day), 13.6), point(ago(19, .day), 14.2)])) // unsorted in
        #expect(trend.scale == .days)
        #expect(trend.points == [point(ago(19, .day), 14.2), point(ago(10, .day), 13.6), point(now, 13.6)])
        #expect(trend.labels == ["Nov 1", "Nov 10", "Nov 20"])
        #expect(trend.accessibilitySummary == "Handicap index fell from 14.2 on November 1 to 13.6 now")
        #expect(trend.lastLabel(locale: en) == "13.6")
        #expect(trend.xDomain == ago(19, .day)...now)
        // A point already at now isn't repeated; two points get two labels.
        let two = try #require(make([point(ago(3, .day), 12.0), point(now, 12.9)]))
        #expect(two.points.count == 2 && two.labels == ["Nov 17", "Nov 20"])
        #expect(two.accessibilitySummary == "Handicap index rose from 12.0 on November 17 to 12.9 now")
    }

    /// The first index today: one point, one label, at the trailing edge of a day-wide X range (PC-HC-05).
    @Test func aLonePoint() throws {
        let trend = try #require(make([point(now, 11.4)]))
        #expect(trend.points.count == 1 && trend.labels == ["Nov 20"])
        #expect(trend.accessibilitySummary == "Handicap index started at 11.4 on November 20")
        #expect(trend.xDomain == now.addingTimeInterval(-86_400)...now)
        #expect(trend.gridlines == [11, 12, 13])
    }

    /// PC-HC-02: older than 2 months → month ends from the first point's month, each the last value by then.
    @Test func moreHistoryPlotsMonths() throws {
        let history = [point(ago(5, .month), 14.0), point(ago(3, .month), 12.0), point(ago(5, .day), 11.0)]
        let trend = try #require(make(history))
        #expect(trend.scale == .months)
        #expect(trend.points.map(\.index) == [14.0, 14.0, 12.0, 12.0, 12.0, 11.0]) // Jun…Oct ends, then now
        #expect(trend.points.last?.date == now)
        #expect(trend.labels == ["Jun", "Sep", "Nov"])
        #expect(trend.accessibilitySummary == "Handicap index fell from 14.0 in June 2026 to 11.0 now")
        let flat = try #require(make([point(ago(4, .month), 9.0)]))
        #expect(flat.accessibilitySummary == "Handicap index has stayed at 9.0 since July 2026")
    }

    /// PC-HC-02: capped at 2 years, with years on the labels; the value carried in from before the window counts.
    @Test func capsAtTwoYears() throws {
        let trend = try #require(make([point(ago(30, .month), 15.0), point(ago(13, .month), 10.0)]))
        #expect(trend.scale == .months)
        #expect(trend.points.count == HandicapTrend.maxMonths + 1)
        #expect(trend.points.first?.index == 15.0 && trend.points.last?.index == 10.0)
        #expect(trend.labels == ["Nov 24", "Nov 25", "Nov 26"])
    }

    /// Month ends: each month's last second from the start's month; the current month ends now.
    @Test func monthEnds() {
        let ends = HandicapTrend.monthEnds(from: ago(2, .month), to: now, calendar: utc)
        #expect(ends.count == 3 && ends.last == now)
        #expect(ends.first == utc.date(from: DateComponents(year: 2026, month: 10, day: 1))!.addingTimeInterval(-1))
        #expect(HandicapTrend.monthEnds(from: now, to: now, calendar: utc) == [now])
    }

    /// Never built empty, but the ranges and summary stay valid.
    @Test func emptyValuesStayValid() {
        let empty = HandicapTrend(scale: .days, points: [], labels: [], accessibilitySummary: "", gridlines: [])
        #expect(empty.domain == 0...1)
        #expect(empty.xDomain.upperBound == .distantPast)
        #expect(HandicapTrend.summary([], scale: .days) == "")
    }
}

/// PC-HC-04: the trend comes from the manager's calculated history, even with a manual index, and ignores
/// the toggle; it's rebuilt only when the manager recalculates.
@MainActor
struct PlayerCardTrendTests {
    @Test func theTrendIsTheCalculatedSeries() async throws {
        let store = try PlayerCardStore()
        let mark = ModelFixtures.player("Mark", startingIndex: 30.0, in: store.context)
        for month in 1...5 {
            for day in [3, 10, 17] {
                let date = Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
                try ModelFixtures.completedRound(players: [mark], holeCount: .eighteen, startedAt: date, seed: month * 31 + day, in: store.context)
            }
        }
        try store.context.save()
        let handicaps = try store.handicaps()
        let model = try store.model(mark.id, handicaps: handicaps)
        model.load()
        #expect(model.handicapTrend == nil) // the manager hasn't run yet
        await handicaps.refresh()
        let trend = try #require(model.handicapTrend)
        #expect(trend == HandicapTrend.make(handicaps.history(for: mark.id, months: HandicapTrend.maxMonths), now: ModelFixtures.referenceDate,
                                             locale: Locale(identifier: "en_US"), calendar: PlayerCardStore.utc))
        #expect(trend.scale == .months) // first index in January, months before the reference date
        #expect(trend.points.allSatisfy { $0.index != 30.0 }) // calculated, not the starting index
        #expect(model.handicap.source == .calculated && model.handicapText != "30.0") // 15 rounds: the seed is replaced (#268)
        model.holeFilter = .nine
        #expect(model.handicapTrend == trend) // the toggle doesn't touch it
        // Deleting the older rounds recalculates: a new revision rebuilds a shorter series.
        for round in try store.rounds.rounds(for: mark).filter({ Calendar.current.component(.month, from: $0.startedAt) < 4 }) {
            try store.rounds.delete(round)
        }
        await handicaps.refresh()
        #expect(model.handicapTrend != trend) // rebuilt from the shorter history
    }
}

// MARK: - Previous rounds (PC-PR, #73)

/// DS-CN-04: a summary's round-row chips, with avatar photos asked for only where the row draws avatars.
@MainActor
struct RoundRowScoresTests {
    private func summary(_ count: Int) -> RoundSummary {
        let colors: [PlayerColor] = [.lake, .sand, .flag, .fairway]
        let players = (0..<count).map {
            RoundSummary.PlayerScore(id: UUID(), playerID: UUID(), firstName: "P\($0)", color: colors[$0],
                                     photoData: Data([UInt8($0)]), gross: 70 + $0, toPar: $0 - 2)
        }
        return RoundSummary(id: UUID(), startedAt: .now, holeCount: .eighteen, tee: .blue, isComplete: true, currentHole: nil,
                            players: players, teeName: "Blue", meta: "18 holes · Blue")
    }

    @Test(arguments: [(1, true), (2, true), (3, false), (4, false)])
    func photosOnlyForAvatarRows(count: Int, asksForPhotos: Bool) {
        let round = summary(count)
        let photo = UIImage()
        var asked: [UUID] = []
        let scores = round.rowScores { id, data in
            #expect(data == round.players.first { $0.playerID == id }?.photoData)
            asked.append(id)
            return photo
        }
        #expect(scores.map(\.id) == round.players.map(\.playerID))
        #expect(scores.map(\.name) == round.players.map(\.firstName))
        #expect(scores.map(\.score) == round.players.map(\.gross))
        #expect(scores.map(\.color) == round.players.map(\.color.palette))
        #expect(asked == (asksForPhotos ? round.players.map(\.playerID) : []))
        #expect(scores.allSatisfy { ($0.photo != nil) == asksForPhotos })
    }
}

/// HOME-AR-04, PC-PR-01, 02, 07: month sections and the this-year count (100 %).
@MainActor
struct RoundMonthGroupingTests {
    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func summary(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> RoundSummary {
        RoundSummary(id: UUID(), startedAt: utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!,
                     holeCount: .nine, tee: .blue, isComplete: true, currentHole: nil, players: [], teeName: "Blue", meta: "9 holes · Blue")
    }

    /// Newest month first, newest round first in each, whatever the input order; titles in caps.
    @Test func groupsByMonthNewestFirst() {
        let oct = summary(2026, 10, 3), novEarly = summary(2026, 11, 2), novLate = summary(2026, 11, 20), lastYear = summary(2025, 11, 30)
        let sections = RoundMonthGrouping.sections([novEarly, lastYear, oct, novLate], calendar: utc, locale: Locale(identifier: "en_US"))
        #expect(sections.map(\.title) == ["NOVEMBER 2026", "OCTOBER 2026", "NOVEMBER 2025"])
        #expect(sections.map(\.id) == [202611, 202610, 202511])
        #expect(sections[0].rounds == [novLate, novEarly])
        #expect(sections[1].rounds == [oct] && sections[2].rounds == [lastYear])
        #expect(RoundMonthGrouping.sections([], calendar: utc).isEmpty)
    }

    /// Two rounds starting at the same moment keep one order.
    @Test func sameStartIsStable() {
        let a = summary(2026, 5, 1), b = RoundSummary(id: UUID(), startedAt: a.startedAt, holeCount: .nine, tee: .blue, isComplete: true,
                                                      currentHole: nil, players: [], teeName: "Blue", meta: "")
        #expect(RoundMonthGrouping.sections([a, b], calendar: utc) == RoundMonthGrouping.sections([b, a], calendar: utc))
    }

    /// PC-PR-01: rounds in the current calendar year only.
    @Test func countThisYear() {
        let now = utc.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let rounds = [summary(2026, 1, 1, hour: 0), summary(2026, 5, 31), summary(2025, 12, 31, hour: 23)]
        #expect(RoundMonthGrouping.countThisYear(rounds, now: now, calendar: utc) == 2)
        #expect(RoundMonthGrouping.countThisYear([], now: now, calendar: utc) == 0)
    }
}

/// PC-PR-01…10: the view model's Previous rounds.
@MainActor
struct PlayerCardRoundsTests {
    /// Completed rounds this player is in, by month, newest first, with a chip for every player in the round;
    /// rounds in progress and other players' rounds are left out; the toggle doesn't filter them.
    @Test func previousRounds() throws {
        let store = try PlayerCardStore()
        let mark = ModelFixtures.player("Mark", in: store.context)
        let ann = ModelFixtures.player("Ann", in: store.context)
        let together = try ModelFixtures.completedRound(players: [ann, mark], holeCount: .eighteen, tee: .blue,
                                                        startedAt: ModelFixtures.daysAgo(3), in: store.context)
        let alone = try ModelFixtures.completedRound(players: [mark], startedAt: ModelFixtures.daysAgo(40), in: store.context)
        let lastYear = try ModelFixtures.completedRound(players: [mark], startedAt: ModelFixtures.daysAgo(200), in: store.context)
        try ModelFixtures.completedRound(players: [ann], startedAt: ModelFixtures.daysAgo(1), in: store.context) // not Mark's
        try ModelFixtures.inProgressRound(players: [mark], thru: 2, startedAt: ModelFixtures.daysAgo(0), in: store.context) // PC-PR-06
        try store.context.save()
        let model = try store.model(mark.id)
        model.load()
        let rounds = model.roundSections.flatMap(\.rounds)
        #expect(rounds.map(\.id) == [together.id, alone.id, lastYear.id])
        #expect(model.roundSections.count == 3)
        #expect(rounds[0].players.map(\.firstName) == ["Ann", "Mark"]) // every player, in round order (PC-PR-03)
        #expect(rounds[0].meta == "18 holes · Blue")
        #expect(model.roundsThisYear == 2 && model.roundsThisYearText == "2 this year") // the clock is 1 June 2026
        #expect(model.courseName == "Maynard Golf Club" && !model.hasNoRounds)
        model.holeFilter = .nine
        #expect(model.roundSections.flatMap(\.rounds).count == 3) // PC-PR-07
    }

    /// PC-PR-10: no completed rounds → the empty text.
    @Test func noRounds() throws {
        let store = try PlayerCardStore()
        let mark = ModelFixtures.player("Mark", in: store.context)
        try ModelFixtures.inProgressRound(players: [mark], thru: 2, in: store.context)
        let model = try store.model(mark.id)
        model.load()
        #expect(model.hasNoRounds && model.roundsThisYear == 0 && model.roundsThisYearText == "0 this year")
    }

    /// No course data: the card says it couldn't load, with Try again.
    @Test func noCourse() throws {
        let store = try PlayerCardStore()
        let mark = ModelFixtures.player("Mark", in: store.context)
        let model = try store.model(mark.id, courses: MissingCourses())
        model.load()
        #expect(model.loadError == "This player couldn't be loaded.")
    }
}

/// A course provider with no courses.
private struct MissingCourses: CourseProvider {
    struct Missing: Error {}
    func course(id: String) throws -> Course { throw Missing() }
}
