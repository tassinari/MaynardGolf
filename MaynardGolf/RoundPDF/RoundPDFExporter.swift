//
//  RoundPDFExporter.swift
//  MaynardGolf
//

import Foundation
import OSLog

/// The file operations the exporter needs (RP-AR-03), so its tests use a fake instead of the disk.
protocol RoundPDFFileSystem: Sendable {
    /// Where the exporter keeps its folder (the app's temporary directory).
    var temporaryDirectory: URL { get }
    func createDirectory(at url: URL) throws
    func write(_ data: Data, to url: URL) throws
    func removeItem(at url: URL) throws
    func fileExists(at url: URL) -> Bool
}

/// `FileManager` in the app's temporary directory.
struct LiveRoundPDFFileSystem: RoundPDFFileSystem {
    var temporaryDirectory: URL { FileManager.default.temporaryDirectory }

    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func write(_ data: Data, to url: URL) throws { try data.write(to: url, options: .atomic) }

    func removeItem(at url: URL) throws { try FileManager.default.removeItem(at: url) }

    func fileExists(at url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) }
}

/// Makes the round PDF when Share is tapped (15-round-pdf §5, RP-AR-03): builds the model off the main
/// actor, renders it, writes it to a fresh folder in the temporary directory for the share sheet and
/// removes the folder afterwards. Nothing is stored, synced or cached (RP-EX-03).
@MainActor
final class RoundPDFExporter {
    /// The folder under the temporary directory that holds one subfolder per share (RP-EX-03).
    static let folderName = "RoundPDF"

    private let renderer: RoundPDFRendering
    private let fileSystem: RoundPDFFileSystem
    private let appVersion: String
    private let locale: Locale
    private let calendar: Calendar
    private let makeID: @Sendable () -> UUID
    private let log = Logger(subsystem: "MaynardGolf", category: "RoundPDF")

    /// `appVersion` goes in the PDF's Creator; `makeID` names each share's folder (fixed in tests).
    init(renderer: RoundPDFRendering = LiveRoundPDFRenderer(), fileSystem: RoundPDFFileSystem = LiveRoundPDFFileSystem(),
         appVersion: String = Bundle.main.marketingVersion, locale: Locale = .current, calendar: Calendar = .current,
         makeID: @escaping @Sendable () -> UUID = { UUID() }) {
        self.renderer = renderer
        self.fileSystem = fileSystem
        self.appVersion = appVersion
        self.locale = locale
        self.calendar = calendar
        self.makeID = makeID
    }

    /// `{tmp}/RoundPDF`: everything the exporter writes is under here.
    var rootFolder: URL { fileSystem.temporaryDirectory.appending(path: Self.folderName, directoryHint: .isDirectory) }

    /// Writes the PDF for a round snapshot and returns its file URL (RP-EX-01…05). Throws when rendering or
    /// writing fails; nothing is left behind then.
    func export(round: RoundSnapshot, players: [PlayerSnapshot], course: Course) async throws -> URL {
        let (locale, calendar) = (locale, calendar)
        let model = await Task.detached(priority: .userInitiated) {
            RoundPDFModelBuilder.build(round: round, players: players, course: course, locale: locale, calendar: calendar)
        }.value
        let data = try await renderer.render(model, metadata: metadata(for: model))
        let folder = rootFolder.appending(path: makeID().uuidString, directoryHint: .isDirectory)
        let url = folder.appending(path: Self.fileName(for: model.title), directoryHint: .notDirectory)
        do {
            try fileSystem.createDirectory(at: folder)
            try fileSystem.write(data, to: url)
        } catch {
            cleanUp(url)
            throw error
        }
        return url
    }

    /// Removes a shared file's folder when the share sheet closes (RP-EX-03).
    func cleanUp(_ url: URL) {
        let folder = url.deletingLastPathComponent()
        guard fileSystem.fileExists(at: folder) else { return }
        do {
            try fileSystem.removeItem(at: folder)
        } catch {
            log.error("Couldn't remove a shared PDF: \(String(describing: error), privacy: .public)")
        }
    }

    /// Removes anything an earlier launch left behind, such as a share interrupted by the app quitting (RP-EX-03).
    func removeLeftovers() {
        guard fileSystem.fileExists(at: rootFolder) else { return }
        do {
            try fileSystem.removeItem(at: rootFolder)
        } catch {
            log.error("Couldn't remove leftover PDFs: \(String(describing: error), privacy: .public)")
        }
    }

    /// Title "Round · …", Creator "Maynard Golf {version}", Subject "Scorecard" (RP-EX-05).
    func metadata(for model: RoundPDFModel) -> RoundPDFMetadata {
        RoundPDFMetadata(
            title: model.title,
            creator: String(localized: "Maynard Golf \(appVersion)", comment: "Round PDF: the PDF's Creator, the app and its version, e.g. 'Maynard Golf 1.2'."),
            subject: String(localized: "roundPDF.subject", defaultValue: "Scorecard",
                            comment: "Round PDF: the PDF's Subject, e.g. 'Scorecard'."))
    }

    /// "Round · Maynard Golf Club · Nov 8.pdf", with "/" and ":" replaced by "-" (RP-EX-04).
    nonisolated static func fileName(for title: String) -> String {
        String(title.map { "/:".contains($0) ? "-" : $0 }) + ".pdf"
    }
}

extension Bundle {
    /// `CFBundleShortVersionString` ("1.2"), or "" when the bundle has none (unit-test hosts always do).
    var marketingVersion: String { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }
}
