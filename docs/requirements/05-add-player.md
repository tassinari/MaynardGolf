# 05 — Add Player

**Artboards:** Add player, Add photo — photo picker, Add photo — move and scale
**Entry:** Home fresh-install empty state › "Add player", New round › "Add player", All players › "Add".
**Exit:** Cancel → back to the caller. Create → save, then back to the caller (Home shows the "no round" state once a player exists).
**Modes:** **Create** (from the entries above) and **Edit**, reached **only** from Player card › Edit (09-player-card PC-TOP-03). See §9.

## 1. Overview
A Chalk 50 form screen with a `DSNavigationBar` (Cancel / "ADD PLAYER"). It has a photo (system picker, then Move and Scale), name fields, an optional handicap index field, a color picker and a Create button. There's no GHIN integration. There's **no** "This is me" option: the app doesn't single out the device owner. The same form serves Edit from the Player card (§9).

## 2. Navigation bar
| ID | Requirement |
|----|-------------|
| AP-NAV-01 | Leading "Cancel" pill. If any field is dirty, confirm "Discard new player?" (Discard / Keep editing). |
| AP-NAV-02 | Centered title "ADD PLAYER". |

## 3. Photo
Tapping the avatar opens the system photo picker straight away. Choosing a photo opens **Move and Scale**, where the player positions it in a circle. Done puts it on the avatar. The app takes photos from the library only; there's no camera option.

| ID | Requirement |
|----|-------------|
| AP-PH-01 | A centered 104 pt `AvatarPicker`: a Tee Green 50 circle with a person glyph (Rough 600) when empty, and a Lake 600 camera badge bottom-right ringed in Chalk. Accessibility label "Add photo" (with a photo set: "Photo of {name}, change photo"). |
| AP-PH-02 | Caption link "Add photo" (Lake 600, SF Pro 600 14) under the avatar. When a photo is set it reads "Change photo". Tapping the caption does the same as tapping the avatar. |
| AP-PH-03 | **No photo:** tapping opens the photo picker (§3.1) directly, with no menu. **Photo set:** tapping shows a menu "Choose new photo", "Adjust photo" (reopens Move and Scale on the current photo) and the destructive "Remove photo". *The menu for a set photo is inferred; the artboards show only the empty avatar.* |
| AP-PH-04 | Done in Move and Scale renders the circle's content to a **square image** (at most 1024 × 1024 px), saved as JPEG (quality 0.85, never upscaled past the source's pixels; `PhotoEncoder`) in `Player.photoData` when the player is created or saved, so it syncs through iCloud (13-icloud-sync IC-DM-04). Until then it's held in the form; Cancel on the form drops it. |
| AP-PH-05 | **No permission prompt.** The picker runs out of process and hands the app only the chosen photo, so the app needs no photo-library permission and has no camera usage. There's no "permission denied" state. |
| AP-PH-06 | With no photo, the avatar elsewhere in the app shows the initial on the chosen color. |
| AP-PH-07 | "Remove photo" clears the photo in the form at once; it's saved with Create / Save. |
| AP-PH-08 | A photo that can't be loaded (an iCloud Photos download that fails, an unsupported file) shows an alert "Couldn't load that photo" with OK, and the avatar stays as it was. While a large photo loads, a spinner shows on the avatar. Only one photo loads at a time: while one does, the avatar and its menu are disabled. A picked photo is decoded off the main actor, downsampled so its shorter side is at most 3072 px (`PhotoEncoder.downsampled`): a crop at 3× still has 1024 px, and a 48 MP original isn't held as a ~195 MB bitmap. |

### 3.1 Photo picker (artboard "Add photo — photo picker")
| ID | Requirement |
|----|-------------|
| AP-PK-01 | The system `PhotosPicker` presented as a sheet over Add player, filtered to **images** (no videos, Live Photos as stills), **single selection**, using the shared photo library. |
| AP-PK-02 | The system provides its own UI: Cancel, the Photos / Collections switch, search ("Photos, People, Places…"), the photo grid and the footer "Maynard Golf only gets the photo you choose." The app doesn't restyle it. |
| AP-PK-03 | Tapping a photo selects it and, with single selection, dismisses the picker and opens **Move and Scale** (§3.2) on that photo, with no separate Add tap. |
| AP-PK-04 | Cancel dismisses the picker and returns to Add player with nothing changed. |

### 3.2 Move and Scale (artboard "Add photo — move and scale")
| ID | Requirement |
|----|-------------|
| AP-MS-01 | A full-screen cover on black, always dark (it's a photo editor), ignoring the safe area for the photo. Title "Move and Scale" (17 pt semibold, white) centered near the top. |
| AP-MS-02 | The photo fills the screen width behind a **circular mask 320 pt across**, centered horizontally and just above the vertical middle (44 % down). Outside the circle the photo is dimmed with Canopy 950 @ 55 % (the darkest token, standing in for black); the circle has a 1.5 pt white @ 70 % ring. |
| AP-MS-03 | **Drag** anywhere moves the photo; **pinch** zooms it. The photo always covers the whole circle: it can't be moved or zoomed out far enough to leave empty space inside the circle. |
| AP-MS-04 | Zoom runs from **1×** (the photo's shorter side just fills the circle) to **3×**. A new photo starts at 1× and centered; "Adjust photo" starts where the current photo was left. A photo saved earlier (only the square is kept) adjusts from 1× on that square. |
| AP-MS-05 | A Glass zoom slider below the circle, inset 32 pt from the sides: a small circle glyph on the left, a large circle glyph on the right, the white track between. It stays in sync with pinching. Accessibility "Zoom", adjustable, value as a percentage. |
| AP-MS-06 | At the bottom: "Cancel" (white text, leading) returns to the photo picker to choose again; "Done" (Lake 600 pill, white semibold text, trailing) applies the crop (AP-PH-04) and returns to Add player with the photo on the avatar and the caption "Change photo". From "Adjust photo", Cancel returns to Add player unchanged. Cancel on a new photo reopens the picker only once Move and Scale has finished closing (`fullScreenCover`'s `onDismiss`), since presenting it during the cover's dismissal can be dropped. |
| AP-MS-10 | **UI tests** can't drive the system picker, so `-uiTestMockPhoto success\|fail` injects a `PhotoLoading` mock: tapping the avatar "picks" a fixed drawn photo (or fails) without the picker, and Cancel in Move and Scale returns to the form. The live `LivePhotoLoader` loads the picker's selection as data. |
| AP-MS-07 | **VoiceOver:** the photo area is one element, "Photo, drag to move, pinch to zoom", with actions "Move up / down / left / right" (10 % of the circle each) and "Zoom in / out". |
| AP-MS-08 | Device-agnostic (X-19): the circle stays 320 pt and centered; on narrow screens it shrinks to the screen width minus 32 pt. |
| AP-MS-09 | `PhotoCropModel` is pure: image size, circle size, offset and zoom in; the clamped offset and zoom and the crop rectangle in image pixels out, plus the VoiceOver steps and the slider's percentage. `PlayerPhotoModel` runs the flow (picker, loading, failure, Move and Scale, the menu) and hands the JPEG to the form. Both, with `PhotoEncoder`, have 100 % unit coverage (the `player photo logic` group). |

## 4. Name fields
| ID | Requirement |
|----|-------------|
| AP-NM-01 | `FormFieldCard` with two fields. **FIRST NAME** (placeholder "e.g. Mark") is required. **LAST NAME** (placeholder "Optional") is optional. |
| AP-NM-02 | Text content types `.givenName` / `.familyName`, autocapitalization words, Return moves to the next field. |
| AP-NM-03 | The first name is trimmed and must be 1–30 characters. The last name is 0–30 characters. Typing past 30 characters is refused (the field keeps the first 30). |
| AP-NM-04 | A duplicate full name shows a non-blocking warning "A player named {name} already exists". |

## 5. Handicap index
| ID | Requirement |
|----|-------------|
| AP-HC-01 | A `FormFieldCard` (own card, under the name fields) with one field: label **STARTING INDEX** (SF Pro 600 12 caps, Moss 600) and a text field with placeholder "e.g. 8.4" (SF Pro 17). Under the card, a caption hint (`addPlayer.handicapHint`): "Used until 3 rounds are played. Add recent scores from other courses on the Handicap screen to start from your real index." |
| AP-HC-02 | **Optional.** The numbers-and-punctuation keyboard (`.numbersAndPunctuation`: the decimal pad has no "+" for plus handicaps). Accepts −10.0 … 54.0 with at most one decimal, after a dot or a comma. A leading "+" means a plus handicap ("+2.1" is stored as −2.1 and shown as "+2.1"). *Inferred.* |
| AP-HC-03 | Invalid input (out of range, more than one decimal, not a number) shows an inline error "Enter a number from +10.0 to 54.0" and disables Create. Blank is valid. |
| AP-HC-04 | **A seed, not an override** (#268): the entered index is the player's handicap only until they have 3 usable rounds; from then the calculated index is shown everywhere (18-handicap HC-SRC-01, 02). It also seeds those first rounds' calculation (HC-CA-14). Blank: no index until 3 rounds. |
| AP-HC-05 | **Shown only until there's a calculated index:** Add player always shows the field; Edit player shows it while `HandicapManager` has no calculated index for the player (fewer than 3 usable rounds) and hides it, with its hint, once there is one. It's read live, so a form opened before the manager's first pass follows it. Hidden, the stored value is kept and saved unchanged. |

### 5.1 Calculated handicap
From the third usable round, the player's index is calculated from their rounds and outside scores, with or without a starting index. That's specified in [18-handicap.md](18-handicap.md).

## 6. Color
| ID | Requirement |
|----|-------------|
| AP-CL-01 | `SectionHeader` "COLOR" + card with 5 44 pt color swatches: Lake, Sand, Flag, Fairway, Moss (accessibility labels = names). |
| AP-CL-02 | Single select. The selected swatch shows a 3 pt white + 2 pt Canopy double ring. Default = the first color not used by an existing player, otherwise Lake. |
| AP-CL-03 | The chosen color is used for the avatar background whenever there's no photo. |

## 7. Create
| ID | Requirement |
|----|-------------|
| AP-CR-01 | Full-width `PrimaryButton` "Create" at the large height (56 pt, `.dsPrimary(height: .large, fullWidth: true)`) at the end of the form (it scrolls with the content). |
| AP-CR-02 | Disabled until the first name is valid and the handicap field is blank or valid. |
| AP-CR-03 | Saves the `Player` (firstName, lastName, color, photoData, handicapIndex? — the starting index, nil when blank) and dismisses. The repository sets `isMarquee` for the first player in an empty store only (DM-PL-12); later creation preserves the marquee choice or None. A save error shows an alert ("Something went wrong", "The player couldn't be saved. Try again.", OK) and the form stays. |

## 8. Data
| ID | Requirement |
|----|-------------|
| AP-DT-01 | `Player` has `photoData: Data?`, `handicapIndex: Double?` (the starting index only; the calculated index isn't stored) and `colorToken` (the new palette), as specified in 12-data-model. No data migration is needed. |
| AP-DT-02 | ~~Export / import~~ Removed: v2 has no Import / Export (see 02-settings §5). |
| AP-DT-03 | `PlayerFormViewModel` (`.create` / `.edit(playerID)`) handles validation, dirty tracking (every field, color and photo included), the default color, Create / Save and Delete. If the player list can't be read, a new form still opens (Lake, no duplicate check). 100 % coverage (the `player form logic` group). The form is `PlayerFormView`, shown by the router's `addPlayer` and `editPlayer` sheets. |

## 9. Edit configuration (from the Player card)
| ID | Requirement |
|----|-------------|
| AP-ED-01 | Opened only from Player card › Edit. There's no Edit entry from Add player's own entry points. |
| AP-ED-02 | Title "EDIT PLAYER". The form is prefilled with the player's photo, first / last name, starting index (blank if none; the field is hidden once there's a calculated index, AP-HC-05) and color. |
| AP-ED-03 | The bottom button reads "Save" (same `PrimaryButton`). It's disabled until something changes and the first name is valid. |
| AP-ED-04 | Cancel with changes → "Discard changes?" (Discard / Keep editing). |
| AP-ED-05 | Clearing the Starting index field removes the starting index; the player shows "—" until they have 3 usable rounds. |
| AP-ED-06 | The color picker's default-color rule (AP-CL-02) doesn't apply; the player's current color is selected. |
| AP-ED-07 | A destructive "Delete player" row below Save. It confirms with the title "Delete {name}?" (the saved name, not what's typed) and the message "Their {n} rounds will also be removed." (plural; no message when they have none) and cascades to their `RoundEntry`s (12-data-model DM-RL-03). It's blocked (disabled, with the explanation "Finish or delete their round in progress first.") while the player is in an active round in progress, and also if the rounds can't be read ("Their rounds couldn't be read, so they can't be deleted right now."). This is worked out when the form opens, not on every keystroke. After deleting, both the form and the Player card are dismissed, back to the screen the card was opened from (Home or All players). |
| AP-ED-09 | If the player being edited no longer exists (deleted elsewhere) or the players can't be read, the form shows "This player no longer exists." and closes on OK; Save stays disabled. |
| AP-ED-08 | Saving updates the `Player` in place, preserving `isMarquee`; marquee selection is changed only through Settings (SET-MQ). The Player card, Home, All players and past rounds reflect the new name / photo / color through observation. |

## 10. Accessibility identifiers
`addPlayer.cancel`, `addPlayer.photo`, `addPlayer.photoCaption`, `addPlayer.photoMenu.choose`, `addPlayer.photoMenu.adjust`, `addPlayer.photoMenu.remove`, `photoCrop.title`, `photoCrop.image`, `photoCrop.zoom`, `photoCrop.cancel`, `photoCrop.done`, `addPlayer.firstName`, `addPlayer.lastName`, `addPlayer.handicap`, `addPlayer.color.{name}`, `addPlayer.create`, `addPlayer.save`, `addPlayer.delete`.
