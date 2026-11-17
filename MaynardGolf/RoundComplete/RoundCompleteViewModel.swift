//
//  RoundCompleteViewModel.swift
//  MaynardGolf
//

import Foundation
import Observation
import OSLog
import UIKit

/// What Round complete shows (17-round-complete §3): the header lines and one row per player in round
/// order. No winner, ranking or "won" (RC-CT-03). Built purely from value snapshots (RC-DT-01).
struct RoundCompleteContent: Equatable, Sendable {
    /// One player's final line (RC-CT-02).
    struct Row: Identifiable, Equatable, Sendable {
        /// The round entry's id.
        let id: UUID
        let playerID: UUID
        let firstName: String
        let color: PlayerColor
        let photoData: Data?
        let gross: Int
        let toPar: Int
    }

    /// "Sat, Nov 8 · Maynard Golf Club".
    let dateLine: String
    /// "Blue tees · 18 holes · 4h 12m", shown in caps; no duration when it isn't known (RC-CT-01).
    let factsLine: String
    let rows: [Row]

    /// The content for a finished round, using the shared `RoundSummaryBuilder` for the scores.
    static func make(round: RoundSnapshot, players: [PlayerSnapshot], course: Course,
                     locale: Locale = .current, calendar: Calendar = .current) -> RoundCompleteContent {
        let summary = RoundSummaryBuilder.summary(of: round, players: players, course: course)
        let day = round.startedAt.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.abbreviated).month(.abbreviated).day())
        let dateLine = String(localized: "\(day) · \(course.name)",
                              comment: "Round complete: the round's date and the course, e.g. 'Sat, Nov 8 · Maynard Golf Club'.")
        var facts = [String(localized: "\(summary.teeName) tees", comment: "Round complete: the tee played, e.g. 'Blue tees'. Shown in caps."),
                     String(localized: "\(round.holeCount.rawValue) holes", comment: "Round complete: the round's hole count, e.g. '18 holes'. Shown in caps.")]
        if let finished = round.finishedAt, finished > round.startedAt {
            let minutes = Int(finished.timeIntervalSince(round.startedAt) / 60)
            facts.append(Duration.seconds(minutes * 60)
                .formatted(.units(allowed: [.hours, .minutes], width: .narrow).locale(locale)))
        }
        return RoundCompleteContent(
            dateLine: dateLine,
            factsLine: facts.joined(separator: " · "),
            rows: summary.players.map {
                Row(id: $0.id, playerID: $0.playerID, firstName: $0.firstName, color: $0.color, photoData: $0.photoData,
                    gross: $0.gross, toPar: $0.toPar)
            })
    }
}

/// Round complete's state (RC-DT-01): reads the finished round and builds its content; plays the
/// `.success` haptic once when the screen appears (RC-BH-04).
@MainActor
@Observable
final class RoundCompleteViewModel {
    let roundID: UUID
    private(set) var content: RoundCompleteContent?
    /// A read failure: the screen still offers both buttons.
    private(set) var loadError: String?

    @ObservationIgnored private let rounds: RoundRepository
    @ObservationIgnored private let courses: CourseProvider
    @ObservationIgnored private let haptics: HapticsProviding
    @ObservationIgnored private let avatars = AvatarCache()
    @ObservationIgnored private var celebrated = false
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "RoundComplete")

    init(roundID: UUID, rounds: RoundRepository, courses: CourseProvider, haptics: HapticsProviding) {
        self.roundID = roundID
        self.rounds = rounds
        self.courses = courses
        self.haptics = haptics
    }

    convenience init(roundID: UUID, dependencies: AppDependencies) {
        self.init(roundID: roundID, rounds: dependencies.rounds, courses: dependencies.courses, haptics: dependencies.haptics)
    }

    /// Reads the round; a round that's gone or unreadable sets `loadError`.
    func load() {
        do {
            guard let round = try rounds.round(id: roundID) else { throw Missing() }
            let course = try courses.course(id: round.courseID)
            let players = round.sortedEntries.compactMap(\.player).map(PlayerSnapshot.init)
            content = RoundCompleteContent.make(round: RoundSnapshot(round), players: players, course: course)
            loadError = nil
        } catch {
            log.error("Round complete couldn't read the round: \(String(describing: error), privacy: .public)")
            loadError = String(localized: "The round's scores couldn't be shown, but they're saved.",
                               comment: "Round complete: shown when the finished round can't be read.")
        }
    }

    /// The `.success` haptic, once (RC-BH-04).
    func appeared() {
        guard !celebrated else { return }
        celebrated = true
        haptics.play(.success)
    }

    /// A player's photo for the row's avatar, decoded once.
    func avatar(_ row: RoundCompleteContent.Row) -> UIImage? { avatars.image(for: row.playerID, photo: row.photoData) }

    private struct Missing: Error {}

    #if DEBUG
    /// A model showing `content` as if read, for previews of the whole screen.
    static func preview(content: RoundCompleteContent) -> RoundCompleteViewModel {
        let dependencies = AppDependencies.preview(.freshInstall)
        let model = RoundCompleteViewModel(roundID: UUID(), dependencies: dependencies)
        model.content = content
        model.previewDependencies = dependencies
        return model
    }

    /// Keeps a preview's in-memory store alive (a context doesn't keep its container).
    @ObservationIgnored private var previewDependencies: AppDependencies?
    #endif
}
