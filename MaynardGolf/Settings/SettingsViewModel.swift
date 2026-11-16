//
//  SettingsViewModel.swift
//  MaynardGolf
//

import Foundation
import Observation

/// What the Settings screen shows and changes (SET-DT-02): the option values, read from and written to the
/// shared `SettingsStore`, the course's tees for the Default tees picker, and the local-rules row.
@MainActor
@Observable
final class SettingsViewModel {
    private let settings: SettingsStore
    /// The course, or nil when its data can't be loaded; the tee picker and local-rules row then hide.
    let course: Course?

    init(settings: SettingsStore, courses: CourseProvider, courseID: String = AppDependencies.courseID) {
        self.settings = settings
        course = try? courses.course(id: courseID)
    }

    var showToPar: Bool {
        get { settings.showToPar }
        set { settings.showToPar = newValue }
    }

    var showShotLine: Bool {
        get { settings.showShotLine }
        set { settings.showShotLine = newValue }
    }

    var autoAdvance: Bool {
        get { settings.autoAdvance }
        set { settings.autoAdvance = newValue }
    }

    var defaultTee: Tee {
        get { settings.defaultTee }
        set { settings.defaultTee = newValue }
    }

    /// The tees to choose from, in the course's order: Blue, White, Yellow, Red (SET-OPT-04).
    var tees: [TeeInfo] { course?.tees ?? [] }

    /// The chosen tee's details, for the row's dot and name.
    var defaultTeeInfo: TeeInfo? { tees.first { $0.id == defaultTee } }

    /// The local-rules row's title and subtitle: "Maynard Golf Club", "12 local rules" (SET-LR-02). Nil
    /// when the course is missing or has no rules.
    var localRulesSummary: (title: String, subtitle: String)? {
        guard let course, !course.localRules.isEmpty else { return nil }
        return (course.name, Plurals.localRules(course.localRules.count))
    }
}
