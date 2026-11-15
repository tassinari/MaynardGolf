//
//  AppModel.swift
//  MaynardGolf
//

import Foundation
import Observation
import SwiftData

/// Launches the app (#18): removes development leftovers once (live store only), opens the store through
/// `PersistenceLoader` (the error boundary, DM-SC-05), then builds the dependencies.
@Observable
@MainActor
final class AppModel {
    enum State {
        case loading
        case ready(AppDependencies)
        case failed(PersistenceError)
    }

    private(set) var state: State = .loading
    @ObservationIgnored private let arguments: LaunchArguments
    @ObservationIgnored private let loader: PersistenceLoader
    @ObservationIgnored private let prepare: @MainActor () -> Void

    /// `factory` opens the store and `prepare` runs first (the leftover cleanup); both are injected for tests.
    init(arguments: LaunchArguments, factory: @escaping @MainActor () throws -> ModelContainer,
         prepare: @escaping @MainActor () -> Void = {}) {
        self.arguments = arguments
        self.loader = PersistenceLoader(factory: factory)
        self.prepare = prepare
    }

    /// The real launch for these arguments.
    static func live(arguments: LaunchArguments = LaunchArguments()) -> AppModel {
        let configuration = AppDependencies.configuration(for: arguments)
        return AppModel(arguments: arguments, factory: {
            if arguments.corruptStore { throw PersistenceError(underlying: "Injected corrupt store (-uiTestCorruptStore)") }
            return try PersistenceController.makeContainer(configuration)
        }, prepare: {
            guard case .live = configuration else {
                if arguments.leftoverStore { Self.plantAndRemoveLeftovers() }
                return
            }
            _ = try? DevelopmentLeftoverCleanup.live().runOnce()
        })
    }

    /// Opens the store; also what Try again calls.
    func load() {
        prepare()
        loader.load()
        switch loader.state {
        case .ready(let container): state = .ready(AppDependencies.make(container: container, arguments: arguments))
        case .failed(let error): state = .failed(error)
        case .loading: state = .loading
        }
    }

    /// `-uiTestLeftoverStore`: plants an old development store and photo folder in the app's sandbox,
    /// then runs the cleanup, as a first launch after an earlier build would (DM-MG-02).
    private static func plantAndRemoveLeftovers() {
        guard let cleanup = try? DevelopmentLeftoverCleanup.live() else { return }
        let fm = FileManager.default
        for url in cleanup.leftovers {
            if url.lastPathComponent == "pics" {
                try? fm.createDirectory(at: url, withIntermediateDirectories: true)
            } else {
                fm.createFile(atPath: url.path(percentEncoded: false), contents: Data("old".utf8))
            }
        }
        UserDefaults.standard.removeObject(forKey: DevelopmentLeftoverCleanup.didRunKey)
        cleanup.runOnce()
    }
}
