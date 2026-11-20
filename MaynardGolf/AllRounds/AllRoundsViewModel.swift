import Foundation
import Observation
import OSLog
import UIKit

/// Searchable history of every round (HOME-AR-01…10). Records are snapshots; all persistence stays in
/// the injected repository. Grouping reuses the Player card's pure `RoundMonthGrouping`.
@MainActor
@Observable
final class AllRoundsViewModel {
    /// Search metadata that isn't shown on the compact row, including players' last names (HOME-AR-02).
    struct Record: Equatable, Sendable {
        let round: RoundSummary
        let courseName: String
        let playerNames: [String]
    }

    /// The confirmed id is carried by the alert, rather than read from state after dismissal (HOME-AR-07).
    struct DeleteRequest: Identifiable, Equatable {
        let id: UUID
        let message: String
    }

    var query = "" { didSet { applyFilter() } }
    private(set) var sections: [RoundMonthSection] = []
    /// Cached image values shared with rows; search never decodes photos or stores row closures.
    private(set) var photos: [UUID: UIImage] = [:]
    private(set) var shownCount = 0
    private(set) var hasLoaded = false
    private(set) var loadError: String?
    var deleteRequest: DeleteRequest?
    var deleteError: String?
    private var records: [Record] = []
    @ObservationIgnored private var byID: [UUID: Record] = [:]
    @ObservationIgnored private let rounds: RoundRepository
    @ObservationIgnored private let courses: CourseProvider
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let avatars = AvatarCache()
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "AllRounds")
    static let pageSize = 200

    init(rounds: RoundRepository, courses: CourseProvider, calendar: Calendar = .current, locale: Locale = .current) {
        self.rounds = rounds
        self.courses = courses
        self.calendar = calendar
        self.locale = locale
    }

    convenience init(dependencies: AppDependencies) {
        self.init(rounds: dependencies.rounds, courses: dependencies.courses)
    }

    var countLabel: String { Plurals.rounds(shownCount).uppercased(with: locale) }
    var hasNoRounds: Bool { hasLoaded && records.isEmpty && loadError == nil }
    var hasNoMatches: Bool { !records.isEmpty && shownCount == 0 }

    /// Names and course match loosely, including a full name; whitespace alone keeps everyone.
    nonisolated static func filter(_ records: [Record], query: String) -> [Record] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? records : records.filter { record in
            ([record.courseName] + record.playerNames).contains { $0.localizedStandardContains(query) }
        }
    }

    private func applyFilter() {
        let matching = Self.filter(records, query: query)
        shownCount = matching.count
        sections = RoundMonthGrouping.sections(matching.map(\.round), calendar: calendar, locale: locale)
    }

    func courseName(for id: UUID) -> String { byID[id]?.courseName ?? "" }

    /// Completed rows open detail; unfinished rows resume the round (HOME-AR-06).
    func destination(for round: RoundSummary) -> Destination {
        round.isComplete ? .roundDetail(round.id) : .holePlay(round.id)
    }

    /// Reads all pages before filtering, so search and count never exclude older rounds. A failed read
    /// retains the prior records and displays Retry rather than pretending the store is empty.
    func load() {
        do {
            var canonical: [UUID: Round] = [:]
            var offset = 0
            while true {
                let page = try rounds.allRounds(offset: offset, limit: Self.pageSize)
                for round in page {
                    // A repeated logical id must resolve exactly like navigation, including timestamp ties.
                    if canonical[round.id] == nil { canonical[round.id] = round }
                    else { canonical[round.id] = try rounds.round(id: round.id) }
                }
                offset += page.count
                if page.count < Self.pageSize { break }
            }
            var cache: [String: Course] = [:]
            var result: [Record] = []
            var images: [UUID: UIImage] = [:]
            for model in canonical.values {
                let course: Course
                if let saved = cache[model.courseID] { course = saved }
                else { course = try courses.course(id: model.courseID); cache[model.courseID] = course }
                let players = model.sortedEntries.compactMap(\.player).map(PlayerSnapshot.init)
                for player in players {
                    if let image = avatars.image(for: player.id, photo: player.photoData) { images[player.id] = image }
                }
                result.append(Record(round: RoundSummaryBuilder.summary(of: RoundSnapshot(model), players: players, course: course),
                                     courseName: course.name, playerNames: players.map(\.fullName)))
            }
            records = result
            photos = images
            byID = Dictionary(uniqueKeysWithValues: result.map { ($0.round.id, $0) })
            hasLoaded = true
            loadError = nil
            applyFilter()
        } catch {
            log.error("All rounds couldn't be read: \(String(describing: error), privacy: .private)")
            loadError = String(localized: "Your rounds couldn't be loaded.", comment: "Home's error banner when the data can't be read.")
        }
    }

    /// Only round, entry and player changes can affect these rows; skip empty or unrelated batches.
    func observe() async {
        load()
        for await changes in rounds.changes() {
            if !changes.only(Round.self).isEmpty || !changes.only(RoundEntry.self).isEmpty || !changes.only(Player.self).isEmpty {
                load()
            }
        }
    }

    func requestDelete(_ round: RoundSummary) {
        deleteRequest = DeleteRequest(id: round.id,
            message: String(localized: "Scores for all \(round.players.count) players will be removed.",
                            comment: "All rounds: confirms deleting every player's scores for this round."))
    }

    /// Uses the id captured in the alert even if dismissal already cleared `deleteRequest`.
    func confirmDelete(id: UUID) {
        deleteRequest = nil
        do {
            if let round = try rounds.round(id: id) { try rounds.delete(round) }
            deleteError = nil
            load()
        } catch {
            log.error("Round couldn't be deleted: \(String(describing: error), privacy: .private)")
            deleteError = String(localized: "The round couldn't be deleted. Try again.", comment: "All rounds: a delete failed; nothing was removed.")
        }
    }
}
