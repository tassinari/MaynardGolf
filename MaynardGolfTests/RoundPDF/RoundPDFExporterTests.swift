//
//  RoundPDFExporterTests.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
import Testing
@testable import MaynardGolf

/// An in-memory file system that records what the exporter asked of the disk.
final class FakePDFFileSystem: RoundPDFFileSystem, @unchecked Sendable {
    var temporaryDirectory = URL(filePath: "/fake/tmp", directoryHint: .isDirectory)
    var files: [URL: Data] = [:]
    var folders: Set<URL> = []
    var removed: [URL] = []
    var failWrite = false
    var failRemove = false

    func createDirectory(at url: URL) throws { folders.insert(url.standardizedFileURL) }

    func write(_ data: Data, to url: URL) throws {
        if failWrite { throw CocoaError(.fileWriteNoPermission) }
        files[url.standardizedFileURL] = data
    }

    func removeItem(at url: URL) throws {
        if failRemove { throw CocoaError(.fileWriteNoPermission) }
        let path = url.standardizedFileURL.path()
        removed.append(url.standardizedFileURL)
        folders = folders.filter { !$0.path().hasPrefix(path) }
        files = files.filter { !$0.key.path().hasPrefix(path) }
    }

    func fileExists(at url: URL) -> Bool {
        let path = url.standardizedFileURL.path()
        return folders.contains { $0.path().hasPrefix(path) } || files.keys.contains { $0.path().hasPrefix(path) }
    }
}

/// A renderer that returns fixed bytes, or throws, and remembers what it was given (also used by Round
/// detail's share tests).
@MainActor
final class FakePDFRenderer: RoundPDFRendering {
    var error: Error?
    /// While true, `render` waits until `release()`, so a test can look at the share state mid-render
    /// without racing real time (RD-SH-05).
    var isHeld = false
    var models: [RoundPDFModel] = []
    var metadata: [RoundPDFMetadata] = []
    private var held: [CheckedContinuation<Void, Never>] = []

    /// Lets every held render finish.
    func release() {
        isHeld = false
        held.forEach { $0.resume() }
        held = []
    }

    func render(_ model: RoundPDFModel, metadata: RoundPDFMetadata) async throws -> Data {
        if isHeld { await withCheckedContinuation { held.append($0) } }
        if let error { throw error }
        models.append(model)
        self.metadata.append(metadata)
        return Data("%PDF-fake".utf8)
    }
}

/// 15-round-pdf §5: the exporter with a fake renderer and file system (RP-AR-03, RP-TS-03; #111).
@MainActor
struct RoundPDFExporterTests {
    private let context: ModelContext
    private let course: Course
    private let files = FakePDFFileSystem()
    private let renderer = FakePDFRenderer()
    private let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let utc: Calendar
    private let saturday: Date

    init() throws {
        context = try makeInMemoryContext()
        course = try BundleCourseProvider().course(id: "MaynardGC")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        utc = calendar
        saturday = calendar.date(from: DateComponents(year: 2025, month: 11, day: 8, hour: 8, minute: 40))!
    }

    private func exporter(locale: Locale = Locale(identifier: "en_US")) -> RoundPDFExporter {
        let id = id
        return RoundPDFExporter(renderer: renderer, fileSystem: files, appVersion: "1.2", locale: locale, calendar: utc, makeID: { id })
    }

    private func export(_ exporter: RoundPDFExporter) async throws -> URL {
        let round = try ModelFixtures.completedRound(players: [ModelFixtures.player("Mark", in: context)], startedAt: saturday, in: context)
        return try await exporter.export(round: RoundSnapshot(round), players: round.sortedEntries.compactMap(\.player).map(PlayerSnapshot.init),
                                         course: course)
    }

    /// RP-EX-03, RP-EX-04: the file goes in its own folder under {tmp}/RoundPDF, named after the round.
    @Test func writesTheFileToAFreshFolder() async throws {
        let url = try await export(exporter())
        #expect(url.path() == "/fake/tmp/RoundPDF/\(id.uuidString)/Round%20%C2%B7%20Maynard%20Golf%20Club%20%C2%B7%20Nov%208.pdf")
        #expect(url.lastPathComponent == "Round · Maynard Golf Club · Nov 8.pdf")
        #expect(files.files[url.standardizedFileURL] == Data("%PDF-fake".utf8))
        #expect(renderer.models.first?.layout == .nine)
    }

    /// RP-EX-05: Title is the file name without ".pdf", Creator the app and version, Subject "Scorecard".
    @Test func metadata() async throws {
        _ = try await export(exporter())
        #expect(renderer.metadata == [RoundPDFMetadata(title: "Round · Maynard Golf Club · Nov 8", creator: "Maynard Golf 1.2", subject: "Scorecard")])
    }

    /// RP-EX-04: "/" and ":" can't be in a file name, so they become "-".
    @Test(arguments: [("Round · A/B · Nov 8", "Round · A-B · Nov 8.pdf"), ("Round · 9:30 · Nov 8", "Round · 9-30 · Nov 8.pdf"),
                      ("Round · Maynard Golf Club · Nov 8", "Round · Maynard Golf Club · Nov 8.pdf")])
    func fileName(title: String, expected: String) {
        #expect(RoundPDFExporter.fileName(for: title) == expected)
    }

    /// RP-PG-02, RP-TS-03: the page is a standard scorecard in every region; the exporter doesn't pick a
    /// paper size from the locale.
    @Test(arguments: ["en_US", "en_GB", "fr_FR"])
    func pageSizeInEveryLocale(identifier: String) async throws {
        _ = try await export(exporter(locale: Locale(identifier: identifier)))
        #expect(RoundPDFPage.size == CGSize(width: 792, height: 306))
        #expect(renderer.models.count == 1)
    }

    /// RP-EX-03: cleanUp removes the share's folder; a second cleanUp does nothing.
    @Test func cleanUpRemovesTheFolder() async throws {
        let exporter = exporter()
        let url = try await export(exporter)
        exporter.cleanUp(url)
        #expect(files.files.isEmpty)
        #expect(files.folders.isEmpty)
        exporter.cleanUp(url)
        #expect(files.removed.count == 1)
    }

    /// RP-EX-03: launch removes whatever an earlier run left under {tmp}/RoundPDF.
    @Test func removeLeftovers() async throws {
        let exporter = exporter()
        _ = try await export(exporter)
        exporter.removeLeftovers()
        #expect(files.removed == [exporter.rootFolder.standardizedFileURL])
        #expect(files.files.isEmpty)
        exporter.removeLeftovers()
        #expect(files.removed.count == 1)
    }

    /// A removal that fails is logged, not thrown: the share already happened.
    @Test func failedRemovalIsLogged() async throws {
        let exporter = exporter()
        let url = try await export(exporter)
        files.failRemove = true
        exporter.cleanUp(url)
        exporter.removeLeftovers()
        #expect(!files.files.isEmpty)
    }

    /// RP-EX-07: a renderer error surfaces as the export's error and nothing is written.
    @Test func rendererErrorSurfaces() async throws {
        renderer.error = RoundPDFError.renderFailed
        await #expect(throws: RoundPDFError.renderFailed) { try await export(exporter()) }
        #expect(files.files.isEmpty && files.folders.isEmpty)
    }

    /// RP-EX-07: a write error surfaces too, and the half-made folder is removed.
    @Test func writeErrorCleansUp() async throws {
        files.failWrite = true
        await #expect(throws: CocoaError.self) { try await export(exporter()) }
        #expect(files.folders.isEmpty)
    }

    /// RP-TS-08: `-uiTestMockPDF fail|slow` picks a failing or slow renderer; without it the live one.
    @Test func launchArgumentPicksTheRenderer() async throws {
        #expect(LaunchArguments(["-uiTestMockPDF", "fail"]).pdf == .fail)
        #expect(LaunchArguments(["-uiTestMockPDF", "slow"]).pdf == .slow)
        #expect(LaunchArguments(["-uiTestMockPDF", "other"]).pdf == nil)
        #expect(AppDependencies.pdfRenderer(for: LaunchArguments(["-uiTestMockPDF", "fail"])) is MockRoundPDFRenderer)
        #expect(AppDependencies.pdfRenderer(for: LaunchArguments(["-uiTestMockPDF", "slow"])) is MockRoundPDFRenderer)
        #expect(AppDependencies.pdfRenderer(for: LaunchArguments([])) is LiveRoundPDFRenderer)
    }

    /// The UI-test renderers: one throws, the slow one waits, then renders for real.
    @Test func mockRenderers() async throws {
        let model = RoundPDFModel.preview(holeCount: .nine, names: ["Mark"])
        let metadata = RoundPDFMetadata(title: "t", creator: "c", subject: "s")
        await #expect(throws: RoundPDFError.injected) { try await MockRoundPDFRenderer(behavior: .fail).render(model, metadata: metadata) }
        let data = try await MockRoundPDFRenderer(behavior: .slow(.milliseconds(1))).render(model, metadata: metadata)
        #expect(data.starts(with: Data("%PDF".utf8)))
    }

    /// The live file system round-trips a file inside a temporary sandbox.
    @Test func liveFileSystem() throws {
        let system = LiveRoundPDFFileSystem()
        let folder = system.temporaryDirectory.appending(path: "RoundPDFTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let file = folder.appending(path: "a.pdf")
        try system.createDirectory(at: folder)
        try system.write(Data("x".utf8), to: file)
        #expect(system.fileExists(at: file))
        try system.removeItem(at: folder)
        #expect(!system.fileExists(at: folder))
    }
}
