//
//  ScorecardViewModelTests.swift
//  MaynardGolfTests
//

import Foundation
import MaynardUI
import SwiftData
import Testing
import UIKit
@testable import MaynardGolf

/// Rounds whose change stream yields once.
@MainActor
private final class OneChangeRounds: RoundRepository {
    private let base: RoundRepository
    private(set) var reads = 0
    init(_ base: RoundRepository) { self.base = base }
    func inProgress() throws -> [Round] { try base.inProgress() }
    func recentCompleted(limit: Int?) throws -> [Round] { try base.recentCompleted(limit: limit) }
    func rounds(for player: Player) throws -> [Round] { try base.rounds(for: player) }
    func round(id: UUID) throws -> Round? {
        reads += 1
        return try base.round(id: id)
    }
    func allRounds(offset: Int, limit: Int) throws -> [Round] { try base.allRounds(offset: offset, limit: limit) }
    func create(players: [Player], holeCount: HoleCount, tee: Tee, weather: WeatherSnapshot?) throws -> Round {
        try base.create(players: players, holeCount: holeCount, tee: tee, weather: weather)
    }
    func saveScore(_ strokes: Int, hole: Int, for entry: RoundEntry) throws { try base.saveScore(strokes, hole: hole, for: entry) }
    func setCurrentHole(_ hole: Int, for round: Round) throws { try base.setCurrentHole(hole, for: round) }
    func deletedRounds(offset: Int, limit: Int) throws -> [Round] { try base.deletedRounds(offset: offset, limit: limit) }
    func permanentlyDelete(id: UUID) throws { try base.permanentlyDelete(id: id) }
    func restore(id: UUID) throws { try base.restore(id: id) }
    func emptyTrash() throws { try base.emptyTrash() }
    func delete(_ round: Round) throws { try base.delete(round) }
    func changes() -> AsyncStream<ModelChanges> { AsyncStream { $0.yield(ModelChanges()); $0.finish() } }
}

/// 08-scorecard: the live card, the header's text, the cells' labels (#64, #66, #67, #68).
@MainActor
struct ScorecardViewModelTests {
    private let context: ModelContext
    private let rounds: SwiftDataRoundRepository

    init() throws {
        context = try makeInMemoryContext()
        rounds = SwiftDataRoundRepository(context: context, tracker: ModelChangeTracker(context: context),
                                          clock: FixedClock(now: TestDates.teeOff))
    }

    /// SC-BH-01, 03: the card follows the round, and a saved score shows on the next read.
    @Test func loadsAndFollowsTheRound() throws {
        let players = ["Mark", "Phil"].map { ModelFixtures.player($0, in: context) }
        let round = try ModelFixtures.inProgressRound(players: players, thru: 3, in: context)
        let model = ScorecardViewModel(roundID: round.id, rounds: rounds, courses: BundleCourseProvider())
        model.load()
        #expect(model.card?.thru == 3 && model.card?.columns.map(\.firstName) == ["Mark", "Phil"])
        #expect(model.avatar(try #require(model.card?.columns.first)) == nil)
        try rounds.saveScore(4, hole: 4, for: round.sortedEntries[0])
        try rounds.saveScore(5, hole: 4, for: round.sortedEntries[1])
        model.load()
        #expect(model.card?.thru == 4)
    }

    /// A round deleted while the Scorecard is open (on another device) clears the card and shows the error.
    @Test func aRoundDeletedWhileOpen() throws {
        let round = try ModelFixtures.completedRound(players: [ModelFixtures.player("Mark", in: context)], in: context)
        let model = ScorecardViewModel(roundID: round.id, rounds: rounds, courses: BundleCourseProvider())
        model.load()
        #expect(model.card != nil)
        try rounds.delete(round)
        model.load()
        #expect(model.card == nil && model.loadError != nil)
    }

    /// A round that's gone shows the error, with Try again.
    @Test func aMissingRound() {
        let model = ScorecardViewModel(roundID: UUID(), rounds: rounds, courses: BundleCourseProvider())
        model.load()
        #expect(model.card == nil && model.loadError == "The scorecard couldn't be loaded.")
    }

    /// SC-BH-01: every store change reloads.
    @Test func changesReload() async throws {
        let round = try ModelFixtures.completedRound(players: [ModelFixtures.player("Mark", in: context)], in: context)
        let counting = OneChangeRounds(rounds)
        let model = ScorecardViewModel(roundID: round.id, rounds: counting, courses: BundleCourseProvider())
        await model.observe()
        #expect(counting.reads == 2)
        let dependencies = AppDependencies.preview(.inProgress) // held: a context doesn't keep its container
        let live = ScorecardViewModel(roundID: try #require(try dependencies.rounds.inProgress().first?.id), dependencies: dependencies)
        live.load()
        #expect(live.card?.columns.count == 3)
    }

    /// SC-HDR-03, 04: the status and start lines.
    @Test func headerText() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let start = utc.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 9, minute: 42))!
        #expect(ScorecardViewModel.status(par: 72, thru: 1) == "Par 72 · Thru 1")
        #expect(ScorecardViewModel.started(start, locale: Locale(identifier: "en_US"), calendar: utc) == "Wed, Nov 11 · 9:42\u{202F}AM") // a narrow no-break space before AM
    }

    /// 08-scorecard §6: what VoiceOver reads for a cell.
    @Test func cellLabels() {
        #expect(ScorecardViewModel.cellLabel(player: "Mark", hole: 3, score: 4, par: 4) == "Mark, hole 3, 4, Par")
        #expect(ScorecardViewModel.cellLabel(player: "Mark", hole: 3, score: 3, par: 4) == "Mark, hole 3, 3, Birdie")
        #expect(ScorecardViewModel.cellLabel(player: "Mark", hole: 3, score: nil, par: 4) == "Mark, hole 3, not played")
    }

    /// SC-HDR-05: every weather kind has its icon.
    @Test(arguments: [(WeatherKind.sunny, WeatherIcon.Kind.sunny), (.partlyCloudy, .partlyCloudy), (.cloudy, .cloudy),
                      (.rain, .rain), (.windy, .windy)])
    func weatherIcons(kind: WeatherKind, icon: WeatherIcon.Kind) {
        #expect(kind.icon == icon)
    }

    /// SC-PT-03: the total rows' titles.
    @Test func totalTitles() {
        #expect([ScorecardModel.Segment.out, .in, .tot].map(ScorecardTable.title) == ["Out", "In", "Tot"])
    }

    /// SC-PT-04 (#283): lines after HOLE (8 + 40) and PAR (+ 34), then between the four equal slots.
    @Test func portraitDividerPositions() {
        // 8 + 40 + 34 + 4 × 50 + 8 = 290 wide: slots start at 82 and are 50 wide.
        #expect(ScorecardTable.portraitDividerPositions(tableWidth: 290) == [48, 82, 132, 182, 232])
    }

    /// A table too narrow for any slot width keeps the slot lines on the PAR line, never left of it.
    @Test func portraitDividerPositionsNarrow() {
        #expect(ScorecardTable.portraitDividerPositions(tableWidth: 50) == [48, 82, 82, 82, 82])
    }
}

/// SC-BH-02, 05, 06: portrait everywhere but the Scorecard.
@MainActor
struct OrientationControllerTests {
    @Test func portraitUntilTheScorecardAllowsLandscape() {
        var applied: [UIInterfaceOrientationMask] = []
        let orientation = OrientationController { applied.append($0) }
        #expect(orientation.mask == .portrait && !orientation.allowsLandscape)
        orientation.lockPortrait() // already portrait: nothing to do
        orientation.allowLandscape()
        orientation.allowLandscape()
        #expect(orientation.mask == .allButUpsideDown)
        orientation.lockPortrait()
        #expect(orientation.mask == .portrait)
        #expect(applied == [.allButUpsideDown, .portrait]) // each change applied once
    }

    @Test func theDelegateAsksTheController() {
        #expect(AppDelegate().application(.shared, supportedInterfaceOrientationsFor: nil) == .portrait)
        let orientation = OrientationController { _ in }
        let delegate = AppDelegate(orientation: orientation)
        orientation.allowLandscape()
        #expect(delegate.application(.shared, supportedInterfaceOrientationsFor: nil) == .allButUpsideDown)
    }
}
