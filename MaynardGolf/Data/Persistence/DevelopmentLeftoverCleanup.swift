//
//  DevelopmentLeftoverCleanup.swift
//  MaynardGolf
//

import Foundation
import os

/// The file operations the cleanup needs, injected so tests can run in a sandbox and fail on purpose.
protocol LeftoverFileSystem: Sendable {
    func fileExists(at url: URL) -> Bool
    func removeItem(at url: URL) throws
}

/// The real file system.
struct SystemLeftoverFileSystem: LeftoverFileSystem {
    func fileExists(at url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) }
    func removeItem(at url: URL) throws { try FileManager.default.removeItem(at: url) }
}

/// Deletes what an earlier development build left behind, once, on first launch (DM-MG-02):
/// `default.store` with its `-wal` / `-shm` files in Application Support, and the `Documents/pics/`
/// photo folder. It never touches `MaynardGolf.store`. A file that can't be deleted is logged and
/// skipped; the app still opens its store (DM-TS-52).
struct DevelopmentLeftoverCleanup {
    /// The UserDefaults key that records the cleanup has run.
    static let didRunKey = "dataModel.didRemoveDevelopmentLeftovers"

    let applicationSupport: URL
    let documents: URL
    let fileSystem: LeftoverFileSystem
    let defaults: UserDefaults
    private let log = Logger(subsystem: "MaynardGolf", category: "Persistence")

    init(applicationSupport: URL, documents: URL, fileSystem: LeftoverFileSystem = SystemLeftoverFileSystem(),
         defaults: UserDefaults = .standard) {
        self.applicationSupport = applicationSupport
        self.documents = documents
        self.fileSystem = fileSystem
        self.defaults = defaults
    }

    /// The app's own folders.
    static func live() throws -> DevelopmentLeftoverCleanup {
        let fm = FileManager.default
        return DevelopmentLeftoverCleanup(
            applicationSupport: try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true),
            documents: try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
    }

    /// The leftovers this cleanup removes.
    var leftovers: [URL] {
        ["default.store", "default.store-wal", "default.store-shm"].map { applicationSupport.appending(path: $0) }
            + [documents.appending(path: "pics", directoryHint: .isDirectory)]
    }

    /// Removes the leftovers the first time it's called; later calls do nothing. Returns what it removed.
    @discardableResult
    func runOnce() -> [URL] {
        guard !defaults.bool(forKey: Self.didRunKey) else { return [] }
        var removed: [URL] = []
        for url in leftovers where fileSystem.fileExists(at: url) {
            do {
                try fileSystem.removeItem(at: url)
                removed.append(url)
            } catch {
                log.error("Couldn't remove \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
        defaults.set(true, forKey: Self.didRunKey)
        return removed
    }
}
