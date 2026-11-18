//
//  PlayerCardViewModel.swift
//  MaynardGolf
//

import Foundation
import Observation
import OSLog
import UIKit

/// The Player card (09-player-card, PC-DT-01): one player's profile, their index from `HandicapManager`,
/// Avg / Best and the score histogram for the 9 / 18 toggle, and the 12-month handicap trend. It reloads on
/// every store change, so the card follows Edit and deleted rounds (PC-DT-04); the index and trend follow the
/// manager by observation (HC-MG-03). The rules are pure (`PlayerCardStats`, `ScoreHistogram`,
/// `HandicapTrend`), so they're tested without a store.
@MainActor
@Observable
final class PlayerCardViewModel {
    /// Who the card is about (PC-HDR-02, 03).
    struct Profile: Equatable, Sendable {
        let firstName: String
        /// "Mark Tassinari", or the first name alone (DM-PL-09).
        let fullName: String
        let color: PlayerColor
        let photoData: Data?
    }

    let playerID: UUID
    private(set) var profile: Profile?
    /// The 9 / 18 toggle (PC-ST-04…06). Set to the player's most-played count on the first load, then left
    /// to the user; a new visit builds a new model, so the choice isn't remembered (PC-ST-06).
    var holeFilter: HoleCount = .eighteen
    /// The player's completed rounds, newest first.
    private(set) var scores: [PlayerRoundScore] = []
    /// A read failure, shown with Try again (error boundary).
    private(set) var loadError: String?
    /// True once the player is gone (deleted from Edit, All players or another device): the card closes.
    private(set) var isMissing = false

    @ObservationIgnored private var hasLoaded = false
    /// The trend with the manager `revision` it was built at, so a redraw doesn't run the 12-month calculation again.
    @ObservationIgnored private var trendCache: (revision: Int, trend: HandicapTrend?)?
    @ObservationIgnored private let players: PlayerRepository
    @ObservationIgnored private let rounds: RoundRepository
    @ObservationIgnored private let handicaps: HandicapManager
    @ObservationIgnored private let avatars = AvatarCache()
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "PlayerCard")

    init(playerID: UUID, players: PlayerRepository, rounds: RoundRepository, handicaps: HandicapManager) {
        self.playerID = playerID
        self.players = players
        self.rounds = rounds
        self.handicaps = handicaps
    }

    convenience init(playerID: UUID, dependencies: AppDependencies) {
        self.init(playerID: playerID, players: dependencies.players, rounds: dependencies.rounds, handicaps: dependencies.handicaps)
    }

    // MARK: Display values

    /// The index: manual, else calculated, else "—" (PC-HDR-05), from the manager only (HC-MG-01).
    var handicap: PlayerHandicap { handicaps.handicap(for: playerID) }

    /// "8.4", "+2.1" or "—" (PC-HDR-04, 05).
    var handicapText: String { handicap.displayText() }

    /// "Handicap index 8.4, calculated" (PC-HDR-05).
    var handicapAccessibilityLabel: String { PlayerCardStats.handicapAccessibilityLabel(handicap) }

    /// Avg score and Best for the toggle's hole count (PC-ST-02, 03, 05, 07).
    var stats: PlayerScoreStats { PlayerCardStats.stats(scores, holeCount: holeFilter) }

    /// The last 20 scores with the toggle's hole count in 2-stroke bars, or nil (the hint) with fewer than 3
    /// (PC-HI-03, 05, PC-ST-05).
    var histogram: ScoreHistogram? { ScoreHistogram.make(scores, holeCount: holeFilter) }

    /// The calculated index at each of the last 12 month ends, or nil under 2 points (PC-HC-04, 06). Not
    /// affected by the toggle, and shown even with a manual index. Built once per manager `revision`; reading
    /// the revision keeps the card following the manager by observation.
    var handicapTrend: HandicapTrend? {
        let revision = handicaps.revision
        if let cached = trendCache, cached.revision == revision { return cached.trend }
        let trend = HandicapTrend.make(handicaps.series(for: playerID, months: Self.trendMonths))
        trendCache = (revision, trend)
        return trend
    }

    /// How far back the handicap chart goes (PC-HC-02).
    static let trendMonths = 12

    /// The player's photo for the avatar, decoded once; nil shows the initial (PC-HDR-02).
    var avatar: UIImage? { avatars.image(for: playerID, photo: profile?.photoData) }

    // MARK: Loading

    /// Reads the player and their rounds. A failure keeps what's shown and sets `loadError`.
    func load() {
        do {
            guard let player = try players.allPlayers().first(where: { $0.id == playerID }) else {
                isMissing = true
                return
            }
            let snapshot = PlayerSnapshot(player)
            let theirs = try rounds.rounds(for: player).map(RoundSnapshot.init)
            profile = Profile(firstName: snapshot.firstName, fullName: snapshot.fullName, color: snapshot.color, photoData: snapshot.photoData)
            scores = PlayerCardStats.scores(for: playerID, in: theirs)
            if !hasLoaded { holeFilter = PlayerCardStats.defaultHoleCount(scores) }
            hasLoaded = true
            loadError = nil
        } catch {
            log.error("Player card couldn't read its data: \(String(describing: error), privacy: .public)")
            loadError = String(localized: "This player couldn't be loaded.", comment: "Player card: shown when the player or their rounds can't be read.")
        }
    }

    /// Loads, then again on every store change (PC-DT-04).
    func observe() async {
        load()
        for await _ in players.changes() { load() }
    }
}
