//
//  HandicapScreenTests.swift
//  MaynardGolfTests
//

import Foundation
import Testing
@testable import MaynardGolf

/// HS-TS-01…05 (#253): the Handicap screen's explanation and the three screens' view models.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct HandicapScreenTests {
    private static let en = Locale(identifier: "en_US")

    private func breakdown(rows count: Int, counting: Int = 0, lowest: Int, adjustment: Double = 0, index: Double? = nil) -> HandicapBreakdown {
        let rows = (0..<count).map { offset in
            HandicapBreakdown.Row(id: UUID(), date: .distantPast, holeCount: .eighteen, gross: 80, tee: .blue, courseName: "Maynard Golf Club",
                                  isOutside: false, differential: 10, counts: offset < counting)
        }
        return HandicapBreakdown(rows: rows, index: index, lowest: lowest, adjustment: adjustment)
    }

    // MARK: HS-TS-01: the explanation (every WHS table row's wording)

    @Test(arguments: [
        (20, 8, 0.0, "Your index is the average of the 8 lowest differentials from your 20 most recent rounds. Rounds that count are highlighted below."),
        (12, 4, 0.0, "Your index is the average of the 4 lowest differentials from your 12 most recent rounds. Rounds that count are highlighted below."),
        (7, 2, 0.0, "Your index is the average of the 2 lowest differentials from your 7 most recent rounds. Rounds that count are highlighted below."),
        (6, 2, -1.0, "Your index is the average of the 2 lowest differentials from your 6 most recent rounds, minus 1.0. Rounds that count are highlighted below."),
        (5, 1, 0.0, "Your index is the lowest differential from your 5 most recent rounds. Rounds that count are highlighted below."),
        (4, 1, -1.0, "Your index is the lowest differential from your 4 most recent rounds, minus 1.0. Rounds that count are highlighted below."),
        (3, 1, -2.0, "Your index is the lowest differential from your 3 most recent rounds, minus 2.0. Rounds that count are highlighted below."),
    ])
    func theExplanationFollowsTheTable(rounds: Int, lowest: Int, adjustment: Double, expected: String) {
        let handicap = PlayerHandicap(index: 8.4, source: .calculated, roundsUsed: rounds)
        let text = HandicapExplanation.text(handicap: handicap, breakdown: breakdown(rows: rounds, lowest: lowest, adjustment: adjustment), locale: Self.en)
        #expect(text == expected)
    }

    /// The count's plural variants are in the String Catalog ("1 more score").
    @Test(arguments: [(0, "Post 3 more scores to get an index."), (1, "Post 2 more scores to get an index."), (2, "Post 1 more score to get an index.")])
    func tooFewRoundsSaysHowManyMore(rounds: Int, expected: String) {
        #expect(HandicapExplanation.text(handicap: .none, breakdown: breakdown(rows: rounds, lowest: 0), locale: Self.en) == expected)
    }

    @Test func aManualIndexSaysWhereItComesFrom() {
        let manual = PlayerHandicap(index: 5.0, source: .manual, roundsUsed: 3)
        #expect(HandicapExplanation.text(handicap: manual, breakdown: breakdown(rows: 3, lowest: 1, adjustment: -2, index: -2.1), locale: Self.en)
                == "Your index is entered by hand in Edit player. From these rounds it would be +2.1.")
        #expect(HandicapExplanation.text(handicap: manual, breakdown: breakdown(rows: 1, lowest: 0), locale: Self.en)
                == "Your index is entered by hand in Edit player.")
    }

    // MARK: HS-TS-02: the Handicap view model

    /// The seeded player: the manager's index, the rows newest first with Maynard and outside scores mixed.
    @Test func theScreenShowsTheManagersValues() async throws {
        let dependencies = AppDependencies.preview(.outsideScores)
        await dependencies.handicaps.refresh()
        let mark = try #require(try dependencies.players.allPlayers().first)
        let model = HandicapViewModel(playerID: mark.id, players: dependencies.players, outsideScores: dependencies.outsideScores,
                                      handicaps: dependencies.handicaps, locale: Self.en, calendar: Self.utc)
        model.load()
        #expect(model.profile?.fullName == "Mark Tassinari")
        #expect(model.handicapText == dependencies.handicaps.handicap(for: mark.id).displayText(locale: Self.en))
        #expect(model.handicapAccessibilityLabel.hasSuffix(", calculated"))
        #expect(model.listTitle == "Last 7 rounds")
        #expect(!model.isEmpty && model.rows.count == 7)
        #expect(model.rows.filter(\.counts).count == 2) // seven rounds: the lowest 2 (HC-CA-05)
        #expect(model.explanation.contains("the 2 lowest differentials from your 7 most recent rounds"))

        let outside = try #require(model.rows.first { $0.isOutside && $0.detail == "9 holes" })
        #expect(outside.courseName == "Heron Bay" && outside.gross == "41")
        let maynard = try #require(model.rows.first { !$0.isOutside })
        #expect(maynard.courseName == "Maynard Golf Club" && maynard.detail == "White · 9 holes")
        #expect(maynard.accessibilityLabel.hasPrefix("Score \(maynard.gross), Maynard Golf Club, "))
        let dates = model.rows.map(\.date)
        #expect(dates.allSatisfy { $0.contains("/2026") })
        #expect(model.avatar == nil)
    }

    @Test func listTitleAtTwentyAndEmpty() async throws {
        let dependencies = AppDependencies.preview(.fullHistory)
        await dependencies.handicaps.refresh()
        let mark = try #require(try dependencies.players.allPlayers().first { $0.firstName == "Mark" })
        #expect(HandicapViewModel(playerID: mark.id, dependencies: dependencies).listTitle == "Last 20 rounds")

        let empty = AppDependencies.preview(.noRound)
        await empty.handicaps.refresh()
        let tiger = try #require(try empty.players.allPlayers().first)
        let model = HandicapViewModel(playerID: tiger.id, dependencies: empty)
        #expect(model.isEmpty && model.rows.isEmpty && model.handicapText == "—")
    }

    /// HS-LS-06: only outside scores ask; confirming deletes it and the index follows.
    @Test func deletingAnOutsideScore() async throws {
        let dependencies = AppDependencies.preview(.outsideScores)
        await dependencies.handicaps.refresh()
        let mark = try #require(try dependencies.players.allPlayers().first)
        let model = HandicapViewModel(playerID: mark.id, dependencies: dependencies)
        let maynard = try #require(model.rows.first { !$0.isOutside })
        model.requestDelete(maynard)
        #expect(model.pendingDelete == nil)

        let outside = try #require(model.rows.first { $0.isOutside })
        model.requestDelete(outside)
        #expect(model.pendingDelete == outside.id)
        model.confirmDelete()
        #expect(model.pendingDelete == nil && model.errorText == nil)
        #expect(try dependencies.outsideScores.scores(for: mark).count == 3)
        await dependencies.handicaps.refresh()
        #expect(model.rows.count == 6 && !model.rows.contains { $0.id == outside.id })
        model.confirmDelete() // nothing pending: nothing happens
        #expect(try dependencies.outsideScores.scores(for: mark).count == 3)
    }

    @Test func aFailedDeleteSaysSo() async throws {
        let dependencies = AppDependencies.preview(.outsideScores)
        await dependencies.handicaps.refresh()
        let mark = try #require(try dependencies.players.allPlayers().first)
        let failing = SwiftDataOutsideScoreRepository(context: dependencies.container.mainContext, tracker: dependencies.tracker,
                                                      clock: dependencies.clock, failSaves: true)
        let model = HandicapViewModel(playerID: mark.id, players: dependencies.players, outsideScores: failing, handicaps: dependencies.handicaps)
        let outside = try #require(model.rows.first { $0.isOutside })
        model.requestDelete(outside)
        model.confirmDelete()
        #expect(model.errorText == "The score couldn't be deleted.")
        #expect(try dependencies.outsideScores.scores(for: mark).count == 4)
    }

    @Test func aMissingPlayerCloses() {
        let dependencies = AppDependencies.preview(.outsideScores)
        let model = HandicapViewModel(playerID: UUID(), dependencies: dependencies)
        model.load()
        #expect(model.isMissing && model.profile == nil)
    }

    // MARK: HS-TS-03: Add score

    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    @Test func addScoreDefaultsAndValidation() throws {
        let dependencies = AppDependencies.preview(.outsideScores)
        let mark = try #require(try dependencies.players.allPlayers().first)
        let model = AddOutsideScoreViewModel(playerID: mark.id, dependencies: dependencies)
        model.loadCourses()
        #expect(model.playedOn == dependencies.clock.now && model.latestDate == dependencies.clock.now)
        #expect(model.holeCount == .eighteen)
        #expect(model.courses.map(\.name) == ["Cedar Ridge", "Heron Bay"])
        #expect(model.courseName == "Heron Bay") // the newest added
        #expect(!model.hasNoCourses && !model.canSave && model.scoreError == nil)
        #expect(model.homeCourseNote == "Scores from Maynard Golf Club are added automatically.")

        model.scoreText = "30"
        #expect(model.scoreError == "Enter a score from 40 to 200." && !model.canSave)
        model.holeCount = .nine
        #expect(model.scoreError == nil && model.canSave)
        model.scoreText = "abc"
        #expect(model.gross == nil && model.scoreError == "Enter a score from 20 to 100." && !model.canSave)
        model.scoreText = " 84 "
        model.holeCount = .eighteen
        #expect(model.gross == 84 && model.canSave)
    }

    @Test func addScoreSaves() async throws {
        let dependencies = AppDependencies.preview(.outsideScores)
        let mark = try #require(try dependencies.players.allPlayers().first)
        let model = AddOutsideScoreViewModel(playerID: mark.id, dependencies: dependencies)
        model.loadCourses()
        model.save() // nothing typed: nothing happens
        #expect(!model.didSave)
        model.scoreText = "84"
        model.save()
        #expect(model.didSave && model.saveError == nil)
        let newest = try #require(try dependencies.outsideScores.scores(for: mark).first)
        #expect(newest.gross == 84 && newest.courseName == "Heron Bay" && newest.holeCount == .eighteen)
    }

    @Test func addScoreWithoutCoursesCantSave() throws {
        let dependencies = AppDependencies.preview(.onePlayer)
        let mark = try #require(try dependencies.players.allPlayers().first)
        let model = AddOutsideScoreViewModel(playerID: mark.id, dependencies: dependencies)
        model.loadCourses()
        model.scoreText = "84"
        #expect(model.hasNoCourses && model.courseID == nil && !model.canSave && model.courseName == nil)
    }

    /// A course made in Add course is chosen when Add score reads the courses again.
    @Test func aNewCourseIsSelected() throws {
        let dependencies = AppDependencies.preview(.outsideScores)
        let mark = try #require(try dependencies.players.allPlayers().first)
        let model = AddOutsideScoreViewModel(playerID: mark.id, dependencies: dependencies)
        model.loadCourses()
        model.courseID = model.courses.first { $0.name == "Cedar Ridge" }?.id
        model.loadCourses() // nothing new: the choice stays
        #expect(model.courseName == "Cedar Ridge")
        try dependencies.outsideScores.addCourse(name: "Apple Hill", courseRating: 70, slope: 120)
        model.loadCourses()
        #expect(model.courseName == "Apple Hill")
    }

    @Test func addScoreFailuresKeepTheValues() throws {
        let dependencies = AppDependencies.preview(.outsideScores)
        let mark = try #require(try dependencies.players.allPlayers().first)
        let failing = SwiftDataOutsideScoreRepository(context: dependencies.container.mainContext, tracker: dependencies.tracker,
                                                      clock: dependencies.clock, failSaves: true)
        let model = AddOutsideScoreViewModel(playerID: mark.id, players: dependencies.players, outsideScores: failing, clock: dependencies.clock,
                                             homeCourseName: nil)
        #expect(model.homeCourseNote == nil)
        model.loadCourses()
        model.scoreText = "84"
        model.save()
        #expect(!model.didSave && model.saveError == "Your score couldn't be saved." && model.scoreText == "84")

        model.playedOn = dependencies.clock.now.addingTimeInterval(3 * 86_400)
        let future = AddOutsideScoreViewModel(playerID: mark.id, dependencies: dependencies)
        future.loadCourses()
        future.scoreText = "84"
        future.playedOn = dependencies.clock.now.addingTimeInterval(3 * 86_400)
        future.save()
        #expect(future.saveError == "The date can't be in the future.")

        let gone = AddOutsideScoreViewModel(playerID: UUID(), dependencies: dependencies)
        gone.loadCourses()
        gone.scoreText = "84"
        gone.save()
        #expect(gone.saveError == "Your score couldn't be saved." && !gone.didSave)
    }

    // MARK: HS-TS-04: Add course

    @Test(arguments: [("71.2", 71.2), ("71,2", 71.2), ("70", 70.0), (" 69.8 ", 69.8)])
    func ratingsParseWithADotOrAComma(_ text: String, _ value: Double) {
        let model = AddOutsideCourseViewModel(outsideScores: AppDependencies.preview(.freshInstall).outsideScores)
        model.ratingText = text
        #expect(model.rating == value && model.ratingError == nil)
    }

    @Test func addCourseValidation() {
        let model = AddOutsideCourseViewModel(outsideScores: AppDependencies.preview(.freshInstall).outsideScores)
        #expect(!model.canSave && model.ratingError == nil && model.slopeError == nil)
        model.name = "Pine Hollow"
        model.ratingText = "99"
        model.slopeText = "20"
        #expect(model.ratingError == "Enter a rating from 50.0 to 85.0." && model.slopeError == "Enter a slope from 55 to 155.")
        model.ratingText = "71.25"
        #expect(model.rating == nil && model.ratingError != nil)
        model.ratingText = "70.4"
        model.slopeText = "x"
        #expect(model.slope == nil && model.slopeError != nil && !model.canSave)
        model.slopeText = "126"
        #expect(model.canSave)
        model.name = "  "
        #expect(!model.canSave)
    }

    @Test func addCourseSavesOrReportsADuplicate() throws {
        let dependencies = AppDependencies.preview(.outsideScores)
        let model = AddOutsideCourseViewModel(outsideScores: dependencies.outsideScores)
        model.save() // invalid: nothing happens
        #expect(!model.didSave)
        model.name = " cedar ridge"
        model.ratingText = "70.0"
        model.slopeText = "120"
        model.save()
        #expect(model.nameError == "A course with this name already exists." && !model.didSave)
        model.name = "Pine Hollow"
        model.nameChanged()
        #expect(model.nameError == nil)
        model.save()
        #expect(model.didSave && model.saveError == nil)
        #expect(try dependencies.outsideScores.courses().contains { $0.name == "Pine Hollow" && $0.courseRating == 70 && $0.slope == 120 })
    }

    @Test func aFailedCourseSaveOffersTryAgain() {
        let dependencies = AppDependencies.preview(.outsideScores)
        let failing = SwiftDataOutsideScoreRepository(context: dependencies.container.mainContext, tracker: dependencies.tracker,
                                                      clock: dependencies.clock, failSaves: true)
        let model = AddOutsideCourseViewModel(outsideScores: failing)
        model.name = "Pine Hollow"
        model.ratingText = "70.4"
        model.slopeText = "126"
        model.save()
        #expect(model.saveError == "The course couldn't be saved." && !model.didSave && model.name == "Pine Hollow")
    }
}
