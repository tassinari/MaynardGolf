//
//  RoundDetailViewModel.swift
//  MaynardGolf
//

import Foundation
import MaynardUI
import Observation
import OSLog
import UIKit

/// What Round detail shows (10-round-detail §3–5): the header lines, the players strip in round order (no
/// badges, no winner) and the scorecard with its legend. Pure, from value snapshots (RD-DT-03).
struct RoundDetailContent: Equatable, Sendable {
    /// One player's result in the strip (RD-PL-02).
    struct PlayerResult: Identifiable, Equatable, Sendable {
        /// The round entry's id.
        let id: UUID
        let playerID: UUID
        let firstName: String
        let color: PlayerColor
        let photoData: Data?
        let gross: Int
        let toPar: Int
    }

    /// "Maynard Golf Club" (RD-HDR-01).
    let courseName: String
    /// "Sat, Nov 8 · Tee time 8:40 AM · 4h 12m"; no duration when it isn't known (RD-HDR-02).
    let metaLine: String
    /// "Blue tees · Par 72 · 6,412 yds", shown in caps (RD-HDR-03).
    let teeLine: String
    /// Nil hides the weather pill (RD-HDR-04).
    let weather: WeatherSnapshot?
    let players: [PlayerResult]
    let scorecard: ScorecardModel
    /// Birdie, Bogey, Double+, with Eagle first only if the round has one (RD-SC-04).
    let legend: [ScoreLegend.Item]

    /// "4h 12m" from tee off to the last score, or nil while the round has no finish (RD-HDR-02). The PDF
    /// shows the same text in caps (RP-HD-04).
    static func duration(of round: RoundSnapshot, locale: Locale) -> String? {
        guard let finished = round.finishedAt, finished > round.startedAt else { return nil }
        let minutes = Int(finished.timeIntervalSince(round.startedAt) / 60)
        return Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow).locale(locale))
    }

    static func make(round: RoundSnapshot, players: [PlayerSnapshot], course: Course,
                     locale: Locale = .current, calendar: Calendar = .current) -> RoundDetailContent {
        let summary = RoundSummaryBuilder.summary(of: round, players: players, course: course)
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        let day = round.startedAt.formatted(style.weekday(.abbreviated).month(.abbreviated).day())
        let time = round.startedAt.formatted(style.hour().minute())
        var meta = [day, String(localized: "Tee time \(time)", comment: "Round detail: when the round started, e.g. 'Tee time 8:40 AM'.")]
        if let duration = duration(of: round, locale: locale) { meta.append(duration) }
        let holes = RoundHoleBuilder.holes(course: course, holeCount: round.holeCount)
        let par = holes.reduce(0) { $0 + $1.par }
        let yards = RoundHoleBuilder.yards(course: course, holeCount: round.holeCount, tee: round.tee)
        let teeLine = [
            String(localized: "\(summary.teeName) tees", comment: "Round complete: the tee played, e.g. 'Blue tees'. Shown in caps."),
            String(localized: "Par \(par)", comment: "Round detail: the round's par, e.g. 'Par 72'. Shown in caps."),
            String(localized: "\(yards.formatted(.number.grouping(.automatic).locale(locale))) yds",
                   comment: "Tee card: total yardage for the round, e.g. '3,013 yds'."),
        ].joined(separator: " · ")
        let scorecard = ScorecardModel(round: round, players: players, course: course)
        let hasEagle = scorecard.rows.contains { row in
            guard case .hole(_, let par, let scores, _) = row else { return false }
            return scores.contains { $0.map { $0 <= par - 2 } ?? false }
        }
        return RoundDetailContent(
            courseName: course.name,
            metaLine: meta.joined(separator: " · "),
            teeLine: teeLine,
            weather: round.weather,
            players: summary.players.map {
                PlayerResult(id: $0.id, playerID: $0.playerID, firstName: $0.firstName, color: $0.color, photoData: $0.photoData,
                             gross: $0.gross, toPar: $0.toPar)
            },
            scorecard: scorecard,
            legend: (hasEagle ? [.eagle] : []) + [.birdie, .bogey, .doublePlus])
    }
}

/// A PDF ready for the share sheet; Identifiable so it can drive `.sheet(item:)`.
struct SharedPDF: Identifiable, Equatable {
    let url: URL
    var id: URL { url }
}

/// Round detail's state (RD-DT-01): the round's content, rebuilt on every store change so an edit shows
/// on return (RD-ED-02), and Share (RD-SH-01…05).
@MainActor
@Observable
final class RoundDetailViewModel {
    /// Where Share is (RD-SH-05, RP-EX-02): nothing, making the PDF (with the progress indicator once it
    /// takes longer than `progressDelay`), or showing the share sheet.
    enum ShareState: Equatable {
        case idle
        case preparing(showsProgress: Bool)
        case presenting(SharedPDF)
    }

    let roundID: UUID
    private(set) var content: RoundDetailContent?
    private(set) var shareState: ShareState = .idle
    /// True while the "Couldn't create the PDF" alert shows (RP-EX-07).
    var shareFailed = false
    /// A read failure, shown with Try again.
    private(set) var loadError: String?
    /// True once the round is gone (deleted on another device, or from All rounds): the screen closes,
    /// since Try again could never find it.
    private(set) var isMissing = false

    @ObservationIgnored private let rounds: RoundRepository
    @ObservationIgnored private let courses: CourseProvider
    @ObservationIgnored private let exporter: RoundPDFExporter
    @ObservationIgnored private let progressDelay: Duration
    /// The values the last load read, so Share builds the PDF from the round as it's shown, never from live
    /// models off the main actor (RP-EX-01, DM-SC-07).
    @ObservationIgnored private var snapshot: (round: RoundSnapshot, players: [PlayerSnapshot], course: Course)?
    /// False once the screen has gone (popped, or covered by a push); a PDF that finishes then isn't shown.
    @ObservationIgnored private var isOnScreen = true
    @ObservationIgnored private let avatars = AvatarCache()
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "RoundDetail")

    /// `progressDelay` is how long making the PDF may take before the share button shows progress (300 ms,
    /// RD-SH-05); tests shorten it.
    init(roundID: UUID, rounds: RoundRepository, courses: CourseProvider, exporter: RoundPDFExporter,
         progressDelay: Duration = .milliseconds(300)) {
        self.roundID = roundID
        self.rounds = rounds
        self.courses = courses
        self.exporter = exporter
        self.progressDelay = progressDelay
    }

    convenience init(roundID: UUID, dependencies: AppDependencies) {
        self.init(roundID: roundID, rounds: dependencies.rounds, courses: dependencies.courses, exporter: dependencies.pdf)
    }

    func load() {
        do {
            guard let round = try rounds.round(id: roundID) else {
                content = nil
                isMissing = true
                return
            }
            let course = try courses.course(id: round.courseID)
            let values = (round: RoundSnapshot(round), players: round.sortedEntries.compactMap(\.player).map(PlayerSnapshot.init), course: course)
            content = RoundDetailContent.make(round: values.round, players: values.players, course: course)
            snapshot = values
            loadError = nil
        } catch {
            log.error("Round detail couldn't read the round: \(String(describing: error), privacy: .public)")
            content = nil
            snapshot = nil
            loadError = String(localized: "This round couldn't be loaded.", comment: "Round detail: shown when the round can't be read.")
        }
    }

    /// Loads, then again on every store change.
    func observe() async {
        load()
        for await _ in rounds.changes() { load() }
    }

    // MARK: Share (RD-SH-01…05, 15-round-pdf §5)

    /// Makes the PDF from the round as shown and opens the share sheet; on failure, shows the alert and
    /// shares nothing (RP-EX-07). Ignored while a share is already under way.
    func share() async {
        guard shareState == .idle, let snapshot else { return }
        shareState = .preparing(showsProgress: false)
        let progress = Task { [progressDelay] in
            try? await Task.sleep(for: progressDelay)
            guard !Task.isCancelled, shareState == .preparing(showsProgress: false) else { return }
            shareState = .preparing(showsProgress: true)
        }
        defer { progress.cancel() }
        do {
            let url = try await exporter.export(round: snapshot.round, players: snapshot.players, course: snapshot.course)
            guard isOnScreen else {
                // No sheet can show it, so nothing would remove it (RP-EX-03).
                exporter.cleanUp(url)
                shareState = .idle
                return
            }
            shareState = .presenting(SharedPDF(url: url))
        } catch {
            log.error("Round detail couldn't make the PDF: \(String(describing: error), privacy: .public)")
            shareState = .idle
            shareFailed = true
        }
    }

    /// The PDF the share sheet is showing.
    var sharedPDF: SharedPDF? {
        if case .presenting(let pdf) = shareState { return pdf }
        return nil
    }

    /// Round detail appeared or went away (a pop, or a push on top of it).
    func setOnScreen(_ visible: Bool) { isOnScreen = visible }

    /// The share sheet closed: removes the PDF's temp folder (RP-EX-03).
    func finishSharing() {
        if let sharedPDF { exporter.cleanUp(sharedPDF.url) }
        shareState = .idle
    }

    /// A player's photo for an avatar, decoded once.
    func avatar(_ player: RoundDetailContent.PlayerResult) -> UIImage? { avatars.image(for: player.playerID, photo: player.photoData) }

    /// The avatars in the scorecard's header.
    func avatar(_ column: ScorecardModel.Column) -> UIImage? { avatars.image(for: column.playerID, photo: column.photoData) }

    /// "Home" when Round detail sits right on Home, else "Rounds" (RD-TOP-01).
    static func backTitle(path: [Destination]) -> String {
        path.count <= 1
            ? String(localized: "Home", comment: "Round detail: the back button's title when it came from Home.")
            : String(localized: "Rounds", comment: "Round detail: the back button's title when it came from a list of rounds.")
    }

}
