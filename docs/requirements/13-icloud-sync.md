# 13 — iCloud Sync (CloudKit backup)

**Scope:** non-UI plus one Settings row. Players, rounds, scores and photos are backed up to the user's **private iCloud database** through SwiftData's CloudKit integration. A new or restored device signed in to the same Apple Account gets all data back automatically, and two devices on the same account stay in sync.
**Replaces:** v1 Import / Export (zip backup), which is removed in v2 (02-settings §5).
**Depends on:** 12-data-model (the schema must be CloudKit-compatible, §3 below).

## 1. Behavior
| ID | Requirement |
|----|-------------|
| IC-BH-01 | Sync is **automatic and always on** when the device is signed in to iCloud with iCloud Drive / app iCloud access enabled. There's no in-app on/off switch. |
| IC-BH-02 | The app works fully **offline and signed out**. Data stays in the local store and syncs when iCloud becomes available. Nothing in the UI waits on sync. |
| IC-BH-03 | **Fresh install with existing iCloud data:** the data arrives in the background. While the store is empty and an import is in progress, Home's fresh-install state shows a non-blocking "Restoring from iCloud…" line under the empty-state message (*inferred*; no design). |
| IC-BH-04 | **First launch:** the app starts with an empty store (12-data-model §8). Whatever is in the user's iCloud database downloads into it; nothing local is uploaded first. |
| IC-BH-05 | **Two devices:** edits on either device appear on the other. Conflicts resolve last-writer-wins per record (CloudKit default). Two in-progress rounds at once are allowed (X-14), so two devices scoring different rounds is fine. |
| IC-BH-06 | Deletes sync (a round deleted on one device disappears on the other). |
| IC-BH-07 | Settings (UserDefaults) **don't** sync. They're per device. |

## 2. Settings status row
| ID | Requirement |
|----|-------------|
| IC-ST-01 | *Inferred (no design):* a row in Settings › About, "iCloud backup", with a trailing status: "On", "Signed out of iCloud", "iCloud storage full" or "Syncing…". Tapping it does nothing when On. Otherwise it opens a short explanation with a button to open the Settings app. |
| IC-ST-02 | Status comes from an injected `CloudAccountProvider` (wraps `CKContainer.accountStatus()` and the persistent-store sync event notifications), so the row is unit-testable. |

## 3. Data model constraints for CloudKit (applies to 12-data-model)
| ID | Requirement |
|----|-------------|
| IC-DM-01 | `ModelConfiguration(cloudKitDatabase: .private("iCloud.{bundle id}"))` for the live container. In-memory and seeded test containers use `.none`. |
| IC-DM-02 | **No `@Attribute(.unique)`.** CloudKit doesn't support unique constraints. `id` stays a plain stored property, and uniqueness is enforced by the app (IC-DM-06). |
| IC-DM-03 | Every stored property is **optional or has a default value**. Every relationship is **optional** (`[PersonRound]?`, `Player?`, `Round?`) with an inverse. Delete rules stay as in 12-data-model §7. |
| IC-DM-04 | Player photos move from `Documents/pics/` files into the model as `@Attribute(.externalStorage) photoData: Data?` (JPEG, max 1024 px, about 200 KB) so they sync. |
| IC-DM-05 | Codable value types (`Score`, `WeatherSnapshot`) are stored as attributes. They're fine for CloudKit as long as they stay small (a round's scores are a few hundred bytes). |
| IC-DM-06 | **Duplicate handling:** after a CloudKit import, a `DuplicateResolver` merges records that share an `id` (keep the most recently modified; re-point relationships to it). |
| IC-DM-07 | **Schema changes after release must be additive** (new optional properties or new models). Renames and deletes need a new version with a lightweight migration and are avoided. The CloudKit schema is promoted to Production before each App Store release (TestFlight / release checklist). |
| IC-DM-08 | The development CloudKit schema is initialized from the SwiftData models in a debug-only step (`initializeCloudKitSchema` on a dev build), never at runtime in release builds. |

## 4. Errors
| ID | Requirement |
|----|-------------|
| IC-ER-01 | Sync errors never show alerts during play. They only change the Settings status (IC-ST-01) and are logged with `os_log` (no analytics, X-13). |
| IC-ER-02 | **iCloud storage full:** local saves keep working; the status row says "iCloud storage full". |
| IC-ER-03 | **Account change** (a different Apple Account signs in): the local store is kept as-is and syncs to the new account (SwiftData default). *Inferred*; confirm with QA. |

## 5. Entitlements and setup
| ID | Requirement |
|----|-------------|
| IC-EN-01 | iCloud capability with **CloudKit**, container `iCloud.{bundle id}`; **Background Modes › Remote notifications** for silent push sync. |
| IC-EN-02 | The privacy policy (https://maynardgolf.tassinari.org/privacy) states that data is stored in the user's own iCloud account, and the developer can't read it. |

## 6. Testing
| ID | Test |
|----|------|
| IC-TS-01 | Unit: every model passes a **CloudKit-compatibility check**: no unique attributes, every property optional or defaulted, every relationship optional with an inverse (reflection over `Schema` entities; fails the build if someone adds a non-compatible property). |
| IC-TS-02 | Unit: `DuplicateResolver`: two Players / Rounds / PersonRounds with the same `id` merge into one; relationships re-pointed; newest values kept; no-duplicate input unchanged. |
| IC-TS-03 | Unit: `CloudAccountProvider` states → the Settings status text, for every account status and sync event (fake provider). |
| IC-TS-04 | Unit: a picked photo is resized to at most 1024 px, stored as JPEG in `photoData`, and reads back; removing the photo sets it to nil. |
| IC-TS-05 | Unit: the live container factory uses `.private(…)`; test factories use `.none` (no test ever touches iCloud). |
| IC-TS-06 | Manual QA (TestFlight, two devices, same Apple Account): create a player and round on A → appears on B; delete on B → gone on A; offline edits sync on reconnect; fresh install restores everything including photos. Recorded in the TestFlight checklist. |
