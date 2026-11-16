//
//  NewRoundViewModel.swift
//  MaynardGolf
//

import Foundation
import MaynardUI
import Observation
import OSLog
import UIKit

/// New round's state (04-new-round): the hole count, the tee and up to four players, the live "Tee off ·
/// Blue · 18 holes" label, and teeing off, which saves the round with the weather when it can get it.
/// Nothing is saved before Tee off, so Cancel just closes (NR-NAV-01).
@MainActor
@Observable
final class NewRoundViewModel {
    /// One tee card (NR-TEE-03, 06): its name, the yards for the round's holes and the rating / slope.
    struct TeeOption: Identifiable, Equatable, Sendable {
        let id: Tee
        let name: String
        /// "3,013 yds", always yards (NR-TEE-03).
        let yards: String
        /// "Rating / slope 34.1 / 123": half the 18-hole rating for 9 holes (NR-TEE-06).
        let ratingAndSlope: String
    }

    /// One row of the players list (NR-PLY-02).
    struct PlayerOption: Identifiable, Equatable, Sendable {
        let id: UUID
        let firstName: String
        let color: PlayerColor
        let photoData: Data?
    }

    /// The most players in a round (NR-PLY-03).
    static let maximumPlayers = 4

    /// 9 or 18 (NR-HOL-01, 02).
    var holeCount: HoleCount
    /// The selected tee (NR-TEE-04, 05).
    var tee: Tee
    /// Every player in NR-PLY-05's order.
    private(set) var players: [PlayerOption] = []
    /// The selected players, in the order they were picked: the round's card order (NR-CTA-03).
    private(set) var selection: [UUID] = []
    /// The course's tees, or empty when the course can't be read.
    private(set) var courseTees: [TeeInfo] = []
    /// True while Tee off is saving, so a second tap does nothing.
    private(set) var isTeeingOff = false
    /// A read failure, shown in place of the lists.
    private(set) var loadError: String?
    /// A save failure, shown as an alert; the screen stays open (NR-CTA-05).
    var saveError: String?

    @ObservationIgnored private let playerRepository: PlayerRepository
    @ObservationIgnored private let rounds: RoundRepository
    @ObservationIgnored private let courses: CourseProvider
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let weather: WeatherProviding
    @ObservationIgnored private let handicaps: HandicapManager
    @ObservationIgnored private let courseID: String
    /// How long Tee off waits for the weather before saving without it (NR-CTA-04).
    @ObservationIgnored private let weatherTimeout: Duration
    @ObservationIgnored private var course: Course?
    /// The players already listed when Add player opened, so the one it creates can be selected
    /// (NR-PLY-06). Nil when Add player isn't open.
    @ObservationIgnored private var knownBeforeAdding: Set<UUID>?
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "NewRound")
    @ObservationIgnored private let avatars = AvatarCache()

    init(players: PlayerRepository, rounds: RoundRepository, courses: CourseProvider, settings: SettingsStore,
         weather: WeatherProviding, handicaps: HandicapManager, courseID: String = AppDependencies.courseID,
         weatherTimeout: Duration = .seconds(4)) {
        self.playerRepository = players
        self.rounds = rounds
        self.courses = courses
        self.settings = settings
        self.weather = weather
        self.handicaps = handicaps
        self.courseID = courseID
        self.weatherTimeout = weatherTimeout
        holeCount = settings.lastHoleCount
        tee = settings.defaultTee
    }

    /// The app's repositories and services.
    convenience init(dependencies: AppDependencies) {
        self.init(players: dependencies.players, rounds: dependencies.rounds, courses: dependencies.courses,
                  settings: dependencies.settings, weather: dependencies.weather, handicaps: dependencies.handicaps)
    }

    // MARK: Display values

    /// One card per tee on the course, for the chosen hole count (NR-TEE-02, NR-HOL-05).
    var tees: [TeeOption] {
        guard let course else { return [] }
        return courseTees.map { info in
            let yards = RoundHoleBuilder.yards(course: course, holeCount: holeCount, tee: info.id)
            let rating = info.rating(for: holeCount).formatted(.number.precision(.fractionLength(1)))
            return TeeOption(id: info.id, name: info.localizedName,
                             yards: String(localized: "\(yards.formatted(.number.grouping(.automatic))) yds",
                                           comment: "Tee card: total yardage for the round, e.g. '3,013 yds'."),
                             ratingAndSlope: String(localized: "Rating / slope \(rating) / \(info.slope)",
                                                    comment: "Tee card: course rating and slope, e.g. 'Rating / slope 34.1 / 123'."))
        }
    }

    /// "Tee off · Blue · 18 holes" (NR-HOL-06, NR-CTA-01).
    var teeOffTitle: String {
        let name = course?.tee(tee)?.localizedName ?? tee.localizedName
        return String(localized: "Tee off · \(name) · \(holeCount.rawValue) holes",
                      comment: "New round button: the tee and the hole count, e.g. 'Tee off · Blue · 18 holes'.")
    }

    /// Tee off needs a player and the course (NR-CTA-02).
    var canTeeOff: Bool { !selection.isEmpty && course != nil && !isTeeingOff }

    /// Four players are picked; the other rows dim and ignore taps (NR-PLY-03).
    var isFull: Bool { selection.count >= Self.maximumPlayers }

    func isSelected(_ id: UUID) -> Bool { selection.contains(id) }

    /// A row can be tapped unless four others are already picked (NR-PLY-03).
    func canToggle(_ id: UUID) -> Bool { isSelected(id) || !isFull }

    /// A player's photo for the row's avatar, decoded once (`AvatarCache`).
    func avatar(for player: PlayerOption) -> UIImage? { avatars.image(for: player.id, photo: player.photoData) }

    /// The handicap from the manager, the only source (HC-MG-01).
    func handicap(for id: UUID) -> PlayerHandicap { handicaps.handicap(for: id) }

    /// "HCP 8.4", or "HCP —" without an index (NR-PLY-02).
    func handicapCaption(for id: UUID) -> String {
        String(localized: "HCP \(handicap(for: id).displayText())", comment: "New round player row: the handicap index, e.g. 'HCP 8.4'.")
    }

    // MARK: Actions

    /// Selects or clears a player; a fifth is refused (NR-PLY-03).
    func toggle(_ id: UUID) {
        if let index = selection.firstIndex(of: id) {
            selection.remove(at: index)
        } else if !isFull, players.contains(where: { $0.id == id }) {
            selection.append(id)
        }
    }

    /// Reads the course and the players. The first read also selects the last round's players
    /// (NR-PLY-04); later reads (after Add player) keep the selection and pick up a new player
    /// (NR-PLY-06).
    func load() {
        do {
            let course = try courses.course(id: courseID)
            let models = try playerRepository.recentPlayers(limit: nil)
            var seen = Set<UUID>() // ids aren't unique-constrained (DM-PL-01): keep the first record
            let unique = models.filter { seen.insert($0.id).inserted }
            let isFirstLoad = self.course == nil
            self.course = course
            courseTees = course.tees
            if course.tee(tee) == nil, let first = course.tees.first { tee = first.id } // NR-TEE-05's fallback
            players = Self.ordered(unique).map {
                PlayerOption(id: $0.id, firstName: $0.firstName, color: $0.color, photoData: $0.photoData)
            }
            let ids = Set(players.map(\.id))
            selection.removeAll { !ids.contains($0) } // a deleted player drops out
            if isFirstLoad {
                let last = try rounds.allRounds(offset: 0, limit: 1).first
                let group = last?.sortedEntries.compactMap { $0.player?.id }.filter(ids.contains) ?? []
                selection = Array(group.prefix(Self.maximumPlayers))
            }
            if let known = knownBeforeAdding {
                for added in players.map(\.id) where !known.contains(added) && !isFull && !isSelected(added) {
                    selection.append(added)
                }
                knownBeforeAdding = ids
            }
            loadError = nil
        } catch {
            log.error("New round couldn't read its data: \(String(describing: error), privacy: .public)")
            loadError = String(localized: "The players couldn't be loaded.", comment: "New round: shown when the players or course can't be read.")
        }
    }

    /// Loads, then again on every store change while the screen is open.
    func observe() async {
        load()
        for await _ in playerRepository.changes() { load() }
    }

    /// Call when Add player opens, so the player it creates is selected on the next load (NR-PLY-06).
    func beginAddingPlayer() {
        knownBeforeAdding = Set(players.map(\.id))
    }

    /// Call when Add player closes.
    func endAddingPlayer() {
        load()
        knownBeforeAdding = nil
    }

    /// Creates the round with the weather if it comes in time, saves it and remembers the hole count
    /// (NR-CTA-03, 04, NR-HOL-02). Returns the round's id for Hole play, or nil with `saveError` set.
    func teeOff() async -> UUID? {
        guard canTeeOff, let course else { return nil }
        isTeeingOff = true
        defer { isTeeingOff = false }
        let snapshot = await Self.weather(from: weather, at: course.coordinate, timeout: weatherTimeout, log: log)
        do {
            let all = try playerRepository.allPlayers()
            let chosen = selection.compactMap { id in all.first { $0.id == id } }
            guard chosen.count == selection.count else { throw MissingPlayer() }
            let round = try rounds.create(players: chosen, holeCount: holeCount, tee: tee, weather: snapshot)
            settings.lastHoleCount = holeCount
            return round.id
        } catch {
            log.error("New round couldn't be saved: \(String(describing: error), privacy: .public)")
            saveError = String(localized: "The round couldn't be started. Try again.", comment: "New round: alert when saving the round fails.")
            return nil
        }
    }

    // MARK: Pure helpers

    /// A selected player was deleted before Tee off.
    struct MissingPlayer: Error {}

    /// NR-PLY-05: the repository's most-recently-played order for players with a round, then everyone
    /// else alphabetically by first name, then full name, ignoring case and accents.
    static func ordered(_ players: [Player]) -> [Player] {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let hasPlayed: (Player) -> Bool = { $0.entries?.isEmpty == false }
        let played = players.filter(hasPlayed)
        let rest = players.filter { !hasPlayed($0) }.sorted { lhs, rhs in
            let order = lhs.firstName.compare(rhs.firstName, options: options)
            return order == .orderedSame ? lhs.fullName.compare(rhs.fullName, options: options) == .orderedAscending
                : order == .orderedAscending
        }
        return played + rest
    }

    /// The current weather, or nil when it fails or takes longer than `timeout`: the round is saved
    /// without it (NR-CTA-04).
    static func weather(from service: WeatherProviding, at coordinate: Coordinate, timeout: Duration,
                        log: Logger) async -> WeatherSnapshot? {
        await withTaskGroup(of: WeatherSnapshot?.self) { group in
            group.addTask {
                do { return try await service.currentWeather(at: coordinate) } catch {
                    log.notice("Weather unavailable at tee off: \(String(describing: error), privacy: .public)")
                    return nil
                }
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            // The first task to finish wins; `next()` is never nil here, as two tasks were added.
            let first = await group.next()
            group.cancelAll()
            return first.flatMap(\.self)
        }
    }
}
