//
//  ModelFixtures.swift
//  MaynardGolf
//

#if DEBUG
import Foundation
import SwiftData

/// Builders for test, UI-test and preview data (DM-TS-01). Every value is fixed: no `random`, no real
/// dates, so a data set looks the same in a unit test, a UI test seed and a preview (TS-VS-05).
@MainActor
enum ModelFixtures {
    /// The fixed "now" every data set is built around: 1 June 2026, 15:00 UTC.
    nonisolated static let referenceDate = Date(timeIntervalSince1970: 1_780_326_000)

    /// Pars of holes 1–9 (course-maynard-gc.md §1); holes 10–18 replay them.
    nonisolated static let pars = [4, 5, 3, 4, 4, 3, 4, 4, 4]

    /// Par for every hole of a round.
    nonisolated static func pars(for holeCount: HoleCount) -> [Int] {
        holeCount == .nine ? pars : pars + pars
    }

    /// A deterministic, believable score: par plus 0, 1 or 2 depending on the seed and hole.
    nonisolated static func strokes(seed: Int, hole: Int) -> Int {
        pars[(hole - 1) % 9] + (seed * 7 + hole * 3) % 3
    }

    /// Inserts a player.
    @discardableResult
    static func player(_ first: String, _ last: String = "", color: PlayerColor = .lake, manualIndex: Double? = nil,
                       in context: ModelContext, createdAt: Date = referenceDate, isMarquee: Bool = false) -> Player {
        let player = Player(firstName: first, lastName: last, color: color, createdAt: createdAt)
        player.isMarquee = isMarquee
        try? player.setHandicapIndex(manualIndex)
        context.insert(player)
        return player
    }

    /// Inserts a round and fills each card's first `thru` holes (all holes when nil). Scores come from
    /// `strokes(seed:hole:)` unless `scores` gives them per player (by card position).
    @discardableResult
    static func round(players: [Player], holeCount: HoleCount = .nine, tee: Tee = .white, startedAt: Date = referenceDate,
                      weather: WeatherSnapshot? = nil, thru: Int? = nil, scores: [[Int]]? = nil, seed: Int = 0,
                      in context: ModelContext) throws -> Round {
        let round = try Round.start(in: context, players: players, holeCount: holeCount, tee: tee,
                                    startedAt: startedAt, weather: weather)
        let holes = thru ?? holeCount.rawValue
        for entry in round.sortedEntries where holes > 0 {
            for hole in 1...holes {
                let value = scores?[entry.cardPosition][hole - 1] ?? strokes(seed: seed + entry.cardPosition, hole: hole)
                // Finish a few hours after tee off, so durations are realistic.
                try entry.setStrokes(value, forHole: hole, at: startedAt.addingTimeInterval(Double(hole) * 900))
            }
        }
        round.currentHole = min(max(holes + 1, 1), holeCount.rawValue)
        return round
    }

    /// A finished round.
    @discardableResult
    static func completedRound(players: [Player], holeCount: HoleCount = .nine, tee: Tee = .white,
                               startedAt: Date = referenceDate, weather: WeatherSnapshot? = nil, seed: Int = 0,
                               in context: ModelContext) throws -> Round {
        try round(players: players, holeCount: holeCount, tee: tee, startedAt: startedAt, weather: weather,
                  seed: seed, in: context)
    }

    /// A round being played, scored through hole `thru` for every player.
    @discardableResult
    static func inProgressRound(players: [Player], thru: Int, holeCount: HoleCount = .nine, tee: Tee = .white,
                                startedAt: Date = referenceDate, in context: ModelContext) throws -> Round {
        precondition(thru < holeCount.rawValue, "an in-progress round has an unplayed hole")
        return try round(players: players, holeCount: holeCount, tee: tee, startedAt: startedAt, thru: thru, in: context)
    }

    /// Weather for a given kind, captured at tee off.
    nonisolated static func weather(_ kind: WeatherKind, temperatureF: Int = 68, at date: Date = referenceDate) -> WeatherSnapshot {
        WeatherSnapshot(condition: kind, temperatureF: temperatureF, capturedAt: date)
    }

    nonisolated static func daysAgo(_ days: Int, hour: Int = 0) -> Date {
        referenceDate.addingTimeInterval(Double(-days * 86_400 + hour * 3_600))
    }
}

/// The named data sets shared by unit tests, UI-test seeds (`-uiTestSeed <name>`) and previews (DM-TS-01).
/// A new case also needs a `MaynardUITestCase.Seed` case and a row in `HarnessUITests`' expected counts.
enum Fixture: String, CaseIterable, Sendable {
    /// Nothing stored.
    case freshInstall
    /// One player with three finished rounds (the one-player Home layout).
    case onePlayer
    /// Two players with three finished rounds together (the two-player Home layout).
    case twoPlayers
    /// Three players and no rounds.
    case noRound
    /// Three players, two finished rounds and one round in progress.
    case inProgress
    /// Three players, one finished round and two rounds in progress.
    case twoInProgress
    /// Three players, one finished round and a 9-hole round in progress on hole 6 with missed scores (HP-OO,
    /// #192): hole 3 has no score for the third player and hole 4 none for anyone; holes 1, 2 and 5 are complete.
    case outOfOrder
    /// Seven players. Six have 20+ finished rounds each (9 and 18 holes, every tee, every weather kind,
    /// 1–4 players); Nina mostly plays 9 holes. Also a tied round and one older round still in progress
    /// (TS-UI-08).
    case fullHistory
    /// Seven players with Nina featured; otherwise fullHistory.
    case marquee
    /// Two players: first-created Mark is featured, with a compact Scottie row.
    case twoPlayersMarquee

    /// Inserts the data set into `context` and saves.
    @MainActor
    func populate(_ context: ModelContext) throws {
        typealias F = ModelFixtures
        switch self {
        case .freshInstall:
            break
        case .marquee:
            try Fixture.fullHistory.populate(context)
            let nina = try context.fetch(FetchDescriptor<Player>()).first { $0.firstName == "Nina" }
            nina?.isMarquee = true
        case .twoPlayersMarquee:
            try Fixture.twoPlayers.populate(context)
            let mark = try context.fetch(FetchDescriptor<Player>()).first { $0.firstName == "Mark" }
            mark?.isMarquee = true
        case .onePlayer:
            let mark = F.player("Mark", "Tassinari", color: .lake, in: context)
            for day in 0..<3 {
                try F.completedRound(players: [mark], startedAt: F.daysAgo(day * 7 + 2), weather: F.weather(.sunny), seed: day, in: context)
            }
        case .twoPlayers:
            let mark = F.player("Mark", "Tassinari", color: .lake, in: context)
            let scottie = F.player("Scottie", "Scheffler", color: .sand, manualIndex: -2.1, in: context)
            for day in 0..<3 {
                try F.completedRound(players: [mark, scottie], tee: .blue, startedAt: F.daysAgo(day * 7 + 2),
                                     weather: F.weather(.partlyCloudy), seed: day, in: context)
            }
        case .noRound:
            Self.threePlayers(context)
        case .inProgress:
            let p = Self.threePlayers(context)
            try F.completedRound(players: p, startedAt: F.daysAgo(9), weather: F.weather(.cloudy), in: context)
            try F.completedRound(players: [p[0], p[1]], holeCount: .eighteen, startedAt: F.daysAgo(4), in: context)
            try F.inProgressRound(players: p, thru: 4, startedAt: F.daysAgo(0, hour: -2), in: context)
        case .twoInProgress:
            let p = Self.threePlayers(context)
            try F.completedRound(players: p, startedAt: F.daysAgo(6), weather: F.weather(.windy), in: context)
            try F.inProgressRound(players: [p[0], p[1]], thru: 3, startedAt: F.daysAgo(1), in: context)
            try F.inProgressRound(players: [p[2]], thru: 11, holeCount: .eighteen, tee: .red, startedAt: F.daysAgo(0, hour: -1), in: context)
        case .outOfOrder:
            let p = Self.threePlayers(context)
            try F.completedRound(players: p, startedAt: F.daysAgo(6), weather: F.weather(.sunny), in: context)
            let startedAt = F.daysAgo(0, hour: -2)
            let round = try Round.start(in: context, players: p, holeCount: .nine, tee: .white, startedAt: startedAt)
            for entry in round.sortedEntries {
                for hole in [1, 2, 3, 5] where !(hole == 3 && entry.cardPosition == 2) {
                    try entry.setStrokes(F.strokes(seed: entry.cardPosition, hole: hole), forHole: hole,
                                         at: startedAt.addingTimeInterval(Double(hole) * 900))
                }
            }
            round.currentHole = 6
        case .fullHistory:
            let names: [(String, String, PlayerColor, Double?)] = [
                ("Mark", "Tassinari", .lake, nil), ("Scottie", "Scheffler", .sand, -2.1), ("Tiger", "Woods", .flag, nil),
                ("Phil", "Mickelson", .fairway, 12.7), ("Chris", "", .moss, nil), ("José", "María", .lake, 18.9),
            ]
            let players = names.enumerated().map { index, n in
                let player = F.player(n.0, n.1, color: n.2, manualIndex: n.3, in: context, createdAt: F.daysAgo(400 - index))
                player.id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!
                return player
            }
            let kinds = WeatherKind.allCases
            let tees = Tee.allCases
            // 60 rounds: each has 1–4 consecutive players rotating through the six, so everyone gets 20+.
            for index in 0..<60 {
                let size = index % 4 + 1
                let group = (0..<size).map { players[(index + $0) % players.count] }
                let holeCount: HoleCount = index % 3 == 0 ? .eighteen : .nine
                let weather = index % 11 == 10 ? nil : F.weather(kinds[index % kinds.count], temperatureF: 50 + index % 35,
                                                                at: F.daysAgo(index * 5 + 1))
                let round = try F.completedRound(players: group, holeCount: holeCount, tee: tees[index % tees.count],
                                     startedAt: F.daysAgo(index * 5 + 1), weather: weather, seed: index, in: context)
                // HOME-AR-09: a stable oldest-row target for the lazy-scrolling UI test (#84).
                if index == 59 { round.id = UUID(uuidString: "00000000-0000-0000-0000-000000000084")! }
            }
            // A player who mostly plays 9 holes (four 9-hole rounds, one 18).
            let nina = F.player("Nina", "Park", color: .moss, in: context, createdAt: F.daysAgo(200))
            nina.id = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!
            for index in 0..<5 {
                try F.completedRound(players: [nina], holeCount: index == 4 ? .eighteen : .nine,
                                     startedAt: F.daysAgo(index * 9 + 3, hour: 2), seed: 100 + index, in: context)
            }
            // A tied round: the same card for Mark and Tiger.
            let tiedScores = Array(repeating: [4, 5, 3, 4, 4, 3, 4, 4, 4], count: 2)
            try F.round(players: [players[0], players[2]], startedAt: F.daysAgo(2, hour: 3), scores: tiedScores, in: context)
            // An older round still in progress.
            try F.inProgressRound(players: [players[1], players[3]], thru: 5, startedAt: F.daysAgo(40), in: context)
        }
        try context.save()
    }

    @MainActor
    @discardableResult
    private static func threePlayers(_ context: ModelContext) -> [Player] {
        [ModelFixtures.player("Mark", "Tassinari", color: .lake, in: context),
         ModelFixtures.player("Scottie", "Scheffler", color: .sand, manualIndex: -2.1, in: context),
         ModelFixtures.player("Tiger", "Woods", color: .flag, in: context)]
    }
}
#endif
