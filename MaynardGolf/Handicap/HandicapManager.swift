//
//  HandicapManager.swift
//  MaynardGolf
//

import Foundation
import MaynardUI
import Observation
import OSLog
import SwiftData

/// Where the manager reads players and rounds from: value snapshots, fetched off the main actor
/// (DM-SC-07). `BackgroundStore` is the live one; tests pass a fake.
protocol HandicapDataSource: Sendable {
    func handicapSnapshots() async throws -> (players: [PlayerSnapshot], rounds: [RoundSnapshot])
    /// Every player's outside scores (HC-CA-12, #253). A source without any keeps the default, none.
    func outsideScoreSnapshots() async throws -> [OutsideScoreSnapshot]
}

extension HandicapDataSource {
    func outsideScoreSnapshots() async throws -> [OutsideScoreSnapshot] { [] }
}

extension BackgroundStore: HandicapDataSource {
    /// Reads through a fresh context each time: the actor's own context lives for the whole session, and
    /// models it already holds could otherwise come back with cached values after a main-context save.
    func handicapSnapshots() async throws -> (players: [PlayerSnapshot], rounds: [RoundSnapshot]) {
        let context = ModelContext(modelContainer)
        let players = try context.fetch(FetchDescriptor<Player>()).map(PlayerSnapshot.init)
        let rounds = try context.fetch(FetchDescriptor<Round>(predicate: #Predicate { $0.deletedAt == nil })).map(RoundSnapshot.init)
        return (players, rounds)
    }

    func outsideScoreSnapshots() async throws -> [OutsideScoreSnapshot] {
        try ModelContext(modelContainer).fetch(FetchDescriptor<OutsideScore>()).map(OutsideScoreSnapshot.init)
    }
}

/// Every player's current handicap, kept up to date; the **only** place screens read an index from
/// (HC-MG-01, 18-handicap §4). Injected through `AppDependencies.handicaps`.
///
/// On launch and after every store change (local saves and iCloud imports both arrive on the tracker's
/// stream, DM-SC-09), it reads fresh snapshots and recalculates only the players whose inputs changed:
/// their manual index or their rounds (HC-MG-02). The calculation runs off the main actor (HC-MG-04);
/// screens update through observation (HC-MG-03). Nothing is stored (HC-MG-07).
@MainActor
@Observable
final class HandicapManager {
    /// What a player's handicap is calculated from; compared between passes to find who changed.
    struct Inputs: Equatable, Sendable {
        let manualIndex: Double?
        let rounds: [HandicapRound]
    }

    /// The current values. A player missing here shows "—" (HC-MG-05).
    private(set) var handicaps: [UUID: PlayerHandicap] = [:]
    /// What each calculated index was made of, for the Handicap screen (HC-MG-08). Missing until ready.
    private(set) var breakdowns: [UUID: HandicapBreakdown] = [:]
    /// True once the launch pass has finished.
    private(set) var isReady = false
    /// Goes up after every pass that changed someone's inputs (a manual index or a finished round), so a
    /// value derived from them, like Home's chart (`series`), can be cached against it and still follow
    /// by observation.
    private(set) var revision = 0
    /// True while the last read failed (values stay as they were); a screen can offer `refresh()` as
    /// "Try again" (error boundary).
    private(set) var loadFailed = false

    /// The players the last pass recalculated (tests check only the affected ones are, HC-TS-06).
    @ObservationIgnored private(set) var lastRecalculated: Set<UUID> = []
    @ObservationIgnored private var inputs: [UUID: Inputs] = [:]
    @ObservationIgnored private let source: HandicapDataSource
    @ObservationIgnored private let calculator: HandicapCalculator?
    @ObservationIgnored private let clock: AppClock
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let retryDelays: [Duration]
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "Handicap")
    /// Counts passes, so a pass that finishes after a newer one has started is dropped.
    @ObservationIgnored private var generation = 0

    /// `calculator` is nil when the course data couldn't be loaded; manual indexes still show, and every
    /// other player shows "—". `retryDelays` are the waits before retrying a failed launch read.
    init(source: HandicapDataSource, calculator: HandicapCalculator?, clock: AppClock, calendar: Calendar = .current,
         retryDelays: [Duration] = [.seconds(1), .seconds(5), .seconds(30)]) {
        self.source = source
        self.calculator = calculator
        self.clock = clock
        self.calendar = calendar
        self.retryDelays = retryDelays
    }

    /// The player's handicap, or `.none` until it's ready (HC-MG-05).
    func handicap(for playerID: UUID) -> PlayerHandicap {
        handicaps[playerID] ?? .none
    }

    /// The rounds behind the player's calculated index and which of them count (HC-MG-08), or `.empty`
    /// until it's ready or without course data.
    func breakdown(for playerID: UUID) -> HandicapBreakdown {
        breakdowns[playerID] ?? .empty
    }

    /// Calculates everyone (HC-MG-05), retrying a failed launch read after each of `retryDelays`, then
    /// recalculates after each batch of changes that touches players, rounds or cards, until the stream
    /// ends.
    func start(changes: AsyncStream<ModelChanges>) async {
        await refresh()
        for delay in retryDelays where !isReady {
            try? await Task.sleep(for: delay)
            await refresh()
        }
        for await batch in changes where Self.affectsHandicaps(batch) {
            await refresh()
        }
    }

    /// Whether a batch touches what handicaps are made of. Other saves don't start a pass.
    nonisolated static func affectsHandicaps(_ batch: ModelChanges) -> Bool {
        !batch.only(Player.self).isEmpty || !batch.only(Round.self).isEmpty || !batch.only(RoundEntry.self).isEmpty
            || !batch.only(OutsideScore.self).isEmpty
    }

    /// One pass: fetch snapshots, find the players whose inputs changed (or who are new or gone) and
    /// recalculate only them. A failed fetch is logged, `loadFailed` is set and the current values stay.
    /// Also the "Try again" action.
    func refresh() async {
        generation += 1
        let pass = generation
        let snapshots: (players: [PlayerSnapshot], rounds: [RoundSnapshot])
        let outside: [OutsideScoreSnapshot]
        do {
            snapshots = try await source.handicapSnapshots()
            outside = try await source.outsideScoreSnapshots()
        } catch {
            log.error("Couldn't read rounds for handicaps: \(String(describing: error), privacy: .public)")
            if pass == generation { loadFailed = true }
            return
        }
        // Finished rounds only (the rest never count, HC-CA-01), so a stroke saved mid-round recalculates
        // nobody. Outside scores join them (HC-CA-12). In date order: the store's fetch order isn't stable, and an unchanged list in another
        // order must not count as a change.
        var fresh: [UUID: Inputs] = [:]
        for player in snapshots.players where fresh[player.id] == nil {
            let rounds = (HandicapRound.rounds(for: player.id, in: snapshots.rounds).filter(\.isComplete)
                + HandicapRound.outside(for: player.id, in: outside))
                .sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }
            fresh[player.id] = Inputs(manualIndex: player.handicapIndex, rounds: rounds)
        }
        let changed = fresh.filter { inputs[$0.key] != $0.value }
        let results = await Self.calculate(changed, with: calculator)
        guard pass == generation else { return } // a newer pass started meanwhile; its result wins

        loadFailed = false
        inputs = fresh
        var updated = handicaps.filter { fresh[$0.key] != nil } // players who are gone drop out
        updated.merge(results.mapValues(\.handicap)) { _, new in new }
        if updated != handicaps { handicaps = updated }
        var details = breakdowns.filter { fresh[$0.key] != nil }
        details.merge(results.mapValues(\.breakdown)) { _, new in new }
        if details != breakdowns { breakdowns = details }
        lastRecalculated = Set(changed.keys)
        if !changed.isEmpty { revision += 1 }
        isReady = true
    }

    /// Off the main actor: each changed player's handicap and breakdown from their inputs. Without a
    /// calculator only a manual index can be shown, with an empty breakdown.
    @concurrent
    nonisolated static func calculate(_ work: [UUID: Inputs], with calculator: HandicapCalculator?) async
        -> [UUID: (handicap: PlayerHandicap, breakdown: HandicapBreakdown)] {
        work.mapValues { inputs in
            guard let calculator else {
                return (inputs.manualIndex.map { PlayerHandicap(index: $0, source: .manual, roundsUsed: 0) } ?? .none, .empty)
            }
            return (calculator.handicap(manualIndex: inputs.manualIndex, rounds: inputs.rounds), calculator.breakdown(rounds: inputs.rounds))
        }
    }

    /// The calculated index at the end of each of the last `months` months, oldest first, using only rounds
    /// played by then (HC-MG-06). The current month ends now. Months without enough rounds give no point.
    /// Always calculated, never the manual index, for the Player card chart (PC-HC-04).
    func series(for playerID: UUID, months: Int) -> [PlayerSummaryCard.HandicapPoint] {
        guard let calculator, let rounds = inputs[playerID]?.rounds, months > 0 else { return [] }
        return Self.monthEnds(months, before: clock.now, calendar: calendar).compactMap { end in
            calculator.calculatedIndex(rounds: rounds, upTo: end).map { PlayerSummaryCard.HandicapPoint(date: end, index: $0) }
        }
    }

    /// The last instant of each of the last `count` months, oldest first; the current month's is `now`.
    nonisolated static func monthEnds(_ count: Int, before now: Date, calendar: Calendar) -> [Date] {
        guard let thisMonth = calendar.dateInterval(of: .month, for: now)?.start else { return [] }
        let earlier = (1..<max(count, 1)).reversed().compactMap { back in
            calendar.date(byAdding: .month, value: -back + 1, to: thisMonth)?.addingTimeInterval(-1)
        }
        return earlier + [now]
    }
}
