//
//  MaynardSchema.swift
//  MaynardGolf
//

import Foundation
import SwiftData

/// The baseline versioned schema (DM-SC-01). The models are nested in it so that a future
/// `MaynardSchemaV2` can redeclare them while V1 stays frozen for its migration stage (DM-MG-03).
enum MaynardSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Player.self, Round.self, RoundEntry.self, OutsideCourse.self, OutsideScore.self]
    }
}

/// The migration plan (DM-SC-02). No stages: the app has never been released, so there's nothing to
/// migrate (DM-MG-01). It exists so later versions add stages without changing how the container is built.
enum MaynardMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [MaynardSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

/// The current models. Code uses these names; only migrations name a schema version.
typealias Player = MaynardSchemaV1.Player
typealias Round = MaynardSchemaV1.Round
typealias RoundEntry = MaynardSchemaV1.RoundEntry
typealias OutsideCourse = MaynardSchemaV1.OutsideCourse
typealias OutsideScore = MaynardSchemaV1.OutsideScore
