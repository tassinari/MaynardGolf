//
//  HomeViewModel.swift
//  MaynardGolf
//

import Foundation
import MaynardUI
import Observation
import OSLog

/// Home's state (HOME-VM-01…05): whether rounds are in progress, how the Players section is laid out (by
/// the player count only) and the recent rounds. It refreshes on every store change through the
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

    /// The Players section, chosen by the player count only (01-home §1).
    enum PlayersLayout: Equatable {
        case empty
        /// One summary card, with the handicap chart (§4.2).
        case one(PlayerStats)
        /// Two summary cards, without the chart (§4.3).
        case two(PlayerStats, PlayerStats)
        /// Up to 4 rows (§4).
        case list([PlayerStats])
    }

    /// How many player rows the List layout shows (HOME-PLY-02).
    static let listLimit = 4

    private(set) var roundState = RoundState.loading
    private(set) var playersLayout = PlayersLayout.empty
    /// Completed rounds, newest first: 3 with a round in progress or summary cards, else 4 (HOME-RR-02).
    private(set) var recentRounds: [RoundSummary] = []
    /// The course name for round rows (X-16: from the data, never a literal).
    private(set) var courseName = ""
    /// The inline error banner's message with "Try again" (HOME-VM-04), nil when there's none.
    private(set) var errorMessage: String?

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

    /// The One player card's 12-month chart, or nil with fewer than 2 points (HOME-PC-06…08).
    func chart(for playerID: UUID) -> HandicapChart? {
        PlayerSummaryBuilder.chart(handicaps.series(for: playerID, months: 12))
    }

    /// Reads everything again. A failure keeps what's shown and sets the banner (HOME-VM-04); "Try again"
    /// calls this.
    func refresh() {
        do {
            let course = try courses.course(id: courseID)
            let everyone = try players.allPlayers().map(PlayerSnapshot.init)
            let playing = try rounds.inProgress().map(RoundSnapshot.init)
            let completed = try rounds.recentCompleted(limit: nil).map(RoundSnapshot.init)

            let ordered = PlayerSummaryBuilder.homeOrder(everyone.map { PlayerSummaryBuilder.stats(for: $0, rounds: completed) })
            let layout: PlayersLayout = switch ordered.count {
            case 0: .empty
            case 1: .one(ordered[0])
            case 2: .two(ordered[0], ordered[1])
            default: .list(Array(ordered.prefix(Self.listLimit)))
            }
            let state: RoundState = everyone.isEmpty ? .freshInstall
                : playing.isEmpty ? .noRound
                : .inProgress(playing.map { RoundSummaryBuilder.summary(of: $0, players: everyone, course: course) })
            let compact = !playing.isEmpty || ordered.count == 1 || ordered.count == 2
            recentRounds = completed.prefix(compact ? 3 : 4).map { RoundSummaryBuilder.summary(of: $0, players: everyone, course: course) }
            playersLayout = layout
            roundState = state
            courseName = course.name
            errorMessage = nil
        } catch {
            log.error("Home couldn't read its data: \(String(describing: error), privacy: .public)")
            errorMessage = String(localized: "Your rounds couldn't be loaded.", comment: "Home's error banner when the data can't be read.")
        }
    }

    /// Refreshes once, then on every store change until the task is cancelled (HOME-VM-02).
    func observe() async {
        refresh()
        for await _ in players.changes() { refresh() }
    }
}
