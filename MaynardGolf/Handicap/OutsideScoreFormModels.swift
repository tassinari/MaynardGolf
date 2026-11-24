//
//  OutsideScoreFormModels.swift
//  MaynardGolf
//

import Foundation
import Observation
import OSLog

/// Add score (19-handicap-screen §3, #253): posts a score a player shot at an outside course. Scores from
/// Maynard come from rounds, so only outside courses are offered (HS-AS-05). Validation is
/// `OutsideScoreRules` (DM-OS-02, 04); a failed save keeps the values and offers Try again.
@MainActor
@Observable
final class AddOutsideScoreViewModel {
    let playerID: UUID
    /// The score as typed (HS-AS-03).
    var scoreText = ""
    /// The day played: today by default, never later (HS-AS-03).
    var playedOn: Date
    /// 18 by default (HS-AS-03).
    var holeCount: HoleCount = .eighteen
    /// The chosen course; the newest added by default, and a course added from Add course once it's back.
    var courseID: UUID?
    /// The outside courses, A–Z.
    private(set) var courses: [OutsideCourseSnapshot] = []
    /// A failed save, shown with Try again (which saves again).
    private(set) var saveError: String?
    /// A failed read of the courses, shown in the course card with Try again (which reads again) instead of
    /// "Add a course first"; cleared by the next read that succeeds (HS-AS-05).
    private(set) var loadError: String?
    /// True once saved: the screen goes back to Handicap.
    private(set) var didSave = false

    @ObservationIgnored private var knownCourses: Set<UUID>?
    @ObservationIgnored private let players: PlayerRepository
    @ObservationIgnored private let outsideScores: OutsideScoreRepository
    @ObservationIgnored private let clock: AppClock
    /// The home course's name, from the course data (X-16), for the intro.
    @ObservationIgnored private let homeCourseName: String?
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "Handicap")

    init(playerID: UUID, players: PlayerRepository, outsideScores: OutsideScoreRepository, clock: AppClock, homeCourseName: String?) {
        self.playerID = playerID
        self.players = players
        self.outsideScores = outsideScores
        self.clock = clock
        self.homeCourseName = homeCourseName
        playedOn = clock.now
    }

    convenience init(playerID: UUID, dependencies: AppDependencies) {
        self.init(playerID: playerID, players: dependencies.players, outsideScores: dependencies.outsideScores, clock: dependencies.clock,
                  homeCourseName: try? dependencies.course().name)
    }

    /// "Scores from Maynard Golf Club are added automatically." (HS-AS-02), or nil without course data.
    var homeCourseNote: String? {
        homeCourseName.map {
            String(localized: "Scores from \($0) are added automatically.",
                   comment: "Add score: the intro's second line; rounds at the home course (its name) count without being added here.")
        }
    }

    /// The latest day the date picker allows (DM-OS-04).
    var latestDate: Date { clock.now }

    /// The gross as a number, or nil while it isn't one.
    var gross: Int? { Int(scoreText.trimmingCharacters(in: .whitespaces)) }

    /// "Enter a score from 40 to 200." once something that isn't a valid score is typed (DM-OS-02).
    var scoreError: String? {
        guard !scoreText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let range = OutsideScoreRules.grossRange(for: holeCount)
        guard let gross, range.contains(gross) else {
            return String(localized: "Enter a score from \(range.lowerBound) to \(range.upperBound).",
                          comment: "Add score: the score isn't valid for the holes played, e.g. 'Enter a score from 40 to 200.'")
        }
        return nil
    }

    /// No outside course yet: the course menu says to add one first (HS-AS-05). Not while the read is failing.
    var hasNoCourses: Bool { courses.isEmpty && loadError == nil }

    /// Save score is enabled with a valid score and a course (HS-AS-06).
    var canSave: Bool {
        guard let gross, courseID != nil else { return false }
        return OutsideScoreRules.grossRange(for: holeCount).contains(gross)
    }

    /// The chosen course's name, for the menu's label.
    var courseName: String? { courses.first { $0.id == courseID }?.name }

    /// Reads the courses; also the course card's Try again. A course that appeared since the last read (one
    /// just made in Add course) is selected; otherwise the choice stays, or falls to the newest course.
    func loadCourses() {
        do {
            courses = try outsideScores.courses().map(OutsideCourseSnapshot.init)
            let ids = Set(courses.map(\.id))
            if let known = knownCourses, let added = courses.filter({ !known.contains($0.id) }).max(by: { $0.createdAt < $1.createdAt }) {
                courseID = added.id
            } else if courseID == nil || !ids.contains(courseID!) {
                courseID = courses.max { $0.createdAt < $1.createdAt }?.id
            }
            knownCourses = ids
            loadError = nil
        } catch {
            log.error("Add score couldn't read courses: \(String(describing: error), privacy: .public)")
            loadError = String(localized: "The courses couldn't be loaded.", comment: "Add score: reading the outside courses failed.")
        }
    }

    /// Reads the courses, then again on every store change (a course added from Add course).
    func observe() async {
        loadCourses()
        for await _ in outsideScores.changes() { loadCourses() }
    }

    /// Saves the score; also Try again.
    func save() {
        guard canSave, let gross, let courseID else { return }
        do {
            guard let player = try players.allPlayers().first(where: { $0.id == playerID }),
                  let course = try outsideScores.courses().first(where: { $0.id == courseID }) else {
                saveError = Self.saveFailed
                return
            }
            try outsideScores.addScore(for: player, course: course, gross: gross, holeCount: holeCount, playedOn: playedOn)
            saveError = nil
            didSave = true
        } catch let error as OutsideScoreError {
            saveError = error == .futureDate
                ? String(localized: "The date can't be in the future.", comment: "Add score: the day played is after today.")
                : Self.saveFailed
        } catch {
            log.error("Couldn't save an outside score: \(String(describing: error), privacy: .public)")
            saveError = Self.saveFailed
        }
    }

    private static var saveFailed: String {
        String(localized: "Your score couldn't be saved.", comment: "Add score: saving failed; Try again is offered.")
    }
}

/// Add course (19-handicap-screen §4, #253): a course other than Maynard with its rating and slope
/// (DM-OC-02…05). The rating accepts a dot or a comma; errors show under their field.
@MainActor
@Observable
final class AddOutsideCourseViewModel {
    var name = ""
    /// The 18-hole rating as typed, e.g. "71.2" or "71,2".
    var ratingText = ""
    var slopeText = ""
    /// Set when the save found the name taken (DM-OC-03).
    private(set) var nameError: String?
    /// A failed save, shown with Try again.
    private(set) var saveError: String?
    /// True once saved: the screen goes back to Add score, which selects the new course.
    private(set) var didSave = false

    @ObservationIgnored private let outsideScores: OutsideScoreRepository
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "Handicap")

    init(outsideScores: OutsideScoreRepository) {
        self.outsideScores = outsideScores
    }

    /// The rating as a number with at most one decimal, after a dot or a comma; nil otherwise.
    var rating: Double? {
        let text = ratingText.trimmingCharacters(in: .whitespaces)
        guard text.wholeMatch(of: /\d{2}([.,]\d)?/) != nil else { return nil }
        return Double(text.replacingOccurrences(of: ",", with: "."))
    }

    var slope: Int? { Int(slopeText.trimmingCharacters(in: .whitespaces)) }

    /// "Enter a rating from 50.0 to 85.0." once something invalid is typed (DM-OC-04).
    var ratingError: String? {
        guard !ratingText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        if let rating, (try? OutsideScoreRules.courseRating(rating)) != nil { return nil }
        return String(localized: "Enter a rating from 50.0 to 85.0.", comment: "Add course: the course rating isn't valid.")
    }

    /// "Enter a slope from 55 to 155." once something invalid is typed (DM-OC-05).
    var slopeError: String? {
        guard !slopeText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        if let slope, OutsideScoreRules.slopeRange.contains(slope) { return nil }
        return String(localized: "Enter a slope from 55 to 155.", comment: "Add course: the slope rating isn't valid.")
    }

    /// Save course is enabled with a name, a valid rating and a valid slope (HS-AC-03).
    var canSave: Bool {
        guard (try? OutsideScoreRules.courseName(name)) != nil, let rating, let slope else { return false }
        return (try? OutsideScoreRules.courseRating(rating)) != nil && OutsideScoreRules.slopeRange.contains(slope)
    }

    /// A new name clears the duplicate error.
    func nameChanged() { nameError = nil }

    /// Saves the course; also Try again.
    func save() {
        guard canSave, let rating, let slope else { return }
        do {
            try outsideScores.addCourse(name: name, courseRating: rating, slope: slope)
            saveError = nil
            didSave = true
        } catch OutsideScoreError.duplicateCourseName {
            nameError = String(localized: "A course with this name already exists.", comment: "Add course: another outside course has this name.")
        } catch {
            log.error("Couldn't save an outside course: \(String(describing: error), privacy: .public)")
            saveError = String(localized: "The course couldn't be saved.", comment: "Add course: saving failed; Try again is offered.")
        }
    }
}
