//
//  PlayerCardViewModel.swift
//  MaynardGolf
//

import Foundation
import MaynardUI
import Observation
import OSLog
import UIKit

/// The Player card (09-player-card, PC-DT-01): one player's profile, their index from `HandicapManager`,
/// Avg / Best and the Latest Scores graph for the 9 / 18 toggle, and the 12-month handicap trend. It reloads on
/// every store change, so the card follows Edit, deleted rounds and outside scores (PC-DT-04); the index and trend
/// follow the manager by observation (HC-MG-03). The rules are pure (`PlayerCardStats`, `LatestScores`,
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
    /// The player's outside scores (#252), for the Latest Scores graph only: Avg and Best stay Maynard-only.
    private(set) var outsideScores: [OutsideScoreSnapshot] = []
    /// Previous rounds: the player's completed rounds by month, newest first, each with every player's chip
    /// (PC-PR-02, 03, 06, 07). Not filtered by the toggle.
    private(set) var roundSections: [RoundMonthSection] = []
    /// How many of those started this calendar year (PC-PR-01).
    private(set) var roundsThisYear = 0
    /// The course name on every row, from the course data (X-16).
    private(set) var courseName = ""
    /// A read failure, shown with Try again (error boundary).
    private(set) var loadError: String?
    /// True once the player is gone (deleted from Edit, All players or another device): the card closes.
    private(set) var isMissing = false

    @ObservationIgnored private var hasLoaded = false
    /// The trend with the manager `revision` it was built at, so a redraw doesn't run the 12-month calculation again.
    @ObservationIgnored private var trendCache: (revision: Int, trend: HandicapTrend?)?
    @ObservationIgnored private let players: PlayerRepository
    @ObservationIgnored private let rounds: RoundRepository
    @ObservationIgnored private let outside: OutsideScoreRepository
    @ObservationIgnored private let handicaps: HandicapManager
    @ObservationIgnored private let courses: CourseProvider
    @ObservationIgnored private let clock: AppClock
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let locale: Locale
    /// Decoded for the 72 pt profile avatar at 3× (PC-HDR-02), larger than a list's.
    @ObservationIgnored private let avatars = AvatarCache(pixels: PlayerCardViewModel.avatarPixels)
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "PlayerCard")

    /// `clock` and `calendar` decide what "this year" is (PC-PR-01); `calendar` and `locale` format the graph's dates.
    init(playerID: UUID, players: PlayerRepository, rounds: RoundRepository, outsideScores: OutsideScoreRepository,
         handicaps: HandicapManager, courses: CourseProvider, clock: AppClock, calendar: Calendar = .current, locale: Locale = .current) {
        self.playerID = playerID
        self.players = players
        self.rounds = rounds
        outside = outsideScores
        self.locale = locale
        self.handicaps = handicaps
        self.courses = courses
        self.clock = clock
        self.calendar = calendar
    }

    convenience init(playerID: UUID, dependencies: AppDependencies) {
        self.init(playerID: playerID, players: dependencies.players, rounds: dependencies.rounds, outsideScores: dependencies.outsideScores,
                  handicaps: dependencies.handicaps, courses: dependencies.courses, clock: dependencies.clock)
    }

    // MARK: Display values

    /// The index: calculated, else the starting index, else "—" (PC-HDR-05), from the manager only (HC-MG-01).
    var handicap: PlayerHandicap { handicaps.handicap(for: playerID) }

    /// "8.4", "+2.1" or "—" (PC-HDR-04, 05).
    var handicapText: String { handicap.displayText() }

    /// "Handicap index 8.4, calculated" (PC-HDR-05).
    var handicapAccessibilityLabel: String { PlayerCardStats.handicapAccessibilityLabel(handicap) }

    /// Avg score and Best for the toggle's hole count (PC-ST-02, 03, 05, 07).
    var stats: PlayerScoreStats { PlayerCardStats.stats(scores, holeCount: holeFilter) }

    /// The last 10 scores with the toggle's hole count, Maynard rounds and outside scores together, or nil (the
    /// hint) with fewer than 2 (PC-LS-02, 07, PC-ST-05).
    var latestScores: LatestScores? {
        LatestScores.make(LatestScores.scores(rounds: scores, outside: outsideScores), holeCount: holeFilter, locale: locale, calendar: calendar)
    }

    /// The calculated index at each of the last 12 month ends, or nil under 2 points (PC-HC-04, 06). Not
    /// affected by the toggle. Built once per manager `revision`; reading
    /// the revision keeps the card following the manager by observation.
    var handicapTrend: HandicapTrend? {
        let revision = handicaps.revision
        if let cached = trendCache, cached.revision == revision { return cached.trend }
        let trend = HandicapTrend.make(handicaps.series(for: playerID, months: Self.trendMonths))
        trendCache = (revision, trend)
        return trend
    }

    /// The profile avatar's short side in pixels: 72 pt at 3× (PC-HDR-02).
    static let avatarPixels = AvatarSize.profile.rawValue * 3

    /// How far back the handicap chart goes (PC-HC-02).
    static let trendMonths = 12

    /// The player's photo for the avatar, decoded once; nil shows the initial (PC-HDR-02).
    var avatar: UIImage? { avatars.image(for: playerID, photo: profile?.photoData) }

    /// "12 this year" next to PREVIOUS ROUNDS (PC-PR-01).
    var roundsThisYearText: String {
        String(localized: "\(roundsThisYear) this year", comment: "Player card: how many of the player's rounds were this calendar year, e.g. '12 this year'.")
    }

    /// No completed rounds: "No rounds yet" replaces the list (PC-PR-10).
    var hasNoRounds: Bool { roundSections.isEmpty }

    // MARK: Loading

    /// Reads the player and their rounds. A failure keeps what's shown and sets `loadError`.
    func load() {
        do {
            guard let player = try players.allPlayers().first(where: { $0.id == playerID }) else {
                isMissing = true
                return
            }
            let snapshot = PlayerSnapshot(player)
            let models = try rounds.rounds(for: player).filter(\.isComplete)
            let theirs = models.map(RoundSnapshot.init)
            let course = try courses.course(id: AppDependencies.courseID)
            // Every player in each round gets a chip, not only this one (PC-PR-03).
            let summaries = zip(models, theirs).map { model, round in
                RoundSummaryBuilder.summary(of: round, players: model.sortedEntries.compactMap(\.player).map(PlayerSnapshot.init), course: course)
            }
            profile = Profile(firstName: snapshot.firstName, fullName: snapshot.fullName, color: snapshot.color, photoData: snapshot.photoData)
            scores = PlayerCardStats.scores(for: playerID, in: theirs)
            outsideScores = try outside.scores(for: player).map(OutsideScoreSnapshot.init)
            roundSections = RoundMonthGrouping.sections(summaries, calendar: calendar)
            roundsThisYear = RoundMonthGrouping.countThisYear(summaries, now: clock.now, calendar: calendar)
            courseName = course.name
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
