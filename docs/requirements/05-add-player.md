# 05 — Add Player

**Artboard:** Add player
**Entry:** Home fresh-install empty state › "Add player", New round › "Add player", All players › "Add".
**Exit:** Cancel → back to the caller. Create → save, then back to the caller (Home shows the "no round" state once a player exists).
**Modes:** **Create** (from the entries above) and **Edit**, reached **only** from Player card › Edit (09-player-card PC-TOP-03). See §9.

## 1. Overview
A Chalk 50 form screen with a `DSNavigationBar` (Cancel / "ADD PLAYER"). It has a photo picker, name fields, a handicap/GHIN row, a color picker and a Create button. There's **no** "This is me" option: the app doesn't single out the device owner. The same form serves Edit from the Player card (§9).

## 2. Navigation bar
| ID | Requirement |
|----|-------------|
| AP-NAV-01 | Leading "Cancel" pill. If any field is dirty, confirm "Discard new player?" (Discard / Keep editing). |
| AP-NAV-02 | Centered title "ADD PLAYER". |

## 3. Photo
| ID | Requirement |
|----|-------------|
| AP-PH-01 | A centered 104 pt `AvatarPicker`: a Tee Green 50 circle with a person glyph (Rough 600) when empty, and a Lake 600 camera badge bottom-right. Accessibility label "Add photo". |
| AP-PH-02 | Caption link "Add photo" (Lake 600, Inter 600 14) under the avatar. When a photo is set it reads "Change photo". |
| AP-PH-03 | Tapping it offers "Take photo" (camera), "Choose from library" (`PhotosPicker`) and, if a photo is set, "Remove photo". |
| AP-PH-04 | After picking, the circular crop/position editor opens (reusing the v1 cropper logic: scale + offset). The result is saved to `Documents/pics/{playerId}.jpg`. |
| AP-PH-05 | Camera or photo permission denied → an explanatory alert with an "Open Settings" link. |
| AP-PH-06 | With no photo, the avatar elsewhere in the app shows the initial on the chosen color. |

## 4. Name fields
| ID | Requirement |
|----|-------------|
| AP-NM-01 | `FormFieldCard` with two fields. **FIRST NAME** (placeholder "e.g. Mark") is required. **LAST NAME** (placeholder "Optional") is optional. |
| AP-NM-02 | Text content types `.givenName` / `.familyName`, autocapitalization words, Return moves to the next field. |
| AP-NM-03 | The first name is trimmed and must be 1–30 characters. The last name is 0–30 characters. |
| AP-NM-04 | A duplicate full name shows a non-blocking warning "A player named {name} already exists". |

## 5. Handicap index
| ID | Requirement |
|----|-------------|
| AP-HC-01 | A card row: label "HANDICAP INDEX" (caps), hint "Link GHIN to keep it up to date" and trailing `TintedButton` "＋ Add GHIN". |
| AP-HC-02 | "Add GHIN" pushes **Link GHIN**. When it returns with a profile, the row shows the index (Sofia 700) and "GHIN {number}", and the button becomes "Change". |
| AP-HC-03 | **GHIN only.** There's no manual handicap entry on this screen. |
| AP-HC-04 | Linking GHIN is optional. A player created without GHIN gets a **calculated** handicap index from their rounds in the app (§5.1). The row's hint stays "Link GHIN to keep it up to date". |

### 5.1 Calculated handicap (players without GHIN)
| ID | Requirement |
|----|-------------|
| AP-CH-01 | When a player has no GHIN index, the app calculates one from their completed, non-deleted rounds, following the World Handicap System: score differential = (113 ÷ slope) × (adjusted gross − course rating), using the **tee played** (per-tee rating/slope, course-maynard-gc.md §2). |
| AP-CH-02 | Index = average of the lowest differentials among the most recent 20 (best 8 of 20), with the WHS table for fewer rounds (3 rounds → lowest 1 − 2.0; 4 → lowest 1 − 1.0; 5 → lowest 1; 6 → avg lowest 2 − 1.0; 7–8 → avg lowest 2; 9–11 → lowest 3; 12–14 → lowest 4; 15–16 → lowest 5; 17–18 → lowest 6; 19 → lowest 7; 20 → lowest 8). Rounded to one decimal, capped at 54.0. |
| AP-CH-03 | Fewer than 3 rounds → no index; the UI shows "—". |
| AP-CH-04 | Adjusted gross caps each hole at net double bogey (par + 2 + strokes received). Until a player has an index, cap at par + 5 (WHS initial-handicap rule). |
| AP-CH-05 | 9-hole rounds count toward the index. How they're converted to an 18-hole differential is an implementation detail for the back-end (calculator) story. |
| AP-CH-06 | The calculated index is derived, not stored on `Player`. It's recalculated whenever a round completes, is deleted, or is edited. GHIN, when linked, always wins. |
| AP-CH-07 | Wherever the index is shown (New round, Players sheet, All players, Player card), a calculated value is visually the same but its accessibility label adds "calculated". |
| AP-CH-08 | Lives in a pure, injected `HandicapCalculator` (replacing the v1 `Player.handicap` extension in `Handicap.swift`) with 100 % branch coverage: each row of the WHS table, the < 3 rounds case, 9- vs 18-hole rounds, per-tee rating/slope and the net-double-bogey cap. |

## 6. Color
| ID | Requirement |
|----|-------------|
| AP-CL-01 | `SectionHeader` "COLOR" + card with 5 44 pt color swatches: Lake, Sand, Flag, Fairway, Moss (accessibility labels = names). |
| AP-CL-02 | Single select. The selected swatch shows a 3 pt white + 2 pt Canopy double ring. Default = the first color not used by an existing player, otherwise Lake. |
| AP-CL-03 | The chosen color is used for the avatar background whenever there's no photo. |

## 7. Create
| ID | Requirement |
|----|-------------|
| AP-CR-01 | Full-width 54 pt `PrimaryButton` "Create" at the end of the form (it scrolls with the content). |
| AP-CR-02 | Disabled until the first name is valid. GHIN isn't required. |
| AP-CR-03 | Saves the `Player` (firstName, lastName, color, photoPath, scale/offset, ghinNumber?, handicapIndex?, handicapRevisedAt? — set only from GHIN) and dismisses. A save error shows an alert. |

## 8. Data
| ID | Requirement |
|----|-------------|
| AP-DT-01 | `Player` model additions: `ghinNumber: String?`, `handicapIndex: Double?` (GHIN index only; the calculated index isn't stored), `handicapRevisedAt: Date?`, `colorToken` (new palette). This needs a SwiftData `VersionedSchema` + `SchemaMigrationPlan`. Unit-test the migration of v1 stores. |
| AP-DT-02 | ~~Export / import~~ Removed: v2 has no Import / Export (see 02-settings §5). |
| AP-DT-03 | `PlayerFormViewModel` handles validation, dirty tracking and the Create / Edit configuration (`.create` / `.edit(Player)`). 100 % branch coverage on validation. |

## 9. Edit configuration (from the Player card)
| ID | Requirement |
|----|-------------|
| AP-ED-01 | Opened only from Player card › Edit. There's no Edit entry from Add player's own entry points. |
| AP-ED-02 | Title "EDIT PLAYER". The form is prefilled with the player's photo, first / last name, GHIN link and color. |
| AP-ED-03 | The bottom button reads "Save" (same `PrimaryButton`). It's disabled until something changes and the first name is valid. |
| AP-ED-04 | Cancel with changes → "Discard changes?" (Discard / Keep editing). |
| AP-ED-05 | The handicap row shows the linked GHIN (index + number, "Change") or, if unlinked, "Add GHIN". *Inferred:* a linked player also offers "Unlink GHIN" (falls back to the calculated index). |
| AP-ED-06 | The color picker's default-color rule (AP-CL-02) doesn't apply; the player's current color is selected. |
| AP-ED-07 | A destructive "Delete player" row below Save. It confirms "Delete {name}? Their {n} rounds will also be removed." and cascades to their `PersonRound`s as in v1. It's blocked (disabled, with an explanation) while the player is in a round in progress. After deleting, both the form and the Player card are dismissed. |
| AP-ED-08 | Saving updates the `Player` in place. The Player card, Home, All players and past rounds reflect the new name / photo / color through observation. |

## 10. Accessibility identifiers
`addPlayer.cancel`, `addPlayer.photo`, `addPlayer.firstName`, `addPlayer.lastName`, `addPlayer.addGhin`, `addPlayer.color.{name}`, `addPlayer.create`, `addPlayer.save`, `addPlayer.delete`.
