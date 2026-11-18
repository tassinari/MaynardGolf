//
//  ScorecardViewModel.swift
//  MaynardGolf
//

import Foundation
import MaynardUI
import Observation
import OSLog
import UIKit

/// The live Scorecard (08-scorecard): the round's `ScorecardModel`, rebuilt on every store change so a
/// saved score shows at once (SC-BH-01), and the header's text. Read-only (SC-BH-07).
@MainActor
@Observable
final class ScorecardViewModel {
    let roundID: UUID
    private(set) var card: ScorecardModel?
    /// A read failure, shown with Try again.
    private(set) var loadError: String?

    @ObservationIgnored private let rounds: RoundRepository
    @ObservationIgnored private let courses: CourseProvider
    @ObservationIgnored private let avatars = AvatarCache()
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "Scorecard")

    init(roundID: UUID, rounds: RoundRepository, courses: CourseProvider) {
        self.roundID = roundID
        self.rounds = rounds
        self.courses = courses
    }

    convenience init(roundID: UUID, dependencies: AppDependencies) {
        self.init(roundID: roundID, rounds: dependencies.rounds, courses: dependencies.courses)
    }

    /// Reads the round and builds the card (SC-BH-03).
    func load() {
        do {
            guard let round = try rounds.round(id: roundID) else { throw Missing() }
            let course = try courses.course(id: round.courseID)
            card = ScorecardModel(round: RoundSnapshot(round), players: round.sortedEntries.compactMap(\.player).map(PlayerSnapshot.init),
                                  course: course)
            loadError = nil
        } catch {
            log.error("Scorecard couldn't read the round: \(String(describing: error), privacy: .public)")
            card = nil // don't keep showing a round that can no longer be read (deleted on another device)
            loadError = String(localized: "The scorecard couldn't be loaded.", comment: "Scorecard: shown when the round can't be read.")
        }
    }

    /// Loads, then again on every store change (SC-BH-01).
    func observe() async {
        load()
        for await _ in rounds.changes() { load() }
    }

    /// A player's photo for an avatar, decoded once.
    func avatar(_ column: ScorecardModel.Column) -> UIImage? { avatars.image(for: column.playerID, photo: column.photoData) }

    private struct Missing: Error {}

    // MARK: Text (pure)

    /// "Par 35 · Thru 4", shown in caps (SC-HDR-03).
    static func status(par: Int, thru: Int) -> String {
        String(localized: "Par \(par) · Thru \(thru)", comment: "Scorecard: the round's par and how many holes everyone has finished, e.g. 'Par 35 · Thru 4'. Shown in caps.")
    }

    /// "Wed, Nov 11 · 9:42 AM": when the round started (SC-HDR-04).
    static func started(_ date: Date, locale: Locale = .current, calendar: Calendar = .current) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        let day = date.formatted(style.weekday(.abbreviated).month(.abbreviated).day())
        let time = date.formatted(style.hour().minute())
        return String(localized: "\(day) · \(time)", comment: "Scorecard: the round's start, e.g. 'Wed, Nov 11 · 9:42 AM'.")
    }

    /// What VoiceOver reads for a score cell: "Mark, hole 3, 4, Par", or "Mark, hole 3, not played".
    static func cellLabel(player: String, hole: Int, score: Int?, par: Int) -> String {
        guard let score else {
            return String(localized: "\(player), hole \(hole), not played", comment: "Scorecard, VoiceOver: an empty cell, e.g. 'Mark, hole 3, not played'.")
        }
        let name = ScoreFormatter.scoreName(score: score, par: par).title
        return String(localized: "\(player), hole \(hole), \(score), \(name)", comment: "Scorecard, VoiceOver: a score cell, e.g. 'Mark, hole 3, 4, Par'.")
    }
}

extension WeatherKind {
    /// The design system's icon for this weather (SC-HDR-05).
    var icon: WeatherIcon.Kind {
        switch self {
        case .sunny: .sunny
        case .partlyCloudy: .partlyCloudy
        case .cloudy: .cloudy
        case .rain: .rain
        case .windy: .windy
        }
    }
}
