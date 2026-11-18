//
//  AboutInfo.swift
//  MaynardGolf
//

import Foundation
import UIKit

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
