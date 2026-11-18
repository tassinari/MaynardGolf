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
| SET-OPT-04 | **Default tees** row: label, trailing `TeeDot` + tee name + chevron (White shows a white dot with a 1.5 pt Moss 400 ring). Tapping it opens a menu of buttons, one per course tee (`settings.defaultTees.{tee}`): **Blue, White, Yellow, Red** (Maynard GC's tees, from [course-maynard-gc.md](course-maynard-gc.md) §2), with the chosen one checked. Default **White**. The value preselects the tee on New round (NR-TEE-05). VoiceOver reads "Default tees" with the tee as its value. |
| SET-OPT-05 | Toggles use `DSToggle` with accessibility label = row label. Hint text is the accessibility hint. |

## 4. Local rules section
| ID | Requirement |
|----|-------------|
| SET-LR-01 | `SectionHeader` "LOCAL RULES". |
| SET-LR-02 | Navigation row: icon tile, title "{Course name}" ("Maynard Golf Club"), subtitle "{n} local rules" (e.g. "12 local rules", localized plural), chevron. The icon tile is a flag glyph (Rough 600) on Tee Green 50. Opens the **Local rules** sheet. |

## 5. About section
| ID | Requirement |
|----|-------------|
| SET-AB-01 | `SectionHeader` "ABOUT". Rows in order: Version, Send feedback, Privacy policy, Rate the app, Weather data. The four action rows have a trailing chevron. |
| SET-AB-02 | "Version" row with the trailing value `{CFBundleShortVersionString} ({CFBundleVersion})` ("1.2 (211)"), read at runtime through `AppDependencies.about` (`AboutInfo`: `.live` in the app, fixed "1.2 (211)" in UI tests and previews), not hard-coded. A missing value reads as "?". |
| SET-AB-03 | "Rate the app": asks for a review with SwiftUI's `requestReview` (the system decides whether to show the prompt). |
| SET-AB-04 | "Send feedback": opens a mail composer (`MFMailComposeViewController`) to the support address **tassinari@yahoo.com**, subject "Maynard Golf feedback", with the app version, build, device model and iOS version at the end of the body. Falls back to a `mailto:` link, or an alert ("Mail isn't set up", naming the address) if nothing can send mail. |
| SET-AB-05 | "Privacy policy": opens **https://maynardgolf.tassinari.org/privacy** in the in-app Safari view (`OpenURLAction.inAppBrowser`: `.systemAction(prefersInApp: true)`, set on Settings where it's created). The existing `privacy policy.txt` content must be hosted there. |
| SET-AB-06 | Footer text "Made for weekend foursomes", centered, Caption, Moss 600. |
| SET-AB-07 | The support email and privacy URL live in one config constant (`AppLinks`), not inline in views. |
| SET-AB-08 | *Inferred (no design):* an "iCloud backup" status row (On / Signed out of iCloud / iCloud storage full / Syncing…). See 13-icloud-sync IC-ST-01. **Not built yet:** it comes with sync (#96). |
| SET-AB-09 | **Weather attribution** (required by Apple for WeatherKit): a row "Weather data" in About, after "Rate the app", with the trailing Apple Weather mark as text (" Weather"). It opens WeatherKit's own legal attribution page (`WeatherService.shared.attribution.legalPageURL`, through `WeatherProviding.attributionPage()`), or https://weatherkit.apple.com/legal-attribution.html (`AppLinks.weatherAttribution`) when that can't be read, in the in-app Safari view. This is the **only** place the attribution appears. |

**Removed from v1:** Import / Export (database backup / restore) is not carried into v2. There's no Data section, and the v1 `Import.swift` / export flow and its ZIPFoundation dependency can be deleted.

## 6. Data
| ID | Requirement |
|----|-------------|
| SET-DT-01 | `SettingsStore` is one `@Observable` class over an injected `SettingsStorage` (a small key-value protocol): `UserDefaultsSettingsStorage` for the app (keys namespaced `settings.*`: `showToPar`, `showShotLine`, `autoAdvance`, `defaultTee`, `lastHoleCount`) and `InMemorySettingsStorage` for tests, previews and UI tests, which always start from the defaults. One class keeps the defaults, the fallbacks and the observation in one place. A missing or wrongly typed value reads as its default; an unknown tee or hole count reads as White or 9 (DM-EN-05). It lives on `AppDependencies.settings`. |
| SET-DT-02 | `SettingsViewModel` exposes typed values that read and write the shared store: `Bool`s (`showToPar`, `showShotLine`, `autoAdvance`), the default `Tee` (default White) with the course's tees for the picker, and the derived local-rules summary (course name, "12 local rules"). Without course data, the tees and the summary are empty. |
| SET-DT-03 | Changes are written to storage immediately (no Save button) and are seen by other screens through observation. |

## 7. Accessibility identifiers
`screen.settings` (the scroll view), `settings.back`, `settings.toggle.toPar`, `settings.toggle.shotLine`, `settings.toggle.autoAdvance`, `settings.defaultTees`, `settings.localRules`, `settings.version`, `settings.rate`, `settings.feedback`, `settings.privacy`, `settings.icloud`, `settings.weatherAttribution`.
