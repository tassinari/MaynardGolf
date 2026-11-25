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
        PlayerCardViewModel(playerID: id, players: players ?? self.players, rounds: rounds, outsideScores: outsideScores,
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
    func create(firstName: String, lastName: String, color: PlayerColor, photoData: Data?, manualIndex: Double?) throws -> Player {
        try base.create(firstName: firstName, lastName: lastName, color: color, photoData: photoData, manualIndex: manualIndex)
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

    /// PC-HDR-02: the photo is decoded big enough for the 72 pt avatar at 3× (216 px, not a list's 192).
    @Test func thePhotoIsDecodedAtProfileSize() throws {
        let store = try PlayerCardStore()
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 1024), format: {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; return format
        }()).jpegData(withCompressionQuality: 0.8) { context in UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024)) }
        let ann = try store.players.create(firstName: "Ann", lastName: "", color: .moss, photoData: photo, manualIndex: nil)
        let model = try store.model(ann.id)
        model.load()
        let image = try #require(model.avatar)
        #expect(PlayerCardViewModel.avatarPixels == 216)
        #expect(min(image.size.width * image.scale, image.size.height * image.scale) == PlayerCardViewModel.avatarPixels)
        #expect(AvatarCache().pixels == AvatarCache.listPixels) // lists keep the default
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

// MARK: - Latest Scores (PC-LS, #251)

/// 09-player-card §5: the series, its limits, best and newest, gridlines, captions and the summary (100 %).
@MainActor
struct LatestScoresTests {
    private static let en = Locale(identifier: "en_US")
    private static let utc = PlayerCardStore.utc
    /// 2026-11-08 12:00 UTC.
    private static let nov8 = Date(timeIntervalSince1970: 1_794_139_200)

    /// `gross` newest last, a week apart, ending on Nov 8; `outside` marks outside scores by position.
    private func scores(_ gross: [Int], _ holeCount: HoleCount = .eighteen, outside: Set<Int> = []) -> [LatestScores.Score] {
        gross.enumerated().map { offset, value in
            LatestScores.Score(id: UUID(), date: Self.nov8.addingTimeInterval(-Double((gross.count - 1 - offset) * 7) * 86_400),
                               holeCount: holeCount, gross: value, isOutside: outside.contains(offset))
        }
    }

    private func make(_ scores: [LatestScores.Score], _ holeCount: HoleCount = .eighteen) -> LatestScores? {
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

    /// PC-LS-02, PC-ST-05: only the selected hole count; Maynard rounds and outside scores merged by date, a
    /// same-day pair by id.
    @Test func mergesBothSourcesForOneHoleCount() throws {
        let day = Self.nov8
        let id1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let rounds = [PlayerRoundScore(id: id2, date: day, holeCount: .eighteen, gross: 80),
                      PlayerRoundScore(id: UUID(), date: day.addingTimeInterval(-86_400), holeCount: .eighteen, gross: 82),
                      PlayerRoundScore(id: UUID(), date: day, holeCount: .nine, gross: 40)]
        let context = try makeInMemoryContext()
        let mark = ModelFixtures.player("Mark", in: context)
        let course = ModelFixtures.outsideCourse("Cedar Ridge", rating: 71.2, slope: 128, in: context)
        let outside = ModelFixtures.outsideScore(78, for: mark, at: course, playedOn: day, in: context)
        outside.id = id1
        outside.playedOn = day
        let merged = LatestScores.scores(rounds: rounds, outside: [OutsideScoreSnapshot(outside)])
        let eighteen = try #require(make(merged))
        #expect(eighteen.points.map(\.gross) == [82, 78, 80]) // same instant: id 1 before id 2
        #expect(make(merged, .nine) == nil) // one nine: the hint
        #expect(merged.filter(\.isOutside).map(\.gross) == [78])
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

    /// PC-LS-06: first, middle and newest dates; 2 rounds have no middle. An outside score's day reads in UTC,
    /// so it's the date picked anywhere (DM-OS-04).
    @Test func captions() throws {
        let ten = try #require(make(scores(Array(repeating: 80, count: 10))))
        #expect(ten.captions.map(\.index) == [0, 5, 9])
        #expect(ten.captions.map(\.text) == ["Sep 6", "Oct 11", "Nov 8"])
        let two = try #require(make(scores([80, 81])))
        #expect(two.captions.map(\.text) == ["Nov 1", "Nov 8"])

        var hawaii = Calendar(identifier: .gregorian)
        hawaii.timeZone = TimeZone(identifier: "Pacific/Honolulu")!
        let midnightUTC = Date(timeIntervalSince1970: 1_794_096_000) // Nov 8 00:00 UTC: Nov 7 in Hawaii
        let mixed = [LatestScores.Score(id: UUID(), date: midnightUTC, holeCount: .eighteen, gross: 80, isOutside: true),
                     LatestScores.Score(id: UUID(), date: midnightUTC.addingTimeInterval(3600), holeCount: .eighteen, gross: 81, isOutside: false)]
        let local = try #require(LatestScores.make(mixed, holeCount: .eighteen, locale: Self.en, calendar: hawaii))
        #expect(local.points.map(\.day) == ["Nov 8", "Nov 7"])
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

/// PC-ST-05, PC-DT-04: the toggle switches the graph, outside scores are in it, and it follows the store.
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
        model.holeFilter = .eighteen
        #expect(model.latestScores == nil) // one 18: the hint
    }

    /// An outside score joins the graph on the next load; Avg and Best stay Maynard-only (PC-ST-02, 03).
    @Test func outsideScoresJoinTheGraph() throws {
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
        #expect(model.latestScores?.points.map(\.gross).last == 60)
        #expect(model.stats == maynardStats)
    }
}

// MARK: - Handicap trend (PC-HC, #72)

/// 09-player-card §6: gridlines, labels and when the chart hides (100 %).
struct HandicapTrendTests {
    private func points(_ values: [Double]) -> [PlayerSummaryCard.HandicapPoint] {
        values.enumerated().map { offset, value in
            PlayerSummaryCard.HandicapPoint(date: Calendar.current.date(byAdding: .month, value: offset - values.count + 1,
                                                                       to: ModelFixtures.referenceDate)!, index: value)
        }
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
        let en = Locale(identifier: "en_US")
        #expect(HandicapTrend.gridlineLabel(12, locale: en) == "12")
        #expect(HandicapTrend.gridlineLabel(0, locale: en) == "0")
        #expect(HandicapTrend.gridlineLabel(-2, locale: en) == "+2")
    }

    /// PC-HC-01, 03, 05, 06: the range, the last point's label and the summary; hidden under 2 points.
    @Test func makeAndHide() throws {
        let en = Locale(identifier: "en_US")
        #expect(HandicapTrend.make([], locale: en) == nil)
        #expect(HandicapTrend.make(points([9.0]), locale: en) == nil)
        let trend = try #require(HandicapTrend.make(points([11.2, 10.1, 9.0, 8.4]), locale: en))
        #expect(trend.chart.range == "11.2 → 8.4")
        #expect(trend.gridlines == [8, 10, 12] && trend.domain == 8...12)
        #expect(trend.lastLabel(locale: en) == "8.4")
        #expect(trend.chart.accessibilitySummary.hasPrefix("Handicap index fell from 11.2"))
        #expect(trend.chart.monthLabels.count == 3)
        #expect(HandicapTrend(chart: trend.chart, gridlines: []).domain == 0...1) // never built empty; still a valid range
    }
}

/// PC-HC-04: the trend comes from the manager's calculated series, even with a manual index, and ignores
/// the toggle; it's rebuilt only when the manager recalculates.
@MainActor
struct PlayerCardTrendTests {
    @Test func theTrendIsTheCalculatedSeries() async throws {
        let store = try PlayerCardStore()
        let mark = ModelFixtures.player("Mark", manualIndex: 30.0, in: store.context)
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
        #expect(trend.chart.points == handicaps.series(for: mark.id, months: PlayerCardViewModel.trendMonths))
        #expect(trend.chart.points.allSatisfy { $0.index != 30.0 }) // calculated, not the manual index
        #expect(model.handicap.source == .manual && model.handicapText == "30.0") // the header still shows the manual one
        model.holeFilter = .nine
        #expect(model.handicapTrend == trend) // the toggle doesn't touch it
        // Deleting the older rounds recalculates: a new revision rebuilds a shorter series.
        for round in try store.rounds.rounds(for: mark).filter({ Calendar.current.component(.month, from: $0.startedAt) < 4 }) {
            try store.rounds.delete(round)
        }
        await handicaps.refresh()
        #expect((model.handicapTrend?.chart.points.count ?? 0) < trend.chart.points.count)
    }
}

// MARK: - Previous rounds (PC-PR, #73)

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
