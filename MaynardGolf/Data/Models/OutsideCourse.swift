//
//  OutsideCourse.swift
//  MaynardGolf
//

import Foundation
import SwiftData

extension MaynardSchemaV1 {
    /// A course other than Maynard Golf Club, entered by the user so scores played there count toward the
    /// handicap (12-data-model §3.4, #252). Shared by every player.
    ///
    /// CloudKit-compatible (DM-SC-08): every stored property has a default, the relationship is optional with
    /// an inverse, and neither `id` nor `name` is unique-constrained. `OutsideScoreRepository` keeps names
    /// unique when adding (DM-OC-03); a sync conflict can still bring in two with the same name, and both stay.
    @Model
    final class OutsideCourse {
        /// App-level identity (DM-OC-01); not unique-constrained, for CloudKit.
        var id: UUID = UUID()
        /// Trimmed, 1–60 characters (DM-OC-02).
        var name: String = ""
        /// The 18-hole course rating, 50.0 … 85.0 with one decimal (DM-OC-04).
        var courseRating: Double = 72.0
        /// The slope rating, 55 … 155 (DM-OC-05).
        var slope: Int = OutsideScoreRules.standardSlope
        /// Set on insert; breaks ties in ordering (DM-OC-06).
        var createdAt: Date = Date.now
        /// Scores posted here (DM-OC-07). Deleting the course leaves them, with the name, rating and slope they
        /// copied (DM-OS-06).
        @Relationship(deleteRule: .nullify, inverse: \OutsideScore.course)
        var scores: [OutsideScore]? = []

        init(id: UUID = UUID(), name: String, courseRating: Double, slope: Int, createdAt: Date = .now) {
            self.id = id
            self.name = name
            self.courseRating = courseRating
            self.slope = slope
            self.createdAt = createdAt
        }
    }
}
