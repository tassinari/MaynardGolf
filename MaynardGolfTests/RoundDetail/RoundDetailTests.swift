//
//  RoundDetailTests.swift
//  MaynardGolfTests
//

import Foundation
import MaynardUI
import SwiftData
import Testing
@testable import MaynardGolf

/// 10-round-detail: the header lines, the players strip, the legend and the model (#75, #76, #77).
@MainActor
struct RoundDetailTests {
    private let context: ModelContext
    private let rounds: SwiftDataRoundRepository
    private let course: Course
    private let utc: Calendar
    private let en = Locale(identifier: "en_US")
    /// Saturday 8 November 2025, 8:40 UTC.
    private let saturday: Date

    init() throws {
        context = try makeInMemoryContext()
        rounds = SwiftDataRoundRepository(context: context, tracker: ModelChangeTracker(context: context),
                                          clock: FixedClock(now: TestDates.teeOff))
        course = try BundleCourseProvider().course(id: "MaynardGC")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        utc = calendar
        saturday = calendar.date(from: DateComponents(year: 2025, month: 11, day: 8, hour: 8, minute: 40))!
    }

    private func content(_ round: Round) -> RoundDetailContent {
        RoundDetailContent.make(round: RoundSnapshot(round), players: round.sortedEntries.compactMap(\.player).map(PlayerSnapshot.init),
                                course: course, locale: en, calendar: utc)
    }

    /// RD-HDR-01…03: the course, the date, tee time and duration, and the tees, par and yards for the round.
    @Test(arguments: [(HoleCount.eighteen, "Blue tees · Par 70 · 6,026 yds", "4h 30m"), (.nine, "Blue tees · Par 35 · 3,013 yds", "2h 15m")])
    func header(holeCount: HoleCount, teeLine: String, duration: String) throws {
        let round = try ModelFixtures.completedRound(players: [ModelFixtures.player("Mark", in: context)], holeCount: holeCount,
                                                     tee: .blue, startedAt: saturday, weather: ModelFixtures.weather(.sunny), in: context)
        let detail = content(round)
        #expect(detail.courseName == "Maynard Golf Club")
        #expect(detail.metaLine == "Sat, Nov 8 · Tee time 8:40\u{202F}AM · \(duration)")
        #expect(detail.teeLine == teeLine)
        #expect(detail.weather?.condition == .sunny)
    }

    /// RD-HDR-02: no duration while a round has no finish.
    @Test func noDuration() throws {
        let playing = try ModelFixtures.inProgressRound(players: [ModelFixtures.player("Mark", in: context)], thru: 2,
                                                        startedAt: saturday, in: context)
        #expect(content(playing).metaLine == "Sat, Nov 8 · Tee time 8:40\u{202F}AM")
        #expect(content(playing).weather == nil)
    }

    /// RD-PL-01…03: every player in round order with gross and to-par, no ranking; the scorecard has no
    /// current-hole highlight (RD-SC-02).
    @Test(arguments: 1...4)
    func playersInRoundOrder(count: Int) throws {
        let names = Array(["Tiger", "Ann", "Mark", "Bob"].prefix(count))
        let round = try ModelFixtures.completedRound(players: names.map { ModelFixtures.player($0, in: context) }, startedAt: saturday, in: context)
        let detail = content(round)
        #expect(detail.players.map(\.firstName) == names)
        #expect(detail.players.map(\.gross) == round.sortedEntries.map(\.grossTotal))
        #expect(detail.scorecard.currentHole == nil)
    }

    /// RD-SC-04: Birdie, Bogey, Double+, with Eagle first only when the round has one.
    @Test func legend() throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let plain = try ModelFixtures.round(players: [mark], startedAt: saturday, scores: [[4, 5, 3, 4, 4, 3, 4, 4, 4]], in: context)
        #expect(content(plain).legend == [.birdie, .bogey, .doublePlus])
        let eagle = try ModelFixtures.round(players: [mark], startedAt: saturday, scores: [[2, 5, 3, 4, 4, 3, 4, 4, 4]], in: context)
        #expect(content(eagle).legend == [.eagle, .birdie, .bogey, .doublePlus])
    }

    /// Waits until `condition` holds, yielding, for up to 2 s.
    private func until(_ condition: () -> Bool) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition(), ContinuousClock.now < deadline { await Task.yield() }
    }

    /// RD-DT-01: the model reads the round; a round that's gone closes the screen; a failed read shows
    /// the error.
    @Test func model() throws {
        let round = try ModelFixtures.completedRound(players: [ModelFixtures.player("Mark", in: context)], in: context)
        let model = RoundDetailViewModel(roundID: round.id, rounds: rounds, courses: BundleCourseProvider(), exporter: exporter())
        model.load()
        let detail = try #require(model.content)
        #expect(model.avatar(detail.players[0]) == nil && model.avatar(detail.scorecard.columns[0]) == nil)
        #expect(!model.isMissing)
        try rounds.delete(round)
        model.load()
        #expect(model.content == nil && model.isMissing && model.loadError == nil)
        struct NoCourse: CourseProvider { func course(id: String) throws -> Course { throw CourseError.missingFile(id) } }
        let other = try ModelFixtures.completedRound(players: [ModelFixtures.player("Phil", in: context)], in: context)
        let unreadable = RoundDetailViewModel(roundID: other.id, rounds: rounds, courses: NoCourse(), exporter: exporter())
        unreadable.load()
        #expect(unreadable.loadError == "This round couldn't be loaded." && !unreadable.isMissing)
    }

    /// RD-ED-02: a saved score reloads the content through the change stream.
    @Test func anEditReloads() async throws {
        let dependencies = AppDependencies.preview(.onePlayer) // held: a context doesn't keep its container
        let finished = try #require(try dependencies.rounds.recentCompleted(limit: 1).first)
        let entry = finished.sortedEntries[0]
        let before = entry.grossTotal, firstHole = try #require(entry.strokes(forHole: 1))
        let newScore = firstHole == 9 ? 8 : 9
        let live = RoundDetailViewModel(roundID: finished.id, dependencies: dependencies)
        let observing = Task { await live.observe() }
        await until { live.content != nil }
        try dependencies.rounds.saveScore(newScore, hole: 1, for: entry)
        await until { live.content?.scorecard.columns.first?.scores.first == newScore }
        observing.cancel()
        #expect(live.content?.scorecard.columns.first?.scores.first == newScore)
        #expect(live.content?.players.first?.gross == before - firstHole + newScore) // against values from before the edit
    }

    // MARK: Share (RD-SH-01…05, RP-EX-01…07)

    private let pdfFiles = FakePDFFileSystem()
    private let pdfRenderer = FakePDFRenderer()

    private func exporter() -> RoundPDFExporter {
        RoundPDFExporter(renderer: pdfRenderer, fileSystem: pdfFiles, appVersion: "1.2", locale: en, calendar: utc)
    }

    private func shareModel(progressDelay: Duration = .milliseconds(300)) throws -> RoundDetailViewModel {
        let round = try ModelFixtures.completedRound(players: [ModelFixtures.player("Mark", in: context)], startedAt: saturday, in: context)
        let model = RoundDetailViewModel(roundID: round.id, rounds: rounds, courses: BundleCourseProvider(), exporter: exporter(),
                                         progressDelay: progressDelay)
        model.load()
        return model
    }

    /// RD-SH-02, RP-EX-01, 03, 04: Share makes the PDF from the round as shown, named after it, and the
    /// sheet's closing removes the file.
    @Test func shareMakesThePDFAndCleansUp() async throws {
        let model = try shareModel()
        await model.share()
        let pdf = try #require(model.sharedPDF)
        #expect(model.shareState == .presenting(pdf))
        #expect(pdf.url.lastPathComponent == "Round · Maynard Golf Club · Nov 8.pdf")
        #expect(pdf.id == pdf.url) // one sheet per file
        #expect(pdfFiles.files.keys.contains(pdf.url.standardizedFileURL))
        #expect(pdfRenderer.models.first?.rows.contains { $0.label == "Mark" } == true)
        model.finishSharing()
        #expect(model.shareState == .idle && model.sharedPDF == nil)
        #expect(pdfFiles.files.isEmpty)
    }

    /// RP-EX-07: a failure shows the alert and shares nothing.
    @Test func shareFailureShowsTheAlert() async throws {
        pdfRenderer.error = RoundPDFError.injected
        let model = try shareModel()
        await model.share()
        #expect(model.shareFailed)
        #expect(model.shareState == .idle && model.sharedPDF == nil)
        #expect(pdfFiles.files.isEmpty)
    }

    /// RD-SH-05, RP-EX-02: the progress shows only once making the PDF takes longer than the delay, and a
    /// second tap while it's made is ignored.
    @Test func shareShowsProgressWhenSlow() async throws {
        pdfRenderer.delay = .milliseconds(300)
        let model = try shareModel(progressDelay: .milliseconds(20))
        let sharing = Task { await model.share() }
        await until { model.shareState == .preparing(showsProgress: true) }
        #expect(model.shareState == .preparing(showsProgress: true))
        await model.share() // ignored: already sharing
        await sharing.value
        #expect(model.sharedPDF != nil)
        #expect(pdfRenderer.models.count == 1)
    }

    /// RD-SH-05: a PDF quicker than the delay never shows progress, only the plain preparing state.
    @Test func quickShareShowsNoProgress() async throws {
        pdfRenderer.delay = .milliseconds(100)
        let model = try shareModel(progressDelay: .seconds(5))
        let sharing = Task { await model.share() }
        await until { model.shareState != .idle }
        #expect(model.shareState == .preparing(showsProgress: false))
        await sharing.value
        #expect(model.sharedPDF != nil)
    }

    /// RP-EX-03: a PDF that finishes after the screen has gone is removed, not presented.
    @Test func shareFinishingOffScreenCleansUp() async throws {
        pdfRenderer.delay = .milliseconds(100)
        let model = try shareModel()
        let sharing = Task { await model.share() }
        await until { model.shareState != .idle }
        model.setOnScreen(false)
        await sharing.value
        #expect(model.shareState == .idle && model.sharedPDF == nil)
        #expect(pdfFiles.files.isEmpty)
        model.setOnScreen(true)
        await model.share()
        #expect(model.sharedPDF != nil)
    }

    /// Share does nothing until the round has loaded.
    @Test func shareBeforeLoadDoesNothing() async throws {
        let model = RoundDetailViewModel(roundID: UUID(), rounds: rounds, courses: BundleCourseProvider(), exporter: exporter())
        await model.share()
        #expect(model.shareState == .idle && pdfRenderer.models.isEmpty)
    }

    /// RD-TOP-01: "Home" right on Home, "Rounds" from a list.
    @Test func backTitle() {
        #expect(RoundDetailViewModel.backTitle(path: [.roundDetail(UUID())]) == "Home")
        #expect(RoundDetailViewModel.backTitle(path: [.allRounds, .roundDetail(UUID())]) == "Rounds")
    }
}
