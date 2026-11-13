# 06 — Link GHIN

**Artboard:** Link GHIN
**Entry:** Add player (or Edit player) › "Add GHIN" (push).
**Exit:** "‹ Back" → Add player, unchanged. "Use this handicap" → Add player with the GHIN profile applied.

## 1. Overview
A Chalk 50 screen with a `DSNavigationBar` ("‹ Back" / "LINK GHIN"). It has an intro block, a two-field form and a Connect button. After lookup the form is replaced by a **Profile found** card. It has two states: **Form** and **Found**.

## 2. Intro
| ID | Requirement |
|----|-------------|
| GH-IN-01 | A centered icon tile (GHIN / link glyph), decorative. |
| GH-IN-02 | Title "Connect your GHIN" (Sofia 700). |
| GH-IN-03 | Body "Enter your GHIN number and last name. We'll pull your Handicap Index and keep it updated after every revision." (Inter, Moss 600, centered). |

## 3. Form state
| ID | Requirement |
|----|-------------|
| GH-FM-01 | `FormFieldCard` with a **GHIN NUMBER** field (placeholder "7–10 digits", `keyboardType(.numberPad)`, `textContentType(.oneTimeCode)` off) and a **LAST NAME** field (placeholder "As it appears on your GHIN profile"). The last name is prefilled from Add player when available. |
| GH-FM-02 | The GHIN field strips non-digits as you type and caps at 10 digits. |
| GH-FM-03 | `PrimaryButton` "Connect" (54 pt) stays **disabled** (Chalk 200 / Moss 600) until there are ≥ 7 digits **and** a non-empty last name. *The design only checks digits; requiring the last name is inferred.* |
| GH-FM-04 | Helper text under the button: "Your GHIN number is in your club's handicap app or on your membership card." |
| GH-FM-05 | On Connect: show progress on the button ("Connecting…", spinner), disable the inputs and call `GHINService.lookup(number:lastName:)`. |
| GH-FM-06 | Errors: **not found / name mismatch** → inline error "We couldn't find a GHIN profile with that number and last name." **Network** → "Can't reach GHIN. Check your connection and try again." **Rate-limited / server** → a generic retry message. The form stays editable. |

## 4. Found state
| ID | Requirement |
|----|-------------|
| GH-FD-01 | A pill "✓ PROFILE FOUND" (success style). |
| GH-FD-02 | A profile card with the full name (Inter 600), "{Club} · GHIN {number}" and "Revised {MMM d, yyyy}" (Caption), plus a trailing "HCP INDEX" label over the index (Sofia 700 large). |
| GH-FD-03 | `PrimaryButton` "Use this handicap" returns to Add player and applies `ghinNumber`, `handicapIndex`, `handicapRevisedAt` and, if empty, first/last name. |
| GH-FD-04 | `TextLinkButton` "Not you? Try another number" clears the GHIN field and returns to the Form state. |
| GH-FD-05 | Editing the GHIN field after a lookup resets to the Form state. |

## 5. Ongoing sync (inferred from "keep it updated after every revision")
| ID | Requirement |
|----|-------------|
| GH-SY-01 | When the app foregrounds (at most once every 24 h), refresh the handicap index for every linked player through `GHINService`. Store the new value and `handicapRevisedAt`. |
| GH-SY-02 | Sync failures fail silently. The last known index stays. |
| GH-SY-03 | The index history is kept (for the Player card handicap chart): `HandicapRevision(date, index)`. |

## 6. Service and security
| ID | Requirement |
|----|-------------|
| GH-SV-01 | `GHINService` is a protocol. The production implementation calls the GHIN API (USGA). A `MockGHINService` is used for previews and UI tests (selected by a launch argument `-uiTestMockGHIN`). |
| GH-SV-02 | API credentials are never stored in source. They go in the Keychain or come from config. GHIN numbers are personal data. Don't log them. |
| GH-SV-03 | Network timeout is 15 s. Decoding errors map to typed `GHINError`. |

## 7. Accessibility identifiers
`ghin.back`, `ghin.number`, `ghin.lastName`, `ghin.connect`, `ghin.error`, `ghin.found`, `ghin.useHandicap`, `ghin.tryAnother`.

## Open questions
1. GHIN API access: does the club / app have USGA API credentials? Without them this needs manual entry or a deferral.
2. Should posting scores to GHIN (see Round detail share) be in v2?
