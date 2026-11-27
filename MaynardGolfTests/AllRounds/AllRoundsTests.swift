import Foundation
import SwiftData
import Testing
import UIKit
@testable import MaynardGolf

/// HOME-AR: full history, search metadata, paging, observation, and delete outcomes.
@MainActor
struct AllRoundsTests {
    private let context: ModelContext
    private let repository: SwiftDataRoundRepository
    private let tracker: ModelChangeTracker
    private let utc: Calendar
    init() throws {
        context = try makeInMemoryContext()
        tracker = ModelChangeTracker(context: context)
        repository = SwiftDataRoundRepository(context: context, tracker: tracker, clock: FixedClock(now: TestDates.teeOff))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        utc = calendar
    }
    private func model(_ rounds: RoundRepository? = nil, courses: CourseProvider = BundleCourseProvider()) -> AllRoundsViewModel {
        AllRoundsViewModel(rounds: rounds ?? repository, courses: courses, calendar: utc, locale: Locale(identifier: "en_US"))
    }

    /// DS-CN-04: one- and two-player rows' avatars are decoded once at list size; no photo shows the initial.
    @Test func rowAvatarsAreCached() throws {
        let data = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 600)).jpegData(withCompressionQuality: 0.8) { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 600, height: 600))
        }
        let model = model()
        let id = UUID()
        let image = try #require(model.avatar(for: id, photo: data))
        #expect(min(image.size.width * image.scale, image.size.height * image.scale) == AvatarCache.listPixels)
        #expect(model.avatar(for: id, photo: data) === image)
        #expect(model.avatar(for: id, photo: nil) == nil)
    }

    @Test func searchCountsAndEmptyStates() throws {
        let jose = ModelFixtures.player("José", "María", in: context)
        let scottie = ModelFixtures.player("Scottie", "Scheffler", in: context)
        let older = try ModelFixtures.completedRound(players: [jose], startedAt: ModelFixtures.daysAgo(20), in: context)
        let newer = try ModelFixtures.inProgressRound(players: [jose, scottie], thru: 2, in: context)
        try context.save()
        let model = model()
        #expect(!model.hasLoaded && !model.hasNoRounds)
        model.load()
        #expect(model.countLabel == "2 ROUNDS" && model.shownCount == 2)
        #expect(model.sections.flatMap(\.rounds).map(\.id) == [newer.id, older.id])
        #expect(model.destination(for: model.sections[0].rounds[0]) == .holePlay(newer.id))
        #expect(model.destination(for: model.sections.flatMap(\.rounds)[1]) == .roundDetail(older.id))
        #expect(model.courseName(for: newer.id) == "Maynard Golf Club")
        #expect(model.courseName(for: UUID()).isEmpty)
        for query in ["JOSE", "maria", "José María", "  Maynard  ", "   "] {
            model.query = query
            #expect(model.shownCount == 2)
        }
        model.query = "sc"
        #expect(model.shownCount == 1 && model.countLabel == "1 ROUND")
        let match = try #require(model.sections.first?.rounds.first)
        #expect(match.players.map(\.firstName) == ["José", "Scottie"])
        #expect(match.players.map(\.gross) == newer.sortedEntries.map(\.grossTotal))
        model.query = "zzz"
        #expect(model.hasNoMatches && !model.hasNoRounds && model.sections.isEmpty)
        model.query = ""
        #expect(model.shownCount == 2)
    }

    @Test func emptyAndYearBoundariesAndDuplicates() throws {
        let model = model()
        model.load()
        #expect(model.hasNoRounds && !model.hasNoMatches)
        let player = ModelFixtures.player("First", in: context)
        let january = try ModelFixtures.completedRound(players: [player], startedAt: Date(timeIntervalSince1970: 1_767_268_800), in: context)
        let december = try ModelFixtures.completedRound(players: [player], startedAt: Date(timeIntervalSince1970: 1_767_182_400), in: context)
        let duplicate = try ModelFixtures.completedRound(players: [player], startedAt: december.startedAt.addingTimeInterval(-1), in: context)
        duplicate.id = december.id
        try context.save()
        model.load()
        #expect(model.shownCount == 2)
        #expect(model.sections.map(\.month) == [202601, 202512])
        #expect(model.sections.map(\.title) == ["JANUARY 2026", "DECEMBER 2025"])
        #expect(model.sections.flatMap(\.rounds).map(\.id) == [january.id, december.id])
        let canonical = try #require(try repository.round(id: december.id))
        let displayed = try #require(model.sections.flatMap(\.rounds).first { $0.id == december.id })
        #expect(displayed.startedAt == canonical.startedAt)
        model.confirmDelete(id: december.id)
        #expect(model.shownCount == 1 && model.sections.flatMap(\.rounds).map(\.id) == [january.id])
        #expect(try repository.round(id: december.id) == nil)

    }

    @Test func loadsPastFirstPageAndKeepsEveryPlayersChip() throws {
        let players = (0..<4).map { ModelFixtures.player("Player\($0)", in: context) }
        for day in 0...AllRoundsViewModel.pageSize {
            try ModelFixtures.inProgressRound(players: day == AllRoundsViewModel.pageSize ? players : [players[0]],
                thru: 0, startedAt: ModelFixtures.daysAgo(day), in: context)
        }
        try context.save()
        let model = model()
        model.load()
        #expect(model.shownCount == 201)
        model.query = "Player3"
        #expect(model.shownCount == 1)
        #expect(model.sections[0].rounds[0].players.map(\.firstName) == players.map(\.firstName))
        #expect(model.sections[0].rounds[0].players.map(\.gross) == [0, 0, 0, 0])
    }

    @Test func deleteCompletedAndInProgressAndVanishedRound() throws {
        let player = ModelFixtures.player("First", in: context)
        let completed = try ModelFixtures.completedRound(players: [player], in: context)
        let playing = try ModelFixtures.inProgressRound(players: [player], thru: 3, in: context)
        try context.save()
        let model = model()
        model.load()
        let summary = try #require(model.sections.flatMap(\.rounds).first { $0.id == completed.id })
        model.requestDelete(summary)
        #expect(model.deleteRequest?.id == completed.id)
        #expect(model.deleteRequest?.message.contains("Deleted rounds") == true)
        model.deleteRequest = nil // alert dismissal can clear state before the callback
        model.confirmDelete(id: completed.id)
        #expect(model.shownCount == 1 && model.deleteError == nil)
        model.confirmDelete(id: playing.id)
        #expect(model.hasNoRounds)
        model.confirmDelete(id: UUID())
        #expect(model.hasNoRounds && model.deleteError == nil)
    }

    @Test func failuresPreserveDataAndSurfaceErrors() throws {
        let player = ModelFixtures.player("First", in: context)
        let round = try ModelFixtures.completedRound(players: [player], in: context)
        try context.save()
        let failing = AllRoundsTestRepository(repository)
        let model = model(failing)
        failing.failReads = true
        model.load()
        #expect(model.loadError != nil && !model.hasNoRounds && !model.hasLoaded)
        failing.failReads = false
        model.load()
        #expect(model.shownCount == 1 && model.loadError == nil)
        failing.failReads = true
        model.load()
        #expect(model.shownCount == 1 && model.loadError != nil)
        failing.failReads = false
        failing.failDelete = true
        model.confirmDelete(id: round.id)
        #expect(model.deleteError != nil && model.shownCount == 1)
        #expect(try repository.round(id: round.id) != nil)
        failing.failDelete = false
        model.confirmDelete(id: round.id)
        #expect(model.deleteError == nil && model.hasNoRounds)
        let badCourse = self.model(courses: MissingCourseForAllRounds())
        try ModelFixtures.completedRound(players: [player], in: context)
        badCourse.load()
        #expect(badCourse.loadError != nil)
    }

    @Test func observationAndDependencyGraph() async throws {
        let dependencies = AppDependencies.preview(.onePlayer)
        let model = AllRoundsViewModel(dependencies: dependencies)
        model.load()
        #expect(model.shownCount == 3)
        let player = ModelFixtures.player("New", in: context)
        let round = try ModelFixtures.completedRound(players: [player], in: context)
        try context.save()
        let finite = AllRoundsTestRepository(repository)
        finite.hideBeforeChange = true
        finite.notifications = [ModelChanges(), ModelChanges(updated: [player.persistentModelID]),
                                ModelChanges(updated: [round.persistentModelID]),
                                ModelChanges(deleted: [round.sortedEntries[0].persistentModelID])]
        let observed = self.model(finite)
        await observed.observe()
        #expect(observed.shownCount == 1 && observed.hasLoaded && !observed.hasNoRounds)
        #expect(finite.readCount == 4) // initial load plus three relevant changes, skipping the empty event
        let emptyOnly = AllRoundsTestRepository(repository)
        emptyOnly.hideBeforeChange = true
        emptyOnly.notifications = [ModelChanges()]
        let unchanged = self.model(emptyOnly)
        await unchanged.observe()
        #expect(unchanged.shownCount == 0 && emptyOnly.readCount == 1)
    }
}

private struct MissingCourseForAllRounds: CourseProvider {
    func course(id: String) throws -> Course { throw CourseError.missingFile(id) }
}

@MainActor
private final class AllRoundsTestRepository: RoundRepository {
    private let base: RoundRepository
    var failReads = false
    var failDelete = false
    var hideBeforeChange = false
    var notifications: [ModelChanges] = []
    private(set) var readCount = 0
    private var hasYielded = false
    struct Failure: Error {}
    init(_ base: RoundRepository) { self.base = base }
    func inProgress() throws -> [Round] { try base.inProgress() }
    func recentCompleted(limit: Int?) throws -> [Round] { try base.recentCompleted(limit: limit) }
    func rounds(for player: Player) throws -> [Round] { try base.rounds(for: player) }
    func allRounds(offset: Int, limit: Int) throws -> [Round] { readCount += 1; if failReads { throw Failure() }; if hideBeforeChange && !hasYielded { return [] }; return try base.allRounds(offset: offset, limit: limit) }
    func round(id: UUID) throws -> Round? { try base.round(id: id) }
    func create(players: [Player], holeCount: HoleCount, tee: Tee, weather: WeatherSnapshot?) throws -> Round {
        try base.create(players: players, holeCount: holeCount, tee: tee, weather: weather)
    }
    func saveScore(_ strokes: Int, hole: Int, for entry: RoundEntry) throws { try base.saveScore(strokes, hole: hole, for: entry) }
    func setCurrentHole(_ hole: Int, for round: Round) throws { try base.setCurrentHole(hole, for: round) }
    func deletedRounds(offset: Int, limit: Int) throws -> [Round] { readCount += 1; if failReads { throw Failure() }; return try base.deletedRounds(offset: offset, limit: limit) }
    func permanentlyDelete(id: UUID) throws { if failDelete { throw Failure() }; try base.permanentlyDelete(id: id) }
    func restore(id: UUID) throws { if failDelete { throw Failure() }; try base.restore(id: id) }
    func emptyTrash() throws { if failDelete { throw Failure() }; try base.emptyTrash() }
    func delete(_ round: Round) throws { if failDelete { throw Failure() }; try base.delete(round) }
    func changes() -> AsyncStream<ModelChanges> { hasYielded = true; return AsyncStream { stream in
        for change in notifications { stream.yield(change) }
        stream.finish()
    } }
}

/// #224: the same paged history model serves Trash without exposing its records to normal navigation.
extension AllRoundsTests {
    @Test func trashLoadsDuplicatesAndPermanentlyDeletesOnlyConfirmedIDs() throws {
        let player = ModelFixtures.player("First", in: context)
        let active = try ModelFixtures.completedRound(players: [player], in: context)
        let old = try ModelFixtures.completedRound(players: [player], startedAt: ModelFixtures.daysAgo(3), in: context)
        let duplicate = try ModelFixtures.completedRound(players: [player], startedAt: ModelFixtures.daysAgo(2), in: context)
        duplicate.id = old.id
        try context.save()
        try repository.delete(old)
        let trash = AllRoundsViewModel(rounds: repository, courses: BundleCourseProvider(), isTrash: true)
        #expect(!trash.canEmptyTrash)
        trash.load()
        #expect(trash.isTrash && trash.canEmptyTrash && trash.shownCount == 1)
        let summary = try #require(trash.sections.first?.rounds.first)
        #expect(summary.startedAt == old.startedAt)
        trash.requestDelete(summary)
        #expect(trash.deleteRequest?.message.contains("permanently") == true)
        trash.deleteRequest = nil // Cancel does not touch the repository
        #expect(try repository.deletedRounds(offset: 0, limit: 10).count == 2)
        trash.confirmDelete(id: old.id)
        #expect(trash.hasNoRounds && !trash.canEmptyTrash && trash.deleteError == nil)
        #expect(try repository.round(id: active.id) != nil)
        trash.confirmDelete(id: UUID())
        let history = model()
        history.emptyTrash() // only a Trash-scoped model can invoke this action
        #expect(try repository.round(id: active.id) != nil)
    }

    @Test func trashFailuresRetainDataAndRetryWorks() throws {
        let player = ModelFixtures.player("First", in: context)
        let round = try ModelFixtures.completedRound(players: [player], in: context)
        try context.save()
        try repository.delete(round)
        let failing = AllRoundsTestRepository(repository)
        let trash = AllRoundsViewModel(rounds: failing, courses: BundleCourseProvider(), isTrash: true)
        trash.load()
        failing.failReads = true
        trash.load()
        #expect(trash.loadError != nil && trash.shownCount == 1)
        failing.failReads = false
        trash.load()
        #expect(trash.loadError == nil)
        failing.failDelete = true
        trash.confirmDelete(id: round.id)
        #expect(trash.deleteError != nil && trash.shownCount == 1)
        trash.emptyTrash()
        #expect(trash.deleteError != nil && trash.canEmptyTrash)
        failing.failDelete = false
        trash.query = "not a match"
        trash.emptyTrash() // empties all Trash, including rows hidden by search
        #expect(trash.deleteError == nil && trash.hasNoRounds && !trash.canEmptyTrash)
    }
}

extension AllRoundsTests {
    @Test func restoreIsTrashOnlyAndFailuresCanBeRetried() throws {
        let player = ModelFixtures.player("Restore", in: context)
        let round = try ModelFixtures.completedRound(players: [player], in: context)
        try context.save()
        try repository.delete(round)
        let failing = AllRoundsTestRepository(repository)
        let trash = AllRoundsViewModel(rounds: failing, courses: BundleCourseProvider(), isTrash: true)
        trash.load()
        model().restore(id: round.id)
        #expect(try repository.round(id: round.id) == nil)
        failing.failDelete = true
        trash.restore(id: round.id)
        #expect(trash.restoreError == "The round couldn't be restored. Try again.")
        #expect(trash.shownCount == 1 && trash.canEmptyTrash)
        failing.failDelete = false
        trash.restore(id: round.id)
        #expect(trash.restoreError == nil && trash.hasNoRounds && !trash.canEmptyTrash)
        #expect(try repository.round(id: round.id) != nil)
    }
}
