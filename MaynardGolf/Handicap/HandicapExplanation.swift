//
//  HandicapExplanation.swift
//  MaynardGolf
//

import Foundation
import MaynardUI

/// The sentence under the Handicap screen's index (HS-HDR-03, #253): how the index is made, worded for the
/// number of rounds behind it (the WHS table, HC-CA-05), or why there isn't one, or that the starting index stands in (#268).
/// Pure, so every case is unit-tested.
enum HandicapExplanation {
    /// The text for a player's handicap and the breakdown of their rounds.
    static func text(handicap: PlayerHandicap, breakdown: HandicapBreakdown, locale: Locale = .current) -> String {
        let rounds = breakdown.rows.count
        guard breakdown.lowest > 0 else {
            let needed = max(3 - rounds, 1)
            if handicap.source == .starting {
                return String(localized: "This is the starting index from Edit player. Post \(needed) more scores to get an index from your rounds.",
                              comment: "Handicap screen: fewer than 3 rounds and a starting index is shown; how many more scores replace it, e.g. 'Post 2 more scores…'.")
            }
            return String(localized: "Post \(needed) more scores to get an index.",
                          comment: "Handicap screen: fewer than 3 rounds; how many more are needed, e.g. 'Post 2 more scores to get an index.'")
        }
        let how = breakdown.lowest == 1
            ? String(localized: "Your index is the lowest differential from your \(rounds) most recent rounds",
                     comment: "Handicap screen: the start of the explanation when one differential counts, e.g. '…from your 5 most recent rounds'. A sentence ending follows.")
            : String(localized: "Your index is the average of the \(breakdown.lowest) lowest differentials from your \(rounds) most recent rounds",
                     comment: "Handicap screen: the start of the explanation, e.g. 'the average of the 8 lowest differentials from your 20 most recent rounds'. A sentence ending follows.")
        let adjustment = breakdown.adjustment == 0 ? nil
            : String(localized: "minus \(abs(breakdown.adjustment).formatted(.number.precision(.fractionLength(1)).locale(locale)))",
                     comment: "Handicap screen: the WHS adjustment after the explanation for 3, 4 or 6 rounds, e.g. 'minus 2.0'.")
        let sentence = adjustment.map {
            String(localized: "\(how), \($0).", comment: "Handicap screen: the explanation and its adjustment, e.g. '…from your 3 most recent rounds, minus 2.0.'")
        } ?? String(localized: "\(how).", comment: "Handicap screen: the explanation as a sentence.")
        return sentence + " " + String(localized: "Rounds that count are highlighted below.",
                                       comment: "Handicap screen: after the explanation; the rounds the index averages are highlighted in the list.")
    }
}
