//
//  RoundDetailTests.swift
//  MaynardGolfTests
//

import Foundation
import MaynardUI
import SwiftData
import Testing
@testable import MaynardGolf

/// 10-round-detail: the header lines, the players strip, the legend and the model (#75, #76, #77).
@MainActor
struct RoundDetailTests {
    private let context: ModelContext
    private let rounds: SwiftDataRoundRepository
    private let course: Course
    private let utc: Calendar
    private let en = Locale(identifier: "en_US")
    /// Saturday 8 November 2025, 8:40 UTC.
    private let saturday: Date

    init() throws {
        context = try makeInMemoryContext()
        rounds = SwiftDataRoundRepository(context: context, tracker: ModelChangeTracker(context: context),
                                          clock: FixedClock(now: TestDates.teeOff))
        course = try BundleCourseProvider().course(id: "MaynardGC")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        utc = calendar
        saturday = calendar.date(from: DateComponents(year: 2025, month: 11, day: 8, hour: 8, minute: 40))!
    }

    private func content(_ round: Round) -> RoundDetailContent {
        RoundDetailContent.make(round: RoundSnapshot(round), players: round.sortedEntries.compactMap(\.player).map(PlayerSnapshot.init),
                                course: course, locale: en, calendar: utc)
    }

    /// RD-HDR-01…03: the course, the date, tee time and duration, and the tees, par and yards for the round.
    @Test(arguments: [(HoleCount.eighteen, "Blue tees · Par 70 · 6,026 yds", "4h 30m"), (.nine, "Blue tees · Par 35 · 3,013 yds", "2h 15m")])
    func header(holeCount: HoleCount, teeLine: String, duration: String) throws {
        let round = try ModelFixtures.completedRound(players: [ModelFixtures.player("Mark", in: context)], holeCount: holeCount,
                                                     tee: .blue, startedAt: saturday, weather: ModelFixtures.weather(.sunny), in: context)
        let detail = content(round)
        #expect(detail.courseName == "Maynard Golf Club")
        #expect(detail.metaLine == "Sat, Nov 8 · Tee time 8:40\u{202F}AM · \(duration)")
        #expect(detail.teeLine == teeLine)
        #expect(detail.weather?.condition == .sunny)
    }

    /// RD-HDR-02: no duration while a round has no finish.
    @Test func noDuration() throws {
        let playing = try ModelFixtures.inProgressRound(players: [ModelFixtures.player("Mark", in: context)], thru: 2,
                                                        startedAt: saturday, in: context)
        #expect(content(playing).metaLine == "Sat, Nov 8 · Tee time 8:40\u{202F}AM")
        #expect(content(playing).weather == nil)
    }

    /// RD-PL-01…03: every player in round order with gross and to-par, no ranking; the scorecard has no
    /// current-hole highlight (RD-SC-02).
    @Test(arguments: 1...4)
    func playersInRoundOrder(count: Int) throws {
        let names = Array(["Tiger", "Ann", "Mark", "Bob"].prefix(count))
        let round = try ModelFixtures.completedRound(players: names.map { ModelFixtures.player($0, in: context) }, startedAt: saturday, in: context)
        let detail = content(round)
        #expect(detail.players.map(\.firstName) == names)
        #expect(detail.players.map(\.gross) == round.sortedEntries.map(\.grossTotal))
        #expect(detail.scorecard.currentHole == nil)
    }

    /// RD-SC-04: Birdie, Bogey, Double+, with Eagle first only when the round has one.
    @Test func legend() throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let plain = try ModelFixtures.round(players: [mark], startedAt: saturday, scores: [[4, 5, 3, 4, 4, 3, 4, 4, 4]], in: context)
        #expect(content(plain).legend == [.birdie, .bogey, .doublePlus])
        let eagle = try ModelFixtures.round(players: [mark], startedAt: saturday, scores: [[2, 5, 3, 4, 4, 3, 4, 4, 4]], in: context)
        #expect(content(eagle).legend == [.eagle, .birdie, .bogey, .doublePlus])
    }

    /// RD-DT-01, RD-ED-02: the model reads the round, follows changes and survives a round that's gone.
    @Test func model() async throws {
        let round = try ModelFixtures.completedRound(players: [ModelFixtures.player("Mark", in: context)], in: context)
        let model = RoundDetailViewModel(roundID: round.id, rounds: rounds, courses: BundleCourseProvider())
        model.load()
        let detail = try #require(model.content)
        #expect(model.avatar(detail.players[0]) == nil && model.avatar(detail.scorecard.columns[0]) == nil)
        try rounds.delete(round)
        model.load()
        #expect(model.content == nil && model.loadError == "This round couldn't be loaded.")
        let dependencies = AppDependencies.preview(.onePlayer) // held: a context doesn't keep its container
        let finished = try #require(try dependencies.rounds.recentCompleted(limit: 1).first)
        let live = RoundDetailViewModel(roundID: finished.id, dependencies: dependencies)
        let observing = Task { await live.observe() }
        try await Task.sleep(for: .milliseconds(50))
        // An edit (RD-ED-02): the change stream reloads the totals.
        try dependencies.rounds.saveScore(9, hole: 1, for: finished.sortedEntries[0])
        try await Task.sleep(for: .milliseconds(200))
        observing.cancel()
        #expect(live.content?.players.first?.gross == finished.sortedEntries[0].grossTotal)
        #expect(live.content?.scorecard.columns.first?.scores.first == 9)
    }

    /// RD-TOP-01: "Home" right on Home, "Rounds" from a list.
    @Test func backTitle() {
        #expect(RoundDetailViewModel.backTitle(path: [.roundDetail(UUID())]) == "Home")
        #expect(RoundDetailViewModel.backTitle(path: [.allRounds, .roundDetail(UUID())]) == "Rounds")
    }
}
