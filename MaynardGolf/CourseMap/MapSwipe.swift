//
//  MapSwipe.swift
//  MaynardGolf
//

import Foundation

/// The swipe between holes as numbers (16-hole-map HM-TR-01, 02): which way a drag heads, how far along
/// the camera move it is, and whether letting go finishes it. Pure, 100 % unit coverage.
enum MapSwipe {
    /// How long the camera move takes when nothing drives it: auto-advance and VoiceOver (HM-TR-03).
    static let flyDuration = 0.9
    /// How long a released drag takes to finish (or spring back) from where the finger let go (HM-TR-02).
    static let settleDuration = 0.5

    /// Which way a drag is heading: dragging left (negative) goes to the next hole (+1), right to the
    /// previous (−1), none 0.
    static func direction(forTranslation translation: Double) -> Int {
        translation < 0 ? 1 : (translation > 0 ? -1 : 0)
    }

    /// The camera move's progress 0…1 for a drag of `translation` points across a screen `width` wide.
    static func progress(translation: Double, width: Double) -> Double {
        guard width > 0 else { return 0 }
        return min(abs(translation) / width, 1)
    }

    /// Whether letting go finishes the move: +1 (next hole), −1 (previous) or 0 (spring back). It finishes
    /// past halfway, or when a flick's predicted end gets past halfway (HM-TR-02).
    static func change(translation: Double, predictedTranslation: Double, width: Double) -> Int {
        guard width > 0 else { return 0 }
        let distance = abs(predictedTranslation) > abs(translation) ? predictedTranslation : translation
        guard abs(distance) >= width / 2 else { return 0 }
        return direction(forTranslation: distance)
    }

    /// What a move to `destination` does (HM-TR-06, 07, 08).
    enum Plan: Equatable, Sendable {
        /// Nothing: past either end of the round, or another move is still settling.
        case none
        /// Swap to the hole with a crossfade: Reduce Motion, the move's pieces aren't loaded yet, or the
        /// camera was turned toward a different hole.
        case crossfade(Int)
        /// Pan, turn and zoom to the hole.
        case animate(Int)
    }

    /// Decides a move to `destination` (nil past either end of the round). `heading` is the hole the camera
    /// is already turned toward, if a drag started one.
    static func plan(destination: Int?, heading: Int?, piecesLoaded: Bool, reduceMotion: Bool, isSettling: Bool) -> Plan {
        guard !isSettling, let destination else { return .none }
        guard !reduceMotion, piecesLoaded, heading == nil || heading == destination else { return .crossfade(destination) }
        return .animate(destination)
    }

    /// The hole the hole card shows during a move: the one being moved toward from halfway (HM-TR-04).
    static func displayedHole(current: Int, target: Int?, progress: Double) -> Int {
        if let target, progress >= 0.5 { return target }
        return current
    }

    /// The time left to finish a move that's at `progress`, so a drag let go near the end settles fast.
    static func remaining(_ duration: Double, from progress: Double) -> Double {
        duration * (1 - min(max(progress, 0), 1)) + 0.05
    }
}
