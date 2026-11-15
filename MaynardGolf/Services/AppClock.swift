//
//  AppClock.swift
//  MaynardGolf
//

import Foundation

/// "Now", injected so tests, previews and UI tests (`-uiTestFixedDate`) control time (TS-UT-04).
protocol AppClock: Sendable {
    var now: Date { get }
}

/// The real time.
struct SystemClock: AppClock {
    var now: Date { Date.now }
}

/// Always the same moment.
struct FixedClock: AppClock {
    let now: Date
}
