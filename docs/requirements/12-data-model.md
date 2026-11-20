# 12 — Data Model (SwiftData schema)

**Diagram:** [`../data-model.drawio`](../data-model.drawio) (page 1: models, page 2: how they fit).
**Scope:** non-UI. The persisted SwiftData models, the Codable values stored inside them, the enums, the bundled read-only course data and the test fixtures every other story builds on. There's **no data migration**: the app has never been released, so it starts with a fresh store (§8).
**Platform:** SwiftData on iOS 26, using its current APIs: `VersionedSchema`, `#Index`, persistent history (`fetchHistory`), `@ModelActor` and `ModelContext.didSave`.
**Replaces:** v1 `Player`, `Round`, `PersonRound`, `Score`, `Tee`, `ColorValues` (`MaynardGolf/Data/`). Nothing from v1 is kept or needs to stay compatible.

## 1. Overview
The app stores three `@Model` types in one SwiftData store: **Player**, **Round** and **RoundEntry** (one player's card in one round). Course data (tees, holes, handicaps, local rules) is **not** in SwiftData; it's decoded from the bundled `MaynardGC.json` (course-maynard-gc.md). Settings live in UserDefaults (02-settings). Anything that can be calculated (handicap, totals, completion, scorecard, summaries) is derived and never stored.

### 1.1 Why it's shaped this way
- **One source of truth per fact.** A round is complete when it has a `finishedAt` date; there's no separate stored flag that could disagree with it.
- **Scores are a plain array on the entry** (`strokes[hole − 1]`). A round has at most 18 numbers per player, they're always read and written together, and they sync as one small CloudKit field. A separate `@Model` per hole would mean up to 72 records per round for no query the app needs.
- **The tee belongs to the round**, because every player in a round plays the same tee (NR-CTA-03). If mixed tees are wanted later, an optional per-entry tee can be added without breaking sync (additive change, IC-DM-07).
- **UUID ids everywhere.** CloudKit can't enforce uniqueness, so every model carries an app-level `id` that `DuplicateResolver` uses (IC-DM-06), and that UI tests and navigation can refer to.
- **Changes are observed, not broadcast.** Screens update through `@Observable` view models fed by repository change streams, which come from `ModelContext.didSave` and persistent history. There's no `NotificationCenter` refresh.

## 2. Schema, container and access
| ID | Requirement |
|----|-------------|
| DM-SC-01 | One versioned schema, `MaynardSchemaV1`, conforming to `VersionedSchema` with `versionIdentifier` 1.0.0 and the models `[Player.self, Round.self, RoundEntry.self]`. It's the baseline for any future change. |
| DM-SC-02 | `MaynardMigrationPlan: SchemaMigrationPlan` lists `[MaynardSchemaV1]` with **no stages**. It exists so later versions add stages without changing how the container is built. |
| DM-SC-03 | The store is the file `MaynardGolf.store` in Application Support, never the old `default.store`, so a store from an earlier development build is never opened. The live store syncs to the user's private **CloudKit** database (13-icloud-sync), so the schema follows DM-SC-08. |
| DM-SC-04 | `PersistenceController.makeContainer(_:)` builds the container: `.live` (on disk, CloudKit `.automatic`, so it syncs once the iCloud entitlement is added in #96), `.inMemory` (unit tests), `.file(URL)` (tests that need persistent history or reopening a store), `.seeded(Fixture)` (UI tests, `-uiTestSeed`) and `.preview(Fixture)` (SwiftUI previews, TS-VS-05). All but `.live` use `cloudKitDatabase: .none`; `.seeded` and `.preview` are DEBUG only. Each in-memory container is uniquely named, so two never share data. |
| DM-SC-05 | **Error boundary:** the app never crashes or calls `fatalError` if the container fails. `PersistenceLoader` (`@Observable`) holds `.loading` / `.ready(container)` / `.failed(error)`, logs the error, and Retry calls the factory again. The app shell (#14) shows a localized "Your data couldn't be opened" screen with Retry for `.failed`. A `ModelContext` doesn't keep its container alive, so whatever owns the container (the loader) lives as long as the app. |
| DM-SC-06 | **Access through repositories.** Views and view models never touch `ModelContext`, and views don't use `@Query`. `PlayerRepository` and `RoundRepository` (#16, `MaynardGolf/Repositories/`) do every fetch and write and are injected as protocols through `AppDependencies`, so view models are tested against an in-memory store. A failed write is rolled back with `ModelContext.discardChanges()`, which also refreshes models already in memory (SwiftData's `rollback()` alone leaves them showing the discarded values). |
| DM-SC-07 | **Concurrency.** UI reads and writes go through the main context on the main actor. Background work runs on a `@ModelActor` `BackgroundStore` with its own context: persistent-history passes now, duplicate merging (`DuplicateResolver`, #94) later. Only `PersistentIdentifier`s and `Sendable` snapshots (`PlayerSnapshot`, `RoundSnapshot`) cross actors, never `@Model` instances. Handicap and PDF work use snapshots (HC-MG-04, 15-round-pdf). The data layer compiles in Swift 6 language mode with complete concurrency checking (`Config/Shared.xcconfig`). |
| DM-SC-08 | **CloudKit-compatible schema** (13-icloud-sync §3): no `@Attribute(.unique)` or `#Unique`; every stored property optional or defaulted; every relationship optional with an inverse; photos in `@Attribute(.externalStorage)`; only additive changes after release. |
| DM-SC-09 | **Change tracking.** `ModelChangeTracker` publishes one `AsyncStream<ModelChanges>` (inserted / updated / deleted `PersistentIdentifier`s): local saves of the main context come from `ModelContext.didSave`, and changes made anywhere else (CloudKit imports, the background store) come from **persistent history** through `HistoryProcessor`, which reads `ModelContext.fetchHistory` on the `BackgroundStore` from the last saved `DefaultHistoryToken`. The main context stamps its transactions with the author `app`, and history passes skip that author, so nothing is reported twice. The token is saved (UserDefaults) after each pass, so each change is processed once; if the token's transaction was pruned, the pass reads all remaining history. `ModelChanges.only(_:)` narrows to one model type, so `HandicapManager` (HC-MG-02) recalculates only the players whose entries changed, and `DuplicateResolver` checks only newly inserted ids. Passes run one after another, so a burst of remote-change notifications never publishes a change twice or moves the token backwards. **History pruning:** the CloudKit-synced live store keeps all history, because CloudKit mirroring reads it to find local changes it still has to export (deleting unexported history, e.g. after a week offline, forces a sync reset); stores without CloudKit can prune processed history older than 7 days (`HistoryProcessor.localRetention`). The retention comes from `PersistenceController.Configuration.historyRetention` (nil for `.live`), so the caller can't pick the wrong one. Revisit with #96. The app shell (#14) runs a pass on launch, on foreground and on remote-change notifications; repositories (#16) expose the stream. |
| DM-SC-10 | **Indexes:** `#Index<Round>([\.startedAt], [\.finishedAt])` for the newest-first lists and the in-progress query; `#Index<Player>([\.firstName])` for the alphabetical lists. |

## 3. Models (`@Model`)

### 3.1 Player
| ID | Property | Type | Rule |
|----|----------|------|------|
| DM-PL-01 | `id` | `UUID` = `UUID()` | Not unique-constrained (CloudKit); de-duplicated by `DuplicateResolver`. |
| DM-PL-02 | `firstName` | `String` = "" | Trimmed, 1–30 characters (AP-NM-03), set through `rename(first:last:)`, which throws `PlayerError.invalidName` otherwise. |
| DM-PL-03 | `lastName` | `String` = "" | 0–30 characters; empty string, not nil. |
| DM-PL-04 | `colorRaw` | `String` = "lake" | Stores `PlayerColor` by raw value (§4); exposed as the computed `color`. Stored as a raw value so it works in `#Predicate` and sorts. |
| DM-PL-05 | `photoData` | `Data?`, `@Attribute(.externalStorage)` | The cropped square photo, JPEG, at most 1024 × 1024 px (AP-PH-04). Syncs through iCloud. Nil = no photo. |
| DM-PL-06 | `handicapIndex` | `Double?` | The **manually entered** index only (AP-HC-*), −10.0 … 54.0, one decimal; plus handicaps stored negative. Nil = not entered, so the calculated index is used (18-handicap). The calculated index is never stored. |
| DM-PL-07 | `createdAt` | `Date` = `.now` | Set on insert. Breaks ties in ordering; not shown. |
| DM-PL-08 | `entries` | `[RoundEntry]?` | `@Relationship(deleteRule: .cascade, inverse: \RoundEntry.player)`. |
| DM-PL-09 | Computed | `color`, `fullName`, `hasManualHandicap` | `fullName` = "first last" trimmed (first name only when there's no last name). `hasManualHandicap` = `handicapIndex != nil`. |
| DM-PL-10 | Invariant | | `handicapIndex`, when set, is within −10.0 … 54.0 and has one decimal; `setHandicapIndex(_:)` throws `PlayerError.invalidHandicapIndex` for anything else and changes nothing. `parseHandicapIndex(_:)` reads a typed index: one or two digits, an optional single decimal after a dot or a comma, an optional sign; "+2.1" is stored as −2.1. |
| DM-PL-11 | `isMarquee` | `Bool` = `false` | Stored on Player, included in PlayerSnapshot and synced with player data. At most **one** player may be the effective marquee; all false means **None**, a valid persisted state. No unique attribute / constraint (IC-DM-02). Specified in [story #197](https://github.com/tassinari/MaynardGolf/issues/197); not implemented yet. |
| DM-PL-12 | Default | Repository creation | Creating the first player in an **empty** store sets that player's flag true in the same save. Later creations default false, even when all existing flags are false (explicit None or deletion). Merely fetching / launching / importing an all-false store never selects a player. After every player has been deleted, creating a new first player uses the default again. |
| DM-PL-13 | Mutation / invariant | Repository selection by `UUID?` | Selecting a player clears all other flags and sets theirs in **one save**; nil clears all. Reject an unknown / deleted id without changes. Failure restores every affected flag via DM-SC-06 and leaves observers showing the prior choice. A no-op choice doesn't write. Imports with multiple true flags resolve as IC-DM-09 before presentation and repair the losing flags. |
| DM-PL-14 | Delete / scope | | Deleting the marquee player leaves all remaining players false; never auto-promote another player. Normal delete restrictions and rollback still apply (DM-RL-03, 04). Marquee only affects Home presentation; it never marks a device owner or changes round player order. |

### 3.2 Round
| ID | Property | Type | Rule |
|----|----------|------|------|
| DM-RD-01 | `id` | `UUID` = `UUID()` | Not unique-constrained (CloudKit). Lookup by id and All rounds use the same oldest stored copy. Repository deletion removes all copies with that logical id in one save (DM-RL-02). |
| DM-RD-02 | `courseID` | `String` = "MaynardGC" | Resolved through `CourseProvider`. |
| DM-RD-03 | `holeCountRaw` | `Int` = 9 | `HoleCount` raw value (9 or 18), exposed as `holeCount`. Set at tee off and never changed (NR-HOL-07). |
| DM-RD-04 | `teeRaw` | `String` = "white" | `Tee` raw value, exposed as `tee`. The tee every player in the round plays (NR-CTA-03). |
| DM-RD-05 | `startedAt` | `Date` = `.now` | The tee time. Indexed. |
| DM-RD-06 | `finishedAt` | `Date?` | Set **once**, when the last missing score of the round is saved (RC-BH-02). Nil = in progress. Unchanged by edit mode (HP-ED-04). Indexed. |
| DM-RD-07 | `currentHole` | `Int` = 1 | 1…`holeCount`. Saved on every hole change, for resume (HP-NAV-04). |
| DM-RD-08 | `weather` | `WeatherSnapshot?` | Captured at tee off; nil if WeatherKit failed (NR-CTA-04). |
| DM-RD-09 | `entries` | `[RoundEntry]?` | `@Relationship(deleteRule: .cascade, inverse: \RoundEntry.round)`. 1–4 entries. |
| DM-RD-10 | Computed | `holeCount`, `tee`, `isComplete`, `isInProgress`, `thru`, `duration`, `sortedEntries` | `isComplete` = `finishedAt != nil`; `isInProgress` = its opposite. `thru` = holes where every entry has a score. `duration` = `finishedAt − startedAt` or nil. `sortedEntries` = by `cardPosition`. |
| DM-RD-11 | Queries | | In-progress rounds: `#Predicate<Round> { $0.finishedAt == nil }`; completed: `!= nil`; both sorted by `startedAt` descending. |
| DM-RD-12 | (none) | — | No soft-delete flag. Rounds are deleted for real (HOME-AR-07). |
| DM-RD-13 | Invariant | | A round always has 1–4 entries with distinct `cardPosition`s 0…n−1, distinct players, and one stroke slot per hole. `Round.start(in:players:holeCount:tee:startedAt:weather:)` creates rounds this way (it throws `RoundError` otherwise), and `validateInvariants()` checks them. |

### 3.3 RoundEntry (one player's card in one round)
| ID | Property | Type | Rule |
|----|----------|------|------|
| DM-RE-01 | `id` | `UUID` = `UUID()` | Not unique-constrained (CloudKit). |
| DM-RE-02 | `player` | `Player?` | Inverse of `Player.entries`. |
| DM-RE-03 | `round` | `Round?` | Inverse of `Round.entries`. |
| DM-RE-04 | `cardPosition` | `Int` = 0 | 0-based selection order; sets the column order everywhere. |
| DM-RE-05 | `strokes` | `[Int?]` = [] | One element per hole, `holeCount` long, created all nil at tee off. `strokes[hole − 1]` is that hole's score; nil = not played yet. |
| DM-RE-06 | Mutation | `setStrokes(_:forHole:at:)` | The only write path. Validates 1…12 and the hole range and throws `ScoreError` otherwise, changing nothing. Reassigns the array so SwiftData records the change. If it filled the round's last missing score, the round's `finishedAt` becomes `at` (DM-RD-06); `at` defaults to now and is injected in tests. |
| DM-RE-07 | Computed | `strokes(forHole:)`, `grossTotal`, `toPar(pars:)`, `isComplete`, `front`, `back` | Totals count **scored holes only**; `toPar(pars:)` is against the par of those holes (HP-DT-04), with `pars[hole − 1]` coming from the course data through `RoundHoleBuilder` (#16). `front` / `back` = holes 1–9 / 10–18 (`back` is nil for a 9-hole round). |

## 4. Values and enums stored in models
| ID | Type | Fields / cases | Rule |
|----|------|----------------|------|
| DM-VT-01 | `WeatherSnapshot` (Codable struct) | `condition: WeatherKind`, `temperatureF: Int`, `capturedAt: Date` | Explicit `CodingKeys`, so renaming a Swift property never breaks stored data; unknown future keys are ignored. Shown in °F (no unit setting). |
| DM-EN-01 | `PlayerColor: String` | `lake`, `sand`, `flag`, `fairway`, `moss` | Maps to design tokens (DS-CL-*). |
| DM-EN-02 | `HoleCount: Int` | `nine = 9`, `eighteen = 18` | |
| DM-EN-03 | `Tee: String` | `blue`, `white`, `yellow`, `red` | Matches `TeeInfo.id` in the course data (DM-CD-02). |
| DM-EN-04 | `WeatherKind: String` | `sunny`, `partlyCloudy`, `cloudy`, `rain`, `windy` | `init(weatherKit:)` maps every WeatherKit condition to one of these; unknown → `cloudy`. |
| DM-EN-05 | Stability | | Raw values are part of the stored format and **never change**. An unknown raw value reads as a documented default (`lake`, `nine`, `white`, `cloudy`) instead of failing. |

## 5. Snapshots (Sendable, never stored)
| ID | Requirement |
|----|-------------|
| DM-SN-01 | `PlayerSnapshot` (id, names, color, photo data, manual index, `isMarquee`) and `RoundSnapshot` (id, hole count, tee, dates, weather, entries with player id, card position and strokes) are plain `Sendable` structs made from the models on the main actor. |
| DM-SN-02 | They're what crosses actors: handicap calculation, the PDF renderer, previews and the background store all work on snapshots (DM-SC-07). |

## 6. Bundled course data (read-only, not SwiftData)
| ID | Requirement |
|----|-------------|
| DM-CD-01 | `Course` (`id`, `name`, `coordinate` (for weather), `tees: [TeeInfo]`, `holes: [Hole]`, `localRules: [LocalRule]`) is decoded from `MaynardGC.json` by `BundleCourseProvider` (the `CourseProvider` protocol), once per course, and cached. `localRules` are String Catalog keys in the JSON (LR-DT-02). |
| DM-CD-02 | `TeeInfo` (`id: Tee`, `name` (a String Catalog key, shown as `localizedName`), `colorToken`, `rating`, `slope`): Blue / White 68.2 / 123, Yellow / Red 71.5 / 124 (course-maynard-gc.md §2). `rating(for: .nine)` is half the 18-hole rating. |
| DM-CD-03 | `Hole` (`number` 1…9, `par`, `yardage: [Tee: Int]`, `handicapFront`, `handicapBack`, `greenCoordinates`). Plus the shot-line fields (14-shot-lines §6), both required: `teeBoxes` (a `TeeBoxes` with one `Coordinate` per tee) and `approachShots: [Coordinate]` (two on a par 5, one otherwise). A hole missing either, or with the wrong number of approach shots, fails to decode with a `CourseDataError`, so the course doesn't load; the hole `camera` comes with the hole map (16-hole-map §6). |
| DM-CD-04 | `RoundHole` (derived) = `number` 1…18, `source: Hole`, `handicap`. Built by `RoundHoleBuilder(course:holeCount:)`: 18 holes → 1–9 front handicaps, 10–18 back handicaps; 9 holes → the 1–9 rank (CRS-HC-01…03). |
| DM-CD-05 | The JSON corrections in course-maynard-gc.md §4 (handicaps, hole 7 Yellow / Red yards, per-tee rating, trailing comma) are made (#16, PR for #14). |
| DM-CD-06 | A failed decode is a programmer error caught by tests. At runtime it surfaces as the DM-SC-05 error screen, not a crash. |

## 7. Relationships and delete rules
| ID | Requirement |
|----|-------------|
| DM-RL-01 | Player 1 → 0..* RoundEntry, **cascade**. Round 1 → 1..4 RoundEntry, **cascade**. |
| DM-RL-02 | Deleting a **Round** (All rounds swipe) removes every stored copy with that logical round id and all their entries in one repository save, so a sync duplicate cannot reappear after a successful delete. Other rounds and all players are untouched. `ModelDeletion` deletes the entries explicitly, not through the cascade rule, because rolling back a cascaded delete crashes SwiftData; a failed save rolls the whole delete back (X-11). |
| DM-RL-03 | Deleting a **Player** (All players swipe or Edit › Delete) removes their entries. Any Round left with **no** entries is deleted in the same save, and rounds with other players keep them, with their `cardPosition`s re-packed. `ModelDeletion.apply(_:in:)` implements this, and `PlayerRepository` (#16) saves it, rolling back if the save fails. |
| DM-RL-04 | Deleting a player who is in a round in progress is refused (`PlayerError.inRoundInProgress`) (AL-LS-06, AP-ED-07). |
| DM-RL-05 | A player's photo lives in the model (`photoData`), so it's deleted with the player; there are no photo files to clean up. |

## 8. No data migration
| ID | Requirement |
|----|-------------|
| DM-MG-01 | There's **no migration from earlier builds**. The app has never been released; every install starts with an empty store. |
| DM-MG-02 | On first launch, leftovers from an earlier development build are deleted: `default.store` and its `-wal` / `-shm` files in Application Support, and the `Documents/pics/` folder. This runs once, never touches `MaynardGolf.store`, and a failure to delete is logged and ignored. |
| DM-MG-03 | After the first release, any schema change adds a new `VersionedSchema` and a stage in `MaynardMigrationPlan`, with a migration test (TS-UT-05). Changes stay additive for CloudKit (IC-DM-07). |

## 9. Unit testing (required, ≥ 90 % coverage of the data layer; 100 % for the pure parts)
All tests use **Swift Testing**, an **in-memory** container (`PersistenceController.inMemory`) per test, and fixture factories. Nothing touches the on-disk store, network or real dates (an injected `Clock`).

### 9.1 Fixtures
| ID | Requirement |
|----|-------------|
| DM-TS-01 | `ModelFixtures` (DEBUG only): `player(...)`, `round(players:holeCount:tee:startedAt:weather:thru:scores:seed:)`, `completedRound(...)`, `inProgressRound(thru:)` builders with fixed values (no `random`, reference date 1 June 2026). Named data sets (`Fixture`) shared with UI tests and previews (TS-VS-05): `freshInstall` (empty), `onePlayer` (1 player, 3 rounds), `twoPlayers` (2 players, 3 rounds together), `noRound` (3 players), `inProgress` (3 players, 2 finished + 1 in progress), `twoInProgress` (3 players, 1 finished + 2 in progress), `fullHistory` (6 players, 20+ rounds each, 9 and 18, all tees, every weather kind and no weather, 1–4 players, a diacritic name, manual and calculated indexes). |

### 9.2 Model tests
| ID | Test |
|----|------|
| DM-TS-10 | `Player`: defaults on insert (including `isMarquee = false`; repository first-player default in DM-TS-39); `fullName` (no last name); `color` from `colorRaw`, unknown raw → `lake`; `hasManualHandicap`; `setHandicapIndex` accepts −10.0 / 54.0 / "+2.1" → −2.1 and throws for 54.1, −10.1 and two decimals (DM-PL-10). |
| DM-TS-11 | `Round`: `isComplete` / `isInProgress` follow `finishedAt`; `thru` with 0 / partial / all holes for 1–4 entries; `duration` nil vs set; `sortedEntries` order; `holeCount` and `tee` from their raw values with fallbacks. |
| DM-TS-12 | `RoundEntry.setStrokes`: accepts 1 and 12; throws for 0, 13 and an out-of-range hole; overwrites an existing score; after a save the change is visible in a fresh context (the array change is persisted). |
| DM-TS-13 | `RoundEntry` totals: `grossTotal` / `toPar` count scored holes only; `front` / `back` for 18; nil `back` for 9; `isComplete`. |
| DM-TS-14 | Round completion: saving the last missing score sets `finishedAt` once; a later edit leaves it unchanged. |
| DM-TS-15 | Queries: the in-progress and completed predicates return the right rounds, newest first. |
| DM-TS-16 | CloudKit compatibility check (IC-TS-01): reflection over the schema finds no unique attributes or constraints, every attribute optional or defaulted, every relationship optional with an inverse, and the photo in external storage. `DuplicateResolver` (IC-TS-02) is tested with its story, #94. |

### 9.3 Values, enums and snapshots
| ID | Test |
|----|------|
| DM-TS-20 | `WeatherSnapshot` Codable round-trip with its stored key names; extra keys are ignored; an unknown condition reads as `cloudy`. Its current fields are all required; any field added later must be optional, so stored weather without it still decodes. |
| DM-TS-21 | **Raw-value snapshot test:** every `PlayerColor`, `HoleCount`, `Tee` and `WeatherKind` raw value equals a hard-coded list. The test fails if anyone renames a case. |
| DM-TS-22 | Unknown raw values read as the documented defaults (DM-EN-05). |
| DM-TS-23 | `WeatherKind(weatherKit:)` covers every WeatherKit condition (parameterized). |
| DM-TS-24 | `PlayerSnapshot` / `RoundSnapshot` copy every field (including `isMarquee`) and are usable off the main actor. |

### 9.4 Relationships and deletes
| ID | Test |
|----|------|
| DM-TS-30 | Delete a Player → their entries are gone; other players' entries remain. |
| DM-TS-31 | Delete a Player who was the only player in a round → that Round is deleted too. In a shared round → the round remains and `cardPosition`s are re-packed 0…n−1. |
| DM-TS-32 | Delete a Player in a round in progress → throws `inRoundInProgress`; nothing is deleted. |
| DM-TS-33 | Delete a Round → its entries are gone; its Players remain with their other rounds. |
| DM-TS-34 | Player delete removes `photoData` with the player (external-storage blob gone after save). |
| DM-TS-35 | Round invariants (DM-RD-13) hold after create, delete-player and re-pack. |

### 9.5 Change tracking and concurrency
| ID | Test |
|----|------|
| DM-TS-36 | A local save emits the changed ids on the repository stream once. |
| DM-TS-37 | Persistent history: changes written by a second context (standing in for a CloudKit import) are found from the saved history token, processed once, and the token advances; a second pass finds nothing new; the main context's own saves aren't reported again; pruning history doesn't lose the place. |
| DM-TS-38 | `BackgroundStore` (`@ModelActor`) returns snapshots, and no `@Model` instance crosses actors (Swift 6 strict concurrency compiles clean). Merging duplicates on it is tested with `DuplicateResolver` (#94). |
| DM-TS-39 | Marquee selection (in-memory container per test): first-player default; later additions preserve a selection or None; replacing / clearing / no-op; unknown or vanished id; read-back / reopen; delete selected / unselected / final player; create a new first player after deleting all; failed save restores all flags; snapshots copy the flag; conflicting imported flags normalize deterministically and idempotently (IC-TS-07). Pure selection logic 100 % coverage. |

### 9.6 Course data
| ID | Test |
|----|------|
| DM-TS-40 | The bundled `MaynardGC.json` decodes and matches the official card: 4 tees, 9 holes, pars (35), yardages per tee (Blue 3,013, Yellow 2,718, Red 2,601), front / back handicaps, rating / slope per tee, 12 local rules as String Catalog keys (course-maynard-gc.md). |
| DM-TS-41 | `RoundHoleBuilder`: 9 holes → numbers 1–9 with ranks 1, 5, 6, 3, 2, 9, 7, 4, 8; 18 holes → numbers 1–18, holes 10–18 sourced from 1–9 with back handicaps; par 35 / 70; Blue yards 3,013 / 6,026. |
| DM-TS-42 | A malformed course JSON (e.g. trailing comma) fails decoding with a typed error, not a crash. |

### 9.7 Fresh store, cleanup and container
| ID | Test |
|----|------|
| DM-TS-50 | A fresh install creates an empty `MaynardGolf.store` with `MaynardSchemaV1` and the stage-less `MaynardMigrationPlan`; reopening it keeps the data written. |
| DM-TS-51 | With a leftover `default.store` (+ `-wal`, `-shm`) and `Documents/pics/` in a temp sandbox, first launch removes them, creates the new store, and doesn't run again on the next launch. |
| DM-TS-52 | A cleanup failure (injected file-system error) is logged and doesn't stop the app from opening its store. |
| DM-TS-60 | `PersistenceController.inMemory`, `.seeded(fixture)` and `.preview(fixture)` create isolated containers (two in parallel don't share data). |
| DM-TS-61 | A container failure (injected) produces the error state, not a crash; Retry calls the factory again. |

## 10. Definition of done (this story)
- All DM-TS tests pass in CI on iOS 26 with Swift 6 strict concurrency; data-layer coverage ≥ 90 %, pure code (values, enums, snapshots, builders) 100 %.
- `data-model.drawio` is updated in the same PR if any property, relationship or delete rule changes.
