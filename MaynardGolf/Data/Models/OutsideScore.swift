//
//  OutsideScore.swift
//  MaynardGolf
//

import Foundation
import SwiftData

extension MaynardSchemaV1 {
    /// One score a player posted from an outside course (12-data-model §3.5, #252): a gross total only, with
    /// no hole-by-hole card and no tee (an outside course has one rating and slope).
    ///
    /// The course's name, rating and slope are copied when the score is saved (DM-OS-06), so a later change to
    /// the course, or its deletion, never changes this score's handicap differential.
    @Model
    final class OutsideScore {
        /// App-level identity (DM-OS-01); not unique-constrained, for CloudKit.
        var id: UUID = UUID()
        /// The gross total: 40 … 200 for 18 holes, 20 … 100 for 9 (DM-OS-02).
        var gross: Int = 0
        /// `HoleCount` raw value (DM-OS-03). Use `holeCount`.
        var holeCountRaw: Int = HoleCount.eighteen.rawValue
        /// The day it was played: the start of that day in the user's calendar, never after today (DM-OS-04).
        var playedOn: Date = Date.now
        /// The course's name when the score was saved (DM-OS-06).
        var courseName: String = ""
        /// The course's 18-hole rating when the score was saved (DM-OS-06).
        var courseRating: Double = 72.0
        /// The course's slope when the score was saved (DM-OS-06).
        var slope: Int = OutsideScoreRules.standardSlope
        /// Set on insert; orders two scores on the same day (DM-OS-07).
        var createdAt: Date = Date.now
        /// Whose score it is (DM-OS-08). Deleting the player deletes their scores.
        var player: Player?
        /// Where it was played (DM-OS-08); nil once the course is gone.
        var course: OutsideCourse?

        init(id: UUID = UUID(), gross: Int, holeCount: HoleCount, playedOn: Date, course: OutsideCourse, createdAt: Date = .now) {
            self.id = id
            self.gross = gross
            self.holeCountRaw = holeCount.rawValue
            self.playedOn = playedOn
            self.courseName = course.name
            self.courseRating = course.courseRating
            self.slope = course.slope
            self.createdAt = createdAt
        }

        /// The hole count; an unknown stored value reads as `.nine` (DM-EN-05).
        var holeCount: HoleCount { HoleCount(storedValue: holeCountRaw) }
    }
}
