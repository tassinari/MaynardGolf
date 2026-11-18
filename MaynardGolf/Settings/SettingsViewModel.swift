//
//  SettingsViewModel.swift
//  MaynardGolf
//

import Foundation
import UIKit
import Observation
import OSLog

/// The app's version and build and the device it runs on, for the Version row and the feedback mail
/// (SET-AB-02, 04). Read at runtime, never hard-coded; injected so tests and previews use fixed values.
struct AboutInfo: Equatable, Sendable {
    let version: String
    let build: String
    /// "iPhone18,1".
    let device: String
    /// "iOS 27.1".
    let system: String

    /// Reads the version and build from an Info.plist dictionary; a missing dictionary or value reads as "?".
    init(info: [String: Any]?, device: String, system: String) {
        version = info?["CFBundleShortVersionString"] as? String ?? "?"
        build = info?["CFBundleVersion"] as? String ?? "?"
        self.device = device
        self.system = system
    }

    /// The running app and device.
    @MainActor static var live: AboutInfo {
        var system = utsname()
        uname(&system)
        let machine = withUnsafeBytes(of: &system.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        return AboutInfo(info: Bundle.main.infoDictionary, device: machine,
                         system: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
    }
}

/// What the Settings screen shows and changes (SET-DT-02): the option values, read from and written to the
/// shared `SettingsStore`, the course's tees for the Default tees picker, and the local-rules row.
@MainActor
@Observable
final class SettingsViewModel {
    private let settings: SettingsStore
    /// The course, or nil when its data can't be loaded; the tee picker and local-rules row then hide.
    let course: Course?
    /// The version, build and device, for About (SET-AB-02, 04).
    let about: AboutInfo

    init(settings: SettingsStore, courses: CourseProvider, courseID: String = AppDependencies.courseID, about: AboutInfo) {
        self.settings = settings
        self.about = about
        do {
            course = try courses.course(id: courseID)
        } catch {
            // The rows hide (SET-DT-02); Home reports the missing course to the user (DM-CD-06).
            Logger(subsystem: "MaynardGolf", category: "Settings")
                .error("Course \(courseID, privacy: .public) couldn't be loaded: \(String(describing: error), privacy: .public)")
            course = nil
        }
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
        guard let course, course.hasRules else { return nil }
        return (course.name, Plurals.localRules(course.localRules.count))
    }

    // MARK: About (SET-AB-01…09)

    /// "1.2 (211)": the version and build from the bundle (SET-AB-02).
    var versionText: String { "\(about.version) (\(about.build))" }

    /// The feedback mail's subject (SET-AB-04).
    var feedbackSubject: String {
        String(localized: "Maynard Golf feedback", comment: "Settings: the subject of the feedback mail.")
    }

    /// The feedback mail's body: room to write, then the app version and device (SET-AB-04).
    var feedbackBody: String {
        let details = String(localized: "Maynard Golf \(versionText) on \(about.device), \(about.system)",
                             comment: "Settings: the app and device details at the end of the feedback mail, e.g. 'Maynard Golf 1.2 (211) on iPhone18,1, iOS 27.1'.")
        return "\n\n\n— \n\(details)"
    }

    /// The `mailto:` fallback when Mail can't compose in the app (SET-AB-04).
    var feedbackMailto: URL? { AppLinks.feedbackMailto(subject: feedbackSubject, body: feedbackBody) }
}
