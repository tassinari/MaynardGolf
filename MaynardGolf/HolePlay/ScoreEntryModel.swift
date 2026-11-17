//
//  ScoreEntryModel.swift
//  MaynardGolf
//

import Foundation
import MaynardUI

/// The Enter score sheet's value (HP-DT-03, HP-ES-03…06): one player's strokes on one hole, kept in
/// 1…12, starting from their saved score or par, with its name and the four quick picks. Pure, 100 %
/// unit coverage.
struct ScoreEntryModel: Equatable, Sendable {
    /// The stepper's range (HP-ES-03): 12 is a fixed bound, not the net double-bogey posting cap.
    static let range = 1...12

    let par: Int
    /// The strokes shown, always in `range`.
    private(set) var value: Int

    /// Starts from `saved` if there's one, otherwise par (HP-ES-04); clamped to `range`.
    init(par: Int, saved: Int?) {
        self.par = par
        value = Self.clamped(saved ?? par)
    }

    /// "Birdie", "Par", "Ace" … for the badge (HP-ES-05).
    var name: ScoreFormatter.ScoreName { ScoreFormatter.scoreName(score: value, par: par) }

    var canDecrease: Bool { value > Self.range.lowerBound }
    var canIncrease: Bool { value < Self.range.upperBound }

    /// Par − 1 … par + 2, inside `range` (HP-ES-06): 3, 4, 5, 6 on a par 4.
    var quickPicks: [Int] { (par - 1...par + 2).filter(Self.range.contains) }

    mutating func decrease() { value = Self.clamped(value - 1) }
    mutating func increase() { value = Self.clamped(value + 1) }

    /// A quick pick or VoiceOver's adjustment; clamped to `range`.
    mutating func set(_ strokes: Int) { value = Self.clamped(strokes) }

    /// "Score, 4, Par": what VoiceOver reads for the numeral (HP-ES-09).
    var accessibilityValue: String {
        String(localized: "\(value), \(name.title)", comment: "Enter score, VoiceOver: the strokes and the score name, e.g. '4, Par'.")
    }

    private static func clamped(_ strokes: Int) -> Int { min(max(strokes, range.lowerBound), range.upperBound) }
}
