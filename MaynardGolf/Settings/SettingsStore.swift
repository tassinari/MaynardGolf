//
//  SettingsStore.swift
//  MaynardGolf
//

import Foundation
import Observation

/// Where settings are kept: a small key-value store, injected so tests and previews never touch
/// `UserDefaults.standard` (SET-DT-01, TS-UT-04).
///
/// *Why a storage protocol under one `SettingsStore` class, rather than two `SettingsStore`
/// implementations:* the defaults, the fallbacks for unknown stored values and the observation then
/// live in one place, and the two storages only read and write values.
protocol SettingsStorage: AnyObject {
    func value(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

/// `UserDefaults` storage, for the app.
final class UserDefaultsSettingsStorage: SettingsStorage {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func value(forKey key: String) -> Any? { defaults.object(forKey: key) }
    func set(_ value: Any?, forKey key: String) { defaults.set(value, forKey: key) }
}

/// In-memory storage, for tests, previews and UI tests (which must start from the defaults every launch).
final class InMemorySettingsStorage: SettingsStorage {
    private var values: [String: Any]

    init(_ values: [String: Any] = [:]) { self.values = values }

    func value(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
}

/// The app's settings (02-settings §6, SET-OPT-01…04, NR-HOL-02). Observable, so every screen that reads
/// a value updates as soon as it changes (SET-DT-03); each change is written straight to storage, with
/// no Save step.
@MainActor
@Observable
final class SettingsStore {
    /// The storage keys, namespaced `settings.*` (SET-DT-01).
    enum Key: String, CaseIterable {
        case showToPar = "settings.showToPar"
        case showShotLine = "settings.showShotLine"
        case autoAdvance = "settings.autoAdvance"
        case defaultTee = "settings.defaultTee"
        case lastHoleCount = "settings.lastHoleCount"
    }

    /// Show to-par scores instead of gross totals (SET-OPT-01). Default on.
    var showToPar: Bool { didSet { storage.set(showToPar, forKey: Key.showToPar.rawValue) } }
    /// Show the shot line on the hole map (SET-OPT-02). Default on.
    var showShotLine: Bool { didSet { storage.set(showShotLine, forKey: Key.showShotLine.rawValue) } }
    /// Move to the next hole once every score is in (SET-OPT-03). Default off.
    var autoAdvance: Bool { didSet { storage.set(autoAdvance, forKey: Key.autoAdvance.rawValue) } }
    /// The tee New round preselects (SET-OPT-04, NR-TEE-05). Default White.
    var defaultTee: Tee { didSet { storage.set(defaultTee.rawValue, forKey: Key.defaultTee.rawValue) } }
    /// The hole count used last, New round's default; set on Tee off (NR-HOL-02). Default 9.
    var lastHoleCount: HoleCount { didSet { storage.set(lastHoleCount.rawValue, forKey: Key.lastHoleCount.rawValue) } }

    /// Where the values are kept (internal, so tests can check which storage a store uses).
    @ObservationIgnored let storage: SettingsStorage

    /// Reads every value once. A missing value, or one of the wrong type, reads as its default; an unknown
    /// tee or hole count reads as White or 9 (DM-EN-05).
    init(storage: SettingsStorage) {
        self.storage = storage
        showToPar = storage.value(forKey: Key.showToPar.rawValue) as? Bool ?? true
        showShotLine = storage.value(forKey: Key.showShotLine.rawValue) as? Bool ?? true
        autoAdvance = storage.value(forKey: Key.autoAdvance.rawValue) as? Bool ?? false
        defaultTee = (storage.value(forKey: Key.defaultTee.rawValue) as? String).map(Tee.init(storedValue:)) ?? .fallback
        lastHoleCount = (storage.value(forKey: Key.lastHoleCount.rawValue) as? Int).map(HoleCount.init(storedValue:)) ?? .fallback
    }

    /// Settings kept in `UserDefaults`, for the app.
    static func live(defaults: UserDefaults = .standard) -> SettingsStore {
        SettingsStore(storage: UserDefaultsSettingsStorage(defaults: defaults))
    }

    /// Settings kept in memory, starting from the defaults (or the given values), for tests and previews.
    static func inMemory(_ values: [Key: Any] = [:]) -> SettingsStore {
        SettingsStore(storage: InMemorySettingsStorage(Dictionary(uniqueKeysWithValues: values.map { ($0.key.rawValue, $0.value) })))
    }
}
