//
//  RoundCompleteTests.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
import Testing
@testable import MaynardGolf

/// Counts haptics.
@MainActor
private final class Haptics: HapticsProviding {
    private(set) var played: [HapticEvent] = []
    func play(_ event: HapticEvent) { played.append(event) }
}

/// 17-round-complete: the header, the rows in round order with no winner, and the screen's model (#119).
@MainActor
struct RoundCompleteTests {
    private let context: ModelContext
    private let rounds: SwiftDataRoundRepository
    private let course: Course
    private let utc: Calendar
    private let en = Locale(identifier: "en_US")
    /// Saturday 7 November 2026, noon UTC.
    private let saturday: Date

    init() throws {
        context = try makeInMemoryContext()
        rounds = SwiftDataRoundRepository(context: context, tracker: ModelChangeTracker(context: context),
                                          clock: FixedClock(now: TestDates.teeOff))
        course = try BundleCourseProvider().course(id: "MaynardGC")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        utc = calendar
        saturday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 12))!
    }

    private func finished(_ names: [String], holeCount: HoleCount = .nine, tee: Tee = .white) throws -> Round {
        let players = names.map { ModelFixtures.player($0, in: context) }
        return try ModelFixtures.completedRound(players: players, holeCount: holeCount, tee: tee, startedAt: saturday, in: context)
    }

    private func content(_ round: Round) -> RoundCompleteContent {
        RoundCompleteContent.make(round: RoundSnapshot(round), players: round.sortedEntries.compactMap(\.player).map(PlayerSnapshot.init),
                                  course: course, locale: en, calendar: utc)
    }

    /// RC-CT-01: the date and course, then the tee, hole count and duration (the fixture's last score is
    /// 15 minutes per hole after tee off).
    @Test(arguments: [(HoleCount.nine, Tee.white, "White tees · 9 holes · 2h 15m"),
                      (.eighteen, .blue, "Blue tees · 18 holes · 4h 30m")])
    func header(holeCount: HoleCount, tee: Tee, facts: String) throws {
        let summary = content(try finished(["Mark"], holeCount: holeCount, tee: tee))
        #expect(summary.dateLine == "Sat, Nov 7 · Maynard Golf Club")
        #expect(summary.factsLine == facts)
    }

    /// RC-CT-01: no duration when the round has no finish time.
    @Test func noDuration() throws {
        let players = [ModelFixtures.player("Mark", in: context)]
        let playing = try ModelFixtures.inProgressRound(players: players, thru: 3, startedAt: saturday, in: context)
        #expect(content(playing).factsLine == "White tees · 9 holes")
    }

    /// RC-CT-02, 03: one row per player in round order, gross and to-par, 1–4 players, no ranking.
    @Test(arguments: 1...4)
    func rowsInRoundOrder(count: Int) throws {
        let names = Array(["Tiger", "Ann", "Mark", "Bob"].prefix(count))
        let round = try finished(names)
        let rows = content(round).rows
        #expect(rows.map(\.firstName) == names) // round order, not sorted by score or name
        for (row, entry) in zip(rows, round.sortedEntries) {
            #expect(row.gross == entry.grossTotal)
            #expect(row.toPar == entry.toPar(pars: RoundHoleBuilder.pars(course: course, holeCount: .nine)))
        }
    }

    /// RC-DT-01, RC-BH-04: the model reads the round, plays the success haptic once, and survives a round
    /// that's gone.
    @Test func model() throws {
        let round = try finished(["Mark", "Phil"])
        let haptics = Haptics()
        let model = RoundCompleteViewModel(roundID: round.id, rounds: rounds, courses: BundleCourseProvider(), haptics: haptics)
        model.load()
        #expect(model.content?.rows.map(\.firstName) == ["Mark", "Phil"])
        #expect(model.loadError == nil)
        #expect(model.avatar(model.content!.rows[0]) == nil)
        model.appeared()
        model.appeared()
        #expect(haptics.played == [.success]) // once
        let gone = RoundCompleteViewModel(roundID: UUID(), rounds: rounds, courses: BundleCourseProvider(), haptics: haptics)
        gone.load()
        #expect(gone.content == nil && gone.loadError != nil)
        let dependencies = AppDependencies.preview(.onePlayer) // held: a context doesn't keep its container alive
        let live = RoundCompleteViewModel(roundID: try #require(try dependencies.rounds.recentCompleted(limit: 1).first?.id),
                                          dependencies: dependencies)
        live.load()
        #expect(live.content?.rows.count == 1)
    }
}
