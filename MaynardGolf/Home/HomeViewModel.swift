//
//  HomeViewModel.swift
//  MaynardGolf
//

import Foundation
import MaynardUI
import UIKit
import Observation
import OSLog

/// Home's state (HOME-VM-01…05): whether rounds are in progress, how the Players section is laid out (by
/// the marquee selection, then player count) and the recent rounds. It refreshes on every store change through the
/// repositories' change stream (HOME-VM-02); handicaps and their charts are read from `HandicapManager`
/// when drawn, so they follow it by observation (HC-MG-03).
@MainActor
@Observable
final class HomeViewModel {
    /// The round part of the screen (01-home §1).
    enum RoundState: Equatable {
        /// Before the first read: the screen shows placeholder rows (HOME-VM-03).
        case loading
        /// No players.
        case freshInstall
        /// Players, no round in progress.
        case noRound
        /// One card per round in progress, newest first (HOME-IPR-07).
        case inProgress([RoundSummary])
    }

    /// The Players section, chosen by marquee selection first, then player count (01-home §1).
    enum PlayersLayout: Equatable {
        case empty
        /// One summary card, with the handicap chart (§4.2).
        case one(PlayerStats)
        /// Two summary cards, without the chart (§4.3).
        case two(PlayerStats, PlayerStats)
        /// Up to 4 rows (§4). Rows show no stats, so these hold only the names and colors.
        case list([PlayerStats])
        /// The detailed selected card and compact others (HOME-MQ-01…03).
        case marquee(PlayerStats, others: [PlayerStats])
    }

    /// How many player rows the List layout shows (HOME-PLY-02).
    static let listLimit = 4

    /// The hero photo (HOME-HDR-01, 06): the bundled photo of Maynard's green. The course data has no
    /// per-course hero yet, so every course falls back to this one.
    static let heroImageName = "HomeHero"

    private(set) var roundState = RoundState.loading
    private(set) var playersLayout = PlayersLayout.empty
    /// Total count drives header actions, even when Home shows only four players (HOME-MQ-04).
    private(set) var playerCount = 0
    var showsAddPlayer: Bool { (1...2).contains(playerCount) }
    /// Completed rounds, newest first: 3 with a round in progress or summary cards, else 4 (HOME-RR-02).
    private(set) var recentRounds: [RoundSummary] = []
    /// Keeps All rounds / Trash reachable even after the final active round is deleted (#224).
    private(set) var hasDeletedRounds = false
    /// The course name for round rows (X-16: from the data, never a literal).
    private(set) var courseName = ""
    /// The inline error banner's message with "Try again" (HOME-VM-04), nil when there's none.
    private(set) var errorMessage: String?
    /// A Discard round that failed, shown as an alert with OK (HOME-IPR-08). Not the banner: its "Try
    /// again" reloads Home, which wouldn't retry the delete.
    var discardError: String?

    /// Avatars decoded once each (#155's review).
    @ObservationIgnored private let avatars = AvatarCache()
    /// Charts by player with the manager's `revision` they were built at, so a redraw doesn't run the
    /// 12-month calculation again.
    @ObservationIgnored private var charts: [UUID: (revision: Int, chart: HandicapChart?)] = [:]

    @ObservationIgnored private let players: PlayerRepository
    @ObservationIgnored private let rounds: RoundRepository
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let handicaps: HandicapManager
    @ObservationIgnored private let courses: CourseProvider
    @ObservationIgnored private let courseID: String
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "Home")

    init(players: PlayerRepository, rounds: RoundRepository, settings: SettingsStore, handicaps: HandicapManager,
         courses: CourseProvider, courseID: String = AppDependencies.courseID) {
        self.players = players
        self.rounds = rounds
        self.settings = settings
        self.handicaps = handicaps
        self.courses = courses
        self.courseID = courseID
    }

    /// The app's dependencies' repositories and services.
    convenience init(dependencies: AppDependencies) {
        self.init(players: dependencies.players, rounds: dependencies.rounds, settings: dependencies.settings,
                  handicaps: dependencies.handicaps, courses: dependencies.courses)
    }

    /// Settings › Show to-par scores; when off, the In-progress card shows gross totals (HOME-IPR-04).
    var showToPar: Bool { settings.showToPar }

    /// A player's handicap from the manager (the only source, HC-MG-01).
    func handicap(for playerID: UUID) -> PlayerHandicap { handicaps.handicap(for: playerID) }

    /// The One player / Marquee card's 12-month chart, or nil with fewer than 2 points (HOME-PC-06…08). Built once
    /// per manager `revision`; reading the revision keeps the card following the manager by observation.
    func chart(for playerID: UUID) -> HandicapChart? {
        let revision = handicaps.revision
        if let cached = charts[playerID], cached.revision == revision { return cached.chart }
        let chart = PlayerSummaryBuilder.chart(handicaps.series(for: playerID, months: 12))
        charts[playerID] = (revision, chart)
        return chart
    }

    /// A player's photo for an avatar, decoded once (`AvatarCache`); nil shows the initial.
    func avatar(for playerID: UUID, photo: Data?) -> UIImage? {
        avatars.image(for: playerID, photo: photo)
    }

    /// What VoiceOver reads for a summary card (HOME-PC-04), with the chart's summary when it shows.
    func accessibilitySummary(for stats: PlayerStats, chart: HandicapChart?) -> String {
        PlayerSummaryBuilder.accessibilitySummary(stats, handicap: handicap(for: stats.id), chart: chart)
    }

    /// Deletes a round in progress after the user confirmed Discard round (HOME-IPR-08). Home redraws
    /// from the change stream; a failure keeps the card and sets `discardError`.
    func discard(roundID: UUID) {
        do {
            guard let round = try rounds.inProgress().first(where: { $0.id == roundID }) else { return }
            try rounds.delete(round)
            refresh()
        } catch {
            log.error("Home couldn't discard a round: \(String(describing: error), privacy: .public)")
            discardError = String(localized: "The round couldn't be discarded.", comment: "Alert on Home when deleting a round in progress fails.")
        }
    }

    /// Reads everything again. A failure keeps what's shown and sets the banner (HOME-VM-04); "Try again"
    /// calls this.
    func refresh() {
        do {
            // Reads only what's drawn, since this runs on every store change, including each score saved
            // during a round: the rounds in progress, the recent rounds, each player's last round date,
            // and full stats only for the one or two summary cards.
            let course = try courses.course(id: courseID)
            // Player ids aren't unique-constrained (CloudKit, DM-PL-01): until `DuplicateResolver` merges a
            // duplicate, two records can share one. Keep the first record of each id; after this filter the
            // ids are unique, so the dictionaries below can't trap on a repeated key.
            var seen = Set<UUID>()
            let models = try players.allPlayers().filter { seen.insert($0.id).inserted }
            let everyone = models.map(PlayerSnapshot.init)
            let lastRound = Dictionary(uniqueKeysWithValues: models.compactMap { player in
                player.entries?.compactMap { $0.round }.filter { !$0.isTrashed }.map(\.startedAt).max().map { (player.id, $0) }
            })
            let byID = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })
            let ordered = PlayerSummaryBuilder.homeOrder(everyone, lastRound: lastRound).compactMap { byID[$0.id] }
            func stats(_ player: Player, full: Bool) throws -> PlayerStats {
                let theirs = full ? try rounds.rounds(for: player).map(RoundSnapshot.init) : []
                return PlayerSummaryBuilder.stats(for: PlayerSnapshot(player), rounds: theirs)
            }
            let selectedID = MarqueeSelection.selectedID(in: everyone)
            let layout: PlayersLayout
            if let selected = ordered.first(where: { $0.id == selectedID }) {
                let others = ordered.filter { $0.id != selected.id }.prefix(Self.listLimit - 1)
                layout = .marquee(try stats(selected, full: true), others: try others.map { try stats($0, full: false) })
            } else {
                layout = switch ordered.count {
                case 0: .empty
                case 1: .one(try stats(ordered[0], full: true))
                case 2: .two(try stats(ordered[0], full: true), try stats(ordered[1], full: true))
                default: .list(try ordered.prefix(Self.listLimit).map { try stats($0, full: false) })
                }
            }
            let playing = try rounds.inProgress().map(RoundSnapshot.init)
            let state: RoundState = everyone.isEmpty ? .freshInstall
                : playing.isEmpty ? .noRound
                : .inProgress(playing.map { RoundSummaryBuilder.summary(of: $0, players: everyone, course: course) })
            let compact = selectedID != nil || !playing.isEmpty || ordered.count == 1 || ordered.count == 2
            let hasDeletedRounds = try !rounds.deletedRounds(offset: 0, limit: 1).isEmpty
            let recent = try rounds.recentCompleted(limit: compact ? 3 : 4).map {
                RoundSummaryBuilder.summary(of: RoundSnapshot($0), players: everyone, course: course)
            }
            recentRounds = recent
            self.hasDeletedRounds = hasDeletedRounds
            playerCount = ordered.count
            playersLayout = layout
            roundState = state
            courseName = course.name
            errorMessage = nil
        } catch {
            log.error("Home couldn't read its data: \(String(describing: error), privacy: .public)")
            errorMessage = String(localized: "Your rounds couldn't be loaded.", comment: "Home's error banner when the data can't be read.")
        }
    }

    /// Refreshes once, then on every store change until the task is cancelled (HOME-VM-02). Both
    /// repositories publish every change from the one shared tracker (DM-SC-09); Home listens through
    /// the rounds repository, the more natural stream for it.
    func observe() async {
        refresh()
        for await _ in rounds.changes() { refresh() }
    }
}
