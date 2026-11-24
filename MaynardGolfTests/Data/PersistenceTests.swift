//
//  PersistenceTests.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
import Testing
@testable import MaynardGolf

/// DM-TS-50, 60, 61 and the CloudKit compatibility check (DM-TS-16, IC-TS-01).
@MainActor
struct PersistenceTests {
    @Test func schemaIsTheBaselineWithNoStages() {
        #expect(MaynardSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(MaynardSchemaV1.models.map { String(describing: $0) } == ["Player", "Round", "RoundEntry", "OutsideCourse", "OutsideScore"])
        #expect(MaynardMigrationPlan.schemas.count == 1)
        #expect(MaynardMigrationPlan.stages.isEmpty)
        #expect(PersistenceController.storeFileName == "MaynardGolf.store")
    }

    /// DM-SC-09: the CloudKit-synced live store never prunes history; the others keep a week.
    @Test func historyRetentionComesFromTheConfiguration() throws {
        #expect(PersistenceController.Configuration.live.historyRetention == nil)
        #expect(PersistenceController.Configuration.inMemory.historyRetention == HistoryProcessor.localRetention)
        #expect(PersistenceController.Configuration.file(URL(filePath: "/tmp/x.store")).historyRetention == HistoryProcessor.localRetention)
        #expect(PersistenceController.Configuration.seeded(.onePlayer).historyRetention == HistoryProcessor.localRetention)
        #expect(PersistenceController.Configuration.preview(.onePlayer).historyRetention == HistoryProcessor.localRetention)
    }

    @Test func theLiveStoreIsInApplicationSupport() throws {
        let url = try PersistenceController.liveStoreURL()
        #expect(url.lastPathComponent == "MaynardGolf.store")
        #expect(url.deletingLastPathComponent().lastPathComponent == "Application Support")
    }

    /// DM-TS-50: a new store starts empty and keeps what's written when reopened.
    @Test func aNewStoreStartsEmptyAndReopens() throws {
        let store = try TemporaryStore()
        defer { store.remove() }
        do {
            let context = try makeContext(.file(store.url))
            #expect(try context.fetchCount(FetchDescriptor<Player>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<Round>()) == 0)
            try ModelFixtures.completedRound(players: [ModelFixtures.player("Mark", in: context)], in: context)
            try context.save()
        }
        let reopened = try makeContext(.file(store.url))
        #expect(try reopened.fetch(FetchDescriptor<Player>()).map(\.firstName) == ["Mark"])
        #expect(try reopened.fetchCount(FetchDescriptor<RoundEntry>()) == 1)
    }

    /// DM-TS-60: containers are isolated from each other.
    @Test func containersDontShareData() throws {
        let a = try makeContext(.inMemory)
        let b = try makeContext(.inMemory)
        a.insert(Player(firstName: "OnlyInA"))
        try a.save()
        #expect(try b.fetchCount(FetchDescriptor<Player>()) == 0)

        let seeded = try makeContext(.seeded(.twoPlayers))
        let preview = try makeContext(.preview(.twoPlayers))
        seeded.insert(Player(firstName: "Extra"))
        try seeded.save()
        #expect(try seeded.fetchCount(FetchDescriptor<Player>()) == 3)
        #expect(try preview.fetchCount(FetchDescriptor<Player>()) == 2)
    }

    /// DM-TS-61: a container failure becomes the error state, and Retry calls the factory again.
    @Test func aFailureIsAStateAndRetryTriesAgain() throws {
        let factory = FlakyFactory()
        let loader = PersistenceLoader { try factory.make() }
        guard case .loading = loader.state else { Issue.record("starts loading"); return }
        loader.load()
        guard case .failed(let failure) = loader.state else { Issue.record("expected failure"); return }
        #expect(failure.underlying.contains("Broken"))
        factory.shouldFail = false
        loader.load()
        guard case .ready = loader.state else { Issue.record("expected ready after retry"); return }
        #expect(factory.attempts == 2)
    }

    /// IC-TS-01: every model can sync through CloudKit (DM-SC-08).
    @Test func everyModelIsCloudKitCompatible() {
        let schema = Schema(versionedSchema: MaynardSchemaV1.self)
        #expect(schema.entities.count == 5)
        for entity in schema.entities {
            #expect(entity.uniquenessConstraints.isEmpty, "\(entity.name) has a unique constraint")
            for attribute in entity.attributes {
                #expect(!attribute.isUnique, "\(entity.name).\(attribute.name) is unique")
                #expect(attribute.isOptional || attribute.defaultValue != nil,
                        "\(entity.name).\(attribute.name) needs a default or must be optional")
            }
            for relationship in entity.relationships {
                #expect(relationship.isOptional, "\(entity.name).\(relationship.name) must be optional")
                #expect(relationship.inverseName != nil, "\(entity.name).\(relationship.name) needs an inverse")
            }
        }
    }

    @Test func photosUseExternalStorage() throws {
        let schema = Schema(versionedSchema: MaynardSchemaV1.self)
        let player = try #require(schema.entities.first { $0.name == "Player" })
        let photo = try #require(player.attributes.first { $0.name == "photoData" })
        #expect(photo.options.contains(.externalStorage))
    }
}

/// Fails until told not to, counting attempts.
@MainActor
private final class FlakyFactory {
    struct Broken: Error {}
    var attempts = 0
    var shouldFail = true

    func make() throws -> ModelContainer {
        attempts += 1
        if shouldFail { throw Broken() }
        return try PersistenceController.makeContainer(.inMemory)
    }
}

/// DM-TS-51, 52: removing development leftovers.
struct DevelopmentLeftoverCleanupTests {
    private final class FailingFileSystem: LeftoverFileSystem, @unchecked Sendable {
        struct Denied: Error {}
        var removed: [String] = []
        func fileExists(at url: URL) -> Bool { true }
        func removeItem(at url: URL) throws {
            if url.lastPathComponent == "default.store" { throw Denied() }
            removed.append(url.lastPathComponent)
        }
    }

    private func sandbox() throws -> (URL, URL, UserDefaults, String) {
        let root = FileManager.default.temporaryDirectory.appending(path: "Leftovers-\(UUID().uuidString)")
        let support = root.appending(path: "Application Support")
        let documents = root.appending(path: "Documents")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: documents.appending(path: "pics"), withIntermediateDirectories: true)
        let suite = "MaynardGolfTests.cleanup.\(UUID().uuidString)"
        return (support, documents, UserDefaults(suiteName: suite)!, suite)
    }

    /// DM-TS-51: leftovers go once; the new store and other files stay.
    @Test func removesLeftoversOnceAndKeepsTheNewStore() throws {
        let (support, documents, defaults, suite) = try sandbox()
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: support.deletingLastPathComponent()) }
        for name in ["default.store", "default.store-wal", "default.store-shm", "MaynardGolf.store"] {
            FileManager.default.createFile(atPath: support.appending(path: name).path, contents: Data([1]))
        }
        FileManager.default.createFile(atPath: documents.appending(path: "pics/old.jpg").path, contents: Data([1]))
        let cleanup = DevelopmentLeftoverCleanup(applicationSupport: support, documents: documents, defaults: defaults)

        let removed = cleanup.runOnce()
        #expect(removed.map(\.lastPathComponent).sorted() == ["default.store", "default.store-shm", "default.store-wal", "pics"])
        #expect(FileManager.default.fileExists(atPath: support.appending(path: "MaynardGolf.store").path))
        #expect(!FileManager.default.fileExists(atPath: documents.appending(path: "pics").path))

        // A leftover appearing later isn't touched: the cleanup only runs once.
        FileManager.default.createFile(atPath: support.appending(path: "default.store").path, contents: Data([1]))
        #expect(cleanup.runOnce().isEmpty)
        #expect(FileManager.default.fileExists(atPath: support.appending(path: "default.store").path))
    }

    @Test func nothingToRemoveIsFine() throws {
        let (support, documents, defaults, suite) = try sandbox()
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: support.deletingLastPathComponent()) }
        try FileManager.default.removeItem(at: documents.appending(path: "pics"))
        #expect(DevelopmentLeftoverCleanup(applicationSupport: support, documents: documents, defaults: defaults).runOnce().isEmpty)
        #expect(defaults.bool(forKey: DevelopmentLeftoverCleanup.didRunKey))
    }

    /// DM-TS-52: a file that can't be deleted is skipped; the rest still go and the run is recorded.
    @Test func aFailureIsSkipped() throws {
        let (support, documents, defaults, suite) = try sandbox()
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: support.deletingLastPathComponent()) }
        let fs = FailingFileSystem()
        let removed = DevelopmentLeftoverCleanup(applicationSupport: support, documents: documents, fileSystem: fs, defaults: defaults).runOnce()
        #expect(!removed.map(\.lastPathComponent).contains("default.store"))
        #expect(fs.removed == ["default.store-wal", "default.store-shm", "pics"])
        #expect(defaults.bool(forKey: DevelopmentLeftoverCleanup.didRunKey))
    }

    @Test func theLiveCleanupUsesTheAppFolders() throws {
        let cleanup = try DevelopmentLeftoverCleanup.live()
        #expect(cleanup.applicationSupport.lastPathComponent == "Application Support")
        #expect(cleanup.documents.lastPathComponent == "Documents")
        #expect(cleanup.leftovers.count == 4)
        #expect(SystemLeftoverFileSystem().fileExists(at: cleanup.documents))
    }
}
