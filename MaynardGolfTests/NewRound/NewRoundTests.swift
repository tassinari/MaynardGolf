//
//  NewRoundTests.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
import Testing
@testable import MaynardGolf

/// A store with repositories on it, for New round's view model.
@MainActor
private struct Store {
    let context: ModelContext
    let players: SwiftDataPlayerRepository
    let rounds: SwiftDataRoundRepository

    init() throws {
        context = try makeInMemoryContext()
        let tracker = ModelChangeTracker(context: context)
        let clock = FixedClock(now: TestDates.teeOff)
        players = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: clock)
        rounds = SwiftDataRoundRepository(context: context, tracker: tracker, clock: clock)
    }

    func add(_ names: [String]) -> [Player] {
        names.map { ModelFixtures.player($0, in: context) }
    }
}

private struct NoHandicaps: HandicapDataSource {
    func handicapSnapshots() async throws -> (players: [PlayerSnapshot], rounds: [RoundSnapshot]) { ([], []) }
}

/// Weather that never answers in time.
private struct SlowWeather: WeatherProviding {
    func currentWeather(at coordinate: Coordinate) async throws -> WeatherSnapshot {
        try await Task.sleep(for: .seconds(30))
        return ModelFixtures.weather(.sunny)
    }
}

/// Weather that ignores cancellation and answers after `seconds` (#156's review: the timeout mustn't
/// wait for it).
private struct StubbornWeather: WeatherProviding {
    let seconds: Double
    func currentWeather(at coordinate: Coordinate) async throws -> WeatherSnapshot {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end { await Task.yield() }
        return ModelFixtures.weather(.sunny)
    }
}

/// Weather that runs `meanwhile` on the main actor while it's being fetched, then answers.
private struct MeddlingWeather: WeatherProviding {
    let meanwhile: @MainActor @Sendable () -> Void
    func currentWeather(at coordinate: Coordinate) async throws -> WeatherSnapshot {
        await meanwhile()
        return ModelFixtures.weather(.cloudy)
    }
}

/// A course provider that fails, or serves a course with only some tees.
private struct Courses: CourseProvider {
    var tees: [Tee]?
    func course(id: String) throws -> Course {
        let full = try BundleCourseProvider().course(id: id)
        guard let tees else { throw CourseError.missingFile(id) }
        return Course(id: full.id, name: full.name, coordinate: full.coordinate, tees: full.tees.filter { tees.contains($0.id) },
                      holes: full.holes, localRules: full.localRules)
    }
}

/// Rounds whose create fails (NR-CTA-05), and whose change stream yields once.
@MainActor
private final class Rounds: RoundRepository {
    struct Failure: Error {}
    private let base: RoundRepository
    var failsCreate = false
    var failsAllRounds = false
    init(_ base: RoundRepository) { self.base = base }
    func inProgress() throws -> [Round] { try base.inProgress() }
    func recentCompleted(limit: Int?) throws -> [Round] { try base.recentCompleted(limit: limit) }
    func rounds(for player: Player) throws -> [Round] { try base.rounds(for: player) }
    func allRounds(offset: Int, limit: Int) throws -> [Round] {
        if failsAllRounds { throw Failure() }
        return try base.allRounds(offset: offset, limit: limit)
    }
    func create(players: [Player], holeCount: HoleCount, tee: Tee, weather: WeatherSnapshot?) throws -> Round {
        if failsCreate { throw Failure() }
        return try base.create(players: players, holeCount: holeCount, tee: tee, weather: weather)
    }
    func saveScore(_ strokes: Int, hole: Int, for entry: RoundEntry) throws { try base.saveScore(strokes, hole: hole, for: entry) }
    func setCurrentHole(_ hole: Int, for round: Round) throws { try base.setCurrentHole(hole, for: round) }
    func delete(_ round: Round) throws { try base.delete(round) }
    func changes() -> AsyncStream<ModelChanges> { base.changes() }
}

/// Players whose change stream yields one change and ends.
@MainActor
private final class OneChangePlayers: PlayerRepository {
    private let base: PlayerRepository
    private(set) var reads = 0
    init(_ base: PlayerRepository) { self.base = base }
    func allPlayers() throws -> [Player] { try base.allPlayers() }
    func recentPlayers(limit: Int?) throws -> [Player] {
        reads += 1
        return try base.recentPlayers(limit: limit)
    }
    func search(_ text: String) throws -> [Player] { try base.search(text) }
    func create(firstName: String, lastName: String, color: PlayerColor, photoData: Data?, manualIndex: Double?) throws -> Player {
        try base.create(firstName: firstName, lastName: lastName, color: color, photoData: photoData, manualIndex: manualIndex)
    }
    func update(_ player: Player, _ change: (Player) throws -> Void) throws { try base.update(player, change) }
    func delete(_ player: Player) throws { try base.delete(player) }
    func changes() -> AsyncStream<ModelChanges> {
        AsyncStream { $0.yield(ModelChanges()); $0.finish() }
    }
}

/// 04-new-round: defaults, tees, the players list and its limit, and Tee off (#38, #39, #40, #41, #85).
@MainActor
struct NewRoundViewModelTests {
    private func model(_ store: Store, players: PlayerRepository? = nil, rounds: RoundRepository? = nil,
                       courses: CourseProvider = BundleCourseProvider(), settings: SettingsStore = .inMemory(),
                       weather: WeatherProviding = MockWeatherService(behavior: .success(ModelFixtures.weather(.sunny))),
                       timeout: Duration = .seconds(4)) -> NewRoundViewModel {
        NewRoundViewModel(players: players ?? store.players, rounds: rounds ?? store.rounds, courses: courses, settings: settings,
                          weather: weather, handicaps: HandicapManager(source: NoHandicaps(), calculator: nil,
                                                                       clock: FixedClock(now: TestDates.teeOff)),
                          weatherTimeout: timeout)
    }

    /// NR-HOL-02, NR-TEE-05, NR-PLY-04: a first-time user gets 9 holes, the default tee, nobody selected.
    @Test func firstTimeDefaults() throws {
        let home = model(try Store())
        home.load()
        #expect(home.holeCount == .nine)
        #expect(home.tee == .white)
        #expect(home.selection.isEmpty && home.players.isEmpty)
        #expect(!home.canTeeOff)
        #expect(home.teeOffTitle == "Tee off · White · 9 holes")
    }

    /// NR-HOL-02, NR-TEE-05: the last hole count and the Settings tee.
    @Test func defaultsComeFromSettings() throws {
        let newRound = model(try Store(), settings: .inMemory([.lastHoleCount: 18, .defaultTee: "blue"]))
        newRound.load()
        #expect(newRound.holeCount == .eighteen)
        #expect(newRound.tee == .blue)
        #expect(newRound.teeOffTitle == "Tee off · Blue · 18 holes")
    }

    /// NR-TEE-05: a default tee the course doesn't have falls back to its first tee.
    @Test func aMissingDefaultTeeFallsBack() throws {
        let newRound = model(try Store(), courses: Courses(tees: [.red, .yellow]), settings: .inMemory([.defaultTee: "blue"]))
        newRound.load()
        #expect(newRound.tees.map(\.id) == [.yellow, .red])
        #expect(newRound.tee == .yellow)
    }

    /// NR-TEE-02, 03, 06, NR-HOL-05: one card per tee with the round's yards and rating / slope.
    @Test func teeCardsFollowTheHoleCount() throws {
        let newRound = model(try Store())
        newRound.load()
        #expect(newRound.tees.map(\.id) == [.blue, .white, .yellow, .red])
        let blue = try #require(newRound.tees.first)
        #expect(blue.name == "Blue")
        #expect(blue.yards == "3,013 yds")
        #expect(blue.ratingAndSlope == "Rating / slope 34.1 / 123")
        newRound.holeCount = .eighteen
        #expect(newRound.tees.first?.yards == "6,026 yds")
        #expect(newRound.tees.first?.ratingAndSlope == "Rating / slope 68.2 / 123")
        newRound.tee = .red
        #expect(newRound.teeOffTitle == "Tee off · Red · 18 holes")
    }

    /// NR-PLY-04, 05: the last round's players are selected in card order; the list is most recently
    /// played first, then A–Z.
    @Test func theLastRoundsGroupIsSelected() throws {
        let store = try Store()
        let p = store.add(["Zed", "Mark", "Phil", "anne", "Ben"])
        let ann = ModelFixtures.player("anne", "Abbott", in: store.context) // same first name: by full name
        try ModelFixtures.completedRound(players: [p[0]], startedAt: TestDates.minutes(-600), in: store.context)
        try ModelFixtures.completedRound(players: [p[2], p[1]], in: store.context)
        let newRound = model(store)
        newRound.load()
        #expect(newRound.selection == [p[2].id, p[1].id])
        #expect(Set(newRound.players.prefix(3).map(\.firstName)) == ["Mark", "Phil", "Zed"])
        #expect(newRound.players.suffix(3).map(\.id) == [p[3].id, ann.id, p[4].id]) // "anne" before "anne Abbott"
        #expect(newRound.canTeeOff)
    }

    /// NR-PLY-03: four at most; the rest can't be toggled until one is cleared.
    @Test func noMoreThanFour() throws {
        let store = try Store()
        let p = store.add(["A", "B", "C", "D", "E"])
        let newRound = model(store)
        newRound.load()
        p.forEach { newRound.toggle($0.id) }
        #expect(newRound.selection == p.prefix(4).map(\.id))
        #expect(newRound.isFull)
        #expect(!newRound.canToggle(p[4].id) && newRound.canToggle(p[0].id))
        newRound.toggle(p[1].id)
        #expect(!newRound.isFull && newRound.canToggle(p[4].id))
        newRound.toggle(p[4].id)
        #expect(newRound.selection == [p[0].id, p[2].id, p[3].id, p[4].id])
        newRound.toggle(UUID()) // not a listed player: ignored
        #expect(newRound.selection.count == 4)
    }

    /// NR-PLY-06: the player Add player creates is selected, unless four already are.
    @Test func anAddedPlayerIsSelected() throws {
        let store = try Store()
        _ = store.add(["A", "B", "C"])
        let newRound = model(store)
        newRound.load()
        newRound.beginAddingPlayer()
        let rory = try store.players.create(firstName: "Rory", lastName: "", color: .flag, photoData: nil, manualIndex: nil)
        newRound.endAddingPlayer()
        #expect(newRound.selection == [rory.id])
        newRound.players.filter { $0.id != rory.id }.forEach { newRound.toggle($0.id) }
        #expect(newRound.isFull)
        newRound.beginAddingPlayer()
        let sam = try store.players.create(firstName: "Sam", lastName: "", color: .moss, photoData: nil, manualIndex: nil)
        newRound.endAddingPlayer()
        #expect(!newRound.isSelected(sam.id))
        newRound.load() // after Add player closed, a reload doesn't select anyone new
        #expect(newRound.selection.count == 4)
    }

    /// A player deleted while New round is open drops out of the selection.
    @Test func aDeletedPlayerDropsOut() throws {
        let store = try Store()
        let p = store.add(["A", "B"])
        let newRound = model(store)
        newRound.load()
        p.forEach { newRound.toggle($0.id) }
        try store.players.delete(p[0])
        newRound.load()
        #expect(newRound.selection == [p[1].id])
    }

    /// NR-CTA-03, NR-HOL-02, 07: Tee off saves the round with the players in selection order, the hole
    /// count, the tee and the weather, and remembers the hole count.
    @Test func teeOffCreatesTheRound() async throws {
        let store = try Store()
        let p = store.add(["Mark", "Phil"])
        let settings = SettingsStore.inMemory()
        let newRound = model(store, settings: settings)
        newRound.load()
        newRound.toggle(p[1].id)
        newRound.toggle(p[0].id)
        newRound.holeCount = .eighteen
        newRound.tee = .blue
        let id = try #require(await newRound.teeOff())
        let round = try #require(try store.rounds.inProgress().first)
        #expect(round.id == id)
        #expect(round.holeCount == .eighteen && round.tee == .blue)
        #expect(round.sortedEntries.compactMap { $0.player?.firstName } == ["Phil", "Mark"])
        #expect(round.weather?.condition == .sunny)
        #expect(settings.lastHoleCount == .eighteen)
        #expect(!newRound.isTeeingOff)
    }

    /// NR-CTA-04: failing or slow weather doesn't block Tee off; the round has no weather.
    @Test(arguments: [false, true])
    func weatherNeverBlocks(slow: Bool) async throws {
        let store = try Store()
        let p = store.add(["Mark"])
        let weather: WeatherProviding = slow ? SlowWeather() : MockWeatherService(behavior: .failure)
        let newRound = model(store, weather: weather, timeout: .milliseconds(50))
        newRound.load()
        newRound.toggle(p[0].id)
        let id = try #require(await newRound.teeOff())
        #expect(try store.rounds.inProgress().first { $0.id == id }?.weather == nil)
    }

    /// NR-CTA-04: the timeout holds even when the weather fetch ignores cancellation.
    @Test func theTimeoutDoesntWaitForStubbornWeather() async throws {
        let store = try Store()
        let p = store.add(["Mark"])
        let newRound = model(store, weather: StubbornWeather(seconds: 3), timeout: .milliseconds(50))
        newRound.load()
        newRound.toggle(p[0].id)
        let started = ContinuousClock.now
        let id = try #require(await newRound.teeOff())
        #expect(ContinuousClock.now - started < .seconds(2))
        #expect(try store.rounds.inProgress().first { $0.id == id }?.weather == nil)
    }

    /// The round is what Tee off said, even if the selection changes during the weather wait.
    @Test func teeOffUsesWhatWasTapped() async throws {
        let store = try Store()
        let p = store.add(["Mark", "Phil"])
        var newRound: NewRoundViewModel!
        newRound = model(store, weather: MeddlingWeather {
            newRound.toggle(p[0].id)
            newRound.toggle(p[1].id)
            newRound.holeCount = .eighteen
            newRound.tee = .red
        })
        newRound.load()
        newRound.toggle(p[0].id)
        newRound.toggle(p[1].id)
        let id = try #require(await newRound.teeOff())
        let round = try #require(try store.rounds.inProgress().first { $0.id == id })
        #expect(round.holeCount == .nine && round.tee == .white)
        #expect(round.sortedEntries.compactMap { $0.player?.firstName } == ["Mark", "Phil"])
    }

    /// The only picked player deleted before Tee off: no empty round is saved.
    @Test func noRoundWithoutPlayers() async throws {
        let store = try Store()
        let p = store.add(["Mark"])
        let newRound = model(store)
        newRound.load()
        newRound.toggle(p[0].id)
        try store.players.delete(p[0])
        #expect(await newRound.teeOff() == nil)
        #expect(try store.rounds.inProgress().isEmpty)
    }

    /// A failed first load changes nothing; Try again loads and still preselects the last group.
    @Test func aFailedFirstLoadRetries() throws {
        let store = try Store()
        let p = store.add(["Mark"])
        try ModelFixtures.completedRound(players: p, in: store.context)
        let rounds = Rounds(store.rounds)
        rounds.failsAllRounds = true
        let newRound = model(store, rounds: rounds)
        newRound.load()
        #expect(newRound.loadError != nil)
        #expect(newRound.players.isEmpty && newRound.tees.isEmpty)
        rounds.failsAllRounds = false
        newRound.load()
        #expect(newRound.loadError == nil)
        #expect(newRound.selection == [p[0].id])
    }

    /// NR-CTA-05: a failed save shows the alert and stays.
    @Test func aFailedSaveShowsTheAlert() async throws {
        let store = try Store()
        let p = store.add(["Mark"])
        let rounds = Rounds(store.rounds)
        rounds.failsCreate = true
        let newRound = model(store, rounds: rounds)
        newRound.load()
        newRound.toggle(p[0].id)
        #expect(await newRound.teeOff() == nil)
        #expect(newRound.saveError == "The round couldn't be started. Try again.")
        #expect(try store.rounds.inProgress().isEmpty)
    }

    /// A selected player deleted before Tee off: nothing is saved and the alert shows.
    @Test func aPlayerDeletedBeforeTeeOff() async throws {
        let store = try Store()
        let p = store.add(["Mark", "Phil"])
        let newRound = model(store)
        newRound.load()
        p.forEach { newRound.toggle($0.id) }
        try store.players.delete(p[1])
        #expect(await newRound.teeOff() == nil)
        #expect(newRound.saveError != nil)
    }

    /// The course can't be read: an error instead of the lists, and no Tee off.
    @Test func aMissingCourse() async throws {
        let store = try Store()
        _ = store.add(["Mark"])
        let newRound = model(store, courses: Courses(tees: nil))
        newRound.load()
        #expect(newRound.loadError == "The players couldn't be loaded.")
        #expect(newRound.tees.isEmpty && !newRound.canTeeOff)
        #expect(newRound.teeOffTitle == "Tee off · White · 9 holes")
        #expect(await newRound.teeOff() == nil)
    }

    /// NR-PLY-02: the caption reads the manager's index; no photo, no image.
    @Test func rowValues() throws {
        let store = try Store()
        let mark = store.add(["Mark"])[0]
        let newRound = model(store)
        newRound.load()
        #expect(newRound.handicapCaption(for: mark.id) == "HCP —")
        #expect(newRound.avatar(for: try #require(newRound.players.first)) == nil)
    }

    /// The list follows the store's change stream.
    @Test func changesReload() async throws {
        let store = try Store()
        let players = OneChangePlayers(store.players)
        let newRound = model(store, players: players)
        _ = store.add(["Mark"])
        await newRound.observe()
        #expect(players.reads == 2)
        #expect(newRound.players.count == 1)
        let live = NewRoundViewModel(dependencies: AppDependencies.preview(.freshInstall))
        live.load()
        #expect(live.players.isEmpty)
    }
}
