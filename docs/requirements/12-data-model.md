# 12 — Data Model (SwiftData schema v2)

**Diagram:** [`../data-model.drawio`](../data-model.drawio) (page 1: models, page 2: how they fit).
**Scope:** non-UI. The persisted SwiftData models, the Codable value types stored inside them, the enums, the bundled read-only course data, the v1 → v2 migration and the test fixtures every other story builds on.
**Replaces:** v1 `Player`, `Round`, `PersonRound`, `Score`, `Tee`, `ColorValues` (`MaynardGolf/Data/`).

## 1. Overview
The app stores three `@Model` types in one SwiftData store: **Player**, **Round** and **PersonRound** (one player's card in one round). There's no GHIN integration. Scores and weather are Codable value types stored inside them. Course data (tees, holes, handicaps, local rules) is **not** in SwiftData. It's decoded from the bundled `MaynardGC.json` (course-maynard-gc.md). Settings live in UserDefaults (02-settings). Anything that can be calculated (handicap, totals, scorecard, summaries) is derived and never stored.

## 2. Schema and container
| ID | Requirement |
|----|-------------|
| DM-SC-01 | Two versioned schemas: `MaynardSchemaV1` (the shipped v1 models, frozen as they are today) and `MaynardSchemaV2` (this document). Both conform to `VersionedSchema` with distinct `versionIdentifier`s (1.0.0, 2.0.0). |
| DM-SC-02 | `MaynardMigrationPlan: SchemaMigrationPlan` lists `[V1, V2]` with one **custom** stage V1 → V2 (§8). |
| DM-SC-03 | The store stays at the v1 location (Application Support, `default.store` + WAL) so existing installs migrate in place. The live store syncs to the user's private **CloudKit** database (13-icloud-sync), so the schema follows the CloudKit rules in DM-SC-08. |
| DM-SC-04 | Container creation lives in a `PersistenceController` factory with `.live` (on disk), `.inMemory` (unit tests) and `.seeded(Fixture)` (UI tests via `-uiTestSeed`). |
| DM-SC-05 | **Error boundary:** v1 calls `fatalError` if the container fails. v2 must not crash. On failure, show a localized "Your data couldn't be opened" screen with Retry, and log the error. A failed migration leaves the v1 store untouched (SwiftData's transactional migration; verified by test). |
| DM-SC-06 | Views never use `ModelContext` directly. Reads and writes go through `PlayerRepository` / `RoundRepository` (#16). `@Query` may be used inside repository-backed observable sources only. |
| DM-SC-08 | **CloudKit-compatible schema** (13-icloud-sync §3): no `@Attribute(.unique)`; every stored property optional or defaulted; every relationship optional with an inverse; photos in `@Attribute(.externalStorage)`; only additive changes after release. Uniqueness of `id` is enforced by the app (`DuplicateResolver`). |
| DM-SC-07 | All model access happens on the main actor through `mainContext`, except the migration and PDF rendering, which take value snapshots (no `@Model` instances cross actors). |

## 3. Models (`@Model`)

### 3.1 Player
| ID | Property | Type | Rule |
|----|----------|------|------|
| DM-PL-01 | `id` | `UUID` = `UUID()` | Kept from v1. Not `.unique` (CloudKit); de-duplicated by `DuplicateResolver`. |
| DM-PL-02 | `firstName` | `String` | Trimmed, 1–30 characters (AP-NM-03). |
| DM-PL-03 | `lastName` | `String` | 0–30 characters; empty string, not nil. |
| DM-PL-04 | `colorToken` | `PlayerColor` | Stored by raw value (§5). |
| DM-PL-05 | `photoData` | `Data?`, `@Attribute(.externalStorage)` | JPEG, max 1024 px. Stored in the model so it syncs through iCloud. Nil = no photo. Replaces v1 `photoPath` files. |
| DM-PL-06 | `photoScale`, `photoOffsetX`, `photoOffsetY` | `Double` | The cropper transform (v1 `scale`, `offsetX`, `offsetY`). Defaults 1, 0, 0. |
| DM-PL-07 | `handicapIndex` | `Double?` | The **manually entered** index (AP-HC-*), −10.0 … 54.0, one decimal (plus handicaps stored negative). Nil = not entered, so the calculated index is used. The calculated index is never stored (AP-CH-06). |
| DM-PL-08 | `createdAt` | `Date` | Set on insert. Used to order ties, not shown. |
| DM-PL-09 | `rounds` | `[PersonRound]?` | `@Relationship(deleteRule: .cascade, inverse: \PersonRound.player)`. |
| DM-PL-10 | Transient | `fullName`, `hasManualHandicap` | `fullName` = "first last" trimmed. `hasManualHandicap` = `handicapIndex != nil`. |
| DM-PL-11 | Invariant | | `handicapIndex`, when set, is within −10.0 … 54.0 and rounded to one decimal; the setter rejects anything else. |

### 3.2 Round
| ID | Property | Type | Rule |
|----|----------|------|------|
| DM-RD-01 | `id` | `String` = UUID string | Kept as `String` to match v1. Not `.unique` (CloudKit). |
| DM-RD-02 | `courseID` | `String` | `"MaynardGC"`; resolved through `CourseProvider`. |
| DM-RD-03 | `holeCount` | `HoleCount` | 9 or 18. Set at tee off; immutable afterwards (NR-HOL-07). |
| DM-RD-04 | `startedAt` | `Date` | The tee time (v1 `date`). |
| DM-RD-05 | `finishedAt` | `Date?` | Set when the last score of the last hole is saved. Unchanged by edit mode (HP-ED-04). |
| DM-RD-06 | `isComplete` | `Bool` | True once every player has a score on every hole. Never goes back to false (scores can't be cleared in edit mode, HP-ED-05). |
| DM-RD-07 | `currentHole` | `Int` | 1…`holeCount`. Saved on every hole change, for resume (HP-NAV-04). |
| DM-RD-08 | `weather` | `WeatherSnapshot?` | Captured at tee off; nil if WeatherKit failed (NR-CTA-04). |
| DM-RD-09 | `players` | `[PersonRound]?` | `@Relationship(deleteRule: .cascade, inverse: \PersonRound.round)`. 1–4 entries. |
| DM-RD-10 | Transient | `isInProgress`, `thru`, `duration`, `sortedPlayers` | `isInProgress` = `!isComplete`. `thru` = holes where every player has a score. `duration` = `finishedAt − startedAt` or nil. `sortedPlayers` = by `cardPosition`. |
| DM-RD-11 | Removed | `deleted` | v1's soft-delete flag is dropped. v2 deletes rounds for real (HOME-AR-05). |
| DM-RD-12 | Invariant | | A round always has 1–4 players with distinct `cardPosition`s 0…n−1 and distinct players. |

### 3.3 PersonRound
| ID | Property | Type | Rule |
|----|----------|------|------|
| DM-PR-01 | `id` | `String` = UUID string | As v1. Not `.unique` (CloudKit). |
| DM-PR-02 | `player` | `Player?` | Inverse of `Player.rounds`. |
| DM-PR-03 | `round` | `Round?` | Inverse of `Round.players`. |
| DM-PR-04 | `teeID` | `String` | A `TeeInfo.id` (`blue`, `white`, `yellow`, `red`). New round sets the same tee for every player (NR-CTA-03). It's kept per player so mixed tees stay possible later. |
| DM-PR-05 | `cardPosition` | `Int` | 0-based selection order. It sets the column order everywhere. |
| DM-PR-06 | `scores` | `[Score]` | Exactly `holeCount` entries, hole numbers 1…`holeCount` in order, created empty at tee off. |
| DM-PR-07 | Transient | `grossTotal`, `toPar`, `isComplete`, `front`, `back` | Totals count **scored holes only**. `toPar` is against the par of those holes (HP-DT-04). `front` / `back` = holes 1–9 / 10–18 (nil for a 9-hole round). |
| DM-PR-08 | Mutation | `setScore(_:forHole:)` | The only write path. It validates 1…12 and the hole range, and throws `ScoreError` otherwise. |

## 4. Value types (Codable, stored inside models)
| ID | Type | Fields | Rule |
|----|------|--------|------|
| DM-VT-01 | `Score` | `holeNumber: Int` (1…18), `strokes: Int?` (1…12, nil = not played) | v1 embedded a whole `Hole`. v2 stores only the number and resolves the hole with `RoundHoleBuilder`. `Hashable`, `Identifiable` (id = holeNumber). |
| DM-VT-02 | `WeatherSnapshot` | `condition: WeatherKind`, `temperatureF: Int`, `capturedAt: Date` | Replaces v1 `weatherTemp` / `weatherString` strings. The display unit is °F (no unit setting). |
| DM-VT-03 | Coding | | Both use explicit `CodingKeys`, so a renamed Swift property never breaks stored data. Unknown future keys are ignored. |

## 5. Enums (persisted by raw value)
| ID | Enum | Cases (raw value) | Rule |
|----|------|-------------------|------|
| DM-EN-01 | `PlayerColor: String` | `lake`, `sand`, `flag`, `fairway`, `moss` | Maps to design tokens (DS-CL-*). |
| DM-EN-02 | `HoleCount: Int` | `nine = 9`, `eighteen = 18` | |
| DM-EN-03 | `WeatherKind: String` | `sunny`, `partlyCloudy`, `cloudy`, `rain`, `windy` | `init(weatherKit:)` maps every WeatherKit condition to one of these. Unknown → `cloudy`. |
| DM-EN-04 | Stability | | Raw values are part of the stored format and **must never change**. A decode of an unknown raw value falls back to a documented default (`lake`, `nine`, `cloudy`) instead of failing. |

## 6. Bundled course data (read-only, not SwiftData)
| ID | Requirement |
|----|-------------|
| DM-CD-01 | `Course` (`id`, `name`, `tees: [TeeInfo]`, `holes: [Hole]`, `localRules: [String]`, `coordinate`) is decoded from `MaynardGC.json` by `CourseProvider`, once, and cached. |
| DM-CD-02 | `TeeInfo` (`id`, `name`, `colorToken`, `rating`, `slope`): Blue / White 68.2 / 123, Yellow / Red 71.5 / 124 (course-maynard-gc.md §2). |
| DM-CD-03 | `Hole` (`number` 1…9, `par`, `yardage: [teeID: Int]`, `handicapFront`, `handicapBack`, `teeCoordinates: [teeID: Coordinate]`, `landingPoints: [Coordinate]`, `bends: [Double]?`, `aerial` (image + 3 GPS control points), `greenCoordinates`). Shot-line fields: 14-shot-lines §4. |
| DM-CD-04 | `RoundHole` (derived) = `number` 1…18, `source: Hole`, `handicap`. Built by `RoundHoleBuilder(course:holeCount:)`: 18 holes → 1–9 front handicaps, 10–18 back handicaps; 9 holes → the 1–9 rank (CRS-HC-01…03). |
| DM-CD-05 | The JSON corrections in course-maynard-gc.md §4 (handicaps, hole 7 Yellow / Red yards, per-tee rating, trailing comma) are part of #16. |
| DM-CD-06 | A failed decode is a programmer error caught by tests. At runtime it surfaces as the DM-SC-05 error screen, not a crash. |

## 7. Relationships and delete rules
| ID | Requirement |
|----|-------------|
| DM-RL-01 | Player 1 → 0..* PersonRound, **cascade**. Round 1 → 1..4 PersonRound, **cascade**. |
| DM-RL-02 | Deleting a **Round** (All rounds swipe) removes its PersonRounds. Players are untouched. |
| DM-RL-03 | Deleting a **Player** (All players swipe or Edit › Delete) removes their PersonRounds. Any Round left with **no** PersonRounds is then deleted by `PlayerRepository` in the same save. Rounds with other players keep them (`cardPosition`s are re-packed). |
| DM-RL-04 | Deleting a player who is in a round in progress is refused (`PlayerError.inRoundInProgress`) (AL-LS-06, AP-ED-07). |
| DM-RL-05 | A player's photo is stored in the model (`photoData`), so it's deleted with the player; there are no photo files to clean up. |

## 8. Migration V1 → V2 (custom stage)
| ID | v1 | v2 |
|----|----|----|
| DM-MG-01 | `Player.color_int` (`ColorValues` red, blue, green, yellow, orange) | `colorToken`: red → flag, blue → lake, green → fairway, yellow → sand, orange → flag (DS-CL-03) |
| DM-MG-02 | `Player.scale`, `offsetX`, `offsetY`; `photoPath` file | `photoScale`, `photoOffsetX`, `photoOffsetY`; the file's JPEG (resized to 1024 px) copied into `photoData`; missing file → nil |
| DM-MG-03 | (none) | `handicapIndex` = nil (calculated index applies); `createdAt` = the player's earliest round date, else migration time |
| DM-MG-04 | `Round.date` | `startedAt` |
| DM-MG-05 | (none) | `holeCount` = 9 if every PersonRound has ≤ 9 scores, else 18 |
| DM-MG-06 | `Round.complete` | `isComplete`; `finishedAt` = nil (unknown) |
| DM-MG-07 | (none) | `currentHole` = the first hole with any missing score, else `holeCount` |
| DM-MG-08 | `weatherTemp`, `weatherString` | `weather` = `WeatherSnapshot` parsed from the strings; unparseable → nil |
| DM-MG-09 | `Round.deleted == true` | The round and its PersonRounds are **purged** |
| DM-MG-10 | `PersonRound.tee_int` (`Tee` white 0, yellow 1, blue 2, red 3) | `teeID` `white` / `yellow` / `blue` / `red` |
| DM-MG-11 | `PersonRound.score: [Score(hole: Hole, score: Int?)]` | `scores: [Score(holeNumber:, strokes:)]` |
| DM-MG-12 | Rule | No player, round or score is lost (other than DM-MG-09). The stage is idempotent. v1 photo files are left in place (not deleted). |

## 9. Unit testing (required, ≥ 90 % coverage of the data layer; 100 % for the pure parts)
All tests use **Swift Testing**, an **in-memory** container (`PersistenceController.inMemory`) per test, and fixture factories. Nothing touches the on-disk store, network or real dates (an injected `Clock`).

### 9.1 Fixtures
| ID | Requirement |
|----|-------------|
| DM-TS-01 | `ModelFixtures` (test target): `player(...)`, `round(holeCount:players:scores:)`, `completedRound(...)`, `inProgressRound(thru:)` builders with sensible defaults. Named data sets shared with UI tests: `empty`, `onePlayer`, `inProgress`, `fullHistory` (20+ rounds per player, 9 and 18, all tees, every weather kind). |
| DM-TS-02 | A checked-in **v1 fixture store** (`Fixtures/v1/default.store`), created by the shipping v1 app, containing: 5 players (one per v1 color, one with a photo transform), completed 9-hole rounds, an in-progress round, a soft-deleted round, rounds on every v1 tee and with and without weather strings. |

### 9.2 Model tests
| ID | Test |
|----|------|
| DM-TS-10 | `Player`: defaults on insert; `fullName` trimming (no last name); `hasManualHandicap`; the handicap setter accepts −10.0 / 54.0 / +2.1 → −2.1 and rejects 54.1, −10.1 and two decimals (DM-PL-11). |
| DM-TS-11 | `Round`: `thru` with 0 / partial / all holes for 1–4 players; `isInProgress`; `duration` nil vs set; `sortedPlayers` order. |
| DM-TS-12 | `PersonRound.setScore`: accepts 1 and 12; rejects 0, 13 and an out-of-range hole (throws); overwrites an existing score. |
| DM-TS-13 | `PersonRound` totals: `grossTotal` / `toPar` count scored holes only (partial rounds); `front` / `back` for 18; nil `back` for 9; `isComplete`. |
| DM-TS-14 | Round completion: saving the last missing score sets `isComplete` and `finishedAt` once; a later edit leaves `finishedAt` unchanged. |
| DM-TS-16 | CloudKit compatibility check and `DuplicateResolver` (13-icloud-sync IC-TS-01, IC-TS-02). |

### 9.3 Value types and enums
| ID | Test |
|----|------|
| DM-TS-20 | `Score` and `WeatherSnapshot` Codable round-trip; decoding with extra keys succeeds; missing optional keys → nil. |
| DM-TS-21 | **Raw-value snapshot test:** every `PlayerColor`, `HoleCount` and `WeatherKind` raw value equals a hard-coded list. The test fails if anyone renames a case. |
| DM-TS-22 | Unknown raw values decode to the documented fallbacks (DM-EN-04). |
| DM-TS-23 | `WeatherKind(weatherKit:)` covers every WeatherKit condition (parameterized test). |

### 9.4 Relationships and deletes
| ID | Test |
|----|------|
| DM-TS-30 | Delete a Player → their PersonRounds are gone; other players' PersonRounds remain. |
| DM-TS-31 | Delete a Player who was the only player in a round → that Round is deleted too. In a shared round → the round remains and `cardPosition`s are re-packed 0…n−1. |
| DM-TS-32 | Delete a Player in a round in progress → throws `inRoundInProgress`; nothing is deleted. |
| DM-TS-33 | Delete a Round → its PersonRounds are gone; its Players remain with their other rounds. |
| DM-TS-34 | Player delete removes `photoData` with the player (external-storage blob gone after save). |
| DM-TS-35 | Round invariants (DM-RD-12) hold after create, delete-player and re-pack. |

### 9.5 Course data
| ID | Test |
|----|------|
| DM-TS-40 | The bundled `MaynardGC.json` decodes and matches the official card: 4 tees, 9 holes, pars (35), yardages per tee (Blue 3,013), front / back handicaps, rating / slope per tee, 12 local rules (course-maynard-gc.md). |
| DM-TS-41 | `RoundHoleBuilder`: 9 holes → numbers 1–9 with ranks 1, 5, 6, 3, 2, 9, 7, 4, 8; 18 holes → numbers 1–18, holes 10–18 sourced from 1–9 with back handicaps; par 35 / 71; Blue yards 3,013 / 6,026. |
| DM-TS-42 | A malformed course JSON (e.g. trailing comma) fails decoding with a typed error, not a crash. |

### 9.6 Migration
| ID | Test |
|----|------|
| DM-TS-50 | Open a **copy** of the v1 fixture store with `MaynardMigrationPlan` → every v1 player, non-deleted round and score is present in v2 with matching values (counts and spot checks). |
| DM-TS-51 | One parameterized test per mapping row DM-MG-01 … DM-MG-11 (colors, transform, tees, hole count, current hole, weather parsing incl. unparseable, soft-deleted purge). |
| DM-TS-52 | Migrating twice (re-opening the migrated store) is a no-op. |
| DM-TS-53 | A forced failure during the custom stage leaves the original v1 file byte-identical. |
| DM-TS-54 | Opening a fresh (no store) install creates an empty V2 store directly. |

### 9.7 Container and error boundary
| ID | Test |
|----|------|
| DM-TS-60 | `PersistenceController.inMemory` and `.seeded(fixture)` create isolated containers (two in parallel don't share data). |
| DM-TS-61 | A container failure (injected) produces the error state, not a crash; Retry calls the factory again. |

## 10. Definition of done (this story)
- All DM-TS tests pass in CI on iOS 26; data-layer coverage ≥ 90 %, pure code (value types, enums, builders, migration mapping functions) 100 %.
- The migration mapping functions are pure (`static func map(_ v1: V1.Player) -> V2PlayerValues`) so they're unit-tested without a store, plus the end-to-end store test.
- `data-model.drawio` is updated in the same PR if any property, relationship or delete rule changes.
