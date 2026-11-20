//
//  CardSwipe.swift
//  MaynardGolf
//

import Foundation

/// Swipe-to-delete on Home's In-progress card as numbers (HOME-IPR-09, #211): how far the card follows the
/// finger, and what letting go does. Swiping left uncovers a Discard action; a long swipe asks straight away,
/// like a list's full swipe. Neither deletes: both lead to the same confirmation as the ✕ (HOME-IPR-08).
/// Home is a scroll view, not a `List`, so `.swipeActions` isn't available. Pure, 100 % unit coverage.
struct CardSwipe: Equatable, Sendable {
    /// The width of the uncovered Discard action, and how far an open card rests.
    static let actionWidth: Double = 88
    /// A swipe that ends past this share of the card's width asks to discard (a full swipe).
    static let fullSwipeShare = 0.6
    /// Seconds of a flick's speed added to where it let go, so a quick flick opens the card.
    static let flickProjection = 0.2

    /// What letting go does.
    enum Release: Equatable, Sendable {
        /// The card springs back.
        case close
        /// The card rests open on the Discard action.
        case open
        /// A full swipe: the card springs back and the confirmation opens.
        case discard
    }

    /// Whether the card rests open on the Discard action.
    private(set) var isOpen = false

    /// Where the card rests: 0 closed, `-actionWidth` open.
    var restingOffset: Double { isOpen ? -Self.actionWidth : 0 }

    /// The card's offset while a swipe of `translation` points is under way: it follows the finger left of
    /// where it rested, never right of closed nor past its own width.
    func offset(translation: Double, width: Double) -> Double {
        min(0, max(restingOffset + translation, -max(width, 0)))
    }

    /// Lets go of a swipe of `translation` points at `velocity` points per second over a card `width` wide.
    /// Past `fullSwipeShare` of the width it asks to discard; past half the action (flicks projected) it rests
    /// open; otherwise it closes.
    mutating func release(translation: Double, velocity: Double, width: Double) -> Release {
        let ended = offset(translation: translation, width: width)
        let projected = offset(translation: translation + velocity * Self.flickProjection, width: width)
        let result: Release
        if width > 0, ended <= -width * Self.fullSwipeShare {
            result = .discard
        } else if projected <= -Self.actionWidth / 2 {
            result = .open
        } else {
            result = .close
        }
        isOpen = result == .open
        return result
    }

    /// Closes an open card: a tap on it, its Discard action, or a swipe the system cancelled.
    mutating func close() {
        isOpen = false
    }
}
