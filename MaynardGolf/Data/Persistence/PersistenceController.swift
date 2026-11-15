//
//  PersistenceController.swift
//  MaynardGolf
//

import Foundation
import Observation
import SwiftData
import os

/// Builds the app's one `ModelContainer` (DM-SC-03, DM-SC-04).
enum PersistenceController {
    /// Where the store lives and what it starts with.
    enum Configuration: Sendable {
        /// `MaynardGolf.store` in Application Support, synced to the user's private CloudKit database
        /// when the iCloud entitlement is present (`.automatic`; 13-icloud-sync, #96).
        case live
        /// In memory, empty. Unit tests.
        case inMemory
        /// A store file at a given URL, without CloudKit. Tests that need persistent history or reopening.
        case file(URL)
        #if DEBUG
        /// In memory, filled with a named data set. UI tests (`-uiTestSeed`, DM-TS-01).
        case seeded(Fixture)
        /// In memory, filled with a named data set. SwiftUI previews (TS-VS-05).
        case preview(Fixture)
        #endif
    }

    /// The store file name (DM-SC-03). Never the old `default.store`, so an earlier development store is never opened.
    static let storeFileName = "MaynardGolf.store"

    /// `MaynardGolf.store` in the app's Application Support folder.
    static func liveStoreURL(fileManager: FileManager = .default) throws -> URL {
        let support = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                          appropriateFor: nil, create: true)
        return support.appending(path: storeFileName)
    }

    /// Makes a container for `configuration` with `MaynardSchemaV1` and the stage-less migration plan.
    /// Throws instead of crashing; the caller shows the error state (DM-SC-05).
    @MainActor
    static func makeContainer(_ configuration: Configuration) throws -> ModelContainer {
        let schema = Schema(versionedSchema: MaynardSchemaV1.self)
        let modelConfiguration: ModelConfiguration
        switch configuration {
        case .live:
            modelConfiguration = ModelConfiguration(schema: schema, url: try liveStoreURL(), cloudKitDatabase: .automatic)
        case .file(let url):
            modelConfiguration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        case .inMemory:
            modelConfiguration = inMemoryConfiguration(schema)
        #if DEBUG
        case .seeded, .preview:
            modelConfiguration = inMemoryConfiguration(schema)
        #endif
        }
        let container = try ModelContainer(for: schema, migrationPlan: MaynardMigrationPlan.self,
                                           configurations: [modelConfiguration])
        #if DEBUG
        switch configuration {
        case .seeded(let fixture), .preview(let fixture):
            try fixture.populate(container.mainContext)
        default:
            break
        }
        #endif
        return container
    }

    /// A uniquely named in-memory store, so two containers never share data (DM-TS-60).
    private static func inMemoryConfiguration(_ schema: Schema) -> ModelConfiguration {
        ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    }
}

/// Why the store couldn't be opened, kept as text so it can cross actors and be logged.
struct PersistenceError: Error, Equatable, Sendable {
    let underlying: String
}

/// Opens the store and owns the result, so the app can show "Your data couldn't be opened" with
/// Retry instead of crashing (DM-SC-05, DM-TS-61). The error screen itself is part of the app shell (#14).
@Observable
@MainActor
final class PersistenceLoader {
    enum State {
        case loading
        case ready(ModelContainer)
        case failed(PersistenceError)
    }

    private(set) var state: State = .loading
    @ObservationIgnored private let factory: @MainActor () throws -> ModelContainer
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "Persistence")

    /// `factory` builds the container; the live app passes `PersistenceController.makeContainer(.live)`,
    /// tests pass one that fails.
    init(factory: @escaping @MainActor () throws -> ModelContainer) {
        self.factory = factory
    }

    /// Tries to open the store. Also what Retry calls.
    func load() {
        do {
            state = .ready(try factory())
        } catch {
            log.error("Couldn't open the store: \(String(describing: error), privacy: .public)")
            state = .failed(PersistenceError(underlying: String(describing: error)))
        }
    }
}
