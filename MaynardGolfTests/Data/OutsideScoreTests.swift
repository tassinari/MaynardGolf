//
//  OutsideScoreTests.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
import Testing
@testable import MaynardGolf

/// DM-TS-70…76 (#252): outside courses and scores, their rules, snapshots and repository, one in-memory
/// container per test.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct OutsideScoreTests {
    private let context: ModelContext
    private let tracker: ModelChangeTracker
    private let repository: SwiftDataOutsideScoreRepository
    private let clock = FixedClock(now: TestDates.teeOff)
    private let calendar: Calendar = {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        return utc
    }()

    init() throws {
        context = try makeInMemoryContext()
        tracker = ModelChangeTracker(context: context)
        repository = SwiftDataOutsideScoreRepository(context: context, tracker: tracker, clock: clock, calendar: calendar)
    }

    // MARK: Rules (DM-TS-70)

    @Test(arguments: [("Cedar Ridge", "Cedar Ridge"), ("  Heron Bay \n", "Heron Bay"), (String(repeating: "a", count: 60), String(repeating: "a", count: 60))])
    func namesAreTrimmed(_ name: String, _ expected: String) throws {
        #expect(try OutsideScoreRules.courseName(name) == expected)
    }

    @Test(arguments: ["", "   ", String(repeating: "a", count: 61)])
    func badNamesAreRefused(_ name: String) {
        #expect(throws: OutsideScoreError.invalidCourseName) { try OutsideScoreRules.courseName(name) }
    }

    @Test func sameNameIgnoresCaseAndSpaces() {
        #expect(OutsideScoreRules.sameName("Cedar Ridge", " cedar RIDGE "))
        #expect(!OutsideScoreRules.sameName("Cedar Ridge", "Cedar Ridge GC"))
    }

    @Test(arguments: [(50.0, 50.0), (71.2, 71.2), (85.0, 85.0), (69.80000000001, 69.8)])
    func ratingsInRangeKeepOneDecimal(_ rating: Double, _ expected: Double) throws {
        #expect(try OutsideScoreRules.courseRating(rating) == expected)
    }

    @Test(arguments: [49.9, 85.1, 71.25, Double.nan, Double.infinity])
    func ratingsOutOfRangeAreRefused(_ rating: Double) {
        #expect(throws: OutsideScoreError.ratingOutOfRange) { try OutsideScoreRules.courseRating(rating) }
    }

    @Test func slopeBoundaries() throws {
        #expect(try OutsideScoreRules.slope(55) == 55)
        #expect(try OutsideScoreRules.slope(155) == 155)
        #expect(throws: OutsideScoreError.slopeOutOfRange) { try OutsideScoreRules.slope(54) }
        #expect(throws: OutsideScoreError.slopeOutOfRange) { try OutsideScoreRules.slope(156) }
    }

    @Test(arguments: [(HoleCount.eighteen, 40, 200), (.nine, 20, 100)])
    func grossBoundariesPerHoleCount(_ holeCount: HoleCount, _ low: Int, _ high: Int) throws {
        #expect(OutsideScoreRules.grossRange(for: holeCount) == low...high)
        #expect(try OutsideScoreRules.gross(low, holeCount: holeCount) == low)
        #expect(try OutsideScoreRules.gross(high, holeCount: holeCount) == high)
        #expect(throws: OutsideScoreError.grossOutOfRange(low - 1)) { try OutsideScoreRules.gross(low - 1, holeCount: holeCount) }
        #expect(throws: OutsideScoreError.grossOutOfRange(high + 1)) { try OutsideScoreRules.gross(high + 1, holeCount: holeCount) }
    }

    @Test func playedOnIsANonFutureDay() throws {
        let now = TestDates.teeOff // 1 June 2026, 15:00 UTC
        let lateToday = now.addingTimeInterval(8 * 3600) // 23:00, still today
        #expect(try OutsideScoreRules.playedOn(lateToday, now: now, calendar: calendar) == noonUTC(2026, 6, 1))
        let lastWeek = now.addingTimeInterval(-7 * 86_400)
        #expect(try OutsideScoreRules.playedOn(lastWeek, now: now, calendar: calendar) == noonUTC(2026, 5, 25))
        #expect(throws: OutsideScoreError.futureDate) {
            try OutsideScoreRules.playedOn(now.addingTimeInterval(9 * 3600), now: now, calendar: calendar) // tomorrow 00:00
        }
    }

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    /// DM-OS-04: a day is stored as noon UTC on the date the user's calendar shows, so it reads back as the same
    /// date in any time zone, including the far ends (UTC−11 and UTC+14), not as the day before to the west.
    @Test(arguments: ["Pacific/Pago_Pago", "America/Los_Angeles", "Europe/London", "Asia/Tokyo", "Pacific/Auckland"])
    func aStoredDayIsTheSameDateEverywhere(_ zone: String) throws {
        let saved = calendar(zone)
        // Late evening of 1 June where it's saved.
        let evening = try #require(saved.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 22, minute: 30)))
        let day = OutsideScoreRules.storedDay(evening, calendar: saved)
        #expect(day == noonUTC(2026, 6, 1))
        for reader in ["Pacific/Pago_Pago", "America/New_York", "Pacific/Kiritimati"] {
            let shown = OutsideScoreRules.dayCalendar(from: calendar(reader)).dateComponents([.year, .month, .day], from: day)
            #expect(shown.year == 2026 && shown.month == 6 && shown.day == 1, "saved in \(zone), read in \(reader)")
        }
    }

    /// The user's calendar system is kept; only the time zone is fixed to UTC.
    @Test func theDayCalendarKeepsTheCalendarSystem() {
        let day = OutsideScoreRules.dayCalendar(from: Calendar(identifier: .buddhist))
        #expect(day.identifier == .buddhist && day.timeZone == .gmt)
        #expect(day.component(.year, from: noonUTC(2026, 6, 1)) == 2569)
    }

    /// "Today" is the user's: just after midnight in Auckland on 2 June is still allowed, though it's 1 June in UTC.
    @Test func todayIsTheUsersToday() throws {
        let auckland = calendar("Pacific/Auckland")
        let now = try #require(auckland.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 0, minute: 30)))
        #expect(try OutsideScoreRules.playedOn(now, now: now, calendar: auckland) == noonUTC(2026, 6, 2))
    }

    // MARK: Models and snapshots (DM-TS-71)

    @Test func defaultsAndHoleCountFallback() throws {
        let course = OutsideCourse(name: "Cedar Ridge", courseRating: 71.2, slope: 128)
        let score = OutsideScore(gross: 84, holeCount: .eighteen, playedOn: TestDates.teeOff, course: course)
        #expect(score.holeCount == .eighteen)
        score.holeCountRaw = 27
        #expect(score.holeCount == .nine) // DM-EN-05
        #expect(score.courseName == "Cedar Ridge" && score.courseRating == 71.2 && score.slope == 128)
    }

    @Test func snapshotsCopyEveryField() throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let course = try repository.addCourse(name: "Cedar Ridge", courseRating: 71.2, slope: 128)
        let score = try repository.addScore(for: mark, course: course, gross: 41, holeCount: .nine, playedOn: TestDates.teeOff)

        let courseSnapshot = OutsideCourseSnapshot(course)
        #expect(courseSnapshot.id == course.id && courseSnapshot.name == "Cedar Ridge")
        #expect(courseSnapshot.courseRating == 71.2 && courseSnapshot.slope == 128 && courseSnapshot.createdAt == TestDates.teeOff)

        let snapshot = OutsideScoreSnapshot(score)
        #expect(snapshot.id == score.id && snapshot.playerID == mark.id && snapshot.courseID == course.id)
        #expect(snapshot.courseName == "Cedar Ridge" && snapshot.courseRating == 71.2 && snapshot.slope == 128)
        #expect(snapshot.gross == 41 && snapshot.holeCount == .nine)
        #expect(snapshot.playedOn == noonUTC(2026, 6, 1) && snapshot.createdAt == TestDates.teeOff)
    }

    // MARK: Repository (DM-TS-72…75)

    @Test func addCourseValidatesAndStampsTheClock() throws {
        let course = try repository.addCourse(name: "  Heron Bay ", courseRating: 69.8, slope: 121)
        #expect(course.name == "Heron Bay" && course.createdAt == TestDates.teeOff)
        #expect(throws: OutsideScoreError.invalidCourseName) { try repository.addCourse(name: " ", courseRating: 70, slope: 113) }
        #expect(throws: OutsideScoreError.ratingOutOfRange) { try repository.addCourse(name: "A", courseRating: 90, slope: 113) }
        #expect(throws: OutsideScoreError.slopeOutOfRange) { try repository.addCourse(name: "A", courseRating: 70, slope: 200) }
        #expect(try repository.courses().map(\.name) == ["Heron Bay"])
    }

    @Test func aDuplicateNameIsRefused() throws {
        try repository.addCourse(name: "Cedar Ridge", courseRating: 71.2, slope: 128)
        #expect(throws: OutsideScoreError.duplicateCourseName) {
            try repository.addCourse(name: " cedar ridge", courseRating: 70.0, slope: 120)
        }
        #expect(try repository.courses().count == 1)
    }

    @Test func coursesAreAlphabeticalThenOldestFirst() throws {
        for name in ["zebra Links", "Émerald", "apple Hill"] {
            try repository.addCourse(name: name, courseRating: 70, slope: 113)
        }
        // A synced duplicate name (DM-OC-03) keeps both, oldest first.
        ModelFixtures.outsideCourse("apple Hill", in: context, createdAt: ModelFixtures.daysAgo(10))
        try context.save()
        let courses = try repository.courses()
        #expect(courses.map(\.name) == ["apple Hill", "apple Hill", "Émerald", "zebra Links"])
        #expect(courses[0].createdAt < courses[1].createdAt)
    }

    @Test func addScoreValidatesCopiesTheCourseAndStoresTheDay() throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let course = try repository.addCourse(name: "Cedar Ridge", courseRating: 71.2, slope: 128)
        let score = try repository.addScore(for: mark, course: course, gross: 84, holeCount: .eighteen, playedOn: TestDates.teeOff)
        #expect(score.player?.id == mark.id && score.course?.id == course.id)
        #expect(score.playedOn == noonUTC(2026, 6, 1) && score.createdAt == TestDates.teeOff)
        #expect(throws: OutsideScoreError.grossOutOfRange(30)) {
            try repository.addScore(for: mark, course: course, gross: 30, holeCount: .eighteen, playedOn: TestDates.teeOff)
        }
        #expect(throws: OutsideScoreError.futureDate) {
            try repository.addScore(for: mark, course: course, gross: 84, holeCount: .eighteen, playedOn: TestDates.teeOff.addingTimeInterval(86_400))
        }
        #expect(try repository.scores(for: mark).count == 1)
    }

    /// DM-OS-06: a later course change or deletion never changes a posted score.
    @Test func copiedRatingSlopeAndNameSurviveTheCourse() throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let course = try repository.addCourse(name: "Cedar Ridge", courseRating: 71.2, slope: 128)
        let score = try repository.addScore(for: mark, course: course, gross: 84, holeCount: .eighteen, playedOn: TestDates.teeOff)
        course.courseRating = 73.0
        course.slope = 140
        course.name = "Cedar Ridge North"
        context.delete(course)
        try context.save()
        let stored = try #require(try repository.scores(for: mark).first)
        #expect(stored.id == score.id && stored.course == nil)
        #expect(stored.courseName == "Cedar Ridge" && stored.courseRating == 71.2 && stored.slope == 128)
    }

    @Test func scoresAreNewestPlayedFirstThenNewestAdded() throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let other = ModelFixtures.player("Other", in: context)
        let course = ModelFixtures.outsideCourse("Cedar Ridge", in: context)
        ModelFixtures.outsideScore(84, for: mark, at: course, playedOn: ModelFixtures.daysAgo(10), in: context)
        ModelFixtures.outsideScore(80, for: mark, at: course, playedOn: ModelFixtures.daysAgo(2, hour: -5), in: context)
        ModelFixtures.outsideScore(78, for: mark, at: course, playedOn: ModelFixtures.daysAgo(2, hour: -1), in: context)
        ModelFixtures.outsideScore(90, for: other, at: course, playedOn: ModelFixtures.daysAgo(1), in: context)
        try context.save()
        #expect(try repository.scores(for: mark).map(\.gross) == [78, 80, 84])
    }

    @Test func deletingAScoreIsPermanent() throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let course = try repository.addCourse(name: "Cedar Ridge", courseRating: 71.2, slope: 128)
        let score = try repository.addScore(for: mark, course: course, gross: 84, holeCount: .eighteen, playedOn: TestDates.teeOff)
        try repository.delete(score)
        #expect(try repository.scores(for: mark).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<OutsideScore>()) == 0)
        #expect(try repository.courses().count == 1)
        #expect(course.scores?.isEmpty == true)
    }

    /// DM-RL-06: deleting a player deletes their outside scores, and the course stays.
    @Test func deletingAPlayerDeletesTheirScores() throws {
        let players = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: clock)
        let mark = try players.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        let other = try players.create(firstName: "Other", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        let course = try repository.addCourse(name: "Cedar Ridge", courseRating: 71.2, slope: 128)
        try repository.addScore(for: mark, course: course, gross: 84, holeCount: .eighteen, playedOn: TestDates.teeOff)
        try repository.addScore(for: other, course: course, gross: 90, holeCount: .eighteen, playedOn: TestDates.teeOff)
        try players.delete(mark)
        #expect(try context.fetch(FetchDescriptor<OutsideScore>()).map(\.gross) == [90])
        #expect(try repository.courses().count == 1)
    }

    /// DM-RL-06: a player delete that fails to save rolls back with their outside scores intact. This is why
    /// `ModelDeletion` deletes the scores explicitly: rolling back a cascaded delete crashes SwiftData.
    @Test func aFailedPlayerDeleteKeepsTheirScores() throws {
        let players = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: clock)
        let mark = try players.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        let course = try repository.addCourse(name: "Cedar Ridge", courseRating: 71.2, slope: 128)
        let scores = try [84, 79].map {
            try repository.addScore(for: mark, course: course, gross: $0, holeCount: .eighteen, playedOn: TestDates.teeOff).id
        }
        let failing = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: clock, failSaves: true)
        #expect(throws: PersistenceError.self) { try failing.delete(mark) }

        let player = try #require(try players.allPlayers().first { $0.id == mark.id })
        #expect(Set(try repository.scores(for: player).map(\.id)) == Set(scores))
        #expect(try context.fetchCount(FetchDescriptor<OutsideScore>()) == 2)
        #expect(try repository.courses().map(\.name) == ["Cedar Ridge"])
        #expect(course.scores?.count == 2)
    }

    @Test func aFailedSaveRollsEverythingBack() throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let course = ModelFixtures.outsideCourse("Cedar Ridge", in: context)
        try context.save()
        let failing = SwiftDataOutsideScoreRepository(context: context, tracker: tracker, clock: clock, calendar: calendar, failSaves: true)
        #expect(throws: PersistenceError.self) { try failing.addCourse(name: "Heron Bay", courseRating: 69.8, slope: 121) }
        #expect(throws: PersistenceError.self) {
            try failing.addScore(for: mark, course: course, gross: 84, holeCount: .eighteen, playedOn: TestDates.teeOff)
        }
        #expect(try context.fetch(FetchDescriptor<OutsideCourse>()).map(\.name) == ["Cedar Ridge"])
        #expect(try context.fetchCount(FetchDescriptor<OutsideScore>()) == 0)
        #expect(mark.outsideScores?.isEmpty == true)

        let score = try repository.addScore(for: mark, course: course, gross: 84, holeCount: .eighteen, playedOn: TestDates.teeOff)
        #expect(throws: PersistenceError.self) { try failing.delete(score) }
        #expect(try repository.scores(for: mark).map(\.id) == [score.id])
    }

    /// DM-TS-76: saves and deletes reach observers through the shared change stream (DM-SC-09).
    @Test func changesArePublished() async throws {
        var changes = repository.changes().makeAsyncIterator()
        let mark = ModelFixtures.player("Mark", in: context)
        try context.save()
        _ = await changes.next()

        let course = try repository.addCourse(name: "Cedar Ridge", courseRating: 71.2, slope: 128)
        let added = try #require(await changes.next())
        #expect(added.only(OutsideCourse.self).inserted == [course.persistentModelID])

        let score = try repository.addScore(for: mark, course: course, gross: 84, holeCount: .eighteen, playedOn: TestDates.teeOff)
        let posted = try #require(await changes.next())
        #expect(posted.only(OutsideScore.self).inserted == [score.persistentModelID])

        let id = score.persistentModelID
        try repository.delete(score)
        let deleted = try #require(await changes.next())
        #expect(deleted.only(OutsideScore.self).deleted == [id])
    }

    /// The seed the Handicap screen's UI tests use (#252).
    @Test func theOutsideScoresFixture() throws {
        try Fixture.outsideScores.populate(context)
        let mark = try #require(try context.fetch(FetchDescriptor<Player>()).first)
        #expect(try repository.courses().map(\.name) == ["Cedar Ridge", "Heron Bay"])
        let scores = try repository.scores(for: mark)
        #expect(scores.map(\.gross) == [79, 81, 41, 84])
        #expect(scores.map(\.holeCount) == [.eighteen, .eighteen, .nine, .eighteen])
        #expect(try context.fetchCount(FetchDescriptor<Round>()) == 3)
    }
}
