//
//  DataTestSupport.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
@testable import MaynardGolf

/// Containers made by `makeContext`, kept alive for the whole test run: a `ModelContext` doesn't keep
/// its container alive, and using a context whose container was freed crashes.
@MainActor private var retainedContainers: [ModelContainer] = []

/// The main context of a new container (in memory by default, so nothing touches the on-disk store).
@MainActor
func makeContext(_ configuration: PersistenceController.Configuration = .inMemory) throws -> ModelContext {
    let container = try PersistenceController.makeContainer(configuration)
    retainedContainers.append(container)
    return container.mainContext
}

/// A fresh in-memory container per test (12-data-model §9).
@MainActor
func makeInMemoryContext() throws -> ModelContext {
    try makeContext(.inMemory)
}

/// A store file in a new temporary folder, for tests that need persistent history or reopening.
struct TemporaryStore {
    let folder: URL
    var url: URL { folder.appending(path: "Test.store") }

    init() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "MaynardGolfTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: folder) }
}

/// Fixed dates (an injected clock, not `.now`).
enum TestDates {
    static let teeOff = ModelFixtures.referenceDate
    static func minutes(_ m: Double) -> Date { teeOff.addingTimeInterval(m * 60) }
}
