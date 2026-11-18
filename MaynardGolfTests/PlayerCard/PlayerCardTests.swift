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

    func model(_ id: UUID, players: PlayerRepository? = nil, handicaps: HandicapManager? = nil,
               courses: CourseProvider = BundleCourseProvider()) throws -> PlayerCardViewModel {
        PlayerCardViewModel(playerID: id, players: players ?? self.players, rounds: rounds, handicaps: try handicaps ?? self.handicaps(),
                            courses: courses, clock: FixedClock(now: ModelFixtures.referenceDate))
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

// MARK: - Score histogram (PC-HI, #71)

/// 09-player-card §5: bucketing, the round limit, the hole-count filter, the hint and the summary (100 %).
struct ScoreHistogramTests {
    private func scores(_ gross: [Int], _ holeCount: HoleCount = .eighteen) -> [PlayerRoundScore] {
        gross.enumerated().map { PlayerRoundScore(id: UUID(), date: ModelFixtures.daysAgo($0.offset), holeCount: holeCount, gross: $0.element) }
    }

    private func shape(_ buckets: [ScoreBucket]) -> [String] { buckets.map { "\($0.label)=\($0.count)" } }

    /// PC-HI-02: 2-stroke bars from the lowest score rounded down to even; the last bar is open-ended.
    @Test func bucketsStartEvenAndEndOpen() {
        #expect(shape(ScoreHistogram.buckets([75, 76, 79])) == ["74–75=1", "76–77=1", "78+=1"])
        #expect(shape(ScoreHistogram.buckets([74, 75, 74])) == ["74+=3"])
        #expect(shape(ScoreHistogram.buckets([38, 44])) == ["38–39=1", "40–41=0", "42–43=0", "44+=1"]) // gaps stay
        #expect(ScoreHistogram.buckets([-3, -1]).map(\.lower) == [-4, -2]) // rounding down works below zero
        #expect(ScoreHistogram.buckets([]).isEmpty)
    }

    /// PC-HI-02, 03: at most 6 bars; the 6th takes every higher score.
    @Test func overflowGoesInTheLastBar() {
        let buckets = ScoreHistogram.buckets([74, 76, 77, 84, 85, 90, 101])
        #expect(shape(buckets) == ["74–75=1", "76–77=2", "78–79=0", "80–81=0", "82–83=0", "84+=4"])
        #expect(buckets.map(\.id) == [74, 76, 78, 80, 82, 84])
        #expect(buckets.reduce(0) { $0 + $1.count } == 7)
    }

    /// Ties: every round on one score is one bar holding them all.
    @Test func tiesShareABar() {
        #expect(shape(ScoreHistogram.buckets([80, 80, 80, 80])) == ["80+=4"])
        #expect(shape(ScoreHistogram.buckets([80, 81, 80])) == ["80+=3"])
    }

    /// PC-HI-03, PC-ST-05: only the selected hole count, and only the newest 20 of it.
    @Test func filtersThenTakesTheNewest20() throws {
        let nines = scores([40, 41, 42], .nine)
        let eighteens = scores(Array(repeating: 80, count: 20) + [100, 100], .eighteen) // the two 100s are the oldest
        let mixed = nines + eighteens
        let eighteen = try #require(ScoreHistogram.make(mixed, holeCount: .eighteen))
        #expect(eighteen.roundCount == 20 && eighteen.holeCount == .eighteen)
        #expect(shape(eighteen.buckets) == ["80+=20"])
        let nine = try #require(ScoreHistogram.make(mixed, holeCount: .nine))
        #expect(shape(nine.buckets) == ["40–41=2", "42+=1"])
    }

    /// PC-HI-05: fewer than 3 rounds of the count → no chart (the hint shows).
    @Test func fewerThanThreeRoundsHasNoChart() {
        #expect(ScoreHistogram.make(scores([80, 82]), holeCount: .eighteen) == nil)
        #expect(ScoreHistogram.make(scores([80, 82, 84], .nine), holeCount: .eighteen) == nil)
        #expect(ScoreHistogram.make([], holeCount: .nine) == nil)
        #expect(ScoreHistogram.make(scores([80, 82, 84]), holeCount: .eighteen) != nil)
    }

    /// PC-HI-04: the summary names the count, hole count and each filled bar.
    @Test func accessibilitySummary() throws {
        let histogram = try #require(ScoreHistogram.make(scores([74, 75, 76, 77, 77, 77, 90]), holeCount: .eighteen))
        #expect(histogram.accessibilitySummary
            == "Histogram of the last 7 18-hole scores: 74–75, 2 rounds; 76–77, 4 rounds; 84+, 1 round")
    }
}

/// PC-ST-05: the toggle switches the histogram too.
@MainActor
struct PlayerCardHistogramTests {
    @Test func theToggleSwitchesTheHistogram() throws {
        let store = try PlayerCardStore()
        let mark = ModelFixtures.player("Mark", in: store.context)
        for day in 0..<4 { try ModelFixtures.completedRound(players: [mark], holeCount: .nine, startedAt: ModelFixtures.daysAgo(day + 1), seed: day, in: store.context) }
        for day in 0..<2 { try ModelFixtures.completedRound(players: [mark], holeCount: .eighteen, startedAt: ModelFixtures.daysAgo(day + 20), in: store.context) }
        let model = try store.model(mark.id)
        model.load()
        #expect(model.holeFilter == .nine)
        #expect(model.histogram?.roundCount == 4 && model.histogram?.holeCount == .nine)
        model.holeFilter = .eighteen
        #expect(model.histogram == nil) // two 18s: the hint
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
