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
| SET-OPT-01 | **Show to-par scores** toggle, hint "Leaderboard shows −2 instead of 70". Default **on**. When off, the leaderboard, players sheet and Home in-progress card show gross totals. |
| SET-OPT-02 | **Shot line on map** toggle, hint "Dotted line from tee to pin". Default **on**. Controls `ShotLine` on Hole play. |
| SET-OPT-03 | **Auto-advance holes** toggle, hint "Move on when all scores are in". Default **off**. When on, Hole play moves to the next hole after the last player's score for the current hole is saved. |
| SET-OPT-04 | **Default tees** row: label, trailing `TeeDot` + tee name + chevron. Tapping it opens a picker listing the course's tees: **Blue, White, Yellow, Red** (Maynard GC's tees, from [course-maynard-gc.md](course-maynard-gc.md) §2). Default **White**. The value preselects the tee on New round (NR-TEE-05). |
| SET-OPT-05 | Toggles use `DSToggle` with accessibility label = row label. Hint text is the accessibility hint. |

## 4. Local rules section
| ID | Requirement |
|----|-------------|
| SET-LR-01 | `SectionHeader` "LOCAL RULES". |
| SET-LR-02 | Navigation row: icon tile, title "{Course name}" (e.g. "Maynard Golf"), subtitle "{n} local rules · updated {Mon YYYY}", chevron. Opens the **Local rules** sheet. |

## 5. About section
| ID | Requirement |
|----|-------------|
| SET-AB-01 | `SectionHeader` "ABOUT". |
| SET-AB-02 | "Version" row with the trailing value `{CFBundleShortVersionString} ({CFBundleVersion})`, read at runtime, not hard-coded "1.0 (1)". |
| SET-AB-03 | "Rate the app": uses `requestReview` / opens the App Store review URL. |
| SET-AB-04 | "Send feedback": opens a mail composer (`MFMailComposeViewController`) to the support address **tassinari@yahoo.com**, with app version and device model in the body. Falls back to a `mailto:` link, or an alert if mail isn't configured. |
| SET-AB-05 | "Privacy policy": opens **https://maynardgolf.tassinari.org/privacy** in `SFSafariViewController`. The existing `privacy policy.txt` content must be hosted there. |
| SET-AB-06 | Footer text "Made for weekend foursomes", centered, Caption, Moss 600. |
| SET-AB-07 | The support email and privacy URL live in one config constant (`AppLinks`), not inline in views. |

**Removed from v1:** Import / Export (database backup / restore) is not carried into v2. There's no Data section, and the v1 `Import.swift` / export flow and its ZIPFoundation dependency can be deleted.

## 6. Data
| ID | Requirement |
|----|-------------|
| SET-DT-01 | `SettingsStore` is a protocol with a `UserDefaults`-backed implementation (`@AppStorage` keys namespaced `settings.*`) and an in-memory implementation for tests. |
| SET-DT-02 | `SettingsViewModel` exposes typed values: `Bool`s (`showToPar`, `showShotLine`, `autoAdvance`), the default `Tee` (default White), and the derived local-rules summary. |
| SET-DT-03 | Changes apply immediately (no Save button) and are seen by other screens through observation. |

## 7. Accessibility identifiers
`settings.back`, `settings.toggle.toPar`, `settings.toggle.shotLine`, `settings.toggle.autoAdvance`, `settings.defaultTees`, `settings.localRules`, `settings.version`, `settings.rate`, `settings.feedback`, `settings.privacy`.

## Resolved questions
1. ~~Where do Import / Export live?~~ **Dropped:** not needed in v2 (§5).
2. ~~Support email and URLs?~~ Support **tassinari@yahoo.com**; privacy policy **https://maynardgolf.tassinari.org/privacy**. There's no Terms of use row.
3. ~~Default tees?~~ Maynard's tees: **Blue / White / Yellow / Red**; default **White**.
