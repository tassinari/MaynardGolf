# 02 — Settings

**Artboard:** Settings
**Entry:** Home › gear button (push).

## 1. Overview
A Chalk 50 screen with a `DSNavigationBar` (leading "‹ Home" pill, centered title "SETTINGS"). It has three grouped sections: **Options**, **Local rules** and **About**. Settings persist on the device through a `SettingsStore`.

## 2. Navigation bar
| ID | Requirement |
|----|-------------|
| SET-NAV-01 | Leading `NeutralPillButton` with a back chevron and "Home", accessibility label "Back to home". Pops to Home. The system back swipe also works. |
| SET-NAV-02 | Centered title "SETTINGS" (Section style). |

## 3. Options section
`SectionHeader` "OPTIONS" + `CardContainer`, rows separated by hairlines.

| ID | Requirement |
|----|-------------|
| SET-OPT-01 | **Distance**: label "Distance" with a trailing `DSSegmented` of "Yards" and "Meters" (accessibility group "Distance units"). Default **Yards**. Changes every yardage shown in the app (hole card, tee cards, overlays). |
| SET-OPT-02 | **Show to-par scores** toggle, hint "Leaderboard shows −2 instead of 70". Default **on**. When off, the leaderboard, players sheet and Home in-progress card show gross totals. |
| SET-OPT-03 | **Shot line on map** toggle, hint "Dotted line from tee to pin". Default **on**. Controls `ShotLine` on Hole play. |
| SET-OPT-04 | **Auto-advance holes** toggle, hint "Move on when all scores are in". Default **off**. When on, Hole play moves to the next hole after the last player's score for the current hole is saved. |
| SET-OPT-05 | **Haptics** toggle, hint "Tap feedback when entering scores". Default **on**. Controls `sensoryFeedback` in the score entry and stepper. |
| SET-OPT-06 | **Default tees** row: label, trailing `TeeDot` + tee name (e.g. "Blue") + chevron. Tapping it opens a picker listing the course's tees. The value preselects the tee on New round. |
| SET-OPT-07 | Toggles use `DSToggle` with accessibility label = row label. Hint text is the accessibility hint. |

## 4. Local rules section
| ID | Requirement |
|----|-------------|
| SET-LR-01 | `SectionHeader` "LOCAL RULES". |
| SET-LR-02 | Navigation row: icon tile, title "{Course name}" (e.g. "Maynard Golf"), subtitle "{n} local rules · updated {Mon YYYY}", chevron. Opens the **Local rules** sheet. |
| SET-LR-03 | **Show at tee off** toggle, hint "Pop up rules when a round starts", accessibility label "Show local rules at tee off". Default **on**. When on, the Local rules sheet opens automatically when a round starts (after "Tee off"). |

## 5. About section
| ID | Requirement |
|----|-------------|
| SET-AB-01 | `SectionHeader` "ABOUT". |
| SET-AB-02 | "Version" row with the trailing value `{CFBundleShortVersionString} ({CFBundleVersion})`, read at runtime, not hard-coded "1.0 (1)". |
| SET-AB-03 | "Rate the app": uses `requestReview` / opens the App Store review URL. |
| SET-AB-04 | "Send feedback": opens a mail composer (`MFMailComposeViewController`) to the support address, with app version and device model in the body. Falls back to a `mailto:` link, or an alert if mail isn't configured. |
| SET-AB-05 | "Privacy policy": opens the hosted privacy policy in `SFSafariViewController`. The existing `privacy policy.txt` content must be hosted. |
| SET-AB-06 | "Terms of use": opens the terms URL in `SFSafariViewController`. |
| SET-AB-07 | Footer text "Made for weekend foursomes", centered, Caption, Moss 600. |
| SET-AB-08 | *Inferred:* the v1 Import / Export database rows should move here under a "Data" section (open question). |

## 6. Data
| ID | Requirement |
|----|-------------|
| SET-DT-01 | `SettingsStore` is a protocol with a `UserDefaults`-backed implementation (`@AppStorage` keys namespaced `settings.*`) and an in-memory implementation for tests. |
| SET-DT-02 | `SettingsViewModel` exposes typed values: `DistanceUnit`, `Bool`s, `Tee`, and the derived local-rules summary. |
| SET-DT-03 | Changes apply immediately (no Save button) and are seen by other screens through observation. |

## 7. Accessibility identifiers
`settings.back`, `settings.distance`, `settings.toggle.toPar`, `settings.toggle.shotLine`, `settings.toggle.autoAdvance`, `settings.toggle.haptics`, `settings.defaultTees`, `settings.localRules`, `settings.toggle.rulesAtTeeOff`, `settings.version`, `settings.rate`, `settings.feedback`, `settings.privacy`, `settings.terms`.

## Open questions
1. Where do the v1 Import / Export (backup / restore) features live in v2?
2. Support email address and the privacy / terms URLs?
3. Default tees: Maynard GC's tees are Red / Yellow / White / Blue, but the design shows Black / Blue / White / Red.
