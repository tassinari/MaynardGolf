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

/// Plays haptics. There's no in-app Haptics setting; the system setting applies (HP-ES-08).
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

/// Plays every event through `performer`; the system's own haptics setting decides whether it's felt.
@MainActor
final class HapticsService: HapticsProviding {
    private let performer: HapticPerformer

    init(performer: HapticPerformer) {
        self.performer = performer
    }

    func play(_ event: HapticEvent) {
        performer.perform(event)
    }
}
