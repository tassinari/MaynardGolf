# 05 — Add Player

**Artboard:** Add player
**Entry:** Home fresh-install empty state › "Add player", New round › "Add player", All players › "Add".
**Exit:** Cancel → back to the caller. Create → save, then back to the caller (Home shows the "no round" state once a player exists).

## 1. Overview
A Chalk 50 form screen with a `DSNavigationBar` (Cancel / "ADD PLAYER"). It has a photo picker, name fields, a handicap/GHIN row, a color picker and a Create button. There's **no** "This is me" option: the app doesn't single out the device owner. *Inferred:* the same screen in **Edit** mode (title "EDIT PLAYER", button "Save") is reached from the Player card.

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
| AP-HC-03 | *Inferred:* a manual entry option. Tapping the row lets you type an index (−10.0 … 54.0, one decimal) for players without GHIN. |

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
| AP-CR-02 | Disabled until the first name is valid. |
| AP-CR-03 | Saves the `Player` (firstName, lastName, color, photoPath, scale/offset, ghinNumber?, handicapIndex?, handicapRevisedAt?) and dismisses. A save error shows an alert. |

## 8. Data
| ID | Requirement |
|----|-------------|
| AP-DT-01 | `Player` model additions: `ghinNumber: String?`, `handicapIndex: Double?`, `handicapRevisedAt: Date?`, `colorToken` (new palette). This needs a SwiftData `VersionedSchema` + `SchemaMigrationPlan`. Unit-test the migration of v1 stores. |
| AP-DT-02 | Export/import (`Codable`) must include the new fields and still accept v1 exports (missing keys → defaults). |
| AP-DT-03 | `PlayerFormViewModel` handles validation, dirty tracking and create vs edit. 100 % branch coverage on validation. |

## 9. Accessibility identifiers
`addPlayer.cancel`, `addPlayer.photo`, `addPlayer.firstName`, `addPlayer.lastName`, `addPlayer.addGhin`, `addPlayer.color.{name}`, `addPlayer.create`.

## Open questions
1. Is manual handicap entry wanted, or GHIN only?
2. Should edit / delete player live on this screen (Edit mode) or on the Player card?
