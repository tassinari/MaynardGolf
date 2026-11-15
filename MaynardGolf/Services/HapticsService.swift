//
//  HapticsService.swift
//  MaynardGolf
//

import Foundation
import UIKit

/// The haptic moments the app uses.
enum HapticEvent: Equatable, Sendable {
    case selection, success, warning
}

/// Plays haptics, respecting the Haptics setting (02-settings).
@MainActor
protocol HapticsProviding: AnyObject {
    func play(_ event: HapticEvent)
}

/// What actually makes the feedback, injected so tests can count calls.
@MainActor
protocol HapticPerformer: AnyObject {
    func perform(_ event: HapticEvent)
}

/// UIKit feedback generators.
@MainActor
final class UIKitHapticPerformer: HapticPerformer {
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    func perform(_ event: HapticEvent) {
        switch event {
        case .selection: selection.selectionChanged()
        case .success: notification.notificationOccurred(.success)
        case .warning: notification.notificationOccurred(.warning)
        }
    }
}

/// Plays through `performer` only while `isEnabled()` is true (the Settings toggle, #30).
@MainActor
final class HapticsService: HapticsProviding {
    private let performer: HapticPerformer
    private let isEnabled: @MainActor () -> Bool

    init(performer: HapticPerformer, isEnabled: @escaping @MainActor () -> Bool) {
        self.performer = performer
        self.isEnabled = isEnabled
    }

    func play(_ event: HapticEvent) {
        guard isEnabled() else { return }
        performer.perform(event)
    }
}
